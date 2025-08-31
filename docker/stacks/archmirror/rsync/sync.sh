#!/bin/sh
set -e

TARGET_DIR="/archlinux"
MAX_RETRIES=3

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

if [ -z "$MIRROR_URL" ]; then
    log "ERROR: MIRROR_URL not set"
    exit 1
fi

mkdir -p "$TARGET_DIR"
for i in $(seq 1 $MAX_RETRIES); do
    log "Sync attempt $i/$MAX_RETRIES from $MIRROR_URL"
    
    if rsync --timeout=7200 \
             -rlptH --safe-links --delete-delay --delay-updates \
             ${RSYNC_EXTRA_OPTIONS:-} \
             "$MIRROR_URL/" "$TARGET_DIR/"; then
        log "Sync completed successfully"
        exit 0
    fi
    
    [ $i -lt $MAX_RETRIES ] && sleep $((i * 300))
done

log "All sync attempts failed"
exit 1
