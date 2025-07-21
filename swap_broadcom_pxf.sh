#!/bin/bash
# swap_broadcom_pxf.sh
# Run as root to replace Broadcom Greenplum and PXF with EDB WarehousePG and PXF

set -euo pipefail
trap 'echo "❌ ERROR: Script failed at line $LINENO. Exiting."; exit 1' ERR

# Load shared configuration
CONFIG_FILE="$(dirname "$0")/config.env"
[ -f "$CONFIG_FILE" ] || { echo "❌ Missing config file: $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"

STEP_START=${1:-0}

# === LOGGING ===
mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1

echo "♻️ Starting full Broadcom ➜ EDB WarehousePG + PXF replacement (from step $STEP_START)..."

# Step 1: Backup Greenplum and PXF directories
if [ "$STEP_START" -le 1 ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)

  echo "📁 Step 1: Backing up Broadcom Greenplum directory: $GP_BROADCOM_DIR"
  if [ -d "$GP_BROADCOM_DIR" ]; then
    BACKUP_DIR="${GP_BROADCOM_DIR}_broadcom_${TIMESTAMP}"
    mv "$GP_BROADCOM_DIR" "$BACKUP_DIR"
    echo "✔️ Greenplum backed up to $BACKUP_DIR"
  else
    echo "⚠️ $GP_BROADCOM_DIR not found, skipping."
  fi

  echo "📁 Backing up PXF_BASE: $PXF_BASE"
  if [ -d "$PXF_BASE" ]; then
    PXF_BACKUP="${PXF_BASE}_broadcom_${TIMESTAMP}"
    cp -a "$PXF_BASE" "$PXF_BACKUP"
    echo "✔️ PXF_BASE backed up to $PXF_BACKUP"
  else
    echo "⚠️ $PXF_BASE not found, skipping."
  fi

  echo "📁 Backing up PXF_HOME: $PXF_HOME"
  if [ -d "$PXF_HOME" ]; then
    PXF_HOME_BACKUP="${PXF_HOME}_broadcom_${TIMESTAMP}"
    cp -a "$PXF_HOME" "$PXF_HOME_BACKUP"
    echo "✔️ PXF_HOME backed up to $PXF_HOME_BACKUP"
  else
    echo "⚠️ $PXF_HOME not found, skipping."
  fi
fi

# Step 2: Remove Broadcom RPMs
if [ "$STEP_START" -le 2 ]; then
  echo "🧹 Step 2: Removing Broadcom Greenplum and PXF RPMs..."
  BROADCOM_RPMS=$(rpm -qa | grep -E 'greenplum|pxf' || true)
  if [ -n "$BROADCOM_RPMS" ]; then
    echo "$BROADCOM_RPMS" | tac | xargs -r rpm -e --nodeps
    echo "✅ Broadcom RPMs removed."
  else
    echo "⚠️ No matching RPMs found."
  fi
fi

# Step 3: Install WarehousePG
if [ "$STEP_START" -le 3 ]; then
  echo "📦 Step 3: Installing WarehousePG RPM: $RPM_GP"
  [ -f "$RPM_GP" ] || { echo "❌ RPM not found: $RPM_GP"; exit 1; }
  rpm -ivh "$RPM_GP"
fi

# Step 4: Update Greenplum symlink
if [ "$STEP_START" -le 4 ]; then
  echo "🔗 Step 4: Updating symlink $GP_SYMLINK → $GP_NEW_DIR"
  [ -e "$GP_SYMLINK" ] && rm -f "$GP_SYMLINK"
  ln -s "$GP_NEW_DIR" "$GP_SYMLINK"
  echo "✔️ Symlink created."
fi

# Step 5: Fix ownership
if [ "$STEP_START" -le 5 ]; then
  echo "🔧 Step 5: Setting ownership to $GP_USER"
  chown -R "$GP_USER:$GP_USER" "$GP_NEW_DIR"
  chown -h "$GP_USER:$GP_USER" "$GP_SYMLINK"
fi

# Step 6: Install backup utility RPM
if [ "$STEP_START" -le 6 ]; then
  echo "💾 Step 6: Installing backup utility RPM: $RPM_GP_BACKUP"
  if [ -f "$RPM_GP_BACKUP" ]; then
    rpm -ivh "$RPM_GP_BACKUP"
  else
    echo "⚠️ Backup RPM not found: $RPM_GP_BACKUP. Skipping."
  fi
fi

# Step 7: Cleanup old Greenplum backups
if [ "$STEP_START" -le 7 ]; then
  echo "🧹 Step 7: Cleaning old Greenplum backups (keep last 3)"
  find "$GP_PARENT_DIR" -maxdepth 1 -type d -name "greenplum-db-6.28.2_broadcom_*" \
    | sort -r | tail -n +4 | while read -r dir; do
      echo "🗑️ Deleting: $dir"
      rm -rf "$dir"
  done
fi

# Step 8: Cleanup old PXF_BASE backups
if [ "$STEP_START" -le 8 ]; then
  echo "🧹 Step 8: Cleaning old PXF_BASE backups (keep last 3)"
  find "$PXF_BASE_PARENT" -maxdepth 1 -type d -name "pxf_broadcom_*" \
    | sort -r | tail -n +4 | while read -r dir; do
      echo "🗑️ Deleting: $dir"
      rm -rf "$dir"
  done
fi

# Step 9: Cleanup old PXF_HOME backups
if [ "$STEP_START" -le 9 ]; then
  echo "🧹 Step 9: Cleaning old PXF_HOME backups (keep last 3)"
  find "$PXF_HOME_PARENT" -maxdepth 1 -type d -name "pxf-gp6_broadcom_*" \
    | sort -r | tail -n +4 | while read -r dir; do
      echo "🗑️ Deleting: $dir"
      rm -rf "$dir"
  done
fi

echo "✅ Completed full Broadcom ➜ EDB WarehousePG + PXF replacement"
echo "📜 Full log: $LOGFILE"
