#!/bin/sh
# shellcheck disable=SC2015
#
# Script to handle preparation of the instance for installing
# and configuring GitLab
#
#################################################################
PROGNAME=$(basename "${0}")
LOGFACIL="user.err"
KERNVERS=$(uname -r)
if [[ ${KERNVERS} == *el7* ]]
then
  OSDIST="os=el&dist=7"
elif [[ ${KERNVERS} == *el6* ]]
then
  OSDIST="os=el&dist=7"
fi
REPOSRC=${REPOSRC:-https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/config_file.repo?${OSDIST}}
INSTRPMS=()
DEPRPMS=(
          curl
          policycoreutils
          openssh-server
          openssh-clients
          nfs-utils
          nfs4-acl-tools
        )
FWPORTS=(
          80
          443
        )

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

   for PORT in "${FWPORTS[@]}"
   do
      printf "Add firewall exception for port %s... " "${PORT}"
      ${FWCMD} --permanent "--add-port=${PORT}/tcp" || \
         err_exit "Failed to add port ${PORT} to firewalld"
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
NfsClientStart

# Install repo-def for repository hosting the GitLab RPM(s)
curl -skL "${REPOSRC}" -o /etc/yum.repos.d/GitLab.repo || \
   err_exit "Failed to install repodef for GitLab CE"
echo "Successfully installed repodef for GitLab CE"
# Ensure SCL repositories are available
RELEASE=$(rpm -qf /etc/redhat-release --qf '%{name}')
if [[ $(yum repolist all | grep -q scl)$? -ne 0 ]]
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
yum install -y gitlab-ce || \
   err_exit "Install failed."
echo "Install succeeded. Gitlab must now be configured"
