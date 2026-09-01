# TDVP K230 r1 的设备端准备约定

[中文（当前）](DEVICE_BOOTSTRAP.zh-CN.md) | [English](DEVICE_BOOTSTRAP.md)

本文定义已签名 TDVP K230 r1 基础镜像的约定，不是在已经投入使用的设备上临时执行几条命令。临时修改生产设备会让 opkg 的状态和实际文件失去对应关系，后续更难维护。

## 1. 修正 opkg 状态配置

目标设备的 opkg 0.7.0 不接受当前 OpenWrt 风格的写法：

```text
lists_dir ext /var/lib/opkg/lists
```

请改用与目标版本兼容的配置：

```conf
dest root /

option lists_dir /var/lib/opkg/lists
option info_dir /var/lib/opkg/info
option status_file /var/lib/opkg/status
option tmp_dir /tmp

arch all 1
arch noarch 1
arch riscv64 10

option check_signature 1
option signature_type gpg-asc
option gpg_dir /etc/opkg/gpg
option gpg_trust_level TrustAny
```

在构建镜像时创建 `/var/lib/opkg/{lists,info}` 和状态文件。唯一的软件源应单独安装为 `/etc/opkg/tdvp-feed.conf`：

```conf
src/gz tdvp_apps_r7 https://vicliu624.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r2/r7/riscv64
```

这样 opkg 才能知道哪些文件由它管理，不会把根文件系统当成一堆无法追踪的文件；签名软件源约定也不会混入核心 opkg 配置。

## 2. 在镜像中登记 ABI 标记包

在设备接受任何公开应用包之前，基础固件必须先安装一个没有载荷的标记包：

```text
Package: tdvp-platform-abi
Version: 2025.02.1-k230.6.6.36-glibc2.33-rv64-lp64d-r2
Architecture: riscv64
Status: install ok installed
Description: ABI identity for TDVP K230 firmware r2
```

应在 Buildroot 构建镜像时生成该状态记录。不要直接手改运行中设备的状态数据库来代替发布清单；手改记录无法证明设备上的 libc、工具链和内核真的是匹配版本。

## 3. 加入真正可用的签名验证

R1 基础镜像使用现有 opkg 的 GPG ASCII 装甲验证后端（`signature_type gpg-asc`）。镜像只携带公开密钥、`/usr/local/libexec/tdvp-opkg-bootstrap` 和 `/usr/local/sbin/tdvp-opkg`；后者会在每次 opkg 操作前把公钥导入 `/etc/opkg/gpg` 并校验指纹。它有意不是开机服务，网络软件源不能阻塞 `greetd` 或桌面。私钥绝不能进入镜像。

验收测试必须证明以下四种情况：

1. 正确的索引签名可以通过；
2. 被篡改的 `Packages.gz` 会失败；
3. 未知签名密钥会失败；
4. 不受信任证书的 HTTPS 连接会失败。

日常更新说明中绝不能使用 `--no-check-certificate`、`--force-checksum` 或 `--force-depends`。
