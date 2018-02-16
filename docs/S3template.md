### S3 Backup Bucket

This template-set makes the assumption that the GitLab service will back itself up daily. Further, the assumption is that the backups will either go directly to a private S3 bucket or be "swept" to such a bucket. The [make_gitlab_S3-main_bucket.tmplt.json](/Templates/make_gitlab_S3-main_bucket.tmplt.json) template sets up the backup destination-bucket in S3 (the EC2 template takes care of scheduling the backup actions; the IAM template takes care of access permissions between the instance and the bucket).
