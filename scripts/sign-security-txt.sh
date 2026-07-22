#!/usr/bin/env bash
# Clearsign static/.well-known/security.txt with the OpenPGP key advertised in
# its own Encryption field, per RFC 9116 §2.3 ("the file SHOULD be digitally
# signed"). The signature covers the exact bytes, so re-run this after ANY edit
# to the file — most commonly after bumping the Expires date.
#
# Usage:
#   scripts/sign-security-txt.sh          # clearsign in place (needs the private key)
#   scripts/sign-security-txt.sh --check  # verify signature + expiry only; exit 1
#                                          # if unsigned, tampered, or expired
#
# --check imports only the published public key (static/key.asc) into a throwaway
# keyring, so it runs in CI without the private key and without touching the
# user's real GnuPG keyring.
set -euo pipefail
cd "$(dirname "$0")/.."

FILE="static/.well-known/security.txt"
PUBKEY="static/key.asc"
SIGNER="jared@jaredeberle.org"

CHECK=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v gpg >/dev/null || { echo "Error: gpg not found." >&2; exit 2; }
[[ -f "$FILE" ]]   || { echo "Error: $FILE not found." >&2; exit 2; }
[[ -f "$PUBKEY" ]] || { echo "Error: $PUBKEY not found." >&2; exit 2; }

# Fail if the Expires field (the one date field RFC 9116 requires) is missing,
# unparseable, or in the past. Uses python3 for cross-platform date handling
# (BSD/macOS `date` and GNU `date` disagree on parsing flags).
check_expiry() {
  python3 - "$FILE" <<'PY'
import re, sys, datetime
text = open(sys.argv[1]).read()
m = re.search(r'^Expires:\s*(\S+)', text, re.M)
if not m:
    print("security.txt has no Expires field"); sys.exit(1)
raw = m.group(1).replace("Z", "+00:00")
try:
    exp = datetime.datetime.fromisoformat(raw)
except ValueError:
    print(f"security.txt has an unparseable Expires value: {m.group(1)}"); sys.exit(1)
now = datetime.datetime.now(datetime.timezone.utc)
if exp <= now:
    print(f"security.txt Expires {exp.isoformat()} is in the past"); sys.exit(1)
print(f"signed, verifies against key.asc, Expires {exp.date()}")
PY
}

if $CHECK; then
  if ! grep -q "BEGIN PGP SIGNED MESSAGE" "$FILE"; then
    echo "security.txt is not clearsigned — run scripts/sign-security-txt.sh" >&2
    exit 1
  fi
  GNUPGHOME="$(mktemp -d)"; export GNUPGHOME
  trap 'rm -rf "$GNUPGHOME"' EXIT
  gpg --batch --quiet --import "$PUBKEY" 2>/dev/null
  if ! gpg --batch --verify "$FILE" 2>/dev/null; then
    echo "security.txt signature does not verify against $PUBKEY (tampered or wrong key)" >&2
    exit 1
  fi
  check_expiry
  exit 0
fi

# --- Sign mode --------------------------------------------------------------
# Recover the cleartext fields first, so re-signing an already-signed file signs
# the payload rather than nesting a new signature around the old block. gpg
# handles clearsign dash-escaping correctly; the signer's key is local here.
payload="$(mktemp)"
trap 'rm -f "$payload"' EXIT
if grep -q "BEGIN PGP SIGNED MESSAGE" "$FILE"; then
  gpg --batch --quiet --output "$payload" --decrypt "$FILE"
else
  cp "$FILE" "$payload"
fi

gpg --batch --yes --local-user "$SIGNER" --clearsign --output "$FILE.tmp" "$payload"
mv "$FILE.tmp" "$FILE"
echo "Signed $FILE — signature covers exact bytes, so re-run after any edit."
