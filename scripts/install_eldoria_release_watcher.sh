#!/usr/bin/env bash
# One-time, operator-approved installation on bacus-server; not run by CI.
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Run installer as root" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f /usr/local/bin/eldoria-release ]] || { echo 'Original release script missing' >&2; exit 3; }

# Patch the one missing pre-build SHA check in place. Never replace the live
# release script with an older repo copy: production may contain hotfixes.
if ! grep -Fq 'ELDORIA_EXPECTED_COMMIT' /usr/local/bin/eldoria-release; then
  cp -p /usr/local/bin/eldoria-release "/usr/local/bin/eldoria-release.before-watcher-$(date -u +%Y%m%dT%H%M%SZ)"
  python3 - <<'PY'
from pathlib import Path
script = Path('/usr/local/bin/eldoria-release')
content = script.read_text()
anchor = 'echo "Source commit=$HEAD"\n'
if content.count(anchor) != 1:
    raise SystemExit('Expected release script SHA anchor not found exactly once')
guard = '''if [[ -n "${ELDORIA_EXPECTED_COMMIT:-}" ]]; then
  [[ "$ELDORIA_EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ && "$HEAD" == "$ELDORIA_EXPECTED_COMMIT" ]] || {
    echo "Release source SHA does not match approved remote branch: $HEAD" >&2; exit 6;
  }
fi
'''
script.write_text(content.replace(anchor, anchor + guard, 1))
PY
  bash -n /usr/local/bin/eldoria-release || { echo 'Release script invalid after patch' >&2; exit 4; }
fi

install -Dm 0755 "$ROOT/scripts/eldoria_release_watcher.py" /usr/local/libexec/eldoria_release_watcher.py
install -Dm 0644 "$ROOT/scripts/systemd/eldoria-release-watcher.service" /etc/systemd/system/eldoria-release-watcher.service
install -Dm 0644 "$ROOT/scripts/systemd/eldoria-release-watcher.timer" /etc/systemd/system/eldoria-release-watcher.timer
install -d -m 0700 /var/lib/eldoria-release-watcher
systemctl daemon-reload
systemctl enable --now eldoria-release-watcher.timer
echo 'WATCHER_INSTALLED. First poll after 3 minutes; no releases triggered by this installer.'