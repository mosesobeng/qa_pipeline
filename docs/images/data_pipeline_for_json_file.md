 # ETL Pipeline for `etl.json` (Incremental + Merge Strategy)

This documentation addresses the pipeline design for the `etl.json` file. The DAG extracts nested JSON from GCS, normalizes it, and loads/merges into BigQuery with partitioning.

---

## High-Level Pipeline

1. **Extract**:  
   - Reads the JSON from GCS (`etl.json`) using `requests.get()`.
   - Performs string replacements to fix single quotes, booleans, etc.  
   - Loads into Python dictionary.

2. **Transform**:  
   - Converts the nested JSON into a Pandas DataFrame using `pd.json_normalize(...)`.  
   - Optionally enriches columns (like converting a Unix timestamp to `dt_customer_signup_date`).

3. **Load**:  
   - If the BigQuery table doesn’t exist, create it with partitioning on date.  
   - If the table exists, load into a staging table, then perform a **MERGE** using a key (like `subscription_id`).  
   - This approach supports **incremental** updates—only changed or new rows are inserted/updated.

### Merge Strategy & Partitioning

- **MERGE**:  
  - Compares existing records in the main table before upsert by
  - `When matched AND updated columns differ ⇒ update.`  
  - `When not matched ⇒ insert.`  
- **Partitioning**:  
  - The final table is partitioned on a date field, e.g. `dt_customer_signup_date`.  
  - This allows efficient queries and incremental loads by date.

### Incremental Loading

- I avoid rewriting all historical data.  
- The MERGE logic only updates rows with different `subscription_updated_at` or `customer_updated_at`.  
- New records are inserted if `subscription_id` does not exist in the main table.

### Additional Tools (dbt)

After data is in BigQuery’s raw layer, **dbt** can further split or transform the JSON into multiple “staging” or “modeled” tables:

```sql
{{ config(materialized='table') }}
SELECT
  subscription_id,
  ...
FROM {{ ref('stg_customer_subscriptions') }}