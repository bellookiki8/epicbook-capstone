#!/bin/bash
# EpicBook MySQL restore script
# Usage: ./restore.sh <backup_file.sql>

set -e

CONTAINER="epicbook-db"
DB_NAME="bookstore"
DB_PASSWORD="demo1234"

if [ -z "$1" ]; then
  echo "Usage: ./restore.sh <backup_file.sql>"
  echo "Available backups:"
  ls -lh "$(dirname "$0")"/*.sql 2>/dev/null || echo "No backups found"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "Error: file '$1' not found"
  exit 1
fi

echo "Restoring from: $1"
echo "WARNING: This will overwrite the current database. Press Ctrl+C to cancel."
sleep 3

docker exec -i "$CONTAINER" \
  mysql -uroot -p"$DB_PASSWORD" "$DB_NAME" \
  < "$1"

echo "Restore complete at $(date)"
