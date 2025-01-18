from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import os
import zipfile
import io
import requests
from cosmos import DbtDag, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import PostgresUserPasswordProfileMapping

def download_and_extract_to_public_gcs(**kwargs):
    """
    Downloads a ZIP file from a public Google Drive link, extracts its contents,
    and uploads them to a publicly accessible GCS bucket.

    Parameters:
        drive_url (str): The public Google Drive URL of the ZIP file.
        bucket_name (str): The name of the public GCS bucket.
        gcs_folder (str): The folder in the GCS bucket where files will be stored.
    """
    drive_url = kwargs['drive_url']
    bucket_name = kwargs['bucket_name']
    gcs_folder = kwargs['gcs_folder']

    try:
        # Parse the file ID from the Google Drive link
        if "id=" in drive_url:
            file_id = drive_url.split("id=")[-1]
        elif "d/" in drive_url:
            file_id = drive_url.split("d/")[1].split("/")[0]
        else:
            raise ValueError("Invalid Google Drive URL format.")

        # Construct the download URL
        download_url = f"https://drive.google.com/uc?export=download&id={file_id}"

        # Download the ZIP file
        print("Downloading the ZIP file...")
        response = requests.get(download_url, stream=True)
        response.raise_for_status()

        # Extract the contents of the ZIP file
        print("Extracting the ZIP file...")
        with zipfile.ZipFile(io.BytesIO(response.content)) as z:
            extracted_files = z.namelist()
            z.extractall("/tmp/extracted")

        print("Uploading files to GCS...")
        # Upload extracted files to GCS using a public endpoint
        for file_name in extracted_files:
            local_path = os.path.join("/tmp/extracted", file_name)
            if os.path.isfile(local_path):  # Only upload files, skip directories
                gcs_url = f"https://storage.googleapis.com/{bucket_name}/{gcs_folder}/{file_name}"
                with open(local_path, "rb") as file_data:
                    upload_response = requests.put(gcs_url, data=file_data)
                    if upload_response.status_code == 200:
                        print(f"Uploaded {file_name} to {gcs_url}")
                    else:
                        print(f"Failed to upload {file_name}: {upload_response.status_code} {upload_response.text}")

        print("All files have been uploaded to the public GCS bucket.")

    except Exception as e:
        print(f"An error occurred: {e}")

# Default arguments for the DAG
default_args = {
    'owner': 'Data Engineering',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
dag = DAG(
    'pipeline_gdrive_to_gcs',
    default_args=default_args,
    description='Download a ZIP from Google Drive, extract, and upload to GCS',
    schedule_interval=None,
    start_date=datetime(2025, 1, 17),
    catchup=False,
)

# Define the task
process_zip_task = PythonOperator(
    task_id='process_zip',
    python_callable=download_and_extract_to_public_gcs,
    op_kwargs={
        'drive_url': 'https://drive.google.com/file/d/1x-OCGj_l17cqH2BjVwN5n-InUX72Pun4/view',
        'bucket_name': 'klaus_bucket_raw_data',
        'gcs_folder': 'qa',
    },
    dag=dag,
)

# Set task dependencies
process_zip_task
