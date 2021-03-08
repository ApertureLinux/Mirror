#!/bin/bash

# Variables
#  REMOTE_NAME     name of machine (same as in ~/.ssh/config or user@ip)
#  REMOTE_DIR      remote dir in which snapshot dirs will be created
#  LOCAL_DIR       local dir that will be backed up
#  FILTER_FILE     file with rsync filter rules(ignores and the such)
#  RSYNC_COMMAND   path to rsync command (or it's equivelent, like deltacopy)
#  SSH_COMMAND     path to ssh command (or shell that runs args as commands)

# (rules for backup retention, at least one must be satisfied to keep)
#  YEARS           keep a backup for each of the last X YEARS   (0 = ignore)
#  MONTHS          keep a backup for each of the last X MONTHS  (0 = ignore)
#  DAYS            keep a backup for each of the last X DAYS    (0 = ignore)
#  LAST            keep last X backups                          (0 = ignore)
#  KEEP_TODAY      keep all backups made today                  (true/false)
REMOTE_NAME="Aperture-Mirror"        # for ssh backups
REMOTE_DIR="./mirrors"
LOCAL_DIR="./archlinux"
RSYNC_COMMAND="/usr/bin/rsync"
SSH_COMMAND="/usr/bin/ssh"
POINTER_PATH="../aperture"
MONTHS=5
DAYS=14
LAST=5
KEEP_TODAY=true
DEBUG=true


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

run() {
    local rc

    "$@"
    rc=$?

    [ "$DEBUG" = true ] && echo "[$rc] $@" >&2

    return $rc
}

# sanity checks (prob should add some more -- ?don't run multiple at once)
check() {
    $SSH_COMMAND $REMOTE_NAME true || error "can't ssh, are keys set up?"
}

on_exit() {
    [[ -f "$FILTER_FILE" ]] && rm -f "$FILTER_FILE"
}

setup() {
    if [ -n "${FILTER_FILE:+1}" ] ; then
        FILTER_FILE="--filter=. $FILTER_FILE"
    fi
    if [ -n "${REMOTE_NAME:+1}" ] ; then
        RSYNC_REMOTE=${REMOTE_NAME}:
    else
        RSYNC_REMOTE=""
    fi

    YEARS=${YEARS:-0}
    MONTHS=${MONTHS:-0}
    DAYS=${DAYS:-0}
    KEEP_TODAY=${KEEP_TODAY:-false}
    [ "${LAST:-0}" -eq 0 ] && LAST=1

    ## for the snapshot dirname
    DATE="`date "+%F_%H%M%S"`"
}

transfer() {
    local rc

    ## create remote dirs
    $SSH_COMMAND $REMOTE_NAME "mkdir -p \"${REMOTE_DIR}\""

    ## -a    archive, recursive, preserve time/original owner id
    ## -P    print progres/save partial(alow resume)
    ## -H    preserve links(hard/sym)
    run $RSYNC_COMMAND -rhHxl -P --link-dest="../$POINTER_PATH" \
        "$LOCAL_DIR/" ${RSYNC_REMOTE}"${REMOTE_DIR}/incomplete_$DATE"
    rc=$?

    ## don't commit snapshot on some rsync errors (see rsync exit codes)
    ## TODO: maybe remove incomplete backup dir as well?
    contains $rc 1 2 5 12 20 22 30 && error "failed to make backup [$rc]"

    # finalize snapshot
    #  0 - ssh (these run on the remote server)
    ##   1 - cd to backup dir (with all snapshots)
    ##   2 - remove "incomplete_" prefix (since all transfers are complete)
    ##   3 - atomically swap old 'current' link with link from step 3
    ##   4 - remove old dirs
    ###     4-12 - apply retention policy to get list of backups to keep
    ###    13-17 - for each backup, if not in list, delete
    $SSH_COMMAND $REMOTE_NAME "
        cd \"$REMOTE_DIR\"
        mv \"incomplete_$DATE\" \"$DATE\"
        ln -nfs \"$REMOTE_DIR/$DATE\" \"$POINTER_PATH\"
        KEEP=\"\$(
            {
                basename \"$(realpath \"$POINTER_PATH\")\" ;
                ls -1d *-*-*_*/ | sort -ru -k1,1 -t- | head -$YEARS ;
                ls -1d *-*-*_*/ | sort -ru -k1,2 -t- | head -$MONTHS ;
                ls -1d *-*-*_*/ | sort -ru -k1,1 -t_ | head -$DAYS ;
                ls -1dr *-*-*_*/ | head -$LAST ;
                [ \"$KEEP_TODAY\" == true ] && ls -1d \"${DATE%_*}\"* ;
            } 2>/dev/null | sort -u
        )\"
        for backup in *-*-*_*/ ; do
            if ! echo -en \"\$KEEP\" | grep -q -- \"^\$backup\" ; then
                rm -rf \"\$backup\"
            fi
        done
    "
}

main() {
    check
    setup
    transfer
}

main
