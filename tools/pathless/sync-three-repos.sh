#!/usr/bin/env bash
# 同步产品分支到 Tron-Z 自有 Fork（仓名固定，勿改名）
#
#   pathless-u-boot / pathless-rkbin / pathless-linux-rockchip / pathless-linux-stable
# 产品分支：vendor | current | edge | bleedingedge
#
# 用法：
#   ./tools/pathless/sync-three-repos.sh              # 全部
#   ./tools/pathless/sync-three-repos.sh uboot|rkbin|kernel-bsp|kernel-mainline
#   ./tools/pathless/sync-three-repos.sh uboot vendor

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${ROOT}/config/sources/pathless-sources.conf"

ONLY_REPO="${1:-all}"
ONLY_BRANCH="${2:-}"
PRODUCT_BRANCHES=(${PATHLESS_SYNC_BRANCHES:-${PATHLESS_PRODUCT_BRANCHES}})
if [[ -n "${ONLY_BRANCH}" ]]; then
	PRODUCT_BRANCHES=("${ONLY_BRANCH}")
fi

OWNER="Tron-Z"

ensure_fork() {
	local name="$1" upstream="$2"
	if ! gh repo view "${OWNER}/${name}" >/dev/null 2>&1; then
		echo "[fork] ${upstream} → ${OWNER}/${name}"
		gh repo fork "${upstream}" --fork-name "${name}" --remote=false
		sleep 5
	fi
	local is_fork
	is_fork="$(gh repo view "${OWNER}/${name}" --json isFork --jq .isFork)"
	if [[ "${is_fork}" != "true" ]]; then
		echo "[error] ${OWNER}/${name} 不是 Fork，勿改名腾位。删非 fork 后重 fork。" >&2
		exit 1
	fi
	echo "[ok] ${OWNER}/${name} is Fork"
}

resolve_sha() {
	local name="$1" ref="$2"
	local sha obj type
	if sha="$(gh api "repos/${OWNER}/${name}/git/ref/heads/${ref}" --jq .object.sha 2>/dev/null)"; then
		printf '%s\n' "${sha}"
		return 0
	fi
	if obj="$(gh api "repos/${OWNER}/${name}/git/ref/tags/${ref}" --jq .object.sha 2>/dev/null)"; then
		type="$(gh api "repos/${OWNER}/${name}/git/ref/tags/${ref}" --jq .object.type)"
		if [[ "${type}" == "tag" ]]; then
			gh api "repos/${OWNER}/${name}/git/tags/${obj}" --jq .object.sha
		else
			printf '%s\n' "${obj}"
		fi
		return 0
	fi
	return 1
}

create_or_update_branch() {
	local name="$1" branch="$2" sha="$3"
	local cur
	if cur="$(gh api "repos/${OWNER}/${name}/git/ref/heads/${branch}" --jq .object.sha 2>/dev/null)"; then
		if [[ "${cur}" == "${sha}" ]]; then
			echo "[skip] ${name} ${branch} 已是 ${sha}（无变更，避免假 push）"
			return 0
		fi
		gh api -X PATCH "repos/${OWNER}/${name}/git/refs/heads/${branch}" -f sha="${sha}" -F force=true \
			--jq '"[upd] "+.ref+" "+.object.sha'
	else
		gh api -X POST "repos/${OWNER}/${name}/git/refs" -f ref="refs/heads/${branch}" -f sha="${sha}" \
			--jq '"[new] "+.ref+" "+.object.sha'
	fi
}

# 若上游跟踪分支不在 fork 上，用已有产品分支 tip 重建（对象已在仓内）
ensure_track_branch() {
	local name="$1" track_ref="$2" seed_branch="$3"
	if resolve_sha "${name}" "${track_ref}" >/dev/null; then
		return 0
	fi
	local seed
	seed="$(resolve_sha "${name}" "${seed_branch}")" || {
		echo "[error] ${name} 既无 ${track_ref} 也无 ${seed_branch}" >&2
		exit 1
	}
	echo "[seed] ${OWNER}/${name} ${track_ref} ← ${seed_branch} (${seed})"
	create_or_update_branch "${name}" "${track_ref}" "${seed}" >/dev/null
}

sync_upstream_branch() {
	local name="$1" source="$2" track_ref="$3"
	echo "[gh-sync] ${OWNER}/${name} ${track_ref} ← ${source}"
	if ! gh repo sync "${OWNER}/${name}" --source "${source}" --branch "${track_ref}"; then
		echo "[warn] gh repo sync 失败，尝试 --force" >&2
		gh repo sync "${OWNER}/${name}" --source "${source}" --branch "${track_ref}" --force || true
	fi
}

drop_track_if_not_product() {
	local name="$1" track_ref="$2"
	case " ${PATHLESS_PRODUCT_BRANCHES} " in
		*" ${track_ref} "*) return 0 ;;
	esac
	if gh api "repos/${OWNER}/${name}/git/ref/heads/${track_ref}" >/dev/null 2>&1; then
		gh api -X DELETE "repos/${OWNER}/${name}/git/refs/heads/${track_ref}" >/dev/null
		echo "[drop] ${name} 临时跟踪分支 ${track_ref}"
	fi
}

sync_product_from_ref() {
	local name="$1" product="$2" track_ref="$3"
	local tip
	echo "[sync] ${OWNER}/${name} branch:${product} ← ${track_ref}"
	tip="$(resolve_sha "${name}" "${track_ref}")" || {
		echo "[error] ${name} 上找不到 ${track_ref}" >&2
		exit 1
	}
	echo "[tip] ${tip}"
	create_or_update_branch "${name}" "${product}" "${tip}"
}

warn_legacy_mirrors() {
	local r
	for r in pathless-u-boot-legacy-mirror pathless-rkbin-legacy-mirror pathless-linux-rockchip-legacy-mirror; do
		if gh repo view "${OWNER}/${r}" >/dev/null 2>&1; then
			echo "[cleanup] 删除残留（勿改正式仓名）：gh auth refresh -h github.com -s delete_repo && gh repo delete ${OWNER}/${r} --yes" >&2
		fi
	done
}

sync_uboot() {
	ensure_fork pathless-u-boot u-boot/u-boot
	local b ref
	for b in "${PRODUCT_BRANCHES[@]}"; do
		case "${b}" in
			vendor) ref="${PATHLESS_UBOOT_UPSTREAM_VENDOR}" ;;
			current) ref="${PATHLESS_UBOOT_UPSTREAM_CURRENT}" ;;
			edge) ref="${PATHLESS_UBOOT_UPSTREAM_EDGE}" ;;
			bleedingedge) ref="${PATHLESS_UBOOT_UPSTREAM_BLEEDINGEDGE}" ;;
			*) continue ;;
		esac
		sync_product_from_ref pathless-u-boot "${b}" "${ref}"
	done
}

sync_rkbin() {
	ensure_fork pathless-rkbin armbian/rkbin
	local b ref="${PATHLESS_RKBIN_UPSTREAM_VENDOR}"
	ensure_track_branch pathless-rkbin "${ref}" vendor
	sync_upstream_branch pathless-rkbin armbian/rkbin "${ref}"
	for b in "${PRODUCT_BRANCHES[@]}"; do
		sync_product_from_ref pathless-rkbin "${b}" "${ref}"
	done
	drop_track_if_not_product pathless-rkbin "${ref}"
}

sync_kernel_bsp() {
	ensure_fork pathless-linux-rockchip armbian/linux-rockchip
	if [[ -z "${ONLY_BRANCH}" || "${ONLY_BRANCH}" == "vendor" ]]; then
		local ref="${PATHLESS_KERNEL_BSP_UPSTREAM_VENDOR}"
		ensure_track_branch pathless-linux-rockchip "${ref}" vendor
		sync_upstream_branch pathless-linux-rockchip armbian/linux-rockchip "${ref}"
		sync_product_from_ref pathless-linux-rockchip vendor "${ref}"
		drop_track_if_not_product pathless-linux-rockchip "${ref}"
	fi
}

sync_kernel_mainline() {
	ensure_fork pathless-linux-stable gregkh/linux
	local b ref seed
	for b in "${PRODUCT_BRANCHES[@]}"; do
		[[ "${b}" == "vendor" ]] && continue
		case "${b}" in
			current) ref="${PATHLESS_KERNEL_MAINLINE_UPSTREAM_CURRENT}"; seed=current ;;
			edge) ref="${PATHLESS_KERNEL_MAINLINE_UPSTREAM_EDGE}"; seed=edge ;;
			bleedingedge) ref="${PATHLESS_KERNEL_MAINLINE_UPSTREAM_BLEEDINGEDGE}"; seed=bleedingedge ;;
			*) continue ;;
		esac
		ensure_track_branch pathless-linux-stable "${ref}" "${seed}"
		sync_upstream_branch pathless-linux-stable gregkh/linux "${ref}"
		sync_product_from_ref pathless-linux-stable "${b}" "${ref}"
		drop_track_if_not_product pathless-linux-stable "${ref}"
	done
	update_linux_stable_version_meta
}

# 从 Makefile 读出版本号，写入仓描述 + pathless-<branch>-vX.Y.Z tag
makefile_version_at() {
	local name="$1" branch="$2"
	gh api "repos/${OWNER}/${name}/contents/Makefile?ref=${branch}" --jq .content \
		| base64 -d \
		| awk '/^VERSION =/{v=$3} /^PATCHLEVEL =/{p=$3} /^SUBLEVEL =/{s=$3} /^EXTRAVERSION =/{e=$3} END{printf "%s.%s.%s%s", v,p,s,e}'
}

update_linux_stable_version_meta() {
	local c e b tip tag title notes
	c="$(makefile_version_at pathless-linux-stable current)"
	e="$(makefile_version_at pathless-linux-stable edge)"
	b="$(makefile_version_at pathless-linux-stable bleedingedge)"
	local desc="Pathless mainline kernel | current=${c} | edge=${e} | bleedingedge=${b}"
	echo "[meta] ${desc}"
	gh api -X PATCH "repos/${OWNER}/pathless-linux-stable" -f description="${desc}" --jq .description >/dev/null

	publish_stable_release() {
		local br="$1" ver="$2"
		[[ -z "${ver}" || "${ver}" == ".." ]] && return 0
		tag="pathless-${br}-v${ver}"
		tip="$(resolve_sha pathless-linux-stable "${br}")" || return 0
		if ! gh api "repos/${OWNER}/pathless-linux-stable/git/ref/tags/${tag}" >/dev/null 2>&1; then
			gh api -X POST "repos/${OWNER}/pathless-linux-stable/git/refs" \
				-f ref="refs/tags/${tag}" -f sha="${tip}" --jq .ref >/dev/null
			echo "[tag] ${tag} → ${tip}"
		else
			echo "[tag] ${tag} already exists"
		fi
		# GitHub Release：页面右侧显示版本号（比 Activity「recent pushes」有意义）
		if ! gh release view "${tag}" --repo "${OWNER}/pathless-linux-stable" >/dev/null 2>&1; then
			title="Pathless ${br}: Linux ${ver}"
			notes="产品分支 \`${br}\` 跟踪上游内核 **${ver}**（提交 \`${tip}\`）。"
			gh release create "${tag}" \
				--repo "${OWNER}/pathless-linux-stable" \
				--target "${br}" \
				--title "${title}" \
				--notes "${notes}"
			echo "[release] ${tag}"
		else
			echo "[release] ${tag} already exists"
		fi
	}

	publish_stable_release current "${c}"
	publish_stable_release edge "${e}"
	publish_stable_release bleedingedge "${b}"

	# 把「最新 Release」标到 current（GitHub 首页默认展示 Latest）
	if gh release view "pathless-current-v${c}" --repo "${OWNER}/pathless-linux-stable" >/dev/null 2>&1; then
		gh release edit "pathless-current-v${c}" --repo "${OWNER}/pathless-linux-stable" --latest >/dev/null 2>&1 || true
	fi
}

warn_legacy_mirrors

case "${ONLY_REPO}" in
	all)
		sync_uboot
		sync_rkbin
		sync_kernel_bsp
		sync_kernel_mainline
		;;
	uboot) sync_uboot ;;
	rkbin) sync_rkbin ;;
	kernel-bsp|kernel) sync_kernel_bsp ;;
	kernel-mainline) sync_kernel_mainline ;;
	*)
		echo "用法: $0 [all|uboot|rkbin|kernel-bsp|kernel-mainline] [vendor|current|edge|bleedingedge]" >&2
		exit 1
		;;
esac

echo
echo "同步完成。构建：BOOT/RKBIN/KERNEL 使用 branch:\${BRANCH}（见 pathless-sources.conf）。"
