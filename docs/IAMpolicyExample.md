The following policy document will be fully-annotated at a later date. For now, the (`${}`-surrounded) variable-names and `Sid` tokens should give a general idea of the intent of a given configuration-stanzas and their contents:

~~~
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${GITLAB_BACKUP_BUCKET}",
                "arn:aws:s3:::${GITLAB_BACKUP_BUCKET}"
            ],
            "Effect": "Allow",
            "Sid": "BackupsAccess"
        },
        {
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::${PATH_TO_GITLAB_CONFIG_TEMPLATE}"
            ],
            "Effect": "Allow",
            "Sid": "ConfigAccess"
        },
        {
            "Action": [
                "cloudformation:DescribeStackResource",
                "cloudformation:SignalResource"
            ],
            "Resource": [
                "*"
            ],
            "Effect": "Allow",
            "Sid": "ASGsupport"
        },
        {
            "Action": [
                "cloudwatch:PutMetricData",
                "ds:CreateComputer",
                "ds:DescribeDirectories",
                "ec2:DescribeInstanceStatus",
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:GetParameters",
                "ssm:ListInstanceAssociations",
                "ssm:ListAssociations",
                "ssm:PutInventory",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation"
            ],
            "Resource": "*",
            "Effect": "Allow",
            "Sid": "MiscEnablement"
        },
        {
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucketMultipartUploads",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": "arn:aws:s3:::ssm-${AWS_ACCOUNT_ID}/*",
            "Effect": "Allow",
            "Sid": "AcctSsmBucket"
        },
        {
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::amazon-ssm-packages-*",
            "Effect": "Allow",
            "Sid": "GetSsmPkgs"
        }
    ]
}
~~~

See the various IAM action guides for translations of the `Action` and `Resource` statements.
