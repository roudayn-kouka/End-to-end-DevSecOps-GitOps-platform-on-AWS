// Dockerfile best-practice linting (fails on warnings and errors).
def call(Map args) {
    sh """
        docker run --rm -i -v "\$PWD/.hadolint.yaml:/.config/hadolint.yaml:ro" ${toolImages().hadolint} \
            hadolint --failure-threshold warning - < ${args.dockerfile}
    """
}
