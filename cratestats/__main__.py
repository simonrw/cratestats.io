import argparse
from .app import app

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--debug", action="store_true", default=False)
    parser.add_argument("-H", "--host", default="127.0.0.1")
    parser.add_argument("-p", "--port", default=8050, type=int)
    args = parser.parse_args()

    app.run_server(debug=args.debug, host=args.host, port=args.port)

