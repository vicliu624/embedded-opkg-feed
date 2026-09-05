# 历史 recipe 的来源锁迁移台账

[中文（当前）](SOURCE_LOCK_MIGRATION.zh-CN.md) | [English](SOURCE_LOCK_MIGRATION.md)

本台账补充[上游源码准入与可复现打包约定](UPSTREAM_SOURCES.zh-CN.md)。它解决的是
一个历史迁移问题：旧 recipe 即使带有 `r9` 或 `r10` 标签，也**不**因目录已存在而
自动满足新的源码供应链要求。只有具备合格 `source.lock`，或是纯 TDVP profile 且有
明确 `SOURCE_LOCK_EXEMPT_REASON` 的 package，才能作为 source-lock candidate 的输入。

每次迁移或新增 recipe 后，维护者应执行：

```sh
bash ./scripts/verify-source-lock.sh --repo-root . --all
find packages -mindepth 2 -maxdepth 2 -name package.env -type f | LC_ALL=C sort
```

第一条命令验证所有已提交的锁；第二条命令用于重审 package 清单和本台账。新建或修改
第三方 recipe 由 CI 的 changed-recipe gate 强制要求锁文件，不能借由“历史迁移尚未完成”
绕过准入。

对于 r10 的共享库 provider，必须区分两类注册表。`extra-runtime-owners.tsv` 是
target-runtime catalogue 的 legacy/attestation 输入：它可能改变从固定 K230 target 提取的 IPK
名称或版本，故必须进入 GitHub Actions runtime-base cache key。`source-runtime-owners.tsv`
仅容纳已由匹配 target 验证为**不存在**的 source-built SONAME；每个 source batch 在 runner
中复制 private runtime base 后，才用 `refresh-extra-runtime-owners.sh` 合并后一份清单。helper
会核对 `package.env` 的 `PACKAGE`、`VERSION` 和 `PACKAGE_RELEASES`，同一 SONAME 的任何不一致
均失败；它不生成 IPK、更不修改共享 cache。因此新增、确实不在 target 中的 library recipe
只触发自身 source closure，而不是历史库的全量重编。若 target ABI、attestation、runtime-base
实现或 target runtime 数据变化，才允许以 GitHub Actions 的 `build-sdk-base` 迁移该 cache；这一步
不构建 feed source package，也不签名、发布或部署。

## 已迁移并可离线审计的基础工具链

下列 r9/r10 package 已有 `source.lock`，由 HTTPS 内容寻址 source cache 校验后可进入
离线交叉构建流程。下文单独列出的 `libatomic-1` 是唯一经过审查的“匹配 target 运行时
所有权转移”，其证据要求更窄；它不构成普通上游源码包的例外：

- Buildroot-derived 维护命令：`make`、`pkgconf`、`patch`、`diffutils`、`strace`；
- TLS 信任库：`ca-certificates` 已由固定 K230 target 的 `/etc/ssl` runtime-data catalogue 提供。
  `trust-store-runtime` run `33977596329` 证明它不是可迁移的 source candidate：选择该同名 recipe 时，
  `build-all` 正确复用 target provider 并停止，而非重新构建或覆盖信任库。未来 TLS consumer 只能引用
  target catalogue 的精确 provider，不能复制 Debian 或 host 生成的 bundle；
- OpenSSH client（命名空间候选，普通路径不准入）：`openssh-client` 锁定 portable 9.9p2 source archive，
  并只构建 `ssh`、`scp`、`sftp`、`ssh-agent`、`ssh-add` client 工具。run `33977961721` 已在 GitHub
  Actions 交叉编译完成，但 identical overlay gate 发现 `/usr/bin/ssh-agent` 与固定 target 的同路径字节
  不同而以 exit 79 拒绝；普通 `/usr/bin/ssh*` 路径仍永远不是此 feed 的发布目标。独立的
  `secure-transfer-tools` 只可将 RISC-V ELF 私有保存在 `/usr/libexec/tdvp-openssh-client/`，并提供
  `tdvp-ssh`、`tdvp-scp`、`tdvp-sftp`、`tdvp-ssh-agent`、`tdvp-ssh-add` wrapper；它仍须通过新的
  GitHub Actions source/closure/deny-overlay/IPK-index 准入和无重编 merge。run
  [`33981065347`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347) 已从锁定 source
  完成这一个 client closure、记录 private payload、通过 feed verification，并上传
  `openssh-client_9.9p2-1_riscv64.ipk` artifact
  [`9973816789`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347/artifacts/9973816789)
  （91,164,015 bytes）。merge run
  [`33981319632`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632) 对此前 19 个成功
  batch 加此 batch 逐 IPK hash 比较、无编译重建索引并验证 runtime closure/target coverage，上传 merged
  artifact [`9973893992`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632/artifacts/9973893992)
  （194,733,782 bytes）。两者仍为 unsigned candidate，未签名、发布、部署或在设备执行；
- 媒体探测 leaf（候选）：`ffprobe` 从 r7 配方迁移到 r10，锁定 Buildroot 2025.02.1 的 FFmpeg 4.4.4
  archive/hash，只 stage `ffprobe` frontend。首次 run `33978610176` 已完成 RISC-V FFmpeg 构建，但
  Buildroot Debian side-artifact 目录在恢复 SDK 中不存在而 exit 2，未上传 artifact；修正仅在 Actions
  workspace 创建该非 payload 目录。重试 run `33979150084` 通过 source、RISC-V、runtime closure、
  deny overlay 与 feed verification，上传 `ffprobe_4.4.4-1_riscv64.ipk` batch artifact `9973352053`；
  随后的无重编 18-batch merge run `33979683310` 成功并上传 merged artifact `9973413113`。它仍是 unsigned
  candidate，尚未签名、发布或执行实机生命周期门禁；
- 命名空间 HTTP transfer leaf（候选）：直接发布 `/usr/bin/curl` 的 source build 已在 run
  `33901074012` 被 target base-overlay 拒绝，故新的 `http-transfer-tools` 不替换该路径。它从相同的
  锁定 Buildroot `libcurl-4` transaction 取得 source-built staging proof，将 ELF 私有放在
  `/usr/libexec/tdvp-curl/curl`，唯一公开入口为 `/usr/bin/tdvp-curl`，并精确依赖 target catalogue 的
  `libcurl-4` 与 `ca-certificates`。GitHub Actions run
  [`33980193318`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980193318) 只构建这一
  closure，记录 `tdvp-curl payload ready from libcurl-4 staged source build`，通过候选 feed verification，
  并上传 `curl_8.12.1-1_riscv64.ipk` batch artifact
  [`9973572086`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980193318/artifacts/9973572086)
  （90,180,302 bytes）。随后的 run
  [`33980466654`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980466654) 对此前 18 个
  成功 source batch 加此 batch 比较全部 IPK hash、无编译重建索引并验证 closure/base-overlay，上传 merged
  artifact [`9973634779`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33980466654/artifacts/9973634779)
  （193,657,204 bytes）。两个 artifact 均为 unsigned candidate；未签名、发布、部署或在设备执行；
- r10 文本/搜索/终端诊断工具：`tree`、`less`、`file`、`which`、`curl`、`wget`、`iperf3`、`lsof`、`netcat`、`rsync`、`dos2unix`、`jq`、`bc`、
  `grep`、`sed`、`findutils`、`diffutils`、`gawk`、`htop`、`nano`、`tmux`；`htop` 的 capability view
  仅可精确使用 immutable target catalogue 的 `libcap-2 (= 2025.02.1-1)`、`libcap.so.2` owner，绝不重建、
  覆盖或隐式借用 firmware library。run [`33982220719`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982220719)
  已以 source-owner conflict 正确拒绝尝试把它改为 `2.73-1` source provider，且在编译前未上传 artifact；修正后的
  `process-monitoring-tools` 在 run [`33982469638`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638)
  实际通过 htop source/closure/deny-overlay 准入，并上传 unsigned batch artifact
  [`9974194807`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638/artifacts/9974194807)
  （90,244,788 bytes）。不重新编译的 21-batch merge run
  [`33982760512`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512) 进一步比较全部输入 IPK hash、
  重新索引并验证 closure/base-overlay，上传 merged unsigned artifact
  [`9974285835`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512/artifacts/9974285835)
  （194,891,156 bytes）。这些仍是 unsigned candidate；未签名、发布、部署或在设备执行。
  `nano` 保持当前 SDK 未选中 `file/libmagic` 的终端编辑配置；
  二者都只复用已拥有的 `libncursesw`；
- Vim 终端编辑器：`vim-runtime`、`vim`；二者锁定同一 Buildroot 2025.02.1 审查的
  Vim 9.1.0145 源归档，并在私有离线 `BR2_DL_DIR` 中交叉构建。`vim-runtime` 仅拥有
  runtime 数据和许可证；`vim` 仅拥有私有 ELF、`/usr/bin/vim` 包装器及 TDVP 配置，
  其唯一的非平台 ELF 依赖为已拥有的 `libncursesw`，并已审计无 RPATH/RUNPATH；
- TLS 信任库：`ca-certificates` 由固定 K230 target catalogue 的 `/etc/ssl` 提供。它不是 source
  candidate；run `33977596329` 已证明同名 source recipe 会被正确地保留 target provider 而停止，
  不能以 Debian source 或 host 生成的 bundle 覆盖它；
- SSH transport 客户端（仅命名空间候选）：`openssh-client` 的锁定 OpenSSH 9.9p2 source 和 client-only
  构建边界可供审计，但 run `33977961721` 的 `/usr/bin/ssh-agent` identical-overlay 检查失败，因此它
  不得替换 firmware 文件。后续候选只允许私有 ELF 和 `tdvp-*` wrapper；在新的 GitHub Actions batch
  与无重编 merge 成功前，它不是 feed provider。run `33981065347` 与 20-batch merge `33981319632`
  现已提供 unsigned candidate evidence；签名 feed 准入及任何 consumer/device 生命周期验证仍独立未完成；
- Git 客户端拆分：`git-runtime` 与 `git` 均锁定 Buildroot 2025.02.1 选定且给出哈希的
  Git 2.48.1 release archive，再以匹配 SDK/sysroot 和已校验的离线 source cache 直接
  交叉构建。`git` 仅拥有 `/usr/bin/git`；`git-runtime` 只拥有明确白名单中的客户端
  helper/template，且以 `git-core/git -> ../../bin/git` 链接消除重复 frontend。产出的
  RISC-V IPK 均无 RPATH/RUNPATH，并精确拥有 curl、Expat、OpenSSL、PCRE2、zlib、CA
  证书与 OpenSSH provider。它们刻意排除 `git-daemon`、HTTP backend/CGI、`git-shell`、
  Gitweb、浏览器启动器和 Perl/Python/Tcl/Tk 工具；拆分与验证边界见
  [`packages/git/README.md`](../packages/git/README.md)；
- Git forge 客户端：`gh` 锁定 GitHub CLI 2.98.0 的不可变源码归档，并把官方 Go
  1.26.7 linux/amd64 归档明确记录为 **host-only** 编译工具，绝不进入 target 或 IPK。
  `go-modules.lock` 同时锁定上游 `go.mod`/原始 `go.sum`、Go 解析后补全的 `go.sum`、
  `vendor/modules.txt`、179 个 vendor module 与确定性 vendor bundle 的 SHA-256。缓存
  预热阶段只有在这些哈希均匹配时才允许访问 Go proxy；最终 linux/riscv64 构建使用空
  `GOMODCACHE`、`GOPROXY=off`、`GOSUMDB=off` 和 `-mod=vendor`。已得到 36 MB 静态
  RISC-V ELF 与候选 IPK，均无动态库、RPATH/RUNPATH；仍须在完整匹配 K230 SDK 和设备上
  完成 HTTPS/SSH、安装、卸载及回滚门禁后才能发布；
- FFI 运行时：`libffi-8` 锁定 Buildroot 2025.02.1 审查的 libffi 3.4.6
  归档，只将公共 ABI `libffi.so.8 -> libffi.so.8.1.4` 制作成独立 IPK。
  已完成 source-cache 构建和候选 IPK 审计，因此它是 CPython `_ctypes` 及后续 FFI
  consumer 的唯一可复用 provider：载荷为 RISC-V ELF64、无 RPATH/RUNPATH，且只依赖
  TDVP 平台 ABI。不得在解释器包中私自复制它，也不得从固件借用；
- 必需的共享运行时：`libz`、`libmagic`、`libjq`、`libpcre2-8`、`libncursesw`、
  `libreadline`、`libbz2`、`liblzma`、`libzstd`、`libexpat-1`、`libcrypto-3`、
  `libssl-3`、`libcurl-4`、`libffi-8`、`libsqlite3-0`、`libmpdec-4`；其中 `libexpat-1` 是 Git XML 解析所需的独立
  `libexpat.so.1` provider，已离线构建并审计为仅依赖平台 ABI 的 libc/libm/loader；
  OpenSSL 3.4.1 则拆为唯一的 `libcrypto.so.3` 与 `libssl.so.3` provider，后者精确
  依赖前者。`libcurl-4` 从锁定的 curl 8.12.1 源码、按审查过的最小 HTTPS 配置离线构建，
  它拥有 `libcurl.so.4`，并精确依赖 CA 信任库、OpenSSL、`libzstd`、`libz` 与
  `libatomic-1`。本候选没有选入 c-ares、IDN、PSL、libssh2、Brotli、nghttp2、GSASL
  或 RTMP 支持。相邻、已完成来源准入的 `curl` leaf 仅在这**同一次**私有
  Buildroot 事务中额外启用 `BR2_PACKAGE_LIBCURL_CURL`，且只能复制经 staging 证明、
  RISC-V ELF 类型、`libcurl.so.4` 依赖和 RPATH/RUNPATH policy 验证后的
  `/usr/bin/curl` 前端；它的实际候选 IPK 仍须经匹配 K230 SDK 构建及实机生命周期
  证据后才可产生；
- 已完成来源准入的 GNU Wget 命令：`wget` 锁定 Wget 1.25.0 与 host-pkgconf 2.3.0；
  它要求匹配 SDK 已启用 OpenSSL/libOpenSSL 和 zlib，随后在私有 Buildroot 事务中明确
  关闭 PSL、GnuTLS、IDN2/IRI、c-ares、PCRE/PCRE2 与 libuuid。该包不携带共享库，只
  复用独立拥有的 CA、OpenSSL 与 zlib provider；实际候选 IPK 仍须经过匹配 K230 SDK
  和实机生命周期证据；
- 已完成来源准入的网络诊断命令：`iperf3` 锁定 Buildroot 2025.02.1 选定的 iperf3
  3.18 归档。配方会在事务前检查匹配 SDK 的线程与原子操作能力，并明确关闭可选
  OpenSSL 认证模式；它没有额外 feed runtime 依赖，只打包私有命令。实际候选 IPK
  仍须经过匹配 K230 SDK 和实机生命周期证据；
- 已完成来源准入的打开文件诊断命令：`lsof` 锁定 Buildroot 2025.02.1 选定的 lsof
  4.99.4 归档。配方会检查匹配 SDK 的 MMU 能力，并明确关闭可选 `libtirpc` 链接；它
  只保留 Linux `/proc` 命令，不新增 feed runtime provider。实际候选 IPK 仍须经过
  匹配 K230 SDK 和实机权限/可见性生命周期证据；
- 已完成来源准入的连接诊断命令：`netcat` 锁定 Buildroot 2025.02.1 选定的 GNU
  Netcat 0.7.1 归档。它的 target recipe 没有可选共享库闭包；但 `nc` 仍是 IPK 私有
  命令，发布前必须通过 base-overlay 路径冲突检查。实机测试只针对受控 endpoint，
  不得暴露未认证 listener；
- 已完成来源准入的终端多路复用器：`libevent` 是其四个公共 event-loop SONAME 的锁定来源
  shared provider，而 `tmux` 精确依赖 `libevent` 与 target catalogue 的 `libncursesw`。
  其 Buildroot 2025.02.1 closure 锁定 tmux、libevent、host-pkgconf 以及与 libevent 的
  target-attested libcrypto closure 匹配的 OpenSSL 归档。tmux 本身不直接链接 OpenSSL 或
  systemd，也不可覆盖匹配 SDK 的全局功能选择：recipe-scoped `TMUX_CONF_OPTS` 关闭
  systemd/utf8proc，固定 `TMUX_DEPENDENCIES` 阻止它们进入构建期。GitHub Actions
  [run `33985238251`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251)
  已通过 matching-SDK 交叉构建、RISC-V ELF、closure 和 deny-overlay 门禁，并上传 unsigned batch artifact
  [`9974999937`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251/artifacts/9974999937)
  （90,887,183 bytes）。23-batch no-recompile merge，
  [run `33985545990`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990)，
  在没有 build job 的条件下比较每个输入 IPK SHA-256、重新索引并验证 closure/base-overlay，并上传
  merged unsigned artifact
  [`9975077200`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990/artifacts/9975077200)
  （195,989,739 bytes）。所有 artifact 仍未签名、发布或部署，且需要实机会话生命周期证据；
- 增量元数据 profile：像 `tdvp-diagnostics` 一样依赖已准入 source package 的 profile，必须向
  GitHub Actions batch 提供 `base_merged_run_id`。CI 只接受一个来自 successful run、未过期的
  merged-unsigned artifact；它会拒绝含糊 feed 路径和顶层 symlink。若 prior artifact 重复
  target-runtime IPK，CI 保留新恢复的权威 target base，而不导入或比较这个 target-derived 容器副本；
  仅把不存在的 source-built IPK hydrate 到私有 candidate 后封装 profile。这样可以验证 profile
  dependency closure，而不重新编译历史 source package。GitHub Actions
  [run `33987100478`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987100478)
  已在成功的 merged run `33985545990` 上实际执行此规则：水合 276 个已验证 IPK，保留新恢复的
  target-runtime 重复容器，并且只构建 `tdvp-diagnostics_1.1-1_riscv64.ipk`。它上传 unsigned batch artifact
  [`9975532821`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987100478/artifacts/9975532821)
  （196,004,873 bytes）；没有重新构建任何历史 source package。随后的 24-batch 无重编 merge，
  [run `33987408229`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229)，
  已跳过 SDK/package-build job、比较输入 IPK hash、重建索引，并通过 runtime closure 与 target-runtime
  coverage。它上传 merged unsigned artifact
  [`9975645724`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229/artifacts/9975645724)
  （195,991,913 bytes）。两个 artifact 均未签名、发布、部署或安装到设备，也没有实机生命周期证据；
- 纯元数据诊断 profile：`tdvp-diagnostics` 仅包含仓库自有说明文档及精确的
  `strace`/`htop`/`lsof`/`iperf3`/`netcat` 依赖元数据，因此具有狭窄 source-lock 豁免；它不拥有
  可执行文件、共享库、SDK 制品或任何固件路径；
- rsync 的 target-attested 依赖：immutable catalogue 以 `libpopt (= 1.19-1)`、
  `libz (= 1.3.1-1)`、`libcrypto-3 (= 3.4.1-1)` 唯一拥有 `libpopt.so.0` / `libz.so.1` /
  `libcrypto.so.3`。匹配 SDK 会恢复锁定 Buildroot rsync transaction 的 OpenSSL 分支，因此 rsync 只消费
  该精确 crypto ABI，不会尝试关闭全局 Kconfig 或重建/替换这些 runtime。它锁定 rsync 3.4.1、popt、zlib、
  OpenSSL、host-pkgconf 及审查过的 Buildroot autoreconf patch；远程 shell 刻意不作为 OpenSSH 包依赖：默认
  使用 platform `ssh`，或由用户通过 `-e /usr/bin/tdvp-ssh` 显式选择传输命令。它明确关闭 ACL、LZ4、xxHash
  和 Zstd。配方会拒绝变化的 Buildroot patch 和缺少 zlib 的 candidate SDK。首次 remote audit，
  [run `33983507607`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983507607)，已正确 defer
  这三个 target provider，但旧配方断言 Buildroot 禁用 OpenSSL，故在上传 artifact 前停止。修正后的精确
  libcrypto revision 在 [run `33983785585`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585)
  成功，并上传 unsigned batch artifact
  [`9974581047`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585/artifacts/9974581047)
  （90,386,375 bytes）。无重编 22-batch merge，
  [run `33984054059`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059)，比较每个输入
  IPK hash、重新索引并验证 closure/base-overlay，上传 merged unsigned artifact
  [`9974652475`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059/artifacts/9974652475)
  （195,190,117 bytes）。两个 artifact 均未签名、未 release/publish、未部署或安装到设备，也没有实机生命周期
  证据；仍需记录匹配 K230 SDK 的实机生命周期验证；
- SQL 数据库运行时：`libsqlite3-0` 锁定 Buildroot 2025.02.1 审查的 SQLite 3.48.0
  归档，只将 `libsqlite3.so.0 -> libsqlite3.so.0.8.6` 制作成独立 IPK。已完成校验过的
  离线源码构建和候选审计，因此它是 CPython `_sqlite3` 及后续数据库 client 的唯一可复用
  provider。该 RISC-V ELF 无 RPATH/RUNPATH，并精确声明 `libz` provider；library IPK
  刻意排除 `sqlite3` CLI、开发头文件、静态库和 staging metadata。独立 `sqlite3` leaf
  只接受同一私有 Buildroot transaction stage 的 RISC-V CLI，并精确依赖
  `libsqlite3-0`、`libreadline` 与 `libncursesw`；它不从 firmware、Debian 或 target root
  复制命令；
- 任意精度计算命令：`bc` 锁定 GNU bc 1.07.1 与构建它所需的 host-flex 2.6.4/host-m4
  1.4.19 archive。二者只是私有 Buildroot host 输入，不进入 target IPK；GNU bc 的 RISC-V
  ELF 仅可通过 `/usr/bin/tdvp-bc` 访问，因而绝不替换 firmware `/usr/bin/bc`；
- 窄系统维护命令：`util-linux-tools` 锁定 Buildroot 2025.02.1 审核的 util-linux
  2.40.2 archive，只以私有 Buildroot transaction 选择明确的 cal、fallocate、IPC、
  last/utmp、scheduler 与 namespace 前端，并在本次 make 调用中关闭
  NLS。它不启用 util-linux basic set、挂载/分区/文件系统/loop/wipefs/login 等 feature，
  私有 configure 也不构建 liblastlog2/libblkid/libfdisk/libmount/libsmartcols/libuuid；desktop baseline
  的 systemd select 不会被篡改，而是由私有 make 调用完整覆写 `UTIL_LINUX_CONF_OPTS`，先关闭
  全部 programs 和未拥有库、再只开启候选命令，因此不产生新的共享运行时
  provider，也不把 target root 现有库当作隐式 ABI。所有 ELF 都在
  `/usr/libexec/tdvp-util-linux/`，公开入口均是
  `/usr/bin/tdvp-util-linux-<command>`，不会覆盖 firmware 或 BusyBox 路径。候选
  CI 只构建、封装和审计，绝不执行可能改变 IPC、进程、namespace、文件或 terminal
  state 的命令；
- exFAT 文件系统维护：`exfatprogs` 锁定 Buildroot 2025.02.1 审核的 1.2.5 archive，
  仅从私有 Buildroot transaction 提取 `mkfs.exfat`、`fsck.exfat`、`dump.exfat`、
  `exfat2img`、`tune.exfat` 与 `exfatlabel` 六个 RISC-V ELF。即使 Buildroot 临时安装
  使用 `/usr/sbin`，最终 IPK 也只拥有 `/usr/libexec/tdvp-exfatprogs/` 和明确的
  `/usr/bin/tdvp-exfat-*` wrapper，因此不覆盖 firmware/BusyBox 路径、不复制 Debian
  binary 或 target root 文件，也不把共享库当作隐式 provider。GitHub Actions 必须在
  source lock、RPATH/RUNPATH、runtime closure 与 base-overlay gate 全部通过后才上传
  unsigned candidate；CI 永不运行会创建、修复、调优、标签或写入镜像的文件系统命令；
- 内存诊断：`memtester` 锁定 Buildroot 2025.02.1 审核的 4.5.1 archive；因原始
  HTTP 端点不构成可审核的 HTTPS fetch 输入，source lock 使用 Buildroot HTTPS archive
  mirror，但仍以该 Buildroot recipe 的 SHA-256 验证同一个 archive。唯一 RISC-V ELF
  只位于 `/usr/libexec/tdvp-memtester/`，公开入口仅为 `/usr/bin/tdvp-memtester`，
  不覆盖 firmware/BusyBox 路径，不复制 Debian binary、target root 文件或共享库。
  GitHub Actions 只构建、封装和审核，绝不执行会分配和写入设备内存的诊断程序；
- YAML C 运行时 ABI：`libyaml-0.so.2` 已由固定 K230 target runtime 提供。Actions retry
  `33973838867` 在真正 source build 前确认了这一点并 fail-closed，因而它不属于 source-lock
  migration candidate；未来 consumer 只能复用 target catalogue 的精确 provider，不能私藏 parser
  或重复编译相同 SONAME；
- 十进制运算运行时：`libmpdec-4` 锁定 Buildroot 2025.02.1 审查的 mpdecimal 4.0.0
  归档，只将 `libmpdec.so.4 -> libmpdec.so.4.0.0` 制作成独立 IPK。候选为 RISC-V ELF64
  共享对象、无 RPATH/RUNPATH，且仅依赖平台 ABI，因此它是 CPython `_decimal` 的唯一可复用
  provider；C++ ABI、开发头文件、pkg-config 数据、文档及 staging 文件均被明确排除；
- CPython 语言运行时拆分：`libpython3.13`、`python3-runtime` 与 `python3` 锁定同一个
  Buildroot 2025.02.1 选定并给出哈希的 CPython 3.13.3 release archive，但 feed 直接用
  匹配 SDK/sysroot 交叉构建，绝不启用 Buildroot 的 Python package，也不复制其 target root。
  三个包分别拥有公共 `libpython3.13` ABI、标准库/原生扩展，以及仅命令 frontend。recipe
  要求复用已独立拥有的 OpenSSL、libffi、mpdecimal、SQLite、压缩库、ncurses/readline、zlib
  与 Expat provider；`pyexpat` 会验证动态依赖 `libexpat.so.1`，而 `_elementtree` 使用
  CPython 的 pyexpat C-API hook。私有 Expat、`_curses_panel`/未准入的 `libpanelw`、IDLE、
  pydoc、tkinter、ensurepip、静态/开发文件与构建 metadata 均明确排除；拆分边界及仍需完成的
  release gate 见 [`packages/python3/README.md`](../packages/python3/README.md)；
- Node.js provider 基础：`libcares`、`libuv` 与 `libnghttp2` 分别锁定官方源码归档并直接
  交叉构建，分别成为唯一的 `libcares.so.2`、`libuv.so.1`、`libnghttp2.so.14` provider；
  三个候选 RISC-V IPK 已审计无 RPATH/RUNPATH，且只具有平台 ABI 闭包。`libuv` 锁定为 1.51.0，
  因为 Node 22.23.2 使用其公开的 `UV_TTY_MODE_RAW_VT` API；仅 SONAME 相同不足以证明 build-time
  API contract 有效。`libicudata`、
  `libicuuc`、`libicui18n` 与 `libicuio` 也锁定 ICU 73.2 归档；由于 ICU 需要 host/target
  双阶段构建，目前仅通过私有离线下载目录调用已审查的 Buildroot recipe，再拆分四个公共
  SONAME。四个候选 IPK 已验证为 RISC-V ELF64，并精确声明 ICU 与 `libatomic-1` 依赖。
  `libnode`、`node`、`npm-runtime`、`npm` 锁定同一份 Node 22.23.2 release archive，并都记录
  已审查的 `patches/node22-lazy-bz2-import.patch` 哈希。该补丁把 Node 的 `bz2` 导入移进
  内置 ICU 数据解压分支；feed 选择 `--with-intl=system-icu`，因此它既不改变选定源码，也不
  绕过 ICU，只避免 SDK 原本可用于 GYP 的 Python 3.13 因未使用的 `_bz2` 扩展而无法配置。
  它还把 target shared-library flags 限定在非 host 的 GYP toolset，使 native V8 generator
  不会尝试链接 RISC-V 库，而 target 仍会得到完整且显式的闭包。host toolset 改为使用同一
  锁定 Buildroot ICU transaction 产生的 x86_64 ICU 73.2；它只是构建工具输入，绝不打包或
  拷贝到设备。host toolset 还只为 native generator 从同一份锁定的 Node release archive 构建
  x86_64 静态 libuv；该静态库及其 headers 都是 host-only 输入，绝不是 target provider，也
  绝不会进入 IPK payload。锁文件记录的 host 输入还要求供 V8 generator 使用的 native GCC/G++ 10+、SDK
  Python 3.8+ 与已审查的 QEMU action wrapper。Node 构建器要求三个网络 provider 带直接源码 staging
  标记，并从本次 release staging sysroot 链接它们，绝不使用预编译 Node 二进制或再次复制
  Buildroot target。完整 Node candidate 与 target 生命周期记录仍是提升前的 release gate；
- 匹配 target 导出的编译器运行时：`libatomic-1`，唯一非 profile 的
  `SOURCE_LOCK_EXEMPT_REASON`。它只转移已完成、匹配的 target 中
  `libatomic.so.1 -> libatomic.so.1.2.0`；recipe 会核验锁定的 Xuantie GCC 14.1.1
  身份、target 配置、SHA-256、SONAME、ELF ABI、无 RPATH、符号链接目标，以及最终对
  基础目标的逐字节一致覆盖。它为非 ABI SONAME 建立唯一 feed owner，并不替换 glibc、
  动态加载器、`libgcc_s` 或任何 ABI seed；
- 归档命令组：`archive-tools`，锁定 tar、gzip、bzip2、xz、zstd、zip、unzip、
  Debian unzip patch archive 和 p7zip 输入；
- 已迁移的纯 Vimscript runtime plugins：`vim-plugin-commentary`、
  `vim-plugin-repeat`、`vim-plugin-sleuth`、`vim-plugin-surround`、
  `vim-plugin-gitgutter`。

“可离线审计”仅表示来源、交叉构建和包闭包门已可执行；它不替代每个 release 的完整
target 安装/卸载、功能测试、签名与发布证据。

## 明确豁免

`tdvp-source-tools`、`tdvp-dev-tools` 和 `tdvp-nodejs-tools` 只安装本仓库拥有的 README
或精确依赖元数据，不下载、不打包第三方源码。它们使用
`SOURCE_LOCK_EXEMPT_REASON` 记录这个窄豁免。profile 的每个第三方依赖仍必须各自拥有
来源锁；profile 豁免绝不能传递给 `git`、`node`、`vim` 或其它实际导入上游源码的包。

`libatomic-1` 是唯一的另一项豁免。与 profile 不同，它包含运行时对象；但它是共享运行时
合同下受约束的所有权转移：不复制任意或外来预编译二进制，只能逐字节复制已声明的匹配
平台 target 导出的 `libatomic.so.1.2.0`。工具链、配置、哈希、SONAME、ELF ABI、模式或
符号链接只要有一项改变，构建都会失败。它不为其它编译器运行时或 target rootfs 文件建立
通用豁免。

## 下一批高价值源码组

Node.js 和多媒体/桌面图已经不属于“待迁移的历史 recipe”：它们的 r10 source batch 已进入成功的
24-batch unsigned merge。它们剩余的是实机生命周期验证，不是再次 source build。

下表单独记录 post-merge 扩展，防止把“已准备 recipe”误写为“已准入 candidate”。每项仍必须先通过
GitHub Actions source batch，再通过无重编 merge，才可获得 candidate 证据。

| 批次 | package | 先决条件与原因 |
| --- | --- | --- |
| 调试/网络诊断 | `gdbserver`、`ethtool` | GitHub Actions source batch [`33988534267`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267) 已用锁定的 Buildroot 2025.02.1 来源及私有 TDVP 前端通过；25-batch no-recompile merge [`33988940718`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718) 随后准入这两个已验证 IPK。`gdbserver` 保持 server-only，未修改 SDK host `debug-root`；`ethtool` 保持 no-netlink/no-libmnl 边界。CI 未启动 server 或修改网络接口；仍需要实机生命周期验证。 |
| I2C 硬件检查 | `i2c-tools` | GitHub Actions source batch [`33989899026`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026) 已通过经审查的 static-only leaf：禁用 Python/py-smbus，五个命令链接私有 `libi2c.a`，并且既不封装 `libi2c.a` 也不封装 `libi2c.so`。26-artifact no-recompile merge [`33990178543`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543) 随后准入该 IPK。CI 未探测或写入任何总线；仍需要实机生命周期验证。 |
| 文件系统事件检查 | `inotify-tools` | GitHub Actions source batch [`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904) 已通过经审查的私有 command leaf：已禁用 shared output、把私有 `libinotifytools` implementation 链接进 `inotifywait`/`inotifywatch`，并且没有封装 `libinotifytools` 或头文件。27-artifact no-recompile merge [`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095) 随后准入该 IPK。CI 未启动 watcher 或观察路径；仍需要实机生命周期验证。 |
| 日志维护 | `logrotate` | GitHub Actions source batch [`33991963284`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991963284) 已通过经审查的 command-only leaf：精确复用 immutable target `libpopt` provider，禁用 SELinux/ACL，只封装私有 `logrotate` ELF 与 `tdvp-logrotate` frontend。不包含 `/etc/logrotate.conf`、`/etc/logrotate.d`、timer 或 daemon。28-artifact no-recompile merge [`33992249214`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992249214) 随后准入该 IPK。CI 未执行它或轮转日志；仍需要实机生命周期验证。 |
| JSON 构造 | `jo` | GitHub Actions source batch [`33992855036`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992855036) 已通过经审查的独立 command leaf：只封装私有 `jo` 与 `tdvp-jo` frontend，不引入 shared-runtime provider。29-artifact no-recompile merge [`33993109744`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993109744) 随后准入该 IPK。CI 未执行它或传入 JSON input；仍需要实机生命周期验证。 |
| 行编辑 | `ed` | GitHub Actions source batch [`33993563150`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993563150) 已通过经审查的 GNU command leaf：runner-only host-lzip 解包锁定 archive，随后只封装私有 `ed` 与 `tdvp-ed` frontend，不引入 shared provider。30-artifact no-recompile merge [`33993808518`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993808518) 随后准入已验证 IPK；CI 未执行它或传入文件。 |
| archive 交换 | `cpio` | GitHub Actions source batch [`33994423195`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33994423195) 已通过经审查的 GNU command leaf：其 glibc/wchar K230 profile 不选择仅用于 musl/uClibc 的 argp-standalone branch，随后只封装私有 `cpio` 与 `tdvp-cpio` frontend，不引入 shared provider。31-artifact no-recompile merge [`33994729377`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33994729377) 随后准入已验证 IPK；CI 未执行它、传入 archive 或 filesystem path。 |
| 进程计时 | `time` | GitHub Actions source batch [`33995251958`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33995251958) 已通过经审查的 GNU command leaf：K230 的 MMU/dynamic-library/BusyBox-show-others profile 满足上游条件，随后只封装私有 `time` 与 `tdvp-time` frontend，不引入 shared provider。32-artifact no-recompile merge [`33995532939`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33995532939) 随后准入已验证 IPK；CI 未执行它或为其启动被计时的子命令。 |
| CPU 限制 | `cpulimit` | GitHub Actions source batch [`33996029211`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33996029211) 已通过经审查的私有 command leaf，不引入 shared provider；成功 source artifact 正待无重编 merge。CI 未执行它、传入 PID/进程名、启动进程或节流进程。 |
| Socket relay（延后） | `socat` | 不得准入 Buildroot 2025.02.1 锁定的 1.8.0.2 archive：上游 HTTPS 端点在受审信任链中呈现自签名证书，且 [NVD CVE-2026-56123](https://nvd.nist.gov/vuln/detail/CVE-2026-56123) 将低于 1.8.1.2 的版本列为受影响。重新考虑前须有可验证的上游 HTTPS artifact、经审查的较新 Buildroot source input，以及独立的 no-OpenSSL/no-readline closure。 |
| 原生构建前端 | target CMake/Ninja | CMake 会带来较宽的 `libarchive`/`libuv`/JSON/rhash closure，必须先准入每个新 provider；Buildroot 的 Ninja 是 host-only，target-Ninja 需要单独锁定 bootstrap 设计。 |

## 提升规则

本台账的“已迁移”不等于可发布。一个批次只有在以下全部完成后，才允许进入具体 release
candidate：每个导入源码的 package 已锁定来源和补丁；source cache 离线重建成功；每个
非平台 SONAME 有唯一 provider；IPK 无受保护路径或 RPATH/RUNPATH；在完整匹配 K230
target 上完成安装、核心功能、卸载和回滚测试；最后才是签名和不可变 release。
