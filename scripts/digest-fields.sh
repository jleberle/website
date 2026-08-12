#!/usr/bin/env bash
# Append RFC 9530 Content-Digest headers (spec: security/digest-fields) for
# the site's machine-readable feed endpoints to public/_headers.
#
# Unlike CSP hashes (template-driven, stable across builds), these digests
# are content-driven: they change on every post. They cannot live in
# static/_headers as a hand-maintained value, so this script runs as part
# of the deploy build (Cloudflare Workers Builds' build command — see
# docs/operations.md) and writes straight into the public/_headers build
# artifact, after Hugo has copied static/_headers there. Re-running is
# idempotent: any previously appended block is replaced, not accumulated.
#
# Deliberately scoped to JSON/XML feeds, not HTML — browsers ignore these
# fields, and per the spec, spending the effort only pays off on
# machine-readable endpoints a client actually verifies.
#
# Usage:
#   scripts/digest-fields.sh              # build, then append digests to public/_headers
#   scripts/digest-fields.sh --check       # verify public/_headers already matches a fresh build
#   scripts/digest-fields.sh --no-build    # reuse an existing public/ (e.g. in CI)
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK=false
NO_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --check)    CHECK=true ;;
    --no-build) NO_BUILD=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if $NO_BUILD; then
  [[ -d public ]] || { echo "Error: --no-build set but public/ not found." >&2; exit 2; }
else
  hugo --quiet
fi

# path-on-disk:path-as-served
TARGETS=(
  "public/index.xml:/index.xml"
  "public/reading/index.xml:/reading/index.xml"
  "public/feed.json:/feed.json"
)

digest_of() {
  # Prefer openssl; fall back to GNU coreutils (sha256sum + basenc), in case
  # Cloudflare's build image lacks an openssl CLI.
  if command -v openssl >/dev/null; then
    openssl dgst -sha256 -binary "$1" | openssl base64 -A
  elif command -v sha256sum >/dev/null && command -v basenc >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1 | tr 'a-f' 'A-F' | basenc --base16 -d | basenc --base64 -w0
  else
    echo "Error: need either openssl or (sha256sum + basenc) to compute a digest." >&2
    exit 2
  fi
}

MARK_START="# BEGIN generated Content-Digest (scripts/digest-fields.sh — do not hand-edit)"
MARK_END="# END generated Content-Digest"

BLOCK="$MARK_START"
for t in "${TARGETS[@]}"; do
  disk="${t%%:*}"
  served="${t#*:}"
  [[ -f "$disk" ]] || { echo "Error: $disk not found — did the build produce it?" >&2; exit 2; }
  d=$(digest_of "$disk")
  BLOCK+=$'\n'"$served"$'\n'"  Content-Digest: sha-256=:${d}:"$'\n'
done
BLOCK+="$MARK_END"

extract_block() {
  awk -v start="$MARK_START" -v end="$MARK_END" \
    '$0==start{p=1} p{print} $0==end{p=0}' "$1"
}

strip_block() {
  awk -v start="$MARK_START" -v end="$MARK_END" \
    '$0==start{p=1} !p{print} $0==end{p=0}' "$1"
}

if $CHECK; then
  if [[ ! -f public/_headers ]]; then
    echo "DRIFT: public/_headers not found." >&2
    exit 1
  fi
  CURRENT=$(extract_block public/_headers)
  if [[ "$CURRENT" == "$BLOCK" ]]; then
    echo "OK: Content-Digest headers in public/_headers match the current build."
    exit 0
  else
    echo "DRIFT: Content-Digest headers in public/_headers do not match a fresh build." >&2
    echo "Run scripts/digest-fields.sh (not --check) as part of the deploy build." >&2
    exit 1
  fi
fi

[[ -f public/_headers ]] || { echo "Error: public/_headers not found — did Hugo copy static/_headers?" >&2; exit 2; }

# Strip any previously appended block, then append the fresh one.
TMP=$(mktemp)
strip_block public/_headers > "$TMP"
printf '%s\n' "$(cat "$TMP")" > public/_headers
rm -f "$TMP"

{
  echo ""
  echo "$BLOCK"
} >> public/_headers

echo "Wrote Content-Digest headers for ${#TARGETS[@]} feed endpoint(s) to public/_headers."
