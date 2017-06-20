#!/bin/sh
#
# Script to configure the GitLab installation
#
#################################################################
PROGNAME=$(basename "${0}")
GLCONFIG="/etc/gitlab/gitlab.rb"
RUNDATE=$(date "+%Y%m%d%H%M")
GITLAB_EXTERNURL="${GITLAB_EXTERNURL:-UNDEF}"
GITLAB_DATABASE="${GITLAB_DATABASE:-UNDEF}"
GITLAB_DBUSER="${GITLAB_DBUSER:-UNDEF}"
GITLAB_PASSWORD="${GITLAB_PASSWORD:-UNDEF}"
GITLAB_DBHOST="${GITLAB_DBHOST:-UNDEF}"
GITLAB_AD_HOST="${GITLAB_AD_HOST:-UNDEF}"
GITLAB_AD_PORT="${GITLAB_AD_PORT:-UNDEF}"
GITLAB_AD_BINDCRYPT="${GITLAB_AD_BINDCRYPT:-UNDEF}"
GITLAB_AD_BINDUSER="${GITLAB_AD_BINDUSER:-UNDEF}"
GITLAB_AD_BINDPASS="${GITLAB_AD_BINDPASS:-UNDEF}"
GITLAB_AD_SRCHBASE="${GITLAB_AD_SRCHBASE:-UNDEF}"
SHAREURI=${GITLAB_SHARE_URI:-UNDEF}
SHARETYPE=${GITLAB_SHARE_TYPE:-UNDEV}
SMTP_FQDN="${GITLAB_SMTP_RELAY:-UNDEF}"
SMTP_PORT="${GITLAB_SMTP_PORT:-UNDEF}"
SMTP_USER="${GITLAB_SMTP_USER:-UNDEF}"
SMTP_PASS="${GITLAB_SMTP_PASS:-UNDEF}"
SMTP_FROMDOM="${GITLAB_SMTP_FROM_DOM:-UNDEF}"
SMTP_FROMUSR="${GITLAB_SMTP_FROM_USER:-UNDEF}"
SMTP_RPLYUSR="noreply@${SMTP_FROMDOM}"

#
# Log errors and exit
#####
function err_exit {
   echo "${1}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${1}"
   exit 1
}


#
# Ensure we've passed an necessary ENVs
#####
if [[ ${GITLAB_EXTERNURL} = UNDEF ]] ||
   [[ ${GITLAB_DATABASE} = UNDEF ]] ||
   [[ ${GITLAB_DBUSER} = UNDEF ]] ||
   [[ ${GITLAB_PASSWORD} = UNDEF ]] ||
   [[ ${GITLAB_DBHOST} = UNDEF ]] ||
   [[ ${GITLAB_AD_HOST} = UNDEF ]] ||
   [[ ${GITLAB_AD_PORT} = UNDEF ]] ||
   [[ ${GITLAB_AD_BINDCRYPT} = UNDEF ]] ||
   [[ ${GITLAB_AD_BINDUSER} = UNDEF ]] ||
   [[ ${GITLAB_AD_BINDPASS} = UNDEF ]] ||
   [[ ${GITLAB_AD_SRCHBASE} = UNDEF ]]
then
   err_exit "Required env var(s) not defined. Aborting!"
fi


#
# Preserve the existing gitlab.rb file
#####
printf "Preserving %s as %s.bak-%s... " ${GLCONFIG} ${GLCONFIG} "${RUNDATE}"
mv ${GLCONFIG} "${GLCONFIG}.bak-${RUNDATE}" || \
      err_exit "Failed to preserve ${GLCONFIG}: aborting"
echo "Success!" 

#
# Localize the GitLab installation
#####
printf "Localizing gitlab config files... "

install -b -m 0600 /dev/null ${GLCONFIG} || \
   err_exit "Failed to create new/null config file"

chcon "--reference=${GLCONFIG}.bak-${RUNDATE}" ${GLCONFIG} || \
   err_exit "Failed to set SELinx label on new/null config file"

cat << EOF > ${GLCONFIG}
external_url 'https://${GITLAB_EXTERNURL}'
nginx['listen_addresses'] = ["0.0.0.0", "[::]"]
nginx['listen_port'] = 80
nginx['listen_https'] = false
postgresql['enable'] = false
gitlab_rails['db_adapter'] = "postgresql"
gitlab_rails['db_encoding'] = "unicode"
gitlab_rails['db_database'] = "${GITLAB_DATABASE}"
gitlab_rails['db_username'] = "${GITLAB_DBUSER}"
gitlab_rails['db_password'] = "${GITLAB_PASSWORD}"
gitlab_rails['db_host'] = "${GITLAB_DBHOST}"
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "${SMTP_FQDN}"
gitlab_rails['smtp_port'] = "${SMTP_PORT}"
gitlab_rails['smtp_user_name'] = "${SMTP_USER}"
gitlab_rails['smtp_password'] = "${SMTP_PASS}"
gitlab_rails['smtp_domain'] = "${SMTP_FROMDOM}"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['gitlab_email_from'] = "${SMTP_FROMUSR}"
gitlab_rails['gitlab_email_reply_to'] = "${SMTP_RPLYUSR}"
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-EOS
main:
  label: 'ActiveDirectory'
  host: '${GITLAB_AD_HOST}'
  port: ${GITLAB_AD_PORT}
  method: '${GITLAB_AD_BINDCRYPT}'
  bind_dn: '${GITLAB_AD_BINDUSER}'
  password: '${GITLAB_AD_BINDPASS}'
  timeout: 10
  active_directory: true
  uid: 'sAMAccountName'
  allow_username_or_email_login: false
  block_auto_created_users: false
  base: '${GITLAB_AD_SRCHBASE}'
  uid: 'sAMAccountName'
EOS
EOF

# shellcheck disable=SC2181
if [[ $? -eq 0 ]]
then
   echo "Success!"
else
   err_exit "Failed to localize GitLab installation. Aborting!"
fi

#
# Ensure that share-persisted repositories are present
#####
echo "Configure NAS-based persisted data..." 
case ${SHARETYPE} in
   UNDEF)
      echo "No network share declared for persisting git repository data"
      ;;
   nfs)
      echo "Adding NFS-hosted, persisted git repository data to fstab"
      (
       printf "%s\t/var/opt/gitlab/git-data\tnfs4\trw,relatime,vers=4.1," "${SHAREURI}" ;
       printf "rsize=1048576,wsize=1048576,namlen=255,hard,";
       printf "proto=tcp,timeo=600,retrans=2\t0 0\n"
      ) >> /etc/fstab || err_exit "Failed to add NFS volume to fstab"
      mount /var/opt/gitlab/git-data || err_exit "Failed to mount GitLab repository dir"
      ;;
   glusterfs)
      echo "Adding Gluster-hosted, persisted git repository data to fstab"
      (
       printf "%s\t/var/opt/gitlab/git-data\tglusterfs\t" "${SHAREURI}" ;
       printf "defaults\t0 0\n"
      ) >> /etc/fstab || err_exit "Failed to add Gluster volume to fstab"
      mount /var/opt/gitlab/git-data || err_exit "Failed to mount GitLab repository dir"
      ;;
esac

#
# Configure the GitLab pieces-parts
#####
printf "###\n# Localizing GitLab service elements...\n###\n"
export CHEF_FIPS=""
gitlab-ctl reconfigure || \
    err_exit "Localization did not succeed. Aborting."
echo "Localization successful."


#
# Restart service to get new config bits
#####
printf "###\n# Restarting GitLab to finalize settings...\n###\n"
gitlab-ctl restart || \
      err_exit "Restart did not succeed. Check the logs."
echo "Restart successful."
