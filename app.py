import dash
import dash_core_components as dcc
import dash_html_components as html


app = dash.Dash(__name__)

app.layout = html.Div([
    html.H1("cratestats.io"),
    dcc.Markdown("""
    """)
    ])


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--debug", action="store_true", default=False)
    parser.add_argument("-H", "--host", default="127.0.0.1")
    parser.add_argument("-p", "--port", default=8050, type=int)
    args = parser.parse_args()

    app.run_server(debug=args.debug, host=args.host, port=args.port)
