---
description: Install this kit on the current machine (this writes to $HOME — ask first)
---

# /kit-onboard

Follow [`AGENT_BOOTSTRAP.md`](../../AGENT_BOOTSTRAP.md) exactly.

This is the one flow in this repository that **writes to the developer's home
directory**: wrappers, PATH and the env file. Confirm with the human before the
first write, then report by name — CLIs kept, installed, missing; wrappers on
PATH; env keys set versus unset — and **never** print a value.

Do not add or enable a Herdr machine and do not install a Herdr integration:
report what you would do and let the human decide.
