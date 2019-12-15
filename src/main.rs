use std::io;
use actix_web::{App, HttpServer, middleware, web, HttpResponse, Error, error};

fn set_up_tera() -> Result<tera::Tera, tera::Error> {
    tera::Tera::new("templates/**/*")
}

async fn index(tmpl: web::Data<tera::Tera>) -> Result<HttpResponse, Error> {
    let ctx = tera::Context::new();
    let s = tmpl.render("index.html", &ctx)
        .map_err(|_| error::ErrorInternalServerError("template error"))?;

    Ok(HttpResponse::Ok().content_type("text/html").body(s))
}

#[actix_rt::main]
async fn main() -> io::Result<()> {
    dotenv::dotenv().ok();

    std::env::set_var("RUST_LOG", "actix_web=info");
    env_logger::init();

    HttpServer::new(|| {
        let tera = set_up_tera().expect("could not set up tera");

        App::new()
            .data(tera)
            .wrap(middleware::Logger::default())
            .service(web::resource("/").route(web::get().to(index)))
    })
    .bind("127.0.0.1:8080")?
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
            App::new().data(tera).service(web::resource("/").route(web::get().to(index))),
        ).await;

        // Send request
        let req = test::TestRequest::get()
            .uri("/")
            .to_request();
        let resp = app.call(req).await?;

        assert_eq!(resp.status(), http::StatusCode::OK);

        Ok(())
    }
}
