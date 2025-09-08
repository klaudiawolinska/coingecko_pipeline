from airflow.models import BaseOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
import json
from datetime import datetime, date


class CoinGeckoToS3Operator(BaseOperator):
    # Mark fields that can receive Jinja templates
    template_fields = ("target_date", "s3_key_template")

    def __init__(
        self,
        coins,
        target_date,
        bucket_name,
        s3_key_template,
        aws_conn_id="aws_default",
        *args,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.coins = coins
        self.target_date = target_date
        self.bucket_name = bucket_name
        self.s3_key_template = s3_key_template
        self.aws_conn_id = aws_conn_id

    def execute(self, context):
        from hooks.coingecko_hook import CoinGeckoHook

        hook = CoinGeckoHook()
        s3 = S3Hook(aws_conn_id=self.aws_conn_id)

        # Ensure target_date is a date object
        d = self.target_date
        if isinstance(d, str):
            d = datetime.strptime(d, "%Y-%m-%d").date()
        elif isinstance(d, datetime):
            d = d.date()
        elif not isinstance(d, date):
            raise TypeError(f"Unsupported type for target_date: {type(d)}")

        for coin in self.coins:
            data = hook.get_history(coin, d)
            record = json.dumps(data)

            key = self.s3_key_template.format(
                coin=coin,
                date=d.isoformat(),
            )

            self.log.info(f"Uploading {coin} data for {d} to s3://{self.bucket_name}/{key}")
            s3.load_string(record, key=key, bucket_name=self.bucket_name, replace=True)
