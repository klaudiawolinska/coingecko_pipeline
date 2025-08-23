from airflow.hooks.http_hook import HttpHook
from datetime import date

class CoinGeckoHook(HttpHook):
    def __init__(self, http_conn_id: str = "coingecko_default", *args, **kwargs):
        super().__init__(method="GET", http_conn_id=http_conn_id, *args, **kwargs)

    def get_history(self, coin_id: str, d: date):
        date_str = d.strftime("%d-%m-%Y")
        endpoint = f"/coins/{coin_id}/history"
        params = {"date": date_str, "localization": "false"}  # do not return coin name translations
        
        response = self.run(endpoint, data=params)
        return response.json()
