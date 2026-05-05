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
    -destination 'generic/platform=iOS' \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    CODE_SIGNING_ALLOWED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build >/dev/null
}

bundle_kb_du() {
  local path="$1"
  du -sk "${path}" | awk '{print $1}'
}

strip_framework_binary() {
  local framework_path="$1"
  local name binary

  name="$(basename "${framework_path}" .framework)"
  binary="${framework_path}/${name}"

  if [[ -f "${binary}" ]]; then
    echo "==> Stripping symbols from ${binary}" >&2
    strip -S -x "${binary}"
  fi
}

embedded_dependencies_kb() {
  local framework_path="$1"
  local deps_kb=0

  if [[ -d "${framework_path}/Frameworks" ]]; then
    while IFS= read -r dep; do
      deps_kb=$((deps_kb + $(bundle_kb_du "${dep}")))
    done < <(
      find "${framework_path}/Frameworks" \
        -mindepth 1 -maxdepth 1 \
        \( -type d -name "*.framework" -o -type d -name "*.xcframework" \)
    )
  fi

  echo "${deps_kb}"
}

find_framework_for_scheme() {
  local scheme="$1"
  local products_dir="${DERIVED_DATA_DIR}/Build/Products/Release-iphoneos"

  if [[ -d "${products_dir}/${scheme}.framework" ]]; then
    echo "${products_dir}/${scheme}.framework"
    return 0
  fi

  find "${products_dir}" -maxdepth 1 -type d -name "*.framework" \
    | grep "/${scheme}.framework$" \
    | head -n 1
}

emit_records() {
  rm -rf "${DERIVED_DATA_DIR}"
  mkdir -p "${DERIVED_DATA_DIR}"

  for entry in "${MODULES[@]}"; do
    local module_name scheme framework_path artifact
    local total_kb stripped_kb deps_kb own_kb

    IFS='|' read -r module_name scheme <<< "${entry}"

    echo "==> Building ${module_name} (${scheme})" >&2
    build_scheme "${scheme}"

    framework_path="$(find_framework_for_scheme "${scheme}")" || {
      echo "Failed to find framework: ${scheme}" >&2
      exit 1
    }

    # Measure BEFORE stripping
    total_kb="$(bundle_kb_du "${framework_path}")"

    # Strip symbols
    strip_framework_binary "${framework_path}"

    # Measure AFTER stripping
    stripped_kb="$(bundle_kb_du "${framework_path}")"

    # Embedded dependencies
    deps_kb="$(embedded_dependencies_kb "${framework_path}")"

    # Own size (post-strip)
    own_kb=$((stripped_kb - deps_kb))

    artifact="$(basename "${framework_path}")"

    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${module_name}" \
      "${total_kb}" \
      "${stripped_kb}" \
      "${deps_kb}" \
      "${own_kb}" \
      "${artifact}"
  done
}

print_text() {
  printf "%-30s %12s %14s %14s %18s %s\n" \
    "MODULE" "TOTAL(KB)" "STRIPPED(KB)" "EMBEDDED(KB)" "EXCL.EMBEDDED(KB)" "FRAMEWORK"

  printf "%-30s %12s %14s %14s %18s %s\n" \
    "------------------------------" "------------" "--------------" "--------------" "----------------------" "------------------------------"

  while IFS=$'\t' read -r m t s d o a; do
    printf "%-30s %12s %14s %14s %18s %s\n" "$m" "$t" "$s" "$d" "$o" "$a"
  done < <(emit_records)
}

print_markdown() {
  cat <<'EOF'
# iOS SDK package size report

## Package size summary

| Module | Total (KB) | Stripped (KB) | Embedded (KB) | Excl. Embedded (KB) | Framework |
|---|---:|---:|---:|---:|---|
EOF

  while IFS=$'\t' read -r m t s d o a; do
    printf '| `%s` | %s | %s | %s | %s | `%s` |\n' \
      "$m" "$t" "$s" "$d" "$o" "$a"
  done < <(emit_records)

  cat <<'EOF'

## Summary

This report measures the size of each iOS SDK module as a generated **Release framework bundle**.

Because the iOS SDK is distributed through SPM and CocoaPods, modules are compiled inside the consuming application. The framework size reported here is a **CI-friendly approximation of compiled module footprint**, not a direct prediction of final app size.

## Column definitions

| Column | Meaning |
|---|---|
| **Total (KB)** | Full framework bundle size immediately after build (before stripping). |
| **Stripped (KB)** | Size after removing debug/local symbols from the main binary. |
| **Embedded (KB)** | Size of dependency frameworks physically embedded in the bundle. |
| **Excl. Embedded (KB)** | `Stripped - Embedded`. Best approximation of module’s own bundle footprint. |
| **Framework** | Name of the generated framework bundle. |

## Measurement method

1. Build each module scheme from the workspace
2. Use `Release` configuration
3. Use `generic/platform=iOS`
4. Measure `.framework` bundle size with `du -sk`
5. Strip symbols using `strip -S -x`
6. Re-measure stripped size
7. Detect embedded frameworks under `Frameworks/`
8. Compute `Excl. Embedded = Stripped - Embedded`

## Important notes

- This does **not** represent final app size
- Sizes are **not additive** across modules
- Linked dependencies not physically embedded are not subtracted
- Final size depends on linker optimization and actual usage

This report is designed for **SDK footprint tracking and regression detection in CI**.
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