# Data Model Implementation & Validation

I have organized transformations in **dbt**, targeting BigQuery tables in `zendesk-assessment.dw`. The key dimensions and fact models are built incrementally, referencing staging models in `zendesk-assessment.refined`. Below is an overview of the approach, testing strategy

---

## 1. Structure & Materialization

### 1.1 DBT Models

- **Dimensions**:
  - `dim_date`
  - `dim_team`
  - `dim_payment`
  - `dim_user`
  - `dim_rating_category`

- **Facts**:
  - `fact_autoqa_reviews`
  - `fact_autoqa_ratings`
  - `fact_autoqa_root_cause`
  - `fact_manual_reviews`
  - `fact_manual_ratings`
  - `fact_conversations`

  - *Included*: `customer` and `subscriptions` for the JSON ingestion scenario

Each model typically references staging model in `zendesk-assessment.refined` (e.g. `stg_autoqa_reviews`) and writes to final dimensional/fact tables in `zendesk-assessment.dw`.

### 1.2 Incremental Materialization

Most models use:

```jinja
{{ config(
    materialized='incremental',
    unique_key='some_id',
    on_schema_change='sync_all_columns'
) }}
