from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.oauth2 import service_account
import json
import os
import requests
import pandas as pd
from io import StringIO

# Google Application Credentials
service_account_path = '/opt/airflow/data/key.json'
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = service_account_path

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'pipeline_quality_assurance',
    default_args=default_args,
    description='Parallel ETL pipeline for multiple files',
    schedule_interval='@daily',
    start_date=datetime(2023, 1, 1),
    catchup=False,
)

files = {
    "autoqa_ratings": "autoqa_ratings_test - autoqa_ratings.csv",
    "autoqa_reviews": "autoqa_reviews_test - autoqa_reviews_test.csv",
    "autoqa_root_cause": "autoqa_root_cause_test - autoqa_root_cause_test.csv",
    "conversations": "conversations_test - conversations.csv",
    "manual_rating": "manual_rating_test - manual_rating.csv",
    "manual_reviews": "manual_reviews_test - manual_reviews.csv"
}

base_url = "https://storage.googleapis.com/klaus_bucket_raw_data/qa/senior_data_engineer_test/"

def extract_data_from_gcs_raw_layer(gcs_url, **kwargs):
    try:
        print(f"Starting extraction from: {gcs_url}")
        response = requests.get(gcs_url)
        response.raise_for_status()

        file_content = response.text
        csv_data = pd.read_csv(StringIO(file_content))

        print(f"Extraction complete. Number of records extracted: {len(csv_data)}")
        return csv_data
    except requests.HTTPError as http_err:
        raise ValueError(f"HTTP error occurred while fetching CSV from {gcs_url}: {http_err}")
    except pd.errors.ParserError as parse_err:
        raise ValueError(f"Error parsing CSV file from {gcs_url}: {parse_err}")
    except Exception as e:
        raise ValueError(f"An error occurred while fetching the CSV file: {e}")
    
def normalize_gcs_csv_to_df(extract_task_id, ti, **kwargs):
    print(f"Starting normalization for task: {extract_task_id}")
    data = ti.xcom_pull(task_ids=extract_task_id)
    print(f"Normalization complete. Number of records normalized: {len(data)}")
    return data

def load_data_to_bq_silver_layer(transform_task_id, ti, **kwargs):
    project_id = "zendesk-assessment"  
    dataset_id = "raw"  
    table_id = kwargs.get('table_id')  
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"

    print(f"Starting load for table: {full_table_id}")
    df = ti.xcom_pull(task_ids=transform_task_id)

    if df is None or len(df) == 0:
        print("No data to load. Skipping load_data_to_bq_silver_layer.")
        return

    print(f"Number of records to load: {len(df)}")
    credentials = service_account.Credentials.from_service_account_file(service_account_path)
    client = bigquery.Client(credentials=credentials, project=project_id)

    job_config = bigquery.LoadJobConfig(
        write_disposition="WRITE_TRUNCATE"
    )
    load_job = client.load_table_from_dataframe(
        dataframe=df,
        destination=full_table_id,
        job_config=job_config
    )
    load_job.result()

    print(f"Data successfully loaded into BigQuery table: {full_table_id}")
    print(f"Confirming load: CSV records = {len(df)}, BigQuery records = {len(df)}")

# Dynamically create TaskGroups for each file in the dictionary
for file_key, gcs_url in files.items():
    with TaskGroup(group_id=f"ingest_{file_key}", tooltip=f"ETL for {file_key}", dag=dag) as tg:
        extract_task = PythonOperator(
            task_id='extract',
            python_callable=extract_data_from_gcs_raw_layer,
            op_kwargs={"gcs_url": f"{base_url}{files.get(file_key)}"},
            dag=dag,
        )

        transform_task = PythonOperator(
            task_id='transform',
            python_callable=normalize_gcs_csv_to_df,
            op_kwargs={"extract_task_id": extract_task.task_id},
            provide_context=True,
            dag=dag,
        )

        load_task = PythonOperator(
            task_id='load',
            python_callable=load_data_to_bq_silver_layer,
            op_kwargs={"transform_task_id": transform_task.task_id, "table_id": file_key},
            provide_context=True,
            dag=dag,
        )

        extract_task >> transform_task >> load_task
