# dotc-gitlab

This project was undertaken to automate the deployment of the git repository service, [GitLab](https://gitlab.com), onto Enterprise Linux 7 (Red Hat, CentOS, etc.) hosts. Currently, this, project's automation focuses on using AWS CFn templates to deploy GitLab onto EC2-hosted instances.

CFn deployment takes the form of parent/driver stacks and child stacks. Each of the child stacks is oriented around managing one tier of AWS resources. The current stack-set consists of CFn templates to deploy:

- EC2 instance to host the application
- EFS storage to provide persistent repository storage across EC2 instantiations
- ELB to provide public-facing access to EC2 instances proisioned on private subnets
- GlusterFS cluster to act as an alternative to EFS in AWS regions that lack the EFS service
- IAM to manage access permissions from EC2 resources to S3 resources
- RDS to host persistent configuration information
- S3 to host backups of the GitLab-hosted data
- Security-groups to manage network-based access to and between linked AWS resources

Each of the above child stacks is designed to be pluggable. Parent templates are provided for environments that easily support monolithic deployments or the child-templates may be individually run (or nested under locally-authored or community-contributed driver templates) to support environments with delegated AWS security roles.

The EC2 template links out to two support scripts as well as a STIG-hardening utility, [watchmaker](https://github.com/plus3it/watchmaker). The first script makes light configuration tweaks necessary to install and run GitLab (e.g., `firewalld` exceptions, GitLab `yum` setup, etc.). Watchmaker hardens the EC2 instance to comply with [DISA STIGs](https://iase.disa.mil/stigs/os/unix-linux/Pages/index.aspx) to the greatest degree possible. The second script configures GitLab for run-time operations for both initial and and re-deployment standup.

Administrators can deploy the latest version of GitLab or specific versions targeted to the major, major.minor or major.minor.point release. Release-targeting is designed to support specific deployment-environments' needs with respect to controlled-release methodologies. It is primarily expected that administrators will target major releases or major.minor releases. Targeting dot-releases are primarily for pre-upgrade testing and to support upgrades from one major-release to another (via parallel standup and migration).

The templates and scripts will enable GitLab administrators to more-easily use a "redeploy to upgrade" model - whether upgrading the underlying operating system or the GitLab software itself. 
