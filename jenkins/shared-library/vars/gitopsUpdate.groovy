// GitOps write-back: bump image.tag in helm/skyforge/values-<environment>.yaml and push to main.
// ArgoCD notices the commit and rolls the new version out. Retries on concurrent pushes.
def call(Map args) {
    String valuesFile = "${args.chartDir}/values-${args.environment}.yaml"

    withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
        withEnv(["VALUES_FILE=${valuesFile}", "NEW_TAG=${args.tag}", "TARGET_ENV=${args.environment}"]) {
            // Single quotes: the token is expanded by the shell, never by Groovy (no leak in logs).
            sh '''
                set -eu
                git config user.name  "SkyForge CI"
                git config user.email "ci@skyforge.local"
                askpass="$(mktemp)"
                trap 'rm -f "$askpass"' EXIT
                printf '#!/bin/sh\ncase "$1" in Username*) echo "$GIT_USER";; *) echo "$GIT_TOKEN";; esac\n' > "$askpass"
                chmod 700 "$askpass"
                export GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0

                for attempt in 1 2 3; do
                    git fetch --quiet origin main
                    git checkout --quiet -B main origin/main
                    yq -i ".image.tag = \\"$NEW_TAG\\"" "$VALUES_FILE"
                    if git diff --quiet -- "$VALUES_FILE"; then
                        echo "$TARGET_ENV already runs $NEW_TAG"
                        exit 0
                    fi
                    git add "$VALUES_FILE"
                    git commit --quiet -m "deploy($TARGET_ENV): skyforge-tasks $NEW_TAG [skip ci]"
                    if git push --quiet origin main; then
                        echo "$TARGET_ENV -> $NEW_TAG pushed; ArgoCD will sync it"
                        exit 0
                    fi
                    echo "Push rejected (attempt $attempt), retrying..."
                    sleep 5
                done
                exit 1
            '''
        }
    }
}
