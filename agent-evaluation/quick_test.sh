#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  QUICK TEST - business_insights_agent Evaluation           ║"
echo "║  This will run a minimal test (2 queries) in ~30 seconds   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if in correct directory
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: Run this from the agent-evaluation directory"
    echo "   cd automated-intelligence/agent-evaluation"
    exit 1
fi

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

# Setup environment if needed
if [ ! -d "venv" ]; then
    echo "[1/4] Creating Python environment..."
    $PYTHON_CMD -m venv venv
    source venv/bin/activate
    pip install --quiet --upgrade pip
    pip install --quiet -r requirements.txt
    echo "✓ Environment created"
else
    echo "[1/4] Using existing environment..."
    source venv/bin/activate
    echo "✓ Environment activated"
fi

# Set environment variable
export TRULENS_OTEL_TRACING=1

echo ""
echo "[2/4] Checking Snowflake connection..."
$PYTHON_CMD << 'EOF'
from snowflake.snowpark import Session
try:
    session = Session.builder.configs({"connection_name": "dash-builder-si"}).create()
    print(f"✓ Connected as {session.get_current_role()}")
    session.close()
except Exception as e:
    print(f"❌ Connection failed: {e}")
    exit(1)
EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "Fix: Check your Snowflake connection 'dash-builder-si'"
    exit 1
fi

echo ""
echo "[3/4] Running quick test (2 queries)..."
echo "      This will call business_insights_agent with real queries"
echo ""

$PYTHON_CMD quick_test.py

echo ""
echo "[4/4] ✅ Test complete!"
echo ""
echo "Next steps:"
echo "  1. View results in Snowsight:"
echo "     AI & ML > Evaluations > business_insights_agent"
echo ""
echo "  2. Run full evaluation (8 queries):"
echo "     $PYTHON_CMD evaluate_cortex_agent.py"
echo ""
