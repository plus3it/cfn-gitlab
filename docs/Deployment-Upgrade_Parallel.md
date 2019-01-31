# Deploying a Parallel, Upgraded GitLab Service

## Purpose

This document is intended to walk the automation-user through the process of deploying a parallel, upgraded deployment of an existing GitLab service using templates included in this project.

## Caveats

1. While the vendor documentation typicall indicates that it's possible to successfully do `X.Y.z` to any arbitrary `X.Y'.z'` , "real life" has proven this to not be wholly true. This gap between "vendor documents" and reality widens as the delta between `Y` and `Y'` increases. Therefore, the upgrade procedure (below) outlines an iterative method for upgrading from `X.Y.z` to a target `X.Y'.z'` configuration.  
1. The automated deployment logic still does not account for ensuring that the previous instance's `/etc/gitlab-secrets.json` file gets carried over to the replacement instance (_see [Issue](https://github.com/plus3it/cfn-gitlab/issues/30)_). If users are storing secrets in gitlab, it will be necessary for the automation-user to account for this gap.

## Dependencies

Because a parallel-deployment is essentially the same as for a wholly-new deployment, The following dependencies are the same as those for a [brand-new deployment](Deployment-Fresh.md#dependencies):

* Access to an AWS account
* An IAM user or role with (at least) enough permissions to:
    * Create EC2 network security groups
    * Create S3 buckets
    * Create classic Elastic LoadBalancers (ELBs)
    * Create IAM instance-roles and policies
    * Create RDS databases
    * Create EFS shares (Optional: only required if deploying to an EFS-supporting region and choosing to use EFS for persistent storage)
    * Create CloudWatch Logs log-groups (Optional: only required if deploying to a region that supports the use of the CloudWatch Logs service and wishing to take advantage of same)
    * Create new DNS records in Route53 (Optional: only required if deploying to a region that supports Route53 and use of Route53 DNS service is desired)
* Access to a computer that has a modern git client
* Access to a computer that has Python installed (and is pip-enabled)
* Access to a computer that has a modern web browser
* Access to a computer that has the AWS CLI installed or _installable_ (e.g., `pip install awscli`)
* Ability to configure the AWS CLI to use the previously-described IAM user or role
* Availability of a known-good, _recent_ backup of the to-be-replaced GitLab service.

## Automation Elements

See section-contents in [brand-new deployment](Deployment-Fresh.md#automation-elements)

### Cloud-Level Automation

See section-contents in [brand-new deployment](Deployment-Fresh.md#cloud-level-automation)

#### Directly-Used Templates

See section-contents in [brand-new deployment](Deployment-Fresh.md#directly-used-templates)
 
#### Indirectly-Used Templates

See section-contents in [brand-new deployment](Deployment-Fresh.md#indirectly-used-templates)

### Instance-Level Automation

See section-contents in [brand-new deployment](Deployment-Fresh.md#instance-level-automation)

## Deployment/Workflow

The "upgrade" process follows a generic workflow of:

1. Deploy new "infrastructure" stack-set &mdash; See _Wholly-New GitLab Service_'s [Cloud Provisioning](Deployment-Fresh.md#cloud-provisioning) section.
1. Duplicate backup-data from prior GitLab service's backup-bucket to the new backup-bucket (created in first step) &mdash; see method-description ([below](Deployment-Upgrade_Parallel.md#bucket-to-bucket-data-copy)). To save time, this step may be performed concurrent to the deployment of the new EC2 (next step).
1. Deploy new EC2 stack &mdash; See _Wholly-New GitLab Service_'s [Instance Provisioning](Deployment-Fresh.md#instance-provisioning) section. Ensure to use the "standalone" deployment option at this phase of the parallel upgrade. *Ensure that GitLab version selected for install is the same as the current, user-facing version.*
1. Deregister new EC2 from new ELB
1. Login to new EC2 instance and esclate privileges to root (`sudo -i`)
1. Ensure GitLab's backups directory exists (check the value of `backup_path` in the `/etc/gitlab/gitlab.rb` file) &mdash; create as necessary and ensure directory is readable by the GitLab service user (typically `git`).
1. Copy-down the previously-duplicated backup to the previously-determined GitLab backups directory
1. Set the ownership of the downloaded backup file to match the GitLab service-user (typically `chown git:git /FULLY/QUALIFIED/FILE/PATH`)
1. Follow the vendor-documented [restore procedures](https://docs.gitlab.com/ce/raketasks/backup_restore.html#restore-for-omnibus-gitlab-installations). Note: restoration of the `gitlab-secrets.json` file is only _strictly_-necessary if GitLab users have been storing secrets in their GitLab projects &mdash; be paranoid and assume that they have been.
1. Determine the next-closest GitLab X.Y release to the instance's currently-installed GitLab (e.g., if deployed on 11.6.x, see if 11.7. is available)
1. Up date to the highest available version within the next point-release (`yum install gitlab-ce-X.Y.\*`)
1. Repeat previous two steps until desired version is reached (if not "latest")
1. Execute a CloudFormation stack-update, only updating the value of the `GitLabRpmName` parameter to match the migrated-to version.

Optional:

14. Re-deploy EC2-stack:
    * If service will be a standalone instance, used the "Stack Update" option and change the deployed-to subnet (update the `SubnetId` parameter's value)
    * If desired end-state is AutoScale managed, deploy a new AutoScale stack-template &mdash; populating with the appropriate values borroed from the existing standalone template (see `gitlab-secrets.json` caveat about suitability of this option)

## Bucket-to-Bucket Data-Copy

It will be necessary to execute a third-party copy of data from the source bucket to the destination bucket. This is most-easily done using the AWS CLI &mdash; it is assumed that the CLI has permissions to both the source and destination buckets. (see notes in the dependencies section about "Access to a computer...").

1. Determine the name of the source bucket and path to most-recent backup file
2. Determine the name of the destination bucket
3. Execute a bucket to bucket copy operation similar to: 
    ~~~~
    aws s3 cp s3://<SOURCE_BUCKET>/Backups/<LATEST_BACKUP_FILE>.tar s3://<DESTINATION_BUCKET>/Restores/
    ~~~~
