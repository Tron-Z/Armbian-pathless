# Pathless RK3566 板级 BSP（全部自有路径）

| 文件 | 来源说明 | 运行时路径 |
|:--|:--|:--|
| `pathless-rk3566-sprd-bluetooth` | 功能对齐原 orangepi3b 脚本，服务名/二进制名已 Pathless 化 | `/usr/bin/pathless-rk3566-sprd-bluetooth` |
| `pathless-rk3566-sprd-bluetooth.service` | 自有 unit | `/lib/systemd/system/...` |
| `hciattach_pathless` | 二进制内容拷自原 `packages/bsp/rk3399/hciattach_opi`，**文件名已改为 pathless** | `/usr/bin/hciattach_pathless` |
| `pathless-firstlogin` | 覆盖 Armbian 交互向导（Orange Pi 做法） | `/usr/lib/armbian/armbian-firstlogin` |
| `pathless-firstrun-config` | 可选 `/boot/pathless_first_run.txt` 配网 | `/usr/lib/pathless/pathless-firstrun-config` |
| `pathless_first_run.txt.template` | 改名为 `pathless_first_run.txt` 后首次开机生效 | `/boot/pathless_first_run.txt.template` |

出厂账号：`pathless` / `pathless`，root 同密码。无控制台自动登录、无首次设密向导。

板级 conf **只**引用本目录。
