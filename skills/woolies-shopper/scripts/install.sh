#!/usr/bin/env bash
# Idempotent installer for the woolies-shopper skill's runtime dependencies.
#
# - Verifies Python 3.11+ is available
# - Verifies `pipx` is on PATH (prints install command if not — never sudos)
# - Installs woolies-nz-cli at the pinned version via pipx (skipped when
#   already present and at the right version)
# - Detects missing Camoufox runtime libraries on Linux and prints the
#   exact apt/dnf command for the user to run themselves
# - Ends with `woolies doctor` so any remaining problem surfaces loudly
#
# This script does not require sudo and will not call it. Anywhere a
# privileged action is needed (system library install) the script prints
# the command and exits with status 2 so the caller can prompt the user.

set -euo pipefail

WOOLIES_PINNED_VERSION="0.1.1"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

bold "woolies-shopper install — target version $WOOLIES_PINNED_VERSION"

# ── Python ────────────────────────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 not found on PATH. Install Python 3.11 or newer and re-run."
fi
PY_VERSION="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
PY_MAJOR="${PY_VERSION%%.*}"
PY_MINOR="${PY_VERSION##*.}"
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 11 ]; }; then
    fail "Python $PY_VERSION is too old. woolies-nz-cli needs 3.11+."
fi
echo "  python3 → $PY_VERSION"

# ── pipx ──────────────────────────────────────────────────────────────
if ! command -v pipx >/dev/null 2>&1; then
    warn ""
    warn "pipx is not installed. Recommended install commands:"
    warn "  macOS:    brew install pipx && pipx ensurepath"
    warn "  Debian:   sudo apt install pipx && pipx ensurepath"
    warn "  Fedora:   sudo dnf install pipx && pipx ensurepath"
    warn "  uv users: uv tool install woolies-nz-cli==$WOOLIES_PINNED_VERSION (skip pipx)"
    warn ""
    warn "Re-run this script after pipx is on PATH, or install woolies-nz-cli yourself."
    exit 2
fi
echo "  pipx     → $(pipx --version 2>/dev/null || echo 'unknown')"

# ── woolies-nz-cli ────────────────────────────────────────────────────
INSTALLED_VERSION="$(woolies --version 2>/dev/null | awk '{print $NF}' || true)"
if [ "$INSTALLED_VERSION" = "$WOOLIES_PINNED_VERSION" ]; then
    echo "  woolies  → $INSTALLED_VERSION (already at pinned version, skipping install)"
else
    if [ -n "$INSTALLED_VERSION" ]; then
        echo "  woolies  → $INSTALLED_VERSION installed; upgrading to $WOOLIES_PINNED_VERSION"
        pipx install --force "woolies-nz-cli==$WOOLIES_PINNED_VERSION"
    else
        echo "  woolies  → not installed; installing $WOOLIES_PINNED_VERSION"
        pipx install "woolies-nz-cli==$WOOLIES_PINNED_VERSION"
    fi
fi

# ── Linux runtime libs for Camoufox (Firefox) ─────────────────────────
# Camoufox bundles its own Firefox binary but uses host-provided GTK,
# NSS, audio and X11 libs. macOS bundles equivalents so we only check
# on Linux. We never sudo — we print the install command for the user.
if [ "$(uname -s)" = "Linux" ]; then
    REQUIRED_LIBS=(libnss3.so libgtk-3.so.0 libasound.so.2 libdbus-glib-1.so.2 libxcb.so.1 libgbm.so.1 libxcomposite.so.1 libxdamage.so.1 libxrandr.so.2 libxkbcommon.so.0)
    MISSING=()
    if command -v ldconfig >/dev/null 2>&1; then
        for lib in "${REQUIRED_LIBS[@]}"; do
            if ! ldconfig -p 2>/dev/null | grep -q "$lib"; then
                MISSING+=("$lib")
            fi
        done
    else
        warn "  ldconfig not found — skipping Camoufox system-lib check"
    fi
    if [ "${#MISSING[@]}" -gt 0 ]; then
        warn ""
        warn "Camoufox needs these system libraries which are not on this host:"
        for lib in "${MISSING[@]}"; do warn "  - $lib"; done
        warn ""
        warn "Install them with the command for your distro:"
        warn "  Debian/Ubuntu: sudo apt install -y libnss3 libgtk-3-0 libasound2 \\"
        warn "                   libdbus-glib-1-2 libxcb1 libgbm1 libxcomposite1 \\"
        warn "                   libxdamage1 libxrandr2 libxkbcommon0"
        warn "  Fedora/RHEL:   sudo dnf install -y nss gtk3 alsa-lib dbus-glib \\"
        warn "                   libxcb mesa-libgbm libXcomposite libXdamage \\"
        warn "                   libXrandr libxkbcommon"
        warn ""
        warn "  After installing, re-run this script. (We don't sudo for you.)"
        exit 2
    fi
fi

# ── jq (needed by shop.sh / phase2_bulk_add.sh) ───────────────────────
if ! command -v jq >/dev/null 2>&1; then
    warn ""
    warn "jq is required by shop.sh (the phased orchestrator added in v0.2.0)."
    warn "Install commands:"
    warn "  macOS:    brew install jq"
    warn "  Debian:   sudo apt install -y jq"
    warn "  Fedora:   sudo dnf install -y jq"
    warn ""
    warn "Re-run this script once jq is installed."
    exit 2
fi
echo "  jq       → $(jq --version 2>/dev/null || echo 'unknown')"

# ── iris CLI (needed by shop.sh phase 2 to read aggregated lists, walk
#    Ingredient element attributes, and write back resolved SKUs) ─────
if ! command -v iris >/dev/null 2>&1; then
    warn ""
    warn "iris CLI is required by shop.sh phase 2 + phase 3 writeback."
    warn "Install with: uv tool install iris-cli  (or pipx install iris-cli)"
    warn "Then run: iris login"
    warn ""
    warn "shop.sh will refuse to run until iris CLI is authenticated."
    warn "(woolies-only workflows that don't use shop.sh still work without it.)"
    exit 2
fi
if ! iris whoami >/dev/null 2>&1; then
    warn ""
    warn "iris CLI installed but not authenticated."
    warn "Run: iris login"
    warn ""
    exit 2
fi
echo "  iris     → authenticated"

# ── Final health check ────────────────────────────────────────────────
echo ""
bold "Running woolies doctor…"
if ! woolies doctor; then
    warn ""
    warn "woolies doctor reported a problem. The most common cause is that"
    warn "you haven't logged in yet — run \`woolies login\` and re-run doctor."
    exit 2
fi

echo ""
bold "✓ woolies-shopper install complete."
bold "Entry point: ./scripts/shop.sh  (runs the full phased pipeline)"
