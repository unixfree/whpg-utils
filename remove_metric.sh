#!/bin/bash
# remove_metrics_collector.sh

set -euo pipefail

# Load config
source "$(dirname "$0")/config.env"

mkdir -p "$SWAP_LOG_DIR"

echo "📋 Removing 'metrics_collector' from shared_preload_libraries..."

mapfile -t segment_lines < "$SEGMENTS_FILE"
for line in "${segment_lines[@]}"; do
  host=$(echo "$line" | cut -d'|' -f1)
  dir=$(echo "$line" | cut -d'|' -f2)

  echo "🧹 Removing from $dir on $host"
  su - "$GPADMIN_USER" -c "ssh -tt -o StrictHostKeyChecking=no $GPADMIN_USER@$host '$UPDATE_SHARED_PRELOAD_SCRIPT \"$dir\" \"metrics_collector\" \"\"'" \
    | tee -a "$SWAP_LOG_DIR/${host}_remove.log"
done

echo "✅ Removal complete."
