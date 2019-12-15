use std::io;
use actix_web::{App, HttpServer, middleware, web, HttpResponse, Error, error};

async fn index(tmpl: web::Data<tera::Tera>) -> Result<HttpResponse, Error> {
    let ctx = tera::Context::new();
    let s = tmpl.render("index.html", &ctx)
        .map_err(|_| error::ErrorInternalServerError("template error"))?;

    Ok(HttpResponse::Ok().content_type("text/html").body(s))
}

#[actix_rt::main]
async fn main() -> io::Result<()> {
    dotenv::dotenv().ok();
    env_logger::init();

    HttpServer::new(|| {
        let tera = match tera::Tera::new("templates/**/*") {
            Ok(t) => t,
            Err(e) => {
                log::error!("could not compile templates: {}", e);
                std::process::exit(1);
            }
        };

        App::new()
            .data(tera)
            .wrap(middleware::Logger::default())
            .service(web::resource("/").route(web::get().to(index)))
    })
    .bind("127.0.0.1:8080")?
    .start()
    .await
}
