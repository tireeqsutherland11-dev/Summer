#!/usr/bin/env python3
"""Serve the downloaded Quantum Engine on a real, loopback-only web origin."""

from __future__ import annotations

import argparse
import functools
import http.server
import threading
import webbrowser
from pathlib import Path
from urllib.parse import quote


APP_FILE = "Quantum Engine Elite New.html"


class LocalOnlyServer(http.server.ThreadingHTTPServer):
    """HTTP server that is reusable and never exposed beyond this machine."""

    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run TME FX Quantum Engine Elite on a local web origin."
    )
    parser.add_argument("--port", type=int, default=8765, help="local port (default: 8765)")
    parser.add_argument("--no-browser", action="store_true", help="do not open a browser")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent
    app = root / APP_FILE
    if not app.is_file():
        parser.error(f"{APP_FILE!r} was not found beside this launcher")
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")

    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
    server = LocalOnlyServer(("127.0.0.1", args.port), handler)
    port = server.server_address[1]
    url = f"http://127.0.0.1:{port}/{quote(APP_FILE)}"

    print(f"Serving Quantum Engine from {root}")
    print(f"Open {url}")
    print("Press Ctrl+C to stop.")
    if not args.no_browser:
        threading.Timer(0.25, webbrowser.open, args=(url,)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping local server.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
