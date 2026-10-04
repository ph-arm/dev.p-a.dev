#!/usr/bin/env bash
#
# Publish the latest site screenshot to a dedicated orphan branch that holds
# only screenshots (no site files). Commits go through the GitHub Git Data API
# with no custom author/committer/signature, so GitHub signs them (Verified).
# Uses the gh CLI (preinstalled on GitHub-hosted runners), which reads the token
# from GH_TOKEN so it never appears on a command line.
# Expects env: GH_TOKEN, REPO. Optional: TARGET_BRANCH (default: screenshots).
set -euo pipefail

BRANCH="${TARGET_BRANCH:-screenshots}"
FILE="$(printf '%s\n' _screenshots/*.png | sort | tail -1)"
MESSAGE="chore: weekly site screenshot $(date -u +%Y-%m-%d)"

api() { # api METHOD ENDPOINT [JSON-body]
  if [ "$#" -ge 3 ]; then
    gh api -X "$1" "$2" -H "X-GitHub-Api-Version: 2022-11-28" --input - <<<"$3"
  else
    gh api -X "$1" "$2" -H "X-GitHub-Api-Version: 2022-11-28"
  fi
}

# Upload the PNG as a blob. base64 is read from a file (not argv) so large
# images stay under the shell's per-argument size limit.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
base64 "$FILE" | tr -d '\n' > "$tmp"
blob_sha="$(api POST "repos/$REPO/git/blobs" "$(jq -n --rawfile content "$tmp" '{content: $content, encoding: "base64"}')" | jq -r '.sha')"

# Current tip of the target branch (empty when the branch does not exist yet).
parent_sha="$(api GET "repos/$REPO/git/ref/heads/$BRANCH" 2>/dev/null | jq -r '.object.sha // empty' || true)"

# Build a tree with just the screenshot. Existing branch: layer it on the
# current tree so earlier screenshots are kept. New branch: start empty so the
# branch only ever contains screenshots.
if [ -n "$parent_sha" ]; then
  base_tree="$(api GET "repos/$REPO/git/commits/$parent_sha" | jq -r '.tree.sha')"
  tree_sha="$(api POST "repos/$REPO/git/trees" "$(jq -n --arg base "$base_tree" --arg path "$FILE" --arg blob "$blob_sha" \
    '{base_tree: $base, tree: [{path: $path, mode: "100644", type: "blob", sha: $blob}]}')" | jq -r '.sha')"
else
  tree_sha="$(api POST "repos/$REPO/git/trees" "$(jq -n --arg path "$FILE" --arg blob "$blob_sha" \
    '{tree: [{path: $path, mode: "100644", type: "blob", sha: $blob}]}')" | jq -r '.sha')"
fi

# Create the commit. Omitting parents on a new branch writes an orphan root.
if [ -n "$parent_sha" ]; then
  commit_sha="$(api POST "repos/$REPO/git/commits" "$(jq -n --arg message "$MESSAGE" --arg tree "$tree_sha" --arg parent "$parent_sha" \
    '{message: $message, tree: $tree, parents: [$parent]}')" | jq -r '.sha')"
else
  commit_sha="$(api POST "repos/$REPO/git/commits" "$(jq -n --arg message "$MESSAGE" --arg tree "$tree_sha" \
    '{message: $message, tree: $tree}')" | jq -r '.sha')"
fi

# Move the branch to the new commit, creating the ref on the first run.
if [ -n "$parent_sha" ]; then
  api PATCH "repos/$REPO/git/refs/heads/$BRANCH" "$(jq -n --arg sha "$commit_sha" '{sha: $sha}')" >/dev/null
else
  api POST "repos/$REPO/git/refs" "$(jq -n --arg ref "refs/heads/$BRANCH" --arg sha "$commit_sha" '{ref: $ref, sha: $sha}')" >/dev/null
fi

echo "Committed $FILE to '$BRANCH' ($commit_sha) — GitHub-signed (Verified)."
