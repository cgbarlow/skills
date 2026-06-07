#!/usr/bin/env bash
# Easy Supabase auth for the iris CLI — SOURCE this, don't execute it.
#
#     source scripts/iris-auth.sh        # logs in, exports IRIS_URL + IRIS_TOKEN
#     ./shop.sh                          # now authenticated; SKU writeback works
#
# Why this exists: this iris deployment runs in Supabase mode, where the CLI's
# `iris login` (username/password) is disabled (/api/auth/login → 404) and the
# PAT path currently 500s server-side. The one auth that works is a Supabase
# session JWT — the same token the web app uses. This fetches one via Supabase's
# password grant and exports it as IRIS_TOKEN (which overrides any token in
# ~/.config/iris/config.toml). After the first login it caches the *refresh*
# token (0600) and silently reuses it, so you only type your password once.
#
# Config — each value is taken from the environment, else from $IRIS_ENV_FILE,
# else from a gitignored scripts/iris-auth.local.env beside this script:
#   SUPABASE_PROJECT_ID        e.g. abc123  →  https://abc123.supabase.co
#   SUPABASE_PUBLISHABLE_KEY   the public anon/publishable key
#   IRIS_URL                   iris-api backend (default below)
#   IRIS_EMAIL                 optional; prompted if unset

_iris_auth_main() {
    local DEFAULT_IRIS_URL="https://iris-api-gtb3.onrender.com"
    local here cache rt_file resp access refresh err
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # ── Load config (env wins, then IRIS_ENV_FILE, then local.env) ──────
    if [ -z "${SUPABASE_PROJECT_ID:-}" ] || [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
        local f
        for f in "${IRIS_ENV_FILE:-}" "$here/iris-auth.local.env"; do
            [ -n "$f" ] && [ -f "$f" ] || continue
            set -a; . "$f"; set +a
            [ -n "${SUPABASE_PROJECT_ID:-}" ] && [ -n "${SUPABASE_PUBLISHABLE_KEY:-}" ] && break
        done
    fi
    if [ -z "${SUPABASE_PROJECT_ID:-}" ] || [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
        echo "iris-auth: need SUPABASE_PROJECT_ID and SUPABASE_PUBLISHABLE_KEY." >&2
        echo "  Set them in the environment, point IRIS_ENV_FILE at your iris .env," >&2
        echo "  or create $here/iris-auth.local.env with both values." >&2
        return 1
    fi

    local auth_base="https://${SUPABASE_PROJECT_ID}.supabase.co/auth/v1"
    export IRIS_URL="${IRIS_URL:-$DEFAULT_IRIS_URL}"
    cache="${XDG_CONFIG_HOME:-$HOME/.config}/woolies-shopper"
    rt_file="$cache/supabase-refresh-token"
    mkdir -p "$cache"; chmod 700 "$cache" 2>/dev/null || true

    # ── Try the cached refresh token first (no password) ────────────────
    access=""; refresh=""
    if [ -f "$rt_file" ]; then
        resp=$(curl -s -X POST "$auth_base/token?grant_type=refresh_token" \
            -H "apikey: $SUPABASE_PUBLISHABLE_KEY" -H "Content-Type: application/json" \
            -d "{\"refresh_token\":\"$(cat "$rt_file")\"}" 2>/dev/null)
        access=$(printf '%s' "$resp" | jq -r '.access_token // empty' 2>/dev/null)
        refresh=$(printf '%s' "$resp" | jq -r '.refresh_token // empty' 2>/dev/null)
        [ -n "$access" ] && echo "iris-auth: reused cached session (no password needed)."
    fi

    # ── Fall back to a password grant ───────────────────────────────────
    if [ -z "$access" ]; then
        local email password
        email="${IRIS_EMAIL:-}"
        [ -n "$email" ] || { printf 'Iris (Supabase) email: ' >&2; read -r email; }
        printf 'Password: ' >&2; read -rs password; echo >&2
        resp=$(curl -s -X POST "$auth_base/token?grant_type=password" \
            -H "apikey: $SUPABASE_PUBLISHABLE_KEY" -H "Content-Type: application/json" \
            -d "$(jq -nc --arg e "$email" --arg p "$password" '{email:$e,password:$p}')" 2>/dev/null)
        password=""
        access=$(printf '%s' "$resp" | jq -r '.access_token // empty' 2>/dev/null)
        refresh=$(printf '%s' "$resp" | jq -r '.refresh_token // empty' 2>/dev/null)
        if [ -z "$access" ]; then
            err=$(printf '%s' "$resp" | jq -r '.error_description // .msg // .error // "unknown error"' 2>/dev/null)
            echo "iris-auth: login failed — $err" >&2
            return 1
        fi
    fi

    # Cache the (rotated) refresh token for next time; export the access JWT.
    if [ -n "$refresh" ]; then
        printf '%s' "$refresh" > "$rt_file"; chmod 600 "$rt_file" 2>/dev/null || true
    fi
    export IRIS_TOKEN="$access"

    # ── Verify by asking the iris-api backend directly ──────────────────
    # We hit /api/auth/me ourselves (rather than rely on `iris whoami`) so we
    # can surface the backend's exact status + detail when something's wrong.
    local tmp code body detail email_claim sub_claim
    tmp=$(mktemp)
    code=$(curl -s -o "$tmp" -w '%{http_code}' \
        -H "Authorization: Bearer $access" "$IRIS_URL/api/auth/me" 2>/dev/null || echo 000)
    body=$(cat "$tmp" 2>/dev/null); rm -f "$tmp"
    detail=$(printf '%s' "$body" | jq -r '.detail // empty' 2>/dev/null || true)

    if [ "$code" = "200" ]; then
        local uname role
        uname=$(printf '%s' "$body" | jq -r '.username // .email // "?"' 2>/dev/null || echo '?')
        role=$(printf '%s' "$body" | jq -r '.role // "?"' 2>/dev/null || echo '?')
        echo "iris-auth: authenticated as $uname (role: $role) against $IRIS_URL."
        echo "  IRIS_TOKEN exported for this shell. Supabase tokens are short-lived (~1h);"
        echo "  re-run 'source scripts/iris-auth.sh' to refresh (no password — uses the cached refresh token)."
        return 0
    fi

    # Decode the JWT payload to help diagnose (base64url, add padding).
    local pl
    pl=$(printf '%s' "$access" | cut -d. -f2 | tr '_-' '/+')
    pl=$(printf '%s%s' "$pl" "$(printf '%*s' $(( (4 - ${#pl} % 4) % 4 )) '' | tr ' ' '=')")
    email_claim=$(printf '%s' "$pl" | base64 -d 2>/dev/null | jq -r '.email // empty' 2>/dev/null || true)
    sub_claim=$(printf '%s' "$pl" | base64 -d 2>/dev/null | jq -r '.sub // empty' 2>/dev/null || true)

    echo "iris-auth: Supabase login succeeded, but the iris-api backend rejected the token." >&2
    echo "  /api/auth/me → HTTP $code${detail:+  ($detail)}" >&2
    [ -n "$email_claim" ] && echo "  token identity: ${email_claim} (sub ${sub_claim:-?})" >&2
    case "$detail" in
        *"not found"*|*"inactive"*)
            echo "  → You authenticated with Supabase, but there is no active 'profiles' row for" >&2
            echo "    this user in Iris. Supabase *auth* (login) is separate from the app's" >&2
            echo "    *profiles* (authorization). Use the SAME account you log into the web app" >&2
            echo "    with, or have an Iris admin provision a profile for ${email_claim:-this user}." >&2 ;;
        *"Invalid token"*|*"claims"*)
            echo "  → Signature/claims didn't validate. Confirm IRIS_URL is the iris-api host and" >&2
            echo "    the deployment's Supabase project matches SUPABASE_PROJECT_ID/PUBLISHABLE_KEY." >&2 ;;
        *)
            [ "$code" = "500" ] && echo "  → 500 is a backend crash (see iris issue #286 for the PAT variant)." >&2 ;;
    esac
    return 1
}

# Guard: only useful when sourced (exports must land in the caller's shell).
if (return 0 2>/dev/null); then
    _iris_auth_main
else
    echo "Run this with 'source': source scripts/iris-auth.sh" >&2
    echo "(Executing it normally would set IRIS_TOKEN in a subshell that vanishes.)" >&2
    exit 1
fi
