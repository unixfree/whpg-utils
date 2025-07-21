#!/bin/bash
# update_shared_preload.sh
# Safely update shared_preload_libraries in postgresql.conf across multiple base directories

set -e

BASE_DIRS=$1
OLD_VALUE=$2
NEW_VALUE=$3

if [[ -z "$BASE_DIRS" ]]; then
  echo "❌ Usage: $0 \"<base_dirs>\" <old_value> <new_value>"
  echo "Example: $0 \"/data /data1\" 'metrics_collector' ''"
  exit 1
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/postgresql_conf_backups_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

for BASE in $BASE_DIRS; do
  echo "🔍 Searching in: $BASE"
  CONF_PATHS=$(find "$BASE" -type f -name "postgresql.conf" 2>/dev/null)

  for conf in $CONF_PATHS; do
    echo "📄 Processing: $conf"
    cp "$conf" "$BACKUP_DIR/$(basename "$conf")_$(basename "$(dirname "$conf")").bak"

    ESC_OLD=$(printf '%s\n' "$OLD_VALUE" | sed 's/[]\/$*.^[]/\\&/g')
    ESC_NEW=$(printf '%s\n' "$NEW_VALUE" | sed 's/[]\/$*.^[]/\\&/g')

    if grep -q "^shared_preload_libraries *= *'$ESC_OLD'" "$conf"; then
      echo "🔧 Replacing: '$OLD_VALUE' → '$NEW_VALUE'"
      sed -i "s/^shared_preload_libraries *= *'$ESC_OLD'/shared_preload_libraries = '$ESC_NEW'/" "$conf"
    else
      echo "⚠️  No match found for '$OLD_VALUE' in $conf"
    fi
  done
done

echo "✅ All done. Backups in: $BACKUP_DIR"


