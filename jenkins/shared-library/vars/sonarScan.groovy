// Static analysis with SonarQube / SonarCloud (enabled when SONAR_HOST_URL is configured).
def call() {
    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
        sh """
            docker run --rm -e SONAR_HOST_URL -e SONAR_TOKEN -v "\$PWD:/usr/src" ${toolImages().sonar} \
                -Dsonar.qualitygate.wait=true
        """
    }
}
