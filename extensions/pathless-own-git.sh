# Pathless：内核 / U-Boot 只 git clone KERNELSOURCE / BOOTSOURCE（Tron-Z 自有仓），
# 经 GITHUB_SOURCE（gh-proxy.com），不拉 Armbian ORAS 内核包、不拉主线 u-boot 裸仓。
#
# SPDX-License-Identifier: GPL-2.0

function pathless_github_proxy_url() {
	declare _url="${1}"
	if [[ "${_url}" == https://github.com/* ]]; then
		echo "${GITHUB_SOURCE}/${_url#https://github.com/}"
	else
		echo "${_url}"
	fi
}

# fetch_from_repo 会把 cache/sources/.../<name> 当成 worktree，并要求
# <bare>/.git/worktrees/<name>/gitdir 存在。换仓/重克隆后旧 worktree 的 .git
# 还在，就会跳过 worktree add，随后 realpath 失败。
function pathless_drop_stale_git_worktree() {
	declare bare_dir="${1}" worktree_dir="${2:-}"
	[[ -z "${worktree_dir}" ]] && return 0
	declare wt_name
	wt_name="$(basename "${worktree_dir}")"
	if [[ -f "${bare_dir}/.git/worktrees/${wt_name}/gitdir" ]]; then
		return 0
	fi
	if [[ -e "${worktree_dir}" ]]; then
		display_alert "Removing stale Git worktree" "${worktree_dir}" "info"
		run_host_command_logged rm -rf "${worktree_dir}"
	fi
}

# clone $2 (git url) at ref $3 (branch:foo|tag:bar) into directory $1
# $5：Armbian worktree 路径；与本仓无 worktree 元数据时删掉，让 fetch_from_repo 重建
function pathless_clone_product_git() {
	declare dest_dir="${1}" src_url="${2}" git_ref="${3}" kind="${4:-repo}" stale_worktree="${5:-}"
	declare own_url
	own_url="$(pathless_github_proxy_url "${src_url}")"

	declare -g ref_type ref_name
	git_parse_ref "${git_ref}"

	declare done_marker="${dest_dir}/.git/armbian-bare-tree-done"

	if [[ -d "${dest_dir}/.git" && -f "${done_marker}" ]]; then
		display_alert "Pathless ${kind} tree already exists" "${dest_dir}" "cachehit"
		git_ensure_safe_directory "${dest_dir}"
		pathless_drop_stale_git_worktree "${dest_dir}" "${stale_worktree}"
		return 0
	fi

	if [[ -e "${dest_dir}" ]]; then
		display_alert "Removing incomplete Pathless ${kind} tree" "${dest_dir}" "info"
		run_host_command_logged rm -rf "${dest_dir}"
	fi

	# --no-checkout：与官方 uboot_prepare_bare_repo 一样，只当 worktree 的源仓
	declare -a clone_opts=(--progress --single-branch --branch "${ref_name}" --no-checkout)
	if [[ "${KERNEL_GIT:-}" == "shallow" ]]; then
		clone_opts+=(--depth 1)
	fi

	display_alert "Cloning Pathless ${kind}" "${own_url} (${ref_type}:${ref_name})" "info"
	run_host_command_logged mkdir -p "$(dirname "${dest_dir}")"
	improved_git clone "${clone_opts[@]}" "${own_url}" "${dest_dir}"

	# worktree add … master（Armbian 内核/U-Boot 共用）
	if ! git -C "${dest_dir}" show-ref --verify --quiet refs/heads/master; then
		run_host_command_logged git -C "${dest_dir}" branch master HEAD
	fi

	if [[ ! -d "${dest_dir}/.git" ]]; then
		exit_with_error "Pathless ${kind} clone missing .git" "${dest_dir}"
	fi
	touch "${done_marker}"
	git_ensure_safe_directory "${dest_dir}"
	pathless_drop_stale_git_worktree "${dest_dir}" "${stale_worktree}"
}

function kernel_prepare_bare_repo_decide_shallow_or_full() {
	declare repo_slug
	repo_slug="$(basename "${KERNELSOURCE:-kernel}" .git)"
	[[ -z "${repo_slug}" || "${repo_slug}" == "kernel" ]] && repo_slug="pathless-kernel"
	kernel_git_bare_tree="${SRC}/cache/git-bare/${repo_slug}"
	git_bundles_dir="${SRC}/cache/git-bundles/kernel"
	git_kernel_ball_fn="pathless-own-repo-unused"
	git_kernel_oras_ref="pathless-own-repo-unused"
	display_alert "Pathless kernel git" "skip Armbian ORAS gitball; clone ${KERNELSOURCE}" "info"
}

function kernel_prepare_bare_repo_from_oras_gitball() {
	if [[ -z "${KERNELSOURCE}" || "${KERNELSOURCE}" == "none" ]]; then
		exit_with_error "Pathless kernel git" "KERNELSOURCE is empty; cannot clone own repo"
	fi
	if [[ -z "${kernel_git_bare_tree}" ]]; then
		exit_with_error "kernel_git_bare_tree is not set"
	fi
	pathless_clone_product_git "${kernel_git_bare_tree}" "${KERNELSOURCE}" "${KERNELBRANCH}" "kernel" \
		"${SRC}/cache/sources/${LINUXSOURCEDIR}"
	return 0
}

function uboot_prepare_bare_repo() {
	if [[ -z "${BOOTSOURCE}" || "${BOOTSOURCE}" == "none" ]]; then
		exit_with_error "Pathless u-boot git" "BOOTSOURCE is empty; cannot clone own repo"
	fi
	declare repo_slug
	repo_slug="$(basename "${BOOTSOURCE}" .git)"
	uboot_git_bare_tree="${SRC}/cache/git-bare/${repo_slug}"
	pathless_clone_product_git "${uboot_git_bare_tree}" "${BOOTSOURCE}" "${BOOTBRANCH}" "u-boot" \
		"${SRC}/cache/sources/${BOOTSOURCEDIR}"
	return 0
}
