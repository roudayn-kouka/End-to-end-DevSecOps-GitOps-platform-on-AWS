// Vulnerability gate, run BEFORE the image is pushed:
//   1. full HIGH/CRITICAL report (informational, archived)
//   2. fail on fixable CRITICAL vulnerabilities
def call(Map args) {
    String trivy = """docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v trivy-cache:/root/.cache/ \
        -v "\$PWD:/work" -w /work \
        ${toolImages().trivy} image --scanners vuln --no-progress"""

    sh "${trivy} --severity HIGH,CRITICAL --exit-code 0 --format table --output trivy-report.txt ${args.image}"
    archiveArtifacts artifacts: 'trivy-report.txt', allowEmptyArchive: true
    sh "${trivy} --severity CRITICAL --ignore-unfixed --exit-code 1 ${args.image}"
}
