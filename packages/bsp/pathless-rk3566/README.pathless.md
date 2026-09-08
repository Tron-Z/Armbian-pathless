# Pathless RK3566 板级 BSP（全部自有路径）

| 文件 | 来源说明 | 运行时路径 |
|:--|:--|:--|
| `pathless-rk3566-sprd-bluetooth` | 功能对齐原 orangepi3b 脚本，服务名/二进制名已 Pathless 化 | `/usr/bin/pathless-rk3566-sprd-bluetooth` |
| `pathless-rk3566-sprd-bluetooth.service` | 自有 unit | `/lib/systemd/system/...` |
| `hciattach_pathless` | 二进制内容拷自原 `packages/bsp/rk3399/hciattach_opi`，**文件名已改为 pathless** | `/usr/bin/hciattach_pathless` |

板级 conf **只**引用本目录。
