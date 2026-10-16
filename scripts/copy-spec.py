#!/usr/bin/env python3
"""Copy the server's OpenAPI spec into Tools/openapi, minus every
`"additionalProperties": false`.

The server marks its objects closed, and Swift OpenAPI Generator turns that
into `ensureNoAdditionalProperties`, which makes the app fail to decode any
response that has gained a field. A field added on the server then breaks
every build already on a phone (sign-in failed for that reason on
2026-10-16, sc-2381). The app sends only what it was built with, so dropping
the flag loses nothing on requests and lets responses grow (I18).
"""
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "../fantasy-cat/web/openapi.json")
dst = pathlib.Path("Tools/openapi/openapi.json")


def strip(node):
    if isinstance(node, dict):
        if node.get("additionalProperties") is False:
            del node["additionalProperties"]
        for v in node.values():
            strip(v)
    elif isinstance(node, list):
        for v in node:
            strip(v)


spec = json.loads(src.read_text())
strip(spec)
dst.write_text(json.dumps(spec, indent=2) + "\n")
