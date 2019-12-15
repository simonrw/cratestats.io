use actix_web::{error, middleware, web, App, Error, HttpResponse, HttpServer};
use serde::{Deserialize, Serialize};
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

async fn download_timeseries(item: web::Json<DownloadTimeseriesRequest>) -> HttpResponse {
    let req = item.0;
    log::info!("got request: {:?}", req);
    HttpResponse::Ok().json(req)
}

#[actix_rt::main]
async fn main() -> io::Result<()> {
    dotenv::dotenv().ok();
    env_logger::init();

    let port = std::env::var("PORT").expect("PORT variable not set (see .env file)");

    HttpServer::new(|| {
        let tera = set_up_tera().expect("could not set up tera");

        App::new()
            .wrap(middleware::Logger::default())
            .service(
                web::scope("/api/v1")
                    // Limit the size of incoming payload
                    .data(web::JsonConfig::default().limit(1024))
                    .route("/downloads", web::post().to(download_timeseries)),
            )
            .service(web::scope("/").data(tera).route("", web::get().to(index)))
    })
    .bind(format!("127.0.0.1:{port}", port=port))?
    .start()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
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
}
