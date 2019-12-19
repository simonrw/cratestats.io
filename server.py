from fastapi import FastAPI
from starlette.staticfiles import StaticFiles
from starlette.templating import Jinja2Templates
import datetime
from starlette.requests import Request
from starlette_prometheus import metrics, PrometheusMiddleware
from pydantic import BaseModel
from typing import List, Optional
import databases
import dotenv
import os

# Setup variables
dotenv.load_dotenv()
DATABASE_URL = os.environ["DATABASE_URL"]

# Database setup
database = databases.Database(DATABASE_URL)

# App setup
app = FastAPI(title="cratestats.io", version="v1", redoc_url=None)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Middleware
app.add_middleware(PrometheusMiddleware)
app.add_route("/metrics", metrics)


@app.on_event("startup")
async def startup():
    await database.connect()


@app.on_event("shutdown")
async def shutdown():
    await database.disconnect()


templates = Jinja2Templates(directory="templates")


@app.get("/")
async def index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


class DownloadTimeseriesRequest(BaseModel):
    name: str
    version: Optional[str]


class Download(BaseModel):
    date: datetime.date
    downloads: int


class Downloads(BaseModel):
    name: str
    version: Optional[str]
    downloads: List[Download]


@app.post("/api/v1/downloads", response_model=Downloads)
async def download_timeseries(req: DownloadTimeseriesRequest):
    if req.version is None or req.version == "all":
        query = """
        SELECT version_downloads.date AS date, sum(version_downloads.downloads) as downloads
        FROM crates
        JOIN versions ON crates.id = versions.crate_id
        JOIN version_downloads ON versions.id = version_downloads.version_id
        WHERE crates.name = :name
        GROUP BY version_downloads.date
        ORDER BY version_downloads.date ASC
        """
        values = {"name": req.name}
    else:
        query = """
        SELECT version_downloads.date AS date, sum(version_downloads.downloads) as downloads
        FROM crates
        JOIN versions ON crates.id = versions.crate_id
        JOIN version_downloads ON versions.id = version_downloads.version_id
        WHERE crates.name = :name
        AND versions.num = :version
        GROUP BY version_downloads.date
        ORDER BY version_downloads.date ASC
        """
        values = {"name": req.name, "version": req.version}

    rows = await database.fetch_all(query=query, values=values)
    downloads = [Download(date=row["date"], downloads=row["downloads"]) for row in rows]

    response = Downloads(name=req.name, downloads=downloads, version=req.version)
    return response


@app.get("/api/v1/versions/{crate_name}")
async def fetch_versions(crate_name: str):
    query = """SELECT DISTINCT versions.num as version
    FROM versions
    JOIN crates ON crates.id = versions.crate_id
    WHERE crates.name = :name
    """

    values = {"name": crate_name}

    rows = await database.fetch_all(query=query, values=values)
    versions = [row["version"] for row in rows]

    return {"versions": versions}
