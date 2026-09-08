# Pathless mainline DT (rockchip64-7.3)

- `rk3566-pathless-3b.dts` → `BOOT_FDT_FILE=rockchip/rk3566-pathless-3b.dtb`
- 由 `0000.patching_config.yaml` 的 `dts-directories` + `auto-patch-dt-makefile` 拷入并编进内核
- 基于 upstream `rk3566-orangepi-3b.dtsi`（勿拷 BSP vendor DTS）
