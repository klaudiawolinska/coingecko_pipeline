from airflow.sdk import dag, task   
from datetime import datetime
from plugins.operators.coingecko_to_s3_operator import CoinGeckoToS3Operator

@dag(schedule="@daily", start_date=datetime(2025, 9, 1), catchup=False)
def coingecko_to_s3():
    fetch_and_save_to_s3 = CoinGeckoToS3Operator(
        task_id="fetch_and_save_to_s3",
        coins=["bitcoin", "ethereum", "tether", "solana", "dogecoin"],
        target_date="{{ ds }}",
        bucket_name="coingecko-pipeline-data",
        s3_key_template="{date}/{coin}/{coin}_{date}_data.json"
    )

coingecko_to_s3()
