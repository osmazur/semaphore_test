#!/bin/bash

# Setup script for Embucket Docker container with COMPLETELY CLEAN environment
# This script removes all persistent data and creates a fresh container

echo "=== Setting up Embucket Docker Container (CLEAN) ==="

# Determine which Python command to use
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "Error: Neither python3 nor python found. Please install Python."
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute Python-based Docker setup
echo "Running Python-based Docker setup..."
$PYTHON_CMD "$SCRIPT_DIR/setup_docker_python.py"

# Check the exit code from the Python script
if [ $? -eq 0 ]; then
    echo "✓ Docker setup completed successfully"
    exit 0
else
    echo "❌ Docker setup failed"
    exit 1
fi 
