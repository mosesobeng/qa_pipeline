import os
import yaml

# Configuration details
profiles_content = {
    "bigquery": {
        "target": "dev",
        "outputs": {
            "dev": {
                "type": "bigquery",
                "method": "service-account",
                "project": "zendesk-assessment",
                "dataset": "dw", 
                "threads": 4,  
                "keyfile": "~/.dbt/keyfile.json"  
               
            }
        }
    }
}

# Define the file path for ~/.dbt/profiles.yml
dbt_dir = os.path.expanduser("~/.dbt")
profiles_path = os.path.join(dbt_dir, "profiles.yml")

# Ensure the ~/.dbt directory exists
os.makedirs(dbt_dir, exist_ok=True)

# Write the YAML content to the profiles.yml file
with open(profiles_path, "w") as profiles_file:
    yaml.dump(profiles_content, profiles_file, default_flow_style=False)

print(f"DBT profiles.yml has been created/updated at {profiles_path}")
