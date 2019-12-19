import warnings

warnings.simplefilter("ignore")
from starlette.testclient import TestClient
import pytest
import sys

sys.path.append(".")
from server import app


def test_downloads():
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/downloads", json={"name": "fitsio", "version": "0.15.0"}
        )
        assert response.status_code == 200

        json = response.json()
        assert json["name"] == "fitsio"
        assert json["version"] == "0.15.0"
        assert len(json["downloads"]) > 0


def test_downloads_no_version():
    with TestClient(app) as client:
        response = client.post("/api/v1/downloads", json={"name": "fitsio"})
        assert response.status_code == 200

        json = response.json()
        assert json["name"] == "fitsio"
        assert json["version"] is None
        assert len(json["downloads"]) > 0


def test_versions():
    with TestClient(app) as client:
        response = client.get("/api/v1/versions/fitsio")
        assert response.status_code == 200

        json = response.json()
        assert len(json["versions"]) > 0
        assert "0.15.0" in json["versions"]
