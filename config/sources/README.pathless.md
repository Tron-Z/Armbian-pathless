# Pathless 三仓与编译说明（跟踪路径，勿依赖被 ignore 的 userpatches）

## 日常用法

只 clone **一个**框架仓：

```bash
git clone --single-branch --branch main https://github.com/Tron-Z/Armbian-pathless.git
cd Armbian-pathless
./tools/pathless/setup-china-speed.sh write-conf   # 可选：国内加速
./compile.sh pathless
```

**不要**再 clone `pathless-mirrors*`。资源仓（内核 / U-Boot / rkbin）由编译过程拉到 `cache/sources/`。

内核 / U-Boot **git clone 自有仓**（经 `ghfast.top`），**不**下载 Armbian GHCR 的 `linux-complete.git.tar`，也 **不** 先克隆主线 `u-boot/u-boot`。rkbin 走 `pathless-rkbin`。不拉 `armbian/firmware`（`INSTALL_ARMBIAN_FIRMWARE=no`）。

## 自有资源仓（方案 B）

| 用途 | 仓库 | 产品分支 |
|:--|:--|:--|
| BSP 内核 | `Tron-Z/pathless-linux-rockchip` | `vendor` |
| 主线内核 | `Tron-Z/pathless-linux-stable` | `current` / `edge` / `bleedingedge` |
| U-Boot | `Tron-Z/pathless-u-boot` | 四档同名 |
| rkbin | `Tron-Z/pathless-rkbin` | 四档同名 |

URL 表：`config/sources/pathless-sources.conf`  
国内 apt/GitHub/ORAS 默认：`config/sources/pathless-china-mirrors.conf`  
上游→自有 Fork 同步：`tools/pathless/sync-three-repos.sh`（`gh` API，不建旁路 mirrors 目录）

## 板级 DTB

| BRANCH | DTS |
|:--|:--|
| vendor | `patch/kernel/rk35xx-vendor-6.1/dt/rk3566-pathless-3b.dts` |
| current | `patch/kernel/archive/rockchip64-6.18/dt/rk3566-pathless-3b.dts` |
| edge | `patch/kernel/archive/rockchip64-7.2/dt/rk3566-pathless-3b.dts` |
| bleedingedge | `patch/kernel/archive/rockchip64-7.3/dt/rk3566-pathless-3b.dts` |

`BOOT_FDT_FILE=rockchip/rk3566-pathless-3b.dtb`（四档共用文件名）。

## 调试回退官方源

`PATHLESS_USE_OFFICIAL_SOURCES=yes` 只换 git URL；**仍使用本仓 pathless DTB 补丁**（官方树无该文件名）。
