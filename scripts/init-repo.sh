#!/usr/bin/env bash
# Replaces the __GITHUB_USER__ / __DOCKERHUB_USER__ placeholders with your accounts.
# Usage: scripts/init-repo.sh <github-user> <dockerhub-user>
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <github-user> <dockerhub-user>" >&2
  exit 1
fi

github_user="$1"
dockerhub_user="$2"
cd "$(dirname "$0")/.."

mapfile -t files < <(grep -rlE '__(GITHUB|DOCKERHUB)_USER__' \
  --exclude-dir=.git --exclude-dir=.terraform --exclude=init-repo.sh .)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Nothing to replace: the repository is already initialized."
  exit 0
fi

for file in "${files[@]}"; do
  sed -i.bak -e "s/__GITHUB_USER__/${github_user}/g" -e "s/__DOCKERHUB_USER__/${dockerhub_user}/g" "$file"
  rm -f "$file.bak"
  echo "updated $file"
done
