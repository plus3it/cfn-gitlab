### Auto-Scaling GitLab Instance(s)

The [make_gitlab_EC2-autoscale.tmplt.json](/Templates/make_gitlab_EC2-autoscale.tmplt.json) template &mdash; along with deployment-automation helper-scripts &mdash; creates an EC2 Launch Configuration tied to an AutoScaling Group. This configuration is intended primarily to improve the availability of the GitLab service. The AutoScaling group keeps the number of active nodes at "1": in the event of a failure detected in the currently-active node, the AutoScaling group will launch a replacement node. When the replacement node reaches an acceptable state, the original node is terminated.

The Launch Configuration will create EC2 instances that contain a fully-configured GitLab service. The service will have appropriate connector-definitions for:

* Working with an external, PGSQL-based configuration-database
* Working with an authenticated SMTP-relay service (like [SES](https://aws.amazon.com/ses/)).
* Working behind an SSL-terminating, Internet-facing HTTP proxy
* Allow SSH-based git-transactions

Additionally &mdash; and depending on the user-provided contents of the templated [`gitlab.rb`](gitlab.rb.tmplt.md) file &mdash; functionality like Active Directory integration, backups directly to S3, etc. may all also be automatically configured at launch
