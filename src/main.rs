use actix_files as fs;
use actix_web::http::StatusCode;
use actix_web::{error, middleware, web, App, Error, HttpResponse, HttpServer};
use failure::bail;
use listenfd::ListenFd;
use r2d2_postgres::TlsMode;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::io;

fn set_up_tera() -> Result<tera::Tera, tera::Error> {
    tera::Tera::new("templates/**/*")
}

// Handlers

async fn index(tmpl: web::Data<tera::Tera>) -> Result<HttpResponse, Error> {
    let ctx = tera::Context::new();
    let s = tmpl
        .render("index.html", &ctx)
        .map_err(|_| error::ErrorInternalServerError("template error"))?;

    Ok(HttpResponse::Ok().content_type("text/html").body(s))
}

// API routes

#[derive(Deserialize, Serialize, Debug)]
struct DownloadTimeseriesRequest {
    name: String,
    version: Option<String>,
}

#[derive(Serialize)]
struct Response {
    name: String,
    version: Option<String>,
    downloads: Vec<Download>,
}

#[derive(Serialize)]
struct Download {
    date: chrono::NaiveDate,
    downloads: i64,
}

async fn download_timeseries(
    item: web::Json<DownloadTimeseriesRequest>,
    db: web::Data<r2d2::Pool<r2d2_postgres::PostgresConnectionManager>>,
) -> Result<web::Json<Response>, Error> {
    let req = item.0;

    // execute sync code in threadpool
    web::block(move || {
        let conn = db.get().unwrap();

        let rows = if let Some(version) = req.version.as_ref() {
            conn.query(
                "
            SELECT version_downloads.date, sum(version_downloads.downloads)
            FROM crates
            JOIN versions ON crates.id = versions.crate_id
            JOIN version_downloads ON versions.id = version_downloads.version_id
            WHERE crates.name = $1
            AND versions.num = $2
            GROUP BY version_downloads.date
            ORDER BY version_downloads.date ASC",
                &[&req.name, &version],
            )
            .unwrap()
        } else {
            conn.query(
                "
            SELECT version_downloads.date, sum(version_downloads.downloads)
            FROM crates
            JOIN versions ON crates.id = versions.crate_id
            JOIN version_downloads ON versions.id = version_downloads.version_id
            WHERE crates.name = $1
            GROUP BY version_downloads.date
            ORDER BY version_downloads.date ASC",
                &[&req.name],
            )
            .unwrap()
        };

        let downloads = rows
            .iter()
            .map(|row| Download {
                date: row.get(0),
                downloads: row.get(1),
            })
            .collect::<Vec<_>>();

        if downloads.is_empty() {
            bail!("cannot find any downloads for {}", &req.name);
        }

        let res: Result<Response, failure::Error> = Ok(Response {
            name: req.name.clone(),
            version: req.version.clone(),
            downloads,
        });

        res
    })
    .await
    .map(|v| web::Json(v))
    .map_err(|e| {
        match e {
            actix_threadpool::BlockingError::Error(e) => {
                HttpResponse::InternalServerError().json(json!({
                    "error": e.to_string(),
                }))
            }
            actix_threadpool::BlockingError::Canceled => {
                HttpResponse::InternalServerError().json(json!({
                    "error": "threadpool task cancelled",
                }))
            }
        }
        .into()
    })
}

// 404 handler
async fn p404() -> actix_web::Result<fs::NamedFile> {
    Ok(fs::NamedFile::open("static/404.html")?.set_status_code(StatusCode::NOT_FOUND))
}

#[actix_rt::main]
async fn main() -> io::Result<()> {
    // Initial setup
    dotenv::dotenv().ok();
    env_logger::init();
    let mut listenfd = ListenFd::from_env();

    // Get variables from the environment
    let db_conn_str =
        std::env::var("DATABASE_URL").expect("DATABASE_URL variable not set (see .env file)");
    let port = std::env::var("PORT").expect("PORT variable not set (see .env file)");
    let host = std::env::var("HOST").expect("HOST variable not set (see .env file)");

    // Set up the database
    let manager = r2d2_postgres::PostgresConnectionManager::new(db_conn_str, TlsMode::None)
        .expect("creating postgres connection manager");
    let pool = r2d2::Pool::new(manager).expect("setting up postgres connection pool");

    let mut server = HttpServer::new(move || {
        let tera = set_up_tera().expect("could not set up tera");

        App::new()
            .wrap(middleware::Logger::default())
            .service(
                web::scope("/api/v1")
                    // Limit the size of incoming payload
                    .data(web::JsonConfig::default().limit(1024))
                    .data(pool.clone())
                    .route("/downloads", web::post().to(download_timeseries)),
            )
            .service(fs::Files::new("/static", "static"))
            .service(web::scope("/").data(tera).route("", web::get().to(index)))
            // 404 handler
            .default_service(web::resource("").route(web::get().to(p404)))
    });

    // Let listenfd support live reloading
    server = if let Some(l) = listenfd.take_tcp_listener(0).unwrap() {
        server.listen(l)?
    } else {
        server.bind(format!("{host}:{port}", host = host, port = port))?
    };

    server.start().await
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::dev::ResponseBody;
    use actix_web::dev::Service;
    use actix_web::{http, test, web, App};

    #[actix_rt::test]
    async fn test_index() -> Result<(), Error> {
        // Set up app
        let tera = set_up_tera().unwrap();

        let mut app = test::init_service(
            App::new()
                .data(tera)
                .service(web::resource("/").route(web::get().to(index))),
        )
        .await;

        // Send request
        let req = test::TestRequest::get().uri("/").to_request();
        let resp = app.call(req).await?;

        assert_eq!(resp.status(), http::StatusCode::OK);

        Ok(())
    }

    #[actix_rt::test]
    #[ignore]
    async fn test_downloads() -> Result<(), Error> {
        dotenv::dotenv().ok();

        let db_conn_str = std::env::var("DATABASE_URL").unwrap();
        let manager =
            r2d2_postgres::PostgresConnectionManager::new(db_conn_str, TlsMode::None).unwrap();
        let pool = r2d2::Pool::new(manager).unwrap();
        let mut app = test::init_service(
            App::new().service(
                web::scope("/api/v1")
                    .data(pool.clone())
                    .route("/downloads", web::post().to(download_timeseries)),
            ),
        )
        .await;

        let query_body = DownloadTimeseriesRequest {
            name: "rand".to_string(),
            version: None,
        };

        let req = test::TestRequest::post()
            .uri("/api/v1/downloads")
            .set_json(&query_body)
            .to_request();
        let mut resp = app.call(req).await?;

        assert_eq!(resp.status(), http::StatusCode::OK);

        match resp.take_body() {
            ResponseBody::Body(b) => println!("{:?}", b),
            ResponseBody::Other(b) => println!("other: {:?}", b),
        }

        Ok(())
    }
}
