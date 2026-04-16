#!/bin/bash
# EpicBook MySQL backup script
# Usage: ./backup.sh
# Saves a timestamped SQL dump to ~/epicbook-capstone/backups/

set -e

BACKUP_DIR="$(dirname "$0")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FILENAME="bookstore_${TIMESTAMP}.sql"
CONTAINER="epicbook-db"
DB_NAME="bookstore"
DB_PASSWORD="demo1234"

echo "Starting backup at $(date)"

docker exec "$CONTAINER" \
  mysqldump -uroot -p"$DB_PASSWORD" "$DB_NAME" \
  > "${BACKUP_DIR}/${FILENAME}"

echo "Backup saved to: ${BACKUP_DIR}/${FILENAME}"
echo "Size: $(du -sh ${BACKUP_DIR}/${FILENAME} | cut -f1)"
