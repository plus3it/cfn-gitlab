### RDS Externalized Database

GitLab uses a database to host configuration, tracking and other, non-BLOB data.GitLab support a couple of different database back-ends. This stack-set makes use of PGSQL. The [make_gitlab_RDS.tmplt.json](/Templates/make_gitlab_RDS.tmplt.json) template deploys a small, multi-AZ database to provide for GitLab's database needs. Being externalized, loss of an EC2 instance does not result in the loss of database contents. Leveraging AWS's [RDS](https://aws.amazon.com/rds/) also means that backups and version upgrades are handled by the CSP. Using a multi-AZ design means that, even if an AZ becomes unavailable, the GitLab-hosting EC2 can still contact its database.

Note: Whether the resultant RDS configuration is multi-AZ or not depends on the options selected by the template-user. Selecting the single-AZ option lowers accumulated AWS service charges but does so at the expense of design-resiliency.
