<div align="center">

# Phicomm N1 · ImmortalWrt

**内置 honk / doona 的斐讯 N1 旁路由固件** · eBPF / BTF 就绪 · 纯有线

[![Build](https://github.com/mackolzjj/Phicomm-N1_ImmortalWrt/actions/workflows/armsr_armv8.yml/badge.svg)](https://github.com/mackolzjj/Phicomm-N1_ImmortalWrt/actions/workflows/armsr_armv8.yml)
[![Release](https://img.shields.io/github/v/release/mackolzjj/Phicomm-N1_ImmortalWrt?label=Release)](https://github.com/mackolzjj/Phicomm-N1_ImmortalWrt/releases)
![Source](https://img.shields.io/badge/ImmortalWrt-v25.12.2-orange)
![Kernel](https://img.shields.io/badge/kernel-6.18.y-blue)
![Board](https://img.shields.io/badge/board-s905d%20%2F%20aarch64-green)
![Package](https://img.shields.io/badge/pkg-apk-lightgrey)

</div>

> 旁路由定位：拨号与 WiFi 交给主路由，本固件**不含 PPPoE / WiFi**，只把 eBPF 透明代理做扎实。

## ✨ 特性

- **开箱即用的代理**：`honk`（构建时自动取 `daeuniverse/honk` 最新 tag）+ 内嵌 **doona** 面板、`luci-app-honk`、`luci-lib-daeuniverse`、`v2ray-geoip` / `v2ray-geosite`
- **eBPF 全链路就绪**：`DEBUG_INFO_BTF` / `BPF_EVENTS` / `XDP_SOCKETS` = y，`vmlinux-btf-builtin`、`BPF_TOOLCHAIN_HOST=y`
- **容器与界面**：`podman` + LuCI、`luci-app-amlogic`、Argon 主题 + 配置、`autocore`
- **日常工具**：`bsdtar` / `btrfs-progs` / `f2fs-tools` / `xfs-*` / `pigz` / `gawk` / `perl-*` / `fstrim` / `zoneinfo-asia`
- **预置调优**：每日 04:00 `fstrim -a`，CPU `performance` 锁 1.512 GHz，晶晨宝盒在线更新已指向本库

## 🚀 快速开始

从 [Releases](https://github.com/mackolzjj/Phicomm-N1_ImmortalWrt/releases) 取 `openwrt_amlogic_s905d_k6.18.*.img.gz` 并解压，写入 U 盘启动：

```bash
openwrt-install-amlogic      # 需要固化到 eMMC 时执行
# 浏览器打开 http://192.168.2.2    root / password
```

开机后建议核对：

```bash
grep PRETTY_NAME /etc/os-release; uname -r
ls -l /sys/kernel/btf/vmlinux
apk list --installed | grep -E 'honk|daeuniverse|podman'
```

预期 `ImmortalWrt 25.12.2`、`6.18.x-ophub`、BTF 文件存在、honk 相关包已装。面板在 LuCI「服务」下；honk 原生 API 启动约十几秒，过早访问会误判为未监听。

> ⚠️ 建议**全新刷写、不保留配置**。跨源码线（官方 OpenWrt ↔ ImmortalWrt）保留配置易残留不兼容项。

## ⚙️ 构建与发布

| | |
| --- | --- |
| 源码 | `immortalwrt/immortalwrt` @ `v25.12.2` → `armsr/armv8` |
| 内核 | ophub `kernel_stable` `6.18.y` + `auto_kernel: true` |
| 打包 | `ophub/amlogic-s9xxx-openwrt` · `s905d` · `256/1024` · builder `Mackol` |
| 触发 | push `main` / `master`、手动、每月 1 / 16 日 08:00（北京时间） |
| Release | `ImmortalWrt_<分支>_<YYYYMMDD>`，同日 `--clobber` 覆盖，仅留最近 10 个 |

<details>
<summary><b>展开：完整构建参数 · 在线更新 · 排错 · 自定义编译</b></summary>

### 构建参数

| 参数 | 值 |
| --- | --- |
| 源码处理 | checkout `v25.12.2` 后把 `25.12-SNAPSHOT` 改为 `25.12.2` |
| 构建机 | `ubuntu-24.04`，`TZ=Asia/Shanghai`；77 个 apt 编译依赖已固化在 workflow 内，不再外部拉取 |
| Rust / eBPF | rustup `1.99.1` + `nightly-2026-10-20` + `bpfel-unknown-none` + `bpf-linker` v0.13.0（honk 编译必需） |
| `diy.sh` | clone `daeuniverse/openwrt-packages`、`ophub/luci-app-amlogic`、`Zerogiven-OpenWRT-Packages/luci-app-podman`；移除 `luci-app-dae` / `luci-app-daed` / `luci-app-passwall` / `dae` 与 `luci-app-attendedsysupgrade`；安装 Rust |
| 默认网络 | `eth0` 静态 `192.168.2.2/24`，网关 `192.168.2.1`，仅 `lan` 无 wan |
| 不集成 | `ppp` / `kmod-ppp` / `kmod-mppe`（无 PPPoE）、`wpad` / `hostapd`（无 WiFi）、`luci-app-samba4` |
| 产物名 | `openwrt_amlogic_s905d_k6.18.*_<日期>.img.gz`（ophub 生成，与 Release 名不同） |

### 晶晨宝盒在线更新

`/etc/config/amlogic` 已预置四项指向本库：`firmware_repo = mackolzjj/Phicomm-N1_ImmortalWrt`、`firmware_tag = ImmortalWrt`、`firmware_suffix = .img.gz`、`kernel_branch = 6.18`。设备端可用 `uci show amlogic.config | grep -E 'firmware|kernel_branch'` 核对。

### 常见问题

| 现象 | 排查 |
| --- | --- |
| honk 启动失败 | 确认 `/sys/kernel/btf/vmlinux` 存在、未自行更换内核；eBPF / BTF 不匹配会直接退出 |
| 无法拨号 / 无 WiFi | 设计如此，`.config` 明确禁用 ppp 与无线组件 |
| LuCI 无 honk 菜单 | 确认刷的是本线；另一条 `Phicomm-N1_OpenWrt` 不内置 honk，仅提供 BTF 支持 |

### 自定义编译

`armsr/armv8/N1/.config`（内置包 / 内核选项）· `armsr/armv8/diy/diy.sh`（软件源、honk 拉取、Rust）· `armsr/armv8/N1/files/`（预置 `/etc/config` 与 crontabs）· `armsr/armv8/N1/mk_s905d_n1.sh`（本地打包）· `.github/workflows/armsr_armv8.yml`（触发、内核、Release 规则）。

改动后推送到 `main` / `master` 会触发构建；仅改文档且不想编译时，在 commit body 写 `[skip ci]`。

</details>

## 🙏 致谢

[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) · [ophub/amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt) · [ophub/kernel](https://github.com/ophub/kernel) · [daeuniverse/honk](https://github.com/daeuniverse/honk) · [daeuniverse/openwrt-packages](https://github.com/daeuniverse/openwrt-packages) · [luci-app-podman](https://github.com/Zerogiven-OpenWRT-Packages/luci-app-podman)
