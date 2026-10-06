// terraform-gitops-pipeline
//
// Multibranch pipeline for one Terraform stack with a root per environment.
//   * Every branch and pull request: static checks, then a saved plan that is
//     archived and summarized (and posted to the PR) for review.
//   * Trunk only: the same saved plan is applied. prod always waits for a human
//     approval; dev waits only when the plan deletes or replaces something.
//   * Nightly PLAN_ONLY runs on trunk report drift without applying.

pipeline {
  agent { label 'terraform' } // agent image provides terraform, tflint, checkov and jq

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Environment root to plan (and apply, on trunk).')
    booleanParam(name: 'PLAN_ONLY', defaultValue: false, description: 'Plan and report drift only; never apply.')
  }

  triggers {
    // Drift detection: plan both environments from trunk on weekday mornings.
    // Needs the Parameterized Scheduler plugin.
    parameterizedCron(env.BRANCH_NAME == 'master' ? '''
      H 5 * * 1-5 %ENVIRONMENT=dev;PLAN_ONLY=true
      H 6 * * 1-5 %ENVIRONMENT=prod;PLAN_ONLY=true
    ''' : '')
  }

  options {
    ansiColor('xterm')
    timestamps()
    disableConcurrentBuilds()
    skipDefaultCheckout(true)
    timeout(time: 90, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '20'))
  }

  environment {
    TRUNK_BRANCH     = 'master'
    TF_IN_AUTOMATION = 'true'
    TF_INPUT         = '0'
    TF_DIR           = "environments/${params.ENVIRONMENT}"
    // TF_STATE_BUCKET is a global Jenkins environment variable (not a secret).
  }

  stages {
    stage('Checkout') {
      steps {
        cleanWs()
        script {
          // With skipDefaultCheckout, checkout returns the git vars instead of setting them.
          env.GIT_COMMIT = checkout(scm).GIT_COMMIT
        }
      }
    }

    stage('Static checks') {
      parallel {
        stage('fmt + validate + test') {
          steps {
            sh 'scripts/check.sh' // offline: no backend, AWS provider mocked in tests
          }
        }

        stage('tflint') {
          steps {
            sh '''
              tflint --init
              tflint --recursive --config "$WORKSPACE/.tflint.hcl" --format compact
            '''
          }
        }

        stage('checkov') {
          steps {
            sh '''
              checkov -d . --framework terraform --quiet --compact \
                --output cli --output junitxml --output-file-path console,reports
            '''
          }
          post {
            always {
              junit allowEmptyResults: true, testResults: 'reports/results_junitxml.xml'
            }
          }
        }
      }
    }

    // Everything that touches state runs under one lock per environment, so the
    // plan a reviewer approves cannot go stale behind another build's apply.
    stage('Deliver') {
      options {
        lock(resource: "terraform-${params.ENVIRONMENT}")
      }

      stages {
        stage('Plan') {
          steps {
            withCredentials([[
              $class           : 'AmazonWebServicesCredentialsBinding',
              credentialsId    : "terraform-${params.ENVIRONMENT}-plan", // read-only role plus state access
              accessKeyVariable: 'AWS_ACCESS_KEY_ID',
              secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
            ]]) {
              sh 'terraform -chdir="$TF_DIR" init -input=false -backend-config="bucket=$TF_STATE_BUCKET"'
              script {
                // 0 = no changes, 2 = changes present, anything else = failure.
                int rc = sh(returnStatus: true,
                  script: 'terraform -chdir="$TF_DIR" plan -input=false -lock-timeout=5m -detailed-exitcode -out=tfplan')
                if (rc != 0 && rc != 2) {
                  error("terraform plan failed with exit code ${rc}")
                }
                env.PLAN_HAS_CHANGES = (rc == 2).toString()
              }
            }

            sh '''
              terraform -chdir="$TF_DIR" show -no-color tfplan > tfplan.txt
              terraform -chdir="$TF_DIR" show -json tfplan > tfplan.json
              scripts/plan-summary.sh tfplan.json "$ENVIRONMENT" > plan-summary.md
            '''

            script {
              env.PLAN_DESTRUCTIVE = sh(returnStdout: true, script: '''
                jq '[.resource_changes[]? | select(.mode == "managed") | select(.change.actions | index("delete"))] | length' tfplan.json
              ''').trim()
              currentBuild.description = "${params.ENVIRONMENT}: changes=${env.PLAN_HAS_CHANGES}, destructive=${env.PLAN_DESTRUCTIVE}"

              // Pull request builds post the summary on the PR (Pipeline: GitHub plugin).
              if (env.CHANGE_ID) {
                pullRequest.comment(readFile('plan-summary.md') +
                  "\n\nFull plan: ${env.BUILD_URL}artifact/tfplan.txt")
              }

              if (params.PLAN_ONLY && env.BRANCH_NAME == env.TRUNK_BRANCH && env.PLAN_HAS_CHANGES == 'true') {
                unstable("Drift: ${params.ENVIRONMENT} does not match ${env.TRUNK_BRANCH}. See plan-summary.md.")
              }
            }
          }
          post {
            always {
              archiveArtifacts allowEmptyArchive: true, fingerprint: true,
                artifacts: "tfplan.txt, plan-summary.md, ${env.TF_DIR}/tfplan"
            }
          }
        }

        stage('Approve') {
          when {
            expression {
              env.BRANCH_NAME == env.TRUNK_BRANCH && !params.PLAN_ONLY && env.PLAN_HAS_CHANGES == 'true' &&
                (params.ENVIRONMENT == 'prod' || env.PLAN_DESTRUCTIVE != '0')
            }
          }
          steps {
            script {
              timeout(time: 30, unit: 'MINUTES') {
                env.APPROVER = input(
                  message: "Apply the ${params.ENVIRONMENT} plan from ${env.GIT_COMMIT.substring(0, 8)}? Review plan-summary.md first.",
                  ok: 'Apply',
                  submitter: 'platform-approvers',
                  submitterParameter: 'APPROVER'
                )
              }
              echo "Approved by ${env.APPROVER}"
            }
          }
        }

        stage('Apply') {
          when {
            expression {
              env.BRANCH_NAME == env.TRUNK_BRANCH && !params.PLAN_ONLY && env.PLAN_HAS_CHANGES == 'true'
            }
          }
          steps {
            script {
              if (params.ENVIRONMENT == 'prod' && !env.APPROVER) {
                error('Refusing to apply prod without a recorded approval.')
              }
            }
            withCredentials([[
              $class           : 'AmazonWebServicesCredentialsBinding',
              credentialsId    : "terraform-${params.ENVIRONMENT}-apply", // only bound on trunk
              accessKeyVariable: 'AWS_ACCESS_KEY_ID',
              secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
            ]]) {
              // A saved plan applies exactly what was reviewed, with no new prompt.
              sh 'terraform -chdir="$TF_DIR" apply -input=false -lock-timeout=5m tfplan'
            }
          }
        }
      }
    }
  }

  post {
    always {
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
