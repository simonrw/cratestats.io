#!/usr/bin/env python


from semantic_version import Version, SimpleSpec
from functools import cmp_to_key
import networkx as nx
import logging
import psycopg2
import os


class DepException(Exception):
    pass


class NoValidVersions(DepException):
    def __init__(self):
        super().__init__("no versions found")


logging.basicConfig(level=logging.WARNING)
logger = logging.getLogger()


class NodeStore(object):
    def __init__(self):
        self.store = set()

    def add(self, graph, name):
        if name not in self.store:
            logger.debug("not seen %s before, adding to graph", name)
            graph.add_node(name)
            self.store.add(name)
        else:
            logger.debug("seen %s before", name)
        return name


def fetch_latest_version(conn, crate_name):
    with conn.cursor() as cursor:
        cursor.execute(
            """SELECT versions.num
                FROM crates
                JOIN versions ON crates.id = versions.crate_id
                WHERE crates.name = %s
                """,
            (crate_name,),
        )
        versions = [row[0] for row in cursor]

    if not versions:
        raise ValueError(f"cannot find any versions for {crate_name}")

    versions.sort(key=Version)

    return versions[-1]


def node_name(crate_name, crate_version):
    return f"{crate_name} - {crate_version}"


def fetch_compatible_version(conn, dep_name, dep_requirement):
    logger.debug("checking for versions of %s matching %s", dep_name, dep_requirement)
    req = SimpleSpec(dep_requirement.replace(" ", ""))

    with conn.cursor() as cursor:
        cursor.execute(
            """SELECT versions.num
                FROM versions
                JOIN crates ON crates.id = versions.crate_id
                WHERE crates.name = %s
                """,
            (dep_name,),
        )

        version_strings = [row[0] for row in cursor]

        versions = [Version(vs) for vs in version_strings]

    valid_versions = [v for v in versions if req.match(v)]

    valid_versions.sort()
    try:
        return valid_versions[-1]
    except IndexError:
        raise NoValidVersions()


def graph_contains_edge(graph, n1, n2):
    graph.has_edge(n1, n2)


def update_graph(graph, conn, node_store, crate_name, crate_version, depth):
    prefix = " " * depth

    this_crate_name = node_name(crate_name, crate_version)

    logger.info("%sseen %s", prefix, this_crate_name)
    node = node_store.add(graph, this_crate_name)

    with conn.cursor() as cursor:
        cursor.execute(
            """SELECT b.name, deps.req
                FROM crates AS a
                JOIN versions ON a.id = versions.crate_id
                JOIN dependencies AS deps ON deps.version_id = versions.id
                JOIN crates AS b ON deps.crate_id = b.id
                WHERE a.name = %s
                AND (deps.kind = 0 OR deps.kind = 1)
                AND versions.num = %s
                """,
            (crate_name, crate_version),
        )
        rows = cursor.fetchall()

    for dep_name, dep_requirement in rows:
        try:
            dep_version = fetch_compatible_version(conn, dep_name, dep_requirement)
        except NoValidVersions:
            logger.warning(
                "cannot find any matching versions for %s constraint: %s",
                dep_name,
                dep_requirement,
            )
            continue

        dep_crate_name = node_name(dep_name, dep_version)
        dep_node = node_store.add(graph, dep_crate_name)

        if graph.has_edge(node, dep_node):
            continue

        graph.add_edge(node, dep_node)

        update_graph(graph, conn, node_store, dep_name, str(dep_version), depth + 1)


def build_graph(conn: psycopg2.extensions.connection, crate_name: str) -> nx.DiGraph:
    g = nx.DiGraph()
    node_store = NodeStore()

    version = fetch_latest_version(conn, args.crate)

    logger.info("updating graph with top level crate %s:%s", args.crate, version)

    update_graph(
        graph=g,
        conn=conn,
        node_store=node_store,
        crate_name=args.crate,
        crate_version=version,
        depth=0,
    )

    return g


if __name__ == "__main__":
    import argparse
    import dotenv
    from networkx.drawing.nx_pydot import write_dot

    dotenv.load_dotenv()

    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--crate", required=True)
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()

    with psycopg2.connect(os.environ["DATABASE_URL"]) as conn:
        g = build_graph(conn, args.crate)

    write_dot(g, args.output)
