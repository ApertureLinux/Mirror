#!/bin/bash

# Variables
#  REMOTE_NAME     name of machine (same as in ~/.ssh/config or user@ip)
#  REMOTE_DIR      remote dir in which snapshot dirs will be created
#  LOCAL_DIR       local dir that will be backed up
#  FILTER_FILE     file with rsync filter rules(ignores and the such)
#  RSYNC_COMMAND   path to rsync command (or it's equivelent, like deltacopy)
#  SSH_COMMAND     path to ssh command (or shell that runs args as commands)
#  DAYS            delete backups older than X DAYS    (0 = store all)
#  KEEP            keep up to X backups, delete others (0 = store all)
REMOTE_NAME="Aperture-Mirror"        # for ssh backups
REMOTE_DIR="./mirrors"
LOCAL_DIR="./archlinux"
RSYNC_COMMAND="/usr/bin/rsync"
SSH_COMMAND="/usr/bin/ssh"
POINTER_PATH="../aperture"
DAYS=0
KEEP=10

trap on_exit EXIT

contains() { # usage: contains to_find elem1 elem2 elem3
    val=$1 ; shift
    for e in "$@"; do
        [[ "$e" == "$val" ]] && return 0
    done
    return 1
}

error() {
    echo "$@" >&2
    exit 1
}

# sanity checks (prob should add some more -- ?don't run multiple at once)
check() {
    $SSH_COMMAND $REMOTE_NAME true || error "can't ssh, are keys set up?"
}

on_exit() {
    [[ -f "$FILTER_FILE" ]] && rm -f "$FILTER_FILE"
}

setup() {
    if [ -n "${REMOTE_NAME:+1}" ] ; then
        RSYNC_REMOTE=${REMOTE_NAME}:
    else
        RSYNC_REMOTE=""
    fi

    [ $KEEP -ne 0 ] && KEEP=$((KEEP+1))

    ## for the snapshot dirname
    DATE="`date "+%F_%H%M%S"`"
}

transfer() {
    ## create remote dirs
    $SSH_COMMAND $REMOTE_NAME "mkdir -p \"${REMOTE_DIR}\""

    ## -a    archive, recursive, preserve time/original owner id
    ## -P    print progres/save partial(alow resume)
    ## -H    preserve links(hard/sym)
    $RSYNC_COMMAND -rhHx --link-dest="$POINTER_PATH" \
        "$LOCAL_DIR/" ${RSYNC_REMOTE}"${REMOTE_DIR}/incomplete_$DATE"

    ## don't commit snapshot on some rsync errors (see rsync exit codes)
    ## TODO: maybe remove incomplete backup dir as well?
    contains $? 1 2 5 12 20 22 30 && error rsync failed to make backup

    # finalize snapshot
    ##   0 - ssh (these run on the remote server)
    ##   1 - cd to backup dir (with all snapshots)
    ##   2 - remove "incomplete_" prefix (since all transfers are complete)
    ##   3 - create a link to this snapshot
    ##   4 - atomically swap old 'current' link with link from step 3
    ##   5 - remove old dirs
    $SSH_COMMAND $REMOTE_NAME "
        cd \"$REMOTE_DIR\"
        mv \"incomplete_$DATE\" \"$DATE\"
        ln -nfs \"$REMOTE_DIR/$DATE\" $POINTER_PATH
        [ \"$DAYS\" -eq 0 ] && [ \"$KEEP\" -ne 0 ]                      \\
            && ls -1tr -I $POINTER_PATH                                 \\
            | tail -n \"+$KEEP\"                                        \\
            | xargs rm -rf
    "
}

main() {
    check
    setup
    transfer
}

main
