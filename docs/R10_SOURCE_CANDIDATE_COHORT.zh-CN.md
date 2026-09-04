# r10 上游源码候选批次

本清单是 r10 的**候选构建与设备验收清单**，不是已签名的软件源目录，也不授权将任一
包直接发布。它补充 [上游源码准入约定](UPSTREAM_SOURCES.zh-CN.md) 和
[来源锁迁移台账](SOURCE_LOCK_MIGRATION.zh-CN.md)，把需要同一 ABI 匹配 K230 SDK 处理的
provider、应用和 profile 放在一个可复核的批次中。

一次实际本地构建的成功 IPK、base-overlay 拒绝以及尚缺少的设备门，记录在
[r10 本地候选构建证据台账](R10_LOCAL_CANDIDATE_EVIDENCE.zh-CN.md)。该台账不会改变本
清单的候选性质，也不会把本机 `dist-*` 目录当成 release。

## 必须先满足的环境门槛

构建机必须有完整、匹配 TDVP K230 基线的 Buildroot output：

```text
<output>/.config
<output>/Makefile
<output>/target/
<output>/host/bin/riscv64-unknown-linux-gnu-readelf
```

它必须解析为 Buildroot 2025.02.1，且每个 package 的 `build.sh` 会在继续前检查自己需要
的 Kconfig feature。不得以主机 ELF、Debian 二进制或另一块板子的 sysroot 代替这个 output。

每个候选都先运行：

```sh
bash ./scripts/verify-source-lock.sh --repo-root . --all
```

接着在受控网络阶段用固定 cohort 顺序预热每个候选的 source cache：

```sh
bash ./scripts/fetch-r10-candidate-cohort.sh \
  --cache .tdvp-source-cache
```

若旧构建主机的系统 CA 缺少某一官方 HTTPS 站点的根证书，先更新主机 CA 库；只有无法立即
更新时，才可由受控主机配置传入完整的审查过的 PEM bundle：

```sh
bash ./scripts/fetch-r10-candidate-cohort.sh \
  --cache .tdvp-source-cache \
  --ca-bundle /etc/ssl/tdvp-controlled-roots.pem
```

该选项不会允许 HTTP 或跳过 TLS 验证，下载后仍必须命中 `source.lock` 的 SHA-256。不能因为
旧 CA 链失败而改用内容不同的 GitHub tag snapshot；这会改变归档内容及 Buildroot 的 release
配方假设，必须作为一个新的、完整审查过的来源迁移处理。

上述 cohort helper 只验证并准备 cache；它不会调用 `build.sh`、生成 IPK、签名、安装或发布。
可在第二台无网络构建机上把同一命令附加 `--offline`，以证明所有已锁定归档均已准备就绪。

收到完成态 SDK 后，再运行只读 cohort 门：

```sh
bash ./scripts/verify-r10-candidate-cohort.sh --sdk-root <output>/host
```

它会验证 SDK 结构、Buildroot 版本、r10 所需 Kconfig feature 与每个候选归档的 cache
哈希；它不会构建、签名、安装或发布任何 IPK。

再以已校验的 `.tdvp-source-cache` 离线构建。任何归档缺失、哈希不同、Buildroot recipe
版本不同、RPATH/RUNPATH、base-overlay 路径冲突或未拥有 SONAME 都是停止条件。

## 候选组和构建顺序

| 顺序 | provider / 应用 | 版本 | 闭包与验收重点 |
| --- | --- | --- | --- |
| 1 | `libncursesw`、`libreadline` | 6.4-20230603、8.2 | 已拥有的终端 ABI；先确认其候选与平台 ABI 一致 |
| 2 | `libpopt`、`libz` | 1.19、1.3.1 | rsync 的公共 provider；不得私藏在 leaf 中 |
| 3 | `libevent` | 2.1.12 | 唯一拥有四个 `libevent*.so.7`；OpenSSL event 支持关闭 |
| 4 | `libcurl-4`、`curl` | 8.12.1 | 同一事务 stage `curl`，验证 `libcurl.so.4`、RISC-V ELF 和 RPATH/RUNPATH |
| 5 | `wget`、`rsync` | 1.25.0、3.4.1 | Wget 只允许 CA/OpenSSL/zlib；rsync 只允许 popt/zlib/OpenSSH |
| 6 | `iperf3`、`netcat`、`lsof` | 3.18、0.7.1、4.99.4 | 受控 LAN、无公开 listener；lsof 还需记录权限可见性 |
| 7 | `htop`、`nano`、`dialog`、`ncdu`、`pv` | 3.3.0、8.2、1.3-20220117、1.21、1.9.0 | 真实终端、locale/宽字符和小屏交互验收 |
| 8 | `tmux` | 3.3a | 仅复用 libevent/ncurses；验证 detached session、capture、kill-session |
| 9 | `tdvp-source-tools`、`tdvp-diagnostics` | 1.6、1.1 | 仅元数据 profile；安装/卸载不得复制或误删工具/共享库 |

应用只可以在其所有 runtime provider 已被同一候选批次成功打包、并通过 IPK 依赖闭包检查后
构建。共享库 IPK 必须先于其消费者安装到测试机。

特别地，当前 staging K230 output 已选择 `BR2_PACKAGE_POPT=y` 并拥有
`/usr/lib/libpopt.so.0`。这使 `libpopt` 的普通 feed provider 被 base-overlay gate 拒绝，
从而也暂停 `rsync`；详情及可接受的后续路径见上述本地证据台账。不得把这份基础库当作
rsync 的隐式 runtime，也不得以同内容覆盖绕过 gate。

## 设备生命周期记录

每一个 unsigned candidate 都要独立记录：

1. 安装前 `opkg status`、路径和 SONAME 状态；
2. 安装后版本检查及上表指定的核心功能；
3. 对网络工具使用受控 endpoint，对 `lsof` 记录运行用户和可见性；
4. 卸载后确认固件 BusyBox、loader、基础库和其它候选仍正常；
5. 回滚到前一不可变 feed revision 后重复核心 smoke test。

只有所有 provider/应用/profile 都有这些记录，且候选 IPK 未更改来源锁、SDK identity 或
测试机平台，才可进入签名和不可变 release 流程。
