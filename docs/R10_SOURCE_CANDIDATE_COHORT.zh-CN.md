# r10 上游源码候选批次

本清单是 r10 的**候选构建与设备验收清单**，不是已签名的软件源目录，也不授权将任一
包直接发布。它补充 [上游源码准入约定](UPSTREAM_SOURCES.zh-CN.md) 和
[来源锁迁移台账](SOURCE_LOCK_MIGRATION.zh-CN.md)，把需要同一 ABI 匹配 K230 SDK 处理的
provider、应用和 profile 放在一个可复核的批次中。

本清单的 K230 构建、封装、ELF/依赖闭包检查以及候选合并证据，**只能**来自 GitHub
Actions 的成功 run 和其受校验的 artifact manifest。本地 worktree 只可用于来源锁、策略、
shell 语法和精确 patch dry-run 等不产生 K230 IPK 的静态检查；本地 `dist-*`、下载缓存或
其他临时输出既不是候选输入，也不是 release 证据。失败的 Actions run 只保留为拒绝原因，
不能作为 merge source。

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

**CI 来源镜像记录（2026-09-04）。** Actions run `33902486905` 和 `33902490498` 均在
GNU Make 的 host `lzip-1.25.tar.gz` 输入上遇到 `download.savannah.gnu.org` 的 `502/504`。
`packages/make/source.lock` 因此改用 Savannah 的公开 release mirror
`download-mirror.savannah.gnu.org`；文件名、版本和 Buildroot 审核的 SHA-256
`09418a6d8fb83f5113f5bd856e09703df5d37bae0308c668d0f346e3d3f0a56f` 完全不变。
镜像只是传输端替换，不能作为放宽散列、替换归档内容或跳过来源复核的理由。

run `33902479037` 随后对 `wget-1.25.0.tar.lz` 的 `ftp.gnu.org:443` 连接等待
135 秒后超时（curl exit 28）；GNU 官方镜像选择器在 run `33903742083` 又返回
`502/504`。`packages/wget/source.lock` 因此固定使用 Buildroot 官方备份来源站
`https://sources.buildroot.net/wget/`。归档文件名、版本和 Buildroot 审核的 SHA-256
`19225cc756b0a088fc81148dc6a40a0c8f329af7fd8483f1c7b2fe50f4e08a1f` 完全不变。
它是 Buildroot 维护的备份下载端，不是未审核的独立来源；下载结果仍必须命中此 SHA-256。

run `33904493372` 对 `dialog-1.3-20220117.tgz` 得到的仅约 7 KiB 内容，其 SHA-256 为
`b19714c4c4de88cf005f92c9bc88e9f8dc4ddebeab9f734a500253b0bf06c1b9`，与 Buildroot
审核值 `754cb6bf7dc6a9ac5c1f80c13caa4d976e30a5a6e8b46f17b3bb9b080c31041f` 不同，因而被
CI 以 exit 69 拒绝。`packages/dialog/source.lock` 改用 Dialog 维护者的官方
`https://invisible-island.net/archives/dialog/`；归档文件名、版本和审核 SHA-256 保持不变。
这说明“镜像可访问”不足以准入，任何内容差异都必须停止，而不能修改锁定散列来迁就下载结果。

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
| 4 | `libcurl-4`、`curl` | 8.12.1 | `libcurl-4` 是 target provider；`curl` 的锁定源码构建与 base `/usr/bin/curl` 字节不同，CI 拒绝发布 |
| 5 | `wget`、`rsync` | 1.25.0、3.4.1 | Wget 只允许 CA/OpenSSL/zlib；`rsync` 在 `libpopt` 仍为 target provider 时暂停 |
| 6 | `iperf3`、`netcat`、`lsof` | 3.18、0.7.1、4.99.4 | 受控 LAN、无公开 listener；lsof 还需记录权限可见性 |
| 7 | `htop`（暂缓）、`nano`、`dialog`、`ncdu`、`pv` | 3.3.0、8.2、1.3-20220117、1.21、1.9.0 | 真实终端、locale/宽字符和小屏交互验收；`htop` 需先有独立的 libcap provider |
| 8 | `tmux`（暂缓） | 3.3a | 需先准入 OpenSSL-capable libevent runtime；再验证 detached session、capture、kill-session |
| 9 | `tdvp-source-tools`、`tdvp-diagnostics` | 1.6、1.1 | 仅元数据 profile；安装/卸载不得复制或误删工具/共享库 |
| 10 | `sdl2`、`sdl2-ttf`、`libmgba`、`tdvp-gba` | 2.30.11、2.22.0、0.10.5、0.2.3 | `retro-gba` 独立增量批次；四个 IPK 必须全部由来源锁重建，不能复用历史 r2/r3 payload；验证 Wayland/ALSA runtime closure、`tdvp-gba` 动态依赖及 `/opt/tdvp-gba` 的非覆盖安装。 |
| 11 | `sqlite3` | 3.48.0 | `database-tools` 只从 `libsqlite3-0` 同一次锁定源码构建的私有 staging 取得 CLI；仍验证 RISC-V ELF、`libsqlite3.so.0`、精确 readline/ncurses 依赖及无 base-path 覆盖。 |
| 12 | `bc` | 1.07.1 | `calculator-tools` 锁定 GNU bc 与 host-flex/host-m4 输入；只公开 `tdvp-bc`，不替换 firmware `bc`，并验证 RISC-V ELF、无 RPATH/RUNPATH 与 base-overlay。 |
| 13 | `coreutils` | 9.5 | `coreutils-tools` 只封装一个 GNU multi-call ELF，并以 `tdvp-coreutils-*` 公开 35 个基础命令；保留平台 Kconfig，以 coreutils 专用 configure override 禁用 ACL/attr/libcap/libselinux/OpenSSL/NLS，不覆盖 firmware/BusyBox 路径。 |
| 14 | `mtools` | 4.0.47 | `fat-media-tools` 锁定 GNU mtools archive 与只供解压的 host-lzip 1.25 输入，构建 FAT/MS-DOS 用户态工具组；全部以 `tdvp-mtools-*` 公开，私有 multi-call ELF/applet symlink 保留 `argv[0]` 语义，绝不覆盖 firmware/BusyBox 或未来标准路径。 |
| 15 | `dosfstools` | 4.2 | `fat-filesystem-tools` 从锁定 source 构建 FAT 创建、检查和 label 三个 ELF；全部以 `tdvp-dosfstools-*` 公开，私有 payload 不覆盖 `/sbin/*`、firmware 或 BusyBox 路径。 |
| 16 | `util-linux-tools` | 2.40.2 | `system-tools` 只启用命名的无 liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid 闭包命令；全部以 `tdvp-util-linux-*` 公开，不替换 firmware/BusyBox 路径，也不把基础镜像库作为隐式 provider。 |
| 17 | `exfatprogs` | 1.2.5 | `exfat-filesystem-tools` 仅提取 6 个锁定源码构建的 exFAT 命令；私有 ELF 位于 `/usr/libexec/tdvp-exfatprogs/`，公开入口均为 `tdvp-exfat-*`，不占用 `/usr/sbin/*`、firmware 或 BusyBox 路径，也不新增共享运行时 provider。 |
| 18 | `memtester` | 4.5.1 | `memory-diagnostic-tools` 只构建一个锁定源码的内存诊断 ELF；私有 payload 位于 `/usr/libexec/tdvp-memtester/`，公开入口仅为 `tdvp-memtester`，不占用 firmware/BusyBox 路径，也不新增共享运行时 provider。 |

应用只可以在其所有 runtime provider 已被同一候选批次成功打包、并通过 IPK 依赖闭包检查后
构建。共享库 IPK 必须先于其消费者安装到测试机。

`database-tools` 是与已合并的开发工具 batch 分离的 SQLite CLI 增量批次。它选择
`sqlite3` leaf，使闭包同时重建唯一的 `libsqlite3-0` provider；library IPK 仍只拥有
`libsqlite3.so*`。`libsqlite3-0` 只在同一个私有 `build-all` transaction 中 stage
`/usr/bin/sqlite3`，leaf 会核验 staging proof、RISC-V ELF、`DT_NEEDED` 的
`libsqlite3.so.0` 并执行 `deny` base-overlay gate。它不得使用固件中的命令、目标 root
copy、Debian binary 或其他 SQLite source。只有 GitHub Actions batch、后续 merge 和实机
`sqlite3 --version` / create-query-uninstall-rollback 记录都通过，才可作为 unsigned candidate。

`calculator-tools` 是单包、无 target shared-library provider 的增量批次。`bc` 只从锁定的
GNU bc 1.07.1 源码构建，host-flex 2.6.4 与 host-m4 1.4.19 仅作为同一私有 Buildroot
transaction 的 host 输入，绝不进入 IPK。目标 ELF 保存到 IPK 私有
`/usr/libexec/tdvp-bc/bc`，唯一公开入口是 `/usr/bin/tdvp-bc`；因此即使基础镜像以后拥有
`/usr/bin/bc`，该候选也不会覆盖它。只有 GitHub Actions batch、后续 merge 和实机
`tdvp-bc --version` / arbitrary-precision expression / uninstall-rollback 记录都通过，才可
作为 unsigned candidate。

`coreutils-tools` 同样不以“用 GNU 命令替换 BusyBox”作为准入路径。它只从锁定的 GNU
coreutils 9.5 archive 构建一个 RISC-V multi-call ELF，保存为
`/usr/libexec/tdvp-coreutils/coreutils`；每个公开入口都是独立的
`/usr/bin/tdvp-coreutils-<command>` wrapper。例如 `tdvp-coreutils-ls`、
`tdvp-coreutils-mktemp` 与 `tdvp-coreutils-chroot` 都不会占用 `/bin`、`/usr/bin/ls`
或其他 firmware 命令路径。recipe 不会修改 immutable platform Kconfig；它只在私有
Buildroot transaction 中以 `COREUTILS_CONF_OPTS` 显式关闭 coreutils 的 ACL、attr、libcap、
libselinux、OpenSSL 与 NLS 功能，避免把尚未准入的 target provider 链接进 closure。
它必须证明 locked source、RISC-V ELF、无 RPATH/RUNPATH、唯一 payload owner、runtime
closure 和 base-overlay gate；之后仍须在 K230 上记录 wrapper 功能、卸载和回滚，才可进入
unsigned candidate。

`fat-media-tools` 是独立的单包增量 batch。`mtools` 4.0.47 从 Buildroot 2025.02.1
审核的 GNU archive 编译，`lzip-1.25.tar.gz` 作为锁定的 host-only 解压输入；它仅在 runner
私有 Buildroot transaction 中解出 mtools 的 `.tar.lz`，绝不进入 target IPK。package payload
在私有 `/usr/libexec/tdvp-mtools/` 中保存
`mtools` multi-call ELF、`mkmanifest` 和选定 applet 的相对 symlink，以保持 mtools 根据
`argv[0]` 分派的行为。公开命令全部是 `/usr/bin/tdvp-mtools-*` wrapper，例如
`tdvp-mtools-mdir`、`tdvp-mtools-mcopy`、`tdvp-mtools-mformat`、`tdvp-mtools-mlabel`。
因此候选不占用 `/usr/bin/mcopy`、`/usr/bin/mdir`、`/bin/*` 或 target firmware 文件；不复制
Debian package、target root 文件或共享库。GitHub Actions 必须从锁定 archive 离线构建，验证
RISC-V ELF、无 RPATH/RUNPATH、IPK runtime closure 和 base-overlay；实机仍须验证只读
列目录、复制、小心使用的格式化/label 流程、卸载及回滚，才可进入 signed feed。

Actions run `33966562313` 在 mtools archive 通过 SHA-256 校验后，按离线规则发现私有
download root 缺少这个 `.tar.lz` 所需的 host-lzip 1.25；它在下载阶段终止，没有 artifact。
run `33966781743` 则已从锁定的 mtools 与 host-lzip 输入完成 RISC-V 编译和临时 target install，
但 recipe 的批准清单错误地包含未被 4.0.47 安装的 `mclasserase`，所以提取 gate 以 exit 81
拒绝并跳过 artifact 上传。该 install 证据明确列出 `mdoctorfat`，后续 retry 只以它替换
`mclasserase`。两个失败 run 均不是 merge source；不得以放宽命令存在性、关闭离线 source
check 或复制 target 文件来绕过。

`fat-filesystem-tools` 是与 `fat-media-tools` 分离的单包增量 batch。`dosfstools` 4.2
只从 Buildroot 2025.02.1 审核的 release archive 构建 `mkfs.fat`、`fsck.fat` 与
`fatlabel`。Buildroot 在 transaction 的临时 extraction root 中以 `/sbin` 安装它们；recipe
逐一验证其存在、RISC-V ELF 和无 RPATH/RUNPATH，再复制到私有
`/usr/libexec/tdvp-dosfstools/`。公开命令只有 `tdvp-dosfstools-mkfs-fat`、
`tdvp-dosfstools-fsck-fat` 和 `tdvp-dosfstools-fatlabel`，因此绝不占用 firmware
`/sbin/*`。该包不复制 Debian binary、target root 或共享库；GitHub Actions 必须通过 source
lock、runtime closure 与 base-overlay gate。格式化/检查的实机验证具有潜在破坏性，必须由
设备使用者选择非生产测试介质后执行，再记录卸载和回滚，才可签名或发布。

`exfat-filesystem-tools` 也是单包、无新增共享运行时 provider 的增量 batch。
`exfatprogs` 1.2.5 只从 Buildroot 2025.02.1 审核并给出 SHA-256 的 archive 构建
`mkfs.exfat`、`fsck.exfat`、`dump.exfat`、`exfat2img`、`tune.exfat` 和
`exfatlabel`。Buildroot 临时 extraction root 中的 `/usr/sbin` 安装路径只用于验证
这六个 RISC-V ELF；候选 payload 只把它们放进
`/usr/libexec/tdvp-exfatprogs/`，公开入口分别为 `/usr/bin/tdvp-exfat-mkfs`、
`tdvp-exfat-fsck`、`tdvp-exfat-dump`、`tdvp-exfat-image`、`tdvp-exfat-tune` 和
`tdvp-exfat-label`。它不复制 Debian binary、target root 文件或共享库。GitHub Actions
必须通过 source lock、RISC-V ELF、无 RPATH/RUNPATH、runtime closure 和 base-overlay
gate；CI 不执行任何会创建、修复、调优、标签或写镜像的前端。实机只能在设备使用者
显式选择的非生产介质上进行，并记录安装、卸载和回滚后才可成为发布证据。

Actions run `33971280098` 已完成该锁定 archive 的 K230 RISC-V 构建、六个白名单
命令的私有提取、无 RPATH/RUNPATH、runtime closure 与 base-overlay gate，并上传未签名
exfat-filesystem-tools artifact `9971033517`。随后它和此前 13 个成功 source batch 在
run `33971483972` 中逐 IPK 比较 hash、重新索引并在无编译模式下再次验证合并候选，生成
未签名 merged artifact `9971101810`。这些 run 是候选构建/合并证据，不是签名、公开
发布、部署或实机执行 exFAT 文件系统命令的授权。

`memory-diagnostic-tools` 是单包、无新增共享运行时 provider 的增量 batch。`memtester`
4.5.1 只从 Buildroot 2025.02.1 审核并给出 SHA-256 的 archive 构建一个 `memtester`
RISC-V ELF。它在临时 Buildroot 安装目录中出现的 `/usr/bin/memtester` 只用于验证；
候选 payload 只保留 `/usr/libexec/tdvp-memtester/memtester`，公开入口只有
`/usr/bin/tdvp-memtester`。原始上游 HTTP 地址不作为 source-lock fetch 输入；lock 以
Buildroot HTTPS archive mirror 取得由相同 Buildroot hash 验证的同一 archive。它不复制
Debian binary、target root 文件或共享库。GitHub Actions 必须通过 source lock、RISC-V
ELF、无 RPATH/RUNPATH、runtime closure 和 base-overlay gate，且不运行该程序。它会分配
并写入用户指定内存，物理地址模式有更高风险；实机只能由设备使用者在非生产设备上明确
限制内存预算、记录安装、卸载和回滚后执行。

`system-tools` 是一个单包、无新增共享运行时 provider 的增量 batch。它从 Buildroot
2025.02.1 审核的 util-linux 2.40.2 archive 离线构建，仅启用 cal、fallocate、IPC、
last/utmp、调度与 namespace 等明确命名的前端。所有 RISC-V ELF
都位于 `/usr/libexec/tdvp-util-linux/`，所有公开入口都为
`/usr/bin/tdvp-util-linux-<command>`；它不使用 basic set，也不选择 mount、分区、
文件系统、loop、wipefs、login/su/runuser/setpriv，并在私有 configure 中禁用
liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid。desktop baseline 的 systemd
select 保持不变，但私有 make 调用完整覆写 `UTIL_LINUX_CONF_OPTS`：关闭所有 programs 和
未拥有库后，仅开启该 cohort，因此不能把固件现存库变为隐式依赖，
也不能占用 firmware/BusyBox 路径。GitHub Actions 只从锁定源码构建、封装并审核
RISC-V ELF、RPATH/RUNPATH、base-overlay 和 runtime closure，绝不执行这些前端。
IPC、进程、namespace、文件或 terminal state 的实机操作须由使用者在非生产设备上显式
选择目标并记录安装、卸载、回滚后才可作为发布证据。

该候选的首次 Actions run `33968694581` 已完成锁定 archive 的 source-cache 审核，却在
Buildroot configure 阶段因默认的 liblastlog2 需要 SQLite 而停止；没有上传 artifact。
recipe 因此在该次 private transaction 的 configure 参数中关闭 liblastlog2。第二次 run
`33968909916` 已越过该 configure 问题并开始目标编译，但也证明不可变 SDK baseline 可以
预先启用宽泛的 util-linux feature：未受约束的临时 install 尝试安装 wall 与 mount，触发其
chgrp/chown hook 后在 staging 失败，同样没有 artifact。当前 recipe 不以放宽权限、复制
target root 文件或跳过 gate 来规避此情况；它先尝试逐一关闭非 cohort Kconfig feature，
再由下一次 GitHub Actions source batch 验证隔离边界。第三次 run `33969473024` 使这一
Kconfig 事实可复现：Buildroot 在 `olddefconfig` 后报告 `BR2_PACKAGE_UTIL_LINUX_AGETTY` 仍为 y，
因为 desktop baseline 的 systemd 明确 select 该 feature；该 guard 正确停止且没有 artifact。
修复不再试图以被选择项覆盖 select，而是以本段所述的完整 configure-option 覆写建立 source
边界。第四次 run `33970029697` 在进入 Buildroot 前由 `tdvp_buildroot_install` 的安全参数
grammar 拒绝了该覆写：`--with-systemdsystemunitdir=no` 含有 make-variable 名值分隔符之外的第二个
等号；没有开始编译，也没有 artifact。由于同一覆写已使用 `--without-systemd`，该路径参数没有
作用且被移除，保持 make-variable 只含允许字符的约束不变。

第五次 run `33970173415` 以该修复完成了锁定 util-linux archive 的 K230 RISC-V 编译、白名单
提取、无 RPATH/RUNPATH、runtime closure 与 base-overlay gate，并上传未签名 system-tools batch
artifact `9970727624`。它与此前 12 个成功 source batch 在 run `33970393061` 中逐 IPK 比较哈希、
重新索引并再次执行 merged closure/base-overlay 验证后，生成未签名 merged artifact `9970775466`。
这两项成功是候选构建和合并的证据，不是签名、公开发布、部署或实机执行任何 util-linux 命令的授权。

`tdvp-gba` 的锁定 commit `4c82b09e1bf042d0709c26ed6c4e5098a283a908` 已由 GitHub commit
API 和其固定 HTTPS archive endpoint 复核可达。早期 “仅本地 source cache、不可公开下载” 的
说明不再适用；package metadata 现已与 `source.lock` 对齐。`retro-gba` batch 仍只允许将该
archive 以 SHA-256 写入受控 source cache，最终交叉编译只读取缓存，并明确设置
`TDVP_REUSE_PUBLISHED_PAYLOADS=0`。这使旧 feed 的 SDL2/mGBA IPK 不能成为 r10 的隐式
二进制输入。

首次 `retro-gba` run `33921909790` 证明 `libmgba` 已由锁定源码实际构建并封装为
`libmgba_0.10.5-1_riscv64.ipk`，随后在 SDL2 的 development-ABI 预检处以 exit 68 停止：
workflow 未生成/导出 `TDVP_K230_WAYLAND_SDK_OVERLAY`。这不是来源、ELF 或 base-overlay
失败。后续 retry 必须复用匹配的 restored SDK output，通过
`prepare-tdvp-wayland-sdk-overlay.sh` 在 runner 临时目录创建 overlay，供 SDL2、SDL_ttf 与
GBA frontend 的 headers、pkg-config 和链接探测使用；overlay 不会进入 IPK，也不得从 target
rootfs 复制一个未声明的 runtime provider。

第二次 retry `33922256133` 已正确生成并导出该 overlay，但在它的 FreeType headers fallback
处停止。SDK 的 package-only cache 保留了 `build/freetype-2.13.3` 的 stamp，却没有保留其
`include/` 源码头文件；这不是 SDL2/mGBA/GBA 的 source lock、目标 ABI 或 runtime closure
失败。第三次 retry `33922965456` 又证明 restored SDK 的 `dl` base 并不含
`freetype-2.13.3.tar.xz`，所以也不能把该下载缓存误当作这个 header fallback 的来源契约。
第四次 retry `33923512627` 已到达新的 source-cache retrieval，并证实 lock 和 SHA-256 验证
本身有效；失败只是 `download-mirror.savannah.gnu.org` 的 TLS connection reset，未写入 archive，
也未启动任何 K230 package build。该 lock 改用与 Buildroot 维护流程一致的
`sources.buildroot.net/freetype/freetype-2.13.3.tar.xz` HTTPS mirror，仍以完全相同的
Buildroot SHA-256 验证。它不是下载失败时的未验证备用源：archive hash、文件名与 Buildroot
commit 仍必须全部一致。

后续 retry 的 helper 仍优先使用完整 build tree；若 cache 仍缺头文件，CI 必须先通过独立的
`support/wayland-sdk-overlay-source/source.lock` 将 FreeType 2.13.3 放入内容寻址的 source
cache。helper 只接受该 cache 中按 SHA-256 定位的 archive，并再次读取同一 restored SDK 中唯一的
Buildroot `package/freetype/freetype.mk`/`.hash` 核验版本与摘要；两份不可变记录必须一致，才会在
runner 临时目录解出 `ft2build.h` 与 `include/freetype`。该临时目录会在最终 overlay 前删除，既不会
进入 IPK，也不会使用 host headers、未锁定网络下载、target rootfs 的未声明 provider 或手写/合成的
pkg-config metadata。失败 run `33921909790`、`33922256133`、`33922965456` 与 `33923512627` 都不得
被 merge；只有修正后的独立 retry 通过全部 source、ELF、payload 和 runtime-closure gates 后才是可
合并候选。

第五次 retry `33924007401` 已在 GitHub Actions runner 中从锁定源码完成 `libmgba` 0.10.5 的
实际 K230 编译并生成 `libmgba_0.10.5-1_riscv64.ipk`，但在随后 SDL2/GBA 共用的 overlay 准入处以
exit 69 停止，明确缺少 `include/zlib.h`。该失败只说明新 overlay 没有实现既有 K230 development
contract 的两个公共 zlib 头；不是可接受的 IPK 产物，也不得 merge。修复只从同一匹配 SDK 复制
`zlib.h` 与其包含的 `zconf.h` 作为 runner 临时编译输入；不复制 `libz.so`、不合成 `zlib.pc`、不将
它们写入 overlay 以外的位置。`libz` 仍由候选 feed 的唯一 `libz` provider 拥有，runtime closure
gate 继续验证这一点。

zlib retry `33924722697` 已实际通过上述 overlay 准入、FreeType source-cache、target runtime base
和所有静态策略，并再次从锁定源码成功构建/封装 `libmgba`。随后它正确阻止在 SDL patch 之前：旧 patch
的 hunk 末尾把 `FindDeviceName(...))` 写成少一个右括号的 `FindDeviceName(...)`，且带有无意义的空行
删除/添加对；`git apply` 可以模糊接受它，但实际 recipe 使用的 GNU `patch --batch --forward` 在第 663
行拒绝，故没有 SDL2、SDL_ttf 或 GBA IPK 被产生或 merge。新 patch 直接从 source.lock 固定 commit
`fa24d868ac2f8fd558e4e914c9863411245db8fd` 重新生成，使用精确 `@@ -668,6 +668,34` hunk；其 SHA-256
为 `072edf301194f744e9782fd40e2e6bf6b25580af2408c61a42ea25a99d3ed16e`。本地只进行了这个精确源码的
GNU patch dry-run（无 K230 构建），随后才允许 GitHub Actions 重试。由于 SDL2 payload 代码输入发生
变化，`sdl2` 升为 `2.30.11-3`，依赖它的 `sdl2-ttf` 升为 `2.22.0-3`，`tdvp-gba` 升为 `0.2.3-4`，三者
保持精确版本依赖；失败 run `33924722697` 同样不得 merge。

五个已成功 batch 的首次 partial merge `33923703593` 也在下载 artifact 之前停止，原因是 merge
job 的 SDK cache `path` 集合漏掉了 package batch 保存时包含的 `build/**/.stamp_*`。GitHub Actions
cache version 包含 path 集合，故即使文本 key 相同也会被当作 cache miss；此修复把 merge restore
path 与 package-batch restore path 完全对齐。它不会重建 SDK、不会改 ABI identity，也不会把
`fail-on-cache-miss` 放宽为继续执行。

该修复后的 partial merge `33924004327` 已成功恢复 SDK，随后在第一个 source batch 的 artifact
枚举处停止。runner 内置的 GitHub CLI 不支持 `gh run view --json artifacts` 字段；因此 merge 改为
调用同一 Actions run artifacts REST API，再保持 `gh run download --name`、manifest SHA-256 比对和
所有后续 closure gates。这个调整不会从本地下载 artifact，也不会接受零个、多个或名称不符合
`tdvp-k230-r10-*-unsigned-*` 的 artifact。

final merge `33942996461` 在 IPK hash 比对阶段发现 development batch 与 Node batch 都带有
`libpython3.13_3.13.3-1_riscv64.ipk`，但 SHA-256 不同，因而以 exit 70 停止；没有进入索引、
closure 或上传步骤。最初把它归类为 private runtime-base 的假设是错误的：替代 merge
`33943923122` 恢复 catalog manifest 后仍以同一 exit 70 停止，因为该 manifest 不包含
`libpython3.13`。两个 source-batch 日志都显示它由锁定的 CPython 3.13.3 archive 直接交叉构建，
而非从 target runtime 复制；两次失败 run 均永久排除，不能产生或合并候选 feed。

`scripts/build-ipk.sh` 已以固定排序、epoch mtime、numeric owner 和 deterministic ar 创建 IPK，
所以不同外层 SHA-256 表示 payload 已不同，不能用“保留先到副本”掩盖。CPython 上游
`Modules/getbuildinfo.c` 的已知 fallback 会把编译时的 `__DATE__` 与 `__TIME__` 写入公共
`libpython`；原 direct-cross helper 也使用随机的 `/tmp/tdvp-python-build.*` source root。helper
现在在验证锁定源码仍具有该已审查 fallback 后，将 build-info 固定为 v3.13.3 upstream tag commit
`2025-04-08T13:54:08Z`，并固定 `SOURCE_DATE_EPOCH`、locale/time zone、Python hash seed 和
compiler source-path remap。`make` 后、`make install` 前会把生成的
`_sysconfigdata_*.py` 中的临时 `abs_srcdir`/`abs_builddir` 规范化；因此随后生成的 `.pyc`
也不保留 runner 的随机工作路径。它把 staging marker 升为 format 2，防止旧 staging 被误复用。

为避免误把 source-build 差异当成 runtime-base，merge 的默认规则仍是最严格的：任意同名同版本
IPK 必须逐字节 SHA-256 相同，否则 exit 70。只重跑受 CPython closure 影响的 development 与 Node
batch；其余五个已成功 source batch 保持可复用。两个替代 artifact 的 Python IPK 已相同，因此
`libpython3.13`、`python3-runtime`、`python3` 以及所有其他不在 target-runtime provider manifest
中的重复 source IPK 仍必须精确相同，不能以 artifact 顺序覆盖。

随后 partial merge `33958358691` 在同一 hash gate 发现
`tdvp-runtime-libexec_2025.02.1-1_riscv64.ipk` 的重复外层 SHA-256 不同而停止，尚未索引、closure
或上传。该名称在平台受审查的 `runtime-data-packages.tsv` 中明确是 `@remaining-usr-libexec` 的
target-runtime catalogue provider；它与 `libpython3.13` 的直接 source-build 身份不同。merge 因而
只恢复一个受限的 provenance 分支：先以同一 SDK/ABI cache key 恢复不可变的 private runtime base。
第一次实现只查 `.tdvp-target-runtime-packages.tsv`，而该 manifest 有意只列 top-level SONAME
provider；run `33959287158` 因而再次拒绝 data-catalogue package `tdvp-runtime-libexec`，并在同一
hash gate 停止。正确、完整且更窄的归属条件是：重复文件名必须逐字节等于该恢复的 private base 中
一个实际 IPK 文件名，同时 base 必须具有 provenance manifest 且不得存在公开 `Packages` index。
这样既包含 data/module catalogue，又不能把任意 public feed 或 source-built package 当作 runtime
base。cache 只定义文件成员资格，不提供、更不复制 IPK 内容；merge 仍保留先前已由其 source-batch
manifest 校验过 SHA-256 的副本。所有不在 private base 的差异一律 exit 70，故此前错误地被假设为
runtime-base 的 `libpython3.13` 仍受严格字节一致性约束。这个修复只重跑 merge job，不重建 SDK、
target-runtime base 或任何 source batch，随后仍必须通过 index、runtime closure 和 target-runtime
coverage gates。

development replacement `33946874048` 还证明 source lock 对上游分发漂移同样保持 fail-closed：
`oldmanprogrammer.net/tar/tree/tree-2.1.1.tgz` 返回了 11,949-byte、SHA-256 为
`a04acb9b6bcfdfe27acd1df517edca380ab43abda14e51984b3c08aa34204300` 的不同内容，不能满足
Buildroot 2025.02.1 审查的 `d3c3d55f403af7c76556546325aa1eca90b918cbaaf6d3ab60a49d8367ab90d5`。
因此该 run 在 source cache gate 停止，没有编译或上传 artifact。首次换用的 BLFS mirror
`mama.indstate.edu` 又在 GitHub runner DNS 中不可解析（curl exit 6），同样没有放宽 hash 或产生
artifact。`tree` source lock 现只将下载位置改为 Ubuntu archive 的
`tree_2.1.1.orig.tar.gz`：Ubuntu source manifest 为该 *orig* tarball 记录同一 60,515-byte 的
`d3c3…7ab90d5` SHA-256，故它是原 upstream archive 的按内容验证镜像，而非 Debian/Ubuntu patch
或 repack。逻辑文件名、版本、Buildroot source snapshot 与预期 SHA-256 均不变。下一个 GitHub
batch 必须用原有 SHA-256 验证该 mirror 内容，绝不接受新 hash、HTML 错页、Debian delta 或未经
审查的新版源码。

下一次 partial merge 还必须区分“SDK ABI”与“GitHub Actions cache 布局”。已成功的 archive batch
`33878735088` 记录的是同一固件/profile 的 cache `v2`，后续成功 batch 记录 `v3`；`v3` 只增加了
Buildroot package stamp 的缓存路径，不能成为要求全部旧 IPK 重编的 ABI 变化。新 manifest 记录不带
缓存后缀的 `sdk_abi_id`（固件固定 revision + RM69A10 profile）；merge 对新 batch 精确比较该字段。
为保留已审查的增量成果，缺少该字段的历史 manifest 仅显式接纳这两个已审查的 `v2`/`v3` key，其他
旧 key 一律拒绝。平台、release path、artifact 名称、每个 IPK SHA-256、SDK 恢复、索引和最终 runtime
closure/coverage gate 都没有放宽。

特别地，当前 staging K230 output 已选择 `BR2_PACKAGE_POPT=y` 并拥有
`/usr/lib/libpopt.so.0`。这使 `libpopt` 的普通 feed provider 被 base-overlay gate 拒绝，
从而也暂停 `rsync`；可接受的后续路径是先以独立、版本化的 feed provider 通过同一
GitHub Actions 准入链。不得把这份基础库当作 rsync 的隐式 runtime，也不得以同内容覆盖
绕过 gate。

GitHub Actions 的增量准入证据同样是候选台账的一部分：run `33901074012` 已从
`source.lock` 审核的 Buildroot 输入重新构建 `curl`，但字节级 base-overlay gate 报告
`/usr/bin/curl` 与目标不同，因此 `curl` 不得进入 r10 feed。run `33901555917` 对
`openssh-client` 的 `/usr/bin/ssh-agent` 得到相同结论。两者保留为
`tdvp-k230-r1` base 能力，不能以“已有路径”或放宽 overlay 策略的方式伪装成 feed IPK。

run `33904931122` 验证了 Dialog 的新锁定来源，随后在 `htop` 上被
`BR2_PACKAGE_LIBCAP` 的禁用断言停止。匹配 SDK 会把该 Kconfig 符号恢复为启用状态，
而 `tdvp-k230-r1` 的 seed ABI 清单只声明 loader/glibc/编译器运行时，并没有可在
`Depends` 中声明的独立 `libcap` owner。因此 r10 的 `network-tools` 批次暂时排除
`htop`；不得把目标镜像中碰巧存在的 `libcap` 当作隐式依赖，也不得伪造 seed owner。
后续只有在 `libcap` 以自己的来源锁、ABI owner、版本化 IPK 与设备验收记录通过准入后，
才可以重新评审 capability 支持的 `htop`。

同一 run 在 `tmux` 的 `BR2_PACKAGE_OPENSSL` 禁用断言处停止。`tmux` 的 Buildroot
路径通过 libevent 的可选 TLS 分支间接继承 OpenSSL；当前 SDK 把该符号恢复为启用状态，
而 TDVP 的窄 seed ABI 也不声明 `libssl`/`libcrypto` 为基础 owner。因此 r10 批次也暂时
排除 `tmux`。它只能在具有独立、版本化、已验收的 OpenSSL-capable libevent runtime
provider 后重新准入；不能借用目标镜像已有文件，或把未声明的 TLS ABI 藏在命令 IPK 中。

run `33905941863` 已构建到 GNU awk 的 payload gate，随后因它试图发布
`/usr/bin/awk` 而被 exit 77 拒绝。该路径属于固件命令，不能被 source-tools profile
覆盖。`gawk` 因此更新为 `5.3.1-2`：GNU 实现仍以 `/usr/bin/gawk` 提供，兼容前端改为
`/usr/bin/tdvp-awk`，其私有 `awk -> gawk` 关系仍只存在 IPK 自己的 libexec 目录。与之
精确依赖的 `tdvp-source-tools` 同步更新到 `1.6-3`。这保留 GNU awk 能力，同时确保卸载
该 IPK 不会改变固件的 `/usr/bin/awk`。

run `33906647472` 已成功构建前面的网络 leaf，随后错误地尝试重建已在 target-runtime
catalogue 中的 `ca-certificates`，因此它的私有 Buildroot 下载目录找不到该包的来源锁归档。
根因是 `build-all.sh` 的选择阶段已把 catalogue provider 排除，但递归 build 阶段只跳过
SONAME 型 target provider。两处现在使用同样的 catalogue 判定：已有的、带版本的
target-runtime IPK 直接保留在部分 feed 中，不重新编译、不要求重复 source cache，也不
改变其 ABI owner；真正需要 source build 的依赖仍会在 CI 预取并锁定校验。

在该修正后的 run `33907526598` 中，`wget` 已到达自己的 Buildroot configure gate。
该 SDK 全局启用了 GnuTLS，故旧的 Kconfig 禁用断言正确地拒绝了它。r10 改为仅在
该次 Buildroot make 调用传入 `BR2_PACKAGE_GNUTLS=n` 等七个可选 closure 变量；这样
`wget.mk` 选择 OpenSSL/zlib 分支，而 SDK `.config` 仍保持字节不变。后续 CI 必须以
ELF runtime-closure gate 证明确实只使用已声明的 provider。

run `33908264128` 证实该 Wget 配置已经进入 Buildroot 解包阶段，但 `wget-1.25.0.tar.lz`
需要 host `lzip-1.25`，而 base download cache 中并没有该 host helper。Wget 的 `source.lock`
因此新增同一份 Buildroot 审核的 host-lzip 归档：Savannah mirror URL、文件名
`lzip-1.25.tar.gz` 与 SHA-256
`09418a6d8fb83f5113f5bd856e09703df5d37bae0308c668d0f346e3d3f0a56f`。它是这个 .tar.lz
构建输入的一部分，CI 会先通过 source-cache 锁验证再放入私有 Buildroot 下载目录。

run `33907529611` 已用锁定 GitHub CLI source、Go 1.26.7 host archive、`go.mod`/`go.sum`
和 `vendor/modules.txt` 生成 vendor bundle；前一条记录的 archive SHA-256
`7d0291b6670a81ad46c701bac86e87bd4e9b4198301d831882e6f7533dd9c6ea` 不匹配。CI 产生的
实际摘要为 `1b974e17d52a82d09d02032442f15c171734974bb43f3bb5f49b8751dd22dfa1`，现已写入
`go-modules.lock`；其变更后的文本摘要
`6ae99bb890f2dd7ccc92d7041d94147a650f21b666c807c24dd3e59082e6d3c6` 同步写入
`gh/source.lock`。下一次 CI 必须重新生成相同 vendor archive 后才会继续交叉编译，不能
把先前失败产生的临时目录或未验证 cache 当作输入。

run `33908930481` 已证明新摘要本身已获接受，并把失败收敛到 vendor-cache helper 的
stdout 契约：`go mod verify` 输出的 `all modules verified` 被命令替换一并捕获，导致本应
只包含 vendor archive 绝对路径的变量变成两行，并被安全路径检查以 exit 93 拒绝。helper
现在把 `go mod download`、`go mod verify` 和 `go mod vendor` 的诊断输出都定向到 stderr；
它在 stdout 上只返回经哈希验证的 archive 路径。这个修正不改变 Go 模块、vendor 内容或
目标 ABI，只恢复函数调用方所依赖的单值返回协议，后续 CI 必须仍验证同一锁定摘要才可交叉编译。

run `33908926617` 已证明 host-lzip 作为锁定输入成功到达 Wget 编译阶段，但也证明先前
通过 `WGET_CONF_OPTS` 的覆盖会被 `wget.mk` 的追加分支重新引入 GnuTLS。新的 make-time
Kconfig view 解决该问题。同时，完整 GNU Wget 的源码 payload 与固件 `/usr/bin/wget`
不同，base-overlay gate 正确拒绝覆盖。因此 Wget 更新为 `1.25.0-2`，仅公开
`/usr/bin/tdvp-wget`；固件 wget 保持不变。依赖它的 `tdvp-source-tools` 更新为 `1.6-4`，
设备验收命令也使用 `tdvp-wget`。这与 `tdvp-awk` 前端相同：新能力通过明确名称加入，不
以替换 firmware command 的方式取得 PATH 优先级。

run `33910604255` 已证明 GitHub CLI 的 vendor-cache stdout 修复生效：构建越过 `gh` 后继续
到 GNU grep 的 payload gate。该 gate 按设计拒绝其默认 `/usr/bin/grep`，因为该路径由固件
拥有；这既不是 ABI 问题，也不是放宽 gate 的理由。`grep` 因而更新为 `3.11-2`，私有 GNU
二进制仍保留在该 IPK 的 libexec 目录，唯一公开入口改为 `/usr/bin/tdvp-grep`。依赖它的
`tdvp-source-tools` 更新为 `1.6-5`，设备验收使用 `tdvp-grep -P`；固件 grep 和 IPK 卸载
后的行为均不受影响。

run `33913031567` 又越过 GNU grep，随后在 GNU Less 默认 `/usr/bin/less` 的同一 immutable
base-overlay gate 处停止。Less 更新为 `661-2` 并只公开 `/usr/bin/tdvp-less`；它的私有
二进制和 `libncursesw` 运行时所有权保持不变。`tdvp-source-tools` 因而更新到 `1.6-6` 并以
`tdvp-less --version` 验收。不能因 BusyBox 已有 pager 而覆盖它，也不能把未选择的
`lesskey`/`lessecho` 命令扩大为新的公开 feed ABI。

run `33914366172` 已继续构建并封装 `libsqlite3-0`，但在 CPython 的来源锁 helper 前停止：
repository 中的验证器以 `bash` 调用本来是正确的，但 Python helper 额外要求其 Git 文件模式
带 executable bit；该模式不属于脚本内容或锁定来源的 ABI 契约。helper 现在像其它来源锁调用
路径一样只接受 regular、non-symlink verifier，并显式以 `bash` 运行它。这保留安全文件检查和
完整 SHA-256 验证，不改变 CPython 源码、交叉构建 flags、任何动态库 provider 或 IPK 内容。

run `33918586751` 已通过 `libcares`、`libuv`、`libnghttp2`、ICU 等直接 source provider 的
构建，并完成 Node `configure.py`；失败发生在真正目标编译之前。跨编译时显式选择的
`--ninja` generator 为 V8 的 `v8_inspector_headers` 同时生成 host 与 target rule，而两者均声明
同一个 `gen/inspector-generated-output-root/src/js_protocol.stamp` 输出。Ninja 正确地以
“multiple rules generate”拒绝该图；这不是 RISC-V ABI、来源锁、provider 闭包或 QEMU action
wrapper 的失败。r10 因而改回 Node/GYP 的默认 Make generator，并用源码级策略测试禁止配方重新
引入 `--ninja`。这不是 `-w dupbuild=warn` 一类掩盖重复输出的变通；target action 仍由原有
QEMU wrapper 执行，全部 source lock、ELF、RPATH 与 runtime-closure gates 均保持。下一次仅
Node.js 的 GitHub Actions 批次必须从头证明这个 generator 路径能完成实际 K230 IPK 构建。

在 SDL2 patch 修复和 runtime-base 刷新 `33925822425` 成功后，新的 `retro-gba` run
`33926416128` 已恢复同一 K230 SDK、工具链、Buildroot download cache、FreeType source cache 和
更新后的 target-runtime base。它随后从锁定来源实际构建并封装 `libmgba`、`sdl2` 与
`sdl2-ttf`，但 `tdvp-gba` 在生成 Wayland 绑定前以 exit 67 停止：package-only SDK cache 虽保留
`wayland-protocols` 的 Buildroot stamp，却不保留 build tree 中
`unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml`。这不是 SDL patch、目标 ABI、ELF runtime
closure 或此前 runtime cache 的失败；该 run 没有上传 unsigned batch，必须排除出 merge。

修复把 development-only overlay 的来源锁扩展为 Buildroot 2025.02.1 固定提交
`3815d578c5759fa824322ea3d95ad51b55ab888e` 所审计的 `wayland-protocols-1.39.tar.xz`：文件名和
SHA-256 `e1dcdcbbf08e2e0a8a02ee5d9a0be3a6aafc39a4b51fa7e0d2f1a16411cb72fa` 必须先进入内容寻址
source cache，overlay helper 再读取同一 restored SDK 的
`package/wayland-protocols/wayland-protocols.mk`/`.hash` 重新验证版本与摘要。若 SDK staging
已带有同一匹配 XML，它优先使用该输入；否则只从已验证 archive 解出 `stable`、`staging` 与
`unstable` 协议树到 runner 临时 overlay 的 `share/wayland-protocols`。GBA 的 linux-dmabuf 和未来
LoFiBox 的 xdg-shell/xdg-decoration 都先查 matching build tree、再查这个 verified overlay。协议
XML 不进入任何 IPK、不是 runtime provider，也不得改用 host 文件、任意 target-root copy、手工
生成 XML 或未锁定网络下载。新的 retry 仍必须完成实际 K230 编译、IPK SHA manifest、ELF 和
runtime-closure gate 后才能成为 merge 输入。

## 设备生命周期记录

每一个 unsigned candidate 都要独立记录：

1. 安装前 `opkg status`、路径和 SONAME 状态；
2. 安装后版本检查及上表指定的核心功能；
3. 对网络工具使用受控 endpoint，对 `lsof` 记录运行用户和可见性；
4. 卸载后确认固件 BusyBox、loader、基础库和其它候选仍正常；
5. 回滚到前一不可变 feed revision 后重复核心 smoke test。

只有所有 provider/应用/profile 都有这些记录，且候选 IPK 未更改来源锁、SDK identity 或
测试机平台，才可进入签名和不可变 release 流程。
