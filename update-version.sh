#!/usr/bin/env -S nix shell nixpkgs#bash nixpkgs#gh nixpkgs#jq nixpkgs#nix-prefetch-github --command bash

# Bumps pin.nix to the requested commit of tcpipuk/mcp-server (GitHub) and re-validates the source hash. Run from the flake root:
#
#   nix run .#update-version              # latest commit on main
#   nix run .#update-version -- <rev>     # specific commit
#
# Always recomputes the hash and rewrites pin.nix if anything changed; idempotent on no-change runs.

set -euo pipefail

FLAKE_ROOT="${FLAKE_ROOT:-${PWD}}"
pin="${FLAKE_ROOT}/pin.nix"

repo_owner=tcpipuk
repo_name=mcp-server

if [[ ! -f "${pin}" ]]; then
  echo "error: no pin.nix in ${FLAKE_ROOT}" >&2
  exit 1
fi

if [[ $# -ge 1 && -n "${1}" ]]; then
  ref="${1}"
  echo "Resolving requested ref ${ref}..."
  commit=$(gh api "/repos/${repo_owner}/${repo_name}/commits/${ref}")
else
  echo "Querying GitHub for latest main commit..."
  commit=$(gh api "/repos/${repo_owner}/${repo_name}/commits/main")
fi
new_rev=$(jq -r '.sha' <<<"${commit}")
new_date=$(jq -r '.commit.committer.date' <<<"${commit}" | cut -d'T' -f1)
new_version="0-unstable-${new_date}"

cur_version=$(nix eval --raw --file "${pin}" version 2>/dev/null || echo "")
cur_rev=$(nix eval --raw --file "${pin}" sourceRev 2>/dev/null || echo "")
cur_hash=$(nix eval --raw --file "${pin}" sourceHash 2>/dev/null || echo "")

echo "  current: ${cur_version} (${cur_rev:-<empty>})"
echo "  target:  ${new_version} (${new_rev})"

echo "Computing source hash..."
new_source_hash=$(nix-prefetch-github --rev "${new_rev}" "${repo_owner}" "${repo_name}" --json | jq -r '.hash // .sha256')

if [[ "${cur_version}" != "${new_version}" || "${cur_rev}" != "${new_rev}" || "${cur_hash}" != "${new_source_hash}" ]]; then
  echo "Writing pin.nix..."
  cat > "${pin}" <<EOF
# Auto-managed by \`nix run .#update-version\`. Manual edits will be overwritten by the next bump.
{
  version = "${new_version}";
  sourceRev = "${new_rev}";
  sourceHash = "${new_source_hash}";
}
EOF
fi

echo "Verifying build..."
nix build --option post-build-hook "" "${FLAKE_ROOT}#searxng-mcp-server" --no-link

echo
echo "Updated to ${new_version} (${new_rev})"
echo "  Commit pin.nix / flake.lock to capture."
