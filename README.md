# CoinGecko Pipeline

This repository contains a data pipeline built with Apache Airflow that extracts daily cryptocurrency market data from the CoinGecko API, stores it in AWS S3, ingests into Snowflake RAW tables via Snowpipe, and models the data into a minimal star schema for analytics.

<br>

## 🎯 Project Focus

* Every day, for the selected 5 coins (`bitcoin`, `ethereum`, `tether`, `solana`, `dogecoin`), it calls the CoinGecko API:

  ```
  https://api.coingecko.com/api/v3/coins/{coin}/history?date=DD-MM-YYYY
  ```

* Extracts market data:

  * `current_price`
  * `market_cap`
  * `total_volume`

* Writes one JSON file per coin per day into S3:

  ```
  s3://<bucket>/<prefix>/{date}/{coin}/{coin}_{date}_data.json
  ```

* Snowpipe ingests files from S3 into `RAW\.RAW\_COINGECKO\_COIN\_MARKET` (VARIANT column).

* Snowflake streams + tasks move data from RAW to STAGING.

* Final `MART` schema enables analytics.

<br>

## 📂 Repo structure

```
.
├── dags/
│   └── coingecko_to_s3_dag.py              # main DAG, extracts data from CoinGecko API and uploads it to S3
├── plugins/
│   ├── hooks/
│   │   └── coingecko_hook.py               # custom hook for connection to CoinGecko API
│   └── operators/
│       └── coingecko_to_s3_operator.py     # custom CoinGecko to S3 operator
├── snowflake/                              # Snowflake setup script (stage, Snowpipe, all data warehouse layers)
│   └── ... 
├── airflow_settings.yaml                   # connections & variables
├── requirements.txt                        # python dependencies
├── packages.txt                            # system packages if needed
├── Dockerfile                              # Astro Airflow image
├── .gitignore
└── README.md
```

<br>

## 🚀 Getting started

### Prerequisites

* [Astro CLI](https://www.astronomer.io/docs/astro/cli/install-cli)
* Docker & Docker Compose
* AWS Admin credentials
* A Snowflake account

### 1. Clone the repo

```bash
git clone <this_repo_url> coingecko-pipeline
cd coingecko-pipeline
```

### 2. Configure environment

Create `.env` file and set values:

```env
AIRFLOW_CONN_COINGECKO_DEFAULT=http://:@https%3A%2F%2Fapi.coingecko.com%2Fapi%2Fv3?api_key=<your_API_key>

AIRFLOW_CONN_AWS_DEFAULT=aws://?region_name=<your_region_name>
AWS_ACCESS_KEY_ID=<your_access_key>
AWS_SECRET_ACCESS_KEY=<your_secret>
```

### 3. Start Airflow

```bash
astro dev start
```

Airflow UI → [http://localhost:8080](http://localhost:8080) (default user: `admin` / `admin`)

Connections and Variables are automatically loaded from `airflow_settings.yaml`.

<br>

## 🔄 Running the pipeline

Enable DAG `coingecko_to_s3` in the UI or trigger manually:

```bash
astro dev bash
airflow dags trigger coingecko_to_s3
```

Backfill (e.g., for July 2025):

```bash
airflow dags backfill coingecko_to_s3 -s 2025-07-01 -e 2025-08-01
```

<br>

## 📝 Outputs

In S3 you’ll see:

```
s3://<your_bucket>/<your_prefix>/
  ├── 2025-08-01/bitcoin/bitcoin_2025-08-01_data.json
  ├── 2025-08-01/ethereum/ethereum_2025-08-01_data.json
  └── ...
```

In Snowflake:

* `RAW\.RAW\_COINGECKO\_COIN\_MARKET` (semi-structured, `VARIANT`)
* `STAGING.STG\_COINGECKO\_COIN\_MARKET` (flattened)
* `MARTS` schema:

  * `FACT_COIN_MARKET`
  * `DIM_COIN`

<br>

## 📄 License

MIT (see LICENSE file)
