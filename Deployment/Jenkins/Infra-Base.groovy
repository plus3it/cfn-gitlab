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
        string(name: 'SecurityGroupTemplate', description: 'URL to the child-template for creating the GitLab SecurityGroups')
        string(name: 'GitlabBucketTemplate', description: 'URL to the child-template used to create the GitLab S3-bucket')
        string(name: 'GitlabElbTemplate', description: 'URL to the child-template for creating the public-facing GitLab ELB')
        string(name: 'GitlabIamTemplate', description: 'URL to the child-template for creating the IAM roles used to access the GitLab S3 bucket(s)')
        string(name: 'GitlabRdsTemplate', description: 'URL to the child-template for creating the GitLab RDS service')
        string(name: 'DbInstanceType', defaultValue: 'db.m4.large', description: 'Amazon RDS instance type')
        string(name: 'DbDataSize', description: 'Size in GiB of the RDS table-space to create')
        string(name: 'PgsqlVersion', description: 'Version of the PostGreSQL database to deploy')
        string(name: 'DbNodeName', description: 'NodeName to assign to the GitLab RDS instance')
        string(name: 'DbInstanceName', description: 'Instance-name of the GitLab database')
        string(name: 'DbAdminName', description: 'Name of the GitLab master database-user')
        password(name: 'DbAdminPass', description: 'Password of the GitLab master database-user')
        string(name: 'GitlabElbSubnets', description: 'User-facing subnets to create ELB listeners on')
        string(name: 'GitLabServicePort', defaultValue: '80', description: 'TCP Port number that the GitLab service listens on')
        choice(name: 'GitLabPassesSsh', choices:'false\ntrue', description: 'Whether public-facing ELB should forward SSH traffic to GitLab EC2 instance')
        choice(name: 'CertHostingService', choices:'ACM\nIAM', description: 'Whether certificate is hosted in ACM or IAM')
        string(name: 'GitLabListenerCert', description: 'Amazon Certificate Manager object-ID for ELB SSL certificate')
        string(name: 'GitlabBucket', description: 'S3 Bucket used by GitLab EC2 host to store files for long-term retention')
        string(name: 'TierToGlacierDays', defaultValue: '7', description: 'Number of days to retain objects in standard storage tier')
        string(name: 'FinalExpirationDays', defaultValue: '30', description: 'Number of days to retain objects before aging them out of the bucket')
        string(name: 'RetainIncompleteDays', defaultValue: '2', description: 'Number of days to retain objects that were not completely uploaded')
        string(name: 'BucketInventoryTracking', defaultValue: 'false',description: '(Optional) Whether to enable generic bucket inventory-tracking. Requires setting of the "ReportingBucket" parameter')
        string(name: 'ReportingBucket', description: '(Optional) Destination for storing analytics data')
        string(name: 'ConfigBucketPath', description: 'S3 bucket-path to GitLab configuration template-file')
        string(name: 'TargetVPC', description: 'ID of the VPC to deploy GitLab components into')
        string(name: 'HaSvcSubnets', description: 'Private subnets to create RDS and EFS listeners on')
        string(name: 'RolePrefix', description: '(Optional) Prefix to apply to IAM role to make things a bit prettier')
        string(name: 'CloudwatchBucketName', description: 'S3 bucket from which to fetch CloudWatch log-agent')
    }

    stages {
        stage ('Prepare Agent Environment') {
            steps {
                deleteDir()
                git branch: "${GitProjBranch}",
                    credentialsId: "${GitCred}",
                    url: "${GitProjUrl}"
                writeFile file: 'gitlab-infra-base.parms.json',
                    text: /
                        [
                            {
                                "ParameterKey": "SecurityGroupTemplate",
                                "ParameterValue": "${env.SecurityGroupTemplate}"
                            },
                            {
                                "ParameterKey": "GitlabBucketTemplate",
                                "ParameterValue": "${env.GitlabBucketTemplate}"
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
                                "ParameterKey": "DbInstanceType",
                                "ParameterValue": "${env.DbInstanceType}"
                            },
                            {
                                "ParameterKey": "DbDataSize",
                                "ParameterValue": "${env.DbDataSize}"
                            },
                            {
                                "ParameterKey": "PgsqlVersion",
                                "ParameterValue": "${env.PgsqlVersion}"
                            },
                            {
                                "ParameterKey": "DbNodeName",
                                "ParameterValue": "${env.DbNodeName}"
                            },
                            {
                                "ParameterKey": "DbInstanceName",
                                "ParameterValue": "${env.DbInstanceName}"
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
                                "ParameterKey": "GitlabElbSubnets",
                                "ParameterValue": "${env.GitlabElbSubnets}"
                            },
                            {
                                "ParameterKey": "GitLabServicePort",
                                "ParameterValue": "${env.GitLabServicePort}"
                            },
                            {
                                "ParameterKey": "GitLabPassesSsh",
                                "ParameterValue": "${env.GitLabPassesSsh}"
                            },
                            {
                                "ParameterKey": "CertHostingService",
                                "ParameterValue": "${env.CertHostingService}"
                            },
                            {
                                "ParameterKey": "GitLabListenerCert",
                                "ParameterValue": "${env.GitLabListenerCert}"
                            },
                            {
                                "ParameterKey": "GitlabBucket",
                                "ParameterValue": "${env.GitlabBucket}"
                            },
                            {
                                "ParameterKey": "TierToGlacierDays",
                                "ParameterValue": "${env.TierToGlacierDays}"
                            },
                            {
                                "ParameterKey": "FinalExpirationDays",
                                "ParameterValue": "${env.FinalExpirationDays}"
                            },
                            {
                                "ParameterKey": "RetainIncompleteDays",
                                "ParameterValue": "${env.RetainIncompleteDays}"
                            },
                            {
                                "ParameterKey": "BucketInventoryTracking",
                                "ParameterValue": "${env.BucketInventoryTracking}"
                            },
                            {
                                "ParameterKey": "ReportingBucket",
                                "ParameterValue": "${env.ReportingBucket}"
                            },
                            {
                                "ParameterKey": "ConfigBucketPath",
                                "ParameterValue": "${env.ConfigBucketPath}"
                            },
                            {
                                "ParameterKey": "TargetVPC",
                                "ParameterValue": "${env.TargetVPC}"
                            },
                            {
                                "ParameterKey": "HaSvcSubnets",
                                "ParameterValue": "${env.HaSvcSubnets}"
                            },
                            {
                                "ParameterKey": "RolePrefix",
                                "ParameterValue": "${env.RolePrefix}"
                            },
                            {
                                "ParameterKey": "CloudwatchBucketName",
                                "ParameterValue": "${env.CloudwatchBucketName}"
                            }
                        ]
                    /
                sh '''#!/bin/bash
                    printf "Validating param-file syntax... "
                    SYNTAXCHK=$( python -m json.tool gitlab-infra-base.parms.json > /dev/null 2>&1 )$?
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
                          --template-body file://Templates/make_gitlab_parent-infra.tmplt.json \
                          --parameters file://gitlab-infra-base.parms.json

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
