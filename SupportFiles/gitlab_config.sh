#!/bin/bash
# shellcheck disable=SC2015
# Script to configure the GitLab installation
#
#################################################################
PROGNAME=$(basename "${0}")
export PATH=${PATH}:/opt/aws/bin
# Read in template envs we might want to use
while read -r GLENV
do
   # shellcheck disable=SC2163
   export "${GLENV}"
done < /etc/cfn/GitLab.envs
GLCONFIG="/etc/gitlab/gitlab.rb"
RUNDATE=$(date "+%Y%m%d%H%M")
GITLAB_BACKUP_BUCKET="${GITLAB_BACKUP_BUCKET}"
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
GITLAB_REGION="${GITLAB_AWS_REGION:-UNDEF}"
GITLAB_RPM_NAME="${GITLAB_RPM_NAME:-UNDEF}"
UPLOADDIR="/var/opt/gitlab/git-data/uploads"
UPLOADLNK="/var/opt/gitlab/gitlab-rails/uploads"

#
# Log errors and exit
#####
function err_exit {
   logger -s -t "${PROGNAME}" -p kern.crit "${1}"
   /etc/cfn/scripts/glprep-signal.sh 1
   exit 1
}

#
# Ensure we've passed an necessary ENVs
#####
if [[ ${GITLAB_EXTERNURL} = UNDEF ]] ||
   [[ ${GITLAB_PASSWORD} = UNDEF ]] ||
   [[ ${GITLAB_DBHOST} = UNDEF ]]
then
   err_exit "Required env var(s) not defined. Aborting!"
fi

# Dear SEL: relax for a minute!
setenforce 0 || \
   err_exit "Failed to temp-disable SELinux"
echo "Temp-disabled SELinux"

# Install gitlab
if [[ $( rpm --quiet -q "${GITLAB_RPM_NAME}" )$? -eq 0 ]]
then
   echo "${GITLAB_RPM_NAME} installed. Skipping further install attempts."
else
   printf "Attempting to install %s... " "${GITLAB_RPM_NAME}"
   yum install -y "${GITLAB_RPM_NAME}" && echo "Success" || \
   err_exit "Failed installing ${GITLAB_RPM_NAME}"
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

sed '{
  s/__PROXY_URL__/'"${GITLAB_EXTERNURL}"'/
  s/__RDS_DB_PASSWD__/'"${GITLAB_PASSWORD}"'/
  s/__RDS_DB_FQDN__/'"${GITLAB_DBHOST}"'/
  s/__RDS_DB_INSTANCE__/'"${GITLAB_DATABASE}"'/
  s/__RDS_DB_ADMIN__/'"${GITLAB_DBUSER}"'/
  s/__BUCKET__/'"${GITLAB_BACKUP_BUCKET}"'/
  s/__REGION__/'"${GITLAB_REGION}"'/
}' /etc/cfn/gitlab.rb.tmplt > ${GLCONFIG}

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


#
# Ensure uploads directory is a symlink
#####
if [[ -d ${UPLOADDIR} ]]
then
   echo "${UPLOADDIR} already exists as directory"

   if [[ -d "${UPLOADLNK}" ]]
   then
      echo "${UPLOADLNK} is a directory; should be link"
      printf "Nuking %s... " "${UPLOADLNK}"
      rm -rf "${UPLOADLNK}" && echo "Success" || \
        err_exit "Failed deleting ${UPLOADLNK}"
      printf "Recreating %s as symlink to %s... " "${UPLOADLNK}" "${UPLOADDIR}"
      ln -s "${UPLOADDIR}" "${UPLOADLNK}" && echo "Success" || \
        err_exit "Failed creating ${UPLOADLNK} as symlink"

   fi
else
   printf "Creating %s... " "${UPLOADDIR}"
   install -d -m 000700 -o git -g git "${UPLOADDIR}" && echo "Success" || \
     err_exit "Failed creating ${UPLOADDIR}"

   if [[ -d "${UPLOADLNK}" ]]
   then
      printf "Moving data from %s to %s..." "${UPLOADLNK}" "${UPLOADDIR}"
      (
       cd "${UPLOADLNK}" && tar cf - . | ( cd "${UPLOADDIR}" && tar xf - )
      ) && echo "Done" || echo "Some failures detected"

      printf "Nuking %s... " "${UPLOADLNK}"
      rm -rf "${UPLOADLNK}" && echo "Success" || \
        err_exit "Failed deleting ${UPLOADLNK}"
      printf "Recreating %s as symlink to %s... " "${UPLOADLNK}" "${UPLOADDIR}"
      ln -s "${UPLOADDIR}" "${UPLOADLNK}" && echo "Success" || \
        err_exit "Failed creating ${UPLOADLNK} as symlink"

      # Aesthetics...
      chown -h git:git "${UPLOADLNK}"
   elif [[ -h "${UPLOADLNK}" ]]
   then
      echo "${UPLOADLNK} is already a sym-link. Leaving as is."
   fi
fi

#
# Restart service to get new config bits
#####
printf "###\n# Restarting GitLab to finalize settings...\n###\n"
gitlab-ctl restart || \
      err_exit "Restart did not succeed. Check the logs."
echo "Restart successful."

#
# Export any saved SSH keys
#####
echo "yes" | gitlab-rake gitlab:shell:setup && echo "Success!" || \
  echo 'Failure during restoration of git-users'\'' SSH pubkeys (new install?)'

# Dear SEL: go back to being a PitA
setenforce 1 || \
   err_exit "Failed to reactivate SELinux"
echo "Re-enabled SELinux"

# Really only need this to run once...
systemctl disable gitlab-config.service

# Send success to CFn
/etc/cfn/scripts/glprep-signal.sh 0
