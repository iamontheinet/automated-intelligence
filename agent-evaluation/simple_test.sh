#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  SIMPLE TEST - business_insights_agent                     ║"
echo "║  Quick test with minimal dependencies (~15 seconds)        ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Check if required packages are installed
echo ""
echo "Checking dependencies..."

# Try to use existing venv if it exists
if [ -d "venv" ]; then
    echo "Using existing virtual environment..."
    source venv/bin/activate
else
    echo "No virtual environment found."
    echo "Installing minimal packages with system Python..."
    echo ""
fi

# Run the simple test
python3 simple_test.py

# Capture exit code
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Test completed successfully!"
else
    echo "⚠️  Test had issues (see above for details)"
fi

exit $EXIT_CODE
