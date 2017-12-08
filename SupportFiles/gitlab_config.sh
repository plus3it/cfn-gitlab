#!/bin/bash
# shellcheck disable=SC2015
# Script to configure the GitLab installation
#
#################################################################
PROGNAME=$(basename "${0}")
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
SHAREURI=${GITLAB_SHARE_URI:-UNDEF}
SHARETYPE=${GITLAB_SHARE_TYPE:-UNDEV}

#
# Log errors and exit
#####
function err_exit {
   echo "${1}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${1}"
   exit 1
}

#
# Ensure persistent data storage is valid
function ValidShare {
   SHARESRVR="${SHAREURI/\:*/}"
   SHAREPATH=${SHAREURI/${SHARESRVR}\:\//}

   echo "Attempting to validate share-path"
   printf "\t- Attempting to mount %s... " "${SHARESRVR}"
   if [[ ${SHARETYPE} = glusterfs ]]
   then
      mount -t "${SHARETYPE}" "${SHARESRVR}":/"${SHAREPATH}" /mnt && echo "Success" ||
        err_exit "Failed to mount ${SHARESRVR}"
   elif [[ ${SHARETYPE} = nfs ]]
   then
      mount -t "${SHARETYPE}" "${SHARESRVR}":/ /mnt && echo "Success" ||
        err_exit "Failed to mount ${SHARESRVR}"
      printf "\t- Looking for %s in %s... " "${SHAREPATH}" "${SHARESRVR}"
      if [[ -d /mnt/${SHAREPATH} ]]
      then
         echo "Success" 
      else
         echo "Not found."
         printf "Attempting to create %s in %s... " "${SHAREPATH}" "${SHARESRVR}"
         mkdir /mnt/"${SHAREPATH}" && echo "Success" ||
           err_exit "Failed to create ${SHAREPATH} in ${SHARESRVR}"
      fi
   fi

   printf "Cleaning up... "
   umount /mnt && echo "Success" || echo "Failed"
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
# Ensure that share-persisted repositories are present
#####

ValidShare

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
