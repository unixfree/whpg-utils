# swap_edb_to_broadcom_pxf.sh
# Run as root — Multi-node rollback from EDB WarehousePG to Broadcom, including PXF rollback

set -euo pipefail
trap 'echo "❌ ERROR at line $LINENO. Exiting multi-node rollback." >&2; exit 1' ERR

# Load shared config
source "$(dirname "$0")/config.env"

STEP_START=${1:-1}

echo "🔁 Starting multi-node rollback from EDB to Broadcom (from step $STEP_START)..."
mkdir -p "$SWAP_LOG_DIR"
chmod -R 777 "$SWAP_LOG_DIR"

########################################
# Step 1: Pre-Swap Row Count (Master)
########################################
if [ "$STEP_START" -le 1 ]; then
  echo -e "\n📋 [Step 1] Pre-swap row count on master node"
  su - "$GP_USER" -c "$PRE_SWAP" | tee "$SWAP_LOG_DIR/multi_step1_pre_swap.log"
fi

########################################
# Step 2: Gather Host & Segment Info
########################################
if [ "$STEP_START" -le 2 ]; then
  echo -e "\n📋 [Step 2] Collecting segment and host info"
  su - "$GP_USER" -c "psql -At -d postgres -f /home/gpadmin/query.sql" > "$TMP_FILE_SEGMENTS"
  su - "$GP_USER" -c "psql -At -d postgres -f /home/gpadmin/hostname.sql" > "$TMP_FILE_HOSTS"
fi

########################################
# Step 3: Stop Cluster and Stop PXF
########################################
if [ "$STEP_START" -le 3 ]; then
  echo -e "\n🛑 [Step 3] Stopping Greenplum cluster and PXF"

  echo "⛔ Stopping PXF on all nodes"
  su - "$GP_USER" -c "source ~/.bashrc && pxf cluster stop" | tee "$SWAP_LOG_DIR/multi_step3_pxf_stop.log"

  echo "🛑 Stopping Greenplum cluster"
  su - "$GP_USER" -c "gpstop -M fast -a" | tee "$SWAP_LOG_DIR/multi_step3_gpstop.log"
fi

########################################
# Step 4a: Binary Rollback Per Host
########################################
if [ "$STEP_START" -le 4 ]; then
  echo -e "\n🔄 [Step 4a] Rolling back binaries on all hosts"
  mapfile -t host_lines < "$TMP_FILE_HOSTS"
  for host in "${host_lines[@]}"; do
    echo -e "\n🔧 Connecting to host: \e[1;34m$host\e[0m"
    echo "📦 Rolling back binaries..."
    su - "$GP_USER" -c "ssh -tt -o StrictHostKeyChecking=no $GP_USER@$host 'sudo $SWAP_SCRIPT_E_TO_B'" | tee "$SWAP_LOG_DIR/${host}_swap_back.log"
  done

  ########################################
  # Step 4b: Update postgresql.conf
  ########################################
  echo -e "\n⚙️  [Step 4b] Updating postgresql.conf on all segment directories"
  mapfile -t segment_lines < "$TMP_FILE_SEGMENTS"
  for line in "${segment_lines[@]}"; do
    host=$(echo "$line" | cut -d'|' -f1)
    dir=$(echo "$line" | cut -d'|' -f2)
    echo -e "\n🔧 Connecting to segment host: \e[1;34m$host\e[0m"
    echo "🛩️  Updating shared_preload_libraries in: $dir"
    su - "$GP_USER" -c "ssh -tt -o StrictHostKeyChecking=no $GP_USER@$host '$UPDATE_SCRIPT \"$dir\" \"\" \"metrics_collector\"'" | tee -a "$SWAP_LOG_DIR/${host}_conf_restore.log"
  done
fi


########################################
# Step 5 Reinstall and Register Broadcom PXF
########################################
if [ "$STEP_START" -le 5 ]; then
  echo -e "\n🔌 [Step 5] Reinstalling and re-registering Broadcom PXF"

  mapfile -t host_lines < "$TMP_FILE_HOSTS"

  echo "📦 Installing PXF on all hosts"
  for host in "${host_lines[@]}"; do
    echo -e "\n🔧 Installing PXF on: \e[1;34m$host\e[0m"
    su - "$GP_USER" -c "ssh -tt $GP_USER@$host 'sudo rpm -ivh /home/gpadmin/$(basename $BROADCOM_PXF_RPM)'"
    su - "$GP_USER" -c "ssh -tt $GP_USER@$host 'sudo chown -R $GP_USER:$GP_GROUP $PXF_HOME_NEW'"
    su - "$GP_USER" -c "ssh -tt $GP_USER@$host 'sudo ln -sfn $PXF_HOME_NEW /usr/local/whpg-pxf-6'"
    su - "$GP_USER" -c "ssh -tt $GP_USER@$host 'sudo chown -R $GP_USER:$GP_GROUP /usr/local/whpg-pxf-6'"
  done

  echo "🧩 Updating .bashrc with Broadcom PXF paths"
  su - "$GP_USER" -c "sed -i '/export PXF_HOME=/d' ~/.bashrc"
  su - "$GP_USER" -c "sed -i '/export PXF_BASE=/d' ~/.bashrc"
  su - "$GP_USER" -c "sed -i '/export PATH=.*pxf.*bin/d' ~/.bashrc"
  su - "$GP_USER" -c "echo 'export PXF_HOME=$PXF_HOME_NEW' >> ~/.bashrc"
  su - "$GP_USER" -c "echo 'export PXF_BASE=$PXF_BASE' >> ~/.bashrc"
  su - "$GP_USER" -c "echo 'export PATH=\$PXF_HOME/bin:\$PATH' >> ~/.bashrc"


fi


########################################
# Step 6: Start Greenplum Cluster
########################################
if [ "$STEP_START" -le 6 ]; then
  echo -e "\n🚀 [Step 6] Starting Greenplum cluster"
  su - "$GP_USER" -c "gpstart -a" | tee "$SWAP_LOG_DIR/multi_step6_gpstart.log"

  echo "🔁 Running: pxf cluster register"
  su - "$GP_USER" -c "source ~/.bashrc && PXF_BASE=$PXF_BASE PXF_HOME=$PXF_HOME_NEW pxf cluster register" | tee "$SWAP_LOG_DIR/multi_step5_pxf_register.log"
  echo "🚀 Starting PXF cluster"
  su - "$GP_USER" -c "source ~/.bashrc && PXF_BASE=$PXF_BASE PXF_HOME=$PXF_HOME_NEW pxf cluster start" | tee "$SWAP_LOG_DIR/multi_step6_pxf_start.log"
fi


########################################
# Step 7: Post-Swap Row Count (Validation)
########################################
if [ "$STEP_START" -le 7 ]; then
  echo -e "\n📊 [Step 7] Post-swap row count for validation"
  su - "$GP_USER" -c "$POST_SWAP" | tee "$SWAP_LOG_DIR/multi_step7_post_swap.log"
fi


########################################
# Final
########################################
echo -e "\n✅ Rollback from EDB to Broadcom complete including PXF."
echo "📁 Logs stored in: $SWAP_LOG_DIR"

