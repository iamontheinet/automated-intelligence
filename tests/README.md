# Tests

This directory contains test scripts for validating data quality and system behavior.

## Files

- `test_data_quality.sql` - SQL-based data quality tests
- `test_data_quality.ipynb` - Jupyter notebook for data quality validation

## Purpose

Use these scripts to validate data quality, test Dynamic Tables, and ensure the system is functioning correctly after setup.

## Usage

Run these tests after completing setup to verify data integrity and pipeline health.

```bash
# Run SQL tests
snow sql -f tests/test_data_quality.sql -c dash-builder-si

# Or run notebook for detailed analysis
jupyter notebook tests/test_data_quality.ipynb
```
