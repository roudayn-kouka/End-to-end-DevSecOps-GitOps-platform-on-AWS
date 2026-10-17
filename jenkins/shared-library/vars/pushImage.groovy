// Pushes the image and returns its immutable digest (repo@sha256:...).
def call(Map args) {
    withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_TOKEN')]) {
        sh 'echo "$REGISTRY_TOKEN" | docker login docker.io -u "$REGISTRY_USER" --password-stdin'
    }
    sh "docker push ${args.image}"
    return sh(script: "docker inspect --format '{{index .RepoDigests 0}}' ${args.image}", returnStdout: true).trim()
}
