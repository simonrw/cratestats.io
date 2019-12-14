from flask import Flask, render_template, jsonify, request
import json
import logging
import os
import psycopg2
from urllib.parse import urljoin
from functools import lru_cache
import dotenv

dotenv.load_dotenv()

logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger("cratestats.io")
logger.setLevel(logging.DEBUG)


app = Flask(__name__)
db = psycopg2.connect(os.environ["DATABASE_URL"])


@app.route("/")
def index():
    return render_template("index.html")


# Helper functions
def jsonify_ok(**kwargs):
    kwargs.pop("status", None)
    return jsonify(status="ok", **kwargs)


def jsonify_err(message, **kwargs):
    kwargs.pop("status", None)
    kwargs.pop("message", None)
    return jsonify(status="error", message=message, **kwargs), 400


# Api routes


@app.route("/api/v1/recent_downloads", methods=["POST"])
def api_recent_downloads():
    req = request.get_json()
    if not req:
        return jsonify_err(message="no json body supplied")

    crate_name = req.get("crate")
    if not crate_name:
        return jsonify_err(message="no `crate` name specified")

    with db as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
        SELECT versions.num, sum(version_downloads.downloads) as recent_downloads
        FROM crates
        JOIN versions ON crates.id = versions.crate_id
        JOIN version_downloads on version_downloads.version_id = versions.id
        WHERE version_downloads.date > current_date - interval '90' day
        AND name = %s
        GROUP BY versions.num
        """,
            (crate_name,),
        )

        results = cursor.fetchall()

    return jsonify_ok(
        crate=crate_name,
        downloads=[{"version": row[0], "downloads": row[1]} for row in results],
    )
