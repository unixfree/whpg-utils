#!/bin/bash

# Load external configuration
source "$(dirname "$0")/config.env"

# === INPUT VALIDATION ===
HOST="$1"
if [ -z "$HOST" ]; then
  echo "❌ Usage: $0 <hostname>"
  exit 1
fi

echo "🔧 Updating PXF setup on host: $HOST"

# 1. Fix ownership of PXF_HOME
su - "$GPADMIN_USER" -c "ssh -tt $GPADMIN_USER@$HOST 'sudo chown -R $GPADMIN_USER:$GPADMIN_USER $PXF_HOME'"

# 2. Update .bashrc remotely
su - "$GPADMIN_USER" -c "ssh -tt $GPADMIN_USER@$HOST '
  echo \"🧩 Updating .bashrc on \$(hostname)\"

  sed -i \"/export PXF_HOME=/d\" ~/.bashrc
  sed -i \"/export PXF_BASE=/d\" ~/.bashrc
  sed -i \"/export PATH=.*pxf.*bin/d\" ~/.bashrc

  echo \"export PXF_HOME=$PXF_HOME_NEW\" >> ~/.bashrc
  echo \"export PXF_BASE=$PXF_BASE\" >> ~/.bashrc
  echo \"export PATH=\\\$PXF_HOME/bin:\\\$PATH\" >> ~/.bashrc
'"
