#!/usr/bin/env bash
# Sync all missing top-level movie folders from remote → local (no deletions).
# No ACLs; simple group model (:media) with setgid so Plex/Jellyfin can write subs.
# Dry-run scans ALL remote folders and reports totals.

set -Eeuo pipefail

# --- Config ---
: "${ENV_FILE:=/etc/sync-movies.env}"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# Required vars
: "${REMOTE_USER:?Set REMOTE_USER}"
: "${REMOTE_HOST:?Set REMOTE_HOST}"
: "${REMOTE_PORT:=22}"
: "${REMOTE_PATH:?Set REMOTE_PATH}"                   # remote dir containing movie subfolders
: "${LOCAL_PATH:?Set LOCAL_PATH}"                     # e.g. /mnt/nfs/media-nas/movies
: "${SSH_KEY:=~/.ssh/id_ed25519}"
: "${KNOWN_HOSTS_FILE:=/etc/ssh/ssh_known_hosts}"

: "${MEDIA_GROUP:=media}"                             # plex & jellyfin should be in this group
: "${DIR_MODE:=2775}"                                 # setgid dirs so new files inherit group
: "${FILE_MODE:=0664}"
: "${LOG_DIR:=/var/log/sync-movies}"
: "${DRY_RUN:=0}"                                     # 1 => scan & report only
: "${BANDWIDTH_LIMIT_KBPS:=0}"
: "${VERBOSE:=1}"                                     # 1 => list each folder in dry-run

mkdir -p "$LOG_DIR" "$LOCAL_PATH" "$(dirname "$KNOWN_HOSTS_FILE")"
LOG_FILE="$LOG_DIR/sync-$(date +%F).log"

# --- Ensure media group exists locally ---
if ! getent group "${MEDIA_GROUP}" >/dev/null 2>&1; then
  echo "[$(date -Is)] Group '${MEDIA_GROUP}' not found, creating..." | tee -a "$LOG_FILE"
  groupadd -f "${MEDIA_GROUP}" || {
    echo "[$(date -Is)] ERROR: failed to create group '${MEDIA_GROUP}'" | tee -a "$LOG_FILE"
    exit 1
  }
fi

# --- Single-run lock ---
LOCK_FILE="/var/lock/sync-movies.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "[$(date -Is)] Another run is active; exiting." | tee -a "$LOG_FILE"; exit 0; }

echo "[$(date -Is)] Config: REMOTE=${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}  LOCAL=${LOCAL_PATH}  DRY_RUN=${DRY_RUN}" | tee -a "$LOG_FILE"

# --- SSH prep ---
ssh-keyscan -p "$REMOTE_PORT" "$REMOTE_HOST" >> "$KNOWN_HOSTS_FILE" 2>/dev/null || true
SSH_CMD=(ssh -i "$SSH_KEY" -p "$REMOTE_PORT" -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS_FILE" -o BatchMode=yes)

# --- Remote listing (ALL; NUL-delimited) ---
remote_find=(find "${REMOTE_PATH%/}" -mindepth 1 -maxdepth 1 -type d -print0)

# --- rsync options (NO deletes) ---
RSYNC_OPTS=(
  -aHzz
  --partial
  --append-verify
  --human-readable
  --no-inc-recursive
  --info=stats2
  --protect-args
  --chmod=Du=rwx,g=rwx,o=rx,Fu=rw,g=rw,o=r
  --chown=":${MEDIA_GROUP}"
)
[[ "$BANDWIDTH_LIMIT_KBPS" -gt 0 ]] && RSYNC_OPTS+=(--bwlimit="$BANDWIDTH_LIMIT_KBPS")
[[ "$DRY_RUN" == "1" ]] && RSYNC_OPTS+=(--dry-run)

# --- Dry run: scan ALL and summarize ---
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[$(date -Is)] DRY RUN: scanning all remote folders..." | tee -a "$LOG_FILE"
  total_count=0
  missing_count=0

  while IFS= read -r -d '' REMOTE_ENTRY; do
    ((total_count++)) || true
    MOVIE_DIR="${REMOTE_ENTRY##*/}"
    DST="${LOCAL_PATH%/}/${MOVIE_DIR}"
    if [[ -d "$DST" ]]; then
      [[ "$VERBOSE" == "1" ]] && echo "[$(date -Is)] SKIP existing: $MOVIE_DIR" | tee -a "$LOG_FILE"
    else
      ((missing_count++)) || true
      [[ "$VERBOSE" == "1" ]] && echo "[$(date -Is)] WILL COPY missing: $MOVIE_DIR" | tee -a "$LOG_FILE"
    fi
  done < <( "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "${remote_find[@]}" )

  echo "[$(date -Is)] Remote total folders: ${total_count}" | tee -a "$LOG_FILE"
  echo "[$(date -Is)] Missing locally (would be copied): ${missing_count}" | tee -a "$LOG_FILE"
  echo "[$(date -Is)] === Finished DRY RUN ===" | tee -a "$LOG_FILE"
  exit 0
fi

# --- Real run: copy ALL missing folders, then set perms ---
copied_any=0
while IFS= read -r -d '' REMOTE_ENTRY; do
  MOVIE_DIR="${REMOTE_ENTRY##*/}"
  SRC="${REMOTE_PATH%/}/${MOVIE_DIR}"
  DST="${LOCAL_PATH%/}/${MOVIE_DIR}"

  if [[ -d "$DST" ]]; then
    echo "[$(date -Is)] SKIP existing: $MOVIE_DIR" | tee -a "$LOG_FILE"
    continue
  fi

  echo "[$(date -Is)] COPY missing: $MOVIE_DIR" | tee -a "$LOG_FILE"
  mkdir -p "$DST"

  if rsync "${RSYNC_OPTS[@]}" -e "${SSH_CMD[*]}" --rsync-path="rsync" \
        "${REMOTE_USER}@${REMOTE_HOST}:${SRC%/}/" \
        "${DST%/}/" 2>&1 | tee -a "$LOG_FILE"
  then
    copied_any=1
    chgrp -R "${MEDIA_GROUP}" "$DST" || true
    find "$DST" -type d -print0 | xargs -0 chmod "${DIR_MODE}" || true
    find "$DST" -type f -print0 | xargs -0 chmod "${FILE_MODE}" || true
    echo "[$(date -Is)] DONE: $MOVIE_DIR" | tee -a "$LOG_FILE"
  else
    echo "[$(date -Is)] ERROR: rsync failed for $MOVIE_DIR" | tee -a "$LOG_FILE"
  fi
done < <( "${SSH_CMD[@]}" "${REMOTE_USER}@${REMOTE_HOST}" "${remote_find[@]}" )

[[ "$copied_any" == "0" ]] && echo "[$(date -Is)] No new folders to copy." | tee -a "$LOG_FILE"
echo "[$(date -Is)] === Finished ===" | tee -a "$LOG_FILE"
root@plex:~# 
