#!/bin/bash

echo "=========================================="
echo "AI Observability Evaluation Setup"
echo "=========================================="
echo ""

# Find compatible Python version (3.9-3.12 required for TruLens)
PYTHON_CMD=""
for cmd in python3.11 python3.10 python3.9 python3.12; do
    if command -v $cmd &> /dev/null; then
        PYTHON_CMD=$cmd
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Error: TruLens requires Python 3.9-3.12"
    echo "   Your python3 is: $(python3 --version)"
    echo ""
    echo "   Install compatible Python:"
    echo "   brew install python@3.11"
    exit 1
fi

echo "Using Python: $($PYTHON_CMD --version)"
echo ""

# Create Python virtual environment
echo "[1/3] Creating Python virtual environment..."
$PYTHON_CMD -m venv venv

if [ ! -d "venv" ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi

# Activate virtual environment
echo "[2/3] Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "[3/3] Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Set environment variable for tracing
export TRULENS_OTEL_TRACING=1

echo ""
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
echo "To run evaluation:"
echo "  1. source venv/bin/activate"
echo "  2. export TRULENS_OTEL_TRACING=1"
echo "  3. python evaluate_order_analytics.py"
echo ""
echo "Prerequisites (run as ACCOUNTADMIN if needed):"
echo "  - CORTEX_USER database role"
echo "  - AI_OBSERVABILITY_EVENTS_LOOKUP application role"
echo "  - CREATE EXTERNAL AGENT privilege"
echo "  - CREATE TASK and EXECUTE TASK privileges"
echo ""
