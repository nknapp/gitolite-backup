#!/bin/bash

# Settings 
BACKUP_TARGET=/tmp/gitolite-backup/

# Variables
BASE_DIR="$( cd "$(dirname $0)/.." && pwd )"
BACKUP_TMP=${BASE_DIR}/backup
export GIT_SSH="${BASE_DIR}/config/ssh"
export RSYNC_RSH="${BASE_DIR}/config/ssh"

mkdir -p ${BACKUP_TARGET}
mkdir -p ${BACKUP_TMP}

rsync -avz --delete --exclude 'repositories' backup_shell:~/ ${BACKUP_TMP}/

# Clone repositories into the same directory structure as in the original
for i in $( ${GIT_SSH} backup_repo expand | tail -n +3 | cut -f "3" ) ; do
    REPO_TARGET="${BACKUP_TMP}/repositories/${i}.git"
    if [ -d "${REPO_TARGET}" ] ; then 
        cd ${REPO_TARGET}
        git fetch
    else
        mkdir -p "$(dirname "${REPO_TARGET}" )"
        cd "$(dirname "${REPO_TARGET}" )"
        git clone --mirror "ssh://backup_repo/${i}"
    fi
done
