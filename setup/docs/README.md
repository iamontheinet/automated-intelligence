# Setup Documentation & Maintenance Scripts

This directory contains reference documentation and maintenance scripts for the core setup infrastructure.

## Documentation

### Dynamic Tables
- `DYNAMIC_TABLE_CONFIGURATION.md` - Configuration reference for the 3-tier Dynamic Tables pipeline
- `DYNAMIC_TABLE_LAG_FIX.md` - Troubleshooting guide for lag configuration issues

**Covers:**
- TARGET_LAG settings (time-based vs DOWNSTREAM)
- Refresh behavior and cascading
- Performance optimization
- Common configuration mistakes

## Maintenance Scripts

⚠️ **Use with caution** - These scripts modify system configuration or reset data.

### Dynamic Tables Configuration
- `fix_dynamic_table_lags.sql` - Fix TARGET_LAG settings for proper cascading
- `set_realtime_lag.sql` - Configure Dynamic Tables for real-time (1 second) lag

**When to use:**
- After modifying Dynamic Tables structure
- When refresh cascading is not working correctly
- For demo scenarios requiring sub-second freshness

### Data Management
- `reset_tables.sql` - Reset and recreate tables for fresh start
- `migrate_to_uuid.sql` - Migration script for UUID implementation (historical)

**When to use:**
- `reset_tables.sql`: When you need to clear data and start fresh for demos
- `migrate_to_uuid.sql`: Likely already applied (historical migration)

## Usage

### Read Documentation
```bash
# View configuration reference
cat setup/docs/DYNAMIC_TABLE_CONFIGURATION.md

# View troubleshooting guide
cat setup/docs/DYNAMIC_TABLE_LAG_FIX.md
```

### Run Maintenance Scripts
```bash
# Fix Dynamic Table lag settings
snow sql -f setup/docs/fix_dynamic_table_lags.sql -c dash-builder-si

# Set real-time lag (for demos)
snow sql -f setup/docs/set_realtime_lag.sql -c dash-builder-si

# Reset tables (⚠️ deletes data!)
snow sql -f setup/docs/reset_tables.sql -c dash-builder-si
```

## When to Use These

**Documentation:**
- When configuring Dynamic Tables
- When debugging refresh issues
- When understanding pipeline architecture

**Maintenance Scripts:**
- ❌ **NOT** part of initial setup
- ✅ Use for troubleshooting or reconfiguration
- ✅ Use for demo resets

## Related Resources

- Core setup: `setup/setup.sql` (run this first)
- Examples: `setup/examples/` (tutorials and learning materials)
- Interactive tutorial: `setup/examples/Dash_AI_DT.ipynb`
