#!/bin/bash
# pre_swap_rowcheck_gpadmin.sh
# Run as gpadmin before WarehousePG swap
# Drops and recreates schema_table_counts, logs execution time per DB

# Load config
source "$(dirname "$0")/config.env"

# Set up Greenplum environment
export GPHOME="$GPHOME_SYMLINK"
export PATH="$GPHOME/bin:$PATH"
export LD_LIBRARY_PATH="$GPHOME/lib:$LD_LIBRARY_PATH"
source "$GPHOME/greenplum_path.sh"

echo "📋 Gathering user databases..."
databases=$(psql -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn ORDER BY 1;")

for db in $databases; do
  echo "------------------------------------------------------"
  echo "🗂️  Processing database: $db"

  echo "🔄 Dropping and recreating table in $db..."
  psql -d "$db" <<'EOSQL'
  DROP TABLE IF EXISTS public.schema_table_counts;
  CREATE TABLE public.schema_table_counts (
    schema_name TEXT,
    table_name TEXT,
    row_count BIGINT,
    execution_time INTERVAL,
    run_timestamp TIMESTAMP DEFAULT now()
  ) DISTRIBUTED BY (schema_name, table_name);
EOSQL

  echo "📊 Creating count_rows_all_fx_uat() in $db..."
  psql -d "$db" <<'EOSQL'
  CREATE OR REPLACE FUNCTION count_rows_all_fx_uat()
  RETURNS VOID AS $$
  DECLARE 
      rec_schema RECORD;
      rec_table RECORD;
      start_time TIMESTAMP;
      end_time TIMESTAMP;
      execution_time INTERVAL;
      row_count BIGINT;
  BEGIN
      FOR rec_schema IN 
          SELECT n.nspname
          FROM pg_namespace n
          WHERE n.nspname NOT LIKE 'pg_%'
            AND n.nspname NOT IN ('information_schema')
            AND n.nspname NOT LIKE '%external%'
      LOOP
          FOR rec_table IN 
              SELECT c.relname
              FROM pg_class c
              JOIN pg_namespace n ON c.relnamespace = n.oid
              LEFT JOIN pg_inherits i ON c.oid = i.inhrelid
              WHERE i.inhrelid IS NULL AND c.relkind = 'r'
                AND n.nspname = rec_schema.nspname
          LOOP
              start_time := clock_timestamp();
              BEGIN
                  EXECUTE format('SELECT COUNT(*) FROM %I.%I', rec_schema.nspname, rec_table.relname) INTO row_count;
              EXCEPTION 
                  WHEN others THEN
                      RAISE WARNING 'Skipping %.%: %', rec_schema.nspname, rec_table.relname, SQLERRM;
                      CONTINUE;
              END;
              end_time := clock_timestamp();
              execution_time := end_time - start_time;

              INSERT INTO public.schema_table_counts (schema_name, table_name, row_count, execution_time)
              VALUES (rec_schema.nspname, rec_table.relname, row_count, execution_time);
          END LOOP;
      END LOOP;
  END $$ LANGUAGE plpgsql;
EOSQL

  echo "▶️ Running count_rows_all_fx_uat() in $db..."
  start_time=$(date +%s)

  psql -d "$db" -c "SELECT count_rows_all_fx_uat();"

  end_time=$(date +%s)
  duration=$((end_time - start_time))
  echo "⏱️  Completed $db in $duration seconds"
done

echo "✅ Pre-swap row count completed for all databases."
