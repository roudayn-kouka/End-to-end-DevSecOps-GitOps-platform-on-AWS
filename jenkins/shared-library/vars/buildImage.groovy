// Builds the production (runtime) stage of the Dockerfile with OCI metadata.
def call(Map args) {
    sh """
        docker buildx build --load --pull \
            --target runtime \
            --build-arg APP_VERSION=${args.version} \
            --build-arg GIT_COMMIT=${args.commit} \
            --label org.opencontainers.image.source=\$(git config --get remote.origin.url) \
            --label org.opencontainers.image.created=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
            -t ${args.image} \
            ${args.context}
    """
}
