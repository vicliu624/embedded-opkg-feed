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
| 4 | `libcurl-4`、`curl` | 8.12.1 | `libcurl-4` 是 target provider；直接占用 `/usr/bin/curl` 的锁定源码构建曾被 CI 拒绝。`http-transfer-tools` 只从同一 source transaction stage ELF，私有保存为 `/usr/libexec/tdvp-curl/curl`，公开入口为 `/usr/bin/tdvp-curl`，不替换 target 命令。 |
| 5 | `wget`、`rsync` | 1.25.0、3.4.1 | Wget 只允许 CA/OpenSSL/zlib；匹配 SDK 的 rsync 事务保留 OpenSSL 分支，因此 `rsync` 精确依赖 immutable target catalogue 的 `libpopt (= 1.19-1)`、`libz (= 1.3.1-1)`、`libcrypto-3 (= 3.4.1-1)`，不重建三者。SSH 是用户以默认 platform `ssh` 或 `-e /usr/bin/tdvp-ssh` 明确选择的传输命令，不是 rsync 的 ELF/包 provider 依赖；ACL/LZ4/xxHash/Zstd 仍关闭，`file-sync-tools` 仍须通过 GitHub Actions。 |
| 6 | `iperf3`、`netcat`、`lsof` | 3.18、0.7.1、4.99.4 | 受控 LAN、无公开 listener；lsof 还需记录权限可见性 |
| 7 | `libcap-2`（target provider）、`htop`（候选）、`nano`、`dialog`、`ncdu`、`pv` | 2025.02.1、3.3.0、8.2、1.3-20220117、1.21、1.9.0 | immutable catalogue 已拥有 `libcap.so.2`；`htop` 只能精确依赖 `libcap-2 (= 2025.02.1-1)` 以启用 capability view，绝不重建或覆盖该 ABI。真实终端、locale/宽字符和小屏交互验收仍是独立门禁。 |
| 8 | `libevent`、`tmux`（已通过 CI/无重编 merge，待实机） | 2.1.12、3.3a | cohort 从锁定源码构建 `libevent (= 2.1.12-1)`，tmux 精确消费它与 immutable catalogue 的 `libncursesw (= 6.4-20230603-1)`；`libevent` 的 TLS closure 精确使用 target `libcrypto-3`。仍需验证 detached session、capture、kill-session。 |
| 9 | `tdvp-source-tools`、`tdvp-diagnostics`（已通过 hydrate CI / 无重编 24-batch merge，待实机） | 1.6、1.1 | 仅元数据 profile；run `33987100478` 已在 GitHub Actions 从成功的 merged candidate hydrate 276 个已验证 IPK，只封装 `tdvp-diagnostics_1.1-1_riscv64.ipk`；run `33987408229` 又在无编译模式完成 24-batch hash、索引与 closure merge。绝不重编已准入的诊断工具。安装/卸载不得复制或误删工具/共享库。 |
| 10 | `sdl2`、`sdl2-ttf`、`libmgba`、`tdvp-gba` | 2.30.11、2.22.0、0.10.5、0.2.3 | `retro-gba` 独立增量批次；四个 IPK 必须全部由来源锁重建，不能复用历史 r2/r3 payload；验证 Wayland/ALSA runtime closure、`tdvp-gba` 动态依赖及 `/opt/tdvp-gba` 的非覆盖安装。 |
| 11 | `sqlite3` | 3.48.0 | `database-tools` 只从 `libsqlite3-0` 同一次锁定源码构建的私有 staging 取得 CLI；仍验证 RISC-V ELF、`libsqlite3.so.0`、精确 readline/ncurses 依赖及无 base-path 覆盖。 |
| 12 | `bc` | 1.07.1 | `calculator-tools` 锁定 GNU bc 与 host-flex/host-m4 输入；只公开 `tdvp-bc`，不替换 firmware `bc`，并验证 RISC-V ELF、无 RPATH/RUNPATH 与 base-overlay。 |
| 13 | `coreutils` | 9.5 | `coreutils-tools` 只封装一个 GNU multi-call ELF，并以 `tdvp-coreutils-*` 公开 35 个基础命令；保留平台 Kconfig，以 coreutils 专用 configure override 禁用 ACL/attr/libcap/libselinux/OpenSSL/NLS，不覆盖 firmware/BusyBox 路径。 |
| 14 | `mtools` | 4.0.47 | `fat-media-tools` 锁定 GNU mtools archive 与只供解压的 host-lzip 1.25 输入，构建 FAT/MS-DOS 用户态工具组；全部以 `tdvp-mtools-*` 公开，私有 multi-call ELF/applet symlink 保留 `argv[0]` 语义，绝不覆盖 firmware/BusyBox 或未来标准路径。 |
| 15 | `dosfstools` | 4.2 | `fat-filesystem-tools` 从锁定 source 构建 FAT 创建、检查和 label 三个 ELF；全部以 `tdvp-dosfstools-*` 公开，私有 payload 不覆盖 `/sbin/*`、firmware 或 BusyBox 路径。 |
| 16 | `util-linux-tools` | 2.40.2 | `system-tools` 只启用命名的无 liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid 闭包命令；全部以 `tdvp-util-linux-*` 公开，不替换 firmware/BusyBox 路径，也不把基础镜像库作为隐式 provider。 |
| 17 | `exfatprogs` | 1.2.5 | `exfat-filesystem-tools` 仅提取 6 个锁定源码构建的 exFAT 命令；私有 ELF 位于 `/usr/libexec/tdvp-exfatprogs/`，公开入口均为 `tdvp-exfat-*`，不占用 `/usr/sbin/*`、firmware 或 BusyBox 路径，也不新增共享运行时 provider。 |
| 18 | `memtester` | 4.5.1 | `memory-diagnostic-tools` 只构建一个锁定源码的内存诊断 ELF；私有 payload 位于 `/usr/libexec/tdvp-memtester/`，公开入口仅为 `tdvp-memtester`，不占用 firmware/BusyBox 路径，也不新增共享运行时 provider。 |
| 19 | `tree` | 2.1.1 | `directory-tree-tools` 只构建一个锁定源码的目录树 ELF；唯一公开入口为 `tdvp-tree`，不替换 firmware/BusyBox `tree` 路径，也不新增共享运行时 provider。 |
| 20 | `less` | 661 | `terminal-pager-tools` 只构建一个锁定源码 pager ELF；唯一公开入口为 `tdvp-less`，精确复用 target catalogue 的 `libncursesw`，不替换 firmware/BusyBox `less` 路径。 |
| 21 | `ffprobe` | 4.4.4 | `media-inspection-tools` 只从锁定的 Buildroot FFmpeg 4.4.4 source build stage `ffprobe` frontend。它不导入 host binary、不接管 base 的 `ffmpeg`，且 `deny` overlay 会拒绝 target 已有的 `/usr/bin/ffprobe` 路径或任何未拥有的动态依赖。 |
| 22 | `gdbserver`、`ethtool`（GitHub Actions source batch/无重编 merge 已通过，待实机） | 15.1、6.14 | `debug-network-tools` 只允许私有 ELF 与 `tdvp-gdbserver`、`tdvp-ethtool`。gdbserver 清空 Buildroot 的 SDK `debug-root` post-install hook，并关闭 full GDB/TUI/Python；ethtool 关闭 netlink/libmnl 和 pretty-print。run `33988534267` 验证 source cache、RISC-V ELF、runtime closure 和 deny overlay 并产生两个 IPK；run `33988940718` 只 hash-merge 25 个 artifact、重建索引并再次通过 closure/target-runtime coverage。CI 不启动 debug server 或变更网络接口。 |
| 23 | `i2c-tools`（GitHub Actions source batch/无重编 merge 已通过，待实机） | 4.4 | `i2c-inspection-tools` 只允许私有静态链接 ELF 与 `tdvp-i2c-{detect,dump,set,get,transfer}`。run `33989899026` 禁用 `BR2_PACKAGE_PYTHON3`/`py-smbus`，并实际传入 `BUILD_DYNAMIC_LIB=0`、`BUILD_STATIC_LIB=1`、`USE_STATIC_LIB=1`；临时 `libi2c.a` 和任何 `libi2c.so` 均未进入 IPK。run `33990178543` 只 hash-merge 26 个 artifact、重建索引并再次通过 closure/target-runtime coverage。CI 不得探测、读取、写入或枚举 I2C 总线。 |
| 24 | `inotify-tools`（GitHub Actions source batch/无重编 merge 已通过，待实机） | 3.20.2.2 | `filesystem-event-tools` 只允许与私有 static `libinotifytools` implementation 链接的 ELF，及 `tdvp-inotify-wait`、`tdvp-inotify-watch`。run [`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904) 实际传入 `--disable-shared --enable-static --enable-static-binary --disable-doxygen`，产生一个 IPK 并通过 source cache、RISC-V ELF、runtime closure、deny overlay 与 feed verification；run [`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095) 只 hash-merge 27 个 artifact、重建索引并再次通过 closure/target-runtime coverage。任何 `libinotifytools`、头文件或普通 firmware 路径均未进入 IPK；CI 不得启动 watcher、传入路径或观察真实 filesystem event。 |

应用只可以在其所有 runtime provider 已被同一候选批次成功打包、并通过 IPK 依赖闭包检查后
构建。共享库 IPK 必须先于其消费者安装到测试机。

**延后 socket relay 候选（2026-09-06）。** 不把当前 Buildroot 2025.02.1 的 `socat` 1.8.0.2
直接纳入候选：其上游 HTTPS 下载端点在受审信任链中呈现自签名证书，且
[NVD CVE-2026-56123](https://nvd.nist.gov/vuln/detail/CVE-2026-56123) 将 `< 1.8.1.2` 列为受影响范围。
在有可验证的上游 HTTPS source artifact、经审查的较新 Buildroot source input 及独立 closure 设计之前，
不得为 `socat` 创建 recipe、source batch 或 IPK。该延后决定不是 Debian/Buildroot 来源的通用否定。

**源码导航包的去重结论（2026-09-05）。** `development-tools` run `33948462622` 已从锁定来源
实际构建 `diffutils_3.10-1`、`findutils_4.10.0-1`、`gawk_5.3.1-2`、`grep_3.11-2`、`sed_4.9-1`
和 `which_2.21-1`。为验证增量路径而启动的 `source-navigation-tools` run `33976531692` 也通过了
构建、ELF、runtime closure 与 base-overlay gate，但它完全重复这些已有包；merge run `33976943804`
在遇到不同 payload 的同名 `diffutils_3.10-1` 后以 exit 70 fail-closed。该 artifact 不是 merge
source，batch 入口和配方改动均已撤回；旧的成功 source batch 是这六个包的唯一 r10 构建证据。
以后新增候选必须先比对成功 batch 的实际 IPK 清单，不能以“仓库中有配方”误判为尚未构建。

**r10 实际 package inventory（2026-09-06）。** 对 27 个成功 source batch 的 GitHub Actions
`built *.ipk` 记录逐一去重后，102 个 r10 recipe 中已有 86 个 recipe package 具备实际 source-build
证据。其余 12 个通用 package 是 immutable target catalogue provider：`ca-certificates`、`libatomic-1`、
`libcrypto-3`、`libcurl-4`、`libexpat-1`、`libffi-8`、`libncursesw`、`libpcre2-8`、`libpopt`、
`libreadline`、`libssl-3` 与 `libz`；它们只能复用，不能为补齐数量重编。metadata-only
`tdvp-diagnostics` 已在 run `33987100478` 生成独立 unsigned batch artifact，并已由 24-batch 无重编
merge run `33987408229` 纳入 r10 candidate。`gdbserver` 与 `ethtool` 的 source lock、私有命名空间和
静态策略门禁已由 `debug-network-tools` run
[`33988534267`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267) 实际验证：从锁定
cache 交叉构建的 `ethtool_6.14-1_riscv64.ipk` 与 `gdbserver_15.1-1_riscv64.ipk` 均通过 feed verification，
并上传 artifact [`9975971554`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267/artifacts/9975971554)
（90,422,923 bytes；zip SHA-256 `999adf320af6631743463861159d7df9ffb46dad9bb46e06822a3e501b66c44a`）。
二者计入 84，并已由 25-batch no-recompile merge run
[`33988940718`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718) 纳入 merged candidate：
它下载并比对 25 个 compatible artifact 的 IPK hash，只重建 `Packages` 索引、验证 runtime closure 和
445 个 non-ABI dynamic objects 的 target-runtime coverage；其 SDK-build 与 package-build job 都是 skipped。
最终 merged unsigned artifact 为
[`9976065136`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718/artifacts/9976065136)
（`tdvp-k230-r10-merged-unsigned-341f925…`，196,327,304 bytes；zip SHA-256
`b8a59e8356ed4865960056e629ecbcb355709a9b899e022923225f7bb114ae7d`）。`tdvp-hello`、LoFiBox 与
Cardputer 应用不属于本 release。
`i2c-tools` 的 source lock、static-only 构建边界、私有命名空间和独立
`i2c-inspection-tools` Actions batch 已由 run
[`33989899026`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026) 实际验证：从锁定
cache 交叉构建的 `i2c-tools_4.4-1_riscv64.ipk` 通过 feed verification，并上传 artifact
[`9976342416`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026/artifacts/9976342416)
（90,121,328 bytes；zip SHA-256 `5da4d34ac6923de025113a2f180f042f5db72c30c3ad962e712be96bed828a72`）。
它计入 85，并已由 26-artifact no-recompile merge run
[`33990178543`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543) 纳入 merged candidate：
run 下载并比对全部 26 个 compatible artifact 的 IPK hash，只重建 `Packages` 索引、验证 runtime closure 和
445 个 non-ABI dynamic objects 的 target-runtime coverage；SDK-build 与 package-build job 都是 skipped。最终
merged unsigned artifact 为
[`9976438201`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543/artifacts/9976438201)
（`tdvp-k230-r10-merged-unsigned-131279c…`，196,361,181 bytes；zip SHA-256
`b3309e77019d68583464eaf28af21526ea203856a121216c040a6eac8fdd8fc9`）。
`inotify-tools` 的 source lock、无 shared `libinotifytools` 输出、私有命令路径和独立
`filesystem-event-tools` Actions batch 已由 run
[`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904) 实际验证：从锁定
cache 交叉构建的 `inotify-tools_3.20.2.2-1_riscv64.ipk` 通过 feed verification，并上传 artifact
[`9976701684`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904/artifacts/9976701684)
（90,138,431 bytes；zip SHA-256 `693daa5000ce40db80da8a422abf99d14a8fc20edf20c4407605050c9da67d35`）。
它计入 86，并已由 27-artifact no-recompile merge run
[`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095) 纳入 merged candidate：
run 下载并比对全部 27 个 compatible artifact 的 IPK hash，只重建 `Packages` 索引、验证 runtime closure 和
445 个 non-ABI dynamic objects 的 target-runtime coverage；SDK-build 与 package-build job 都是 skipped。最终
merged unsigned artifact 为
[`9976793781`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095/artifacts/9976793781)
（`tdvp-k230-r10-merged-unsigned-1c2c281…`，196,412,136 bytes；zip SHA-256
`319c26927150e18dd442110e4e1d9afaf81dc23491d5922c220b08d0c8bd8716`）。CI 的验收只检查
package payload，绝不启动 watcher、传入路径或观察真实 filesystem event。
为使这个 metadata profile 也真正增量，`diagnostics-profile` 必须提供成功的
`base_merged_run_id`：CI 只接受一份未过期的 merged unsigned artifact，校验 run 成功态、唯一 artifact、
feed 路径和无顶层 symlink；若 prior artifact 含有同名 target-runtime IPK，则保留本次新恢复、权威的
target base，不导入或比较这个 target-derived 容器副本。其余 source-built IPK 才会复用，并仅封装
`tdvp-diagnostics`。它不触发历史 source package 的再次构建。实际 run `33987100478` 已以 run
`33985545990` 为基线完成这一门禁：水合 276 个已验证 IPK、保留重复的 target runtime 容器、仅产出
`tdvp-diagnostics_1.1-1_riscv64.ipk`，并上传 unsigned artifact
[`9975532821`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987100478/artifacts/9975532821)
（196,004,873 bytes）。这不是签名、release/publish、部署或实机安装授权。
随后 24-batch no-recompile merge run
[`33987408229`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229) 的 SDK-build 和
package-build job 均为 skipped；它比较输入 IPK hash、重新生成 `Packages` 索引，并通过 runtime closure 与
445 个 non-ABI dynamic objects 的 target-runtime coverage。最终 merged unsigned artifact 为
[`9975645724`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229/artifacts/9975645724)
（`tdvp-k230-r10-merged-unsigned-3f100ce…`，195,991,913 bytes）。它仍未签名、未 release/publish、未部署或
安装到设备，且没有实机生命周期验证记录。

**CA 信任库所有权结论（2026-09-05）。** `runtime-data-packages.tsv` 已把固定 target 的 `/etc/ssl`
明确归属为 `ca-certificates`。`trust-store-runtime` run `33977596329` 成功恢复 SDK、source cache、
target-runtime base 并通过所有静态 gate，随后 `build-all` 复用该 target catalogue package，因没有可
构建 source recipe 以 exit 68 停止，未上传 artifact。这是正确的“已有 target provider”结论：不应以
同名 Debian source recipe 重建、覆盖或重新发布 CA bundle。此 package 已随每个 runtime base 入候选
目录；未来 TLS consumer 必须引用该 target-derived catalogue provider 的精确版本。

**OpenSSH client 路径冲突结论（2026-09-05）。** `secure-transfer-tools` run `33977961721`
在 GitHub Actions 中成功恢复固定 K230 工具链、SDK、source cache、target-runtime base，并完成
OpenSSH 9.9p2 的 RISC-V client 编译；不含 server、`/etc/ssh`、setuid helper 或 key 工具。但封装前的
`PACKAGE_BASE_OVERLAY=identical` gate 发现 `/usr/bin/ssh-agent` 与固定 target 的同一路径字节不同，
以 exit 79 fail-closed，未上传 batch artifact。故 `openssh-client` 已从 r10 candidate cohort 和
旧的 direct-path workflow dispatch matrix 移除；其 `source.lock` 与 client-only recipe 保留作可复核的
上游输入记录，不能作为覆盖 target 命令的 feed IPK 或被 `rsync` 等后续候选当作已拥有的 provider。
新的 `secure-transfer-tools` 是独立的命名空间候选设计：它只允许私有
`/usr/libexec/tdvp-openssh-client/{ssh,scp,sftp,ssh-agent,ssh-add}` 和
`/usr/bin/tdvp-{ssh,scp,sftp,ssh-agent,ssh-add}` wrapper，使用 `deny` overlay 并继续拒绝任何 target
路径、`/etc/ssh`、server、setuid helper 或 key 工具。它必须经过新的 GitHub Actions source/RISC-V/
runtime-closure/IPK-index gate 与后续无重编 merge 后，才能成为 unsigned candidate。

**命名空间 OpenSSH 的 GitHub Actions 准入证据（2026-09-05）。** `secure-transfer-tools` run
[`33981065347`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347) 只选择
`openssh-client`；固定 K230 toolchain、SDK、锁定 source cache、target-runtime catalogue 与 batch policy
均通过，runner 随后完成唯一的 selected dependency closure。日志记录
`tdvp-openssh-client payload ready from locked OpenSSH source build`，并产出
`openssh-client_9.9p2-1_riscv64.ipk`；候选 feed verification 两次成功。它上传 unsigned batch artifact
[`9973816789`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347/artifacts/9973816789)
（`tdvp-k230-r10-secure-transfer-tools-unsigned-e0cd6d5…`，91,164,015 bytes）。这是私有 ELF 和
`tdvp-*` wrapper 的准入证据，绝不把 direct-path OpenSSH 失败 run 变为可接受输入。

后续 merge run [`33981319632`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632)
只接收此前 19 个成功 source batch 与上述 batch：其 package-build/SDK-base jobs 均明确 skipped，
成功比较 20 个输入 batch 的 IPK hash，并在 **without compiling** 模式完成 merged feed 的索引、runtime
dependency closure 与 target-runtime coverage 验证。它上传 merged unsigned artifact
[`9973893992`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632/artifacts/9973893992)
（`tdvp-k230-r10-merged-unsigned-e0cd6d5…`，194,733,782 bytes）。两个 artifact 都仍是 unsigned
candidate；未签名、未 release/publish、未部署/安装到设备，也未执行实机生命周期操作。

`media-inspection-tools` 是从 r7 历史配方迁移的单叶 r10 候选。`ffprobe` 的 `source.lock` 固定
Buildroot 2025.02.1 审查的 FFmpeg 4.4.4 archive 与 SHA-256；GitHub Actions 只允许匹配 K230 SDK 的
私有 Buildroot transaction stage `/usr/bin/ffprobe`。它不在本机编译，也不复制 base image 的
`/usr/bin/ffmpeg`。封装时仍须通过 RISC-V ELF、RPATH/RUNPATH、精确 runtime closure 和 `deny`
base-overlay gate；只有 batch 与后续无重编 merge 都成功、上传 unsigned artifact 后，才可记为
feed candidate，实机媒体、安装、卸载和回滚仍是独立门禁。

首次 `media-inspection-tools` run `33978610176` 已验证来源锁、toolchain、SDK、target-runtime
和 policy，且完成 FFmpeg 4.4.4 的 RISC-V 构建；但该 Buildroot recipe 还会生成私有 Debian-format
side artifact，恢复的 Actions SDK 不保留空的 `output/images/deb` 目录，令 `dpkg-deb` 因目标目录不存在
而 exit 2。它不是 ABI、ELF、路径所有权或 source hash 的放宽理由，也没有上传 artifact。配方现在仅在
Actions SDK workspace 中显式创建此 Buildroot-required 目录；该目录和 side artifact 不会 stage 到 IPK
payload、target runtime 或 SDK cache。重试 run `33979150084` 成功完成 source、RISC-V、runtime closure、
`deny` overlay 与 feed verification，上传 artifact `9973352053`
(`tdvp-k230-r10-media-inspection-tools-unsigned-fc77690…`，90,343,614 bytes)，其中含
`ffprobe_4.4.4-1_riscv64.ipk`。随后无重编 merge run `33979683310` 对全部 18 个 source batch 比对
IPK hash、重新索引并验证完整 closure，上传 merged artifact `9973413113`
(`tdvp-k230-r10-merged-unsigned-fc77690…`，193,564,339 bytes)。两者均为 unsigned candidate；未签名、
未 release/publish、未安装到设备，也未执行任何实机媒体、卸载或回滚操作。

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

Actions run `33972132034` 已完成锁定 memtester archive 的 K230 RISC-V 构建、私有 ELF
提取、无 RPATH/RUNPATH、runtime closure 与 base-overlay gate，并上传未签名
memory-diagnostic-tools artifact `9971278184`。随后它和此前 14 个成功 source batch 在
run `33972330479` 中逐 IPK 比较 hash、重新索引并在无编译模式下再次验证合并候选，生成
未签名 merged artifact `9971324996`。这些 run 是候选构建/合并证据，不是签名、公开
发布、部署或实机运行内存诊断的授权。

**LibYAML 准入结论（2026-09-05）。** `libyaml-0.so.2` 已在固定 K230 target runtime 中，
所以它是 target-derived provider，不是可新增的 source-built provider。首次 `yaml-runtime`
run `33972857828` 在 source-cache、Buildroot、K230 编译和 artifact 上传之前因 runtime-base
cache miss 停止；用于验证缓存路径的迁移 run `33973476445` 成功恢复已有 SDK、跳过 SDK build，
只重新生成 target-derived catalogue。随后 retry `33973838867` 已实际恢复新的 runtime-base、
刷新候选私有 owner map 并通过全部静态 gate，但 `build-all` 明确报告
`source runtime recipe deferred; target owns libyaml-0.so.2`，随后以“没有可构建 recipe”
fail-closed 结束，未上传 artifact。这是正确拒绝，不是需要靠关闭 gate 或重复编译解决的故障；
强行将同一 SONAME 再编译成 IPK 会替换/复制平台 ABI。因此本候选、其 source lock 与 batch
入口均已撤回；未来 YAML consumer 应精确依赖 target catalogue 中的 `libyaml-0` provider，
而非携带私有 parser。

缓存边界也据此更正：`extra-runtime-owners.tsv` 是可能改变 target-derived IPK 名称或版本的
legacy/attestation 输入，必须仍进入 runtime-base key；只有已经由 GitHub Actions 证明**不存在于
matching target** 的 source provider 才可写入 `source-runtime-owners.tsv`。每个 source batch
复制 runtime-base 后由 `refresh-extra-runtime-owners.sh` 将后一份清单合并进候选私有 owner map，
严格核对 `PACKAGE`、`VERSION` 和 `PACKAGE_RELEASES`，冲突立即拒绝且不会修改共享 cache。这样
新增真实 source provider 只构建自身 closure；target ABI 的身份或版本声明变化才会在 GitHub
Actions 中重建 runtime-base，且仍不会重编既有 source package。

`directory-tree-tools` 是下一个独立的单包候选。`tree` 2.1.1 使用 Buildroot 2025.02.1
审核的源选择与 SHA-256；早期 upstream endpoint 返回内容漂移时，source lock 已记录并固定为
Ubuntu 的同内容 `orig` archive，而不是 Ubuntu patch/repack。CI 只从该锁定 archive 构建一个
RISC-V ELF，保存到 private payload；公开 `/usr/bin/tdvp-tree` wrapper 不占用 firmware/BusyBox
标准路径。它没有非平台共享库依赖、不会创建 source runtime provider，且 GitHub Actions 不执行
tree 的文件遍历命令。成功后的 artifact 仍须通过 IPK、RPATH/RUNPATH、runtime closure 与
base-overlay gate，且只作为 unsigned candidate。

首次 `directory-tree-tools` run `33974767492` 已确认恢复 SDK、runtime-base 和 source cache 的
增量路径均正常，但新增 batch 后有九个历史 policy test 仍将 workflow 选项写成旧的精确列表，
故在 source build 前以 policy gate 停止；没有生成 IPK 或 artifact。该测试矩阵已在
`3f79ddc` 同步，retry `33975012697` 仅从锁定 tree archive 完成 K230 RISC-V source closure、
私有 payload 提取、RPATH/RUNPATH、runtime closure 与 base-overlay gate，并上传 unsigned
artifact `9972102351`。随后 merge `33975265337` 对此前 15 个成功 source batch 加这一 batch
逐 IPK 比较 SHA-256、重新索引并重新验证 runtime/target coverage，全程无编译，生成 unsigned
merged artifact `9972160481`。这些均为候选证据，不是签名、发布、部署或实机执行授权。

`terminal-pager-tools` 是紧随其后的单包候选。GNU Less 661 使用 Buildroot 2025.02.1
审核、SHA-256 锁定的上游 archive；其唯一非平台依赖是 target catalogue 已拥有的
`libncursesw (= 6.4-20230603-1)`。`/usr/bin/less` 仅是私有 extraction 中的验证路径，最终
IPK 的唯一公开入口为 `/usr/bin/tdvp-less`，不会覆盖 firmware/BusyBox pager，也不携带
`lesskey`、`lessecho` 或共享库。GitHub Actions 只构建、封装并审计；不得执行 interactive
pager 或把终端会话作为 CI 验收。成功前它仍只是 source-lock candidate。

run `33975682895` 已从该锁定 Less archive 完成 K230 RISC-V 单包 source closure、私有
payload 提取、无 RPATH/RUNPATH、runtime closure 与 base-overlay gate，并上传 unsigned
artifact `9972273878`。随后 run `33975892465` 对此前 16 个成功 source batch 加入 Less 后
逐 IPK 比较 SHA-256、重新索引并再次验证 runtime/target coverage；该 merge 未运行任何
Buildroot package 编译，生成 unsigned merged artifact `9972335828`。这些是候选构建/合并
证据，不是签名、公开发布、部署或实机 pager 执行授权。

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
`/usr/lib/libpopt.so.0`。这使普通 source-built `libpopt` feed provider 被 base-overlay gate 拒绝；
其后 target-runtime catalogue 以 `libpopt (= 1.19-1)` 和 `libz (= 1.3.1-1)` 的版本化 attestation
成为这两个 SONAME 的唯一 provider。匹配 SDK 又会恢复 `BR2_PACKAGE_OPENSSL=y`，使锁定的 Buildroot rsync
transaction 启用 OpenSSL 分支；它只能精确声明现有的 `libcrypto-3 (= 3.4.1-1)`，而不能关闭全局 Kconfig
或重建/覆盖这三个 ABI。远程 shell 同样不是 package ABI：默认使用 platform `ssh`，或由用户通过
`-e /usr/bin/tdvp-ssh` 显式选择已安装的 namespaced client。首次 `file-sync-tools` remote audit
[`33983507607`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983507607) 已证明三个 target
provider 都会被 defer，但旧配方错误断言 OpenSSL 已关闭，故在 Buildroot configuration 以
`Buildroot did not disable BR2_PACKAGE_OPENSSL`（exit 71）停止；没有编译完成或上传 artifact。修正后的
run [`33983785585`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585) 使用精确
`libcrypto-3` ABI，实际通过锁定源码、RISC-V ELF、runtime closure 与 deny base-overlay，并上传 unsigned
batch artifact [`9974581047`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585/artifacts/9974581047)
（`tdvp-k230-r10-file-sync-tools-unsigned-fd0c34a3…`，90,386,375 bytes）。随后的 22-batch no-recompile
merge run [`33984054059`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059) 比对每个
输入 IPK hash，重新索引并验证 runtime closure/base-overlay，上传 merged unsigned artifact
[`9974652475`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059/artifacts/9974652475)
（`tdvp-k230-r10-merged-unsigned-fd0c34a3…`，195,190,117 bytes）。这些 artifact 均未签名、未 release/publish、
未部署或安装到设备，也没有实机生命周期验证记录。

GitHub Actions 的增量准入证据同样是候选台账的一部分：run `33901074012` 已从
`source.lock` 审核的 Buildroot 输入重新构建 `curl`，但字节级 base-overlay gate 报告
`/usr/bin/curl` 与目标不同，因此 `curl` 不得进入 r10 feed。run `33901555917` 对
`openssh-client` 的 `/usr/bin/ssh-agent` 得到相同结论。两者保留为
`tdvp-k230-r1` base 能力，不能以“已有路径”或放宽 overlay 策略的方式伪装成 feed IPK。

`http-transfer-tools` 不改变上述拒绝结论：它不发布 `/usr/bin/curl`，也不要求 target 文件字节相同。
同一份经过来源锁核验的 Buildroot `libcurl-4` transaction 只提供 source-built command staging proof；
leaf 将 ELF 移入 `/usr/libexec/tdvp-curl/curl`，只添加 `/usr/bin/tdvp-curl` wrapper，并继续去除
RPATH/RUNPATH、精确依赖 target catalogue 的 `libcurl-4` 与 `ca-certificates`。因此它是一次全新的
namespaced candidate batch，仍须由 GitHub Actions 通过 RISC-V、runtime closure、`deny` overlay、IPK
索引和后续无重编 merge 后，才能成为 unsigned candidate；不得覆盖、删除或重命名 target 的 curl。

**命名空间 curl 的 GitHub Actions 准入证据（2026-09-05）。** `http-transfer-tools` run
[`33980193318`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980193318) 只选择 `curl`；
固定 K230 toolchain、SDK、锁定 source cache、target-runtime catalogue 与 batch policy 全部恢复/检查成功，
再由 runner 完成唯一的 selected dependency closure 构建。日志记录
`tdvp-curl payload ready from libcurl-4 staged source build`，并产出
`curl_8.12.1-1_riscv64.ipk`；候选 feed verification 两次成功。run 上传 unsigned batch artifact
[`9973572086`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980193318/artifacts/9973572086)
（`tdvp-k230-r10-http-transfer-tools-unsigned-ba9277f…`，90,180,302 bytes）。这只证明
`/usr/libexec/tdvp-curl/curl` 加 `/usr/bin/tdvp-curl` 的新命名空间载荷通过准入；不改变对
`/usr/bin/curl` 的拒绝结论。

随后 merge run [`33980466654`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980466654)
只接收此前 18 个成功 source batch 与上述新 batch：其 build job 明确 skipped，成功下载并比较所有
19 个输入 batch 的 IPK hash，随后在 **without compiling** 模式重新索引、验证 merged runtime
closure/base-overlay。它上传 merged unsigned artifact
[`9973634779`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980466654/artifacts/9973634779)
（`tdvp-k230-r10-merged-unsigned-ba9277f…`，193,657,204 bytes）。该成果仍只是 unsigned candidate；
未签名、未 release/publish、未部署或安装到设备，也未执行任何实机生命周期验证。

run `33904931122` 验证了 Dialog 的新锁定来源，随后在 `htop` 上被
`BR2_PACKAGE_LIBCAP` 的禁用断言停止。匹配 SDK 会把该 Kconfig 符号恢复为启用状态，
而 `tdvp-k230-r1` 的 seed ABI 清单只声明 loader/glibc/编译器运行时，并没有可在
`Depends` 中声明的独立 `libcap` owner；因此旧的 `network-tools` 批次正确排除 `htop`，
不得把目标镜像中碰巧存在的 `libcap` 当作隐式依赖，也不得伪造 seed owner。

`process-monitoring-tools` 的首次 ownership audit 已由 GitHub Actions run
[`33982220719`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982220719) 给出权威结论。
它恢复固定 SDK、source cache 与 private target-runtime catalogue 后，在 source-owner refresh 以 exit 69
停止：`libcap.so.2` 已属于 `libcap-2 2025.02.1-1`，与试验性的 source provider
`libcap-2 2.73-1` 冲突；尚未编译、封装或上传 artifact。这是正确的 fail-closed 结果，不能通过改写
target 版本、使用 `identical` overlay 或发布同路径 source library 绕过。

因此新的 `process-monitoring-tools` 只 source-build `htop (= 3.3.0-1)`；它以精确
`Depends: libcap-2 (= 2025.02.1-1)` 使用 immutable target catalogue 的 owner，同时保留 capability
view。它不重建、复制、覆盖或隐式借用 `libcap.so.2`，也不打包 `capsh`/`setcap`/`getcap`。修正后的
GitHub Actions run [`33982469638`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638)
已实际通过 htop source lock、RISC-V ELF、无 RPATH/RUNPATH、runtime closure 与 `deny` base-overlay；它上传
unsigned batch artifact [`9974194807`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638/artifacts/9974194807)
（`tdvp-k230-r10-process-monitoring-tools-unsigned-c4fc7b28…`，90,244,788 bytes）。随后 no-recompile
21-batch merge run [`33982760512`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512) 比对每个
输入 IPK hash，并重新索引验证合并 candidate 的路径归属与 runtime closure；它上传 merged unsigned artifact
[`9974285835`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512/artifacts/9974285835)
（`tdvp-k230-r10-merged-unsigned-c4fc7b28…`，194,891,156 bytes）。两个 artifact 均未签名、未 release/publish、
未部署或安装到设备，也没有实机生命周期验证记录。

同一 run 曾在 `tmux` 的 `BR2_PACKAGE_OPENSSL` 禁用断言处停止。之后已复核 pin 到
Buildroot 2025.02.1 的 `tmux.mk`：tmux 直接依赖仅为 `libevent`、`ncurses` 与
`host-pkgconf`；OpenSSL 只是 `libevent.mk` 的可选分支。run `33984719429` 证明 matching
SDK 强制保持全局 `BR2_PACKAGE_SYSTEMD=y`，所以不能以 Kconfig 禁用该符号。修正后的配方
不再修改全局 OpenSSL/systemd/utf8proc，而是在 make-time 固定 tmux 的
`--disable-systemd --disable-utf8proc` 和 `libevent ncurses host-pkgconf` closure。该 cohort
从锁定源码构建 `libevent`，由它精确声明 target `libcrypto-3` 的 TLS/runtime closure；tmux
精确依赖这个 provider 与 target `libncursesw`。修正后的 GitHub Actions
[`33985238251`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251) 已通过 matching-SDK
交叉构建、RISC-V ELF、runtime closure、`deny` base-overlay 和 feed verification，并上传 unsigned
`terminal-session-tools` artifact [`9974999937`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251/artifacts/9974999937)
（90,887,183 bytes）。随后 23-batch no-recompile merge
[`33985545990`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990) 对全部输入 IPK
逐一比较 SHA-256，再重新索引并验证 runtime closure/base-overlay；其 build job 为 skipped，并上传
merged unsigned artifact [`9975077200`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990/artifacts/9975077200)
（195,989,739 bytes）。所有 artifact 仍未签名、发布、部署或安装到设备；仍必须完成 detached session、
capture、kill-session 的实机生命周期验证，才可考虑签名或发布。

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
