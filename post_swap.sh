#!/bin/bash
# post_swap.sh — Run as gpadmin after any swap (EDB or Broadcom)

# Load external configuration
source "$(dirname "$0")/config.env"

# Use dynamic GPHOME from symlink
export GPHOME="$GPHOME_SYMLINK"
export PATH="$GPHOME/bin:$PATH"
export LD_LIBRARY_PATH="$GPHOME/lib:$LD_LIBRARY_PATH"
source "$GPHOME/greenplum_path.sh"

# Run post-swap row count
echo "🧮 Running post-swap row count across all databases..."

for db in $(psql -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn ORDER BY 1;"); do
  echo "▶️ Running count_rows_all_fx_uat() in $db..."
  psql -d "$db" -c "SELECT count_rows_all_fx_uat();"
done

# Row diff validation SQL
echo "📊 To validate row consistency, run this in each database:"
cat <<'EOF'
SELECT 
    a.schema_name, a.table_name,
    a.row_count AS before_swap,
    b.row_count AS after_swap,
    b.row_count - a.row_count AS diff
FROM 
    (SELECT * FROM schema_table_counts WHERE run_timestamp = (SELECT MIN(run_timestamp) FROM schema_table_counts)) a
JOIN 
    (SELECT * FROM schema_table_counts WHERE run_timestamp = (SELECT MAX(run_timestamp) FROM schema_table_counts)) b
USING (schema_name, table_name)
WHERE a.row_count != b.row_count;
EOF

echo "✅ Post-swap validation completed."
