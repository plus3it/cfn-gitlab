#!/bin/sh
#
# Script to configure the GitLab installation
#
#################################################################
PROGNAME=$(basename "${0}")
GLCONFIG="/etc/gitlab/gitlab.rb"
RUNDATE=$(date "+%Y%m%d%H%M")
GITLAB_EXTERNURL=${GITLAB_EXTERNURL:-UNDEF}
GITLAB_DATABASE=${GITLAB_DATABASE:-UNDEF}
GITLAB_DBUSER=${GITLAB_DBUSER:-UNDEF}
GITLAB_PASSWORD=${GITLAB_PASSWORD:-UNDEF}
GITLAB_DBHOST=${GITLAB_DBHOST:-UNDEF}
GITLAB_AD_HOST=${GITLAB_AD_HOST:-UNDEF}
GITLAB_AD_PORT=${GITLAB_AD_PORT:-UNDEF}
GITLAB_AD_BINDCRYPT=${GITLAB_AD_BINDCRYPT:-UNDEF}
GITLAB_AD_BINDUSER=${GITLAB_AD_BINDUSER:-UNDEF}
GITLAB_AD_BINDPASS=${GITLAB_AD_BINDPASS:-UNDEF}
GITLAB_AD_SRCHBASE=${GITLAB_AD_SRCHBASE:-UNDEF}


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
# Configure the GitLab pieces-parts
#####
printf "###\n# Localizing GitLab service elements...\n###\n"
export CHEF_FIPS=""
gitlab-ctl reconfigure || \
    err_exit "Localization did not succeed. Aborting."
echo "Localization successful."

printf "###\n# Restarting GitLab to finalize settings...\n###\n"
gitlab-ctl restart || \
      err_exit "Restart did not succeed. Check the logs."
echo "Restart successful."
