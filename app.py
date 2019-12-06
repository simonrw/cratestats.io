from flask import Flask, render_template, jsonify
import requests
import logging
from functools import lru_cache


logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger("cratestats.io")
logger.setLevel(logging.DEBUG)


app = Flask(__name__)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/v1/crates/<crate>")
def fetch_crates(crate):
    return jsonify(
            crates=fetch_crate_data_from_api(crate)
            )


@lru_cache()
def fetch_crate_data_from_api(crate):
    logger.debug("fetching crate data for crate %s from crates.io", crate)
    # TODO: injection prevention
    r = requests.get("https://crates.io/api/v1/crates/{}".format(crate))
    r.raise_for_status()
    return r.json()
