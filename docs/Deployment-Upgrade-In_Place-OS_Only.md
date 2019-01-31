# Upgrading the GitLab-Hosting Instance

## Purpose

This document is intended to walk the automation-user through the process of upgrading the instance-OS used to host the GitLab service.

## CAVEATS

This procedure is not intended to be used to update the installed GitLab version. While performing these procedures _can_ be used to update the GitLab version, there are risks associated with doing so. Specifically, the greater the version-to-version delta when updating, the likelier this procedure is to result in a broken GitLab service.

This document is provided primarily as a generic guideline for performing an upgrade to the GitLab service's hosting EC2 resource. Project-contents' users are urged to research and codify their own, site-local upgrade procedures.

The procedure (below) will launch a new instance and attempt to configure it while the existing instance continues in its current state. Because the newly-launched instance will have read-write access to the service's configuration database (RDS instance) and persistent filesystem, it is recommended to stop the instance to be replaced prior to hitting the "Update" button.

## Assumptions/Dependencies

* The automation user has a verified backup of the running configuration (or the ability to do so immediately prior to attempting the upgrade)
* The GitLab-hosting EC2 instance was deployed using the `make_gitlab_EC2-instance.tmplt.json` template
* The "GitLabRpmName" parameter-value was specified as a version-pinned value in the previous deployment
* Automation user has sufficient privileges to execute an instance-replacing CloudFormation stack-update action

## Workflow Description

While this task can, notionally, be done through both the CloudFormation web UI and the AWS CLI, only procedures for use with the web UI have been validated.

### Update Via Web UI

1. Login to the CloudFormation web console
1. Locate the previously-deployed stack
1. Select the  previously-deployed stack
1. Select the "Update Stack" option from the `Action` button/menu
1. Select "Use current template" from the "Select Template" page.
1. Change the value of the "AmiId" parameter to the AMI you wish to update to. Other parameters &mdash; but for the `"GitLabRpmName"` &mdash; may be updated. However doing so is out of scope for this document.
1. Click on the "Next" button to get to the "Options" page
1. Click on the "Next" button to get to the "Review" page
1. Validate all values are as desired. Note that the instance should be shown for replacement in the "Preview your changes" section.
1. Click on the "Update" button to commence the process.
1. Track the update process
    * If the update succeeds, the previous instance will be terminated
    * If the update fails, the new instance will be terminated. If &mdash; per the caveats section &mdash; the previous instance wa stopped, it will need to be restarted for services to resume.
1. Login to the GitLab service and verify that previous functionality is present on the replacement node.

### Update Via AWS CLI

**TBD**
