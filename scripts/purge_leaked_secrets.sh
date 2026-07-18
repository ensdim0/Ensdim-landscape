#!/usr/bin/env bash
set -euo pipefail

echo "This script rewrites Git history to remove known leaked files (DANGEROUS)."
echo "Read the script before running. You must have backups and coordinate with your team."
echo

if ! command -v git &> /dev/null; then
  echo "git is required"
  exit 1
fi

if ! command -v git-filter-repo &> /dev/null; then
  echo "git-filter-repo not found. Install from: https://github.com/newren/git-filter-repo"
  exit 1
fi

read -p "This will remove 'supabase keys.txt' from all commits. Continue? (y/N) " ok
if [[ "$ok" != "y" && "$ok" != "Y" ]]; then
  echo "Aborting."
  exit 1
fi

# Example: remove the specific file from history
git filter-repo --path "supabase keys.txt" --invert-paths --force

echo "History rewritten. You must force-push branches and tags to remote:"
echo "  git push --force --all"
echo "  git push --force --tags"
