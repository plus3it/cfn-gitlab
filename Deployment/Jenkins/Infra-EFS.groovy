pipeline {

    agent any

    options {
        buildDiscarder(
            logRotator(
                numToKeepStr: '5',
                daysToKeepStr: '30',
                artifactDaysToKeepStr: '30',
                artifactNumToKeepStr: '3'
            )
        )
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        AWS_DEFAULT_REGION = "${AwsRegion}"
        AWS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
        REQUESTS_CA_BUNDLE = '/etc/pki/tls/certs/ca-bundle.crt'
    }

    parameters {
        string(name: 'AwsRegion', defaultValue: 'us-east-1', description: 'Amazon region to deploy resources into')
        string(name: 'AwsCred', description: 'Jenkins-stored AWS credential with which to execute cloud-layer commands')
        string(name: 'GitCred', description: 'Jenkins-stored Git credential with which to execute git commands')
        string(name: 'GitProjUrl', description: 'SSH URL from which to download the Jenkins git project')
        string(name: 'GitProjBranch', description: 'Project-branch to use from the Jenkins git project')
        string(name: 'CfnStackRoot', description: 'Unique token to prepend to all stack-element names')
        choice(name: 'BucketInventoryTracking', choices: 'true\nfalse', description: '(Optional: ignored if BackupReportingBucket is unset) Whether to enable generic bucket inventory-tracking')
        choice(name: 'CertHostingService', choices:'ACM\nIAM', description: 'Select AWS service that is hosting the SSL certificate.')
        string(name: 'CloudwatchBucketName', description: 'Name of the S3 Bucket hosting the CloudWatch agent archive files', defaultValue: 'amazoncloudwatch-agent')
        string(name: 'ConfigBucketPath', description: 'S3 bucket-path to GitLab configuration template-file.')
        string(name: 'DbAdminName', description: 'Name of the GitLab master database-user.')
        string(name: 'DbAdminPass', description: 'Password of the GitLab master database-user.')
        string(name: 'DbDataSize', description: 'Size in GiB of the RDS table-space to create.')
        string(name: 'DbInstanceName', description: 'Instance-name of the GitLab database.')
        string(name: 'DbInstanceType', description: 'Amazon RDS instance type')
        string(name: 'DbNodeName', description: 'NodeName of the GitLab database.')
        string(name: 'FinalExpirationDays', description: 'Number of days to retain objects before aging them out of the bucket', defaultValue: '30')
        string(name: 'GitLabListenerCert', description: 'Name/ID of the ACM-managed SSL Certificate to protect public listener.')
        choice(name: 'GitLabPassesSsh', choices: 'true\nfalse', description: 'Whether to allow SSH passthrough to GitLab master.')
        string(name: 'GitLabServicePort', description: 'TCP Port number that the GitLab host listens to.', defaultValue: '80')
        string(name: 'GitlabBucket', description: 'S3 Bucket to host GitLab files')
        string(name: 'GitlabBucketTemplate', description: 'URL to the child-template for creating the gitlab-bucket.')
        string(name: 'GitlabEfsTemplate', description: 'URL to the child-template for creating the GitLab EFS service.')
        string(name: 'GitlabElbSubnets', description: 'Select three subnets - each from different Availability Zones.')
        string(name: 'GitlabElbTemplate', description: 'URL to the child-template for creating the GitLab service-ELB')
        string(name: 'GitlabIamTemplate', description: 'URL to the child-template for creating the GitLab S3 bucket(s) IAM roles.')
        string(name: 'GitlabRdsTemplate', description: 'URL to the child-template for creating the GitLab RDS service.')
        string(name: 'HaSvcSubnets', description: 'Select three subnets - each from different Availability Zones.')
        string(name: 'PgsqlVersion', description: 'The X.Y.Z version of the PostGreSQL database to deploy.', defaultValue: '9.6.10')
        string(name: 'ReportingBucket', description: '(Optional) Destination for storing analytics data. Must be provided in ARN format.')
        string(name: 'RetainIncompleteDays', description: 'Number of days to retain objects that were not completely uploaded.', defaultValue: '2')
        string(name: 'RolePrefix', description: 'Prefix to apply to IAM role to make things a bit prettier (optional).', defaultValue: 'INSTANCE')
        string(name: 'SecurityGroupTemplate', description: 'URL to the child-template for creating the GitLab SecurityGroups.')
        string(name: 'TargetVPC', description: 'ID of the VPC to deploy GitLab components into.')
        string(name: 'TierToGlacierDays', description: 'Number of days to retain objects in standard storage tier.', defaultValue: '6')
    }

    stages {
        stage ('Prepare Agent Environment') {
            steps {
                deleteDir()
                git branch: "${GitProjBranch}",
                    credentialsId: "${GitCred}",
                    url: "${GitProjUrl}"
                writeFile file: 'gitlab-infra-efs.parms.json',
                    text: /
                        [
                            {
                                "ParameterKey": "BucketInventoryTracking",
                                "ParameterValue": "${env.BucketInventoryTracking}"
                            },
                            {
                                "ParameterKey": "CertHostingService",
                                "ParameterValue": "${env.CertHostingService}"
                            },
                            {
                                "ParameterKey": "CloudwatchBucketName",
                                "ParameterValue": "${env.CloudwatchBucketName}"
                            },
                            {
                                "ParameterKey": "ConfigBucketPath",
                                "ParameterValue": "${env.ConfigBucketPath}"
                            },
                            {
                                "ParameterKey": "DbAdminName",
                                "ParameterValue": "${env.DbAdminName}"
                            },
                            {
                                "ParameterKey": "DbAdminPass",
                                "ParameterValue": "${env.DbAdminPass}"
                            },
                            {
                                "ParameterKey": "DbDataSize",
                                "ParameterValue": "${env.DbDataSize}"
                            },
                            {
                                "ParameterKey": "DbInstanceName",
                                "ParameterValue": "${env.DbInstanceName}"
                            },
                            {
                                "ParameterKey": "DbInstanceType",
                                "ParameterValue": "${env.DbInstanceType}"
                            },
                            {
                                "ParameterKey": "DbNodeName",
                                "ParameterValue": "${env.DbNodeName}"
                            },
                            {
                                "ParameterKey": "FinalExpirationDays",
                                "ParameterValue": "${env.FinalExpirationDays}"
                            },
                            {
                                "ParameterKey": "GitLabListenerCert",
                                "ParameterValue": "${env.GitLabListenerCert}"
                            },
                            {
                                "ParameterKey": "GitLabPassesSsh",
                                "ParameterValue": "${env.GitLabPassesSsh}"
                            },
                            {
                                "ParameterKey": "GitLabServicePort",
                                "ParameterValue": "${env.GitLabServicePort}"
                            },
                            {
                                "ParameterKey": "GitlabBucket",
                                "ParameterValue": "${env.GitlabBucket}"
                            },
                            {
                                "ParameterKey": "GitlabBucketTemplate",
                                "ParameterValue": "${env.GitlabBucketTemplate}"
                            },
                            {
                                "ParameterKey": "GitlabEfsTemplate",
                                "ParameterValue": "${env.GitlabEfsTemplate}"
                            },
                            {
                                "ParameterKey": "GitlabElbSubnets",
                                "ParameterValue": "${env.GitlabElbSubnets}"
                            },
                            {
                                "ParameterKey": "GitlabElbTemplate",
                                "ParameterValue": "${env.GitlabElbTemplate}"
                            },
                            {
                                "ParameterKey": "GitlabIamTemplate",
                                "ParameterValue": "${env.GitlabIamTemplate}"
                            },
                            {
                                "ParameterKey": "GitlabRdsTemplate",
                                "ParameterValue": "${env.GitlabRdsTemplate}"
                            },
                            {
                                "ParameterKey": "HaSvcSubnets",
                                "ParameterValue": "${env.HaSvcSubnets}"
                            },
                            {
                                "ParameterKey": "PgsqlVersion",
                                "ParameterValue": "${env.PgsqlVersion}"
                            },
                            {
                                "ParameterKey": "ReportingBucket",
                                "ParameterValue": "${env.ReportingBucket}"
                            },
                            {
                                "ParameterKey": "RetainIncompleteDays",
                                "ParameterValue": "${env.RetainIncompleteDays}"
                            },
                            {
                                "ParameterKey": "RolePrefix",
                                "ParameterValue": "${env.RolePrefix}"
                            },
                            {
                                "ParameterKey": "SecurityGroupTemplate",
                                "ParameterValue": "${env.SecurityGroupTemplate}"
                            },
                            {
                                "ParameterKey": "TargetVPC",
                                "ParameterValue": "${env.TargetVPC}"
                            },
                            {
                                "ParameterKey": "TierToGlacierDays",
                                "ParameterValue": "${env.TierToGlacierDays}"
                            }
                        ]
                    /
                sh '''#!/bin/bash
                    printf "Validating param-file syntax... "
                    SYNTAXCHK=$( python -m json.tool gitlab-infra-efs.parms.json > /dev/null 2>&1 )$?
                    if [[ ${SYNTAXCHK} -eq 0 ]]
                    then
                       echo "syntax is valid"
                    else
                       echo "syntax not valid"
                       exit ${SYNTAXCHK}
                    fi
                '''
            }
        }
        stage ('Prepare AWS Environment') {
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to delete any active ${CfnStackRoot} stacks... "
                        aws --region "${AwsRegion}" cloudformation delete-stack --stack-name "${CfnStackRoot}"

                        sleep 5

                        # Pause if delete is slow
                        while [[ $(
                                    aws cloudformation describe-stacks \
                                      --stack-name ${CfnStackRoot} \
                                      --query 'Stacks[].{Status:StackStatus}' \
                                      --out text 2> /dev/null | \
                                    grep -q DELETE_IN_PROGRESS
                                   )$? -eq 0 ]]
                        do
                           echo "Waiting for stack ${CfnStackRoot} to delete..."
                           sleep 30
                        done
                    '''

                }
            }
        }
        stage ('Launch Nested Stack') {
            steps {
                withCredentials(
                    [
                        [$class: 'AmazonWebServicesCredentialsBinding', accessKeyVariable: 'AWS_ACCESS_KEY_ID', credentialsId: "${AwsCred}", secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']
                    ]
                ) {
                    sh '''#!/bin/bash
                        echo "Attempting to create stack ${CfnStackRoot}..."
                        aws --region "${AwsRegion}" cloudformation create-stack --stack-name "${CfnStackRoot}" \
                          --disable-rollback --capabilities CAPABILITY_NAMED_IAM \
                          --template-body file://Templates/make_gitlab_parent-infra-EFS.tmplt.json \
                          --parameters file://gitlab-infra-efs.parms.json

                        sleep 15

                        # Pause if create is slow
                        while [[ $(
                                    aws cloudformation describe-stacks \
                                      --stack-name ${CfnStackRoot} \
                                      --query 'Stacks[].{Status:StackStatus}' \
                                      --out text 2> /dev/null | \
                                    grep -q CREATE_IN_PROGRESS
                                   )$? -eq 0 ]]
                        do
                           echo "[$( date '+%Y-%m-%d %H:%M:%S' )] Waiting for stack ${CfnStackRoot} to finish create process..."
                           sleep 30
                        done

                        if [[ $(
                                aws cloudformation describe-stacks \
                                  --stack-name ${CfnStackRoot} \
                                  --query 'Stacks[].{Status:StackStatus}' \
                                  --out text 2> /dev/null | \
                                grep -q CREATE_COMPLETE
                               )$? -eq 0 ]]
                        then
                           echo "Stack-creation successful"
                        else
                           echo "Stack-creation ended with non-successful state"
                           exit 1
                        fi
                    '''
                }
            }
        }
    }
    post {
        cleanup {
           step([$class: 'WsCleanup'])
        }
    }
}
