#!/usr/bin/env bash
# Unit tests for scripts/lib/system_libs.sh — specifically the case-insensitive
# detection of capitalised X11 sonames (the v0.2.1 regression: lowercase,
# case-sensitive grep falsely reported libXcomposite/libXdamage/libXrandr as
# missing even when installed).
#
# Run with: bash tests/test_system_libs.sh
# Exits 0 if all checks pass, 1 otherwise.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO_ROOT/scripts/lib/system_libs.sh"

PASS=0
FAIL=0
check() { # <description> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   — $1"
        PASS=$((PASS + 1))
    else
        echo "  FAIL — $1 (expected '$2', got '$3')"
        FAIL=$((FAIL + 1))
    fi
}

# A complete ldconfig -p cache reports X11 libs with their real, capitalised
# sonames. Detection must find them despite REQUIRED_LIBS being capitalised
# and the grep being case-insensitive.
FULL_CACHE="	libnss3.so (libc6,AArch64) => /usr/lib/libnss3.so
	libgtk-3.so.0 (libc6,AArch64) => /usr/lib/libgtk-3.so.0
	libasound.so.2 (libc6,AArch64) => /usr/lib/libasound.so.2
	libdbus-glib-1.so.2 (libc6,AArch64) => /usr/lib/libdbus-glib-1.so.2
	libxcb.so.1 (libc6,AArch64) => /usr/lib/libxcb.so.1
	libgbm.so.1 (libc6,AArch64) => /usr/lib/libgbm.so.1
	libXcomposite.so.1 (libc6,AArch64) => /usr/lib/libXcomposite.so.1
	libXdamage.so.1 (libc6,AArch64) => /usr/lib/libXdamage.so.1
	libXrandr.so.2 (libc6,AArch64) => /usr/lib/libXrandr.so.2
	libxkbcommon.so.0 (libc6,AArch64) => /usr/lib/libxkbcommon.so.0"

# Stub ldconfig as a shell function; detect_missing_libs honours it via
# `command -v ldconfig` and `ldconfig -p`.
ldconfig() { printf '%s\n' "$FAKE_CACHE"; }

# Case 1 — everything present (the regression guard).
FAKE_CACHE="$FULL_CACHE"
detect_missing_libs
check "full cache → nothing missing (capitalised X11 libs found)" "" "${MISSING[*]}"

# Case 2 — drop the three X11 libs; they must be reported.
FAKE_CACHE="$(printf '%s\n' "$FULL_CACHE" | grep -v 'libX')"
detect_missing_libs
check "missing X11 libs are reported" "libXcomposite.so.1 libXdamage.so.1 libXrandr.so.2" "${MISSING[*]}"

# Case 3 — package lists stay aligned with REQUIRED_LIBS count (10 libs).
check "REQUIRED_LIBS has 10 entries" "10" "${#REQUIRED_LIBS[@]}"
check "apt package list has 10 entries" "10" "$(set -- $SYSTEM_LIBS_APT_PKGS; echo $#)"
check "dnf package list has 10 entries" "10" "$(set -- $SYSTEM_LIBS_DNF_PKGS; echo $#)"

echo ""
echo "test_system_libs: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
