from flask import Flask, render_template, jsonify
import requests


app = Flask(__name__)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/v1/crates/<crate>")
def fetch_crates(crate):
    # TODO: injection prevention
    r = requests.get("https://crates.io/api/v1/crates/{}".format(crate))
    r.raise_for_status()

    return jsonify(crates=r.json())
