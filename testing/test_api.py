import warnings

warnings.simplefilter("ignore")
from starlette.testclient import TestClient
import pytest
import sys

sys.path.append(".")
from server import app


@pytest.fixture
def client():
    with TestClient(app) as client:
        yield client


def test_downloads(client):
    response = client.post(
        "/api/v1/downloads", json={"name": "fitsio", "version": "0.15.0"}
    )
    assert response.status_code == 200

    json = response.json()
    assert json["name"] == "fitsio"
    assert json["version"] == "0.15.0"
    assert len(json["downloads"]) > 0


def test_downloads_no_version(client):
    response = client.post("/api/v1/downloads", json={"name": "fitsio"})
    assert response.status_code == 200

    json = response.json()
    assert json["name"] == "fitsio"
    assert json["version"] is None
    assert len(json["downloads"]) > 0


def test_versions(client):
    response = client.get("/api/v1/versions/fitsio")
    assert response.status_code == 200

    json = response.json()
    assert len(json["versions"]) > 0
    assert "0.15.0" in json["versions"]


def test_deps(client):
    response = client.get("/api/v1/dependencies/rand")
    assert response.status_code == 200

    json = response.json()

    # Test nodes
    nodes = json["nodes"]
    assert len(nodes) > 0
    assert "id" in nodes[0]


    # Test edges
    edges = json["links"]
    assert len(edges) > 0
    assert "source" in edges[0]
    assert "target" in edges[0]
