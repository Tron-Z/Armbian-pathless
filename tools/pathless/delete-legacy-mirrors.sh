#!/usr/bin/env bash
# 删除 pathless-*-legacy-mirror（需 delete_repo scope）
set -euo pipefail
gh auth refresh -h github.com -s delete_repo,repo
for r in pathless-u-boot-legacy-mirror pathless-rkbin-legacy-mirror pathless-linux-rockchip-legacy-mirror; do
  if gh repo view "Tron-Z/${r}" >/dev/null 2>&1; then
    echo "Deleting Tron-Z/${r} ..."
    gh repo delete "Tron-Z/${r}" --yes
  else
    echo "already gone: ${r}"
  fi
done
echo done
