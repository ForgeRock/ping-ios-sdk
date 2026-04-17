#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_PATH="${ROOT_DIR}/SampleApps/Ping.xcworkspace"
DERIVED_DATA_DIR="${ROOT_DIR}/.build/size-derived-data"
MODE="${1:-text}"

MODULES=(
  "Logger|PingLogger"
  "Storage|PingStorage"
  "Network|PingNetwork"
  "Commons|PingCommons"
  "Orchestrate|PingOrchestrate"
  "DavinciPlugin|PingDavinciPlugin"
  "JourneyPlugin|PingJourneyPlugin"
  "Oidc|PingOidc"
  "Davinci|PingDavinci"
  "TamperDetector|PingTamperDetector"
  "DeviceId|PingDeviceId"
  "DeviceProfile|PingDeviceProfile"
  "Journey|PingJourney"
  "DeviceClient|PingDeviceClient"
  "ExternalIdP|PingExternalIdP"
  "ExternalIdPApple|PingExternalIdPApple"
  "ExternalIdPGoogle|PingExternalIdPGoogle"
  "ExternalIdPFacebook|PingExternalIdPFacebook"
  "Protect|PingProtect"
  "ReCaptchaEnterprise|PingReCaptchaEnterprise"
  "Fido|PingFido"
  "Oath|PingOath"
  "Push|PingPush"
  "Binding|PingBinding"
  "AuthMigration|PingAuthMigration"
)

build_scheme() {
  local scheme="$1"

  xcodebuild \
    -workspace "${WORKSPACE_PATH}" \
    -scheme "${scheme}" \
    -configuration Release \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null
}

framework_kb_du() {
  local framework_path="$1"
  du -sk "${framework_path}" | awk '{print $1}'
}

find_framework_for_scheme() {
  local scheme="$1"
  local products_dir="${DERIVED_DATA_DIR}/Build/Products/Release-iphonesimulator"

  if [[ -d "${products_dir}/${scheme}.framework" ]]; then
    echo "${products_dir}/${scheme}.framework"
    return 0
  fi

  while IFS= read -r fw; do
    if [[ "$(basename "${fw}" .framework)" == "${scheme}" ]]; then
      echo "${fw}"
      return 0
    fi
  done < <(find "${products_dir}" -maxdepth 1 -type d -name "*.framework")

  return 1
}

emit_records() {
  rm -rf "${DERIVED_DATA_DIR}"
  mkdir -p "${DERIVED_DATA_DIR}"

  for entry in "${MODULES[@]}"; do
    local module_name scheme framework_path kb artifact
    IFS='|' read -r module_name scheme <<< "${entry}"

    echo "==> Building ${module_name} (${scheme})" >&2
    build_scheme "${scheme}"

    framework_path="$(find_framework_for_scheme "${scheme}")" || {
      echo "Failed to find framework output for scheme: ${scheme}" >&2
      exit 1
    }

    kb="$(framework_kb_du "${framework_path}")"
    artifact="$(basename "${framework_path}")"

    printf '%s\t%s\t%s\n' "${module_name}" "${kb}" "${artifact}"
  done
}

print_text() {
  printf "%-30s %12s %s\n" "MODULE" "SIZE(KB)" "FRAMEWORK"
  printf "%-30s %12s %s\n" "------------------------------" "------------" "------------------------------"

  while IFS=$'\t' read -r module kb artifact; do
    printf "%-30s %12s %s\n" "${module}" "${kb}" "${artifact}"
  done < <(emit_records)
}

print_markdown() {
  cat <<'EOF'
# iOS SDK package size report

This report shows the size of each generated **Release framework bundle**.

## What this measures

- Size of each built `.framework` bundle from the workspace
- Useful for comparing module build outputs

## What this does NOT measure

- Final app size after linking
- App Store download size
- Installed app size
- Exact linker stripping or dead-code elimination impact

## Package size summary

| Module | Size (KB) | Framework |
|---|---:|---|
EOF

  while IFS=$'\t' read -r module kb artifact; do
    printf '| `%s` | %s | `%s` |\n' "${module}" "${kb}" "${artifact}"
  done < <(emit_records)

  cat <<'EOF'

## Measurement method

1. Build each module scheme from the workspace in `Release`
2. Use `generic/platform=iOS Simulator`
3. Measure the resulting `.framework` bundle size with `du -sk`

This reflects built framework bundle size, not final app size.
EOF
}

main() {
  if [[ ! -d "${WORKSPACE_PATH}" ]]; then
    echo "Workspace not found: ${WORKSPACE_PATH}" >&2
    exit 1
  fi

  case "${MODE}" in
    text)
      print_text
      ;;
    markdown|md)
      print_markdown
      ;;
    *)
      echo "Usage: $0 [text|markdown]" >&2
      exit 1
      ;;
  esac
}

main "$@"