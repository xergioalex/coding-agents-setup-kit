#!/usr/bin/env python3
"""agentbox — start, inspect and reach the machines you declared, and keep each
one's Herdr saved machine in step with it.

The kit wraps coding agents; this command wraps the *places* you run them: a
docker-compose dev container, a VM, a box you only reach over SSH. Everything it
knows comes from one file you write (default
``~/.config/coding-agents-kit/machines.toml``) — there is no built-in machine
list and nothing is discovered behind your back.

The join key with Herdr is the **SSH alias**: a Herdr saved machine is matched by
its ``target`` field, so no machine id is ever configured and nothing breaks when
one changes.

Degradation contract: every Herdr call is best effort. Herdr absent, machine
absent or a failed call warns **once** and never changes this command's exit
code — your containers must not fail because a sidebar entry did not move.

Usage:
  agentbox ls [--json]
  agentbox status [<name>]
  agentbox up|stop|down|restart <name> [--no-herdr]
  agentbox ssh <name> [-- <command>...]
  agentbox herdr [<name>] [status|add|enable|disable|remove]
  agentbox ssh-config [--write]
  agentbox doctor
"""
import json
import os
import re
import shutil
import subprocess
import sys

KIT = "agentbox"
SSH_INCLUDE = os.path.expanduser("~/.ssh/config.d/coding-agents-kit")
_WARNED = set()


# --------------------------------------------------------------------------
# config
# --------------------------------------------------------------------------
def machines_file():
    return os.path.expanduser(
        os.environ.get("AGENTKIT_MACHINES", "~/.config/coding-agents-kit/machines.toml")
    )


def parse_machines(text):
    """Parse the documented subset of TOML: [[machine]] tables with scalar keys.

    Deliberately not a TOML library: `tomllib` only exists from Python 3.11 and
    this kit must run on whatever Python a machine already has. The subset is
    exactly what machines.example.toml shows — anything richer is a config error
    we would rather report than half-understand.
    """
    out = []
    current = None
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[["):
            if line.replace(" ", "") != "[[machine]]":
                raise ValueError("line %d: only [[machine]] tables are supported" % lineno)
            current = {}
            out.append(current)
            continue
        if line.startswith("["):
            raise ValueError("line %d: only [[machine]] tables are supported" % lineno)
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*(?:#.*)?$', line)
        if not m:
            raise ValueError("line %d: cannot parse %r" % (lineno, raw))
        if current is None:
            raise ValueError("line %d: key outside a [[machine]] table" % lineno)
        key, value = m.group(1), m.group(2).strip()
        if value[:1] in "\"'" and value[-1:] == value[:1] and len(value) >= 2:
            value = value[1:-1]
        elif value in ("true", "false"):
            value = value == "true"
        elif re.match(r'^-?\d+$', value):
            value = int(value)
        current[key] = value
    return out


def load_machines(required=True):
    path = machines_file()
    if not os.path.isfile(path):
        if required:
            die("no machines file at %s. Copy machines.example.toml there and "
                "declare your own — this kit ships no machine list." % path)
        return []
    try:
        machines = parse_machines(open(path, encoding="utf-8").read())
    except ValueError as exc:
        die("%s: %s" % (path, exc))
    for m in machines:
        if not m.get("name"):
            die("%s: a [[machine]] block has no name" % path)
        m.setdefault("ssh", m["name"])
        m.setdefault("label", m["name"])
        for key in ("compose",):
            if m.get(key):
                m[key] = os.path.expanduser(str(m[key]))
    return machines


def find_machine(machines, name):
    for m in machines:
        if m["name"] == name or m["ssh"] == name:
            return m
    die("no machine named %r in %s (have: %s)"
        % (name, machines_file(), ", ".join(m["name"] for m in machines) or "none"))


# --------------------------------------------------------------------------
# output helpers
# --------------------------------------------------------------------------
def die(msg, code=1):
    sys.stderr.write("%s: %s\n" % (KIT, msg))
    raise SystemExit(code)


def warn_once(key, msg):
    if key in _WARNED:
        return
    _WARNED.add(key)
    sys.stderr.write("%s: %s\n" % (KIT, msg))


def run(argv, capture=True, check=False):
    try:
        proc = subprocess.run(
            argv,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            universal_newlines=True,
        )
    except (OSError, ValueError) as exc:
        return 127, "", str(exc)
    if check and proc.returncode != 0:
        return proc.returncode, proc.stdout or "", proc.stderr or ""
    return proc.returncode, proc.stdout or "", proc.stderr or ""


# --------------------------------------------------------------------------
# docker
# --------------------------------------------------------------------------
def compose_argv(machine):
    if not machine.get("compose"):
        return None
    if not shutil.which("docker"):
        return None
    return ["docker", "compose", "-f", machine["compose"]]


def compose_state(machine):
    """running | stopped | no-compose | unknown. Never raises."""
    base = compose_argv(machine)
    if base is None:
        return "no-compose" if not machine.get("compose") else "unknown"
    code, out, _ = run(base + ["ps", "--format", "json"])
    if code != 0:
        return "unknown"
    text = out.strip()
    if not text:
        return "stopped"
    states = []
    for chunk in text.splitlines():
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            data = json.loads(chunk)
        except ValueError:
            continue
        entries = data if isinstance(data, list) else [data]
        for entry in entries:
            if isinstance(entry, dict):
                states.append(str(entry.get("State", "")).lower())
    if not states:
        return "stopped"
    return "running" if any(s.startswith("running") for s in states) else "stopped"


def compose_do(machine, verb):
    base = compose_argv(machine)
    if base is None:
        if machine.get("compose"):
            die("docker is not on PATH, so %r cannot be started here" % machine["name"])
        warn_once("nocompose", "%s has no compose file — only its SSH and Herdr "
                               "sides are managed" % machine["name"])
        return 0
    service = machine.get("service")
    # --remove-orphans is never passed: several stacks can share one compose
    # project, and it would delete the other stacks' containers.
    if verb == "up":
        argv = base + ["up", "-d"] + ([service] if service else [])
    elif verb == "stop":
        argv = base + ["stop"] + ([service] if service else [])
    elif verb == "down":
        argv = base + ["down"]
    elif verb == "restart":
        argv = base + ["restart"] + ([service] if service else [])
    else:
        die("unknown verb %r" % verb)
    code, _, _ = run(argv, capture=False)
    return code


# --------------------------------------------------------------------------
# ssh
# --------------------------------------------------------------------------
def ssh_alias_defined(alias):
    """True when ssh config resolves the alias to a real hostname."""
    if not shutil.which("ssh"):
        return False
    code, out, _ = run(["ssh", "-G", alias])
    if code != 0:
        return False
    for line in out.splitlines():
        if line.startswith("hostname "):
            host = line.split(None, 1)[1].strip()
            return bool(host) and host != alias
    return False


def ssh_reachable(alias, timeout=5):
    if not shutil.which("ssh"):
        return False
    code, _, _ = run([
        "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=%d" % timeout,
        alias, "true",
    ])
    return code == 0


def render_ssh_include(machines):
    lines = [
        "# Generated by `agentbox ssh-config --write` — do not edit by hand.",
        "# Every value comes from your machines file; regenerating is free.",
        "#",
        "# Add this line near the TOP of ~/.ssh/config:",
        "#   Include ~/.ssh/config.d/coding-agents-kit",
        "",
    ]
    written = 0
    for m in machines:
        if not m.get("port"):
            continue
        written += 1
        lines += [
            "# %s" % m["label"],
            "Host %s" % m["ssh"],
            "  HostName %s" % (m.get("host") or "127.0.0.1"),
            "  Port %s" % m["port"],
            "  User %s" % (m.get("user") or os.environ.get("USER", "root")),
            "  StrictHostKeyChecking accept-new",
            "",
        ]
    return "\n".join(lines), written


def write_ssh_include(machines):
    body, count = render_ssh_include(machines)
    if count == 0:
        die("no machine declares a port, so there is nothing to generate "
            "(add port/user to a [[machine]] block, or write the Host block yourself)")
    target = os.path.expanduser(os.environ.get("AGENTKIT_SSH_INCLUDE", SSH_INCLUDE))
    parent = os.path.dirname(target)
    os.makedirs(parent, exist_ok=True)
    for d in (os.path.expanduser("~/.ssh"), parent):
        try:
            os.chmod(d, 0o700)
        except OSError:
            pass
    # Refuse to clobber a file this kit did not generate: it may be someone's
    # own include, and overwriting it would silently delete every alias in it.
    if os.path.exists(target):
        head = open(target, encoding="utf-8").readline()
        if "Generated by" not in head:
            die("%s exists and was not generated by this kit — move it aside first" % target)
    tmp = "%s.tmp.%d" % (target, os.getpid())
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(body)
    os.chmod(tmp, 0o600)
    os.replace(tmp, target)
    print("wrote %s (%d host%s)" % (target, count, "" if count == 1 else "s"))
    main_config = os.path.expanduser("~/.ssh/config")
    included = False
    if os.path.isfile(main_config):
        included = "config.d/coding-agents-kit" in open(main_config, encoding="utf-8").read()
    if not included:
        # We never write ~/.ssh/config itself. One line is the user's to add.
        print("next: add this line near the TOP of %s" % main_config)
        print("  Include ~/.ssh/config.d/coding-agents-kit")
    return 0


# --------------------------------------------------------------------------
# herdr (best effort, always)
# --------------------------------------------------------------------------
def herdr_available():
    return shutil.which("herdr") is not None


def herdr_machines():
    if not herdr_available():
        warn_once("herdr", "herdr is not installed; leaving machines alone")
        return []
    code, out, _ = run(["herdr", "machine", "list", "--json"])
    if code != 0 or not out.strip():
        warn_once("herdrlist", "could not read the Herdr machine list; skipping")
        return []
    try:
        data = json.loads(out)
    except ValueError:
        warn_once("herdrjson", "could not parse the Herdr machine list; skipping")
        return []
    return [m for m in data if isinstance(m, dict)] if isinstance(data, list) else []


def herdr_machine_for(alias, catalog=None):
    for m in catalog if catalog is not None else herdr_machines():
        if m.get("target") == alias:
            return m
    return None


def herdr_set_state(machine, action, catalog=None):
    """enable|disable. Warns once on any failure; always returns 0."""
    if not herdr_available():
        warn_once("herdr", "herdr is not installed; leaving machines alone")
        return 0
    entry = herdr_machine_for(machine["ssh"], catalog)
    if entry is None:
        return 0  # no machine yet is a normal state, not an error
    code, _, _ = run(["herdr", "machine", action, str(entry.get("id", ""))])
    if code == 0:
        print("herdr: machine %s %sd" % (machine["ssh"], action))
    else:
        warn_once("herdr%s" % action,
                  "could not %s machine %s; continuing" % (action, machine["ssh"]))
    return 0


def herdr_add(machine):
    """Create a saved machine. Unlike the lifecycle path this one is loud."""
    if not herdr_available():
        die("herdr is not installed")
    if not ssh_alias_defined(machine["ssh"]):
        die("your ssh config does not resolve %r — run `agentbox ssh-config --write` "
            "or add the Host block yourself first" % machine["ssh"])
    if not sys.stdin.isatty():
        die("`herdr machine add` prompts, so it needs a terminal — run this in one")
    code, _, _ = run(["herdr", "machine", "add", machine["ssh"], "--label", machine["label"]],
                     capture=False)
    return code


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------
def cmd_ls(args):
    machines = load_machines(required=False)
    if "--json" in args:
        print(json.dumps(machines, indent=2))
        return 0
    if not machines:
        print("no machines declared (%s)" % machines_file())
        print("copy machines.example.toml there to manage containers or remote boxes")
        return 0
    print("%-16s %-18s %-10s %s" % ("NAME", "SSH ALIAS", "STATE", "LABEL"))
    for m in machines:
        print("%-16s %-18s %-10s %s" % (m["name"], m["ssh"], compose_state(m), m["label"]))
    return 0


def cmd_status(args):
    machines = load_machines(required=False)
    if args:
        machines = [find_machine(machines, args[0])]
    if not machines:
        print("no machines declared (%s)" % machines_file())
        return 0
    catalog = herdr_machines()
    for m in machines:
        entry = herdr_machine_for(m["ssh"], catalog)
        if entry is None:
            herdr_state = "no machine"
        else:
            herdr_state = "enabled" if entry.get("enabled") else "disabled"
        print("%s" % m["name"])
        print("  compose : %s" % compose_state(m))
        print("  ssh     : alias %s, %s" % (
            "defined" if ssh_alias_defined(m["ssh"]) else "NOT defined",
            "reachable" if ssh_reachable(m["ssh"]) else "not reachable"))
        print("  herdr   : %s" % herdr_state)
    return 0


def cmd_lifecycle(verb, args):
    no_herdr = "--no-herdr" in args or os.environ.get("AGENTBOX_NO_HERDR")
    names = [a for a in args if not a.startswith("-")]
    machines = load_machines()
    if not names:
        die("which machine? %s" % ", ".join(m["name"] for m in machines))
    machine = find_machine(machines, names[0])
    code = compose_do(machine, verb)
    if no_herdr:
        return code
    # up enables the machine; stop/down disable it. Either of those two leaves
    # the box unable to answer SSH, and an enabled machine would then only be a
    # sidebar entry that fails to connect.
    if verb in ("up", "restart"):
        herdr_set_state(machine, "enable")
    elif verb in ("stop", "down"):
        herdr_set_state(machine, "disable")
    return code


def cmd_ssh(args):
    if not args:
        die("which machine?")
    machines = load_machines()
    machine = find_machine(machines, args[0])
    rest = args[1:]
    if rest and rest[0] == "--":
        rest = rest[1:]
    if not shutil.which("ssh"):
        die("ssh is not on PATH")
    os.execvp("ssh", ["ssh", machine["ssh"]] + rest)


def cmd_herdr(args):
    machines = load_machines(required=False)
    verbs = ("status", "add", "enable", "disable", "remove")
    name, verb = None, "status"
    for a in args:
        if a in verbs:
            verb = a
        elif not a.startswith("-"):
            name = a
    targets = [find_machine(machines, name)] if name else machines
    if not targets:
        print("no machines declared (%s)" % machines_file())
        return 0
    catalog = herdr_machines()
    if verb == "status":
        print("%-16s %-18s %s" % ("NAME", "SSH ALIAS", "HERDR"))
        for m in targets:
            entry = herdr_machine_for(m["ssh"], catalog)
            state = "no machine" if entry is None else (
                "enabled" if entry.get("enabled") else "disabled")
            print("%-16s %-18s %s" % (m["name"], m["ssh"], state))
        return 0
    if name is None:
        die("%r needs one machine name — it is not a fleet-wide operation" % verb)
    machine = targets[0]
    if verb == "add":
        return herdr_add(machine)
    if verb == "remove":
        entry = herdr_machine_for(machine["ssh"], catalog)
        if entry is None:
            die("no saved Herdr machine targets %r" % machine["ssh"])
        if not herdr_available():
            die("herdr is not installed")
        code, _, _ = run(["herdr", "machine", "remove", str(entry.get("id", ""))], capture=False)
        return code
    if not herdr_available():
        die("herdr is not installed")
    entry = herdr_machine_for(machine["ssh"], catalog)
    if entry is None:
        die("no saved Herdr machine targets %r — create one with `agentbox herdr %s add`"
            % (machine["ssh"], machine["name"]))
    return herdr_set_state(machine, verb, catalog)


def cmd_ssh_config(args):
    machines = load_machines()
    if "--write" in args:
        return write_ssh_include(machines)
    body, count = render_ssh_include(machines)
    sys.stdout.write(body)
    if count == 0:
        sys.stderr.write("%s: no machine declares a port — nothing to generate\n" % KIT)
    return 0


def cmd_doctor(args):
    """Reconcile the three sources that must agree: your machines file, your ssh
    config, and the Herdr catalog. Reports; never fixes what a human owns."""
    machines = load_machines(required=False)
    if not machines:
        print("  note    no machines file at %s — nothing to reconcile" % machines_file())
        return 0
    catalog = herdr_machines()
    targets = [m.get("target") for m in catalog]
    problems = 0
    for m in machines:
        alias = m["ssh"]
        defined = ssh_alias_defined(alias)
        entry = herdr_machine_for(alias, catalog)
        if not defined:
            problems += 1
            print("  MISSING %s: ssh config does not resolve %r" % (m["name"], alias))
            print("          -> agentbox ssh-config --write, then add the Include line")
        if entry is None:
            near = [t for t in targets if t and t.replace("-", "") == alias.replace("-", "")]
            if near:
                problems += 1
                print("  MISSING %s: this kit says %r, a saved machine says %r"
                      % (m["name"], alias, near[0]))
                print("          -> a machine's target cannot be renamed, only removed and re-added")
            else:
                print("  note    %s: no saved Herdr machine yet" % m["name"])
                print("          -> agentbox herdr %s add" % m["name"])
        elif defined:
            print("  ok      %s: ssh alias and Herdr machine agree" % m["name"])
    if problems == 0:
        print("  ok      %d machine(s) reconciled" % len(machines))
    return 0


USAGE = __doc__.split("Usage:")[1].strip()


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print("Usage:\n  " + USAGE.replace("\n", "\n"))
        return 0
    cmd, args = argv[0], argv[1:]
    if cmd == "ls" or cmd == "list":
        return cmd_ls(args)
    if cmd == "status":
        return cmd_status(args)
    if cmd in ("up", "stop", "down", "restart"):
        return cmd_lifecycle(cmd, args)
    if cmd == "ssh":
        return cmd_ssh(args)
    if cmd == "herdr":
        return cmd_herdr(args)
    if cmd == "ssh-config":
        return cmd_ssh_config(args)
    if cmd == "doctor":
        return cmd_doctor(args)
    sys.stderr.write("%s: unknown command %s\n\nUsage:\n  %s\n" % (KIT, cmd, USAGE))
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
