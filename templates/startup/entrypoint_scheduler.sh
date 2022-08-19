#!/bin/bash
echo "[INFO] Starting up airflow scheduler"
# Sanity check the dags
echo "[INFO] Available dags:"
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
echo "[INFO] Installing awscli"
python -m pip install awscli --user
python -m pip install poetry --user

# Install python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/dags/poetry.lock" ]]; then
    echo "[INFO] poetry.lock provided. Installing packages with poetry install."
    python -m poetry install
fi
# Run the airflow scheduler
echo "[INFO] Running airflow scheduler"
airflow scheduler