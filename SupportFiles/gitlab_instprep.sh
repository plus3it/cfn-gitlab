#!/bin/bash
# shellcheck disable=SC2015,SC1091,SC2086
#
# Script to handle preparation of the instance for installing
# and configuring GitLab
#
#################################################################
PROGNAME=$(basename "${0}")
LOGFACIL="user.err"
# Read in template envs we might want to use
source /etc/cfn/GitLab.envs
KERNVERS=$(uname -r)
if [[ ${KERNVERS} == *el7* ]]
then
  OSDIST="os=el&dist=7"
elif [[ ${KERNVERS} == *el6* ]]
then
  OSDIST="os=el&dist=7"
fi
REPOSRC=${GITLAB_YUM_CONFIG:-https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/config_file.repo?${OSDIST}}
INSTRPMS=()
DEPRPMS=(
          curl
          policycoreutils
          openssh-server
          openssh-clients
        )
FWSVCS=(
          http
          https
        )
SHARETYPE=${GITLAB_SHARE_TYPE:-UNDEF}


# Log failures and exit
function err_exit {
   echo "${1}"
   logger -t "${PROGNAME}" -p ${LOGFACIL} "${1}"
   exit 1
}

# Open firewall ports
function FwStuff {
   # Temp-disable SELinux (need when used in cloud-init context)
   setenforce 0 || \
      err_exit "Failed to temp-disable SELinux"
   echo "Temp-disabled SELinux"

   if [[ $(systemctl --quiet is-active firewalld)$? -eq 0 ]]
   then
      local FWCMD='firewall-cmd'
   else
      local FWCMD='firewall-offline-cmd'
      ${FWCMD} --enabled
   fi

   for SVC in "${FWSVCS[@]}"
   do
      printf "Add firewall exception for service %s... " "${SVC}"
      ${FWCMD} --permanent "--add-service=${SVC}" || \
         err_exit "Failed to add service ${SVC} to firewalld"
   done

   # Restart firewalld with new rules loaded
   printf "Reloading firewalld rules... "
   ${FWCMD} --reload || \
      err_exit "Failed to reload firewalld rules"

   # Restart SELinux
   setenforce 1 || \
      err_exit "Failed to reactivate SELinux"
   echo "Re-enabled SELinux"
}

##
## Enable NFS-client pieces
function NfsClientStart {
   local NFSCLIENTSVCS=(
            rpcbind
            nfs-server
            nfs-lock
            nfs-idmap
         )

    # Enable and start services
    for SVC in "${NFSCLIENTSVCS[@]}"
    do
       printf "Enabling %s... " "${SVC}"
       systemctl enable "${SVC}" && echo "Success!" || \
          err_exit "Failed to enable ${SVC}"
       printf "Starting %s... " "${SVC}"
       systemctl start "${SVC}" && echo "Success!" || \
          err_exit "Failed to start ${SVC}"
    done
}

##
## Decide what GitLab version to install
function InstGitlab {
   local CPUARCH
      CPUARCH=$(uname -i)
   local RPMARR
      RPMARR=(
       $(
         yum --showduplicates list available ${GITLAB_RPM_NAME} | \
         tail -1
        )
      )
   
   if [[ ${#RPMARR[@]} -gt 0 ]]
   then
      yum install -qy "${RPMARR[0]/.${CPUARCH}/}-${RPMARR[1]}.${CPUARCH}"
   else
      err_exit 'Was not able to determine GitLab version to install'
   fi
}


###############
## Main Program
###############
if [[ ${SHARETYPE} = nfs ]]
then
   DEPRPMS+=(
         nfs-utils
         nfs4-acl-tools
      )
elif [[ ${SHARETYPE} = glusterfs ]]
then
   DEPRPMS+=(
         glusterfs
	 glusterfs-fuse
	 attr
      )
fi


# Check if we're missing any vendor-enumerated RPMs
for RPM in "${DEPRPMS[@]}"
do
   printf "Cheking for presence of %s... " "${RPM}"
   if [[ $(rpm --quiet -q "$RPM")$? -eq 0 ]]
   then
      echo "Already installed."
   else
      echo "Selecting for install"
      INSTRPMS+=(${RPM})
   fi
done

# Install any missing vendor-enumerated RPMs
if [[ ${#INSTRPMS[@]} -ne 0 ]]
then
   echo "Will attempt to install the following RPMS: ${INSTRPMS[*]}"
   yum install -y "${INSTRPMS[@]}" || \
      err_exit "Install of RPM-dependencies experienced failures"
else
   echo "No RPM-dependencies to satisfy"
fi

# Ensure vendor-enumerated services are in proper state
for MGSVC in sshd postfix
do
   if [[ $(systemctl --quiet is-active ${MGSVC})$? -ne 0 ]]
   then
      printf "Starting %s..." ${MGSVC}
      systemctl start ${MGSVC} || \
         err_exit "Failed to start ${MGSVC}!"
      echo "Success!"
   fi
   if [[ $(systemctl --quiet is-enabled ${MGSVC})$? -ne 0 ]]
   then
      printf "Enabling %s..." ${MGSVC}
      systemctl enable ${MGSVC} || \
         err_exit "Failed to enable ${MGSVC}!"
      echo "Success!"
   fi
done

# Call to firewall exceptions function
FwStuff
if [[ ${SHARETYPE} = nfs ]]
then
   NfsClientStart
fi

# Install repo-def for repository hosting the GitLab RPM(s)
curl -skL "${REPOSRC}" -o /etc/yum.repos.d/GitLab.repo || \
   err_exit "Failed to install repodef for GitLab CE"
echo "Successfully installed repodef for GitLab CE"
# Ensure SCL repositories are available
RELEASE=$(rpm -qf /etc/redhat-release --qf '%{name}')
if [[ $(yum repolist -y all | grep -q scl)$? -ne 0 ]]
then
   yum install -y "${RELEASE}-scl" || \
      err_exit "Attempted install of Software CoLlections repodefs failed."
   echo "Successfully nstalled Software CoLlections repodefs"
fi

# Install a Ruby version that is FIPS compatible
yum --enablerepo=*scl* install -y rh-ruby23 || \
   err_exit "Install of updated Ruby RPM failed."
echo "Installed updated Ruby RPM"

# Permanently eable the SCL version of Ruby
cat << EOF > /etc/profile.d/scl-ruby.sh
source /opt/rh/rh-ruby23/enable
export X_SCLS="\$(scl enable rh-ruby23 'echo \$X_SCLS')"
EOF

# Create GitLab backup script
install -b -m 0700 /dev/null /usr/local/bin/backup.cron ||
  echo "Couldn't create backup script"
cat << EOF > /usr/local/bin/backup.cron
#!/bin/bash
#
# Script to backup GitLab data to S3 bucket
#################################################################
PROGNAME=\$(basename "\${0}")
LOGFACIL="user.err"
for VAR in \$(cat /etc/cfn/GitLab.envs)
do
   export \$VAR
done
BUCKET="\${GITLAB_BACKUP_BUCKET:-UNDEF}"
FOLDER="\${GITLAB_BACKUP_FOLDER:-UNDEF}"
REGION="\${GITLAB_AWS_REGION:-UNDEF}"
DAYSUB="\$(date '+%A')"
SRCDIR=/var/opt/gitlab/backups/

# Set up flexible logging
function err_exit {
   echo "\${1}"
   logger -t "\${PROGNAME}" -p \${LOGFACIL} "\${1}"
   exit 1
}

# Create GitLab archive file
printf "Creating backup archive-file in s3://%s..." "\${BUCKET}"
gitlab-rake gitlab:backup:create STRATEGY=copy DIRECTORY="\${FOLDER}" CRON=1 &&\
  echo "Success" || err_exit 'Failed creating backup archive-file'

EOF

# Here documents are weird about status-capture, so...
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]
then
   echo "Couldn't insert backup script content"
fi

# Add backupscript to crontab
printf "Adding backup job to root's cron... "
(
  crontab -l 2>/dev/null
  echo "0 23 * * * /usr/local/bin/backup.cron"
) | \
crontab - && echo "Success." || echo "Failed."

# shellcheck disable=SC1091
source /etc/profile.d/scl-ruby.sh || \
   err_exit "Failed to reset Ruby-location to updated version"
echo "Reset Ruby-location to updated version"

# Disable Chef's FIPS stuff
cat << EOF > /etc/profile.d/chef.sh
export CHEF_FIPS=""
EOF

# shellcheck disable=SC1091
source /etc/profile.d/chef.sh || \
   err_exit "Failed to shut off FIPS-checking in embedded Chef Gem"
echo "Shut off FIPS-checking in embedded Chef Gem"

# Do base-install of GitLab RPM
printf "Installing GitLab CE"
InstGitlab && \
echo "Install succeeded. Gitlab must now be configured"
