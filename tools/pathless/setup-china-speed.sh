#!/usr/bin/env bash
# Pathless：国内编译加速一键准备
#
#   - Docker 构建环境镜像：南大 GHCR（首次拉一次，之后本地复用）
#   - 编译过程 apt/GitHub/ORAS：REGIONAL_MIRROR=china
#   - 内核/U-Boot/rkbin：Tron-Z 自有仓（pathless-sources.conf）
#
# 用法：
#   ./tools/pathless/setup-china-speed.sh           # 写 config + 预拉 Docker 镜像
#   ./tools/pathless/setup-china-speed.sh pull-only
#   ./tools/pathless/setup-china-speed.sh write-conf
#   ./tools/pathless/setup-china-speed.sh print-daemon-json
#
# 自有 Docker 镜像仓（可选）：
#   PATHLESS_DOCKER_OWN_REPO=ghcr.io/Tron-Z/docker-armbian-build \
#     ./tools/pathless/setup-china-speed.sh mirror-own

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${1:-all}"

WANTED_OS="${DOCKER_ARMBIAN_BASE_IMAGE:-debian:trixie}"
WANTED_NAME="${WANTED_OS%%:*}"
WANTED_TAG="${WANTED_OS##*:}"
IMAGE_SUFFIX="armbian-${WANTED_NAME}-${WANTED_TAG}-latest"

NJU_PREFIX="${PATHLESS_DOCKER_COORDINATE_PREFIX:-ghcr.nju.edu.cn/armbian/docker-armbian-build:armbian-}"
OFFICIAL_PREFIX="ghcr.io/armbian/docker-armbian-build:armbian-"
NJU_IMAGE="${NJU_PREFIX}${WANTED_NAME}-${WANTED_TAG}-latest"
OFFICIAL_IMAGE="${OFFICIAL_PREFIX}${WANTED_NAME}-${WANTED_TAG}-latest"

USER_CONF="${ROOT}/userpatches/config-pathless.conf"

write_user_conf() {
	mkdir -p "${ROOT}/userpatches"
	if [[ -f "${USER_CONF}" ]]; then
		grep -v -E '^(REGIONAL_MIRROR|DOWNLOAD_MIRROR|GITHUB_MIRROR|GHCR_MIRROR|GHPROXY_ADDRESS|DOCKER_ARMBIAN_BASE_COORDINATE_PREFIX|DOCKER_SKIP_UPDATE|ARMBIAN_DOCKER_AUTO_PULL|KERNEL_BTF|DOCKER_EXTRA_ARGS|CUSTOM_UBUNTU_MIRROR_PORTS|SKIP_ARMBIAN_REPO)=' \
			"${USER_CONF}" > "${USER_CONF}.tmp" || true
		mv "${USER_CONF}.tmp" "${USER_CONF}"
	else
		cat > "${USER_CONF}" <<'EOF'
BOARD=pathless-rk3566
BRANCH=vendor
RELEASE=noble
BUILD_MINIMAL=yes
BUILD_DESKTOP=no
KERNEL_CONFIGURE=no
EOF
	fi

	cat >> "${USER_CONF}" <<EOF

# --- pathless china speed (managed by tools/pathless/setup-china-speed.sh) ---
REGIONAL_MIRROR=china
KERNEL_BTF=no
GITHUB_MIRROR=ghproxy
GHPROXY_ADDRESS=ghfast.top
CUSTOM_UBUNTU_MIRROR_PORTS=mirrors.aliyun.com/ubuntu-ports/
SKIP_ARMBIAN_REPO=yes
DOCKER_EXTRA_ARGS=(--dns 1.1.1.1 --dns 8.8.8.8 --dns 223.5.5.5)
DOCKER_ARMBIAN_BASE_COORDINATE_PREFIX=${NJU_PREFIX}
DOCKER_SKIP_UPDATE=yes
ARMBIAN_DOCKER_AUTO_PULL=no
EOF
	echo "[ok] wrote mirror defaults → ${USER_CONF}"
}

pull_docker_env() {
	echo "[pull] ${NJU_IMAGE}"
	if docker pull "${NJU_IMAGE}"; then
		docker tag "${NJU_IMAGE}" "${OFFICIAL_IMAGE}" || true
		echo "[ok] local: ${NJU_IMAGE}"
		echo "[ok] also tagged: ${OFFICIAL_IMAGE}"
		return 0
	fi
	echo "[warn] NJU pull failed, trying official ${OFFICIAL_IMAGE}" >&2
	docker pull "${OFFICIAL_IMAGE}"
}

print_daemon_json() {
	cat <<'EOF'
# 可选：加速 Docker Hub（debian:trixie 等 FROM scratch 回退时用）
# 写入 /etc/docker/daemon.json 后：sudo systemctl restart docker

{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://mirror.ccs.tencentyun.com"
  ]
}
EOF
}

mirror_own() {
	local own="${PATHLESS_DOCKER_OWN_REPO:-}"
	if [[ -z "${own}" ]]; then
		echo "Set PATHLESS_DOCKER_OWN_REPO=ghcr.io/Tron-Z/docker-armbian-build" >&2
		exit 1
	fi
	local own_image="${own}:${IMAGE_SUFFIX}"
	pull_docker_env
	docker tag "${NJU_IMAGE}" "${own_image}"
	echo "[push] ${own_image}"
	docker push "${own_image}"
	echo "[hint] DOCKER_ARMBIAN_BASE_COORDINATE_PREFIX=${own}:armbian-"
}

case "${CMD}" in
	all)
		write_user_conf
		pull_docker_env
		echo
		echo "下一步：cd ${ROOT} && ./compile.sh pathless"
		;;
	pull-only) pull_docker_env ;;
	write-conf) write_user_conf ;;
	print-daemon-json) print_daemon_json ;;
	mirror-own) mirror_own ;;
	*)
		echo "Usage: $0 [all|pull-only|write-conf|print-daemon-json|mirror-own]" >&2
		exit 1
		;;
esac
