#!/bin/sh

# Usage function
usage() {
    echo "Usage: backup.sh <environment>"
    echo "  environment: preprod or prod"
    echo ""
    echo "Configuration file: /etc/backup/\${environment}-secrets.conf"
    echo "Should contain:"
    echo "  BORG_PASSPHRASE='your-password'"
    echo "  B2_BUCKET='your-bucket-name'"
    echo ""
    echo "Example: ./backup.sh prod"
    exit 1
}

# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM

backup() {
    local ENVIRONMENT=$1
    
    # Validate arguments
    if [ $# -ne 1 ]; then
        echo "Error: Incorrect number of arguments"
        usage
    fi

    # Validate environment
    if [ "$ENVIRONMENT" != "preprod" ] && [ "$ENVIRONMENT" != "prod" ]; then
        echo "Error: Environment must be 'preprod' or 'prod'"
        usage
    fi

    # Source the environment-specific secrets file
    local SECRETS_FILE="/etc/backup/${ENVIRONMENT}-secrets.conf"
    if [ ! -f "$SECRETS_FILE" ]; then
        echo "Error: Secrets file not found: $SECRETS_FILE"
        exit 1
    fi

    . "$SECRETS_FILE"

    # Check that required variables were loaded
    if [ -z "$BORG_PASSPHRASE" ]; then
        echo "Error: BORG_PASSPHRASE not found in $SECRETS_FILE"
        exit 1
    fi

    if [ -z "$B2_BUCKET" ]; then
        echo "Error: B2_BUCKET not found in $SECRETS_FILE"
        exit 1
    fi

    if [ -z "$B2_APPLICATION_KEY_ID" ]; then
        echo "Error: B2_APPLICATION_KEY_ID not found in $SECRETS_FILE"
        exit 1
    fi

    if [ -z "$B2_APPLICATION_KEY" ]; then
        echo "Error: B2_APPLICATION_KEY not found in $SECRETS_FILE"
        exit 1
    fi

    # Export passphrase for Borg (borg expects this as an environment variable)
    export BORG_PASSPHRASE

    info "Starting backup for $ENVIRONMENT environment"

    # Backup the specified environment data directory:

    borg create                         \
        --verbose                       \
        --list                          \
        --stats                         \
        --show-rc                       \
        --exclude-caches                \
                                        \
        /srv/data/bkp/$ENVIRONMENT::'data-'$ENVIRONMENT'-{utcnow}' \
        /srv/data/$ENVIRONMENT

backup_exit=$?

info "Pruning repository"

    # Use the `prune` subcommand to maintain 7 daily, 4 weekly and 6 monthly
    # archives of this environment data:

    borg prune                          \
        --list                          \
        --show-rc                       \
        --keep-daily    7               \
        --keep-weekly   4               \
        --keep-monthly  6               \
        --prefix 'data-'$ENVIRONMENT'-' \
        /srv/data/bkp/$ENVIRONMENT

prune_exit=$?

    # actually free repo disk space by compacting segments

    info "Compacting repository"

    borg compact                        \
        --list                          \
        --show-rc                       \
        --progress                      \
        /srv/data/bkp/$ENVIRONMENT

    compact_exit=$?

    # use rclone to copy the backup to b2, fully overwriting the directory
    # B2 versioning will keep old versions for 30 days
    info "Copying backup to B2"

    rclone sync /srv/data/bkp/$ENVIRONMENT b2:$B2_BUCKET/$ENVIRONMENT/ --progress --delete-during

    sync_exit=$?


    # use highest exit code as global exit code
    global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
    global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))
    global_exit=$(( sync_exit > global_exit ? sync_exit : global_exit ))

    if [ ${global_exit} -eq 0 ]; then
        info "Backup, Prune, Compact, and Sync finished successfully"
    elif [ ${global_exit} -eq 1 ]; then
        info "Backup, Prune, Compact, and/or Sync finished with warnings"
    else
        info "Backup, Prune, Compact, and/or Sync finished with errors"
    fi

    exit ${global_exit}
}

# Execute the backup function with command line arguments
backup "$@"