#!/usr/bin/env bash
# Helper: detect which Camoufox runtime system libraries are missing, and
# expose the per-distro package lists as a single source of truth so the
# detection, the printed install command, and the opt-in auto-install all
# stay in sync (§13 DRY).
#
# Camoufox bundles its own Firefox binary but links against host-provided
# GTK, NSS, audio and X11 libraries. macOS ships equivalents, so callers
# only run this on Linux.
#
# Usage:
#   source lib/system_libs.sh
#   detect_missing_libs        # populates the MISSING array
#   echo "${MISSING[@]}"       # capitalised sonames not found by ldconfig
#
# IMPORTANT: the X11 sonames are capitalised on disk — libXcomposite.so.1,
# libXdamage.so.1, libXrandr.so.2 — so detection MUST be case-insensitive.
# A case-sensitive `grep` against lowercase names reports these as missing
# even after a successful `apt install` (the bug fixed in v0.2.1).

# Sonames as ldconfig reports them. X11 libs are capitalised on purpose.
REQUIRED_LIBS=(
    libnss3.so
    libgtk-3.so.0
    libasound.so.2
    libdbus-glib-1.so.2
    libxcb.so.1
    libgbm.so.1
    libXcomposite.so.1
    libXdamage.so.1
    libXrandr.so.2
    libxkbcommon.so.0
)

# Distro package names that provide the libs above. Kept aligned with
# REQUIRED_LIBS so the printed command and the auto-installer match.
SYSTEM_LIBS_APT_PKGS="libnss3 libgtk-3-0 libasound2 libdbus-glib-1-2 libxcb1 libgbm1 libxcomposite1 libxdamage1 libxrandr2 libxkbcommon0"
SYSTEM_LIBS_DNF_PKGS="nss gtk3 alsa-lib dbus-glib libxcb mesa-libgbm libXcomposite libXdamage libXrandr libxkbcommon"

# Populate the MISSING array with any REQUIRED_LIBS not known to ldconfig.
# Case-insensitive match (-i) so capitalised X11 sonames resolve correctly.
# Sets MISSING=() when ldconfig is unavailable (caller decides what to do).
detect_missing_libs() {
    MISSING=()
    command -v ldconfig >/dev/null 2>&1 || return 0
    local cache lib
    cache="$(ldconfig -p 2>/dev/null)"
    for lib in "${REQUIRED_LIBS[@]}"; do
        if ! printf '%s\n' "$cache" | grep -qiF "$lib"; then
            MISSING+=("$lib")
        fi
    done
}
