# 如何使用公开软件源

[中文（当前）](USAGE.zh-CN.md) | [English](USAGE.md)

## 设备需要先具备什么条件

目标设备的基础固件必须已经提供以下全部内容：

1. 已登记为“已安装”的匹配 `tdvp-platform-abi` 标记包；
2. 有效的 opkg 状态数据库和索引目录；
3. 用于 HTTPS 的受信任 CA 证书包，以及正确的系统时间；
4. 经过实际测试的 opkg 索引签名验证后端；
5. 用来验证本仓库发布密钥的内置公开密钥。

已签名发布的 TDVP K230 r1 长期维护基础镜像会提供第 1、2、4、5 项。它的 `tdvp-opkg` 包装器会在每次包管理操作前初始化专用密钥环，因此软件源不在开机路径上。使用者仍需保证网络可用、系统时间正确，以便 HTTPS 正确校验证书。旧镜像不能替代该基础镜像；制作基础镜像时请按 [设备引导说明](DEVICE_BOOTSTRAP.zh-CN.md) 完成这些准备。

## 配置 TDVP K230 r1 软件源

当前基础镜像会在 `/etc/opkg/tdvp-feed.conf` 中安装下面这个**与 ABI 绑定的 r4 软件源**。这里的 r4 是不可变的软件源目录版本；设备的基础 ABI 仍是 r1：

```conf
src/gz tdvp_apps_r4 https://vicliu624.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r4/riscv64
```

不要手工修改该文件，也不要添加通用 OpenWrt、Debian 或任意 `riscv64` 软件源；即使 CPU 架构同为 RISC-V 64 位，它们的系统 ABI 也可能不同。

## 日常安装流程

```sh
sudo tdvp-opkg update
sudo tdvp-opkg list 'tdvp-*'
sudo tdvp-opkg info tdvp-gba
sudo tdvp-opkg install --download-only tdvp-gba
sudo tdvp-opkg install tdvp-gba
tdvp-gba
```

安装社区应用时，把 `tdvp-gba` 换成它的实际发布名称。`tdvp-gba` 会自动拉取 `sdl2`、`sdl2-ttf` 和 `libmgba`；不要单独强制安装或绕开依赖检查。若设备已安装 r1 的旧 `tdvp-cardputer-zero-gba`，先卸载旧包再安装 `tdvp-gba`，避免两个启动器重叠。不要使用 `--force-depends`、`--force-checksum` 或 `--no-check-certificate`；这些选项会跳过本仓库用来保护设备的检查。

## 哪些失败是正常且正确的

下面的情况都必须阻止安装：

- 包索引的签名无法验证；
- 公开密钥未知，或密钥轮换后固件没有同步更新；
- 包的架构不被设备接受；
- `tdvp-platform-abi` 的版本不匹配；
- 包的校验和与已签名索引不一致。

遇到这些错误时，请不要用“强制安装”绕过它。应检查设备基础固件、软件源地址、公开密钥和包所声明的平台。

## 更新应用

只能从本软件源更新由 feed 管理的用户态包：共享库、工具、桌面程序和设备应用。不要对基础固件执行不加选择的 `opkg upgrade`：内核、驱动、libc、动态加载器、桌面基础栈、网络栈和 KPU 运行时由固件管理，不是这个软件发行源的升级对象。
