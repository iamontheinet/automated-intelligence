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

⚠️ **Use with caution** - These scripts modify or reset data.

### Data Management
- `reset_tables.sql` - Reset and recreate tables for fresh start

**When to use:**
- When you need to clear data and start fresh for demos
- Truncates raw tables and recreates Dynamic Tables

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
