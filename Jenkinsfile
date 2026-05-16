pipeline {
  agent any

  options {
    ansiColor('xterm')
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    AWS_DEFAULT_REGION = 'us-west-2'
    TF_IN_AUTOMATION   = 'true'
  }

  stages {
    stage('Checkout') {
      steps {
        cleanWs()
        checkout scm
      }
    }

    stage('Format') {
      steps {
        sh 'terraform fmt -check -recursive'
      }
    }

    stage('Init') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awsCredentials',
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh 'terraform init -input=false'
        }
      }
    }

    stage('Validate') {
      steps {
        sh 'terraform validate'
      }
    }

    stage('Plan') {
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awsCredentials',
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh 'terraform plan -input=false -out=tfplan'
          sh 'terraform show -no-color tfplan > tfplan.txt'
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
        }
      }
    }

    stage('Approval') {
      when {
        branch 'master'
      }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Apply this Terraform plan to AWS?', ok: 'Apply'
        }
      }
    }

    stage('Apply') {
      when {
        branch 'master'
      }
      steps {
        withCredentials([[
          $class: 'AmazonWebServicesCredentialsBinding',
          credentialsId: 'awsCredentials',
          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
          sh 'terraform apply -input=false -auto-approve tfplan'
        }
      }
    }
  }

  post {
    always {
      cleanWs()
    }
  }
}
