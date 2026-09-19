#!/usr/bin/env python3
"""Upsert ONE provider into Pi's ~/.pi/agent/models.json (merge-safe).

Mirrors the container wrappers: the apiKey field holds the literal string
"$ENV_NAME" so Pi resolves it from the environment — the secret never lands
on disk. Refuses to overwrite a file it cannot parse; atomic write; one-time
backup.

Usage: write_pi_provider.py <models.json> <provider_id> <base_url> <ENV_KEY>
         <context_window> <max_tokens> <supports_reasoning_effort:true|false>
         <model_id[:label]>...
"""
import json
import os
import sys
import tempfile
from pathlib import Path

if len(sys.argv) < 9:
    sys.stderr.write(
        "usage: write_pi_provider.py <models.json> <provider> <base_url> <ENV_KEY> "
        "<context_window> <max_tokens> <reasoning_effort:true|false> <model[:label]>...\n"
    )
    sys.exit(2)

path = Path(sys.argv[1])
provider_id = sys.argv[2]
base_url = sys.argv[3]
env_key = sys.argv[4]
context_window = int(sys.argv[5])
max_tokens = int(sys.argv[6])
reasoning_effort = sys.argv[7].lower() == "true"
specs = sys.argv[8:]

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
                "Fix the file by hand (or set PI_MODELS_FILE to another path) and retry.\n"
            )
            sys.exit(1)
    if not isinstance(data, dict):
        sys.stderr.write(f"agentkit: refusing to modify {path}: top level is not an object.\n")
        sys.exit(1)
    backup = path.with_name(path.name + ".agentkit.bak")
    if not backup.exists():
        backup.write_bytes(path.read_bytes())

models = []
seen = set()
for spec in specs:
    mid, _, label = spec.partition(":")
    if not mid or mid in seen:
        continue
    seen.add(mid)
    models.append(
        {
            "id": mid,
            "name": f"{mid} ({label})" if label else mid,
            "reasoning": True,
            "input": ["text", "image"],
            "contextWindow": context_window,
            "maxTokens": max_tokens,
        }
    )

providers = data.setdefault("providers", {})
if not isinstance(providers, dict):
    sys.stderr.write(f"agentkit: refusing to modify {path}: 'providers' is not an object.\n")
    sys.exit(1)
providers[provider_id] = {
    "baseUrl": base_url,
    "api": "openai-completions",
    "apiKey": f"${env_key}",
    "compat": {
        "supportsDeveloperRole": False,
        "supportsReasoningEffort": reasoning_effort,
    },
    "models": models,
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
