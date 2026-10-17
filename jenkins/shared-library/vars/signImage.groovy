// Signs the pushed image digest with cosign (supply-chain integrity).
// Enabled when COSIGN_ENABLED=true, set by JCasC when vault_cosign_private_key is provided.

def call(Map args) {
    withCredentials([
        file(credentialsId: 'cosign-key', variable: 'COSIGN_KEY'),
        string(credentialsId: 'cosign-password', variable: 'COSIGN_PASSWORD'),
    ]) {
        sh """
            docker run --rm -e COSIGN_PASSWORD \
                -v "\$COSIGN_KEY:/cosign.key:ro" \
                -v "\$HOME/.docker/config.json:/root/.docker/config.json:ro" \
                ${toolImages().cosign} sign --yes --key /cosign.key ${args.imageDigest}
        """
    }
}
