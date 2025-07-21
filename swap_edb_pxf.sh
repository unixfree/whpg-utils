#!/bin/bash
# swap_back_to_broadcom.sh
# Run as root — EDB ➜ Broadcom rollback

set -euo pipefail
trap 'echo "❌ Error at line $LINENO. Exiting."; exit 1' ERR

# Load shared config
source "$(dirname "$0")/config.env"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PKG="/home/gpadmin/greenplum_backup_restore-1.30.7-gp6-rhel8-x86_64.gppkg"

STEP_START=${1:-1}

echo "♻️ Starting rollback to Broadcom Greenplum 6.28.2 from step $STEP_START..."

# Step 1: Remove EDB PXF + EDB RPMs
if [ "$STEP_START" -le 1 ]; then
  echo "🧹 Step 1: Removing EDB PXF and EDB RPMs..."

  # 1b. Remove EDB PXF RPM first (to clear dependency)
  if rpm -q "$EDB_PXF_RPM" >/dev/null 2>&1; then
    echo "❌ Removing $EDB_PXF_RPM"
    rpm -e "$EDB_PXF_RPM" || { echo "❌ Failed to remove $EDB_PXF_RPM"; exit 1; }
  fi

  # 1c. Remove remaining EDB RPMs
  RPM_LIST=$(rpm -qa | grep -E '^(whpg-backup|warehouse-pg)' | sort)
  if echo "$RPM_LIST" | grep -q .; then
    while read -r pkg; do
      echo "❌ Removing $pkg..."
      rpm -e "$pkg" || { echo "❌ Failed to remove $pkg"; exit 1; }
    done <<< "$RPM_LIST"
    echo "✅ Successfully removed EDB RPMs."
  else
    echo "✅ No EDB-related RPMs found to remove."
  fi
fi

# Step 2: Remove symlink
if [ "$STEP_START" -le 2 ]; then
  echo "🔗 Step 2: Removing symlink $GP_SYMLINK (if exists)..."
  [ -L "$GP_SYMLINK" ] && rm -f "$GP_SYMLINK" && echo "✔️ Symlink removed." || echo "✅ No symlink to remove."
fi

# Step 3: Reinstall Broadcom RPM
if [ "$STEP_START" -le 3 ]; then
  echo "📦 Step 3: Installing Broadcom RPM: $GP_BROADCOM_RPM"
  [ -f "$GP_BROADCOM_RPM" ] || { echo "❌ ERROR: Broadcom RPM not found at $GP_BROADCOM_RPM"; exit 1; }
  rpm -ivh "$GP_BROADCOM_RPM"
fi

# Step 4: Verify installation directory
if [ "$STEP_START" -le 4 ]; then
  echo "📁 Step 4: Verifying Broadcom installation directory..."
  [ -d "$GP_BROADCOM_DIR" ] || {
    echo "❌ ERROR: Expected Broadcom directory not found at $GP_BROADCOM_DIR"
    echo "💡 Please ensure RPM installation completed successfully."
    exit 1
  }
  echo "✅ Directory found: $GP_BROADCOM_DIR"
fi

# Step 5: Recreate symlink
if [ "$STEP_START" -le 5 ]; then
  echo "🔗 Step 5: Creating symlink $GP_SYMLINK → $GP_BROADCOM_DIR"
  rm -f "$GP_SYMLINK"
  ln -s "$GP_BROADCOM_DIR" "$GP_SYMLINK"
  chown -h "$GP_USER:$GP_USER" "$GP_SYMLINK"
  echo "✔️ Symlink created."
fi

# Step 6: Set permissions
if [ "$STEP_START" -le 6 ]; then
  echo "🔐 Step 6: Setting ownership for $GP_BROADCOM_DIR and $GP_SYMLINK"
  chown -R "$GP_USER:$GP_USER" "$GP_BROADCOM_DIR"
  chown -h "$GP_USER:$GP_USER" "$GP_SYMLINK"
  echo "✅ Ownership set."
fi

echo "✅ Rollback complete. Broadcom Greenplum restored."
echo "📣 Next step: run the restart script as gpadmin"


