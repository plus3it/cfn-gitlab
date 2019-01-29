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
        string(name: 'Ec2TemplateUrl', description: 'S3-hosted URL of the EC2 instance-template')
        string(name: 'CfnStackRoot', description: 'Unique token to prepend to all stack-element names')
        string(name: 'AdminPubkeyURL', description: 'URL of the admin-group SSH public key-bundle')
        string(name: 'AmiId', description: 'ID of the AMI to launch')
        choice(name: 'AppVolumeDevice', choices: 'true\nfalse', description: 'Decision whether to mount an extra EBS volume. Set to "false" to launch without an extra application volume')
        string(name: 'AppVolumeMountPath', description: 'Filesystem path to mount the extra app volume. Ignored if "AppVolumeDevice" is blank', defaultValue: '/opt/gitlab')
        string(name: 'AppVolumeSize', description: 'Size in GB of the EBS volume to create. Ignored if "AppVolumeDevice" is blank', defaultValue: '50')
        string(name: 'AppVolumeType', description: 'Type of EBS volume to create. Ignored if "AppVolumeDevice" is blank', defaultValue: 'gp2')
        string(name: 'BackupBucket', description: 'S3 Bucket to host backups of GitLab config-data')
        string(name: 'BackupFolder', description: 'Folder in S3 Bucket to host backups of GitLab config-data', defaultValue: 'Backups')
        string(name: 'CfnBootstrapUtilsUrl', description: 'URL to aws-cfn-bootstrap-latest.tar.gz', defaultValue: 'https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz')
        string(name: 'CfnEndpointUrl', description: '(Optional) URL to the CloudFormation Endpoint. e.g. https://cloudformation.us-east-1.amazonaws.com', defaultValue: 'https://cloudformation.us-east-1.amazonaws.com')
        string(name: 'CfnGetPipUrl', description: 'URL to get-pip.py', defaultValue: 'https://cloudformation.us-east-1.amazonaws.com')
        string(name: 'CloudWatchAgentUrl', description: '(Optional) S3 URL to CloudWatch Agent installer. Example: s3://amazoncloudwatch-agent/linux/amd64/latest/AmazonCloudWatchAgent.zip', defaultValue: 's3://amazoncloudwatch-agent/linux/amd64/latest/AmazonCloudWatchAgent.zip')
        string(name: 'ConfigBucketPath', description: 'S3 bucket-path to GitLab configuration template-file.')
        string(name: 'DesiredCapacity', description: 'Desired number of instances in the Autoscaling Group', defaultValue: '1')
        string(name: 'GitLabConfScript', description: 'URL of the script that localizes GitLab for running in the target environment')
        string(name: 'GitLabPrepScript', description: 'URL of the script that preps the OS to host GitLab')
        string(name: 'GitLabRpmName', description: 'Name of GitLab RPM to install. Include release version if "other-than-latest" is desired. Example values would be: gitlab-ce, gitlab-ce-X.Y.Z', defaultValue: 'gitlab-ce')
        string(name: 'GitLabRpmSourceUri', description: 'Url from which to download the Yum repository-definition for GitLab.', defaultValue: 'https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/config_file.repo?os=el&dist=7')
        choice(name: 'GitRepoShareType', choices: 'nfs\nglusterfs', description: 'Type of network share hosting persisted git repository content.')
        string(name: 'GitRepoShareUri', description: 'URI of network share hosting persisted git repository content.')
        string(name: 'InstanceRoleName', description: '(Optional) IAM instance-role name used by cfn-init to authenticate to the CloudFormation endpoint.')
        string(name: 'InstanceRoleProfile', description: '(Optional) IAM instance-role profile to apply to the instance(s)')
        string(name: 'InstanceType', description: 'Amazon EC2 instance type', defaultValue: 'm5.large')
        string(name: 'KeyPairName', description: 'Public/private key pairs allow you to securely connect to your instance after it launches')
        string(name: 'LoadBalancerNames', description: 'Comma-separated string of Classic ELB Names to associate with the Autoscaling Group; conflicts with TargetGroupArns')
        string(name: 'MaxCapacity', description: 'Maximum number of instances in the Autoscaling Group', defaultValue: '2')
        string(name: 'MinCapacity', description: 'Minimum number of instances in the Autoscaling Group', defaultValue: '0')
        choice(name: 'NoPublicIp', choices: 'true\nfalse', description: 'Controls whether to assign the instance a public IP (set to "true" _unless_ launching in a public subnet)')
        choice(name: 'NoReboot', choices: 'true\nfalse', description: 'Controls whether to reboot the instance as the last step of cfn-init execution')
        choice(name: 'NoUpdates', choices: 'true\nfalse', description: 'Controls whether to run yum update during a stack update (on the initial instance launch, Watchmaker _always_ installs updates)')
        string(name: 'ProvisionUser', description: 'Default login user account name.', defaultValue: 'ec2-user')
        string(name: 'ProxyName', description: 'FQDN of public-facing reverse-proxy.')
        string(name: 'PypiIndexUrl', description: 'URL to the PyPi Index', defaultValue: 'https://pypi.org/simple')
        string(name: 'RdsDbAdmin', description: 'RDS database-user name.')
        string(name: 'RdsDbHost', description: 'RDS End-point Name (FQDN)')
        string(name: 'RdsDbInstance', description: 'RDS database name.')
        password(name: 'RdsDbPasswd', description: 'RDS database-user login password.')
        string(name: 'RootVolumeSize', description: 'Size in GB of the EBS volume to create. If smaller than AMI default, create operation will fail; If larger, root device-volume partition size will be increased', defaultValue: '20')
        string(name: 'ScaleDownSchedule', description: '(Optional) Scheduled Action in cron-format (UTC) to scale down to MinCapacity; ignored if empty or ScaleUpSchedule is unset (E.g. "0 0 * * *")')
        string(name: 'ScaleUpSchedule', description: '(Optional) Scheduled Action in cron-format (UTC) to scale up to MaxCapacity; ignored if empty or ScaleDownSchedule is unset (E.g. "0 10 * * Mon-Fri")')
        string(name: 'SecurityGroupIds', description: 'List of security groups to apply to the instance(s)')
        string(name: 'SubnetIds', description: 'List of subnets to associate to the Autoscaling Group')
        string(name: 'TargetGroupArns', description: 'Comma-separated string of Target Group ARNs to associate with the Autoscaling Group; conflicts with LoadBalancerNames')
        choice(name: 'ToggleCfnInitUpdate', choices: 'A\nB', description: 'A/B toggle that forces a change to instance metadata, triggering the cfn-init update sequence')
        choice(name: 'ToggleNewInstances', choices: 'A\nB', description: 'A/B toggle that forces a change to instance userdata, triggering new instances via the Autoscale update policy')
        string(name: 'WatchmakerAdminGroups', description: '(Optional) Colon-separated list of domain groups that should have admin permissions on the EC2 instance')
        string(name: 'WatchmakerAdminUsers', description: '(Optional) Colon-separated list of domain users that should have admin permissions on the EC2 instance')
        choice(name: 'WatchmakerAvailable', choices: 'true\nfalse', description: 'Specify if Watchmaker is available (if "false" all other Watchmaker-related parms will be ignored).')
        string(name: 'WatchmakerComputerName', description: '(Optional) Sets the hostname/computername within the OS')
        string(name: 'WatchmakerConfig', description: '(Optional) Path to a Watchmaker config file.  The config file path can be a remote source (i.e. http[s]://, s3://) or local directory (i.e. file://)')
        choice(name: 'WatchmakerEnvironment', choices: '\ndev\ntest\nprod', description: 'Environment in which the instance is being deployed')
        string(name: 'WatchmakerOuPath', description: '(Optional) DN of the OU to place the instance when joining a domain. If blank and "WatchmakerEnvironment" enforces a domain join, the instance will be placed in a default container. Leave blank if not joining a domain, or if "WatchmakerEnvironment" is "false"')
    }

    stages {
        stage ('Prepare Agent Environment') {
            steps {
                deleteDir()
                git branch: "${GitProjBranch}",
                    credentialsId: "${GitCred}",
                    url: "${GitProjUrl}"
                writeFile file: 'gitlab-ec2-autoscale.parms.json',
                    text: /
                        [
                            {
                                "ParameterKey": "AdminPubkeyURL",
                                "ParameterValue": "${env.AdminPubkeyURL}"
                            },
                            {
                                "ParameterKey": "AmiId",
                                "ParameterValue": "${env.AmiId}"
                            },
                            {
                                "ParameterKey": "AppVolumeDevice",
                                "ParameterValue": "${env.AppVolumeDevice}"
                            },
                            {
                                "ParameterKey": "AppVolumeMountPath",
                                "ParameterValue": "${env.AppVolumeMountPath}"
                            },
                            {
                                "ParameterKey": "AppVolumeSize",
                                "ParameterValue": "${env.AppVolumeSize}"
                            },
                            {
                                "ParameterKey": "AppVolumeType",
                                "ParameterValue": "${env.AppVolumeType}"
                            },
                            {
                                "ParameterKey": "BackupBucket",
                                "ParameterValue": "${env.BackupBucket}"
                            },
                            {
                                "ParameterKey": "BackupFolder",
                                "ParameterValue": "${env.BackupFolder}"
                            },
                            {
                                "ParameterKey": "CfnBootstrapUtilsUrl",
                                "ParameterValue": "${env.CfnBootstrapUtilsUrl}"
                            },
                            {
                                "ParameterKey": "CfnEndpointUrl",
                                "ParameterValue": "${env.CfnEndpointUrl}"
                            },
                            {
                                "ParameterKey": "CfnGetPipUrl",
                                "ParameterValue": "${env.CfnGetPipUrl}"
                            },
                            {
                                "ParameterKey": "CloudWatchAgentUrl",
                                "ParameterValue": "${env.CloudWatchAgentUrl}"
                            },
                            {
                                "ParameterKey": "ConfigBucketPath",
                                "ParameterValue": "${env.ConfigBucketPath}"
                            },
                            {
                                "ParameterKey": "DesiredCapacity",
                                "ParameterValue": "${env.DesiredCapacity}"
                            },
                            {
                                "ParameterKey": "GitLabConfScript",
                                "ParameterValue": "${env.GitLabConfScript}"
                            },
                            {
                                "ParameterKey": "GitLabPrepScript",
                                "ParameterValue": "${env.GitLabPrepScript}"
                            },
                            {
                                "ParameterKey": "GitLabRpmName",
                                "ParameterValue": "${env.GitLabRpmName}"
                            },
                            {
                                "ParameterKey": "GitLabRpmSourceUri",
                                "ParameterValue": "${env.GitLabRpmSourceUri}"
                            },
                            {
                                "ParameterKey": "GitRepoShareType",
                                "ParameterValue": "${env.GitRepoShareType}"
                            },
                            {
                                "ParameterKey": "GitRepoShareUri",
                                "ParameterValue": "${env.GitRepoShareUri}"
                            },
                            {
                                "ParameterKey": "InstanceRoleName",
                                "ParameterValue": "${env.InstanceRoleName}"
                            },
                            {
                                "ParameterKey": "InstanceRoleProfile",
                                "ParameterValue": "${env.InstanceRoleProfile}"
                            },
                            {
                                "ParameterKey": "InstanceType",
                                "ParameterValue": "${env.InstanceType}"
                            },
                            {
                                "ParameterKey": "KeyPairName",
                                "ParameterValue": "${env.KeyPairName}"
                            },
                            {
                                "ParameterKey": "LoadBalancerNames",
                                "ParameterValue": "${env.LoadBalancerNames}"
                            },
                            {
                                "ParameterKey": "MaxCapacity",
                                "ParameterValue": "${env.MaxCapacity}"
                            },
                            {
                                "ParameterKey": "MinCapacity",
                                "ParameterValue": "${env.MinCapacity}"
                            },
                            {
                                "ParameterKey": "NoPublicIp",
                                "ParameterValue": "${env.NoPublicIp}"
                            },
                            {
                                "ParameterKey": "NoReboot",
                                "ParameterValue": "${env.NoReboot}"
                            },
                            {
                                "ParameterKey": "NoUpdates",
                                "ParameterValue": "${env.NoUpdates}"
                            },
                            {
                                "ParameterKey": "ProvisionUser",
                                "ParameterValue": "${env.ProvisionUser}"
                            },
                            {
                                "ParameterKey": "ProxyName",
                                "ParameterValue": "${env.ProxyName}"
                            },
                            {
                                "ParameterKey": "PypiIndexUrl",
                                "ParameterValue": "${env.PypiIndexUrl}"
                            },
                            {
                                "ParameterKey": "RdsDbAdmin",
                                "ParameterValue": "${env.RdsDbAdmin}"
                            },
                            {
                                "ParameterKey": "RdsDbHost",
                                "ParameterValue": "${env.RdsDbHost}"
                            },
                            {
                                "ParameterKey": "RdsDbInstance",
                                "ParameterValue": "${env.RdsDbInstance}"
                            },
                            {
                                "ParameterKey": "RdsDbPasswd",
                                "ParameterValue": "${env.RdsDbPasswd}"
                            },
                            {
                                "ParameterKey": "RootVolumeSize",
                                "ParameterValue": "${env.RootVolumeSize}"
                            },
                            {
                                "ParameterKey": "ScaleDownSchedule",
                                "ParameterValue": "${env.ScaleDownSchedule}"
                            },
                            {
                                "ParameterKey": "ScaleUpSchedule",
                                "ParameterValue": "${env.ScaleUpSchedule}"
                            },
                            {
                                "ParameterKey": "SecurityGroupIds",
                                "ParameterValue": "${env.SecurityGroupIds}"
                            },
                            {
                                "ParameterKey": "SubnetIds",
                                "ParameterValue": "${env.SubnetIds}"
                            },
                            {
                                "ParameterKey": "TargetGroupArns",
                                "ParameterValue": "${env.TargetGroupArns}"
                            },
                            {
                                "ParameterKey": "ToggleCfnInitUpdate",
                                "ParameterValue": "${env.ToggleCfnInitUpdate}"
                            },
                            {
                                "ParameterKey": "ToggleNewInstances",
                                "ParameterValue": "${env.ToggleNewInstances}"
                            },
                            {
                                "ParameterKey": "WatchmakerAdminGroups",
                                "ParameterValue": "${env.WatchmakerAdminGroups}"
                            },
                            {
                                "ParameterKey": "WatchmakerAdminUsers",
                                "ParameterValue": "${env.WatchmakerAdminUsers}"
                            },
                            {
                                "ParameterKey": "WatchmakerAvailable",
                                "ParameterValue": "${env.WatchmakerAvailable}"
                            },
                            {
                                "ParameterKey": "WatchmakerComputerName",
                                "ParameterValue": "${env.WatchmakerComputerName}"
                            },
                            {
                                "ParameterKey": "WatchmakerConfig",
                                "ParameterValue": "${env.WatchmakerConfig}"
                            },
                            {
                                "ParameterKey": "WatchmakerEnvironment",
                                "ParameterValue": "${env.WatchmakerEnvironment}"
                            },
                            {
                                "ParameterKey": "WatchmakerOuPath",
                                "ParameterValue": "${env.WatchmakerOuPath}"
                            }
                        ]
                    /
                sh '''#!/bin/bash
                    printf "Validating param-file syntax... "
                    SYNTAXCHK=$( python -m json.tool gitlab-ec2-autoscale.parms.json > /dev/null 2>&1 )$?
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
                          --template-url "${Ec2TemplateUrl}" \
                          --parameters file://gitlab-ec2-autoscale.parms.json

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
