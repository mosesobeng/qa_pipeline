import os 
from datetime import datetime 
from pathlib import Path 

from cosmos import DbtDag, ProjectConfig, ProfileConfig 
from cosmos.profiles import GoogleCloudServiceAccountFileProfileMapping 

DEFAULT_DBT_ROOT_PATH = Path(__file__).parent / "dbt"

DBT_ROOT_PATH = Path(os.getenv("DBT_ROOT_PATH", DEFAULT_DBT_ROOT_PATH))

DBT_PROJECT_PATH = Path("/opt/airflow/dags/dbt")
CONNECTION_ID = "bigquery_conn"
DATASET_NAME = "dw"

profile_config = ProfileConfig(
    profile_name="dw_pipeline",
    target_name="dev",
    profile_mapping=GoogleCloudServiceAccountFileProfileMapping(
        conn_id=CONNECTION_ID,
        profile_args={
            "schema": DATASET_NAME,  
            "project": "zendesk-assessment", 
        },
    ),
)


transformation_data_warehouse = DbtDag( 
    # dbt/cosmos-specific parameters 
    project_config=ProjectConfig( 
        DBT_ROOT_PATH / "", 
    ), 
    profile_config=profile_config, 
    operator_args={ 
        "install_deps": True,
        "full_refresh": True,
    }, 
    # normal dag parameters 
    schedule_interval="@daily", 
    start_date=datetime(2023, 1, 1), 
    catchup=False, 
    dag_id="transformation_data_warehouse", 
    default_args={"retries": 2,'owner': 'Data Engineering'}, 
) 

