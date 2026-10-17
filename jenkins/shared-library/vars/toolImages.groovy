// Pinned container images for every CI tool: upgrading a tool is a one-line, reviewable change.
def call() {
    return [
        gitleaks: 'ghcr.io/gitleaks/gitleaks:v8.21.2',
        hadolint: 'hadolint/hadolint:v2.12.0',
        trivy   : 'aquasec/trivy:0.57.1',
        cosign  : 'gcr.io/projectsigstore/cosign:v2.4.1',
        sonar   : 'sonarsource/sonar-scanner-cli:11.1',
    ]
}
