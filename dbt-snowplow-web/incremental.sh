#!/bin/bash

# Set DBT_TARGET environment variable
export DBT_TARGET="embucket"

# Determine which Python command to use
echo "###############################"
echo ""
echo "Determining which Python command to use..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "Error: Neither python3 nor python found. Please install Python."
    exit 1
fi
echo ""

# Creating virtual environment
echo "###############################"
echo ""
echo "Creating virtual environment with $PYTHON_CMD..."
$PYTHON_CMD -m venv env
source env/bin/activate
echo ""

# Install requirements
echo ""
echo "###############################"
echo ""
echo "Installing the requirements"
$PYTHON_CMD -m pip install --upgrade pip >/dev/null 2>&1
pip install -r requirements.txt >/dev/null 2>&1
echo ""
echo "###############################"
echo ""
# Set incremental flag from command line argument, default to true
is_incremental=${1:-false}
# Set number of rows to generate, default to 1000
num_rows=${2:-10000}

echo "Setting up Docker container"
./setup_docker.sh

# Function to check if Docker container is running
check_docker_container() {
    echo "Checking if Docker container 'em' is running..."
    if docker ps --format "table {{.Names}}" | grep -q "^em$"; then
        echo "✓ Docker container 'em' is running"
        return 0
    else
        echo "⚠ Docker container 'em' is not running"
        return 1
    fi
}

# Function to wait for container to be running
wait_for_container() {
    local max_attempts=30  # Wait up to 5 minutes (30 * 10 seconds)
    local attempt=1
    
    echo "Waiting for Docker container 'em' to be in running state..."
    
    while [ $attempt -le $max_attempts ]; do
        if check_docker_container; then
            echo "✓ Docker container 'em' is now running (attempt $attempt/$max_attempts)"
            return 0
        else
            echo "⏳ Container not ready yet, waiting 10 seconds... (attempt $attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo "❌ Error: Docker container 'em' failed to start within 5 minutes"
    return 1
}

# Wait for container to be running
if wait_for_container; then
    echo "✓ Docker container setup completed successfully"
else
    echo "❌ Error: Docker container failed to start after waiting"
    exit 1
fi
echo ""
echo "###############################"
echo ""


# FIRST RUN
echo "Generating events"
$PYTHON_CMD gen_events.py $num_rows

echo "Loading events"
$PYTHON_CMD load_events.py events_yesterday.csv

echo "Running dbt"
./run_snowplow_web.sh

# Update the errors log and run results
echo "###############################"
echo ""
echo "Updating the errors log and total results"
if [ "$DBT_TARGET" = "embucket" ]; then
   ./statistics.sh
fi
echo ""

# Generate assets after the run
echo "###############################"
echo ""
echo "Updating the chart result"
if [ "$DBT_TARGET" = "embucket" ]; then
   $PYTHON_CMD generate_dbt_test_assets.py --output-dir dbt-snowplow-web/assets --errors-file dbt-snowplow-web/assets/top_errors.txt
fi
echo ""
echo "###############################"
echo ""

if [ "$is_incremental" == true ]; then

# SECOND RUN INCEREMENTAL

echo "Loading events"
$PYTHON_CMD load_events.py events_today.csv

echo "Running dbt"
./run_snowplow_web.sh

# Update the errors log and run results
echo "###############################"
echo ""
echo "Updating the errors log and total results"
if [ "$DBT_TARGET" = "embucket" ]; then
   ./statistics.sh
fi
echo ""

# Generate assets after the run
echo "###############################"
echo ""
echo "Updating the chart result"
if [ "$DBT_TARGET" = "embucket" ]; then
   $PYTHON_CMD generate_dbt_test_assets.py --output-dir dbt-snowplow-web/assets --errors-file dbt-snowplow-web/assets/top_errors.txt
fi
echo ""
echo "###############################"
echo ""

fi
