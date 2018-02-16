### IAM Role

The [make_gitlab_IAM-role.tmplt.json](/Templates/make_gitlab_IAM-role.tmplt.json) file sets up an IAM role. This role is attached to the GitLab-hosting EC2 instances. This role:
* Grants access from the EC2 instances to an associated S3 "backups" bucket.
* Allows deployment of EC2 instances via the AutoScaling service within a least-privileges deployment-environment.
* Grants access to a templated [`gitlab.rb`](/docs/gitlab.rb.tmplt.md) file.
* the IAM role includes permissions sufficient to make use of AWS's [Systems Manager](https://aws.amazon.com/systems-manager/) service (as a logical future capability).

An example of the resultant IAM policy can be viewed [here](/docs/IAMpolicyExample.md)
