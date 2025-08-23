# CoinGecko Pipeline

This repository contains a data pipeline built with **Apache Airflow** (running with **Astro**) that extracts daily cryptocurrency market data from the **CoinGecko API**, stores it in **AWS S3** as NDJSON files, ingests into **Snowflake RAW tables** via Snowpipe, and models the data into a **star schema** for analytics.

## 🎯 Project Focus

* Every day, for the selected **5 coins** (`bitcoin`, `ethereum`, `tether`, `solana`, `dogecoin`), it calls the CoinGecko API:

  ```
  https://api.coingecko.com/api/v3/coins/{coin}/history?date=DD-MM-YYYY
  ```

* Extracts market data:

  * `price_usd`
  * `market_cap_usd`
  * `volume_usd`

* Writes one **NDJSON file per coin per day** into S3:

  ```
  s3://<bucket>/<prefix>/coin={coin}/load_date=YYYY-MM-DD/data.ndjson
  ```

* Snowpipe ingests files from S3 into **RAW\.COIN\_MARKET\_RAW** (VARIANT column).

* Snowflake **streams + tasks** move data from RAW to STAGING.

* Final **star schema** enables easy analytics by coin, date, currency.

---

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
├── snowflake/                              # SQL scripts for raw and core data layers
│   └── ... 
├── airflow_settings.yaml              # connections & variables
├── requirements.txt                   # python dependencies
├── packages.txt                       # system packages if needed
├── Dockerfile                         # Astro Airflow image
├── .env.example                       # env vars template
├── .gitignore
└── README.md
```

---

## 🚀 Getting started

### Prerequisites

* [Astro CLI](https://www.astronomer.io/docs/astro/cli/install-cli)
* Docker & Docker Compose
* AWS credentials with write access to S3
* A Snowflake account

### 1. Clone the repo

```bash
git clone <this_repo_url> coingecko-pipeline
cd coingecko-pipeline
```

### 2. Configure environment

Copy `.env.example` to `.env` and set values:

```env
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_DEFAULT_REGION=eu-central-1

S3_BUCKET=your-bucket-name
S3_PREFIX=coingecko/prices
COINGECKO_COINS=bitcoin,ethereum,tether,solana,dogecoin

SNOWFLAKE_ACCOUNT=your_account
SNOWFLAKE_USER=your_user
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_ROLE=SYSADMIN
SNOWFLAKE_WAREHOUSE=LOADER_WH
SNOWFLAKE_DATABASE=CRYPTO
```

### 3. Start Airflow

```bash
astro dev start
```

Airflow UI → [http://localhost:8080](http://localhost:8080) (default user: `admin` / `admin`)

Connections and Variables are automatically loaded from `airflow_settings.yaml`.

---

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

---

## 📝 Outputs

In S3 you’ll see:

```
s3://my-bucket/coingecko/prices/
  ├── coin=bitcoin/load_date=2025-08-01/data.ndjson
  ├── coin=ethereum/load_date=2025-08-01/data.ndjson
  └── ...
```

In Snowflake:

* **RAW\.COIN\_MARKET\_RAW** (semi-structured, `VARIANT`)
* **STAGING.COIN\_MARKET** (flattened)
* **STAR schema**:

  * `DIM_COIN`
  * `DIM_DATE`
  * `DIM_CURRENCY`
  * `FACT_COIN_MARKET`

## ⚙️ Configuration

Edit `airflow_settings.yaml` for:

* **Connections**:

  * `coingecko_default` → base URL: `https://api.coingecko.com/api/v3`
  * `aws_default` → AWS region
  * `snowflake_default` → account, user, role, warehouse
  
* **Variables**:

  * `S3_BUCKET`
  * `S3_PREFIX`
  * `COINGECKO_COINS`

Changes take effect after:

```bash
astro dev restart
```

## 📄 License

MIT (see LICENSE file)
