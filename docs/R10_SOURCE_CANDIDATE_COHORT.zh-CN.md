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

应用只可以在其所有 runtime provider 已被同一候选批次成功打包、并通过 IPK 依赖闭包检查后
构建。共享库 IPK 必须先于其消费者安装到测试机。

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

特别地，当前 staging K230 output 已选择 `BR2_PACKAGE_POPT=y` 并拥有
`/usr/lib/libpopt.so.0`。这使 `libpopt` 的普通 feed provider 被 base-overlay gate 拒绝，
从而也暂停 `rsync`；详情及可接受的后续路径见上述本地证据台账。不得把这份基础库当作
rsync 的隐式 runtime，也不得以同内容覆盖绕过 gate。

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

## 设备生命周期记录

每一个 unsigned candidate 都要独立记录：

1. 安装前 `opkg status`、路径和 SONAME 状态；
2. 安装后版本检查及上表指定的核心功能；
3. 对网络工具使用受控 endpoint，对 `lsof` 记录运行用户和可见性；
4. 卸载后确认固件 BusyBox、loader、基础库和其它候选仍正常；
5. 回滚到前一不可变 feed revision 后重复核心 smoke test。

只有所有 provider/应用/profile 都有这些记录，且候选 IPK 未更改来源锁、SDK identity 或
测试机平台，才可进入签名和不可变 release 流程。
