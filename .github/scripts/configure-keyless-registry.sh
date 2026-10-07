#!/usr/bin/env bash
#
# Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.
#

# Configures SwiftPM on a macOS CI runner to resolve the private Keyless registry on Cloudsmith.
#
# Cloudsmith issues two kinds of credential and each authenticates differently:
#   - entitlement token  -> HTTP Basic with username "token" (also accepted as a Bearer token)
#   - user/service API key -> HTTP Basic with the owning Cloudsmith username
# The secret's type is not recorded anywhere, so instead of assuming one the script probes the
# registry with the supplied secret under each scheme and configures SwiftPM for the first one
# Cloudsmith accepts. If none is accepted the credential is genuinely unusable and the script fails
# with the probe results.
#
# The credential is delivered through ~/.netrc plus an `authentication` entry in the user-level
# registries.json. It is NOT stored with `swift package-registry login`: on macOS that writes to
# the keychain, and xcodebuild then blocks forever on a keychain ACL consent prompt that nobody
# can answer on a headless runner.
#
# Environment:
#   CLOUDSMITH_KEYLESS_TOKEN  The Cloudsmith credential. Required. Never printed.
#   CI                        Must be "true" — the script overwrites ~/.netrc.

set -euo pipefail

REGISTRY_HOST="swift.cloudsmith.io"
REGISTRY_URL="https://${REGISTRY_HOST}/keyless/partners/"
PROBE_URL="${REGISTRY_URL}keyless/mobile-sdk"
ACCEPT_HEADER="Accept: application/vnd.swift.registry.v1+json"

if [[ "${CI:-}" != "true" ]]; then
  echo "Refusing to run outside CI: this script overwrites ~/.netrc." >&2
  exit 1
fi

: "${CLOUDSMITH_KEYLESS_TOKEN:?CLOUDSMITH_KEYLESS_TOKEN is not set}"
secret="$CLOUDSMITH_KEYLESS_TOKEN"

# The probes pass the secret to curl through a config on stdin (never argv) and quote it, so
# characters that would break that quoting are rejected up front. A stray newline or space is also
# the classic way a pasted secret ends up wrong, so report it explicitly.
echo "Credential length: ${#secret}"
if [[ "$secret" =~ [[:space:]\"\\] ]]; then
  echo "::error::CLOUDSMITH_KEYLESS_TOKEN contains whitespace, a quote or a backslash — it was most likely pasted with extra characters. Re-set the secret."
  exit 1
fi

# http_code <auth-kind> [username] — prints the HTTP status of the registry probe, or 000.
http_code() {
  local kind="$1" user="${2:-}" code
  code="$({
    case "$kind" in
      basic) printf 'user = "%s:%s"\n' "$user" "$secret" ;;
      bearer) printf 'header = "Authorization: Bearer %s"\n' "$secret" ;;
    esac
  } | curl -sS -o /dev/null -w '%{http_code}' --max-time 30 --config - -H "$ACCEPT_HEADER" "$PROBE_URL" 2>/dev/null)" || true
  echo "${code:-000}"
}

# If the secret is a user API key, the Cloudsmith API reveals the account it belongs to, which is
# the username Basic auth needs. The account name is deliberately not printed (public CI logs).
api_user=""
self_json="$(mktemp)"
self_code="$(printf 'header = "X-Api-Key: %s"\n' "$secret" \
  | curl -sS -o "$self_json" -w '%{http_code}' --max-time 30 --config - https://api.cloudsmith.io/v1/user/self/ 2>/dev/null)" || true
self_code="${self_code:-000}"
if [[ "$self_code" == "200" ]]; then
  api_user="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("slug",""))' "$self_json" 2>/dev/null || true)"
fi
rm -f "$self_json"
echo "Secret is a Cloudsmith user API key: $([[ "$self_code" == "200" ]] && echo yes || echo "no (API answered $self_code)")"

# label | auth kind | netrc login. Order is the order tried.
candidates=("basic-token|basic|token" "basic-pingidentity|basic|pingidentity" "bearer|bearer|token")
if [[ -n "$api_user" ]]; then
  candidates+=("basic-account|basic|$api_user")
fi

chosen_kind=""
chosen_login=""
echo "Probing ${PROBE_URL}"
for candidate in "${candidates[@]}"; do
  IFS='|' read -r label kind login <<<"$candidate"
  code="$(http_code "$kind" "$login")"
  echo "  $label -> HTTP $code"
  if [[ "$code" == "200" && -z "$chosen_kind" ]]; then
    chosen_kind="$kind"
    chosen_login="$login"
    chosen_label="$label"
  fi
done

if [[ -z "$chosen_kind" ]]; then
  echo "::error::Cloudsmith rejected the credential under every scheme (Basic token/pingidentity/account, Bearer). The secret is invalid, expired, or has no access to keyless/partners."
  exit 1
fi
echo "Using scheme: $chosen_label"

# Map the registry to the 'keyless' scope in the user-level config. --global is required: without
# it the mapping lands in a project-local .swiftpm/ that xcodebuild does not read.
swift package-registry set --global --scope keyless "$REGISTRY_URL"

# Declare how SwiftPM should use the netrc credential. On macOS the user-level SwiftPM config lives
# in ~/Library/org.swift.swiftpm (~/.swiftpm is only a symlink some developer machines have).
AUTH_TYPE="$([[ "$chosen_kind" == "bearer" ]] && echo token || echo basic)" \
REGISTRY_HOST="$REGISTRY_HOST" \
python3 - <<'EOF'
import json, os

config_dir = os.path.expanduser("~/Library/org.swift.swiftpm/configuration")
os.makedirs(config_dir, exist_ok=True)
path = os.path.join(config_dir, "registries.json")

config = {}
if os.path.exists(path):
    with open(path) as f:
        config = json.load(f)

config.setdefault("authentication", {})[os.environ["REGISTRY_HOST"]] = {
    "loginAPIPath": "/keyless/partners",
    "type": os.environ["AUTH_TYPE"],
}
with open(path, "w") as f:
    json.dump(config, f, indent=2)
print(f"Wrote {os.environ['AUTH_TYPE']} authentication for {os.environ['REGISTRY_HOST']} to {path}")
EOF

umask 077
printf 'machine %s\nlogin %s\npassword %s\n' "$REGISTRY_HOST" "$chosen_login" "$secret" > "$HOME/.netrc"
echo "Wrote ~/.netrc entry for ${REGISTRY_HOST}"
