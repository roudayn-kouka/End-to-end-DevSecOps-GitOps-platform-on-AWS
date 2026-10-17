// Runs lint + pytest inside the Dockerfile `test` stage and exports the reports
// (JUnit + Cobertura coverage) to ./reports for Jenkins.
def call(Map args) {
    sh """
        rm -rf reports
        docker buildx build --target test-report --output type=local,dest=reports ${args.context}
    """
}
