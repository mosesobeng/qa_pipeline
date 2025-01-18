from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
from google.cloud import bigquery
from google.oauth2 import service_account
import json
import os
import requests
import pandas as pd

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
    'pipeline_customer_subscriptions',
    default_args=default_args,
    description='ETL pipeline to ingest nested JSON into BigQuery with partitioning by date',
    schedule_interval='@daily',
    start_date=datetime(2023, 1, 1),
    catchup=False,
)

def extract_data_from_gcs_raw_layer(**kwargs):
    gcs_url = 'https://storage.googleapis.com/klaus_bucket_raw_data/qa/senior_data_engineer_test/etl.json'
    try:
        response = requests.get(gcs_url)
        response.raise_for_status()
        file_content = response.text

        # Preprocessing steps
        file_content = file_content.replace("'[", "[").replace("]'", "]")
        print("Replaced improperly formatted array strings.")
        file_content = file_content.replace("'", "\"")
        print("Replaced single quotes with double quotes.")
        file_content = file_content.replace("True", "true").replace("False", "false")
        print("Replaced Python's boolean values with JSON's boolean values.")

        data = json.loads(file_content)
        return data  
    except requests.HTTPError as http_err:
        raise ValueError(f"HTTP error occurred while fetching JSON from {gcs_url}: {http_err}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON format from {gcs_url}: {e}")
    except Exception as e:
        raise ValueError(f"An error occurred while fetching the JSON file: {e}")

def normalize_gcs_json_to_df(ti, **kwargs):
    data = ti.xcom_pull(task_ids='extract_data_from_gcs_raw_layer')
    df = pd.json_normalize(data, record_path=['list'], sep='_')
    
    # Convert Unix timestamp to date without time, store as 'dt_customer_signup_date'
    if 'customer_created_at' in df.columns:
        df['dt_customer_signup_date'] = pd.to_datetime(df['customer_created_at'], unit='s').dt.date
    
    return df  

def load_data_to_bq_silver_layer(ti, **kwargs):
    project_id = "zendesk-assessment"  
    dataset_id = "raw"  
    table_id = "customer_subscriptions"  
    full_table_id = f"{project_id}.{dataset_id}.{table_id}"
    staging_table_id = f"{project_id}.{dataset_id}.temp_{table_id}"

    df = ti.xcom_pull(task_ids='normalize_gcs_json_to_df')
    if df is None or len(df) == 0:
        print("No data to load. Skipping load_data_to_bq_silver_layer.")
        return

    print(f"DataFrame to load:\n{df.head()}")

    credentials = service_account.Credentials.from_service_account_file(service_account_path)
    client = bigquery.Client(credentials=credentials, project=project_id)

    # Check if target table exists
    table_exists = True
    try:
        client.get_table(full_table_id)
    except Exception:
        table_exists = False
        print(f"Target table {full_table_id} does not exist. Will perform initial load without MERGE.")

    if not table_exists:
        try:
            job_config = bigquery.LoadJobConfig(
                write_disposition="WRITE_TRUNCATE",
                time_partitioning=bigquery.TimePartitioning(
                    type_=bigquery.TimePartitioningType.DAY,
                    field="dt_customer_signup_date"
                )
            )
            load_job = client.load_table_from_dataframe(
                dataframe=df,
                destination=full_table_id,
                job_config=job_config
            )
            load_job.result()
            print(f"Data successfully loaded into new partitioned BigQuery table: {full_table_id}")
        except Exception as e:
            print(f"An error occurred while loading data into BigQuery: {e}")
        return

    try:
        job_config = bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE")
        load_job = client.load_table_from_dataframe(
            dataframe=df,
            destination=staging_table_id,
            job_config=job_config,
        )
        load_job.result()
        print(f"Data successfully loaded into staging table: {staging_table_id}")
    except Exception as e:
        print(f"Error loading data to staging table: {e}")
        return

    columns_list = list(df.columns)
    columns = ", ".join(columns_list)
    values = ", ".join([f"S.{col}" for col in columns_list])
    # Exclude 'subscription_id' and 'dt_customer_signup_date' from updates
    update_columns = ", ".join([f"T.{col} = S.{col}" for col in columns_list if col not in ["subscription_id", "dt_customer_signup_date"]])

    merge_query = f"""
    MERGE `{full_table_id}` T
    USING `{staging_table_id}` S
    ON T.subscription_id = S.subscription_id
    WHEN MATCHED AND (
            T.subscription_updated_at <> S.subscription_updated_at 
         OR T.customer_updated_at <> S.customer_updated_at
        ) THEN
      UPDATE SET {update_columns}
    WHEN NOT MATCHED THEN
      INSERT ({columns}) VALUES ({values})
    """

    try:
        merge_job = client.query(merge_query)
        merge_job.result()
        print(f"MERGE query executed successfully on table: {full_table_id}")
    except Exception as e:
        print(f"An error occurred during the MERGE operation: {e}")
        return

    try:
        client.delete_table(staging_table_id, not_found_ok=True)
        print(f"Staging table {staging_table_id} deleted successfully.")
    except Exception as e:
        print(f"Could not delete staging table {staging_table_id}: {e}")

    print(f"Loaded {len(df)} rows into {full_table_id} using MERGE.")

# Define the DAG tasks
extract_task = PythonOperator(
    task_id='extract_data_from_gcs_raw_layer',
    python_callable=extract_data_from_gcs_raw_layer,
    dag=dag,
)

transform_task = PythonOperator(
    task_id='normalize_gcs_json_to_df',
    python_callable=normalize_gcs_json_to_df,
    provide_context=True,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_data_to_bq_silver_layer',
    python_callable=load_data_to_bq_silver_layer,
    provide_context=True,
    dag=dag,
)

extract_task >> transform_task >> load_task
