### Standalone Instance(s)

The [make_gitlab_EC2-instance.tmplt.json](/Templates/make_gitlab_EC2-instance.tmplt.json) template &mdash; along with deployment-automation helper-scripts &mdash; launches a standalone EC2 instance. This instance will contain a fully-configured GitLab service. The service will have appropriate connector-definitions for:

* Working with an external, PGSQL-based configuration-database
* Working with an authenticated SMTP-relay service (like [SES](https://aws.amazon.com/ses/)).
* Working behind an SSL-terminating, Internet-facing HTTP proxy
* Allow SSH-based git-transactions

Additionally &mdash; and depending on the user-provided contents of the templated [`gitlab.rb`](gitlab.rb.tmplt.md) file &mdash; functionality like Active Directory integration, backups directly to S3, etc. may all also be automatically configured at launch
