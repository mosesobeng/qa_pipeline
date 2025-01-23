# Preliminary Analysis of Relationships (No Dimensional Modeling)

In this initial phase, we are reviewing **six base tables** and identifying how they can be joined **without** applying any dimensional modeling. Below is a summary of each relevant join:

1. **`autoqa_reviews` → `autoqa_ratings`**  
   - **Key**: `autoqa_review_id`  
   - `autoqa_ratings.autoqa_review_id` references `autoqa_reviews.autoqa_review_id`.  

2. **`autoqa_ratings` → `autoqa_root_cause`**  
   - **Key**: `autoqa_rating_id`  
   - `autoqa_root_cause.autoqa_rating_id` references `autoqa_ratings.autoqa_rating_id`.  

3. **`autoqa_reviews` ↔ `conversations`**  
   - **Match on**: `payment_id`, `payment_token_id`, and `external_ticket_id`  
   - If these three columns match in both tables, you can join `autoqa_reviews` with `conversations`.

4. **`manual_reviews` → `manual_rating`**  
   - **Key**: `review_id`  
   - `manual_rating.review_id` references `manual_reviews.review_id`.

5. **`manual_reviews` ↔ `conversations`**  
   - **Match on**: `payment_id`, `payment_token_id`, plus `conversation_external_id = external_ticket_id`  
   - If your data logic supports linking `conversation_external_id` to `external_ticket_id`, these columns can join the two tables.

This **preliminary analysis** focuses on the **raw relationships** between the six tables. We have **not** yet reorganized or optimized them into a dimensional (star) schema. Instead, we are simply documenting how they **can** be joined in their current form.



# Dimensional Modeling Overview (Explicit Entities and Columns)

Below is a **star schema** design that transforms the original six base tables into **dimensions** (entities describing business objects) and **facts** (entities capturing measurements). All columns are listed to ensure complete clarity. No abbreviations such as “etc.” are used.

---

## 1. Dimensions (Entities)

### 1.1 **DimTeam**
- **Purpose**: Holds team-related data.
- **Grain**: One row per unique `team_id`.
- **Surrogate Key (Primary Key)**: `team_key` (string or integer generated in the warehouse)
- **Natural Key**: `team_id` (integer from source)
- **Columns**:
  1. **team_key** *(PK, surrogate)* — for joins from fact tables  
  2. **team_id** *(int)* — business identifier from the raw data  
  3. **updated_at** *(timestamp or string)* — if tracked from source tables (if any)

> **Note**: If there is no `team_name` or additional attributes in the raw data, this dimension may only contain `team_id` and `updated_at`. 

---

### 1.2 **DimPayment**
- **Purpose**: Stores payment identifiers.
- **Grain**: One row per unique `payment_id`.
- **Surrogate Key (Primary Key)**: `payment_key` (string or integer)
- **Natural Key**: `payment_id` (integer)
- **Columns**:
  1. **payment_key** *(PK, surrogate)*  
  2. **payment_id** *(int)*  
  3. **payment_token_id** *(int)*  
  4. **updated_at** *(timestamp or string)* — optional if derived from the sources

---

### 1.3 **DimUser**
- **Purpose**: Centralizes user references (reviewers, reviewees, assignees, etc.).
- **Grain**: One row per unique user identifier across the system.
- **Surrogate Key (Primary Key)**: `user_key`
- **Natural Key**: `user_id`
- **Columns**:
  1. **user_key** *(PK, surrogate)*  
  2. **user_id** *(int)* — can represent `reviewer_id`, `reviewee_id`, `assignee_id`, etc.
  3. **updated_at** *(timestamp or string)* — optional if captured from staging

---

### 1.4 **DimRatingCategory**
- **Purpose**: Consolidates categories from manual and auto QA ratings.
- **Grain**: One row per unique category identifier.
- **Surrogate Key (Primary Key)**: `rating_category_key`
- **Natural Key**: `category_id`
- **Columns**:
  1. **rating_category_key** *(PK, surrogate)*  
  2. **category_id** *(int)* — from raw data (e.g., `autoqa_ratings.rating_category_id`, `manual_rating.category_id`)
  3. **category_name** *(string)*

> If there is no additional metadata for categories, these are the main columns.

---

## 2. Fact Tables (Entities)

Below are the **six** facts representing your major business processes. Each fact references relevant dimensions by **surrogate keys**.  

### 2.1 **FactAutoQAReviews**
- **Source Table**: `autoqa_reviews`
- **Grain**: One row per *Auto QA review*.
- **Primary Key**: `autoqa_review_key` (surrogate)
- **Columns**:

  1. **autoqa_review_key** *(PK, surrogate)*  
  2. **autoqa_review_id** *(string)* — from `autoqa_reviews`
  3. **payment_key** *(FK to DimPayment)*  
  4. **payment_id** *(int)* — optional degenerate if you wish to store the raw ID  
  5. **payment_token_id** *(int)* — optional degenerate  
  6. **external_ticket_id** *(int)*  
  7. **created_at** *(string or timestamp)*  
  8. **conversation_created_at** *(string or timestamp)*  
  9. **conversation_created_date** *(string or date)*  
  10. **team_key** *(FK to DimTeam)*  
  11. **team_id** *(int)* — optional degenerate  
  12. **reviewee_key** *(FK to DimUser)*  
  13. **reviewee_internal_id** *(float)* — optional degenerate  
  14. **updated_at** *(string or timestamp)*  

---

### 2.2 **FactAutoQARatings**
- **Source Table**: `autoqa_ratings`
- **Grain**: One row per *Auto QA rating line item*.
- **Primary Key**: `autoqa_rating_key`
- **Columns**:

  1. **autoqa_rating_key** *(PK, surrogate)*  
  2. **autoqa_rating_id** *(string)*  
  3. **autoqa_review_key** *(reference to FactAutoQAReviews or treated as FK if you prefer a direct link)*  
  4. **payment_key** *(FK to DimPayment)*  
  5. **payment_id** *(int)* — optional degenerate  
  6. **team_key** *(FK to DimTeam)*  
  7. **team_id** *(int)* — optional degenerate  
  8. **payment_token_id** *(int)* — optional degenerate  
  9. **external_ticket_id** *(int)*  
  10. **rating_category_key** *(FK to DimRatingCategory)*  
  11. **rating_category_id** *(int)*  
  12. **rating_category_name** *(string)*  
  13. **rating_scale_score** *(float)*  
  14. **score** *(float)*  
  15. **reviewee_key** *(FK to DimUser)*  
  16. **reviewee_internal_id** *(int)* — optional degenerate

---

### 2.3 **FactAutoQARootCause**
- **Source Table**: `autoqa_root_cause`
- **Grain**: One row per *root cause* record linked to an Auto QA rating.
- **Primary Key**: `autoqa_root_cause_key` (surrogate)
- **Columns**:

  1. **autoqa_root_cause_key** *(PK, surrogate)*  
  2. **autoqa_rating_key** *(FK to FactAutoQARatings)*  
  3. **autoqa_rating_id** *(string)* — optional degenerate  
  4. **category** *(float)*  
  5. **count** *(float)*  
  6. **root_cause** *(string)*

---

### 2.4 **FactManualReviews**
- **Source Table**: `manual_reviews`
- **Grain**: One row per *manual review*.
- **Primary Key**: `manual_review_key`
- **Columns**:

  1. **manual_review_key** *(PK, surrogate)*  
  2. **review_id** *(int)*  
  3. **payment_key** *(FK to DimPayment)*  
  4. **payment_id** *(int)* — optional degenerate  
  5. **payment_token_id** *(int)* — optional degenerate  
  6. **created** *(string or timestamp)*  
  7. **conversation_created_at** *(string or timestamp)*  
  8. **conversation_created_date** *(string or date)*  
  9. **conversation_external_id** *(int)*  
  10. **team_key** *(FK to DimTeam)*  
  11. **team_id** *(int)* — optional degenerate  
  12. **reviewer_key** *(FK to DimUser)*  
  13. **reviewer_id** *(int)* — optional degenerate  
  14. **reviewee_key** *(FK to DimUser)*  
  15. **reviewee_id** *(float)* — optional degenerate  
  16. **comment_id** *(float)*  
  17. **scorecard_id** *(float)*  
  18. **scorecard_tag** *(string)*  
  19. **score** *(float)*  
  20. **updated_at** *(string or timestamp)*  
  21. **updated_by** *(int)*  
  22. **assignment_review** *(boolean)*  
  23. **seen** *(boolean)*  
  24. **disputed** *(boolean)*  
  25. **review_time_seconds** *(float)*  
  26. **assignment_name** *(string)*  
  27. **imported_at** *(string or timestamp)*  

---

### 2.5 **FactManualRatings**
- **Source Table**: `manual_rating`
- **Grain**: One row per *category-level rating* within a manual review.
- **Primary Key**: `manual_rating_key`
- **Columns**:

  1. **manual_rating_key** *(PK, surrogate)*  
  2. **payment_key** *(FK to DimPayment)*  
  3. **payment_id** *(int)* — optional degenerate  
  4. **team_key** *(FK to DimTeam)*  
  5. **team_id** *(int)* — optional degenerate  
  6. **review_id** *(int)*  
  7. **manual_review_key** *(FK to FactManualReviews)* — optional approach  
  8. **category_id** *(int)*  
  9. **rating** *(float)*  
  10. **cause** *(string)*  
  11. **rating_max** *(int)*  
  12. **weight** *(float)*  
  13. **critical** *(boolean)*  
  14. **category_name** *(string)*

---

### 2.6 **FactConversations**
- **Source Table**: `conversations`
- **Grain**: One row per *conversation*.
- **Primary Key**: `conversation_key`
- **Columns**:

  1. **conversation_key** *(PK, surrogate)*  
  2. **payment_key** *(FK to DimPayment)*  
  3. **payment_id** *(int)* — optional degenerate  
  4. **payment_token_id** *(int)*  
  5. **external_ticket_id** *(int)*  
  6. **conversation_created_at** *(string or timestamp)*  
  7. **conversation_created_at_date** *(string or date)*  
  8. **channel** *(string)*  
  9. **assignee_key** *(FK to DimUser)*  
  10. **assignee_id** *(int)* — optional degenerate  
  11. **updated_at** *(string or timestamp)*  
  12. **closed_at** *(string or timestamp)*  
  13. **message_count** *(int)*  
  14. **last_reply_at** *(string or timestamp)*  
  15. **language** *(string)*  
  16. **imported_at** *(string or timestamp)*  
  17. **unique_public_agent_count** *(int)*  
  18. **public_mean_character_count** *(float)*  
  19. **public_mean_word_count** *(float)*  
  20. **private_message_count** *(int)*  
  21. **public_message_count** *(int)*  
  22. **klaus_sentiment** *(string)*  
  23. **is_closed** *(boolean)*  
  24. **agent_most_public_messages** *(int)*  
  25. **first_response_time** *(float)*  
  26. **first_resolution_time_seconds** *(float)*  
  27. **full_resolution_time_seconds** *(float)*  
  28. **most_active_internal_user_id** *(float)*  
  29. **deleted_at** *(float)*  

---

## 3. Relationships (No “Etc.”)

Below is a textual summary of how the **Facts** reference the **Dimensions**:

1. **FactAutoQAReviews** → references **DimTeam** (via `team_key`), **DimPayment** (via `payment_key`), **DimUser** for `reviewee_key`.
2. **FactAutoQARatings** → references **DimTeam**, **DimPayment**, **DimUser**, **DimRatingCategory**, and optionally links back to **FactAutoQAReviews** by `autoqa_review_key`.
3. **FactAutoQARootCause** → references **FactAutoQARatings** by `autoqa_rating_key`.
4. **FactManualReviews** → references **DimTeam**, **DimPayment**, **DimUser** for reviewer/reviewee.
5. **FactManualRatings** → references **DimTeam**, **DimPayment**, **DimRatingCategory**, and optionally **FactManualReviews** by `review_id`.
6. **FactConversations** → references **DimPayment**, **DimUser** (for the `assignee_key`).

---

## 4. Data Types

Each column is assigned a specific data type. Examples include:

- **INT** (or **INTEGER**) for identifiers (`team_id`, `payment_id`, `review_id`, etc.).
- **FLOAT** for numeric measures that can have decimals (e.g., `score`, `weight`).
- **STRING** (or **VARCHAR**) for textual columns (`root_cause`, `channel`, `cause`).
- **BOOLEAN** for true/false fields (`critical`, `is_closed`, `seen`).
- **TIMESTAMP** or **DATE** for time-based columns (`created_at`, `updated_at`, `conversation_created_date`).

You can parse string-based dates into **TIMESTAMP** or **DATE** in your ETL or staging, depending on your data warehouse.

---

## 5. ERD and Design Choices

### ERD (Conceptual Star Layout)

