# 如何使用公开软件源

[中文（当前）](USAGE.zh-CN.md) | [English](USAGE.md)

## 设备需要先具备什么条件

目标设备的基础固件必须已经提供以下全部内容：

1. 已登记为“已安装”的匹配 `tdvp-platform-abi` 标记包；
2. 有效的 opkg 状态数据库和索引目录；
3. 用于 HTTPS 的受信任 CA 证书包，以及正确的系统时间；
4. 经过实际测试的 opkg 索引签名验证后端；
5. 用来验证本仓库发布密钥的内置公开密钥。

已检查的 TDVP K230 系统目前不满足第 1、2、4 项。因此它不能直接安全地使用公开软件源；下一版固件构建时应按照 [设备引导说明](DEVICE_BOOTSTRAP.zh-CN.md)完成这些准备。

## 配置 TDVP K230 r1 软件源

基础固件准备并刷入后，在设备唯一的 `/etc/opkg/opkg.conf` 中加入下面这个**与 ABI 绑定的单一软件源**：

```conf
src/gz tdvp_apps_r1 https://YOUR_GITHUB_ID.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/riscv64
```

把 `YOUR_GITHUB_ID` 换成发布本仓库的 GitHub 用户名或组织名。不要再添加通用 OpenWrt、Debian 或任意 `riscv64` 软件源；即使 CPU 架构同为 RISC-V 64 位，它们的系统 ABI 也可能不同。

## 日常安装流程

```sh
opkg update
opkg list 'tdvp-*'
opkg info tdvp-hello
opkg install --download-only tdvp-hello
opkg install tdvp-hello
tdvp-hello
```

安装社区应用时，把 `tdvp-hello` 换成它的实际发布名称。不要使用 `--force-depends`、`--force-checksum` 或 `--no-check-certificate`；这些选项会跳过本仓库用来保护设备的检查。

## 哪些失败是正常且正确的

下面的情况都必须阻止安装：

- 包索引的签名无法验证；
- 公开密钥未知，或密钥轮换后固件没有同步更新；
- 包的架构不被设备接受；
- `tdvp-platform-abi` 的版本不匹配；
- 包的校验和与已签名索引不一致。

遇到这些错误时，请不要用“强制安装”绕过它。应检查设备基础固件、软件源地址、公开密钥和包所声明的平台。

## 更新应用

只能从本软件源更新应用包。不要对基础固件执行不加选择的 `opkg upgrade`：内核、驱动、libc、网络栈和 KPU 运行时由固件管理，不是这个应用仓库的升级对象。
