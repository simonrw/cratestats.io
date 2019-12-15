use log::{debug, info, warn};
use petgraph::dot::{Config, Dot};
use postgres::{Connection, TlsMode};
use semver::{Version, VersionReq};
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use std::{error, result};
use structopt::StructOpt;

#[derive(Debug, StructOpt)]
#[structopt(name = "cratedeps")]
struct Opts {
    #[structopt(long = "crate", short = "c", help = "Crate to analyse")]
    krate: String,

    #[structopt(long = "output", short = "o", parse(from_os_str))]
    output: PathBuf,
}

type Result<T> = result::Result<T, Box<dyn error::Error>>;

fn node_name(name: &str, version: &str) -> String {
    format!("{} - {}", name, version)
}

fn fetch_compatible_version(
    conn: &mut Connection,
    dep_name: &str,
    dep_requirement: &str,
) -> Result<String> {
    match VersionReq::parse(&dep_requirement) {
        Ok(req) => {
            // Fetch all versions of a given crate
            let rows = conn.query(
                "select versions.num
        from versions
        join crates on crates.id = versions.crate_id
        where crates.name = $1",
                &[&dep_name],
            )?;

            let mut valid_versions: Vec<_> = rows
                .iter()
                .filter_map(|row| {
                    let version_str: String = row.get(0);
                    match Version::parse(&version_str) {
                        Ok(version) => {
                            if req.matches(&version) {
                                Some(version)
                            } else {
                                None
                            }
                        }
                        Err(e) => {
                            warn!("could not parse version {}: {:?}", version_str, e);
                            None
                        }
                    }
                })
                .collect();

            if valid_versions.is_empty() {
                return Err(format!(
                    "no valid versions of {} found with constraint {}",
                    dep_name, dep_requirement
                )
                .into());
            }

            valid_versions.sort();

            Ok(valid_versions[valid_versions.len() - 1].to_string())
        }
        Err(e) => {
            warn!(
                "could not parse version requirement {}: {:?}",
                dep_requirement, e
            );
            return Err(format!(
                "could not parse version requirement {}: {:?}",
                dep_requirement, e
            )
            .into());
        }
    }
}

type NodeHashMap = HashMap<String, petgraph::graph::NodeIndex<petgraph::graph::DefaultIx>>;

struct NodeStore(NodeHashMap);

impl NodeStore {
    fn new() -> Self {
        Self(HashMap::new())
    }

    fn get<S: Into<String>>(
        &mut self,
        key: S,
        graph: &mut petgraph::Graph<String, ()>,
    ) -> petgraph::graph::NodeIndex<petgraph::graph::DefaultIx> {
        let name = key.into();

        if self.0.contains_key(&name) {
            self.0.get(&name).unwrap().clone()
        } else {
            let this_node = graph.add_node(name.clone());
            self.0.insert(name.clone(), this_node);
            self.0.get(&name).unwrap().clone()
        }
    }
}

fn fetch_latest_version<S: Into<String>>(
    conn: &mut Connection,
    crate_name: S,
) -> Result<Option<String>> {
    let rows = conn.query(
        "select versions.num
    from crates
    join versions on crates.id = versions.crate_id
    where crates.name = $1",
        &[&crate_name.into()],
    )?;

    let mut versions: Vec<_> = rows
        .iter()
        .map(|row| {
            let version: String = row.get(0);
            Version::parse(&version).unwrap()
        })
        .collect();
    versions.sort();
    Ok(Some(format!("{}", versions[versions.len() - 1])))
}

fn update_graph(
    graph: &mut petgraph::Graph<String, ()>,
    conn: &mut Connection,
    node_store: &mut NodeStore,
    crate_name: &str,
    crate_version: &str,
    depth: i32,
    max_depth: Option<i32>,
) -> Result<()> {
    if let Some(max_depth) = max_depth {
        if depth >= max_depth {
            return Ok(());
        }
    }

    let prefix: String = (0..depth).map(|_| " ").collect();

    let this_crate_name = node_name(crate_name, crate_version);
    let this_node = node_store.get(&this_crate_name, graph);

    debug!("{}updating graph with crate `{}`", prefix, &this_crate_name);

    let rows = conn
        .query(
            "select b.name, deps.req
    from crates as a
    join versions on a.id = versions.crate_id
    join dependencies as deps on deps.version_id = versions.id
    join crates as b on deps.crate_id = b.id
    where a.name = $1
    and (deps.kind = 0 or deps.kind = 1)
    and versions.num = $2",
            &[&crate_name, &crate_version],
        )
        .expect("fetching dependencies");

    if rows.len() == 0 {
        warn!("no dependencies found; this should probably not happen");
    }

    for row in &rows {
        let dep_name: String = row.get(0);
        let dep_requirement: String = row.get(1);
        let dep_version = fetch_compatible_version(conn, &dep_name, &dep_requirement)?;

        let dep_crate_name = node_name(&dep_name, &dep_version);
        let dep_node = node_store.get(&dep_crate_name, graph);

        if graph.contains_edge(this_node.clone(), dep_node) {
            continue;
        }

        graph.update_edge(this_node, dep_node, ());

        update_graph(
            graph,
            conn,
            node_store,
            dep_name.as_str(),
            dep_version.as_str(),
            depth + 1,
            max_depth,
        )?;
    }

    Ok(())
}

fn main() -> Result<()> {
    env_logger::init();

    let opts = Opts::from_args();
    info!("command line arguments: {:?}", opts);

    info!("connecting to database");
    let mut conn = Connection::connect(
        "postgres://crates.io@localhost/cargo_registry",
        TlsMode::None,
    )?;
    info!("database connected");

    let mut g = petgraph::Graph::<String, ()>::new();
    let mut node_store = NodeStore::new();
    let max_depth = None; // Some(10);

    let crate_name = &opts.krate;
    let version = fetch_latest_version(&mut conn, crate_name)?.unwrap();

    info!(
        "updating graph with top level crate {}:{}",
        crate_name, version
    );
    update_graph(
        &mut g,
        &mut conn,
        &mut node_store,
        crate_name,
        &version,
        0,
        max_depth,
    )?;

    info!("compiling dot source");
    let dot_str = Dot::with_config(&g, &[Config::EdgeNoLabel]);

    info!("writing dot source to file");
    let mut f = File::create(opts.output)?;
    write!(&mut f, "{:?}", dot_str)?;

    Ok(())
}
