from flask import Flask, render_template, jsonify
import requests
import json
import logging
import os
from urllib.parse import urljoin
from functools import lru_cache
from redis import Redis


logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger("cratestats.io")
logger.setLevel(logging.DEBUG)


app = Flask(__name__)

redis = Redis.from_url(os.environ["REDIS"])


class CratesIoClient(object):
    """Handles fetching from the crates.io API,
    and caching the response
    """

    # XXX SRP
    def __init__(self):
        self.CRATES_URL = "https://crates.io/api/v1/"
        self.DEFAULT_TTL = 60
        self.session = requests.Session()

    def fetch_crate_data_from_api(self, crate):
        logger.info("fetching crate info from API: %s", crate)
        cache_key = "crates:{}".format(crate)
        if not self._fetch_from_cache(cache_key):
            logger.debug(
                "cache value missing for crate %s, cache key %s", crate, cache_key
            )
            data = self._fetch_from_cratesio("/crates/{}".format(crate))
            self._store_in_cache(cache_key, data)

        return self._fetch_from_cache(cache_key)

    def _fetch_from_cache(self, cache_key):
        logger.debug("trying to get cache key %s", cache_key)
        res = redis.get(cache_key)
        if res:
            return json.loads(res)

    def _fetch_from_cratesio(self, stub):
        url = "/".join([self.CRATES_URL, stub])
        logger.debug("fetching data from url %s (stub %s)", url, stub)
        r = self.session.get(url)
        logger.debug("status: %d", r.status_code)
        r.raise_for_status()
        return r.json()

    def _store_in_cache(self, cache_key, value, ttl_value=None):
        if ttl_value is None:
            ttl_value = self.DEFAULT_TTL

        serialised = json.dumps(value)

        logger.debug(
            "storing value %s at location %s with ttl %s",
            serialised[:20] + "...",
            cache_key,
            ttl_value,
        )
        redis.setex(cache_key, ttl_value, serialised)


client = CratesIoClient()


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/v1/crates/<crate>")
def fetch_crates(crate):
    return jsonify(crates=client.fetch_crate_data_from_api(crate))
