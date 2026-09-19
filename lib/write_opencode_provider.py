#!/usr/bin/env python3
"""Merge ONE provider block into OpenCode's opencode.json using {env:KEY}.

Host-safe rules (this file is shared with the user's own OpenCode setup):
  * never writes the raw secret — only the {env:KEY} placeholder;
  * never touches the global `model` default (wrappers pass -m instead);
  * refuses to overwrite a config it cannot parse;
  * keeps a one-time backup and writes atomically.

Usage: write_opencode_provider.py <config.json> <provider> <ENV_KEY> <base_url> <model_id>...
"""
import json
import os
import sys
import tempfile
from pathlib import Path

if len(sys.argv) < 6:
    sys.stderr.write("usage: write_opencode_provider.py <config> <provider> <ENV_KEY> <base_url> <model>...\n")
    sys.exit(2)

path = Path(sys.argv[1])
provider = sys.argv[2]
env_key = sys.argv[3]
base = sys.argv[4]
models = sys.argv[5:]

path.parent.mkdir(parents=True, exist_ok=True)

data = {}
if path.exists():
    raw = path.read_text()
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            sys.stderr.write(
                f"agentkit: refusing to modify {path}: not valid JSON ({exc}). "
                "Fix the file by hand (or set OPENCODE_CONFIG to another path) and retry.\n"
            )
            sys.exit(1)
    if not isinstance(data, dict):
        sys.stderr.write(f"agentkit: refusing to modify {path}: top level is not an object.\n")
        sys.exit(1)
    backup = path.with_name(path.name + ".agentkit.bak")
    if not backup.exists():
        backup.write_bytes(path.read_bytes())

vision = {
    "attachment": True,
    "modalities": {"input": ["text", "image"], "output": ["text"]},
}
whitelist = []
model_map = {}
for mid in models:
    if mid and mid not in whitelist:
        whitelist.append(mid)
        model_map[mid] = {"id": mid, "name": mid, **vision}

providers = data.setdefault("provider", {})
if not isinstance(providers, dict):
    sys.stderr.write(f"agentkit: refusing to modify {path}: 'provider' is not an object.\n")
    sys.exit(1)
existing = providers.get(provider)
existing = existing if isinstance(existing, dict) else {}
options = existing.get("options")
options = dict(options) if isinstance(options, dict) else {}
options.update({"apiKey": "{env:%s}" % env_key, "baseURL": base})
providers[provider] = {
    **existing,
    "options": options,
    "whitelist": whitelist,
    "models": model_map,
}

tmp = tempfile.NamedTemporaryFile(
    "w", dir=str(path.parent), prefix=f".{path.name}.", suffix=".tmp", delete=False
)
try:
    tmp.write(json.dumps(data, indent=2) + "\n")
    tmp.close()
    os.replace(tmp.name, path)
finally:
    if os.path.exists(tmp.name):
        os.unlink(tmp.name)
