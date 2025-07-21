#!/bin/bash

# Load external configuration
source "$(dirname "$0")/config.env"

echo "🔎 Checking Greenplum version and cluster state..."
echo "----------------------------------------------------"

if su - "$GPADMIN_USER" -c "gpstate -s | grep -q 'Database status * = Up'" 2>/dev/null; then
  echo "✅ Greenplum is running. Extracting version..."
  su - "$GPADMIN_USER" -c "gpstate -s | grep 'Greenplum current version'"
else
  echo "⚠️  Greenplum is not running. Trying pg_config fallback..."
  if [ -x "$PG_CONFIG_PATH" ]; then
    "$PG_CONFIG_PATH" --gp_version
  else
    echo "❌ ERROR: Cannot find pg_config under $PG_CONFIG_PATH"
    exit 1
  fi
fi

echo
echo "🚀 Checking PXF cluster status..."
echo "---------------------------------"
su - "$GPADMIN_USER" -c "PXF_BASE=$PXF_BASE_PATH pxf cluster status"

echo
echo "📦 PXF Version"
echo "------------------"
su - "$GPADMIN_USER" -c "pxf version 2>/dev/null | grep -i version || echo '❌ Unable to retrieve PXF version.'"

echo
echo "📋 Segment Hosts and Data Directories"
echo "-------------------------------------"
su - "$GPADMIN_USER" -c "psql -At -d $SEGMENT_DB -f $SEGMENT_QUERY" | \
awk -F'|' '{ printf " %-12s | %s\n", $1, $2 }'

echo
echo "📋 Extensions in Use"
echo "---------------------"
su - "$GPADMIN_USER" -c "psql -At -d $EXTENSION_DB -f $EXTENSION_QUERY" | \
awk -F'|' '{ printf " %-10s | %-3s | %-4s | %-5s | %-4s\n", $1, $2, $3, $4, $5 }'
