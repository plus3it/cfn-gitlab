### EFS-Persisted Storage

GitLab primarily stores configuration data in its (externalize) database. Actual project-data &mdash; the stuff moved via `git push`, `git clone` and the like &mdash; is stored on the GitLab server's local filesystems. In order to foster quicker recoverability in the event of the loss of an EC2 instance, this data is hosted on an [EFS](https://aws.amazon.com/efs/) share. The [make_gitlab_EFS.tmplt.json](/Templates/make_gitlab_EFS.tmplt.json) template creates the requisite persistent file-server service while the EC2-related templates configure GitLab's accessing/use of that file-server.

Currently, the only content stored on the EFS share is the `${GIT_HOME}/git-data` directory (typically `/var/opt/gitlab/git-data`). By default, gitlab stores file uploads (user- and project-avatars, file-attachments, etc.) in the `/var/opt/gitlab/gitlab-rails/uploads` directory (in versions prior to 9.5, a different path was used). This directory is moved onto the EFS share, as well.

In the case of a rebuild-event, EFS allows the replacement instance to come up with all of its contents in the expected locations.
