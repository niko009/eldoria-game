#!/usr/bin/env python3
"""Opt-in release controller for the existing, root-owned Eldoria release script.

Only release/eldoria-vMAJOR.MINOR.PATCH branches from the fixed repository
are considered. Never executes commands obtained from GitHub.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path


REPOSITORY = "https://github.com/niko009/eldoria-game.git"
RELEASE_BIN = "/usr/local/bin/eldoria-release"
LATEST = Path("/srv/bacus/apps/bacus-dev/site/projects/eldoria/latest.json")
SERVER = Path("/srv/bacus/apps/bacus-dev/site/projects/eldoria/server.json")
STATE = Path("/var/lib/eldoria-release-watcher/state.json")
RELEASE_REF = re.compile(r"^refs/heads/release/eldoria-v([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$")
SHA = re.compile(r"^[0-9a-f]{40}$")


def version_tuple(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{1,3}(?:\.[0-9]{1,3}){2}", value):
        raise ValueError("Invalid release version")
    return tuple(int(part) for part in value.split("."))


def production_version(latest=LATEST, server=SERVER):
    public = json.loads(Path(latest).read_text(encoding="utf-8"))["version"]
    live = json.loads(Path(server).read_text(encoding="utf-8"))["client_version"]
    if public != live:
        raise ValueError("Refusing release: latest.json != server.json")
    version_tuple(public)
    return public


def release_branches(output):
    candidates = []
    for line in output.splitlines():
        fields = line.split()
        if len(fields) != 2 or not SHA.fullmatch(fields[0]):
            continue
        match = RELEASE_REF.fullmatch(fields[1])
        if match:
            version = match.group(1)
            version_tuple(version)
            candidates.append((version_tuple(version), version, fields[1].removeprefix("refs/heads/"), fields[0]))
    return sorted(candidates)


def choose_branch(current, output):
    pending = [x for x in release_branches(output) if x[0] > version_tuple(current)]
    return pending[0] if pending else None


def save_state(state_file, data):
    path = Path(state_file)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=".state-", delete=False) as handle:
        temp = Path(handle.name)
        json.dump(data, handle, ensure_ascii=False, sort_keys=True)
        handle.write("\n")
    os.chmod(temp, 0o600)
    os.replace(temp, path)


def run_once(*, latest=LATEST, server=SERVER, state_file=STATE, repo=REPOSITORY,
             release_bin=RELEASE_BIN, dry_run=False, ls_remote=None, executor=None):
    active = production_version(latest, server)
    if ls_remote is None:
        ls_remote = subprocess.check_output(
            ["/usr/bin/git", "ls-remote", "--heads", repo, "refs/heads/release/eldoria-v*"],
            text=True, timeout=30, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"},
        )
    candidate = choose_branch(active, ls_remote)
    if candidate is None:
        print(f"ELDORIA_WATCH_IDLE production={active}")
        return False
    _, version, branch, commit = candidate
    existing = json.loads(Path(state_file).read_text(encoding="utf-8")) if Path(state_file).exists() else {}
    if existing.get("status") in ("started", "failed") and version_tuple(existing["version"]) > version_tuple(active):
        raise RuntimeError("Release requires review after previous failure/interruption: " + existing["version"])
    if dry_run:
        print(f"ELDORIA_WATCH_DRY_RUN version={version} ref={branch} sha={commit}")
        return True
    if os.geteuid() != 0:
        raise PermissionError("Release watcher must run via its dedicated systemd root service")
    event = {"version": version, "branch": branch, "sha": commit, "status": "started", "previous": active}
    save_state(state_file, event)
    print(f"ELDORIA_WATCH_START version={version} ref={branch} sha={commit}", flush=True)
    if executor is None:
        executor = subprocess.run
    try:
        # The installed release script verifies the immutable expected commit
        # immediately after cloning, before build/deployment operations.
        executor([release_bin, version, branch, "--deploy"], check=True, timeout=2400,
                 env={**os.environ, "ELDORIA_EXPECTED_COMMIT": commit})
        if production_version(latest, server) != version:
            raise RuntimeError("Release command returned success but public version did not advance")
    except Exception as error:
        event["status"] = "failed"
        event["error"] = str(error)[:500]
        save_state(state_file, event)
        raise
    event["status"] = "success"
    save_state(state_file, event)
    print(f"ELDORIA_WATCH_SUCCESS version={version}")
    return True


if __name__ == "__main__":
    try:
        run_once(dry_run="--dry-run" in sys.argv[1:])
    except Exception as error:
        print("ELDORIA_WATCH_ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)