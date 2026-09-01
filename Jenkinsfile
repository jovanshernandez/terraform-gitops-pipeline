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
    TF_ENV             = 'dev'
    APPLY_BRANCH       = 'master'
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
          sh 'terraform init -input=false -backend-config=backend/${TF_ENV}.hcl'
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
          sh 'terraform plan -input=false -var-file=env/${TF_ENV}.tfvars -out=tfplan'
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
        expression { env.BRANCH_NAME == env.APPLY_BRANCH }
      }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Apply this Terraform plan to AWS?', ok: 'Apply'
        }
      }
    }

    stage('Apply') {
      when {
        expression { env.BRANCH_NAME == env.APPLY_BRANCH }
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
