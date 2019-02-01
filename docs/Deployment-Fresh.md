# Deploying a Wholly-New GitLab Service

## Purpose

This document is intended to walk the automation-user through the process of deploying a brand-new GitLab service from the templates included in this project.

## Dependencies

In order to use these templates, the following things will be necessary:

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

## Automation Elements

The automation in this project works at two levels: cloud-level (AWS components) and instance-level

### Cloud-Level Automation

This project includes a number of CloudFormation templates. These templates are used to deploy AWS resources.
The templates' functionalities are described in greater detail elsewhere in this documentation-directory.

#### Directly-Used Templates

The following templates are categorized as "directly-used" as they are the templates that automation-users will directly-launch using either the `cloudformation` CLI or web UI:

* `make_gitlab_EC2-instance.tmplt.json`: Used to launch and configure the EC2 that will host the GitLab service
* `make_gitlab_parent-infra-EFS.tmplt.json`: Used to create and configure all of the native AWS elements that support the GitLab-hosting EC2 instance

 
#### Indirectly-Used Templates

The following are categorized as "indirectly-used" because they are launched as children of the `make_gitlab_parent-infra-EFS.tmplt.json` template described in the previous section.

* `make_gitlab_SGs.tmplt.json`: Used to create the AWS VPC's network security-groups.
* `make_gitlab_IAM-role.tmplt.json`: Used to create an instance-role to apply to the GitLab-hosting EC2. Allows the EC2 to access its backup-bucket and other (optional) AWS services.
* `make_gitlab_ELBv1.tmplt.json`: Used to create the SSL-terminating web-proxy that sits between the GitLab-hosting EC2 and the GitLab service's users.
* `make_gitlab_EFS.tmplt.json`: Used to create the persistent, infinitely-scalable storage location to host GitLab repositories, wikis and other data.
* `make_gitlab_RDS-pgsql.tmplt.json`:  Used to create the PGSQL database that hosts the GitLab service's project metadata and persistent configuration data.

### Instance-Level Automation

In addition to cloud-layer automation, there is instance-layer automation. This automation is fetched and invoked by way of `cfn-init` components within the `make_gitlab_EC2-instance.tmplt.json` CloudFormation template.

* `gitlab_instprep.sh`: This script does basic preparation of a generic, Enterprise Linux 7 instance &mdash; things like OS-hardening, adding exceptions to the host-based firewall and taking care of (initial) RPM dependencies.
* `gitlab_config.sh`: This script takes care of fetching, installing and configuring the GitLab binaries and sending the final `SUCCESS` (or `FAILURE`) signal to CloudFormation (so that the automation-user knows that the deployment has completed as expected).

The above _could_ have been built into a single script. However, it was anticipated that some users of this automation-set may prefer to substitute their own secondary-provisioning services &mdash; Ansible, SaltStack, Puppet, etc. &mdash; for these types of tasks. Automation users with such a preference can reference an appropriate substitute-script in their invocation of the `make_gitlab_EC2-instance.tmplt.json` template.

## Deployment/Workflow

As alluded to above, automation takes care of cloud- and instance-level provisioning tasks. These are taken care of by a mix of CloudFormation templates and instance-level scripts. This automation takes care of, in to main sequences:

* Provisioning cloud-level resources
* Provisioning instance-level resources

Further, cloud-level resources will be configured prior-to &mdash; and in service of &mdash; the instance-level resource-provisioning.

It will be necessary to upload all of the template files and instance-level automation-scripts into an S3 bucket. A private bucket can be used, however, it will be necessary to make the instance-level automation-scripts anonymously-accessible. The templates only need be accessible from the CloudFormation subsystem (a default S3 bucket created within the same account as CloudFormation actions are executed should satisfy this need).

### Cloud Provisioning

As noted above, the cloud-level tasks consist of directly- and indirectly-deployed CloudFormation templates. This design was chosen in recognition that some automation-users' organizations may break up permissions in a way that doesn't allow a user to execute all of the sub-tasks within a single IAM user's &mdash; or role's &mdash; scope.

Each of the templates noted as indirectly-deployed _can_ be directly deployed. However, this is not generally recommended as it increases the complexity of taskings required of the automation-user. Such usage is out of the scope of this document.

Note: If using the indirectly-deployed templates directly, omit use of the `make_gitlab_parent-infra-EFS.tmplt.json` template.

The first step is to launch the `make_gitlab_parent-infra-EFS.tmplt.json` template. This can be done through either the web UI or the AWS CLI utility.

* Use by way of the web UI should be generally self-explanatory to those familiar with launching templates via that method.
* When using the AWS CLI, it is recommended to pass all template parameters by way of a parameters-file. The parameters-file must contain a parameter-definition for any parameter that does not have a default value or for which an override is desired. See the [example file](infrastructure.parameters).

After the parent template has been launched, monitor its progress:
* Correct any errors encountered &mdash; usually bad parameters or permission errors on dependencies &mdash; and re-launch as necessary.
* After Stack successfully completes, move on to [Instance Provisioning](#instance-provisioning)

### Instance Provisioning

Launch the `make_gitlab_EC2-instance.tmplt.json` template. As with the `make_gitlab_parent-infra-EFS.tmplt.json` template, launching the `make_gitlab_EC2-instance.tmplt.json` template can be done through either the web UI or the AWS CLI utility. Similarly, use of a parameters-file is recommended.  See the [example file](ec2.parameters).

### Post-Launch Tasks

A _brand new_ gitlab install will require a couple details be taken care of. These tasks take place at AWS, EC2's OS and Web/Application layers:

1. (AWS layer) De-register the EC2 instance from the ELB
1. (EC2 host) Login to the EC2 instance
1. (EC2 host) Esclate privileges (`sudo -i`)
1. (EC2 host) Edit the `/etc/gitlab/gitlab.rb` file:
    * If set to the ELB's FQDN, set the `external_url` value to `http://<EC2>.<INTERNAL>.<FQDN>`
    * Update gitlab's configuration (`gitlab-ctl reconfigure && gitlab-ctl restart`)
1. (RDSH host) Use a web browser to visit `http://<EC2>.<INTERNAL>.<FQDN>`
1. (RDSH host) Follow the on-screen steps for setting the new instance's admin user credentials
1. (RDSH host) Validate new credentials by logging in as the `root` user using the new credentials
1. (EC2 host) Edit the `/etc/gitlab/gitlab.rb` file:
    * Update the `external_url` value to either `https://<ELB>.<FQDN>` or `https://<R53_ELB_ALIAS>.<FQDN>`
    * Update gitlab's configuration (`gitlab-ctl reconfigure && gitlab-ctl restart`)
1. (AWS layer) Re-register the EC2 instance to the ELB
1. (Arbitrary browser-equipped host) Navigate to the most-recently set value for `external_url`
1. (Arbitrary browser-equipped host) establish secondary administrators:
    * Local-only Authentication configured:
        1. Login with (local) `root` user
        1. Go to user-administration tool
        1. Define service-internal users; ensure to set the administrator attribute on them
        1. Verify that each new secondary-administrator has received their initial-login email and was able to login
    * Centralized Authtication configured:
        1. If built-from `gitlab.rb.tmplt` file includes centralized authentication, login with a username from that namespace that should be set as a service administrator
        1. Log out
        1. Login with (local) `root` user
        1. Go to user administration panel
        1. Set the target (centralized-authentication) user as an administrator
        1. Log out
        1. Login with the (now admin-enabled) username from the centralized-authentication namespace
        1. Verify access to administrator interfaces
        1. Repeat sequence for enabling any further centralized-authentication namespace users as administrators
1. (AWS layer) Re-deploy the GitLab-hosting EC2 (via "Stack Update") to verify configuration data is properly persisted
1. (Arbitrary browser-equipped host) Login as an administrator and commence remaining GitLab configurtion tasks (establish other users, groups, etc.)

**Notes**:
When new local users are created, GitLab defaults to attempting to email them an account setup link. If network topology does not allow for this:
* it will be necessary to set/update new users' passwords via the GitLab CLI console (outside the scope of this document).
* Similarly, normal address-verification will not work: it will be desirable/necessary to affect this verification via the GitLab CLI console
