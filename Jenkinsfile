podTemplate(label: 'sanbase-builder', containers: [
  containerTemplate(name: 'docker', image: 'docker', ttyEnabled: true, command: 'cat', envVars: [
    envVar(key: 'DOCKER_HOST', value: 'tcp://docker-host-docker-host:2375')
  ])
]) {
  node('sanbase-builder') {
    stage('Run Tests') {
      container('docker') {
        checkout scm

        sh "docker build -t sanbase-test:${env.BRANCH_NAME} -f Dockerfile-test ."
        sh "docker run --rm --name postgres_${env.BRANCH_NAME} -d postgres:9.6-alpine"
        try {
          sh "docker run --rm --link postgres_${env.BRANCH_NAME}:db --env DATABASE_URL=postgres://postgres:password@db:5432/postgres -t sanbase-test:${env.BRANCH_NAME}"
        } finally {
          sh "docker kill postgres_${env.BRANCH_NAME}"
        }

        if (env.BRANCH_NAME == "master") {
          withCredentials([
            string(
              credentialsId: 'SECRET_KEY_BASE',
              variable: 'SECRET_KEY_BASE'
            ),
            string(
              credentialsId: 'aws_account_id',
              variable: 'aws_account_id'
            )
          ]) {

            def awsRegistry = "${env.aws_account_id}.dkr.ecr.eu-central-1.amazonaws.com"
            def GIT_COMMIT = sh(script: "git rev-parse HEAD", returnStdout: true).trim()
            docker.withRegistry("https://${awsRegistry}", "ecr:eu-central-1:ecr-credentials") {
              sh "docker build -t ${awsRegistry}/sanbase:${env.BRANCH_NAME} -t ${awsRegistry}/sanbase:${GIT_COMMIT} --build-arg SECRET_KEY_BASE=${env.SECRET_KEY_BASE} ."
              sh "docker push ${awsRegistry}/sanbase:${env.BRANCH_NAME}"
              sh "docker push ${awsRegistry}/sanbase:${GIT_COMMIT}"
            }

          }
        }
      }
    }
  }
}