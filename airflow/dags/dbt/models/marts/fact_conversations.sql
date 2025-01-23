{{ config(
    materialized='incremental',
    unique_key='conversation_key',
    on_schema_change='sync_all_columns'
) }}

WITH base AS (
  SELECT
    payment_id,
    payment_token_id,
    external_ticket_id,
    conversation_created_at,
    conversation_created_at_date,
    channel,
    assignee_id,
    CAST(updated_at AS TIMESTAMP) AS updated_at,
    closed_at,
    message_count,
    last_reply_at,
    language,
    imported_at,
    unique_public_agent_count,
    public_mean_character_count,
    public_mean_word_count,
    private_message_count,
    public_message_count,
    klaus_sentiment,
    is_closed,
    agent_most_public_messages,
    first_response_time,
    first_resolution_time_seconds,
    full_resolution_time_seconds,
    most_active_internal_user_id,
    deleted_at
  FROM {{ ref('stg_conversations') }}
),

filtered AS (
  SELECT *
  FROM base
  {% if is_incremental() %}
    WHERE updated_at > (
      SELECT IFNULL(MAX(updated_at), TIMESTAMP('1900-01-01'))
      FROM {{ this }}
    )
  {% endif %}
)

SELECT
  MD5(CONCAT(
    CAST(b.payment_id AS STRING), 
    '_', 
    CAST(external_ticket_id AS STRING), 
    '_', 
    COALESCE(conversation_created_at, '')
  )) AS conversation_key,

  dp.payment_key,
  payment_token_id,
  external_ticket_id,
  du.user_key AS assignee_key,

  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversation_created_at) AS conversation_created_ts,
  SAFE.PARSE_DATE('%Y-%m-%d', conversation_created_at_date) AS conversation_created_dt,
  b.updated_at,
  SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', closed_at) AS closed_ts,

  channel,
  language,
  is_closed,
  message_count,
  private_message_count,
  public_message_count,
  unique_public_agent_count,
  agent_most_public_messages,
  first_response_time,
  first_resolution_time_seconds,
  full_resolution_time_seconds,
  last_reply_at,
  klaus_sentiment,
  deleted_at,
  imported_at,
  public_mean_character_count,
  public_mean_word_count,
  most_active_internal_user_id,

  -- date keys if desired
  CAST(FORMAT_TIMESTAMP('%Y%m%d', SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', conversation_created_at)) AS INT) AS date_key_created,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', b.updated_at) AS INT) AS date_key_updated,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', closed_at)) AS INT) AS date_key_closed

FROM filtered b
LEFT JOIN {{ ref('dim_payment') }} dp
  ON MD5(CAST(b.payment_id AS STRING)) = dp.payment_key
LEFT JOIN {{ ref('dim_user') }} du
  ON MD5(CAST(b.assignee_id AS STRING)) = du.user_key
