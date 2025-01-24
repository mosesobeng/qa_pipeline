


# QA Pipeline - Klaus Data Engineer Project

**Repo**: [github.com/mosesobeng/qa_pipeline](https://github.com/mosesobeng/qa_pipeline)

This file provides a top-level overview of the entire solution, referencing detailed documentation and code.

---

## 1. Project Structure

Below is a high-level layout:

- **airflow/**:
  - DAGs: 
    - `ingestion_gdrive_to_gcs.py`: Ingest Assessment ZIP data from Google Drive to GCS.
    - `ingestion_quality_assurance.py`: Load raw CSV to BigQuery.
    - `ingestion_customer_subscriptions.py`: JSON ingestion to BigQuery.
    - `transformation_data_warehouse.py`: Orchestrates dbt transformations.
- **dbt/**:
  - `models/marts/*`: Dimensions and Fact SQL models (e.g. `dim_team.sql`, `fact_autoqa_reviews.sql`).
  - `models/staging/*`: Staging references to raw tables (e.g. `stg_autoqa_reviews.sql`).
  - `schema.yml`, `sources.yml`: Testing & source definitions.
- **diagram/**:
  - `erd_non_modeled.mmd`, `erd_modeled.mmd`: Mermaid files for the ERDs.
- **docs/**:
  - `images/*`: Rendered images (ERDs, pipeline diagrams).
- **scripts/**:
    - `*.sql`: sql queries.

---

## 2. Ingestion & Medallion Layers

The assessment source zip file is ingested from the orginal google drive path and placed in a GCS bucket (the “**raw**” layer). Then load into `zendesk-assessment.raw` BigQuery dataset with minimal changes. Optionally transform or refine data in the `zendesk-assessment.refined` dataset (silver). Final dimensional or fact tables live in `zendesk-assessment.dw` (gold).

### Key DAGs
1. **`ingestion_gdrive_to_gcs.py`**: A single-step PythonOperator to download & unzip.  
2. **`ingestion_quality_assurance.py`**: Parallel load multiple csv from GCS → BigQuery.  
3. **`ingestion_customer_subscriptions.py`**: Incremental ingests JSON `etl.json` data.  
4. **`transformation_data_warehouse.py`**: Runs dbt to incrementally build models for the gold layer 

For more detail, see:
 **[Doc: Data Ingestion](docs/data_ingestion.md)**

---

## 3. Data Modeling

The data modeling process in this project is divided into two main phases:

1. **Preliminary Analysis of Relationships**:
   - Explores relationships between six base tables without applying dimensional modeling techniques.
   - Key relationships include:
     - `autoqa_reviews` ↔ `autoqa_ratings` ↔ `autoqa_root_cause`
     - `autoqa_reviews` ↔ `conversations`
     - `conversations` ↔ `conversation_messages` and `conversation_surveys`
   - An Entity-Relationship Diagram (ERD) for this phase is available in the [non-modeled ERD](docs/images/erd_non_modeled.png) and [non-modeled ERD code](diagram/erd_non_modeled.mmd).

2. **Dimensional Modeling**:
   - Optimizes the structure for analytics by organizing data into fact and dimension tables.
   - A second ERD, reflecting the dimensional model, is provided in the [modeled ERD](docs/diagram/erd_modeled.mmd).

For more detail, see:
 **[Doc: Data Model](docs/data_model.md)**

For a detailed explanation and diagrams, see the [full write-up on Data Modeling](docs/data_model.md).

--

## 3. Data Model Implementation

I rely on **incremental** logic with `unique_key` in each dimension/fact. This allows partial loads, merges new columns, and handles schema changes. I test each model with not_null, unique, and relationship constraints in `schema.yml`.

For more detail, see:
- **[Doc #1: DBT Implementation & Testing](docs/data_implementation.md)**

---

## 4. Queries (Weighted Scores & Averages)

To compute rating scores ignoring `rating=42`, or average scores by ticket or reviewee, I show examples using:
- “Modeled” data in `zendesk-assessment.dw`
- “Unmodeled” data in `zendesk-assessment.raw`

See:
- **[Doc #2: SQL Queries for Weighted & Averages](docs/sql_queries.md)**

---

## 5. JSON Pipeline & Future Expansion

One DAG processes a nested JSON (`etl.json`) from GCS. I flatten it with `pd.json_normalize` for simplicity. More advanced usage might split out sub-objects into separate tables. The pipeline also merges records incrementally, ensuring only changed or new data is updated.

**Future Considerations**:
- Partition & cluster for large volumes.
- Introduce ML models on curated data.
- Possibly adopt streaming if real-time updates are required.

See:
- **[Doc #3: ETL JSON + Future Considerations](docs/json_and_future.md)**

---

## 6. Dashboard Development & GPT Tools

Built a BI dashboard in Tableau Public on top of `zendesk-assessment.dw`. The star schema fosters easy slicing by dimension. For an AI-driven approach.

See:
- **[Doc #4: Dashboard ](docs/dashboard_gpt_prompts.md)**

---

## 7. Quick Start

1. **Airflow**:  
   - Deploy these DAGs (`ingestion_*.py`, `transformation_data_warehouse.py`).  
   - Supply a GCS bucket name and BigQuery credentials.
2. **dbt**:  
   - `cd dbt/`, adjust `profiles.yml` to match BigQuery project, run `dbt run`.  
3. **Validation**:  
   - Use `dbt test`.  
   - Check results in the BigQuery console (`zendesk-assessment.dw` dataset).  



---


