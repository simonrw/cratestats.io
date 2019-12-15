from flask import Flask, render_template, jsonify, request
import json
import logging
import networkx
import semver
from networkx.drawing import nx_pydot
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


def node_name(name, version):
    return f"{name}-{version}"


def create_graph(g, tx, crate_name, crate_version, depth=0):

    prefix = " " * depth * 4

    logger.info("%sadding crate %s:%s to graph at depth %s", prefix, crate_name, crate_version, depth)

    tx.execute("""select b.name, versions.num
    from crates as a
    join versions on a.id = versions.crate_id
    join dependencies as deps on deps.version_id = versions.id
    join crates as b on deps.crate_id = b.id
    where a.name = %s
    and versions.num = %s
    """, (crate_name, crate_version))

    g.add_node(node_name(crate_name, crate_version))
    for dep_name, dep_version in tx.fetchall():
        logger.info("%s-> dep: %s:%s", prefix, dep_name, dep_version)

        edge_from = node_name(crate_name, dep_version)
        edge_to = node_name(dep_name, dep_version)

        if (edge_from, edge_to) in g.edges():
            logger.debug("%sseen edge %s -> %s before, skipping", prefix, edge_from, edge_to)
            continue

        g.add_node(node_name(dep_name, dep_version))
        g.add_edge(edge_from, edge_to)

        create_graph(g, tx, dep_name, dep_version, depth + 1)



def fetch_latest_version(tx, crate_name):
    from functools import cmp_to_key
    tx.execute("""select versions.num
    from crates
    join versions on crates.id = versions.crate_id
    where crates.name = %s""", (crate_name, ))
    versions = [row[0] for row in tx.fetchall()]

    sorted_versions = sorted(versions, key=cmp_to_key(semver.compare))

    return sorted_versions[-1]

if __name__ == "__main__":
    import subprocess as sp
    # test the recursive fetching of dependencies

    crate_name = "fitsio"

    g = networkx.DiGraph()

    with db as conn:
        cursor = conn.cursor()
        crate_version = fetch_latest_version(cursor, crate_name)

    with db as conn:
        cursor = conn.cursor()
        create_graph(g, cursor, crate_name, crate_version)

    nx_pydot.write_dot(g, "graph.dot")
    sp.run(["dot", "-Tsvg", "graph.dot", "-o", "graph.svg"])
