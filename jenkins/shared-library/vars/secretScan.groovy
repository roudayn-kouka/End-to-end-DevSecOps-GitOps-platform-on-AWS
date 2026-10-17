// Fails the build if a credential is committed anywhere in the Git history.
def call() {
    sh """
        docker run --rm -v "\$PWD:/repo" -w /repo ${toolImages().gitleaks} \
            detect --source . --config .gitleaks.toml --redact --no-banner --verbose
    """
}
