#!/bin/bash
echo "[INFO] Starting up airflow webserver"
# sanity check the dags
echo "[INFO] Available dags:"
ls /opt/airflow/dags

# Install boto and awscli for the seed dag
echo "[INFO] Installing awscli"
python -m pip install awscli --user
python -m pip install poetry --user

aws configure set region ${REGION} --profile default
aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID} --profile default
aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY} --profile default

# Install python packages through req.txt and pip (if exists)
if [[ -f "${AIRFLOW_HOME}/dags/poetry.lock" ]]; then
    echo "[INFO] poetry.lock provided. Installing packages with poetry install."
    python -m poetry install
fi

export AIRFLOW__WEBSERVER__SECRET_KEY=$(openssl rand -hex 30)

# Run the airflow webserver
echo "[INFO] Running airflow webserver"
airflow webserver