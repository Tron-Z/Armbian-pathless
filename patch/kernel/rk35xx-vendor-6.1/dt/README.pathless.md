# Pathless 内核 DTS（BRANCH=vendor / rk35xx-vendor-6.1）

| 文件 | 来源 | 作用 |
|:--|:--|:--|
| `rk3566-pathless-3b.dts` | 拷自 `armbian/linux-rockchip@rk-6.1-rkr7.2` 的 `rk3566-orangepi-3b-v1.1.dts`，改 `model`/`compatible` | 产品自有 DTB：`rk3566-pathless-3b.dtb` |

Armbian 会通过本目录上级的 `0000.patching_config.yaml`：
1. 把 `dt/*.dts` 复制到内核 `arch/arm64/boot/dts/rockchip/`
2. **自动**改 Makefile 增加对应 `dtb-y` 行

板级 conf 必须设置：`BOOT_FDT_FILE="rockchip/rk3566-pathless-3b.dtb"`
