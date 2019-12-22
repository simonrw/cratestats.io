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
logger.setLevel(logging.WARNING)


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


async def fetch_latest_version(database, crate_name):
    rows = await database.fetch_all(
        query="""SELECT versions.num as num
                FROM crates
                JOIN versions ON crates.id = versions.crate_id
                WHERE crates.name = :crate_name
                """,
        values={"crate_name": crate_name},
    )
    versions = [row["num"] for row in rows]

    if not versions:
        raise ValueError(f"cannot find any versions for {crate_name}")

    versions.sort(key=Version)

    return versions[-1]


def node_name(crate_name, crate_version):
    return f"{crate_name} - {crate_version}"


async def fetch_compatible_version(database, dep_name, dep_requirement):
    logger.debug("checking for versions of %s matching %s", dep_name, dep_requirement)
    req = SimpleSpec(dep_requirement.replace(" ", ""))

    rows = await database.fetch_all(
            query="""SELECT versions.num
                FROM versions
                JOIN crates ON crates.id = versions.crate_id
                WHERE crates.name = :name
                """,
            values={"name": dep_name}
        )

    version_strings = (row["num"] for row in rows)
    versions = (Version(vs) for vs in version_strings)
    valid_versions = [v for v in versions if req.match(v)]
    valid_versions.sort()

    try:
        return valid_versions[-1]
    except IndexError:
        raise NoValidVersions()


async def update_graph(graph, database, node_store, crate_name, crate_version, depth):
    prefix = " " * depth

    this_crate_name = node_name(crate_name, crate_version)

    logger.info("%sseen %s", prefix, this_crate_name)
    node = node_store.add(graph, this_crate_name)

    rows = await database.fetch_all(
        """SELECT b.name, deps.req
                FROM crates AS a
                JOIN versions ON a.id = versions.crate_id
                JOIN dependencies AS deps ON deps.version_id = versions.id
                JOIN crates AS b ON deps.crate_id = b.id
                WHERE a.name = :name
                AND (deps.kind = 0 OR deps.kind = 1)
                AND versions.num = :version
                """,
        values={"name": crate_name, "version": crate_version},
    )

    for row in rows:
        dep_name = row["name"]
        dep_requirement = row["req"]

        try:
            dep_version = await fetch_compatible_version(
                database, dep_name, dep_requirement
            )
        except NoValidVersions:
            logger.info(
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

        await update_graph(graph, database, node_store, dep_name, str(dep_version), depth + 1)


async def build_graph(database, crate_name: str) -> nx.DiGraph:
    g = nx.DiGraph()
    node_store = NodeStore()

    version = await fetch_latest_version(database, crate_name)

    logger.info("updating graph with top level crate %s:%s", crate_name, version)

    await update_graph(
        graph=g,
        database=database,
        node_store=node_store,
        crate_name=crate_name,
        crate_version=version,
        depth=0,
    )

    return g


async def main():
    import databases
    import dotenv
    import argparse
    from networkx.drawing.nx_pydot import write_dot
    dotenv.load_dotenv()

    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--crate", required=True)
    parser.add_argument("-o", "--output", required=True)
    args = parser.parse_args()

    DATABASE_URL = os.environ["DATABASE_URL"]

    database = databases.Database(DATABASE_URL)
    await database.connect()

    graph = await build_graph(database, args.crate)

    await database.disconnect()

    write_dot(graph, args.output)



if __name__ == "__main__":
    import asyncio


    asyncio.run(main())
