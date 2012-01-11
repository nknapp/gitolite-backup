#!/bin/bash

BASE_DIR="$( cd "$(dirname $0)/.." && pwd )"
TMP_DIR="${BASE_DIR}/tmp"
TMP_SSH_CONFIG="${TMP_DIR}/install_ssh_config"
TMP_QUESTIONS="${TMP_DIR}/questions.sh"

CONFIG_DIR="${BASE_DIR}/config"
BACKUP_SSH="${CONFIG_DIR}/ssh"
BACKUP_SSH_CONFIG="${CONFIG_DIR}/ssh_config"

cat <<INTRODUCTION
This is the gitolite-backup install script.

The installation directory is  : $BASE_DIR
Configuration data is stored in: $BASE_DIR/config

Be sure to make a backup of this directory as well in order
to retain the private keys in case of a data loss.


INTRODUCTION

if [ -f "${TMP_QUESTIONS}" ] ; then
    echo "Reading from ${TMP_QUESTIONS}"
    cat "${TMP_QUESTIONS}"
    . "${TMP_QUESTIONS}"
else
    echo "Please edit ${TMP_QUESTIONS}" and fill the values according to your installation.
    echo "Then, run this script again."
    mkdir -p ${TMP_DIR}
    cat >${TMP_QUESTIONS} <<QUESTIONS
# The hostname of the gitolite server
GITOLITE_HOST=servername

# The username of the gitolite user
GITOLITE_USER=username

# If necessary, the location of the private key used for shell-access to the gitolite account
# Leave empty is not needed
GITOLITE_SHELL_PK=

# The location of the private key used for repository-access to the 'gitolite-admin' repository
GITOLITE_REPOSITORY_PK=

# The username within gitolite that should be used for backup access to repositories.
# Note that backups will only be performed of repositories readable to this user.
BACKUP_USER=backup

QUESTIONS
    exit 1
fi

##########################################################################################
### Step 3: Write custom ssh_config and ssh-command for repo access by backup ############
##########################################################################################

# Generate ssh-command that uses custom config file for repo access
cat >"${BACKUP_SSH}" <<SSH_COMMAND
#!/bin/bash
ssh -F "${BACKUP_SSH_CONFIG}" \$*

SSH_COMMAND
chmod u+x "${BACKUP_SSH}"

# Generate ssh_config for repo and shell access
cat >"${BACKUP_SSH_CONFIG}" <<SSH_CONFIG
Host backup_shell
    Hostname ${GITOLITE_HOST}
    User ${GITOLITE_USER}
    IdentityFile ${CONFIG_DIR}/shell_access_key
    IdentitiesOnly yes

Host backup_repo
    Hostname ${GITOLITE_HOST}
    User ${GITOLITE_USER}
    IdentityFile ${CONFIG_DIR}/repo_access_key
    IdentitiesOnly yes
SSH_CONFIG

##########################################################################################
### Step 2: Write temporary ssh_config and ssh-command for the installer ############
##########################################################################################

# Prepare variable for temporary ssh config
if [ -n "${GITOLITE_SHELL_PK}" ]; then
    SHELL_IDENTITY_LINE="IdentityFile ${GITOLITE_SHELL_PK}"
fi

# Create temporary ssh_config for installer
mkdir -p "${BASE_DIR}/tmp"
cat >"${TMP_SSH_CONFIG}" <<INSTALL_SSH
Host gitolite_shell
    Hostname ${GITOLITE_HOST}
    User ${GITOLITE_USER}
    ${SHELL_IDENTITY_LINE}
    IdentitiesOnly yes

Host gitolite_repository
    Hostname ${GITOLITE_HOST}
    User ${GITOLITE_USER}
    IdentityFile ${GITOLITE_REPOSITORY_PK}
    IdentitiesOnly yes
INSTALL_SSH

FAILED=false
# Verify connections
echo Verifying shell connection 
ssh -F "${TMP_SSH_CONFIG}" gitolite_shell echo
if [ "$?" == "0" ]; then
    echo OK
else 
    echo Failed 
    FAILED=true 
fi

echo Verifying repository connection
if [ -n "$( ssh -F "${BASE_DIR}/tmp/install_ssh_config" gitolite_repository info | grep gitolite-admin )" ] ; then
    echo OK
else
    echo Failed
    FAILED=true
fi

if [ "${FAILED}" == "true" ] ; then
    echo Verification of connections failed. Please correct ${TMP_QUESTIONS} and run this script again.
fi

# Verification succeded. 
############################################
# Step 1: Generate keys for backup user.
############################################

mkdir -p ${CONFIG_DIR}

( # Subprocess in order to preserve umask
umask 077
ssh-keygen -N "" -f "${CONFIG_DIR}/repo_access_key"
ssh-keygen -N "" -f "${CONFIG_DIR}/shell_access_key"

) # End of key-generating process


############################################
# Step 0a: Copy repo public key into the gitolite-admin repository
############################################


pushd .

echo Cloning the gitolite-admin repository into tmp/gitolite-admin
cd ${TMP_DIR}

# Generate ssh-command that uses custom config file
cat >${TMP_DIR}/ssh <<TMP_SSH_COMMAND
#!/bin/bash
ssh -F "${TMP_SSH_CONFIG}" \$*

TMP_SSH_COMMAND

chmod u+x ${TMP_DIR}/ssh 
export GIT_SSH="${TMP_DIR}/ssh"
git clone "ssh://gitolite_repository/gitolite-admin"
if [ ! -d gitolite-admin ] ; then echo "Error: gitolite-admin was not cloned" ; exit 1 ; fi

echo Creating backup user within gitolite
if [ -f "${TMP_DIR}/gitolite-admin/keydir/${BACKUP_USER}.pub" ] ; then echo "Error user ${BACKUP_USER} already exists in gitolite!" ; exit 1; fi
cat ${CONFIG_DIR}/repo_access_key.pub >${TMP_DIR}/gitolite-admin/keydir/${BACKUP_USER}.pub

# Commit and push
cd gitolite-admin
git add "keydir/${BACKUP_USER}.pub"
git commit -m "Added backup user"
git push
cd ..
rm -rf gitolite-admin

echo "User '${BACKUP_USER}' has been added to gitolite. You should give this"
echo "user read acess to all repositories that should be part of the backup "
echo "(and only to those)."

popd # git user added

############################################
# Step 0a: Copy shell public key into the authorized_keys file
############################################


echo "The backup must have shell access to gitolite."
echo "The public key for shell access will now be copied to gitolites authorized_keys file."
cat "${CONFIG_DIR}/shell_access_key.pub" | ssh  -F "${TMP_SSH_CONFIG}" gitolite_shell "umask 077 ; cat >> ~/.ssh/authorized_keys"






