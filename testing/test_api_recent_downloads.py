import pytest
import sys
sys.path.insert(0, ".")
import app

@pytest.fixture
def client():
    app.app.config["TESTING"] = True

    with app.app.test_client() as client:
        # with app.app.app_context():
        yield client


def test_something(client):
    rv = client.post("/api/v1/recent_downloads", json=dict(
        crate="rand",
        ))
    json_data = rv.get_json()
    assert json_data["crate"] == "rand"
    assert len(json_data["downloads"]) > 0
