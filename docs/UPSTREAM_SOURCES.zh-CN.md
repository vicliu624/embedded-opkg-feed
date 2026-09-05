# 上游源码准入与可复现打包约定

[中文（当前）](UPSTREAM_SOURCES.zh-CN.md) | [English](UPSTREAM_SOURCES.md)

## 目的与边界

TDVP feed 把 Debian、Buildroot 和项目各自的上游发布页/源码仓库当作**上游源码候选池**。它们可以提供版本、补丁、构建知识和安全更新线索，但它们不是此设备可以直接追加的二进制软件源。

最终发布到本仓库的每一个 IPK 都必须由维护者选定的源码、精确 TDVP 平台 SDK/sysroot 和受审查的 recipe 重新构建；通过准入、可复现、ABI 与实机验证后，才会进入一个已签名的不可变 `rN` release。此规则同时适用于从 Debian source package、Buildroot package recipe、Git tag/commit、release tarball 或其他公开上游引入的软件。

```text
Debian source / Buildroot recipe / upstream source release
                         |
                         v
              source.lock + reviewed patches
                         |
                         v
       TDVP pinned SDK/sysroot + package build.sh
                         |
                         v
      staged target payload -> IPK -> ABI/runtime checks
                         |
                         v
    target functional test -> offline signature -> immutable rN -> stable
```

这是一项**选择性导入**策略，不是把任何发行版的全部软件包镜像到 IPK，也不是建设一个可替代 Debian 的通用 RISC-V 发行版。新增包应解决明确的 TDVP 用户态需求，并且其长期维护成本、许可证、资源占用和安全更新路径都必须可接受。

## 绝不直接复用的内容

以下做法不被允许：

- 在设备端给 Buildroot/opkg 系统直接添加 Debian、Debian Ports、OpenWrt 或任意通用 `riscv64` 二进制软件源；
- 下载 `.deb`，或使用 `dpkg-buildpackage`、`alien`、`ar` 解包等方式把上游二进制“转换”为 `.ipk`；
- 把一个面向其他 glibc、动态加载器、CPU 扩展、内核或桌面栈构建的预编译 RISC-V 二进制放入 `root/`；
- 以滚动分支、未校验的下载、构建时临时 `apt install`、未锁定的工具或预编译 host 工具作为发布输入；
- 因一个应用需要库或命令，就修改平台 ABI 清单、内核、设备树、boot chain 或基础固件。

特别是，下面这些属于固件/平台 ABI 的责任，不能由普通 feed package 引入、替换或通过 `opkg upgrade` 更新：动态加载器、glibc ABI seed（包括 `libc`、`libdl`、`libm`、`libpthread`、`librt`、`libutil`、`libresolv`）、`libgcc_s`、`libstdc++`、内核、内核模块、设备树、驱动、固件 blob、启动链、init/system manager、`opkg`、信任根和平台 ABI 标记。它们变化时必须创建新的平台基线和兼容性契约，而不是发布一个普通 IPK。共享运行时的精确边界和所有权要求见[共享运行时包约定](SHARED_RUNTIMES.zh-CN.md)。

## 允许作为候选池的输入

### Debian

只使用**源包**作为候选输入：`.dsc`、上游 `orig` tarball、Debian 维护补丁 tarball/patch series 及其公开元数据。维护者可以借鉴 Debian 的依赖、补丁和安全修复，但必须在 TDVP 构建脚本中重新适配、交叉编译和测试。

首选不可变来源，例如明确版本的 Debian source archive；需要按历史时间点重建时，记录精确 snapshot URL。`apt` binary repository 及其 `.deb` 只可用作人工研究材料，不能成为 feed 的构建输入或运行时依赖。

### Buildroot

可以复用 Buildroot package 的版本、hash、补丁、`Config.in`/`.mk` 中的构建知识或其声明的上游源码，但不直接把 Buildroot target rootfs 中的文件任意搬进新的包。只有遵守共享运行时所有权约定的、从已验证 target 字节一致提取的 `runtime` provider 才是例外；它是所有权接管，绝不是覆盖或升级基础镜像。

这个例外比普通二进制复用严格得多：recipe 必须证明使用的是精确匹配的平台 output、
生产者/工具链身份、文件 SHA-256、ELF ABI 与 SONAME、文件模式、符号链接目标以及最终对
基础镜像的逐字节一致覆盖。其 `SOURCE_LOCK_EXEMPT_REASON` 仅记录“没有导入第三方源码或
外来二进制”这一事实；不能借此任意搬运 target rootfs 文件、其它编译器运行时或已改变的
工具链产物。

对于 `buildroot-derived` 命令包，feed 会先把 `source.lock` 声明的**全部**已校验归档从 TDVP source cache 复制到每次构建专有的临时下载目录，再以该目录作为 `BR2_DL_DIR`，并把 Buildroot 限定为只可访问这个本地 primary site。这里既包括 target 源码，也包括该精确构建路径触发的 Buildroot host helper（例如解压 `.tar.lz` 所需的 host `lzip`）；后者不是“构建机自带工具”的隐式豁免，必须有自身的 URL、文件名和 SHA-256，写入同一 recipe 的来源锁。Buildroot recipe 的文件名或哈希与锁不一致、或它试图回退到网络时，构建必须失败。构建事务只会临时修改 SDK output 的配置；结束时按字节恢复原有 `.config` 和已有的 `.config.old`，绝不以 `olddefconfig`“规范化”维护者原有配置。

### staging 是构建接口，不是上游二进制来源

`TDVP_FEED_STAGING_ROOT` 是单次 feed candidate 的临时开发 sysroot。普通可复用库必须先
从其自身 `source.lock` 所声明的精确归档完成交叉编译，才可将头文件、pkg-config metadata、
链接用符号链接和产出的目标库提供给已声明的构建依赖；其 IPK 仍只能包含经过审查、属于自身
SONAME family 的运行时载荷。

确实需要 Buildroot host/target 机制的包（例如经过审查的 ICU 式双阶段构建）必须从私有离线
下载目录中的锁定归档构建，并在 `source.lock` 中说明这一 builder 例外。它可以把这次新鲜
install 的结果加入 staging，但绝不能从 SDK 既有 target rootfs 取替代副本。消费者必须拒绝
缺失或不匹配的 staging marker，不能静默回退到固件库。当前 Node.js provider chain 同时演示
这两条路径；其尚未完成的实机发布门记录在迁移台账中。

### 仅缓存的本地 Git 输入

TDVP 自有或尚未公开的 Git commit 只能作为例外的**候选源码**，不是二进制来源的替代品。只有
在经过审查的本地 checkout 中确实存在该精确 commit、用 `git archive` 生成一个写入受控 source
cache 的哈希锁定归档，并由 recipe 的 `source.lock` 记录该归档、commit、文件名和 SHA-256 时，
它才可准入。release build 必须消费这一 cache 制品，缺失即失败；不得改抓另一个公开 snapshot、
可变分支或任意工作树。这个例外仍可供未来真正未公开的输入使用。`tdvp-gba` 曾被记录为
这一例外，但其锁定的 `4c82b09e1bf042d0709c26ed6c4e5098a283a908` commit 与精确 HTTPS
archive 现已可公开取得且受哈希锁定，因此 r10 将它作为普通的受控 GitHub cache seed，而不再
视为仅缓存输入。

`--offline-source-cache` 还会禁用历史 `REUSE_IPK_URL` 载荷复用。在该模式下，选中的 recipe
只能从已验证的 source cache 重建，或由经过审查的非源码豁免明确拒绝/说明；先前 feed 的 IPK
绝不能静默成为构建输入。

Go 这类会在构建时解析大量模块的上游还必须锁定模块闭包。主源码的 `go.mod`/原始
`go.sum`、受审查 host Go 工具、模块解析后产生的 `go.sum`、`vendor/modules.txt` 和确定性
vendor archive 都是可审查输入。网络仅可用于受哈希约束的 cache seed；最终 target 编译必须
以空 module cache、`GOPROXY=off`、`GOSUMDB=off` 和 `-mod=vendor` 运行。host Go 工具仅是
构建工具，不是 target ABI provider，也不能进入任何 IPK。

维护者应在受控网络阶段显式预热，而不是让正式离线 release 临时解析模块：

```sh
bash ./scripts/prepare-go-module-vendor-cache.sh \
  --package-dir packages/gh --cache .tdvp-source-cache
```

该命令只准备经过锁定的源码和 host-side vendor cache，不生成 IPK 或目标二进制。之后 release
构建以 `--offline-source-cache` 运行；缺少 bundle 或哈希不匹配必须失败。

### 其他上游

Git tag/commit、官方 release tarball、PyPI/crates.io 等公开源码来源也可以准入。选择必须以可重新获取的不可变版本和可验证哈希为基础；维护者不能只记录一个会改变内容的分支名或下载首页。

## 每个引入包的来源记录

从本约定生效后，新增的第三方/上游源码包，以及更新了上游来源、版本或补丁的既有包，必须在 `packages/<name>/source.lock` 提交一份可审查的来源记录。只修改本仓库自有文档或纯数据且不获取第三方源码的包，应在 PR 中说明其不适用原因。

后一类例外还必须在其 `package.env` 中写入非空的 `SOURCE_LOCK_EXEMPT_REASON='…'`。CI 只把这个字段视为“没有导入第三方源码”的显式声明；它不能用来豁免 `.deb` 转换、预编译二进制、未锁定下载，或一个本应有上游来源记录的 recipe。唯一的附加用途是前述已文档化的、匹配 target 的 `runtime` 所有权转移；其 recipe 与 package gate 必须实际执行逐字节一致性检查。

`source.lock` 是人工可读、将来也应被脚本解析的键值记录。它至少应包含：

- 来源类型（例如 `debian-source`、`buildroot-derived`、`git`、`release-tarball`）、上游项目和许可证；
- 不可变版本、Git commit 或发行 tarball 版本；`git` 与 `buildroot-derived` 必须记录完整 40 位 lowercase commit SHA，不能只写分支名或可移动 tag；
- 每个下载产物的完整 URL、文件名和 SHA-256；Debian source package 要分别记录 `.dsc`、`orig`、Debian tarball 及使用的 patch series；
- 适用的 snapshot 时间点或仓库 revision，以及为什么选择该来源；
- feed 自有 patch 的文件名、顺序、SHA-256 和必要性说明；
- 任何非可执行的本地构建输入（例如 Go module lock）的文件名、SHA-256 和必要性说明；
- 重新构建所需的非平台构建输入，以及已知的安全公告/CVE 处理状态；
- 维护者核验日期或对应 PR，不把可变网页文本当作唯一证据。

可从 [模板中的 `source.lock.example`](../packages/_template/source.lock.example) 开始。该记录描述**源码供应链**；`package.env` 继续描述目标 IPK 的名称、版本、支持平台和运行时关系，二者不能互相替代。

历史 recipe 的已迁移范围、纯 TDVP profile 的窄豁免和下一批待迁移源码组见
[来源锁迁移台账](SOURCE_LOCK_MIGRATION.zh-CN.md)。它是审计清单，不会把尚未通过完整
准入的历史 `rN` 标签误写成新的 candidate 证明。

现有已发布 `rN` 保持不可变，不追溯改写其历史制品。旧 recipe 在其下一次上游更新、重大重构或新 release 中应补齐这份记录；维护者也可单独开一次只补来源记录的审计 PR。

## 准入判断

维护者应按以下顺序判断，而不是从“上游是否有 RISC-V 包”倒推：

1. **功能归属：** 它是可选用户态应用、工具、共享运行时或数据，还是平台/BSP 组件？后者拒绝或转入固件项目。
2. **来源可审查：** 能否取得相应源码、补丁、许可证和不可变哈希？无法取得或无法再分发的候选项拒绝。
3. **平台可构建：** 能否只使用目标平台锁定的 SDK/sysroot 构建？若要求替换 ABI seed、私有 host tool 或不同目标 libc，则拒绝或先建设新平台基线。
4. **运行时可拥有：** 每个非 ABI 动态 SONAME、插件、通过 `exec` 调用的工具和运行时数据，是否有唯一且精确版本的 IPK provider/`Depends`？不能依赖基础 rootfs 的隐式副本。
5. **资源与维护：** 存储、内存、启动时间、网络和特权需求在 K230 上是否可接受？是否有人负责版本和安全更新？
6. **验证：** 是否能通过 source/hash、交叉构建、载荷/ELF/SONAME 闭包、安装卸载以及目标机功能测试？不能只因成功生成 IPK 就准入。

共享库和 `runtime` provider 还必须通过 [共享运行时包约定](SHARED_RUNTIMES.zh-CN.md) 的字节一致性、唯一 SONAME 所有者和 ABI 闭包检查。普通 leaf application 应优先作为第一批试点，因为它们的 ABI 风险较低；一个新通用库必须先证明可复用性和维护价值，不能只为绕过静态链接限制而引入。

## 构建与依赖规则

### 增量 feed 构建与 CI

新增一个库时，feed **不会**把所有源码 recipe 重编一次。CI 将不可变输入分成三层：

1. **SDK/ABI 基座**以审阅过的 K230 固件 revision、profile 与平台缓存版本为键。只有平台身份改变才重建；库源码变更不会使它失效。
2. **目标运行时 IPK 基座**对每个 SDK/ABI 基座仅执行一次：把已完成 target 的运行时转换成普通 feed IPK。它的私有所有权映射只保存在缓存中，绝不与公开 `Packages` 索引一起发布。
3. **包批次**恢复前两层，只编译显式选择的 recipe 以及其声明的源码构建/运行时依赖闭包。源码缓存以 `source.lock` 中锁定的 SHA-256 为地址。

一个增量批次只是未签名的局部候选。后续合并门会记录平台身份、来源锁、recipe/patch revision、依赖元数据和 IPK SHA-256；它校验每个声明归档的 SHA-256，拒绝同名但哈希不同的 IPK，重新生成最终索引，并以恢复的 SDK target 做双向运行时闭包验证。它不能替换 IPK，更不能暗中触发全量重编。包批次遇到基座缓存缺失必须硬失败，CI 应显式运行基座任务，而不是把平台重建藏在某个库任务里。

`build.sh` 只能以选定平台锁定的 `TDVP_SDK_ROOT`、`TDVP_FEED_BASE_ROOT` 和临时 `TDVP_FEED_STAGING_ROOT` 为目标构建环境。构建依赖通过 `PACKAGE_BUILD_DEPENDS` 提供给 staging；设备上的运行时关系必须通过精确版本的 `PACKAGE_DEPENDS` 和 ELF 自动闭包写入 IPK。构建依赖绝不因为在编译机上存在，就自动成为设备上可用的库或命令。

不要将 upstream 的 Debian packaging 规则或 Buildroot `.mk` 文件直接当作本仓库的构建脚本执行。可以在 reviewed `build.sh` 中移植其必要逻辑，但每一处 TDVP patch、feature 开关和依赖裁剪都必须可审查，并反映在 `source.lock` 和包 README 中。网络下载应位于可哈希、可缓存的受控获取阶段；发布构建本身应能从已验证的 source cache 重跑。

常用的本地流程如下；所有脚本用 `bash` 调用，以免依赖工作树中的可执行位：

```sh
# 审核仓库中已有的来源记录
bash ./scripts/verify-source-lock.sh --repo-root . --all

# 只取得并校验一个 recipe 的来源；缓存以 SHA-256 和文件名组织
bash ./scripts/fetch-source-cache.sh \
  --cache /srv/tdvp-source-cache \
  --package-dir packages/<package>

# 仅当旧构建机缺少上游 HTTPS 站点的可信根时，显式使用经过主机/IT 管理的 PEM bundle。
# 它不会关闭 TLS 校验，不能以 --insecure 或 HTTP 替代。
bash ./scripts/fetch-source-cache.sh \
  --cache /srv/tdvp-source-cache \
  --package-dir packages/<package> \
  --ca-bundle /etc/ssl/tdvp-controlled-roots.pem

# 在受控缓存已经准备好后，禁止 release build 访问网络
TDVP_SDK_ROOT=/path/to/output/host \
TDVP_FEED_BASE_ROOT=/path/to/output/target \
bash ./scripts/build-all.sh --platform tdvp-k230-r1 --release rN \
  --source-cache /srv/tdvp-source-cache --offline-source-cache --output dist
```

没有显式给出 `--source-cache` 时，`build-all.sh` 使用仓库下被 Git 忽略的 `.tdvp-source-cache/`。该目录是构建缓存，不是发布制品，不能提交到 feed 或作为来源锁定的替代品。

`--ca-bundle` 是针对停止维护的构建主机或企业信任链的**窄主机侧修复**，不是上游来源切换
开关。它只接受普通、非符号链接且含 PEM certificate 的文件，并交给 curl 的 `--cacert`；TLS
证书与主机名校验仍然开启，脚本不提供 `--insecure`。优先更新构建机的系统 CA 库；确有例外时，
由受控主机配置提供完整、经过审查的 bundle（`--cacert` 会取代 curl 的默认 bundle）。无论使用
哪种信任链，缓存仅在下载物的 SHA-256 与 `source.lock` 完全一致时才写入。不得因旧 CA 缺根而
把同版本切换到内容不同的 Git tag snapshot、HTTP 镜像或未锁定下载。

## 发布门与证据

一个候选包在首次发布和之后每次上游更新时，至少需要以下证据：

| 门 | 必需证据 |
| --- | --- |
| 来源 | 完整 `source.lock`、哈希匹配、许可证/再分发核验、补丁审查 |
| 构建 | 匹配平台 SDK/sysroot、可重跑的 recipe、没有未锁定下载或 host target 污染 |
| 包 | 正确架构、精确 `tdvp-platform-abi` 依赖、无受保护路径覆盖 |
| 运行时 | 唯一 SONAME provider、精确动态/显式命令依赖、无 RPATH/RUNPATH 或私有通用库副本 |
| 设备 | 安装、启动/核心功能、卸载和失败/回滚测试，必要时含性能与内存记录 |
| 发布 | 通过 feed 校验、离线签名、作为新不可变 `rN` snapshot 发布后才可提升 `stable` |

仓库会自动解析已提交的 `source.lock`（不执行其中内容）、检查不可变 revision/URL/哈希/补丁，并把每个源码产物放入内容寻址的 HTTPS source cache 后再次校验 SHA-256。CI 对新增或修改的 package recipe 强制要求 `source.lock` 或明确的豁免原因；`build-all.sh --offline-source-cache` 可证明构建不再依赖网络。平台 ABI、包元数据、运行时所有权/闭包、索引和签名也继续自动检查。构建证明和 SBOM/provenance 输出仍是后续工作；许可证、补丁意义和安全公告判断仍必须由维护者审查，不能因为已经有自动化而跳过。

## 更新与安全维护

Debian、Buildroot 或上游发布的新版和安全公告会产生**候选更新**，不会自动进入设备。维护者应比较影响、更新 `source.lock`、重新应用/审查补丁、使用相同 TDVP 平台重新构建并完成全部门检。通过后发布新的 `rN`；旧 snapshot 不重写，`stable` 只通过既定提升流程改变。

当候选修复需要新的 libc、动态加载器、内核/驱动、桌面 ABI 或其他平台 ABI seed 时，停止该 feed 更新并转交给基础固件/新平台基线工作，而不是尝试把它伪装成 IPK 依赖。

## 分阶段落地

这份文档先固定治理规则。自动化实现按以下顺序推进：

1. 已完成：为新 recipe 引入可审查的 `source.lock`，以低风险纯 Vimscript package 作为试点；
2. 已完成：增加 HTTPS 内容寻址 source cache、SHA-256 校验和 offline 模式；
3. 已完成：在构建脚本和 CI 中解析 `source.lock`，拒绝不完整、可变或哈希不匹配的来源；
4. 已完成：把现有 Buildroot-derived `make`、`diffutils`、`pkgconf`、`strace` 与 `patch` 迁移到锁定 source cache；以私有离线 `BR2_DL_DIR` 重建验证 `diffutils`、`patch`、`htop`、`nano`、拆分的 `vim-runtime`/`vim`、自包含的 `ca-certificates`、`libexpat-1`、拆分的 `libcrypto-3`/`libssl-3`、带有锁定来源闭包的 `libcurl-4`，以及已通过来源准入、将从同一次 Buildroot 事务白名单 stage 后独立封装的 `curl` recipe、只复用 OpenSSL/zlib 的 `wget` recipe、明确关闭可选 OpenSSL 认证的 `iperf3` recipe、明确关闭可选 libtirpc 的 `lsof` recipe、无额外 runtime 的 `netcat` recipe、先拆分 libevent 再准入 tmux 的终端会话层、`libpopt`/`rsync`/OpenSSH 拆分、curl 所需的匹配 target `libatomic-1` 所有权转移、client-only 的 `openssh-client` 源码交叉构建，以及经校验的离线 source cache 中 client-only 的 `git-runtime`/`git` 源码拆分；并将审查后的 `tree`、`which`、文本工具链、`htop`、`nano`、`vim-runtime`/`vim`、`ca-certificates`、`libexpat-1`、`libcrypto-3`/`libssl-3`、`libcurl-4`、`libatomic-1`、`openssh-client`、`git-runtime`/`git` 以及带有 `libbz2`/`liblzma`/`libzstd` 运行时闭包的 `archive-tools` 构建为 r10 候选 RISC-V IPK；
5. 已完成：以增量 source batch 构建同事务 `curl` leaf、只复用 OpenSSL/zlib 的 `wget`、明确关闭可选 OpenSSL 认证的 `iperf3`、`lsof`、`netcat`、`libevent`/`tmux` 与 `libpopt`/`rsync`，并通过不重编历史 source package 的 hash merge 合入 unsigned candidate；
6. 已完成：GitHub Actions source batch [`33988534267`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267) 已准入单独锁定、命名空间隔离的 `gdbserver` 与 `ethtool` debug/network leaf；no-recompile merge [`33988940718`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718) 随后合入其已验证 artifact，未重编 source package。其 recipe 未改变 SDK host state、firmware command path 或网络接口；
7. 已完成：GitHub Actions source batch [`33989899026`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026) 已准入锁定的 static-only `i2c-tools` 硬件检查 leaf；no-recompile merge [`33990178543`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543) 随后合入已验证 artifact，未重编 source package。它已禁用 Python/py-smbus 与 shared `libi2c`，CI 未检查或变更任何硬件总线；
8. 已完成：GitHub Actions source batch [`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904) 已准入锁定 no-shared-library `inotify-tools` leaf，no-recompile merge [`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095) 随后合入已验证 artifact，未重编 source package。该 package 已禁用 shared `libinotifytools`，只公开私有 `inotifywait`/`inotifywatch` command ELF，CI 未启动 watcher 或观察 filesystem path；
9. 已完成：GitHub Actions source batch [`33991963284`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991963284) 已准入锁定 command-only `logrotate` leaf，no-recompile merge [`33992249214`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992249214) 随后合入已验证 artifact，未重编 source package。该 package 已禁用 SELinux/ACL，只复用 immutable target `libpopt` provider，排除 `/etc` 配置、timer 和 daemon payload，CI 未运行任何日志轮转操作；
10. 已完成：GitHub Actions source batch [`33992855036`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992855036) 已准入锁定独立 `jo` command，no-recompile merge [`33993109744`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993109744) 随后合入已验证 artifact，未重编 source package。它保持私有、不引入 shared provider，CI 未执行或传入 JSON input；
11. 已完成：GitHub Actions source batch [`33993563150`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993563150) 已准入锁定 GNU `ed` line-editor command，no-recompile merge [`33993808518`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993808518) 随后合入已验证 artifact，未重编 source package。host-lzip 仅解包 runner source，CI 未执行编辑器或传入文件；
12. 为每个 release 生成来源证明/SBOM，并把来源、SDK 和测试结果与签名 release 对应；
13. 同时逐步引入经过审查的通用库，每次均保留共享运行时和实机测试门。

在自动化全部完成以前，本约定仍是所有新上游引入的准入标准；PR 模板、贡献说明和发布检查清单会引用它，确保维护者不会把“候选源码”误解为“可以直接安装的发行版包”。

当前 r10 provider、应用、profile 的离线构建顺序和实机生命周期记录项见
[r10 上游源码候选批次](R10_SOURCE_CANDIDATE_COHORT.zh-CN.md)。
