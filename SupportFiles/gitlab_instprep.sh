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
SHAREURI=${GITLAB_SHARE_URI:-UNDEF}
SHARETYPE=${GITLAB_SHARE_TYPE:-UNDEF}


# Log failures and exit
function err_exit {
   echo "${1}"
   logger -t "${PROGNAME}" -p ${LOGFACIL} "${1}"
   exit 1
}

function NoIpv6localhost {
   if [[ $( grep -q localhost6 /etc/hosts )$? -eq 0 ]]
   then
      sed -i '/localhost6/s/^/## /' /etc/hosts
   fi
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

   # Ensure that mountpoint for persistent-data directory exists
   if [[ ! -d /var/opt/gitlab/git-data ]]
   then
       install -Ddm 000755 /var/opt/gitlab/git-data
   fi

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
}


###############
## Main Program
###############

# Make sure no 'localhost6' entry active in /etc/hosts
NoIpv6localhost

# Add RPMs based on share-server type
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

# Which ruby to install
case $( repoquery ${GITLAB_RPM_NAME} --qf '%{version}\n' | cut -d '.' -f 1 ) in
   10) RUBYVERS=rh-ruby23
       ;;
   11) RUBYVERS=rh-ruby24
       ;;
esac

# Install a Ruby version that is FIPS compatible
yum --enablerepo=*scl* install -y ${RUBYVERS} || \
   err_exit "Install of updated Ruby RPM failed."
echo "Installed updated Ruby RPM"

# Permanently eable the SCL version of Ruby
cat << EOF > /etc/profile.d/scl-ruby.sh
source /opt/rh/${RUBYVERS}/enable
export X_SCLS="\$(scl enable ${RUBYVERS} 'echo \$X_SCLS')"
EOF

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

# Set up persistent storage directory
ValidShare

