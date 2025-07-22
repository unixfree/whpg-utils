# 🔄 Greenplum Swap Automation Scripts

This repository provides a fully automated, step-controlled rollback and swap system for replacing Broadcom Greenplum Database with EDB WarehousePG, and vice versa. It includes:

- RPM swap automation
- Configuration file updates (e.g., `postgresql.conf`)
- Pre/post validation of database row counts
- Symlink switching for Greenplum installation paths
- Safe logging, rollback, and metrics preservation
- Optional PXF component replacement

---

## 📂 Structure

| **File** | **Description** |
|----------|-----------------|
| `swap_broadcom_to_edb_pxf.sh` | Automates full migration from Broadcom Greenplum to EDB WarehousePG, including PXF |
| `swap_edb_to_broadcom_pxf.sh` | Rollback: Restores Broadcom Greenplum from EDB WarehousePG, including PXF |
| `swap_edb_pxf.sh` | Internal logic to install EDB binaries and configure PXF |
| `swap_broadcom_pxf.sh` | Internal logic to install Broadcom binaries and configure PXF |
| `update_shared_preload.sh` | Updates `shared_preload_libraries` in `postgresql.conf` |
| `remove_metric.sh` | Cleans up Greenplum metric configurations (e.g., gpperfmon) |
| `restore_metric.sh` | Restores original metric settings |
| `pre_swap.sh` | Collects row count and system info before the swap |
| `post_swap.sh` | Validates row counts and system integrity post swap |
| `query.sql` | SQL file used for row count validation |
| `hostname.sql` | Captures hostname and active instance info |
| `gp_nodes_segments.txt` | List of segment hostnames and roles for validation or targeting |
| `gp_hosts.txt` | Host inventory for orchestration |
| `extension.sql` | Placeholder for PostgreSQL extensions that need to be reloaded |
| `config.env` | Centralized environment variables and paths for the swap scripts |

---

## ✅ Prerequisites

- Must be executed as `root` unless otherwise stated.
- `gpadmin` user must be configured and able to run Greenplum commands.
- Required tools: `rpm`, `gppkg`, `gpstop`, `gpstart`, `psql`.
- RPMs and GPPKGs must be available in `/home/gpadmin/`.
- Passwordless SSH required for host orchestration (based on `gp_hosts.txt`).

---

## 🚀 Usage

### Prepare Swap. change config.env for your environment.. 
```bash
sudo vi ./whpg-util/config.env
```

### Swap from Broadcom ➜ EDB WarehousePG (with PXF)
```bash
sudo ./whpg-util/swap_broadcom_to_edb_pxf.sh
```

### Rollback: Swap from EDB ➜ Broadcom (with PXF)
```bash
sudo ../whpg-util/swap_edb_to_broadcom_pxf.sh
# whpg-utils
