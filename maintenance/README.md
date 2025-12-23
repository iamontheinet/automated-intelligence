# Maintenance Scripts

This directory contains maintenance, migration, and troubleshooting scripts.

## Files

- `reset_tables.sql` - Reset and recreate tables for fresh start
- `migrate_to_uuid.sql` - Migration script for UUID implementation
- `fix_dynamic_table_lags.sql` - Fix lag configuration for Dynamic Tables
- `set_realtime_lag.sql` - Configure Dynamic Tables for real-time (1 second) lag

## Purpose

These scripts are used for maintenance operations, troubleshooting, and one-time migrations. They are **not** part of the initial setup process.

## Usage

⚠️ **Use with caution** - These scripts modify or reset data.

```bash
# Example: Reset tables for a fresh demo
snow sql -f maintenance/reset_tables.sql -c dash-builder-si

# Example: Fix Dynamic Table lag issues
snow sql -f maintenance/fix_dynamic_table_lags.sql -c dash-builder-si
```

## When to Use

- **reset_tables.sql**: When you need to clear data and start fresh
- **migrate_to_uuid.sql**: Historical migration script (likely already applied)
- **fix_dynamic_table_lags.sql**: When Dynamic Tables have incorrect lag settings
- **set_realtime_lag.sql**: When you need sub-second refresh for demos

See individual scripts for detailed comments and usage instructions.
