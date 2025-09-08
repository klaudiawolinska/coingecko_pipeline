from airflow.providers.http.hooks.http import HttpHook
from datetime import date, datetime

class CoinGeckoHook(HttpHook):
    def __init__(self, http_conn_id: str = "coingecko_default", *args, **kwargs):
        super().__init__(method="GET", http_conn_id=http_conn_id, *args, **kwargs)

    def get_history(self, coin_id: str, d):
        if isinstance(d, str):
            d = datetime.strptime(d, "%Y-%m-%d").date()
        elif not isinstance(d, date):
            raise TypeError(f"Expected str or date, got {type(d)}")

        date_str = d.strftime("%d-%m-%Y")
        endpoint = f"/coins/{coin_id}/history"
        params = {"date": date_str, "localization": "false"}
        
        response = self.run(endpoint, data=params)
        return response.json()
