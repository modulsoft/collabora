#!/usr/bin/env python3
"""Minimal WOPI host for trying an OpenBP Docs container locally.

    python3 openbp/test/wopi-host.py <docs-dir> [--port 8090] [--cool http://127.0.0.1:9980]

Serves every file in <docs-dir> over WOPI (CheckFileInfo/GetFile/PutFile) and an
index page at http://127.0.0.1:<port>/ that opens a file in the editor; add
?user=Name to the index URL to join as another user (collaborative editing).
Start the container with --network host and
    -e aliasgroup1=http://127.0.0.1:<port>
    -e "extra_params=--o:ssl.enable=false"
Test helper only: no authentication, no locking.
"""
import argparse
import html
import json
import os
import re
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ap = argparse.ArgumentParser()
ap.add_argument("docs")
ap.add_argument("--port", type=int, default=8090)
ap.add_argument("--cool", default="http://127.0.0.1:9980")
args = ap.parse_args()
DOCS = os.path.abspath(args.docs)


def editor_url(name):
    ext = name.rsplit(".", 1)[-1]
    with urllib.request.urlopen(args.cool + "/hosting/discovery") as r:
        xml = r.read().decode()
    m = re.search(r'ext="%s"[^>]*urlsrc="([^"]+)"' % re.escape(ext), xml) or \
        re.search(r'urlsrc="([^"]+)"[^>]*ext="%s"' % re.escape(ext), xml)
    src = "http://127.0.0.1:%d/wopi/files/%s" % (args.port, urllib.parse.quote(name))
    return m.group(1) + "WOPISrc=" + urllib.parse.quote(src, safe="")


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body=b"", ctype="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path):
        name = urllib.parse.unquote(path.split("/wopi/files/", 1)[1].split("/")[0])
        return name, os.path.join(DOCS, os.path.basename(name))

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        if url.path == "/":
            user = q.get("user", ["Alice"])[0]
            items = "".join(
                '<li><form method="post" action="%s" target="_self">'
                '<input type="hidden" name="access_token" value="%s">'
                '<button>%s</button></form></li>'
                % (html.escape(editor_url(n)), html.escape(user), html.escape(n))
                for n in sorted(os.listdir(DOCS)))
            body = "<h1>WOPI test host</h1><p>User: %s</p><ul>%s</ul>" % (html.escape(user), items)
            return self._send(200, body.encode(), "text/html")
        if "/wopi/files/" not in url.path:
            return self._send(404)
        name, path = self._file(url.path)
        if url.path.endswith("/contents"):
            with open(path, "rb") as f:
                return self._send(200, f.read(), "application/octet-stream")
        user = q.get("access_token", ["Alice"])[0]
        info = {
            "BaseFileName": name,
            "Size": os.path.getsize(path),
            "OwnerId": "owner",
            "UserId": user,
            "UserFriendlyName": user,
            "UserCanWrite": True,
            "Version": str(os.path.getmtime(path)),
        }
        self._send(200, json.dumps(info).encode())

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if "/wopi/files/" not in url.path or not url.path.endswith("/contents"):
            return self._send(200, b"{}")
        _, path = self._file(url.path)
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(path, "wb") as f:
            f.write(data)
        self._send(200, json.dumps({"LastModifiedTime": ""}).encode())

    def log_message(self, fmt, *a):
        pass


ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()
