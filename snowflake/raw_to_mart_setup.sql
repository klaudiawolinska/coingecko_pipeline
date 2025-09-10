USE ROLE accountadmin;
USE WAREHOUSE compute_wh;

CREATE OR REPLACE DATABASE coingecko;

CREATE OR REPLACE SCHEMA coingecko.raw;
CREATE OR REPLACE SCHEMA coingecko.staging;
CREATE OR REPLACE SCHEMA coingecko.mart;


/*
Replace the values in <> below with the details from your AWS account
*/
CREATE OR REPLACE STORAGE INTEGRATION coingecko_s3_integration 
  TYPE = external_stage 
  STORAGE_PROVIDER = 'S3'
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<your_account_number>:role/snowflake-coingecko-s3'  -- <your_account_number>
  ENABLED = TRUE 
  STORAGE_ALLOWED_LOCATIONS = ('s3://<your_bucket_name>');  -- <your_bucket_name>

  
/*
Execute below and copy the following values from the output to a convenient location: 
property_value of STORAGE_AWS_IAM_USER_ARN: ...
property_value of STORAGE_AWS_EXTERNAL_ID: ...
*/
DESC STORAGE INTEGRATION coingecko_s3_integration;


/*
Complete the steps below.

Reference Snowflake docs if needed: 
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-s3#step-1-configure-access-permissions-for-the-s3-bucket


**************************************************************************************************************************
************************************************* Create an IAM policy ***************************************************
**************************************************************************************************************************

Go to AWS > IAM > Policies > Create policy 
Select Policy editor: JSON

Paste below replacing the values in <> with your bucket name:

--------------------------------------------------------------------------------------------------------------------------
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject",
              "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::<your_bucket_name>/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::<your_bucket_name>",
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "*"
                    ]
                }
            }
        }
    ]
}
--------------------------------------------------------------------------------------------------------------------------

Click on Next
Give the policy a name, e.g. snowflake-coingecko-s3-policy


**************************************************************************************************************************
************************************************** Create an IAM role ****************************************************
**************************************************************************************************************************

Go to AWS > IAM > Roles > Create role 
Select trusted entity: Custom trust policy

Paste below replacing the value in <> with the STORAGE_AWS_IAM_USER_ARN
and STORAGE_AWS_EXTERNAL_ID values you copied earlier:

--------------------------------------------------------------------------------------------------------------------------
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": "<your_STORAGE_AWS_IAM_USER_ARN>"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "<your_STORAGE_AWS_EXTERNAL_ID>"
        }
      }
    }
  ]
}
--------------------------------------------------------------------------------------------------------------------------

Next > Add permissions > Find and select the policy you created in previous step
Next > Name the role: snowflake-coingecko-s3 > Create role 
*/


/*
Replace the values in <> below with your bucket name
*/
CREATE OR REPLACE STAGE coingecko.raw.coingecko_stage
  URL = 's3://<your_bucket_name>/'
  STORAGE_INTEGRATION = coingecko_s3_integration
  FILE_FORMAT = (TYPE = JSON);

LIST @coingecko.raw.coingecko_stage; -- this should show you all files from your bucket


CREATE OR REPLACE TABLE coingecko.raw.raw_coingecko_coin_market (
v VARIANT,
filename STRING
);

CREATE OR REPLACE STREAM coingecko.raw.raw_coingecko_coin_market_changes 
ON TABLE coingecko.raw.raw_coingecko_coin_market;


/*************************************************************************************************************************
**************************************** Configure a Snowpipe with auto-ingest *******************************************
**************************************************************************************************************************/

CREATE OR REPLACE PIPE coingecko.raw.raw_coingecko_coin_market_pipe
  AUTO_INGEST = true
  AS
COPY INTO coingecko.raw.raw_coingecko_coin_market
  (v, filename)
  FROM (
  SELECT 
    $1,
    METADATA$FILENAME 
  FROM @coingecko.raw.coingecko_stage);

/*
Execute below and copy the notification_channel value from the output to a convenient location
*/
SHOW PIPES;


/*
Complete the steps below.

Reference Snowflake & AWS docs if needed: 
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-auto-s3#option-1-creating-a-new-s3-event-notification-to-automate-snowpipe
https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-event-notifications.html

Go to AWS > S3 
Choose your bucket from the list
Go to Properties tab
Event Notifications > Create event notification
Event name: e.g. coingecko-snowflake-notifications
Select All object create events
Scroll down to Destination: SQS queue
Specify SQS queue: Enter SQS queue ARN
SQS queue: Paste the notification_channel you copied earlier from the SHOW PIPES command 
Save changes
*/

-- Load all unprocessed files from the last 7 days 
ALTER PIPE coingecko.raw.raw_coingecko_coin_market_pipe REFRESH;

-- Check if the status = RUNNING
SELECT SYSTEM$PIPE_STATUS('coingecko.raw.raw_coingecko_coin_market_pipe');

-- Check if raw data has been loaded (might take up to couple minutes)
SELECT * FROM coingecko.raw.raw_coingecko_coin_market;

-- Check that new data was captured in a stream (might take up to couple minutes)
SELECT * FROM coingecko.raw.raw_coingecko_coin_market_changes;


CREATE OR REPLACE TABLE coingecko.staging.stg_coingecko_coin_market (
    id STRING,
    event_date DATE,
    coin_name STRING,
    coin_symbol STRING,
    current_price_eur NUMBER(38,15),
    current_price_usd NUMBER(38,15),
    market_cap_eur NUMBER(38,15),
    market_cap_usd NUMBER(38,15),
    total_volume_eur NUMBER(38,15),
    total_volume_usd NUMBER(38,15)
);


CREATE OR REPLACE TASK coingecko.raw.load_coingecko_data_to_staging
WAREHOUSE = compute_wh
SCHEDULE = 'USING CRON 0/5 * * * * UTC'
WHEN system$stream_has_data('coingecko.raw.raw_coingecko_coin_market_changes')
AS 
INSERT INTO coingecko.staging.stg_coingecko_coin_market
SELECT 
      REPLACE(SPLIT_PART(filename, '/', 1), '-', '') || '_' ||
      SPLIT_PART(filename, '/', 2) AS id
    , TO_DATE(SPLIT_PART(filename, '/', 1), 'YYYY-MM-DD') AS event_date
    , v:id::STRING AS coin_name 
    , v:symbol::STRING AS coin_symbol 
    , v:market_data:current_price:eur::NUMBER(38,15) AS current_price_eur
    , v:market_data:current_price:usd::NUMBER(38,15) AS current_price_usd
    , v:market_data:market_cap:eur::NUMBER(38,15) AS market_cap_eur
    , v:market_data:market_cap:usd::NUMBER(38,15) AS market_cap_usd
    , v:market_data:total_volume:eur::NUMBER(38,15) AS total_volume_eur
    , v:market_data:total_volume:usd::NUMBER(38,15) AS total_volume_usd
FROM raw_coingecko_coin_market_changes;

ALTER TASK coingecko.raw.load_coingecko_data_to_staging RESUME;
--ALTER TASK coingecko.raw.load_coingecko_data_to_staging SUSPEND;

SELECT * FROM coingecko.staging.stg_coingecko_coin_market;

CREATE OR REPLACE VIEW coingecko.mart.dim_coin AS
SELECT DISTINCT
      coin_name
    , coin_symbol
FROM coingecko.staging.stg_coingecko_coin_market;

CREATE OR REPLACE VIEW coingecko.mart.fact_coin_market AS
SELECT
      event_date
    , coin_name
    , coin_symbol
    , current_price_eur
    , current_price_usd
    , market_cap_eur
    , market_cap_usd
    , total_volume_eur
    , total_volume_usd
FROM coingecko.staging.stg_coingecko_coin_market;

SELECT * FROM coingecko.mart.dim_coin;
SELECT * FROM coingecko.mart.fact_coin_market;
