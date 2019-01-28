The following is an exemplar template. A greater or fewer number of GitLab config options (see the [annotated source](https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template) for available configuration options) can be pre-specified (hard-coded) into this file. Any element in the below surrounded by doubled underbars (`__`) is a token that is manipulated by this project's application-coniguration scripts. Any element in the below surrounded by variable-signifiers (`${}`) is something that would need to be hard-coded into the template:

~~~
external_url 'https://__PROXY_URL__'
nginx['listen_addresses'] = ["0.0.0.0", "[::]"]
nginx['listen_port'] = 80
nginx['listen_https'] = false
postgresql['enable'] = false
gitlab_rails['db_adapter'] = "postgresql"
gitlab_rails['db_encoding'] = "unicode"
gitlab_rails['db_database'] = "__RDS_DB_INSTANCE__"
gitlab_rails['db_username'] = "__RDS_DB_ADMIN__"
gitlab_rails['db_password'] = "__RDS_DB_PASSWD__"
gitlab_rails['db_host'] = "__RDS_DB_FQDN__"
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "${SMTP_RELAY_FQDN}"
gitlab_rails['smtp_port'] = "587"
gitlab_rails['smtp_user_name'] = "${SMTP_USER}"
gitlab_rails['smtp_password'] = "${SMTP_USER_PASSWORD}"
gitlab_rails['smtp_domain'] = "${SMTP_MAIL_DOMAIN}"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['gitlab_email_from'] = "${APPARENT_FROM_ADDR}"
gitlab_rails['gitlab_email_reply_to'] = "${REPLY_TO_ADDR}"
gitlab_rails['gitlab_host'] = '__PROXY_URL__'
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-EOS
main:
  label: 'ActiveDirectory'
  host: '${DIRECTORY_HOSTNAME}'
  port: 389
  method: 'plain'
  bind_dn: '${LDAP_BIND_DN}'
  password: '${LDAP_BIND_PASSWORD}'
  timeout: 10
  active_directory: true
  uid: 'sAMAccountName'
  allow_username_or_email_login: false
  block_auto_created_users: false
  base: '${LDAP_SEARCH_BASE}'
  uid: 'sAMAccountName'
EOS
gitlab_rails['backup_upload_connection'] = {
'provider' => 'AWS',
'region' => '__REGION__',
'use_iam_profile' => 'true'
}
gitlab_rails['backup_upload_remote_directory'] = '__BUCKET__'
gitlab_rails['backup_keep_time'] = '1296000'
gitlab_rails['backup_path'] = '/var/opt/gitlab/git-data/backups'
~~~

The following table lists the template-variables that the CFn scripts will automatically populate with stack-appropriate values:

|Templated Value|Explanation|
|:--------------|:----------|
|__RDS_DB_INSTANCE__|Database instance-name that GitLab will use|
|__RDS_DB_ADMIN__|Database instance's admin account-name|
|__RDS_DB_PASSWD__|Database admin's account-name|
|__RDS_DB_FQDN__|FQDN of the external DB GitLab will use|
|__PROXY_URL__|FQDN that GitLab answer to|
|__REGION__|AWS region hosting the S3 backup bucket|
|__BUCKET__|Name of the backup-bucket|

The following table lists (some of) the GitLab configuration parameters values that the stack-user can pre-populate into the template file:

|Variable Name |Explanation|
|:-------------|:-------------|
|`${SMTP_RELAY_FQDN}`|FQDN of the host that will be used for SMTP relay-service (typical the region-appropriate [SES](https://aws.amazon.com/ses/) host)|
|`${SMTP_USER}`|Userid used for authenticated SMTP-relaying|
|`${SMTP_USER_PASSWORD}`|Password for the authenticated relay-user|
|`${SMTP_MAIL_DOMAIN}`|DNS domain of the service|
|`${APPARENT_FROM_ADDR}`|"From" address in service-generated notifications|
|`${REPLY_TO_ADDR}`|Email address notice-recipients should reply to|
|`${DIRECTORY_HOSTNAME}`|FQDN of the authentication-directory service|
|`${LDAP_BIND_DN}`|LDAP userid to proxy auth-requests through ([LDAP DN](https://www.ldap.com/ldap-dns-and-rdns) or [UPN-style](https://msdn.microsoft.com/en-us/library/windows/desktop/ms721629(v=vs.85).aspx#_security_user_principal_name_gly) formats supported)|
|`${LDAP_BIND_PASSWORD}`|Password for auth-request proxy-user|
|`${LDAP_SEARCH_BASE}`|Where in the directory-hierarchy to root authentication searches|

Note: The CFn templates expect that the templated `gitlab.rb` file will be hosted in an S3 bucket. The stack will give the launched instance(s) appropriate rights to access that file via an `s3 cp` action.
