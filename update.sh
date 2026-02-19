#!/usr/bin/env bash
set -euo pipefail

REPO="dominicnunez/springfield"
VERSION_FILE="$(dirname "$0")/version.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_latest_version() {
  local releases
  releases=$(curl -s "https://api.github.com/repos/$REPO/releases")

  echo "$releases" | jq -r '
    [.[] | select(.prerelease == false and .draft == false and (.assets | length > 0))] |
    .[0].tag_name // empty
  ' | sed 's/^v//'
}

get_current_version() {
  jq -r '.version' "$VERSION_FILE"
}

hash_to_sri() {
  local hash="$1"
  nix hash convert --hash-algo sha256 --to sri "$hash"
}

fetch_hash() {
  local version="$1"
  local platform="$2"
  local url="https://github.com/$REPO/releases/download/v${version}/sfk-${platform}"

  echo -e "${YELLOW}Fetching hash for $platform...${NC}" >&2
  local hash
  hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
  hash_to_sri "$hash"
}

verify_current_hash() {
  local version="$1"
  local platform="x86_64-linux"

  local stored_hash
  stored_hash=$(jq -r ".hashes[\"$platform\"]" "$VERSION_FILE")

  local current_hash
  current_hash=$(fetch_hash "$version" "linux-x64")

  [[ "$stored_hash" == "$current_hash" ]]
}

update_version_file() {
  local new_version="$1"

  echo -e "${GREEN}Updating to version $new_version${NC}"

  local hash_x86_64_linux hash_aarch64_linux hash_x86_64_darwin hash_aarch64_darwin

  hash_x86_64_linux=$(fetch_hash "$new_version" "linux-x64")
  hash_aarch64_linux=$(fetch_hash "$new_version" "linux-arm64")
  hash_x86_64_darwin=$(fetch_hash "$new_version" "darwin-x64")
  hash_aarch64_darwin=$(fetch_hash "$new_version" "darwin-arm64")

  jq --arg version "$new_version" \
     --arg x86_64_linux "$hash_x86_64_linux" \
     --arg aarch64_linux "$hash_aarch64_linux" \
     --arg x86_64_darwin "$hash_x86_64_darwin" \
     --arg aarch64_darwin "$hash_aarch64_darwin" \
     '.version = $version |
      .hashes["x86_64-linux"] = $x86_64_linux |
      .hashes["aarch64-linux"] = $aarch64_linux |
      .hashes["x86_64-darwin"] = $x86_64_darwin |
      .hashes["aarch64-darwin"] = $aarch64_darwin' \
     "$VERSION_FILE" > "${VERSION_FILE}.tmp" && mv "${VERSION_FILE}.tmp" "$VERSION_FILE"

  echo -e "${GREEN}Successfully updated version.json${NC}"
}

main() {
  local current_version latest_version

  current_version=$(get_current_version)
  latest_version=$(get_latest_version)

  if [[ -z "$latest_version" ]]; then
    echo -e "${RED}Failed to fetch latest version${NC}"
    exit 1
  fi

  echo "Current version: $current_version"
  echo "Latest version:  $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${YELLOW}Verifying upstream hash hasn't changed...${NC}" >&2
    if verify_current_hash "$current_version"; then
      echo -e "${GREEN}Already up to date${NC}"
      echo "UPDATE_NEEDED=false"
      exit 0
    else
      echo -e "${YELLOW}Hash mismatch detected - upstream rebuilt $current_version${NC}" >&2
      latest_version="$current_version"
    fi
  fi

  echo -e "${YELLOW}Update available: $current_version -> $latest_version${NC}"
  echo "UPDATE_NEEDED=true"
  echo "NEW_VERSION=$latest_version"

  if [[ "${1:-}" == "--update" ]]; then
    update_version_file "$latest_version"
  else
    echo -e "${YELLOW}Run with --update to apply the update${NC}"
  fi
}

main "$@"
