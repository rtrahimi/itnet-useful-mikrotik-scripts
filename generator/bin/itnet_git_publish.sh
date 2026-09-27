#!/usr/bin/env bash
# Publish local files into itnet-useful-mikrotik-scripts under flock.
# Usage: itnet_git_publish.sh <commit-message> <src>:<relative-dest> [...]
set -euo pipefail

SCRIPTS_REPO_URL="${SCRIPTS_REPO_URL:-git@github.com:rtrahimi/itnet-useful-mikrotik-scripts.git}"
SCRIPTS_REPO_DIR="${SCRIPTS_REPO_DIR:-/data/repo}"
SCRIPTS_BRANCH="${SCRIPTS_BRANCH:-main}"
COMMIT_NAME="${COMMIT_NAME:-Morteza Rahimi}"
COMMIT_EMAIL="${COMMIT_EMAIL:-rtrahimi@gmail.com}"
LOCK_FILE="${LOCK_FILE:-/data/lock/itnet-useful-mikrotik-scripts.lock}"
GIT_DEPLOY_KEY="${GIT_DEPLOY_KEY:-/run/secrets/git_deploy_key}"

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <commit-message> <src>:<relative-dest> [...]" >&2
  exit 2
fi

commit_msg="$1"
shift

if [ ! -f "$GIT_DEPLOY_KEY" ]; then
  echo "deploy key missing: $GIT_DEPLOY_KEY" >&2
  exit 1
fi

install -m 600 "$GIT_DEPLOY_KEY" /tmp/git_deploy_key
export GIT_SSH_COMMAND="ssh -i /tmp/git_deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

mkdir -p "$(dirname "$LOCK_FILE")"
exec 200>"$LOCK_FILE"
flock -x 200

if [ ! -d "$SCRIPTS_REPO_DIR/.git" ]; then
  git clone "$SCRIPTS_REPO_URL" "$SCRIPTS_REPO_DIR"
fi

git -C "$SCRIPTS_REPO_DIR" config user.name "$COMMIT_NAME"
git -C "$SCRIPTS_REPO_DIR" config user.email "$COMMIT_EMAIL"
# Prefer process env GIT_SSH_COMMAND; restore a stable host key path if present.
if [ -f /root/.ssh/itnet_useful_mikrotik_scripts_deploy ]; then
  git -C "$SCRIPTS_REPO_DIR" config core.sshCommand "ssh -i /root/.ssh/itnet_useful_mikrotik_scripts_deploy -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
else
  git -C "$SCRIPTS_REPO_DIR" config --unset-all core.sshCommand >/dev/null 2>&1 || true
fi

if git -C "$SCRIPTS_REPO_DIR" show-ref --verify --quiet "refs/heads/$SCRIPTS_BRANCH"; then
  git -C "$SCRIPTS_REPO_DIR" checkout "$SCRIPTS_BRANCH"
else
  if git -C "$SCRIPTS_REPO_DIR" ls-remote --exit-code --heads origin "$SCRIPTS_BRANCH" >/dev/null 2>&1; then
    git -C "$SCRIPTS_REPO_DIR" fetch origin "$SCRIPTS_BRANCH"
    git -C "$SCRIPTS_REPO_DIR" checkout -b "$SCRIPTS_BRANCH" "origin/$SCRIPTS_BRANCH"
  else
    git -C "$SCRIPTS_REPO_DIR" checkout -b "$SCRIPTS_BRANCH"
  fi
fi

git -C "$SCRIPTS_REPO_DIR" reset --hard HEAD >/dev/null 2>&1 || true
git -C "$SCRIPTS_REPO_DIR" clean -fd >/dev/null 2>&1 || true

if git -C "$SCRIPTS_REPO_DIR" ls-remote --exit-code --heads origin "$SCRIPTS_BRANCH" >/dev/null 2>&1; then
  git -C "$SCRIPTS_REPO_DIR" fetch origin "$SCRIPTS_BRANCH"
  git -C "$SCRIPTS_REPO_DIR" reset --hard "origin/$SCRIPTS_BRANCH"
fi

rels=()
for spec in "$@"; do
  src="${spec%%:*}"
  rel="${spec#*:}"
  if [ -z "$src" ] || [ -z "$rel" ] || [ "$src" = "$spec" ]; then
    echo "invalid publish spec: $spec (expected src:relative-dest)" >&2
    exit 2
  fi
  if [ ! -f "$src" ]; then
    echo "source file missing: $src" >&2
    exit 1
  fi
  mkdir -p "$SCRIPTS_REPO_DIR/$(dirname "$rel")"
  cp "$src" "$SCRIPTS_REPO_DIR/$rel"
  rels+=("$rel")
done

git -C "$SCRIPTS_REPO_DIR" add "${rels[@]}"

if ! git -C "$SCRIPTS_REPO_DIR" diff --cached --quiet; then
  GIT_AUTHOR_NAME="$COMMIT_NAME" GIT_AUTHOR_EMAIL="$COMMIT_EMAIL" \
  GIT_COMMITTER_NAME="$COMMIT_NAME" GIT_COMMITTER_EMAIL="$COMMIT_EMAIL" \
  git -C "$SCRIPTS_REPO_DIR" commit -m "$commit_msg"
  git -C "$SCRIPTS_REPO_DIR" push origin "$SCRIPTS_BRANCH"
fi
