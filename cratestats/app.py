import os
import dash
import dotenv
import pandas as pd
import numpy as np
import dash_core_components as dcc
import dash_html_components as html
import plotly.graph_objects as go
from dash.dependencies import Input, Output

from . import queries

dotenv.load_dotenv()


database_url = os.environ["CRATESTATS_DATABASE_URL"]

# Data setup
categories_df = queries.downloads_per_category(database_url)
downloads_timeseries_df = queries.downloads_per_dow(database_url)

# Helper functions
def download_heatmap_plot():
    first_week = downloads_timeseries_df["week"].min()
    last_week = downloads_timeseries_df["week"].max()

    out = []
    weeks = list(range(int(first_week), int(last_week)))
    for week in weeks:
        row = []
        for day in range(0, 7):
            cell_idx = (downloads_timeseries_df["week"].astype(int) == week) & (
                downloads_timeseries_df["dow"].astype(int) == day
            )
            row.append(downloads_timeseries_df[cell_idx]["total_downloads"].sum())
        out.append(row)

    arr = np.array(out).T

    dow = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    return go.Figure(
        data=go.Heatmap(
            z=arr, y=dow, x=weeks
        )
    )


# App setup

app = dash.Dash(__name__)

app.layout = html.Div(
    [
        html.H1("cratestats.io"),
        html.Div(
            [
                html.H2("Crates by category"),
                dcc.Slider(
                    id="num-categories-slider",
                    min=1,
                    max=len(categories_df),
                    value=len(categories_df),
                ),
                dcc.Graph(
                    id="crate-categories",
                    figure={
                        "data": [
                            {
                                "x": categories_df["category"],
                                "y": categories_df["crate_count"],
                                "type": "bar",
                            },
                        ],
                        "layout": {"title": "Crates by category",},
                    },
                ),
                dcc.Graph(
                    id="crate-categories-pie",
                    figure=go.Figure(
                        go.Pie(
                            labels=categories_df["category"],
                            values=categories_df["crate_count"],
                        )
                    ),
                ),
                dcc.Graph(
                    id="downloads-per-dow-heatmap", figure=download_heatmap_plot(),
                ),
            ]
        ),
    ]
)


@app.callback(
    [Output("crate-categories", "figure"), Output("crate-categories-pie", "figure")],
    [Input("num-categories-slider", "value")],
)
def update_num_categories(num_categories):
    filtered_df = categories_df.head(num_categories)
    bar_result = {
        "data": [
            {
                "x": filtered_df["category"],
                "y": filtered_df["crate_count"],
                "type": "bar",
            },
        ],
        "layout": {"title": "Crates by category",},
    }
    pie_result = go.Figure(
        go.Pie(labels=filtered_df["category"], values=filtered_df["crate_count"],)
    )

    return bar_result, pie_result
