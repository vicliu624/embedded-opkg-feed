# AI、视觉与常用 Linux 库验收记录

本记录保留历次候选的验收证据。当前构建绑定已发布的
`v2026.10.09-r12-rc2`；公共 stable 的内容以已签名的索引为准。
新增配方、构建成功、实机运行和发布是独立状态，不能互相替代。

## 当前发布配对与验收状态

- 当前镜像所有权清单 SHA256：`13cab0042c6268976cbf795443559e30eacc671ed7670e5b2568b332b4589794`。
- 当前 SDK archive SHA256：`c1f8190acff53034b921fbe9de4043917b42603afc70b2dfa1ab9879f6e3e961`。
- 当前 SDK manifest SHA256：`cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f`。
- 390 包候选已完成离线根的签名开启求解/安装/配置，以及 Kerberos/RPC 安装后回归。
- 392 包候选已通过离线根安装及 talloc/tevent 回归；393 包现代 NIS 候选和 394 包 GDBM 候选均已通过整体/逐包求解、安装配置与新增库安装后回归。
- 395 包 TDB 候选已通过正式合并门禁，以及签名开启的整体求解、395 次单包求解和安装配置；离线根总计 556 个已安装包，受保护基础文件保持不变，安装后的 TDB 事务消费者通过。
- keyutils `1.6.3-2` 已完成源码构建、不可变 IPK、版权投影及统一批次前置检查；它与此前实机测试的 `-1` stripped runtime 字节一致。包含 `-2` 的独立 396 包候选已通过正式整源门禁、整体求解、396 次单包求解和实际安装配置，总计 557 个已安装包；基础保护文件保持不变。安装后许可哈希、runtime 分离和固定版本标识检查通过，QEMU 的 keyring ENOSYS 不计为功能通过。
- SELinux `libsepol`、`libselinux` `3.11-2` 已完成正式配方构建和 IPK，保留 CIL、PCRE2，并显式声明 libselinux 动态加载的精确 libsepol 依赖。两者 runtime 与 `-1` 字节一致；内存上下文、策略对象与动态 provider 消费者通过。编译前投影记录 libsepol 153 个源文件／74 个许可块、libselinux 85 个源文件／4 个许可块；负向投影回归与完整批次前置检查通过。独立 `-2` 398 包候选已完成整体／逐包求解与实际安装配置，总计 559 个已安装包；安装后消费者和许可哈希检查通过，完整组件许可审查仍未完成。
- 399 包 PCI、400 包 NUMA、401 包 OpenJPEG 候选均已完成签名开启的整体／逐包求解与离线根安装配置，受保护基础文件保持不变。安装后分别验证 PCI 离线配置和压缩 ID 数据库、NUMA 位掩码、JPEG 2000 无损编解码及截断输入拒绝。NUMA 能力探测返回不可用，该结果不代表设备具备 NUMA 硬件能力。
- 403 包 HDF5/AEC 候选已完成整体求解、403 次单包求解与实际安装配置，总计 564 个已安装包，基础保护文件保持不变。2026-10-10 使用该安装根的库运行 RISC-V 消费者：HDF5 C/C++/HL 的 deflate、SZIP 数据集关闭后重开读取，高层 C++ packet table，AEC 128 字节无损往返，以及 SZIP 无损往返和非法位宽拒绝均通过。当前提供 serial C/C++/HL，不声明 MPI、Fortran 或线程安全支持。
- GIF `6.1.3-1` 已完成正式配方构建、独立 IPK、CPU0 ELF 检查和像素往返／截断输入拒绝测试；404 包候选完整整源门禁、整体求解、404 次单包求解及实际安装配置通过，总计 565 个已安装包，基础保护文件保持不变。安装后 GIF 像素／调色板往返、截断输入拒绝、许可逐字节比较与 runtime/development 分离检查均通过。
- Imath `3.2.3-1` 已完成正式配方构建、开发 staging 和版本化 runtime；使用该 runtime 的半精度编码／向量／矩阵消费者通过。OpenJPH `0.32.0-1` 已完成正式配方构建和 scalar HTJ2K 64 像素无损往返、截断输入拒绝。首次 codec 工具缺少 pthread 链接，在 glibc 2.33 上返回 `Unknown error -1`；工具显式链接 pthread 后测试通过，回归脚本检查两个工具的 DT_NEEDED。这些工具仅用于验收，不交付到 runtime 包。两项仍待 IPK、整源安装、完整法律与安全审查。
- Imath/OpenJPH 的独立 IPK 已生成并通过 CPU0 检查，406 包候选完整整源门禁通过，安装与正式签名仍未完成。OpenEXR `3.5.2-1` 正式配方构建、独立 IPK 和五个 ELF 检查通过；正式 runtime 的 ZIP/ZSTD/HTJ2K RGBA 往返与截断输入拒绝通过。DT_NEEDED 证明使用外部 Imath、OpenJPH、libdeflate、zstd，五个库无 RPATH/RUNPATH；407 包候选整源门禁正在运行。zstd 开发文件在隔离验证中由锁定 1.5.7 源码的 `install-includes install-pc` 生成，并复用已有候选运行库；正式批次的开发缓存／receipt 流程尚需验证，不能将手工 staging 视为完整批次通过。
- zstd provider 身份核查：404 包候选 `image-backed-report.json` 中 `libzstd` 的 `image_files` 为空，`new_files` 包含三个库路径，runtime 文件 SHA256 为 `827ca078e6f82b7080083394f8401542a0b2f8b9279c2a61bd9e36ba3a44d5c4`。其 `1.5.7-1+tdvpimg.1.97c14e594963a20ec38d` 是镜像配对组合版本，文件属于 feed 新增 provider，不能依据版本后缀判定为基础镜像已有库。当前安装根未发现 zstd 随包许可证目录，旧 runtime 的许可交付需补查；未将其标记为法律审查通过。
- 网络认证库预验证：官方 Cyrus SASL `2.1.28` archive SHA256 为 `7ccfc6abd01ed67c1a0924b353e526f1b766b21f42d4562ee635a8ebfc5bb38c`，隔离目标构建通过；SPNEGO 目标探针通过，SCRAM-SHA-256/GSSAPI/PLAIN 插件加载及 Base64 往返通过。该结果不证明服务端认证、凭据交换或网络 TLS 成功。原生 makemd5 需隔离 CPPFLAGS；已保留时间头文件检测与包含补丁，正式配方和安全补丁审查未完成。
- HDR 安装验收：407 包候选已通过签名开启的整体求解、407 次单包求解与实际安装配置，总计 568 个已安装包，基础保护文件保持不变。安装根中的 OpenEXR ZIP/ZSTD/HTJ2K RGBA 往返及截断拒绝、Imath 半精度与几何、OpenJPH HTJ2K 精确像素往返及截断拒绝均通过；三项许可证文件与正式配方 payload 逐字节一致。OpenJPH 测试仅用临时 root-view 将安装根适配为 QEMU sysroot，未修改 SDK，也未将其声明为新 SDK。
- SASL 正式配方已从干净源码构建通过，自动执行 SPNEGO 探针、补丁与原生生成器隔离；正式产物插件加载／Base64 回归通过，十个 runtime ELF 无 RPATH/RUNPATH，开发目录单独投影。`libsasl2_2.1.28-1_riscv64.ipk` SHA256 为 `d44bb9622bb1176e66890f3935cf732192a74355f5cdc5db8d4dc0e39bcb6f64`，十个 ELF 的 CPU0 检查与配方静态回归通过；408 包候选整源门禁运行中，安全补丁与完整组件许可审查仍未完成。
- 认证 provider 修订：`-1` SASL/LDAP 曾在移除 RPATH 标签后保留随机构建目录字符串，不能声称 runtime 可重复。SASL `2.1.28-2` 关闭配置自动 runpath 并从一次性 sysroot 去除继承的 `.la`，LDAP `2.6.15-2` 在包内生成 libtool 上关闭直接 rpath 和 `LD_RUN_PATH` 注入。两者分别经两次不同工作目录构建，十个 SASL／两个 LDAP runtime ELF 字节一致，私有路径字符串检查、插件／LDAP BER 消费者通过。探针和生成 libtool 补丁均有配方内 build-input 哈希；没有修改全局 SDK。
- 修订 IPK：SASL `-2` SHA256 `69cc8d3da612c8fd7ea321e95d1d011468d4269523f4d90078393473e796e138`；LDAP `-2` SHA256 `e5706282c287f3a64c21b0d16e7333c91752816c00b6e51577b46519d330b0b8`。各十个／两个 ELF 的 CPU0 检查通过，旧 IPK 与旧候选保留。409 包 `paired-common-ldap-409`（含 `-1`）整源门禁通过；独立 `paired-common-auth-revision2-409`（两项 `-2`）整源门禁运行中，尚无其安装结论，也未正式签名发布。
- 图像 codec 扩展：AOM `3.13.3-1`、libyuv `1924-1`、libavif `1.4.2-1` 正式配方构建和独立 IPK 完成，各一个 runtime ELF 的 CPU0 检查通过。AOM 无损 AV1 YUV 往返／截断拒绝、libyuv 黑白转换／box 缩放／90° 旋转、AVIF YUV/alpha 无损往返／RGBA 转换／截断容器拒绝均用正式 runtime 验证通过。AVIF DT_NEEDED 确认独立 `libaom.so.3`／`libyuv.so`；libyuv 上游 runtime SONAME 本身为无版本 `libyuv.so`，按显式 runtime provider 管理，未改造上游 ABI 名称。
- libyuv 镜像来源核对：AVIF 官方脚本锁定提交 `644251f252a84bf8ce91ff0aca86a9b16b069ab8`，版本头为 1924；下载归档 SHA256 `ccc11fbb02077b9385a37606d9edce34eb5e588b5626c894eb1e883c9c2da114`，所有 187 个 blob 与从官方 Chromium Git 仓库获取的提交逐个一致。AVIF 归档 SHA256 `2b645287340ba5a631d268b551dc2d72bd73ac33335962dd36dcdb6d8366921d`，其根 LICENSE 已包含第三方 libyuv 许可；不存在单独 `third_party/libyuv/LICENSE`，配方按真实 bundle 投影。412 包图像扩展候选整源门禁已启动，尚无安装／正式签名／完整法律安全审查结论。
- 官方 OpenLDAP `2.6.15` LTS archive SHA256 为 `bc91225dbfc50354033b1303bc91d1a7f6ddd1dc32fac950d79c28fe66d6bca8`，含 OpenLDAP Public License 2.8 与版权文件。目标 select/pthread、memcmp 探针通过后，客户端源码编译成功。安装阶段旧 libtool 的 `-L/usr/lib` 被 SDK 安全检查拦截，未绕过；单独投影已构建目标库并清除 RPATH 后，LDAPS URL、DN、BER 往返和非法 URL 拒绝通过。正式安装／配方／IPK／依赖闭包与真实 TLS/SASL 网络互操作仍未完成，未启动 slapd/lloadd。
- 独立实机 keyutils 测试通过私有进程 key 的创建、读取、更新、搜索、撤销和解除链接。测试归档 SHA256 为 `21fbdfc237341c064b5087ec9c9c37128c97b5219ddcbf5c6297e4fcd9376215`；仅使用 `/tmp` 测试库与程序，结束后已清理。QEMU 不实现 keyring 系统调用，其返回值不计为功能通过。
- 完整源码批次 Actions `38016770685` 失败于 `eigen-dev` 的可选 BLAS 构建：宿主 Fortran 对象为 x86-64，RISC-V 链接器拒绝。前置夹具隔离回归已通过；具体 CI 修复仍待确认，不能将批次记为构建通过。
- 旧设备上 `a8a531…` 镜像的测试仅支持对应历史身份，不能用于证明上述当前配对设备安装。
- 正式发布签名、配对设备安装、完整法律与安全审查仍未完成；详见后续时间顺序记录。

## 历史候选配对身份（2026-10-09）

- 镜像构建：`t-display-k230-vision-platform` Actions `37614242646`。
- 镜像所有权清单 SHA256：`a8a53102d7ab54c75999e5e08d8802ffbe563c31ae2c9acc9ab38bcbd7babc31`。
- SDK archive SHA256：`78dc04187d9e6c1f0c0f9266ed8f1ae8a481de8e9683b0debad0044456d59522`。
- CPU0 构建约束：RV64 scalar、lp64d、glibc 2.33；新 ELF 必须通过 SDK 的 ISA／ABI 校验。
- 这些哈希用于独立验收配置。正式平台配置继续绑定已发布镜像和 SDK，不能直接改为未发布的 Actions 产物。

常用库与 ABI 修订首先组成 **307 包 unsigned candidate**，与原 299 包签名候选
保存在不同目录。307 包已通过索引／依赖检查、镜像引用校验、ELF 运行时依赖闭包，
并覆盖镜像的 442 个非 ABI 动态对象。该数量只描述检查覆盖，不代表全部软件已完成实机验收。
加入正式 TFLite Python 包后的最新候选为 308 包，具体校验范围见下文。

## 已完成的设备安装验收

299 包候选已经签名。设备使用临时 opkg 配置更新索引、预演和正常安装所选软件，
没有使用强制覆盖、忽略依赖或关闭签名检查的选项。正式 stable 配置保持不动。

| 范围 | 实际测试 | 结果 |
| --- | --- | --- |
| ONNX Runtime Python | MatMul/Add 模型、动态 batch、错误 shape 拒绝 | 通过 |
| ONNX 与 ORT 共存 | 两种导入顺序、算子域、量化工具导入、参考与 CPU 执行 | 通过 |
| NumPy、SciPy | 线性代数、FFT、积分、优化、稀疏矩阵、空间与信号操作 | 通过 |
| Pillow、OpenCV Python | 图像操作，PNG/JPEG/TIFF/WebP 编解码 | 通过 |
| Python 网络与 YAML | 递归依赖版本、CA 数据、SOCKS 请求准备、安全原生 YAML | 通过 |
| SymPy、mpmath | 代数、微积分、矩阵、高精度运算、依赖约束 | 通过 |
| ncnn | CPU ReLU 小模型推理 | 通过 |
| libusb、libpcap | 初始化／枚举、离线 BPF 正反例 | 通过 |

抽查的 libc、opkg、Labwc 文件校验值及镜像身份清单保持一致。
这不构成全部镜像文件的逐字节审计，也不构成全部 299 包的实机功能验收。

## 本次增加的常用库

下列包已交叉构建、生成独立 IPK、通过 CPU0 ISA／ABI 检查及 QEMU 测试。
实机测试从 IPK 解包到独立验收目录，未写入正式系统库目录。

| 包 | 版本 | 实机测试 |
| --- | --- | --- |
| `libjsoncpp` | 1.9.6-1 | JSON 解析、序列化往返、非法输入拒绝 |
| `libpugixml` | 1.14-1 | XML、XPath、往返、非法输入拒绝 |
| `libtinyxml2` | 11.0.0-1 | XML 属性／数值读取、非法输入拒绝 |
| `libxxhash` | 0.8.3-1 | 已知测试向量、流式与单次哈希一致性 |
| `libsodium` | 1.0.22-1 | Ed25519 签名、XChaCha20-Poly1305 正反例 |
| `libseccomp` | 2.6.1-1 | RISC-V syscall 解析、过滤器构造与 BPF 导出 |
| `libuv` | 1.51.0-1 | 异步 timer、事件循环及资源关闭 |

libseccomp 测试没有加载过滤器；内核过滤器执行能力尚未在本轮验证。
libsodium 版本与哈希来源见 [上游 release](https://github.com/jedisct1/libsodium/releases/tag/1.0.22-RELEASE)，
libseccomp 见 [上游 release](https://github.com/seccomp/libseccomp/releases/tag/v2.6.1)。

镜像已拥有的 libarchive、libxml2、OpenSSL、GnuTLS、GMP、Nettle、libgcrypt、
libgpg-error、libffi、libmount、libblkid、libuuid、libcap 等继续通过镜像运行库目录提供。
它们不需要再次源码构建。新增库的 headers、linker names、pkg-config／CMake 文件
由一次构建的 development staging 供消费者复用。

## 原生 Python ABI 边界

NumPy、SciPy、OpenCV、Pillow、ONNX、ORT、CFFI、Protobuf、PyYAML 的原生扩展
按 CPython 3.13 构建。配方同时要求 `python3 (>= 3.13.3-2)` 和
`python3 (<< 3.14~)`；上界也排除 3.14 预发布版本。修订包使用递增的 IPK revision。

`python3-native-abi-transaction.py` 使用配对镜像的真实 opkg，在隔离安装根中验证：
当前 3.13 可安装；过旧 3.13、3.14 正式版、3.14 RC、3.15 被拒绝。
拒绝时没有安装测试 payload，也没有改变测试根中的 Python 包状态。

镜像引用与增量升级回归的 42 个测试全部通过，包含用配对镜像真实 opkg 运行的
安装／卸载／升级事务。Python ABI 边界另覆盖五种版本的隔离事务。
这些事务运行在构建机的隔离根和 QEMU 中，设备自身的升级／卸载回归仍需完成。

新增 recipe、Python ABI、wheel 路径及依赖区间策略已接入 `ci.yml` 的快速校验任务；
同一组新增命令和 YAML 解析已在 Linux 构建机通过。此记录不宣称新的 GitHub Actions 已运行。

## 仍需完成的交付项

### 音频与 SDK 补充验收（2026-10-09）

当前候选镜像的 libsndfile 实测可处理 WAV，FLAC writer 返回未实现的格式。
镜像端已补 FLAC／Vorbis／Opus 配置，并将 libsndfile 加入增量 package invalidation，
避免旧的 configure stamp 使外部编解码开关不生效。

在隔离目录使用 1.2.2 锁定源码及镜像元数据列出的 14 个 Buildroot 补丁构建后，
WAV／FLAC 往返、Vorbis／Opus 能力均通过 QEMU 和 K230 实机测试。
同一实机隔离目录中的 CFFI、pycparser、SoundFile 和 SoundDevice／PortAudio 接口加载也通过。
测试未打开硬件音频流，未替换设备 `/usr/lib` 的镜像库。

本轮还修复 SDK 导出 `.la` 中的 runner 构建路径与所选 C++ ABI archive 路径。
当前产物的 125 个 libtool archive 已完成重定位检查；原有 25 个 SDK 回归和新增
3 个缺失／歧义／路径边界回归通过。feed 公共 autotools helper 已显式传递 sysroot，
15 个调用配方已在独立 staging 中逐个重建，全部通过构建和 CPU0 ELF 校验：
c-ares、FarmHash、FFTW、FLAC、nghttp2、Opus、libpcap、PortAudio、libsamplerate、
libseccomp、libsodium、SpeexDSP、TIFF、libusb、libuv。旧网络库版本的构建成功
不替代发布前的安全版本核对。

新测试已接入镜像 CI 的构建前校验，并在 SDK 隔离验证阶段要求真实音频往返。
这些是源码与隔离验证结果，新的配对镜像／SDK 尚未构建发布。

### 尚未完成

NumPy／SciPy 的公共 Meson 打包出口已补齐上游 PKG-INFO 分发元数据与许可证，
6 项投影回归已接入快速 CI。真实载荷的共享库 SHA256 保持不变，RISC-V QEMU
已通过版本查询、SciPy 对 NumPy 的上游依赖范围查询、线性方程与特殊函数测试。
SciPy opkg 配方同步限制 NumPy >=2.2.6-2、<2.5，避免越过上游兼容范围。
补齐后的载荷尚未进入新的签名候选或设备全局安装。

补齐后的 NumPy／SciPy 已生成新 IPK，最终 IPK 解包载荷通过 RISC-V 功能测试。
新的 308 包 unsigned candidate 已通过运行库依赖闭包及 442 个镜像非 ABI 动态
对象的覆盖检查，旧候选与签名索引保持不动。

目录核对发现 c-ares／nghttp2 尚未纳入该候选。配方已分别更新至 1.34.8／1.70.0，
使用官方 release asset SHA256，已交叉构建并生成 IPK。QEMU 初始化／HTTP/2
客户端帧生成测试通过；DNS 网络请求、完整 HTTP/2 交互及实机安装尚未验证。
libnode 仍精确依赖旧库版本，需要完成消费者兼容与依赖策略验证后再更新。

网络库 IPK 已在 K230 独立目录通过初始化和 HTTP/2 客户端帧生成测试，
未替换系统库。加入后的 310 包候选通过 ELF 闭包及 442 个动态对象覆盖检查。
声明依赖审计发现 CFFI 所需的 pycparser 未纳入旧候选；现已加入已有锁定产物，
组成独立 311 包候选。声明依赖静态检查对缺包旧候选失败、对新候选通过。
新增 7 项回归覆盖 held image owner、缺包、版本范围、备选依赖、未安装状态和
虚拟提供者版本，已接入快速 CI。该静态检查不替代目标 opkg 安装事务；
311 包的 ELF／覆盖整体复查及签名安装仍未完成。

正式 `finalize-image-backed-feed.sh` 已在 ELF 检查前接入声明依赖静态检查。
311 包候选还完成了配对镜像真实 opkg 的全包 `--noaction install` 预演：
隔离根包含镜像 status 与 info 所有权清单，无依赖／所有权报错，数据库未变。
缺少 pycparser 的旧索引对 CFFI 安装预演退出 255，包含缺失依赖诊断，状态未变。
预演不写入软件 payload，不能替代实际安装、升级、卸载和应用功能验收。

311 包候选的声明依赖、ELF 闭包和 442 个镜像动态对象覆盖检查均已通过。

新增 `libelf-1` 0.196-1 配方，复用配对 SDK 及镜像压缩库。官方 elfutils
0.196 archive 的 SHA512 对照上游 sha512.sum 验证后固定 SHA256；不安装
上游 elf.h，不覆盖 glibc 头文件。已交叉构建、生成 IPK，QEMU 与 K230 的
最终 IPK 隔离目录均通过 RISC-V ELF 文件头／节表读取和非法输入测试。
libelf 尚未纳入新签名候选，DWARF／core-file 解析能力也未据此宣称完成。

新增 `libdw-1` 0.196-1，复用同一次 elfutils 构建 staging，不重新编译。
拆包前检查 libelf 的包名／版本／源码归档标记，并按相同 strip／RPATH 规则
规范化 staged libelf，再与已验证的 libelf runtime 字节对比。
IPK 声明精确 libelf 依赖，其他 ELF 依赖由独立所有权映射自动推导。
QEMU 与 K230 最终 IPK 隔离目录均通过 DWARF 编译单元与源文件名读取测试。
这不证明进程附加、栈回溯或实际 core-file 分析已完成；尚未签名安装。

新增 `libzmq-5` 4.3.5-1，复用公共 libsodium 动态库，开启 CURVE 支持，
不引入私有加密库。使用官方 release archive 和 Buildroot 固定 SHA256，
已交叉构建并生成 IPK；QEMU 与 K230 独立目录通过 multipart inproc 消息
收发、分段状态和 CURVE 密钥生成。加密 TCP 会话、认证负例及签名安装未完成。
libelf／libdw／ZeroMQ 统一加入独立 314 包候选，组成与整体复查结果需另行确认。

314 包候选已通过声明依赖、ELF 闭包、442 个镜像动态对象覆盖及真实 opkg
全包安装预演。ZeroMQ CURVE 回环 TCP 往返与错误服务端公钥负例也已在
QEMU／K230 通过，不等同于跨设备通信或客户端访问控制验收。

最终索引审计发现原 `build-ipk.sh` 按包名去重，导致原生 Python 包的版本
上界在实际 IPK 中丢失。此前配方检查和合成事务测试不能证明实际产物保留
这些边界；旧候选暂停签名。公共出口已改为仅去重完全相同的依赖条目，
并避免自动 ELF 依赖覆盖已声明范围。真实 IPK 上下界回归和共享库策略测试
通过；10 份受影响原生 Python IPK 正在使用已有载荷重新打包，不重新编译。

10 份修复后的真实 IPK 已重新生成，并组成独立 314 包 range-corrected 候选。
声明依赖静态检查通过。配对镜像的真实 opkg 针对每份最终 IPK 执行 5 个
安装预演场景，共 50 项：当前 3.13 可接受，过旧 3.13、3.14、3.14 RC、3.15
被拒绝，隔离数据库不变。测试已保存为 `python-native-final-ipk-preflight.py`。
预演依赖的其他提供者是元数据 fixture，不代表这些包完成实际安装。
修正候选的 ELF／动态对象覆盖复查仍需取得终态结果。

range-corrected 314 包候选已完成 ELF 闭包及 442 个动态对象覆盖复查。
补齐 PortAudio 19.7.0-1／SoundDevice 0.5.6-2 的最终 IPK，QEMU 和 K230
独立目录通过分发版本、动态库加载、host API 枚举；未打开硬件音频流。
两份包加入独立 316 包候选，组成和整体检查结果需另行确认。
SoundFile 仍需配对镜像 libsndfile 外部 FLAC 修复，不以接口加载替代编解码验收。

新增 `ai-common-library-cohort.json` 完整交付清单，包含 81 个配方，按用途
组织但不定义分批发布。配方身份、构建 hook、源锁定／明确第一方豁免及构建
依赖存在性校验已通过，已接入快速 CI。对 316 包最终索引覆盖检查明确失败于
缺少 SoundFile；其他 80 个清单条目均在索引中。完整索引检查仍是发布前要求，
不以 recipe 存在替代产物存在。现有 Actions 增量批次选择尚未覆盖完整新清单。

316 包候选的 ELF 闭包及 442 个动态对象覆盖复查已通过。
镜像侧音频／SDK 修复提交为 `4e091d4`，已推送并触发 Actions `37888572049`，
构建尚未完成。同步远端 CI／发布改动后，25 项 SDK、3 项 libtool 和音频配置
回归通过，15 个 workflow run 步骤及 1 段 Python 代码的语法检查通过。

Python host 锁定补齐科学构建所需 Meson／pybind11／Pythran 及其依赖，共 24
个固定版本与 wheel SHA256。完整 wheel 下载哈希验证通过，全新 Python 3.13
虚拟环境离线安装并通过模块／命令预检；4 项不兼容平台／解释器负例通过，
已加入快速 CI。Ubuntu 24.04 的 Python 3.13 初始化和增量批次接入仍未完成，
这些本地结果不代表 Ubuntu runner 的完整构建已通过。

镜像 Actions `37888572049` 已成功，PR head 为 `4e091d4`，实际产物合并提交
为 `0701ec63edf8f4811f4d8003b30b177167870163`。CI 日志确认 libsndfile 启用
外部 FLAC／Ogg／Vorbis／Opus，两个只读 SDK 重定位路径下均通过 WAV／FLAC
往返和 Vorbis／Opus 能力测试。发布步骤跳过；已有 r12-rc1 仍是旧 d6710d 产物。
本次 artifact ID 为 `11601658079`，GitHub archive SHA256 为
`2202e67b23a779686539aed39007ddc3d09ddf77af079b697be4b52cfc3c668a`。
产物下载和独立文件校验正在进行，日志测试结果不替代实际下载包校验。

SoundFile 0.14.0-2 已使用全新、24 个工具锁定的 host 环境从源重新生成。
实际 wheel 元数据检查发现上游默认沿用 x86_64 标签，现通过上游支持的
`PYSOUNDFILE_PLATFORM=linux`／`PYSOUNDFILE_ARCHITECTURE=riscv64` 明确目标，
未修改上游源码正文。最终 IPK 解包后验证 riscv64 标签、分发身份和无私有
libsndfile 通过。新 SDK 的实际 WAV／FLAC 配对验收仍等待 artifact 下载校验，
这份包尚未纳入签名候选，不计为功能交付完成。

许可证交付抽查发现若干共享库 IPK 未保留源码通知文件。公共 autotools／CMake
出口已接入许可证投影：复制源码 notice、记录源锁定和 notice SHA256；缺少
通知时要求配方显式声明文件，不自动推断授权。纯脚本回归通过，真实 libelf／
libdw 补齐三份通知后运行库 SHA256 不变，小型 libcjson 的公共 CMake 出口回归
通过。该修复仍需扩展到已有最终 IPK 和独立框架构建出口，完整许可证审核未完成。

公共出口的 44 个配方均在现有缓存中找到对应源码归档；43 个有常规顶层
许可证文件。OouraFFT 的条款位于 readme.txt／readme2d.txt，已显式声明并
保留原文，源锁定标记改为 LicenseRef-OouraFFT，避免将自定义条款归类为
普通 MIT。锁定归档 SHA256 和两份通知投影验证通过，未重新编译 FFT。

43 份现有源构建 IPK 已从不可变旧包解包并补齐通知，逐文件 SHA256 检查
确认原有载荷字节不变；随后仅重新生成 IPK，未重编译这些库。结果保存于
existing-ipk-license-projection.7p_yws3e／licensed-source-ipks.kEwTFr。
历史 libjson-c 测试目录缺少配方元数据，未纳入这一结果；独立框架和其他
构建出口仍需检查，不能据此宣称全部候选已完成许可证审核。

libdw 分包入口已补充 libelf 通知的来源归档 SHA256 与内容摘要校验，
复用依赖包的三份通知，再生成 libdw 自身来源记录。实际分包执行通过，
libdw 二进制 SHA256 保持不变，不重编译 elfutils。

重新生成的 43 份实际 IPK 已逐包核对，均包含对应通知和 SOURCE.json，
通知文件内容摘要与来源记录一致。镜像 archive 的最后一个区间在传输重试
时返回 403，临时数据被覆盖；其他七个完整区间保留。恢复任务已取得新下载
链接时遇到 TLS 连接失败，恢复下载尚未启动。后续只补缺失区间，
采用更小的独立块；验证完成前不使用 SDK 程序。

重新获取链接的 TLS 失败已恢复；新下载任务实际启动，缺少的区间被拆成
八个小块，完成后分别验证长度与 Content-Range，再合并并验证 GitHub archive
SHA256。七个原完整区间未重下，恢复任务不自动覆盖已验证块。

TFLite Python 已新增正式 `python3-tflite-runtime` 配方和源锁定，复用公共
`libtensorflow-lite`、Python 和 Abseil，未另编或捆绑核心运行库。
正式 IPK 解包后的 QEMU 和 K230 上游 Interpreter API 测试已通过：ADD 模型、
张量读写、动态尺寸、错误 dtype、非法模型及不支持的 XNNPACK 选项。
重复构建显示 `ninja: no work to do`。包内含 TensorFlow、pybind11、NumPy 的许可证通知；
补充通知后的 IPK 已再次通过 QEMU 功能测试。
新增包组成了独立的 308 包 unsigned candidate，最初版本已通过运行库闭包检查。
补充通知后的候选已通过运行库闭包检查，仍保存在独立目录，不覆盖前一候选。
签名源安装、全部许可证／安全审核
及发布尚未完成，不能据此宣称软件已进入公共 stable。

- 新修订包和新库的签名源安装、升级／卸载回归，以及全体候选的发布审核。
- source/build/host 输入锁定、增量 staging 复用与 AI 全量构建 cohort 的 CI 整合。
- 全体配方的源码／许可证／安全评审及公共目录更新。
- c-ares、nghttp2 等已有配方在完整目录中的覆盖与当前安全版本核对。
- 音频硬件录音／播放验收；新候选的 libsndfile 和 SoundFile 编解码验证见下方更新。
- TensorFlow Lite Python 接口；更完整的视觉模型工具链与 CPU1 模型管理接口。
- CPU1 KPU 模型部署、YOLO 模型及语音识别模型的实际验收。

CPU0 上的通用 ONNX Runtime、ncnn、TensorFlow Lite 库不会自动成为 CPU1 KPU 后端。
YOLO 和语音识别仍需各自的模型、预后处理与运行接口验证。

## 2026-10-09：新镜像配对候选的实际产物核验

Actions `37888572049` 的构建提交为 `4e091d4`，产物标识为
`0701ec63edf8f4811f4d8003b30b177167870163`。它是更新候选，不能与已发布的
旧 `v2026.10.08-r12-rc1` 等同，也尚未作为正式 r12 发布。

完整 GitHub archive SHA256 为
`2202e67b23a779686539aed39007ddc3d09ddf77af079b697be4b52cfc3c668a`，
已在构建机验证；内部 SHA256SUMS 的 13 项全部通过。新镜像 inventory 摘要为
`13cab0042c6268976cbf795443559e30eacc671ed7670e5b2568b332b4589794`。
SDK 内外 manifest 字节一致，实际 SDK 校验通过 24,111 个路径、354 个镜像库，
C/C++、GTK、Wayland、ncurses、curl、GLib、OpenSSL、zlib、CMake 编译链接与 ISA 检查通过。
解出的镜像通过 12,223 个 inventory 路径校验。

新 SDK 的 libsndfile WAV／FLAC PCM roundtrip 与 Vorbis／Opus 能力检查通过。
实际 SoundFile 0.14.0 IPK 载荷在 RISC-V QEMU 中调用新镜像公共 libsndfile 1.2.2：
WAV／FLAC 数据往返、Vorbis／Opus 格式支持检查通过，进程映射确认使用新镜像的库。
这不覆盖设备音频硬件录音／播放。

新镜像已生成 176 个非 ABI SONAME 包及运行库归属清单，未重编译源码。
原 316 个 IPK 与新镜像 overlap 审计中，304 个通过，12 个需要替换载荷。
SoundFile 与新 FLAC SONAME 拆分包加入后，镜像绑定候选为 319 包。
五个历史兼容依赖入口保留 `2025.02.1-2`，防降级检查保持启用；
精确依赖按选定 provider 版本核对，未放宽版本约束。

首个 319 包候选通过声明依赖闭包、81 项交付清单、目标 opkg 全包 dry-run 和
50 组 Python ABI dry-run；ELF／运行库覆盖检查发现 libflac 与 libflac-12 重复拥有库。
修正候选将 libflac 改为依赖 FLAC C／C++ SONAME provider 的入口，不携带共享库，
独立保存于构建机 `paired-image-backed-candidate-319-flac-alias`。
修正候选已通过组合、声明依赖和 81 项清单；镜像运行库覆盖检查通过 445 个
非 ABI 动态对象。ELF 闭包仍拒绝 tdvp-runtime-modules：它通过兼容入口依赖 zlib，
但缺少实际 libz provider 的直接 Depends，需补齐实际 provider 声明后再次验证。
候选产物中的版本和 FLAC 映射处理仍需固化为可重复的生成流程。

五类兼容入口已逐项核验为无文件的依赖包。对完整原始候选扫描后，四个包
缺少实际 libz provider 的直接声明：tdvp-runtime-libexec、tdvp-runtime-modules、
libavcodec-58、libavformat-58。补充 `libz (= 1.3.1-1)`，保留既有依赖，
原始 data.tar.gz 字节不变。独立 `paired-image-backed-candidate-319-direct-providers`
组合与声明依赖闭包通过，完整 ELF 检查已再次启动，不能提前记录为通过。
具体调整记录在验证根目录 `direct-provider-dependency-proof.json`。

direct-providers 最终候选的完整 ELF 依赖闭包已通过；feed 文件摘要／架构／ABI
验证与历史包名连续性检查通过（204 个历史名称、319 个候选名称，五项明确退役）。
对该候选重复的 50 组 Python ABI dry-run 和全 319 包目标 opkg dry-run 均通过，
测试数据库状态摘要保持不变。最终覆盖检查通过 445 个非 ABI 动态对象，
实际 319 个 IPK 的 SDK ELF 指令集策略全部通过。上述记录仅覆盖本地候选验证，
不替代签名源安装、升级／卸载、设备功能、许可证和安全评审。

实际 81 项 IPK 通知扫描找到 69 项已有许可证文件，12 项需继续核对；
其中 Opus 为三份镜像文件引用，需检查镜像所有者的通知。该扫描不构成法律合规结论。
随后已向 OpenBLAS、ONNX Runtime、TensorFlow Lite 的实际原始 IPK 加入此前
核验的顶层源码通知和来源摘要，原有载荷逐文件 SHA256 保持不变。
libdw-1 的三份通知也已加入实际 IPK，notice SHA256 与当前 source.lock 核验通过，
原有 libdw 字节不变。未重编译这些库。独立原始候选保存在
`paired-raw-framework-dwarf-notices.do7lsm7d`，尚未组合为新的最终索引。
内嵌第三方许可、剩余 Python／LZ4 通知、第一方声明和镜像所有者许可仍需处理。

Pillow、OpenCV Python 和 LZ4 的锁定归档 SHA256 已验证，随后在实际 IPK 中
分别补充 Pillow LICENSE／内嵌 raqm COPYING、OpenCV LICENSE、LZ4 顶层和
lib/LICENSE。原有 213／1／1 个载荷文件的 SHA256 不变；未编译。
独立原始候选为 `paired-raw-python-image-notices.optdf9kz`，尚未重组最终索引。
FlatBuffers Python 的锁定 sdist 没有独立通知文件，需要从同版本锁定核心项目
补充通知并明确许可来源，不能假装通知原本存在于 Python 归档。

FlatBuffers Python 的实际 IPK 已补充锁定核心版本 24.12.23 的原始 LICENSE。
核心归档 SHA256 核验通过，来源 JSON 明确记录通知来自核心归档而非 Python sdist，
同时记录两份 source.lock 的摘要、归档 URL／SHA256 和通知 member。
原有 14 个 Python 载荷文件的 SHA256 不变，未编译。最新原始候选为
`paired-raw-flatbuffers-notices.8k5vsrf0`，仍未重新组合／签名／发布。
第一方 C 客户端已有 MIT SPDX；Python 客户端／工具尚无明确许可，已请求维护者
确认是否统一 MIT，确认前不自行赋予这些文件许可证。

Opus 的实际 IPK 已补充锁定 1.4 源码归档中的 COPYING，归档 SHA256 核验通过。
来源 JSON 同时记录运行库来自本次已验证镜像的 inventory 摘要，原有运行库
SHA256 不变。原始候选为 `paired-raw-opus-notices.i6hn109f`。
至此九个扫描发现的上游通知缺口均已补充实际 IPK，三项第一方许可仍待确认；
内嵌第三方审查仍未完成。重新组合的 `319-upstream-notices` 任务已启动，
最终索引及最终包通知检查尚需取结果，未签名或发布。

upstream-notices 最终候选已组合成功，319 包声明依赖与 81 项清单通过。
实际最终 IPK 通知复核为 78 项有通知、三项第一方仍待许可确认；九项新补通知
逐包核验当前 source.lock 摘要和实际通知哈希通过。
Pillow／OpenCV Python 构建入口已加入通知交付，shell 语法与通知回归通过。
FlatBuffers Python 声明 libflatbuffers 构建依赖，以单独工具核对 provider 身份、
当前 source.lock、归档字段、版本、许可和通知哈希，路径／篡改／版本回归通过，
已加入快速 CI。实际完整 Python wheel 构建入口在锁定离线 host 环境中通过，
核心库未重编译；已有核心载荷补通知后原始库哈希不变。

正式流程复核发现先前本地 runtime catalogue 使用 `--release r12`，但当前
PACKAGE_RELEASES 的配方范围仍为 r11；额外 owner 映射因此被过滤。这是本地
验收配置错误，镜像版本与 feed 配方范围不能混用。之前 319 候选的文件和闭包
检查结果仍保留，不能把手动版本／别名修正视为正式生成流程的证明。
已启动独立 `runtime-catalog-recipe-scope-r11`，使用同一新镜像和 SDK、正确
配方范围重新验证现有 provider 名称／版本映射，不重编译源码，不覆盖旧目录。

正确配方范围恢复了 libflac／libcurl-4／libopus-0／libz 的既有 provider 名称和版本。
同时发现 extra-owner TSV 的 CRLF 版本字段未清理；生产解析器已清除该行尾并
验证版本语法。直接测试生产解析片段的 LF／CRLF 等价与非法版本拒绝通过，
回归加入快速 CI。开发 IPK 路径、非法共享库／命令／配置、符号链接、伪装 ELF
和非 CPU0 静态对象拒绝测试通过；provider 延迟策略在规范化验收副本 TSV 后通过。
旧 scope-r11 任务明确退出并报告读取后续脚本时 EOF；任务运行时曾同步覆盖
脚本，可能影响 Bash 读取。其输出保留为未通过，不能用于最终候选。
新的独立 `runtime-catalog-recipe-scope-r11-clean` 使用语法验证后的脚本生成，
运行期间不再同步覆盖其脚本，尚需取完整结果。

设备只读复核：当前 image-base.json 摘要仍为
`a8a53102d7ab54c75999e5e08d8802ffbe563c31ae2c9acc9ab38bcbd7babc31`，
与新候选 `13cab004...` 不同；没有安装新候选或修改设备。
正式源码入口新生成的 FlatBuffers Python 24.12.23 载荷在新镜像动态库环境的
RISC-V QEMU 中通过整数／字符串 table 序列化往返，超出单纯 import 检查。
这不替代新配对镜像设备安装验收。

Ubuntu 24.04.4 容器实际验证完成：使用现有缓存镜像、只读源码／wheel 缓存和
独立输出目录，补齐 libffi-dev 后复用锁定本机 CPython 3.13.3 源构建入口。
ssl、zlib、bz2、lzma、ctypes 模块通过，venv 创建通过；24 个锁定 wheel 以
no-index、only-binary、require-hashes 安装通过，Native AI Python host preflight 通过。
容器镜像遗留的 127.0.0.1 APT 代理仅在命令级覆盖，主机和其他项目配置未改。
日志：`ubuntu24-native-python-host-direct.PT1Lh5oZ/validation.log`。

正确配方范围的完整 runtime catalogue 重生成通过 176 个 SONAME；实际清单和
IPK 文件名不存在 CR 字节。使用其正式映射的独立原始候选为
`paired-raw-canonical-providers.cst2i4fd`（317 包），不再需要两个实验 FLAC
拆分入口；FLAC／Opus 的已核验通知被保留，镜像运行库原始字节不变。
该候选仍需最终组合、完整检查和签名／设备验收，不能沿用实验 319 包的结果宣称通过。

canonical 317 最终候选已按重新核验的前一候选签名作为连续性基线组合，
通过声明依赖、81 项清单、204 个历史包名、完整 ELF 闭包、445 个镜像动态对象
归属检查。重复执行的 50 组 Python ABI 和全 317 包 opkg dry-run 通过，数据库不变。
SDK 逐包策略通过实际 317 个 IPK；通知扫描为 78 项有通知、三项第一方待确认，
有来源记录的包核对当前 source.lock 摘要及通知哈希通过。签名安装仍未完成。

统一 `prepare-ai-python-host.sh` 新增本机来源指纹、目标环境污染拒绝、已有 venv
拒绝及离线 hash-locked 安装。Ubuntu 24.04 实际完整测试通过首次构建、匹配前缀
复用、两个 venv 的 24 项工具契约、已有 venv 拒绝和目标环境拒绝。
日志：`ubuntu24-ai-host-entrypoint.BgIdQT9p/validation.log`。
共享 published-sdk action 已显式加入 libffi-dev、libbz2-dev、liblzma-dev 主机依赖；
快速拒绝测试加入 CI。AI 全量 workflow 的实际接入仍需完成，不能视作已触发验证。

新增 `verify-ai-package-sdk.py` 全量编译前门槛，检查协议头、音频开发文件、
匹配的 C／Fortran 版本及 SDK smoke，并复用镜像项目的实际 WAV／FLAC 写入读取
测试和 Vorbis／Opus 格式能力检查。测试只加载 SDK 配对 sysroot 库，清理可掩盖
结果的 LD_PRELOAD／QEMU 环境注入。新 SDK 完整通过；旧 d6710d SDK 在
实际 sf_open_fd FLAC writer 上失败（格式检查本身仍会通过），证实门槛能拦截
已知不完整 codec 配对，未通过放宽校验规避问题。workflow 接入仍未完成。

全量 ai-common 入口已在 workflow 代码中接入：统一 81 项选择、SDK／codec 前置
门槛、本机 Python 指纹缓存和 staging 导出，旧批次与不取消策略保留。
17 个内嵌 Bash 块语法通过，实际选包片段输出全 81 项通过；Ubuntu 24.04 的
默认 Python 3.12 补齐正式 action 声明的 python3-pip 后，CP313 选择参数从只读
已验证 wheel 缓存选出全部 24 项，逐文件 SHA256 匹配。未推送或触发 CI。

staging 复用审计发现旧清单只记录平台／发布范围／版本，不能证明源码和开发
文件输入不变。独立 receipt 工具及正确复用、SDK／源码／helper／文件／权限／
链接／删除／覆盖拒绝回归已通过，仍需接入正式导出导入。
审计同时确认构建器打包后清理临时 root，FlatBuffers Python 不能依赖核心的
临时 root 取通知。CMake 出口已把各包通知复制入 staging，绑定改为从 staging
复用，自己的通知也进入 staging。实际独立 FlatBuffers wheel 生命周期验证通过；
小型 cJSON 的实际 CMake 构建／开发头／notice SHA256 staging 验证通过。

staging receipt 已接入构建器正常路径：导出选定／provided／递归 done 包的联合
源码和开发文件凭据；导入时在复制前验证，显式要求凭据时拒绝旧无凭据输入。
提供单个包时仍核验原凭据的完整递归闭包。独立实际 build-all 非 ELF fixture
联动通过依赖导出、验证导入、消费者构建、依赖 hook 不重复执行，以及篡改
开发头后在消费者 hook 前拒绝。fixture 的旧 r2 平台不含 runtime provider，
只为验证控制流，不替代实际 317 包的运行库闭包。该联动测试加入 AI SDK 前置步骤。

ai-common workflow 代码已支持通过 dependency_run_id 复用此前完整 AI 产物：
要求本仓库同 workflow 的 completed/success 运行，SDK 标识和 IPK 哈希匹配，
staging receipt 验证通过，再向构建器传递已提供包。交付成员清单本身从编译
输入指纹中排除，新增消费者不改变既有源码／helper／SDK 时可保留依赖复用；
这些真实编译输入和开发文件仍在凭据范围内。
首次／复用两个实际选包片段、凭据含成员变化／递归依赖拒绝、正常构建器联动
以及 17 个 Bash 块语法检查通过。尚无新的 AI Actions 产物可做实际 GitHub
下载复用，不能把代码检查当作远端完整 workflow 已运行。

提交前完整 portable CI 步骤已在 Debian 构建机和独立 Ubuntu 24.04 容器中通过。
使用 Git 管理和本次审阅新增路径生成源码快照，归档 SHA256 校验后解出；
仅 keys/README.md 和公开密钥在快照内，未包含私有签名材料。
Windows checkout 的 Packages 行尾恢复为 Linux LF 后历史索引／gzip 对比通过，
原软件源未修改。Ubuntu 容器关闭网络执行完整 portable 步骤，退出码为零。
日志分别为 `feed-fast-ci-source.lCmQ3L7V/portable-ci-second.log` 和
`ubuntu24-portable-ci.6UKcVabI/portable-ci.log`（验证根目录的同级目录）。
图变更检测只识别 24 个已跟踪文件及一个文档符号，对新增配方和 Bash 逻辑
覆盖不足，不能将其 low 风险输出视为完整风险评价。正式发布仍受平台配对、
第一方许可、完整第三方／安全评审及签名安装／设备验收限制。

提交前生命周期扫描发现 libdw 分包仍用 libelf 临时 root 核对字节／通知；
正常 build-all 会在 libelf 打包后清理该目录，因此独立分包成功不能证明正常
全量流程成功。需改为核验已生成 libelf IPK 并复用其通知。扫描到的另一处
FlatBuffers root 是复制其自身当前载荷到 staging，核心通知已改用 staging。
随后已修复 libdw 通知和字节核验的来源：build-all 将当前 IPK 输出目录
传给构建钩子，libdw 从已生成的 libelf IPK 提取指定库及来源通知。
实际 libdw 钩子运行成功，生成库与既有候选 SHA256 完全一致：
`78a5f500430eecd845c6ecfa344931a21e75fa1a9387967e9ce7764e5d7fa9e5`。
`split-provider-extraction.py` 覆盖身份、版本、架构、路径越界、符号链接、
重复文件及来源通知缺失；已在 Linux 构建机通过，并纳入快速 CI。
`split-provider-builder-integration.py` 使用实际 SDK 和 build-all 的小型非 ELF
测试配方，断言依赖临时 root 和载荷均已删除，再由消费者读取依赖 IPK，
最终两个 IPK 均成功生成；已在构建机通过，并纳入 AI 构建前检查。
此证据关闭已发现的临时 root 依赖缺口；完整 81 包源码事务及远端增量
产物复用仍需单独验收，不能用小型流程回归替代。
上述归档提取回归、实际拆包构建器回归和实际 staging 导出／导入回归，
也已在 Ubuntu 24.04 缓存容器中关闭网络复测通过，使用实际候选 SDK，
源码及 SDK 均只读挂载，未修改主机 Python 或签名源。

验证根目录为构建机
`/home/vicliu/work/tdvp-candidate-37888572049-validation/ranged.38h5ew3r`。
该配置只用于未发布产物验收，正式 feed 的已发布平台绑定保持不变。
319 包候选未签名、未发布、未在设备全局安装。dry-run 不证明实际安装、升级、卸载或应用运行。
全体依赖、许可证／安全评审、增量 CI、签名源与设备验收仍未完成。

拆包修复后的完整 portable CI 已在新的 Ubuntu 24.04 离线验证副本通过，
日志：`ubuntu24-portable-split.s6NJceBk/portable-ci.log`（验证根目录同级）。
本次包含新增 split-provider-extraction 回归和既有全部 portable 步骤；
未运行需要网络的其他 GitHub job，也不代表完整 81 包源码编译已通过。
另核对 81 包配方 source.lock 的 78 个归档引用，共 73 个唯一 SHA256：
73 个在四个已有源码缓存根中找到，实际逐文件 SHA256 全部相符，
无缺失或损坏。缓存按 `sha256/<digest>/<filename>` 布局读取；此检查
仅覆盖配方直接归档，不覆盖递归构建工具／宿主 wheel／隐式下载闭包。
递归宿主输入检查发现 ORT 在复用 protobuf 的目标 staging 时，宿主
serialization/abseil 不随 usr 导出；ORT 原先直接准备 protoc，隐含依赖
此前执行过 libprotobuf 钩子。现已在 ORT 钩子中显式准备锁定版本的
宿主 Abseil，再准备 protoc，目标 protobuf 无需因此重新编译。
`onnxruntime-native-input-order.py` 执行真实钩子的宿主输入前缀，在空的
宿主 staging 中验证 flatc → Abseil → protoc 顺序，通过并纳入快速 CI。
测试使用模拟宿主构建器，只证明调用顺序；真实全新宿主生成器编译与
GitHub 增量产物复用仍待验证。
随后在全新 Ubuntu 24.04 离线容器中实际编译宿主 Abseil、protoc 29.3
和 flatc 24.12.23，通过。产物及日志保留于
`ubuntu24-native-generators.zcMH85az/native-build.log`（验证根目录同级）。
`native-schema-generators.py` 使用该实际工具链验证 protoc C++、descriptor、
消息编码／解码，以及 flatc C++、二进制／JSON 往返，全部通过。
递归构建依赖闭包共 88 个配方；合并宿主 Python 后 80 个唯一直接归档。
初查 libwebp、libyaml 两个归档缺失，现已通过现有 fetch-source-cache 入口
补齐并独立计算 SHA256 与 lock 一致。该检查仍不证明所有构建输入或
隐式下载已经完整闭合。
实际宿主生成器相同输入只读复用验证通过，但进一步检查发现原缓存键
未纳入构建参数和宿主依赖身份。现新增 native-cmake-cache-key.py，绑定
源码锁、包元数据、辅助脚本、完整参数、输出位置、宿主系统和工具版本，
并核对 CMAKE_PREFIX_PATH 中的宿主依赖来源标记。输入不一致返回 65，
保留旧目录并提示使用新目录，不静默覆盖。native-cmake-cache-identity.py
在 Debian 与 Ubuntu 24.04 离线容器通过，相同输入复用，参数／辅助脚本／
宿主依赖标记变化拒绝误用、缺少依赖标记拒绝、旧输出保留均有回归。
此键格式升级会拒绝旧标记；上述真实生成器编译证据来自升级前逻辑，
不能作为新键逻辑下完整真实编译的证明。新逻辑全链仍待复测。
新键逻辑下完整 portable CI 加 ORT 宿主顺序／缓存身份回归已在 Ubuntu
24.04 离线容器通过，日志 `ubuntu24-portable-native-v2.XE1LvG17/portable-ci.log`。
真实 ORT 宿主前缀正在全新目录 `ubuntu24-native-key-v2.GGNH2pcq` 编译，
后续须核对终态与真实 schema 功能；未完成前不记为通过。
进一步增量扫描确认 python3-onnxruntime 钩子无条件调用核心钩子，并读取
核心 build 的静态归档与内部源码。usr staging 导出未携带这些构建输入；
跨 job 即使复用了目标核心 IPK，Python 绑定仍可能重建核心。这是尚未
解决的增量复用限制，需要可核验的核心开发产物，不能只增加 provided 标记。
新缓存键逻辑下，真实 ORT 宿主准备前缀已完成全新编译；随后只读挂载
相同产物，再执行真实前缀成功直接复用，真实 schema 测试也通过。
Python 核心开发投影工具 onnxruntime-development-export.py 初版已创建，
对已有 RTTI 核心及其原 SDK（36676804712）导出并核验 5835 文件、552 MiB，
位于 `ort-development-projection.nguGIvy5/export`。包含十个核心静态组件、
源码 include/onnxruntime 和生成头文件，排除对象文件、Ninja 状态及私有
sysroot。manifest 绑定 SDK、source.lock 和逐文件 SHA256；尚未接入正式钩子。
目前正在使用投影输入实际重新构建 Python 绑定，日志
`ort-development-projection.nguGIvy5/binding-build.log`；该实验使用历史核心
匹配 SDK，不能作为最新候选 SDK 的配对通过证明。
随后投影输入的 Python 绑定实际编译链接成功，12 个构建步骤只编译绑定
源文件并链接既有静态组件，未调用核心构建器。此证据证明开发投影可供
绑定消费；运行功能、错误身份／篡改拒绝、正式 staging 导入和新 SDK
配对仍需验证。
投影构建的 Python 绑定已在 QEMU RISC-V 中通过实际 ONNX CPU 推理、
动态批次和错误形状拒绝测试。首次运行因隔离环境没有 onnx 模块失败，
从已验证候选 IPK 提取 python3-onnx、python3-protobuf 到独立依赖目录后
重跑通过；未修改设备或全局 Python。日志
`ort-development-projection.nguGIvy5/projected-binding-inference.log`。
onnxruntime-development-projection.py 已在 Debian 和 Ubuntu 24.04 离线
容器验证 SDK／源码错配、内容篡改、缺失／额外文件、重复导出拒绝及
无关对象文件排除，已加入快速 CI。正式钩子接入尚待完成。
随后已接入正式核心／Python 绑定钩子：核心输出开发投影到
`usr/share/tdvp-build/onnxruntime`，随已有 usr staging 导出传递；Python
绑定优先核验投影并跳过核心钩子，已存在但损坏时直接失败，缺失才准备核心。
onnxruntime-binding-core-reuse.py 执行真实选择前缀，在 Debian 与 Ubuntu
24.04 验证有效投影不调用核心、损坏不静默重编、缺失调用核心，纳入快速 CI。
真实全绑定钩子已在隔离 staging 启动，目录
`ort-real-hook-reuse.Rrx3WpU1`。仍使用历史核心匹配 SDK，待核对终态；
不能据此将最新镜像配对或跨 GitHub job 导入标为完成。
真实全钩子首次编译链接完成后，打包发现投影遗漏上游 ThirdPartyNotices.txt。
已将该根目录通知加入导出和回归，修正投影后全钩子重跑成功，生成载荷
`/tmp/tdvp-command-payload.m4eJ8V`，CPU0 ELF 策略通过；核心未重编。
重跑重新编译了绑定对象，未将其描述为零编译复用。日志 real-hook-second.log。
已清理终态验证的两份完整 CI 解压副本和缺少通知的失败投影，约 1.3 GiB；
原源码归档、完整日志及成功开发投影保留，可重新生成清理掉的验证副本。
开发投影跨目录验收：仅将真实核心投影放入测试 producer 的 usr 路径，
写入现有 staging receipt 后复制至 consumer，receipt 与投影独立校验通过。
故意改动一个真实静态归档后 receipt 拒绝。日志／目录
`ort-projection-receipt.4DsMY7gC`；这个受限试验不声明完整依赖闭包已由
该测试 producer 构建，也不替代 GitHub 下载／真实增量 job 验收。
正式钩子接入及通知文件修复后，完整 portable CI 已在 Ubuntu 24.04
离线容器通过，日志 `ubuntu24-portable-ort-reuse.HP8dunGY/portable-ci.log`。
最新候选 SDK 配对实际编译已启动于 `latest-sdk-ort-pair.8Jbjq5Gm`，
使用 SDK manifest cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f，
隔离源码副本、已有目标开发依赖及 Ubuntu 24.04 离线容器；核心和绑定
终态待核对，未据此前缀输出宣称完成。
2026-10-09 上游 ONNX 公告核对：当前 1.17.0 位于以下公告列出的受影响
范围：GHSA-hwpq-hmq9-wj77、GHSA-p893-rvq9-2xf9、GHSA-hqmj-h5c6-369m、
GHSA-538c-55jv-c5g9、GHSA-cmw6-hcpp-c6jp、GHSA-q56x-g2fj-4rj6、
GHSA-3r9x-f23j-gc73。具体 TDVP 构建可触发性及修复未完成；不能因模型
smoke 通过标为安全可发布。1.19.1 专属 GHSA-p433-9wv8-28xj 不自动
推断适用当前版本。公告入口：https://github.com/onnx/onnx/security/advisories
属性注入公告指出 <=1.20.1 受影响、1.21.0 修复，另两条转换器公告范围
覆盖到 1.21.0；单纯升级到 1.21.0 不能视为全部安全缺口已经关闭。
完整公告 API 的 patched_versions 字段进一步确认两个转换器公告修复版
为 1.22；原先读取 first_patched_version 字段返回 null，不能推断无修复版。
已核对上游合并 PR 7813（cd310408165ad47c3cd7eb2b86cb5b80aa2e4fdf，
八个适配器输入／输出检查）、PR 7880（e9c74f596eaa0250f89e52a54160a25bbcb25b66，
Gemm 输入维数检查）及 PR 7751（e30c6935d67cc3eca2fa284e37248e7c0036c46b，
ExternalDataInfo 校验）。尚未回移或验证这些安全修复。
检查还发现 libonnx 和 python3-onnx 同样隐含宿主 Abseil 已存在；已补显式
准备，与 ORT／protobuf 入口保持相同参数。serialization-native-provider-policy.py
核对所有四个 protoc 消费入口均先声明宿主 Abseil，在 Linux 构建机通过，
加入快速 CI。该静态顺序检查不证明这两个新入口的完整增量编译成功。
已回移 PR 7813、7880 的适配器边界检查至 libonnx/patches，两份补丁
按 1.17.0 函数签名和断言终止符调整，softmax_13_12 在该版本不存在，
未引入新适配器。锁定源码上的 --fuzz=0 检查通过；随后核心与 Python
绑定在 Ubuntu 24.04 离线容器／最新 SDK 下编译成功，目录
`onnx-security-build.bJP3SmFI`。异常模型回归尚未全部通过：1.17.0 的
GroupNormalization 专用适配器注册后又被 CompatibleAdapter 同键覆盖，
导致当前 GroupNormalization 测试被接受，需要核对并修复注册问题。
安全状态尚未关闭；其余外部数据／hub 公告也尚未修复。
最新 SDK ORT 核心及绑定钩子实际编译已成功，首次临时载荷位于容器 /tmp
未持久化。再次指定 TMPDIR 收集载荷时，旧 root 链接触发保护而停止，
并且相同缓存目录下绑定对象仍重编，不能标记为零编译复用。
核对旧 root 链接确为失效的任务产物后，只移除该链接，改用持久化 TMPDIR
再次收集最新 SDK 载荷，成功且 Ninja 显示 no work to do，未重编绑定。
载荷 `latest-sdk-ort-pair.8Jbjq5Gm/payload-tmp/tdvp-command-payload.ZXWPqI`
已在 QEMU／最新 SDK 的 loader 和 runtime libs 下通过实际动态批次推理及
错误形状拒绝。日志 latest-sdk-inference.log。测试复用匹配的 CPython
运行时及候选 Python 依赖，不是设备安装验收。
重复 GroupNormalization 注册已增加明确标注 TDVP 的 0003 补丁，删除
覆盖专用转换器的通用注册，--fuzz=0 检查通过。上游当前源码仍有重复
注册，未声称该项来自已合并上游修复。安全核心／绑定正在隔离目录重编，
安全回归增加合法 GroupNormalization 20→21 的全检查及 Expand 变换断言，
以防只靠拒绝异常输入通过、却仍绕过专用转换器。终态待核对。
该构建随后成功，实际 Python 载荷保存在
`onnx-security-build.bJP3SmFI/payload-tmp/tdvp-command-payload.L9Aoqh`。
对该载荷运行隔离子进程的转换器安全回归全部通过，覆盖 Upsample/Cast/
Softmax/GroupNormalization 缺输入、Gemm 6→7／7→6 的低维输入、合法 Cast
转换和合法 GroupNormalization 转换的模型全检查及 Expand 变换断言。
日志 converter-security-second.log。结果只覆盖这些案例；不能推断全部
ONNX 安全公告或整个 feed 已安全，外部数据／hub 修复与全面审计仍待完成。
已回移上游 PR 7751（e30c6935d67cc3eca2fa284e37248e7c0036c46b）的
ExternalDataInfo 白名单、数字非负校验、实际文件长度检查至 Python runtime
补丁 0002。保留 1.17 现有路径 API；没有宣称此补丁解决路径／写入竞争。
真实 Python 构建钩子无模糊应用成功，Ninja no work to do，无需重编 C++。
新载荷 `onnx-security-build.bJP3SmFI/payload-tmp/tdvp-command-payload.FHnO7S`
在最新 SDK loader/runtime、QEMU RISC-V 下通过属性注入、非法数字、
负值／超界／超大读取拒绝、零长度／文件末尾读取、正常分段读取回归。
日志 external-data-bounds.log。符号链接、硬链接、TOCTOU 写入和 hub 信任
问题仍待修复及回归，完整安全验收尚未完成。
Python 路径读写已新增 TDVP Linux 描述符补丁 0003：相对路径逐级
O_DIRECTORY/O_NOFOLLOW 打开，最后文件 O_NOFOLLOW/O_NONBLOCK 后 fstat
核对普通文件和 st_nlink==1；读写都使用同一已打开文件描述符，拒绝
遍历／符号链接／硬链接／特殊文件。超前写入偏移使用稀疏 truncate，
避免构造巨量零字节的 Python 内存分配。非 Linux 不静默降级。
正式钩子应用成功且 no work to do，载荷
`onnx-security-build.bJP3SmFI/payload-tmp/tdvp-command-payload.P1gobk`。
实际 QEMU 回归通过路径遍历、叶／父符号链接、硬链接、FIFO、目录拒绝、
错误后的描述符计数、普通子目录读写，以及父目录在打开后替换的读／写
竞争场景。原元数据／边界回归也在合并补丁后的载荷复测通过。
日志 external-data-descriptors.log、external-data-bounds-with-descriptors.log。
这是 Linux Python load/save 的测试证据，未关闭 C++ 路径 API 或所有竞争
场景；hub 信任、完整模型隔离策略和全部上游安全公告仍需审计。
hub 新增 runtime 补丁 0004：load 和 download_model_with_test_data 均在
元数据读取前确认非受信仓库；silent=True 拒绝，拒绝交互确认不下载，
缓存存在不豁免信任检查。保留默认受信 onnx/models:main 的加载功能。
实际载荷 `onnx-security-build.bJP3SmFI/payload-tmp/tdvp-command-payload.skLZlu`
在 QEMU 下通过两入口静默／拒绝／明确确认回归、受信模型模拟下载和
缓存加载、非受信缓存拒绝，整个测试模拟网络、未联系模型仓库。
日志 hub-trust.log；未因此宣称模型文件／测试数据归档均安全。
为发布升级设置 libonnx 1.17.0-2、python3-onnx 1.17.0-3、
python3-onnxruntime 1.21.0-3，并更新两个 Python 包的精确依赖。
onnx-security-package-revisions.py 检查升级修订与精确引用，通过并纳入
快速 CI。317 旧候选未随之自动更新；新版本需重新打包、索引和闭包验收。
Linux C++ checker 新增核心补丁 0004，用 open/openat 的目录描述符和
O_NOFOLLOW/O_NONBLOCK 验证当前路径，再对已打开文件 fstat，拒绝
非普通文件和 st_nlink!=1；空 base_dir 保留当前目录语义，其他平台分支
未修改。原接口仍返回路径字符串，明确不保证调用方未来重新打开安全。
最新 SDK 下核心／绑定实际编译通过，载荷
`onnx-security-build.bJP3SmFI/payload-tmp/tdvp-command-payload.7jJESQ`。
直接 C++ 解析绑定和模型文件 checker 的正常子目录／真实 # 文件、
遍历／链接／FIFO／目录／不存在文件拒绝及描述符计数回归通过。
Python 元数据、描述符、hub、转换器回归也对同一载荷全部复测通过。
日志 cpp-external-paths.log、python-onnx-*-final.log、converter-security-final.log。
从真实 317 raw IPK 的顶层 ELF SONAME 建立 356 条 owner 映射，排除旧
libonnx 后登记新核心两个 SONAME；使用正式 build-ipk、实际最新 SDK 及
镜像覆盖保护生成 libonnx_1.17.0-2、python3-onnx_1.17.0-3 两个新 IPK。
文件保存在 `onnx-security-build.bJP3SmFI/ipks`，日志 security-ipks.log。
两包未签名、未发布、未安装；Python ORT 新修订、许可证来源完整性、
合并候选闭包和安装／升级事务仍待验收。
Python ONNX／ORT 钩子现已加入来源通知投影，ORT 显式包含 LICENSE 和
ThirdPartyNotices.txt，避免从源码重建时丢失统一 SOURCE.json 记录。
本次对已有验证载荷只补通知和元数据，不重编核心；旧同版本候选 IPK
不可覆盖，保留旧文件并改用新的 licensed-ipks 目录生成三个包：
libonnx 1.17.0-2、python3-onnx 1.17.0-3、python3-onnxruntime 1.21.0-3。
新的 raw 候选为验证根目录同级 `raw-onnx-security-revisions.yV4MeN4X`；
旧三包及复制的旧索引移动到 `superseded-onnx-revisions.XposiB84` 保留。
raw 317 包的声明依赖闭包和 81 配方索引覆盖通过，已验证旧签名 299 基线。
组合形成 `paired-image-backed-candidate-317-onnx-security`，317 包、复用 28 包，
组合后依赖、81 配方覆盖、IPK／索引校验再次通过。新候选未签名、未发布、
未安装；完整 ELF 闭包检查正在运行，尚未将安装／升级事务标为通过。
生产平台仍锁定已发布 r11 的 image manifest 0c0d0f2f...，因此 ELF 引用
物化检查拒绝最新候选的 13cab004...；环境变量不能覆盖 source 后的锁。
现建立独立 `closure-profile-onnx-security` 离线验证副本，仅将其 image
manifest 锁改为已验证候选摘要，生产仓库 platform.env 未修改。
该副本用于候选 ELF 闭包，不允许作为公开发布绑定；后续必须核对其
日志和进程终态，未把此前锁拒绝计为库依赖故障。
该副本的完整 317 包 ELF 运行依赖闭包随后通过，退出码为零，日志
paired-317-onnx-security-runtime-closure-candidate-profile.log。正常保留的
目标 RPATH/RUNPATH 均通过锁定镜像字节一致性检查，未放宽 SDK／构建机
路径禁令。生产发布锁未改变，实际 opkg 安装／升级验收仍待完成。
随后新增真实 target opkg 事务回归 onnx-package-upgrade-transaction.py，
使用完整镜像副本、Ubuntu 24.04 无网络容器和静态 QEMU；生产设备未改。
最初未签名索引被拒绝；测试专用 RSA 公钥仅复制到夹具中，生产发布密钥
未使用，check_signature 始终为 1。确认 gpg_dir 在 offline-root 下会加
前缀，修正公钥环位置后实际验签通过。离线 unpacked 状态按包逐个配置，
配置前证明所有待配置包无维护脚本；不强制依赖、覆盖文件或降级。
旧版本实际安装通过；只安装新版 Python ORT 以及单根 --combine install
均因旧精确依赖拒绝，数据库不变。显式联合升级
`opkg --combine upgrade python3-onnxruntime python3-onnx libonnx` 通过。
四阶段完整回归（旧安装／联合升级／卸载顶层消费者／重装）随后全部通过，
完整版本号含 +tdvpimg 后缀按实际索引核对，libc、opkg、Labwc、镜像
身份文件的 SHA256 全程未变。日志目录 `onnx-opkg-cohort-upgrade.xgAIP2ji`。
安装后的真实文件和解释器通过 CPU 推理、动态批次／错误形状、Python
外部元数据／描述符、C++ 路径 checker、hub 信任回归，日志 installed-functional.log。
这是测试密钥签名的离线事务证据，未关闭生产发布密钥签名源、联网更新
和实机安装验收；旧精确依赖迁移需联合升级，普通单包升级限制仍明确存在。
五份结束的失败／诊断夹具 root 副本已清理，保留各日志与 final-status.txt；
成功事务的完整 root 和功能测试记录保留。三个用户权限副本共 1172 MiB，
两个 root 权限副本通过 sudo 清理；未清理原镜像、IPK、源码缓存或发布密钥。
这些副本可从保留镜像和测试输入重新生成。

### 2026-10-09 最新代码与候选包复核

- 已安装 root 的版本转换安全回归通过，日志为成功事务目录中的
  `converter-security-installed.log`；使用候选镜像的 Python 与真实安装库。
- 当前 CI portable-feed 步骤在离线 Ubuntu 24.04 容器中全部通过。
  验证目录为 `latest-portable-ci.2Uzvi4VI`，日志 `portable-ci.log`。
  首次验证副本漏装受控 tdvp-hello/root，补齐 Git 跟踪的 payload 后通过。
- 最新安全修订候选的 317 包真实 opkg 成组安装规划通过，数据库 SHA256
  未变；日志 `onnx-opkg-cohort-upgrade.xgAIP2ji/all-317-install-plan.log`。
  该结果只证明依赖规划，不代替文件安装和实机功能验收。
- 直接检查最新候选的 IPK data archive：81 项新增清单中 78 项有非空
  licenses 文件，3 项自研包仍待许可证决定。文件存在检查不代表完整
  法律合规或所有内嵌第三方组件审计通过。
- 317 包逐个执行真实 opkg `--noaction install` 全部通过，数据库 SHA256
  未变。日志保存在成功事务目录的 `individual-install-plans/` 和
  `individual-install-plans-summary.log`。基线包含已安装的新 ONNX 组，
  此项不证明从所有可能旧版本进行单包升级，旧精确依赖组限制仍存在。
- 新建完整镜像副本 `all-317-unpack.flEB6FAt`，开启夹具公钥验签，实际
  `opkg --combine install` 全部 317 包通过，未使用强制覆盖、依赖忽略
  或降级选项。全部包的完整版本与候选索引一致；libc、opkg、Labwc 和
  镜像身份文件 SHA256 未变。离线状态均为 unpacked，维护脚本未执行。
  `install.log`、`transaction.log`、`final-status.txt` 保存完整证据。
- 在该完整安装副本上使用它自己的 RISC-V Python 与库，NumPy/SciPy
  数值与发行元数据、Pillow PNG/JPEG/TIFF/WEBP 往返、OpenCV 图像处理、
  Python 基础设施递归依赖、SymPy/mpmath、原生 CFFI、WAV/FLAC 内存往返
  和 PortAudio 接口加载全部通过，日志 `installed-functions.log`。
  QEMU 测试不包含真实摄像头、音频设备、CPU1 或 KPU 验收。
- 对完整安装副本的维护脚本逐个审查：只有 Audacious/NetSurf 的四份
  postinst/postrm，均在非 `/` 的 IPKG_INSTROOT/PKG_ROOT 下提前退出。
  明确传入离线根目录后，真实 opkg `--force-postinstall configure` 通过，
  所有 317 候选包均为 installed 且版本逐项匹配索引。数据库还包含原
  镜像 161 项额外记录，共 478 项 installed；首次断言误以为总数应为
  317，后续按候选索引逐项核对修正证据范围，配置过程本身未失败。
  日志 `configure.log` 和 `configured-status.txt` 保留，四项受保护文件
  校验值不变。离线桌面缓存更新仍被脚本明确延后，实机验收尚待完成。

### 2026-10-09 自研 AI 包 MIT 授权落地

用户明确同意 libtdvp-ai-client、python3-tdvp-ai、tdvp-ai-tools 统一采用
MIT。三个 recipe 新增完整 LICENSE、PACKAGE_LICENSE 声明和随包安装入口；
修订号均为 0.1.0-2，工具包精确依赖同步更新。运行时代码未改动。
使用最新候选 SDK 的真实 hook/build-ipk 重建三份 IPK，通过 CPU0 ELF
检查，逐个解开 data archive 后确认 LICENSE 与仓库原文完全一致，文本
SHA256 为 dc371929eec34ccd5ebdc45388b765550c9eaa27617240ba582b8438064926af。
构建目录 first-party-mit.J6mclsIG。新增 first-party-ai-license-policy.py
并接入快速 CI。旧 317 候选仍包含旧修订，需重组索引并重新验收、签名；
不能把新三包的检查归到旧候选签名或旧安装结果上。

三份 MIT 修订现已加入 raw-first-party-mit.qvDKPpSE，317 包 raw/index
SHA/声明依赖闭包及 81 项覆盖通过；重组候选目录为
paired-image-backed-candidate-317-first-party-mit，317 包索引校验与声明
依赖闭包通过。测试密钥新签署该索引，check_signature 保持开启，在
all-317-unpack.flEB6FAt 的旧自研修订上显式联合 upgrade 三包通过，
随后配置为 installed，版本均为 0.1.0-2 加实际 tdvpimg 后缀。
三份 LICENSE 在安装目录存在，四项受保护镜像文件 SHA256 未变。
日志 first-party-mit-upgrade.log、first-party-mit-configure.log 与
first-party-mit-upgrade-summary.log 保留。此签名只用于离线夹具，
尚未使用正式发布密钥、公开发布或在板卡上安装新自研修订。
新 MIT 候选完整 ELF 运行时闭包通过，日志
paired-317-first-party-mit-closure.log。使用已记录的私有候选验证 profile
核对新镜像 inventory，生产平台 release 锁定文件保持不变。

### 2026-10-09 公开发布配对状态复核

GitHub 实际状态：镜像 PR #3 OPEN，head 为
4e091d461b539774c6df1f8e2f06d0935b4a567c；run 37888572049 completed/success。
feed PR #4 OPEN/DRAFT，远端 head 仍为 7c0717b，当前新增工作尚未提交。
Latest 正式镜像 release 仍为 r11，公开 r12-rc1 的镜像/SDK 文件名为
d6710d2955e15e050c162383cabb240494542464，其 image inventory a8a53102…、
SDK manifest 9d15648c… 与已验收的新候选不同。不能用旧 RC URL 配新摘要。
重新读取本地已校验产物，当前验收配对为：

- image inventory: 13cab0042c6268976cbf795443559e30eacc671ed7670e5b2568b332b4589794
- SDK manifest: cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f
- SDK archive: c1f8190acff53034b921fbe9de4043917b42603afc70b2dfa1ab9879f6e3e961
- image archive: f19165c08fdffb87ff2bbe2790a2f8c787c032cfb753dbaa1d58f7aed4cb5e3c

产物文件名保留 Actions 的 merge revision 0701ec63…；不能把文件名中的
merge revision 混作 PR head 4e091d4。公开平台 lock 仍指向 r11，没有
绑定尚未发布的新候选。下一发布步骤需取得新候选 release 授权，保留
旧 RC 不覆盖；上传完整配对产物后下载核对摘要，再改 feed 的公开锁定。
正式 stable 推广还需要最新 feed 完整构建/审查、生产签名和板卡验收。

用户随后授权发布独立 r12-rc2 候选。现已公开
https://github.com/vicliu624/t-display-k230-vision-platform/releases/tag/v2026.10.09-r12-rc2
，isDraft=false、isPrerelease=true，tag object 指向真实构建提交
0701ec63edf8f4811f4d8003b30b177167870163。上传前构建机与 Windows 转存
副本 13 项 SHA256SUMS 均通过；公开前全部 14 个 GitHub asset 状态、
大小和 digest 逐项匹配转存文件。旧 r12-rc1 与正式 Latest r11 保留，
没有合并 PR、触发镜像重编译或修改公开 feed 锁定。
公开下载复核目录 r12-rc2-public-download.c8oVs6ut，大文件传输仍进行中，
不能提前记录为全部公开下载 SHA 验证通过。发布使用原始产物名字与
清单，release notes 明确新增库来自独立 feed 候选，未全部预装在镜像中。
公开地址的 11 项配套文件 SHA256 已通过，完整镜像下载摘要
f19165c08fdffb87ff2bbe2790a2f8c787c032cfb753dbaa1d58f7aed4cb5e3c
也已通过。构建机 SDK 单次传输在 240 秒明确超时，curl 自动重试进程
仍在运行；另外启动 Windows 对同一公开 SDK 的独立下载复核，尚待结果。
未因传输超时重新编译或修改 release 资产。
构建机公开下载随后完整结束：14 文件齐全，13 项 SHA256SUMS 全部
通过，含 420415930 字节 SDK。工作分支平台配置已切到公开 r12-rc2
URL/文件名/摘要，四项锁定输入逐个通过，published-sdk-contract 十项
全部通过（把 /usr/sbin 加入验证 PATH 后无跳过）。用实际工作分支
profile 检查 MIT 修订 317 候选运行时闭包通过，日志
paired-317-official-rc2-profile-closure.log；不再需要私有摘要覆盖。
暂存区 Git tree 93803d30… 已导出做完整快速 CI。Windows 默认
core.autocrlf=true 的 git archive 将 METADATA LF 转为 CRLF，导致
固定行匹配失败；git ls-files --eol 证明索引/工作树该文件均 LF，
od 证明归档副本 CRLF。此为验证快照的生成问题，未改测试规避，
正在以 core.autocrlf=false 对同一个 Git tree 重新导出 Linux 字节快照。

### 2026-10-10 精确暂存区快速 CI 完成

Windows native 行尾还受 core.eol 影响；仅关闭 autocrlf 的第二份归档
仍是 CRLF。小范围 git archive/od 实验证明显式 core.autocrlf=false
和 core.eol=lf 可生成索引中的 LF。对同一 tree 93803d30… 导出源码
覆盖层（SHA256 9839cb07c7a7edd2a7ef47f45f0d9082c581d865a7d6b2f73ef80e1145eca1ab），
保留同 tree 的原始签名 site bytes，在 Ubuntu24.04 离线容器运行
当前 ci.yml 完整 portable-feed 步骤全部通过；目录
staged-explicit-lf-rc2.8MF5YxPL，日志 portable-ci.log。无手工改测试、
临时删除依赖或改源码避过检查。第二份 Windows 公共 SDK 独立下载也
完成 SHA256 校验，与构建机公共 SDK 摘要相同。验证快照工具问题已
关闭；完整 AI source workflow、生产签名及板卡验收仍需继续完成。

27d24e5 已推送草稿 PR #4；GitHub run 37956541493 两项 job 全部成功。
完整构建前检查发现增量 workflow 的 TDVP_SDK_CACHE_KEY 仍写死旧 r11
SDK 摘要，虽 platform hash 避免直接命中旧 runtime 缓存，产物身份
仍会标错。移除手写摘要，共享 published-sdk action 在输入验证成功
后从当前平台 lock 导出 SDK cache identity；三个增量模式均调用此
action。新增 published-sdk-cache-identity.py 执行真实 action shell，
验证两种 SDK 摘要、非法值拒绝及三个模式的共同入口。回归通过，完整
Ubuntu24 portable CI 再次通过，目录 sdk-cache-identity-portable.F1thOsvL。
没有取消 CI、重复编译镜像或推广 stable。

### 2026-10-10 签名与包损坏拒绝验收

runtime base run 37957180516 在策略阶段失败，公开 SDK/image 准备成功。
本地逐项复核全部七项 batch policy 与全仓库 source lock，只有
target-runtime-provider-deferral-policy 的旧 r11 inventory 固定摘要
断言失败；CI 修复计划等待用户确认，尚未实现。

等待期间在 signature-rejection.CGSe7kuE 新镜像副本执行真实 target
opkg，check_signature=1 保持开启。篡改索引返回 Bad signature；有效
签名索引加大小变化的 IPK 返回 File size mismatch；同大小字节损坏
被认定 corrupt package 并拒绝；有效签名但空信任公钥环返回 No public
key。四种拒绝均未改变数据库，目标新许可证文件未落盘。测试密钥与
公钥环仅用于夹具，不代表生产密钥签名验收。日志 tampered-index.log、
corrupted-ipk.log、same-size-corrupted-ipk.log、unknown-key.log 保留。
同大小坏包日志没有显式 checksum 字样，首次日志文本断言过严而退出，
实际安装已拒绝且数据库检查已通过；按真实 corrupt package 输出核对。

2026-10-10 磁盘复核：两份已结束的失败快照
staged-portable-rc2.uRBkN1IX/repo、staged-linux-portable-rc2.lDIZBZMD/repo
各 372 MiB，均解析精确路径并确认原始归档与日志存在后删除。只清理
可重建源码副本，保留原始 archive、portable-ci.log、成功验收 root、
IPK、源码缓存及发布产物。清理后构建机约 55 GiB 可用。CI 修复授权
仍等待确认，没有重新派发失败 runtime-base run。

用户随后明确同意修复并继续。旧 r11 固定摘要断言改为读取当前 lock、
校验 SHA256 格式及 image ownership URL 与 SDK release 一致；实际
下载摘要校验和 catalogue inventory 核验未删除。新增共享入口
check-batch-build-policy.sh，保留原七项策略、全部 shell 语法及全仓库
source lock 验证，快速 CI 与两个构建模式统一调用。新增
batch-policy-entrypoint.py 验证入口覆盖、当前 release 接受、非法摘要
及不匹配 release 拒绝；初版 fixture 缺平台 TSV，补齐 fixture 数据
后通过。真实 SDK/image 环境的 Ubuntu24 共享前置检查通过，日志
shared-batch-policy.5wWYlFLB/shared-policy.log。完整快速 CI 再次通过，
日志 shared-policy-portable.q19rvzYi/portable-ci.log；没有弱化失败断言
为忽略错误，也没有重编镜像或关闭签名验证。

runtime base run 37959050946 成功，耗时 6m57s，provider alternatives、
缓存保存和 evidence artifact 均成功。新 SDK digest 对应缓存约
93 MB，ref 为当前候选分支。完整 ai-common run 37960082985 随后启动，
但在编译前 staging integration 失败；SDK 24111 paths/354 libraries、
44 image dependencies、Fortran 与音频能力验收均先通过。
真实日志为 NetworkManager 插件 no feed owner。用 Ubuntu24 容器模拟
SDK/target 同父目录，build-staging-receipt-integration 和 split-provider
integration 两个 fixture 均复现相同错误，日志目录
ai-preflight-layout-reproduction.MqTx0AO6。删除 TDVP_FEED_BASE_ROOT 后
生产 builder 会从 SDK 旁的 target/ 自动推导根目录，导致非 ELF 小
fixture 意外核对整镜像 owner。拟明确使用空 fixture base，保留生产
全镜像校验；修复确认已发出，尚未实现、重新派发或取消任务。

等待 fixture 修复确认期间继续审查共享库消费者：当前 libcares recipe
为 1.34.8-1、libnghttp2 为 1.70.0-1，libnode 仍声明精确依赖
1.34.2-1/1.64.0-1。当前 317 候选含新两库但没有 libnode，因此现有
候选闭包通过不证明整个配方集合版本一致。Node consumer 的 recipe、
相关精确依赖链和 node22 policy 需在其批次发布前修正、验证，不能
把缺失消费者从验收范围中遗忘。尚未修改 Node 配方或重编 Node。

后续人工核对五包链，已修正 Node recipe 元数据：libnode/node 修订为
22.23.2-2，npm-runtime/npm 为 10.9.8-2，安装 profile 为 1.0-2；
libnode 精确匹配 c-ares 1.34.8-1 与 nghttp2 1.70.0-1，五包内部引用
同步更新。新增 node-provider-version-policy.py，读取实际 provider
recipe 逐项核对十二条精确边，并接入快速 CI 与 Node policy。两个
策略均通过，完整 Ubuntu24 快速 CI 通过，日志目录
node-provider-portable.MHAOOaqc。Node 源码/编译脚本未改，旧 IPK 未
覆盖，尚未重建、实机验证或发布新 Node 五包，不能据此声称 Node
交付已经完成。静态 extra-runtime-owners 表的历史镜像 attestation
未改写为未经镜像证明的新 Node runtime 版本。

Node recipe 修订提交 773f81d 已推送，GitHub 快速 CI run 37961893964
成功。进一步核对本地原生/交叉构建输入，未找到可用的 Node/ICU 已
构建缓存；c-ares、nghttp2、libuv 锁定源码均已有且实际摘要通过。
只下载缺失的 Node 22.23.2 与 ICU 73.2 源码到内容寻址缓存，两个
SHA256 重新计算通过，日志 node-input-download.L99gsYBp。没有重复
下载三份已有库、复用错误版本的旧二进制或开始重编 Node。五份源码
输入现已齐备；SDK/source cache 的准备不等于 Node 实际构建完成。

### 2026-10-10 实际 source builder 暴露旧 owner seed

本地 Node 预检先因 profile 闭包带入整个 dev-tools、离线缓存缺 tar
而在编译前停止，未删除 profile 依赖；改以四个运行包为重建验收根。
新 SDK 下 libcares 实际编译/打包通过，随后 register-runtime-owners
拒绝旧 owner seed 的 1.34.2-1，构建目录 node-local-source.nbTt3Ffl。
整表审查发现七条版本落后：mGBA、c-ares、nghttp2、Node、ONNX 两个
SONAME、AI client。确认这些 SONAME 都不在锁定基础镜像，表头也明示
外部 feed providers，先前把这些旧行当作镜像 attestation 而保留的
判断不准确；现只同步外部 provider 声明，未重写真实 image inventory。
新增 extra-runtime-owner-version-policy.py，189 条 eligible source
SONAME 行全部匹配 recipe；该检查与 Node 十二条依赖检查同时进入
共享前置入口。TSV 新增 LF Git attribute，修正 Windows 转存副本的
行尾假失败。Node policy、完整 Ubuntu24 portable CI 及共享前置检查
通过，日志 owner-version-portable.Bykvbp9l/portable-ci-lf.log。
提取实际新 libcares IPK 验证：新声明注册成功，旧 seed 仍被 collision
拒绝且拒绝后 map 不变，证明未放宽冲突保护；日志
owner-registration-proof.EC7HKeYw。既有 runtime base cache 含旧 seed，
新声明会改变其缓存身份，需要重新生成 metadata/base 包装，不编译
镜像；旧公开缓存或 IPK 不得直接改写冒充新输入。

等待新 runtime base 时清理三个已结束的快速 CI 源码副本，各 372 MiB：
staged-explicit-lf-rc2.8MF5YxPL/repo、shared-policy-portable.q19rvzYi/repo、
node-provider-portable.MHAOOaqc/repo。删除前核对绝对路径、保留日志和
源码归档，合计约 1116 MiB 可重建内容。未清理当前工作源码、成功
安装 root、IPK、SDK、Node 输入归档或编译缓存；构建机约 55 GiB 可用。

新 runtime base run 37965484919 成功，耗时 6m49s，provider 检查、缓存
和 evidence 上传均成功。取回四份 evidence，与本地旧基础层比较：
runtime ownership、target runtime packages、image aliases 三份完全
相同；外部 owner map 七条修订值均正确。仅在任务专属新 output
复用原 base IPK 并配置新 evidence，保留旧公开缓存与旧失败输出。
本地 Node 重建第一次被旧容器留下的悬空 libcares/root 拒绝，安全
检查未放宽；检查精确链接及目标不存在后 unlink 该生成链接，切换
到任务映射的持久 TMPDIR。四运行包构建现已越过 owner 注册，进入
ICU 原生生成器编译，日志 node-local-source.nbTt3Ffl/runtime-build-persistent-payload.log。
仍为进行中，未完成 Node 构建/安装验收或发布；AI fixture 修复等待
确认，没有重新派发 AI 失败批次。

后续本地构建在 ICU 原生 `make install` 停止：锁定归档包含
`icu/LICENSE`，helper 仅复制 `icu/source/`，安装规则读取
`$(srcdir)/../LICENSE` 时缺失。修复保留原始 LICENSE 的父目录位置。
新增 `icu-native-source-layout.py` 执行真实 helper 的准备路径，用
隔离归档 fixture 验证 configure 收到字节一致的父目录许可证，
并验证未完成构建不会产生完成 marker。该测试与全配方 exact edge
检查进入快速 CI 和共享前置检查；Ubuntu 24.04 容器共享检查通过。
exact edge 检查覆盖 178 个 r11 配方中的 135 条 source-provider 边；
明确使用 SDK 开发文件的 libcurl-4、libncursesw 仍由实际 image/IPK
闭包校验负责。开发工具 profile 修订为 1.0-2，允许 Python runtime
修订升级，Node profile 引用同步；原生 Python 扩展的 ABI 约束保持。
本地完整 Node/ICU 构建重新启动，日志为
`node-local-source.nbTt3Ffl/runtime-build-icu-license.log`，尚未宣称
完整构建成功。测试 fixture 验证不能替代实际 ICU 安装验收。

实际构建随后越过 ICU native install，进入 RISC-V target 编译；
原生安装日志已完成许可证安装，native/LICENSE 与已安装
share/icu/73.2/LICENSE 字节一致。该证据证明本次许可证布局故障
已在真实 ICU 原生安装中修复，仍不证明完整 Node 构建完成。

扩展验收范围到全部 r11 源码配方，与 317 包候选对照：140 个配方
具有匹配版本的候选包，38 个未包含，无已包含配方版本漂移。
缺项主要为 Node/ICU、Git、Vim、文本工具与开发 profile。审计报告
whole-recipe-candidate-coverage-317.json 和 missing-38-source-input-audit.json
保存在配对验收目录。38 项中 34 项具有 source.lock、4 项为明确
exempt profile；27 份唯一锁定归档中 2 份已有校验通过的缓存，
25 份尚缺。已启动逐配方抓取与摘要校验，日志目录
common-tool-source-inputs.UbAxW2R4；未将输入缓存视为已交付 IPK。

快速 CI run 37970142935（29a7803）成功。34 项输入抓取结束，
其中 make 的 host lzip 原站 TLS EOF，改从 Buildroot 源码镜像
获取同一 lzip-1.25.tar.gz；现有 SHA-256 09418a6d... 校验通过，
make 的严格 offline source-cache 检查通过。没有修改锁定摘要，
也未关闭 HTTPS 校验。日志 make-mirror-offline.log 和
lzip-mirror.oe0ftGgS/download.log 保留原站失败及镜像成功证据。

新本地批次 common-tools-build.cEEnrzc2 选择 25 个缺项工具配方，
复用已验证的基础层 IPK 和新 owner evidence。完整依赖闭包在编译
前捕获 openssh-client 输入缺失（Git transport 依赖），补齐官方
锁定归档后进入实际编译。日志 build-with-ssh-input.log；file 等
开始产出经 CPU0 ELF 策略检查的 IPK，完整批次验收仍进行中。
Node 批次已完成 ICU native 与 target 构建，进入 Node/V8 编译。
独立运行 prepare-go-module-vendor-cache.sh 为 gh 生成锁定
vendor 输入，日志 gh-vendor-input-preparation.log；尚未宣称成功。

gh vendor 准备随后成功：Go 报告 all modules verified，派生归档
SHA-256 与锁定 1f9e4f6a... 一致，保存到 derived/go-module-vendor/
sha256 缓存。开始独立的无网络 Ubuntu 24.04 gh 构建，固定
GOMAXPROCS=2 限制 host 并行度；不将 host Go 工具链打入目标包。

gh 的真实离线编译结束，发布 SDK ISA 校验拒绝 Go 内部链接产物：
ELF 缺少 RISC-V ISA attributes。未改写或绕过 SDK 校验。
小型 Go 外部链接验证 go-external-link-proof.fn3Pt0py 使用锁定
Go 1.26.7、GORISCV64=rva20u64 和配对 SDK GCC；实际 ELF 通过原有
verify-published-sdk-payload.py，QEMU 正常运行。gh 配方迁移仍未
实施，该小型验证不证明完整 gh 已通过。

工具批次在 make 的 .tar.lz 解包发现 ambient host lzip 缺失。
published-sdk-build.sh 已增加限定 .tar.lz 输入分支，从该配方锁定
lzip-1.25 源码构建临时 host helper，安装路径位于事务工作目录，
不进入目标 sysroot。make-locked-lzip-build.log 证明实际 make
源码构建和 IPK 打包成功；纯命令批次 export-staging 随后仍失败，
原因是没有 usr development projection，未将批次视为全部成功。

在 runtime-smoke/payload 解包实际 13 IPK（上述 12 项加 make），
核对 Package/Architecture 并记录每包摘要；21 个新 ELF 通过
配对 SDK ISA 校验。QEMU --version 运行 diff、dos2unix、file、
find、gawk、git、grep、jq、less、make 全部成功，报告保存在
common-tools-build.cEEnrzc2/runtime-smoke/results.json。该验证是
载入/启动 smoke，不替代 opkg 安装、命令功能或 SSH transport 验收。

纯命令 staging 导出修复：build-all.sh 在事务没有开发文件时创建
明确的空 usr/，保留 build-staging-receipt.py 的全部 SDK/input/byte
校验与原断言。新 command-staging-export-integration.py 调用真实
builder export/import，验证空 development_files、producer 只构建
一次、consumer 复用成功、加入未记录文件后拒绝。portable 模式的
测试 SDK 明确拒绝所有 ELF；另以实际配对 SDK 的 manifest/verifier
做隔离 receipt-only 投影运行相同测试，两种模式均通过。没有修改
原先等待批准的两个 AI fixture，生产完整 runtime coverage 保留。
Ubuntu 24.04 全共享前置检查通过，日志 command-staging-integration.log。

8cb144b 快速 CI run 37971696818 成功。启动本地剩余工具批次
common-tools-remaining.FRKolnAQ，包含 make、openssh-client、patch、
sed、strace、tree、Vim runtime/plugins 和 which 共 14 个 root。
Make 重新作为真实 producer 验证完整导出修复；此前已成功的 12 个
工具/IPK 保留用于候选合并。该批次的 Vim plugin 依赖闭包额外要求
Git，因前一失败批次没有成功导出的 receipt，Git 两个包再次构建。
新批次尚未完成。

剩余工具批次随后仅在 which 分派处停止；配方、锁定归档已有，
发布 SDK 通用 Autotools 分派未包含 which。增加该叶子分支后，
which-leaf-build.log 记录真实源码构建、CPU0 ELF 校验、QEMU 版本
输出和 which_2.21-1_riscv64.ipk 打包成功。保留其余已产出包，未
通过绕过分派错误把原失败批次标记成功。

gh 配方已改为 Go rva20u64、netgo/osusergo、配对 SDK GCC 外部
链接，并对白名单 libc/pthread/dl 支持库之外的动态依赖拒绝。
开启 runtime 自动依赖解析，实际 control 将 libc 基线归入锁定
platform ABI，同时保留 Git/CA 依赖。gh 修订为 2.98.0-2；开发
profile 及 Node profile 修订为 1.0-3，全部精确引用同步。源码与
179-module vendor 锁定摘要不变，未修改 SDK verifier。

external-link-versioned-build.log 证明完整 gh 无网络编译、原 SDK
ELF 校验、QEMU 输出 gh version 2.98.0、IPK 打包全部成功。
早期 DEV 版本输出证据保留，最终通过显式上游 build.Version
注入修复。gh 外部链接完整 portable CI block 在 Ubuntu 24.04
运行通过，日志 gh-external-link-portable.Pm8yhQQM/portable-ci.log。
当前 gh IPK 仅含程序；上游与 vendor 许可证交付、正式安装与
发布审查仍待完成，不将该包视为已完成发布。

后续补齐 gh notice 交付。新增 install-go-package-notices.py，保留
上游 LICENSE、Go LICENSE/PATENTS 及 vendor notices 原始字节、
相对路径，并生成 SHA-256 清单；支持 LICENSE 与 LICENCE 拼写。
实际锁定 vendor 清单含 179 个模块，177 个有源码目录，另外
go-minisign 与 gotest.tools/v3 未 materialize 为 vendor 源码，单独
记录而不虚构 notice。收集到 223 份文件；177 个 materialized
模块均有直接 notice。该清单是保留证据，不替代许可条款审查。

go-package-notices.py 覆盖文件字节/摘要、未覆盖模块显式报告、
未 materialize 模块区分、拒绝覆盖、拒绝符号链接；加入快速 CI
和共享检查。完整 Ubuntu 24.04 portable CI block 通过，日志
go-notices-portable.qjE8Gmyo/portable-ci.log。

对已验证 gh payload 加入 notices 后重新打包，不重编程序，保留
此前 unsigned IPK。实际 licensed-ipks/gh_2.98.0-2_riscv64.ipk 的
SHA-256 为 87c92d593125306c12a05f892c3b8365fd93ecde5f933c78f05e9c83bc447f77。
直接读取该 IPK，223 份 notice 全部与清单摘要一致；可执行文件
摘要仍为 cc8de391ec9499efa21e441ed1db70f09438e748fb443d7416ee2bfbb79180e5。
配对 SDK ELF 校验与 QEMU 版本输出再次通过，报告
gh-offline-build.7ogNBYXk/notice-ipk-verification.json。
8dde9f2 的快速 CI run 37973968555 成功；此包尚未正式签名、
公开发布或完成设备安装，法律与安全审查范围不因 notices 齐备缩减。

扩展 IPK notice 审计到已构建常用工具，发现命令包和 archive-library
投影只保留程序/库与运行数据，遗漏 SDK install root 的 notices；
多数 IPK 没有许可证文件，vim-runtime 例外。审计报告保存在
common-tool-notice-payload-audit.json。修复共享 notice 投影到最终
IPK 所属 package 命名空间，保留字节并拒绝符号链接；扩充 SDK
采集文件名，包含 LICENCE、COPYING.LESSER、COPYRIGHT 等。
Git runtime 从锁定 source_dir/COPYING 交付并 stage 给 Git leaf，
OpenSSH client 从锁定 source_dir/LICENCE 交付。

真实 which 验证发现 late source 会触发 RETURN trap 提前清理安装
目录，静态检查未捕获；在推送前将 notice helper 加载移到 trap
设置之前。notice-projection-lifetime.py 调用命令/库共享入口的
non-ELF 事务 fixture，验证运行数据存活和 notice 字节保留；另以
真实配对 SDK 构建 which，COPYING 传递与 ELF 校验均成功，日志
which-notice-projection.RlBMc7H5/build-fixed.log。该 fixture 不证明
原生编译或 ELF ABI，真实 SDK 验证单独保留。完整 portable CI
通过，日志 common-notices-final-portable.LIhhmTQq/portable-ci.log。

OpenSSH 路径原先先编译源码，再用 image 中已存在的五个程序覆盖。
移到编译前判定 image reuse，并保留源码 hash/解包与 SDK 检查；
无 base 时仍保留 source build，遵守 TDVP_JOBS。实际 /image 为
配对 rc2，PATH 中 make shim 永远返回失败；reuse 仍成功，五个
程序与 image cmp 全部一致，LICENCE 存在，SDK 识别 0 新 ELF。
日志 common-tools-remaining.FRKolnAQ/openssh-reuse-notices.log。
尚未完成全部已构建工具的 notices 重包、法律审查或 opkg 验收。

实际补包推进到 19 个常用工具/库：diffutils、dos2unix、libmagic、
file、findutils、gawk、Git 两个包、grep、libjq、jq、less、
openssh-client、patch、sed、strace、tree、vim、which。源码锁定
验证通过后从归档提取根 notice，只增加许可文件，不重编程序。
dos2unix 的文件名为 COPYING.txt，已补入共享 SDK 采集名单和检查。
首次补包验证捕获 tarfile data filter 未恢复原目录 mode，丢弃该
未签名验证输出作为交付输入，保留日志；新 assembly 显式恢复原
member mode，新 notice 目录为 0755。

tool-notices-repack.7yy8wi_n/ipks 实际 19 IPK 均重新经过配对 SDK
CPU0 policy 和标准 build-ipk 打包；直接比较旧/新 data.tar.gz 的
所有原成员，类型、链接目标、mode 与文件内容全部不变。新增
notice 内容摘要全部匹配锁定归档提取结果。报告
tool-notices-repack.7yy8wi_n/ipk-notice-verification.json。
共享 Ubuntu 24.04 前置检查再次通过，日志 copying-txt-shared-policy.log。
该组尚未合并到最终候选或通过 opkg 安装；Make .tar.lz notice、
profile、Node/ICU 及其它包的完整 notice/许可审查仍继续。

Make 的锁定 .tar.lz 经锁定 host lzip 1.25 解压，COPYING 原文摘要
e79e9c8a0c85d735ff98185918ec94ed7d175efc377012787aebcf3b80f0d90b；
加入已构建 Make payload 后重新打包，原成员类型/mode/link/data
保持一致，未重编目标程序，日志 make-notices.UsEvFFr4/harvest.log。
三个纯文档 profile 已打包：tdvp-dev-tools 1.0-3、tdvp-source-tools
1.6-1、tdvp-diagnostics 1.1-1，位于 tool-profiles.GVS8a6mD/ipks。

合并原 317 个 raw input、新工具 notices 包、gh notices 包、Vim
runtime/五插件和三个 profile，common-expanded-raw.q5q4h2yt 为
346 个唯一包名。input-provenance.json 记录所选输入版本/来源/摘要，
索引验证与实际 image status 的声明依赖闭包检查均通过。Node/ICU
八运行包与 Node profile 共九项仍待原任务完成，未把此中间池定义
为完整交付。四个 tpope 插件无独立 LICENSE 文件，README 与 Vim
许可引用及随依赖交付的条款还需审查，未默认为许可审查完成。

完整 finalize 先拒绝旧本地 signed 299 候选作为 predecessor：其
摘要不符合 feed-predecessor.json 的发布锁。保留该拒绝，不改锁。
通过生产 fetch-feed-predecessor.py 从锁定 r10 公共快照取得正确
历史输入，index 摘要为 1d52128e...，两份索引签名与所有 IPK
完整性通过；目录 locked-feed-predecessor-common-346。随后再次
执行生产 finalize，日志 common-expanded-finalization-locked.log，
尚未宣称成功、签名或发布。

346 包的生产 finalize 随后成功：正确 r10 predecessor 锁与签名、
镜像引用、runtime coverage/closure、CPU0 policy 全部通过，输出
paired-common-expanded-346，仍未签名。该证据对应旧插件修订的
中间池，新许可修订需要重新合并和验收，不能直接替代。

四个 tpope 插件的上游许可信息补齐：repeat/commentary/surround
README 已含引用，sleuth 说明位于原 doc/sleuth.txt，先前未复制。
四个 source.lock 增加已锁定 Vim 9.1.0145 归档作为 license text
输入，Vim-LICENSE 随包交付，sleuth 额外保留 UPSTREAM-NOTICE.txt。
没有改写许可原文或把它们归为 MIT，也未增加原生编译依赖。
四插件修订为 -2，Vim leaf 为 9.1.0145-2，开发/Node profiles 为
1.0-4，精确依赖同步；已有程序字节可复用，新控制修订仍需打包。

真实四插件 IPK 在 vim-plugin-notices.Lo1l7tuk/ipks 构建成功，
全部原始文件内容与前一 IPK 一致，新增 Vim terms 与锁定 source
LICENSE 字节一致，sleuth 原说明存在；验证报告为同目录
ipk-notice-verification.json。本地完整 portable 检查捕获旧 Vim
依赖断言，更新后重跑通过，日志
vim-notices-final-portable.dlEUobAa/portable-ci.log。许可原文交付
不替代条款审查；新修订尚未正式签名/发布/设备安装。

Vim 9.1.0145-2 和开发 profile 1.0-4 在
vim-profile-revisions.j65dpuzu/ipks 生成；Vim 新/旧 data.tar.gz 所有
成员类型/mode/link/data 完全一致，没有重编程序。将六个新控制
修订合并到新 raw pool common-notices-revised-raw.08ab_9b1，保持
346 个唯一包名，索引与声明依赖闭包通过。生产 finalize 对新池
成功，输出 paired-common-notices-revised-346，旧输出保留。

使用隔离 fixture RSA key 签署候选索引（非正式发布 key），运行
配对 image 的真实 opkg。先 --noaction --combine install 全346包，
签名检查开启，保护文件和 status 不变；随后在独立 root 执行完整
安装与 offline configure。控制脚本审计捕获新增 Vim postinst，
逐个读取后确认与 Audacious/NetSurf 一样在非根 IPKG_INSTROOT /
PKG_ROOT 下提前退出，再放行离线配置。346 个版本与 index 全部
一致，共507个 installed 条目；libc/opkg/Labwc/image-base.json
摘要未变。日志 common-346-opkg-plan.log、
common-346-opkg-install-audited.log 及 common-346-opkg-plan/*.log。

安装后 QEMU 从该 root 运行 Git/gh/Vim/jq/Make/which 版本检查，
并以安装后的 Python 执行 NumPy/SciPy/OpenCV 计算与 Pillow PNG
round-trip，均通过。测试 harness 最初把 /usr/bin/vim wrapper 当
ELF，改为调用其实际 libexec 程序后通过；未修改包程序或绕过
ELF policy。日志 common-346-installed-smoke-fixed.log。该验证
不替代真实设备、GPU/CPU1/网络验收，也不证明全功能或许可审查。

清理三个已结束 portable 源码副本（各372MiB逻辑大小）：
vim-notices-portable.LcX9Zpj2/repo、vim-notices-final-portable.dlEUobAa/repo、
go-notices-portable.qjE8Gmyo/repo。删除前核对精确路径与非Git属性，
日志/源码锁/当前源码/SDK/全部IPK保留；副本可从已提交代码重建。
Node 原容器仍在运行，达到2078/3570，未重启或取消。

再次对照全部 r11 recipe 与新346包索引，无已交付版本漂移，剩余
九项明确为 ICU 四包、libnode/node/npm/npm-runtime 与 Node profile。
报告 revised-346-whole-recipe-coverage.json。81项 AI/common 清单
与最终索引覆盖检查再次通过；该覆盖结果不代替功能/许可/发布验收。

在新 image-only fixture root 逐个执行实际 target opkg --noaction
install，共346次独立求解，候选没有预装；每次都使用 fixture
签名验证与完整索引，全部返回成功，保护文件与 status 均不变。
此前全346一起安装的结果保留，两者范围分别记录。该单包测试为
solver/noaction 证明，不将其表述为每个包的单独实际安装或运行。
日志 common-346-individual-plan.log 与
common-346-individual-plan/individual-plans/*.log。Node 原任务到
2217/3570仍运行，未重启或取消；正式源、硬件和完整安全审查未完成。

在已安装的隔离 root 补充 source profile / which 生命周期样本：
直接 remove which 被已安装 profile 的依赖保护拒绝，status 不变。
随后先移除 tdvp-source-tools，再移除 which，重新 install profile
自动拉入 which，offline configure 成功；恢复507个 installed 条目，
四个基础保护文件摘要保持不变。日志 common-346-lifecycle-sequential.log，
结果 common-346-opkg-plan/lifecycle-summary.json。

尝试同一次 --combine remove profile which 时，profile 已移除，
which 的移除被依赖检查拒绝；该操作具有部分执行结果，不能视为
原子卸载事务。测试先恢复 profile，再按上述顺序验证，不使用
force-depends。此证据只覆盖一个 profile/leaf 样本，未覆盖全部包
的升级、卸载与恢复。Node 原任务到2606/3570仍在运行。

对 paired-common-notices-revised-346 的全部实际 IPK 做 notice 路径
初筛：277 包带 image-reference 控制字段，单独保留其镜像来源；
其余69包中55包有许可证／copyright／NOTICE 等文件，14包未检出：
iperf3、libbz2、libevent、liblzma、libmicrohttpd-12、libmpdec-4、
libmxml-1、libpython3.13、libwebp-7、libyaml-0-2、lsof、netcat、
pkgconf、pv。该初筛只识别路径，尚未验证文本完整性或条款，
image-reference 包也不能据此视为许可交付完毕。

源码入口核对显示缺口跨越 archive-library、command-package 和
CPython 拆包三条出口，不能只在单个叶子包补文件。共享 notice
复制机制已存在，下一步需核对这些入口的 staging 来源、锁定源码
许可与复用分支，并确保补充声明不改变原有程序／库载荷。

CPython 三拆包出口已补原始 LICENSE 提取：复用既有 staging 时也
调用 tdvp_python3_locked_archive，先核对 source.lock 与归档 SHA256，
再提取 Python-3.13.3/LICENSE 到各自 licenses namespace，空文本拒绝。
python3-package-policy 通过；Linux 隔离非ELF fixture 执行真实
libpython/cli 投影，两份 LICENSE 与真实锁定归档字节一致。
fixture 跳过 staging marker/ELF 校验，仅证明许可投影，不证明
新的 Python 运行时或 IPK 已交付。历史 IPK 与版本修订尚未更新。

剩余 notice 缺口的14个 source.lock 已逐一验证，补下载8个缺失归档
并核对各自固定 SHA256；完整报告 common-remaining-source-notice-audit-complete.json。
13个归档根目录有原始许可，pv 的许可在 docs/COPYING。公共源码
出口此前漏掉 libyaml 的 License、mpdecimal 的 COPYRIGHT.txt、
xz 的 COPYING.0BSD/GPLv2/GPLv3/LGPLv2.1，以及 pv 的 docs/COPYING，
现已补入显式路径清单。source-notice-filenames.py 执行真实复制循环，
验证原始字节、0644模式及仅复制声明文件；接入已被快速CI和批次
preflight调用的 common-tool-notice-policy.sh。

声明投影与载荷生命周期回归均通过，未重编目标程序。此处证明
未来打包出口已修，当前346包中的历史IPK尚需修订和重新打包，
不能将源码修改等同于已签名发布。Node 原任务到2791/3570仍运行。

14个缺失声明包的新 data archive 在 remaining-notice-payloads.92g8vi2y
准备完成，原有每个归档成员的 type/mode/uid/gid/uname/gname/linkname/
mtime/size 与文件内容均与旧IPK一致，新增许可文本匹配锁定源码。
报告 notice-payload-proof.json；这些是重打包输入，还不是新版本IPK。

根据精确依赖传递图同步递增22个配方控制修订，更新消费者依赖及
12条SONAME owner记录。Python上下界保留原先兼容限制，上游源码
版本与二进制均未升级。189条owner、135条source-provider edge、
12条Node edge及八项相关策略通过。Ubuntu24.04容器执行真实78行
portable CI block通过，日志 remaining-notices-portable.N47Hj4/portable-ci-revised.log。
首次运行遇到复制验证目录残留dist，清理独立副本dist后重跑；
第二次捕获historical-library-migration旧修订断言，同步明确区分
三包-3与未变化libubootenv-0的-2后全量通过。正式索引未改写，
22包仍需按新控制元数据重打包及重新验收。

对全部346个实际raw IPK控制字段再次做传递依赖审计，发现三项
ELF自动依赖消费者：libubootenv-0、python3-tflite-runtime、tdvp-netsurf。
同步递增其修订，影响范围为25个配方，报告
remaining-notice-actual-ipk-consumer-plan.json。Node profile尚无旧IPK，
等待live Node任务后首次生成；其余24包在remaining-notices-repack.z2wkq410/ipks
通过真实build-ipk及SDK CPU0策略，新IPK原有成员type/mode/link/content
与旧IPK相同。Python标准库和CLI也加入各自namespace的锁定LICENSE。
前一中间打包remaining-notices-repack.ol4ybzy_未包含这两份补充，
保留用于诊断，不作为最终合并输入。

新24包合入独立common-final-notices-raw.82ba289h，保留346个唯一包名；
索引、哈希和声明依赖闭包通过。历史库／TFLite策略、189条owner与
135条source-provider edge再次通过。生产finalization已针对锁定公共
predecessor启动，日志common-final-notices-finalization.log，尚待结束。

生产finalization结束并成功，输出paired-common-final-notices-346，
全部签名predecessor锁、镜像引用、声明/ELF闭包、覆盖及SDK CPU0
策略通过。最终IPK另对16个补声明包逐项检查license member/type/mode
与原始文本SHA256，全部通过；报告common-final-notices-ipk-proof.json。
新候选仍未正式签名，277个image-reference包的完整许可交付另需审计。

完整25配方修订的78行portable CI block再次通过，日志
remaining-notices-portable.N47Hj4/portable-ci-full25.log。清理该已结束
验证repo副本372MiB及中间打包remaining-notices-repack.ol4ybzy_/repo
77MiB逻辑大小，先核对精确realpath、非链接和无.git；所有日志/
IPK/源码缓存/当前验证repo/SDK保留。生成副本可重建，不将并行
Node增长期间df变化等同于精确回收量。

新候选使用隔离fixture key签署验收索引，启动fresh image root的
真实target opkg逐包求解与全包安装/配置，日志
common-final-notices-opkg.log；该任务尚待结束。未使用正式发布私钥。

新生产候选的fresh-root验收结束：346次独立单包求解、全346包
实际安装/离线configure通过，507个installed条目与index一致，
基础libc/opkg/Labwc/image-base摘要未变。安装后Git/gh/Vim/jq/
Make/which及NumPy/SciPy/OpenCV/Pillow计算和PNG往返通过，日志
common-final-notices-installed-smoke.log。GitHub快速CI37987272901成功。

额外升级测试发现两个独立限制。两个均从公共r10 predecessor
生成的未发布兄弟候选，53项合成版本改变，其中15项被dpkg/opkg
判为下降，不能直接视为连续发布历史；报告
common-final-notices-sibling-upgrade-diagnosis.json。隔离实验先验证
旧fixture索引签名，再直接按真实旧候选历史生成ordered fixture，
不修改production predecessor锁，不把该实验产物发布。

按历史递增修订后的346包，字母序--combine upgrade仍被旧消费者
反向精确约束拒绝。实际opkg-0.7.0源码与-V4日志定位：
opkg_prepare_upgrade_pkg逐个选候选后才标记旧消费者deinstall，
pkg_breaks_reverse_dep会在消费者尚未处理时排除新provider。
根据已安装图和新index的依赖并集生成consumer-first顺序，
未变化的Pulse依赖循环另验证版本相同后置于尾部；同一图的
升级预演、实际upgrade及configure通过，346版本一致、507 installed，
基础保护文件未变。日志common-final-notices-consumer-first-upgrade.log。
这证明排序影响结果，尚未构成设备端通用升级修复，也不证明
发生变化的循环依赖可升级或单包请求能自动协调全部精确依赖。

两个失败预演root的status和四个基础保护文件均与旧安装根摘要
一致，证明common-final-notices-failed-plan-protected-proof.json保留。
删除这两个已结束实验的root副本（各849MiB逻辑大小），精确路径
位于common-final-notices-upgrade/root与common-final-notices-ordered-upgrade/root；
日志、签名、index、排序JSON与摘要报告保留，可由旧安装根重建。

通用升级准备实验位于opkg-combined-upgrade-experiment.PPZJeo，
只改独立opkg源码副本，未修改镜像仓库或设备opkg。实验在批次
候选选择前临时标记非held/replaced旧包deinstall，恢复不升级的
旧约束后，对全部所选新包再次检查reverse dependencies；失败
恢复状态并返回。宿主对照旧版失败、实验版字母序预演通过，
单provider及held profile负例保持保护。首次宿主fixture的GPG
选项不兼容，不纳入有效证据；native-case-clean-config专测求解，
不含GPGME，不代替签名验收。

RISC-V实验工具由Buildroot固定SHA256 d973fd0f...的opkg-0.7.0
归档、镜像现有四个保护补丁及实验补丁构建，使用当前发布SDK
和显式rv64gc/lp64d，SDK CPU0检查通过。签名开启的target-case
再次确认旧工具失败、新工具字母序预演通过、单provider与held
profile负例拒绝不兼容选择，预演status未变。harness恢复hold
时最初用ok而原标记为user，diff确认唯一差异后恢复user，完整
旧status字节一致；再实际字母序upgrade/configure全部346包成功，
507 installed版本一致，基础libc/opkg/Labwc/image-base未变。
日志target-case/*及工具编译日志保留。未据此宣称默认非combine
升级、变更循环依赖、所有失败事务原子性或设备端修复完成。

Node原任务57759终态exit0，容器正常移除；runtime-build-icu-license.log
结束为raw build candidate ready，闭包与445个非ABI动态对象覆盖
通过。四个ICU、libnode/node/npm-runtime/npm及development staging
成功产出，未重启任务。node-final-ipk-smoke.3y4r3z39直接解包最终
IPK并复用当前候选cares/uv/nghttp2，QEMU通过Node22.23.2/ICU73.2、
中文locale、Unicode、SHA256、gzip及异步loopback HTTP，npm CLI
10.9.8通过；该证据不代替K230实机或npm联网安装。最终notice
路径扫描发现ICU四包、libnode/node未带独立声明，npm-runtime
196个notice路径存在；许可完整性仍需核对，六包需复用程序载荷
补声明并递增相应修订后，才合入正式配对候选。

Node/ICU六个拆包出口现统一读取锁定归档的regular LICENSE，
install-archive-source-license.py再次验证source.lock、归档SHA256、
成员路径/类型/大小，并复用install-source-licenses.py保留原文与
SOURCE.json。测试覆盖原始字节、来源、幂等、链接、越界路径、
缺文件和哈希损坏拒绝，接入公共批次preflight/快速CI。

ICU四包修订73.2-2，libnode/node为22.23.2-3，npm-runtime/npm为
10.9.8-3，Node profile为1.0-6；同步精确依赖及五条SONAME owner。
九个IPK在node-licensed-repack.vm6zygqa/ipks成功生成，八个既有拆包
的全部原始type/mode/link/content与原编译IPK一致，六包新增
LICENSE及来源记录；Node profile首次生成，没有重复编译Node。
Node政策、12条精确边、189条owner与135条source-provider edge通过。

九包与现有346包组成common-node-licensed-raw.0j53ipp5，共355个
唯一包名，索引/哈希/声明闭包与81项AI/common覆盖通过。按
PACKAGE声明身份及r11/K230 scope核对178配方，缺包/版本漂移为零，
报告node-licensed-355-declared-identity-coverage.json；首次按目录名
扫描将compat目录误判为缺包，保留原报告，语义核对确认该目录
声明tdvp-cardputer-zero-gba而非目录名，未改变配方或缩小范围。

完整78行portable CI block通过，日志node-licensed-portable.rxKgiu/
portable-ci.log。355包生产finalization以已锁定公共predecessor启动，
日志common-node-licensed-finalization.log，尚待结束及新签名安装验收。
清理已结束CI repo副本372MiB及两个宿主实验root副本848/849MiB，
精确realpath/非链接/无.git核对后删除；日志/IPK/工具源码与编译/
SDK/缓存保留，生成副本可重建，不把逻辑大小当作df精确回收量。

355包生产finalization终态成功，输出paired-common-node-licensed-355；
全部predecessor锁/镜像引用/声明及ELF闭包/覆盖/CPU0策略通过。
本组源码c7018c4已推送，GitHub快速CI37992025376成功。使用
隔离fixture key签署355包验收索引，fresh image root的真实opkg
逐包求解与整批安装/配置已启动，日志common-node-licensed-opkg.log，
尚待结束。正式发布密钥与stable未改动；完整AI源码批次的两个
fixture SDK/base-root隔离修正仍等待明确授权，未改那两个测试。

355包fresh-root验收终态成功：355次独立单包求解、全包实际安装/
configure通过，516个installed版本一致，基础保护文件未变，日志
common-node-licensed-opkg.log。安装后的Node22.23.2/ICU73.2、npm10.9.8
以及npm离线本地tarball安装、lockfile生成、模块加载通过，日志
common-node-licensed-installed-node-separated.log。首次fixture把同一
文件用于user/global npmrc被npm拒绝，仅修正fixture为两个独立
空配置重跑，不改npm程序或包载荷；不据此宣称联网registry或
原生addon安装通过。

升级实验继续覆盖默认入口：opkg_solver_upgrade对无参数及多参数
升级选择批量准备，单包保留原路径，安装/卸载入口不变；批量
函数先保存所有旧状态再标记，避免重复参数污染快照，并去重
所选新包。独立RISC-V工具增量重编完成，签名开启下默认全升级、
显式多包、重复包名预演通过；重复单provider仍不突破旧消费者
约束。普通opkg upgrade实际升级/configure346个候选版本通过，
507 installed一致，基础文件未变；日志
opkg-combined-upgrade-experiment.PPZJeo/target-default-case.log及目录。

创建并附着独立镜像工作树opkg-coordinated-upgrade，分支
codex/opkg-coordinated-upgrade。origin/main为b5ba5a6且缺少已发布
r12-rc2的四个opkg保护补丁；明确fetch发布tag并本地ff到0701ec6，
当前无文件修改，未合并GitHub main/PR3。后续受控补丁应以这份
已发布源码为基线；没有触发整镜像构建或替换设备工具。

镜像分支已正式提交并推送16d8e84，包含opkg第五补丁、七项
自包含升级回归、现有native入口接入及验证记录，保留原四补丁。
完整native入口42项通过（seed22/alternatives8/ownership5/upgrade7）；
同一新测试对旧原生工具失败三项，能捕获原回归。构建机日志
opkg-formal-regression.ljN0yZ/regression-complete.log及regression-old-binary.log。
首次本地因PATH/umask不同触发旧seed测试失败；对齐CI后，补
惰性fixture MD5校验和、显式离线configure，并把held断言限定为
不选新包且状态未变，最终完整通过。生产SHA256/签名未放宽。

新工作树已单独建立GitNexus索引，staged检测确认仅四文件，
影响集中于新增测试流程，未修改桌面或硬件。镜像分支仅push，
未创建PR；gh run list该分支为空，未触发长镜像Action。设备工具
尚未替换；此结果不代替新镜像/SDK配对发布和真实设备验收。

## 常用库扩展候选（2026-10-10）

在 355 包候选上新增七个源码运行库：libbrotli 1.2.0-1、libcbor
0.14.0-1、libedit 20260512-1、libidn2 2.3.8-1、libpsl 0.23.3-1、
librhash 1.4.6-1、libunwind 1.8.3-1。全部使用 r12-rc2 配套 SDK
交叉编译，完成 IPK 打包；提供者表按实际 ELF 登记 13 个 SONAME。
已有 libunistring 和 ncurses 使用 SDK 开发文件与镜像运行库。

RISC-V/QEMU 基本功能测试通过：CBOR 往返及截断拒绝、libedit
引号分词、IDNA Unicode 域名转换、公共后缀及 Cookie 域边界、
Brotli 往返及截断拒绝、RHash SHA256 已知值、本地栈回溯四帧。
这些测试不证明全部算法、协议边界或实机行为。

Autotools 私有依赖投影通过显式 PACKAGE_USE_FEED_DEVELOPMENT=1
启用，原有入口默认保持原路径。真实 SDK 集成回归确认缺失
libidn2 开发依赖会失败，提供后 libpsl 构建成功；整个 SDK sysroot
文件摘要和符号链接在构建前后相同。记录为构建机
common-seven-autotools-isolation.log。

新增配方契约检查已接入共享批次入口；Ubuntu 24.04 网络隔离
容器执行 Shared batch preflight: PASS。Windows 复制的额外提供者
表曾因 CRLF 触发逐行检查失败，验证副本规范化 LF 后重跑通过，
未放宽检查。记录为 common-seven-shared-preflight-lf.log。

完整 362 包配对候选 paired-common-seven-362 已通过生产 finalizer：
前序签名及发布锁、声明依赖、ELF 闭包、目标运行库覆盖、历史
连续性及逐包 CPU0 策略均通过。原始输入 common-seven-raw.64PImUOd
复用已验证 355 包并新增七库，未重编旧依赖。记录为
common-seven-362-finalization.log。

当前索引仅用临时测试密钥签名。镜像中的实际目标 opkg 在签名
校验开启下完成全部 362 包求解、362 次单包求解和实际安装／配置；
523 个 installed，候选版本一致，libc/opkg/Labwc/镜像身份文件未变。
四组 RISC-V 测试从安装根目录加载新增库并全部通过。记录为
common-seven-362-opkg-plan.log、common-seven-362-opkg-install.log 和
common-seven-362-installed-smoke-final-index.log。首次安装后检查
比较原始 libedit 配方版本，遗漏 +tdvpimg 交付后缀；测试改为与
最终索引精确比较，重跑通过，没有改动包或安装结果。

完整快速 CI 原始脚本在 Ubuntu 24.04 网络隔离容器中通过，日志
common-seven-portable.eLnAOlFT/portable-ci.log。AI/common 正式清单
扩展为 88 项，实际 workflow 选包片段和完整候选覆盖检查通过。
正式签名、发布和实机验证尚未完成；未推广 stable。上述七库
补齐本轮发现的缺口，不代表全部常用 Linux 库覆盖审查已经结束。

复查发现 libidn2/libpsl 的 pkg-config Libs.private 残留 SDK/临时
sysroot 的 -L/-R。新增 normalize-pkgconfig-build-paths.py，在
Autotools 安装导出前仅处理明确传入的 sysroot 前缀，移除对应 -R。
保留目标路径及库名；未解决前缀和符号链接拒绝，重复处理幂等。
回归接入共享入口。真实两库重建通过，迁移后的 SDK+staging 使用
pkg-config --static 的依赖参数完成消费者编译、链接和 QEMU 运行。
记录目录 common-idna-portable-development.1ZvSOTbb，首次迁移
验证副本缺测试源码，补齐后 relocated-smoke-complete.log 通过。

重建 runtime payload 与旧 raw IPK 逐字节一致，包括许可证和链接，
common-pkgconfig-runtime-unchanged.json 记录两库；此修复只改变
开发导出。修复后的完整快速 CI 本地通过，记录为
common-pkgconfig-portable.g56bQJg0/portable-ci.log。d811250 的两条
GitHub 快速检查 37998329055、37998362756 通过；开发路径修复的
新提交仍需独立远端 CI。正式发布和实机验收状态未改变。

## 第二轮常用库扩展（2026-10-10）

源码覆盖审查继续补齐十二库：libdeflate 1.26-1、libsnappy 1.3.1-1、
libmpfr 4.2.2-1、libmpc 1.3.1-1、libcap-ng 0.9.6-1、libattr 2.6.0-1、
libacl 2.4.0-1、liburing 2.15-1、libaio 0.3.113-1、libssh2 1.11.1-2、
libnghttp3 1.18.0-1、libngtcp2 1.25.0-1。全部已有配套 SDK 的构建
及 IPK 产物；新增十四个 SONAME，正式 AI/common 清单为 100 项。
这个清单数量不构成全部常用 Linux 库覆盖完成的证明。

压缩、定向舍入、复数运算、内存能力集合、临时文件扩展属性与
ACL、SSH 会话/knownhost 匹配、HTTP3 对象及 GnuTLS TLS1.3 辅助
配置的基本测试通过。Snappy 原自动检测误选 RVV，配方明确关闭
两个 RVV 检测变量，标量构建及 CPU0 检查通过。已有 GMP、GnuTLS、
OpenSSL、zlib 均复用 SDK/镜像。ACL 对 attr 是开发依赖，实际 ELF
未链接 libattr；MPC 明确依赖 MPFR。主机键测试使用合成字节，
不证明真实密钥/网络握手；HTTP3 测试未进行网络握手。libaio 在
QEMU 返回 ENOSYS，只完成请求准备及错误路径检查；liburing 只
验证用户态准备接口，设备内核 AIO/io_uring 验收仍待完成。

libcap-ng 官方 tag 需要执行上游 autogen.sh。Autotools 入口增加
显式 bootstrap 开关与路径约束，已有入口默认不执行。真实 SDK
回归的正常构建通过，穿越/绝对/缺失/含空格路径被拒绝。记录
common-twelve-bootstrap-guard-control.log。旧 Ubuntu 容器缺宿主
工具；临时容器用直接网络安装与 CI 同类的 Autotools，独立配方
副本完成构建。记录 capng-ubuntu-bootstrap.euyNXAWt 下日志；
早期代理及生成 payload 链接冲突失败记录保留，检查未放宽。

旧 374 包配对 paired-common-twelve-374 通过生产 finalizer，其
libssh2 仍为 -1。开发元数据审查在 libssh2 的 .pc 中发现临时目录，
CMake 导出接入同一规范化工具；真实迁移编译/链接/运行通过。
重建 runtime 字节比较失败，进一步确认 __FILE__ 嵌入随机源码
目录。使用显式 SOURCE 路径映射并递增到 -2，两个独立构建的
运行库、.pc 及 IPK 字节一致，无主机/临时前缀；会话测试通过。
记录 libssh2-reproducible.3qzNo3vv/reproducibility-proof.json 和
两次 pack.log；IPK SHA256 为
12cf443f9bb279104532041f90c4a78c9ec75afbfc3c7227d80083e00623613b。

新的原始池 common-twelve-repro-raw.XRj8Hat7 只把 libssh2 -1 换成
-2，其他已验证字节复用，旧候选保持原样。新生产配对及完整
快速 CI 当前在运行，尚未完成新候选安装/实机/发布。

新配对 paired-common-twelve-repro-374 已通过生产 finalizer，日志
common-twelve-repro-374-finalization.log；完整快速检查也通过，日志
common-twelve-repro-portable.YOJFYHzU/portable-ci.log。临时测试密钥
签名验证通过，374 包的实际 opkg 求解/安装回归已启动，尚未终结。

远端只读核对为内核 6.6.36、CONFIG_AIO=y、CONFIG_IO_URING=y，
镜像身份仍是 a8a53102d7ab54c75999e5e08d8802ffbe563c31ae2c9acc9ab38bcbd7babc31，
与候选绑定的 13cab 摘要不同，未在其系统中安装候选 feed。
仅在 /tmp/tdvp-kernel-io-WsAlu8SI 复制测试程序和两库，验证归档
SHA256 后，真实 kernel AIO 和 io_uring 临时文件读回都通过。
设备 BusyBox tar 不支持 -z，改 gzip 管道；timeout 命令缺失，
改 Python subprocess 的 15 秒超时。两次早期尝试未启动测试。
队列及临时文件由程序释放，任务目录已校验准确路径后清理；
原始归档保留在构建机 kernel-async-io-fixture.WsAlu8SI。
镜像摘要测试后不变。此结果仅覆盖旧镜像上的两库/内核链路，
不代替配对新镜像安装、SSH/HTTP3 真握手或正式软件源发布。

最新完整候选安装验收已完成：374 包整体求解及 374 次逐包求解
全部通过，签名校验保持开启；实际安装/configure 验证 374 个
候选版本，共 535 个已安装包，受保护基础文件保持不变。
记录 common-twelve-repro-374-opkg-plan.log 和对应 opkg-install.log。
安装后的根文件系统通过十二库精确版本、十四 SONAME 和十个
RISC-V 测试程序检查。QEMU 的内核调用限制仍按上述独立设备
测试处理。最终索引覆盖全部 100 项配方；十二个交付 IPK 的
许可证/来源文件共 32 份，记录 common-twelve-repro-final-notice-inventory.json。
文件存在与摘要检查不代表完整法律或安全审查。正式签名、发布
及匹配镜像上的整批实机安装尚未完成。

libssh2 真实网络验收补充：使用构建机当前用户启动独立的
127.0.0.1 高端口 OpenSSH 服务，临时 Ed25519 主机键只用于本次
夹具。目标 RISC-V 客户端完成真实握手并核对主机键 SHA256；
错误摘要被明确拒绝（退出码 7）。未进行用户认证或文件传输，
未修改已有 SSH 服务，临时进程/密钥自动清理。记录
libssh2-real-loopback-handshake.log。HTTP3 网络握手仍待验收。

第三轮覆盖审查记录 common-library-family-coverage-374-third-pass.json。
初次按 libNAME.so 扫描漏报带 -1/-2.0 后缀的 D-Bus、Pixman、
GLib、GObject、GIO，已直接核对安装目录排除。仍缺 libev、libzip、
LZO、Jansson、libmnl、libnftnl、libxslt；这些缺口继续处理。
libev 4.33 官方 HTTPS 源码归档 SHA256 为
507eb7b8d1015fbec5b935f34ebed15bf346bed04a11ab82b8eee848c4205aea，
LICENSE 提供 BSD-2-Clause 或 GPL-2.0-or-later 选择。
配套 SDK 构建及目标定时器回调/循环释放测试通过，记录
libev-source-build.h79teqk4/build.log。第一次调用因 staging 环境
变量错误在编译前被拒绝，未放宽入口检查。此库尚未加入整批
交付池，后续仍需 IPK、依赖闭包和安装验收。

第三轮另外六库配方及官方归档已锁定：Jansson 2.15.1、libzip 1.12、
libmnl 1.0.5、libnftnl 1.3.2、LZO 2.10、libxslt 1.1.45。
前五库 SDK 构建通过，记录 common-third-source-build.RDqdo9vA
下各库 build.log；尚未完成 IPK/安装和组合运行验收。
libxslt 配置失败：当前 SDK 实际 libxml2 是 2.13.6，上游
configure.ac 要求 2.15.1。失败路径还检测到宿主 xml2-config
2.9.14，后续必须解决目标检测隔离及上游兼容要求。当前未
替换镜像 libxml2，也未降低依赖断言。1.1.44/45 上游记录包含
CVE-2025-7424、CVE-2025-11731 修复，不能直接回退到 1.1.43
并视作已通过安全验收。

libxslt 新版依赖的解决结果：新增 libxml2-16 2.15.4-1 配方，
官方归档摘要匹配上游 sha256sum。运行 payload 只包含
libxml2.so.16 和 libxml2.so.16.1.4，不包含基础镜像的 libxml2.so.2。
使用上游 CMake 构建及私有 staging 的 libxml2 CMake metadata，
libxslt 1.1.45 构建通过，实际 ELF NEEDED 是 libxml2.so.16。
新版无需调用宿主 xml2-config，也没有降低上游依赖要求。
组合目标程序完成 Jansson 正常/重复键拒绝、Netlink 属性和
nftnl 对象、LZO 压缩解压、ZIP 文件读回、XSLT 文本转换检查；
记录 common-third-source-build.RDqdo9vA/runtime-smoke.log。
新增组共八配方，清单 108 项；数量不构成全范围完成证明。
IPK/安装的 ABI 并存和完整依赖闭包仍待验证。

第三轮八个 IPK 已全部打包通过，记录各 package-pack.log；
third-ipk-dependency-and-base-overlap-proof.json 确认交付路径与
基础镜像无重叠。libxslt 控制文件精确依赖 libxml2-16 2.15.4-1
及 libgcrypt-20，libnftnl 精确依赖 libmnl，libzip 复用 libz/libcrypto。
新增独立第三轮前置策略并接入共享入口，完整快速 CI 本地通过，
记录 common-third-policy-portable.MDTofHeS/portable-ci.log。
直接复制 Windows owner 表的 CRLF 及旧测试目录防覆盖失败
记录均保留，Linux 副本规范为 LF 后在全新目录完成检查。
两个已结束 portable 测试的 repo 副本已按精确路径清理，日志
保留；释放约 744 MiB，可从验证源副本重新生成。
复用 374 个既有 IPK 加入新八包，形成 common-third-raw.6UfomWYu。
382 包生产 finalizer 尚在运行，未把中间结果视作安装或发布完成。

382 包生产 finalizer 已成功结束，记录 common-third-382-finalization.log；
候选为 paired-common-third-382。855c52e 快速 CI 38004800279 通过。
测试密钥签署索引后已启动整体/逐包求解及实际安装，尚未终结；
新增 common-third-installed-smoke.py 用于检查安装版本、九 SONAME、
基础 libxml2.so.2 的链接及字节保留、两个目标运行程序。

QUIC 实网补充：上游 ngtcp2 1.25.0 的未改写 GnuTLS C 示例可用
当前 CPU0 SDK 编译，实际链接 ngtcp2/crypto_gnutls/GnuTLS/libev。
本机临时 aioquic 1.3.0 服务与自签名证书夹具完成 QUIC TLS 握手，
服务收到解密的 GET 请求，记录 http3-network-source.SSP3Awpp/
quic-loopback-runtime.log；宿主依赖仅安装在任务 venv，保存 pip
依赖报告，未改系统 Python。第一次 pip 因已有 SOCKS 代理缺少
支持失败，临时解除代理后直连成功，未关闭证书校验。
上游客户端使用 hq-interop 且未开启对端证书校验。本结果不覆盖
HTTP3 framing、响应内容或证书验证；这些后续门槛保持未完成。

382 包求解/安装完整结果：整体及 382 次逐包求解通过，签名检查
开启；实际 install/configure 验证全部候选版本，543 个已安装包，
基础保护文件未变。记录 common-third-382-opkg-plan.log、
common-third-382-opkg-install.log。安装后第三轮八库/九 SONAME、
目标运行程序通过；旧 libxml2.so.2 摘要和链接保持不变。
另外对两版本同进程 old-first/new-first 加载顺序分别检查：
版本字符串和解析函数地址不同，两个库均独立解析文档成功。
记录 common-third-installed-runtime.log、common-third-installed-xml-parallel.log。
上一轮十二库十个目标程序的安装后回归也通过，记录
common-third-second-pass-regression.log。以上为匹配镜像隔离安装
及 QEMU 运行验收，未称为设备生产源安装或正式发布。
远端只读复查仍为 a8a531 镜像身份，与候选绑定的 13cab 不同，
没有向该设备安装本候选。

匹配候选安装根的 GnuTLS 证书实网检查通过：使用临时本机
OpenSSL TLS 服务及独立测试证书，目标客户端显式加载测试 CA，
校验 localhost，读取加密 HTTP 200 响应；错误主机名和无关 CA
都被拒绝（退出码 7）。记录 common-third-source-build.RDqdo9vA/
gnutls-certificate-loopback.log。未替换系统证书，临时服务/证书
自动清理。首次测试在接收记录时 E_AGAIN 被直接当失败，补上
有限重试及外部超时后通过，证书检查未放宽。本检查覆盖 TLS
传输，HTTP3 的证书与帧验收仍需单独完成。

nghttp3 1.18.0 上游内部协议 suite 已交叉编译并经 QEMU 运行：
61/61 全部通过，无跳过测试，覆盖 QPACK、连接/流状态、HTTP
处理和设置/回调转换。可重复命令为 tests/nghttp3-upstream-protocol-suite.sh
--sdk-root <matched-sdk>；脚本验证锁定归档、CPU0 产物并设置
60 秒运行超时，保存配置/编译/测试日志。记录
tdvp-nghttp3-protocol.7XHITD1v/protocol-suite.log。
此套件链接上游内部静态库，不替换既有共享库/IPK；不能将其
与独立 QUIC 互通、TLS 证书测试拼接成完整 HTTP3 端到端证明。

## 已复现的 cJSON 安全验收缺口（2026-10-10）

当前 libcjson 同时交付 libcjson_utils.so.1。使用
tests/cjson-failed-patch-preservation.c 在 382 包安装根执行：
对 {"x":42} 应用缺少 value 的 replace /x，API 返回错误码 7，
原字段却被删除，程序明确返回 10。官方 1.7.19 源码本机编译
也复现同样行为。记录 cjson-security-source.pYdKR314 下
failed-patch-target.log、failed-patch-upstream.log。
此结果与 CVE-2026-67217 描述一致；GitHub 公告标记 Unreviewed、
未给确定修复版本，因此以本地复现证据作为当前阻断依据。
升级到 1.7.19 不能关闭本问题，源码锁 SECURITY_STATUS 已标记
未通过。CVE-2026-67215 递归问题及其他公告仍待核对。
参考 https://github.com/advisories/GHSA-pr46-97qf-f32c 和
https://github.com/advisories/GHSA-5q3m-r3x7-8phg。
包管理求解/安装成功与安全验收分别记录，382 包候选保持未发布。

补充接口约定核对：上游 cJSON_Utils.h 第 48 行明确说明
ApplyPatches 失败时不保证原子性，并给出复制后应用、成功再
提交的包装方案。前述复现证明此调用风险，不能独立证明
API 违背承诺，也不能单凭这个测试判定必须改写原有接口。
保留原接口，新增 tests/cjson-atomic-wrapper-contract.c 验证官方
建议的所有权处理：失败保留原对象和值，成功提交新对象。
目标 SDK 下升级构建 1.7.19 并运行该包装测试通过，记录
cjson-security-build.AXSosV6R/build.log、atomic-wrapper.log。
配方/源码锁/owner 版本已改 1.7.19-1，纳入上游空指针、重叠
拷贝、复制递归保护及 JSON pointer 索引修复。源码归档摘要为
7fa616e3046edfa7a28a32d5f9eacfd23f92900fe1f8ccd988c1662f30454562。
这个版本仍不能代表 2026 公告全部关闭，深度/循环输入等继续
核对；新 IPK 和整批候选还需重验，已验证旧池保留原样。
接口来源：https://github.com/DaveGamble/cJSON/blob/v1.7.19/cJSON_Utils.h。

1.7.19 新 IPK 已打包，记录 cjson-security-build.AXSosV6R/pack.log；
上游 22 项目标测试全部通过，记录 upstream-suite-binfmt-root.log。
首次 CTest 使用 binfmt 而未带目标加载器根目录失败，指定
QEMU_LD_PREFIX 后同批测试通过，源码和断言未改动。
升级后完整快速 CI 本地通过，记录 cjson-updated-portable.4kLrXVyT/
portable-ci.log。新的 common-cjson-updated-raw.aznyL6KA 只替换
libcjson 的 IPK，旧 382 池保留；新生产配对尚在运行。

新增 cjson-input-boundary-smoke.c 未通过，退出码 5：超范围
JSON Pointer 索引 /a/184467440737095516160 没有被拒绝。
1.7.19 decode_array_index_from_pointer 累加 size_t 时没有溢出
检查，范围外数值可能绕回有效索引。这个边界保持失败状态，
不能依据上游 suite 通过认定此版本所有输入已安全。后续需要
上游修复核对、补丁和明确的边界回归。原接口非原子性与本项
索引边界风险分别处理，不混淆 API 使用约定与数值校验缺口。

索引边界修复已加入包级 0001 补丁：十进制累加前检查
parsed_index > (SIZE_MAX - digit) / 10，并拒绝空索引。使用
等价的 (size_t)-1 保持上游 C89 编译兼容。新版本 1.7.19-2，
新增 patch 宿主依赖；共享 CMake 入口没有修改。补丁函数有
三处调用（查询、分离、应用），GitNexus 未索引上游函数，
人工核对调用范围。首次缺尾部上下文被 fuzz=0 检查拒绝，
补齐上下文后仍以 fuzz=0 应用。
目标边界及官方原子包装用法测试通过；补丁后上游 22 项测试
全部通过，记录 cjson-index-fixed-build.qcgENWqa 下 build-context-fixed.log、
upstream-suite.log。1.7.19-1 的生产配对检查已完成，仅作未修补
对照，未发布；修补 -2 的 IPK/配对/安装仍需单独验收。

修补 -2 IPK 已打包，CPU0 两个 ELF 检查通过；新的原始池
common-cjson-index-fixed-raw.PsKuGVoG 复用其余 381 个已验证 IPK。
生产配对仍在运行，记录 common-cjson-index-fixed-382-finalization.log。
新增 cjson-source-security-policy.py 将补丁内容摘要、unified diff
结构、host patch 依赖、源码锁和两 SONAME 的 -2 owner 纳入
共享快速入口。独立策略及完整快速 CI 本地通过，记录
cjson-index-fixed-portable.2SXOKcj2/portable-ci.log。
首次策略错误地按空格解析带引号字段，独立测试即发现，修正
后再执行完整 CI；包元数据和实际依赖未放宽。
包 README 记录原子包装约定及输入深度限制，避免把原 API
失败时的修改行为当作事务保证。其他安全审查未完成。

修补 -2 生产配对已通过，候选 paired-common-cjson-index-fixed-382；
652ff80 的快速 CI 38006887433 通过。测试签名开启的实际 opkg
升级在旧候选根副本上通过：1.7.18-1 到 1.7.19-2，旧实体库
文件被移除，公共链接指向正确新实体，基础保护文件保持不变，
边界和原子包装回归通过。记录 cjson-index-fixed-upgrade-configured.log。
首次验收停在 offline-root unpacked 状态检查；确认库包没有
维护脚本后添加受控 configure，按 installed 状态检查通过。
未使用 force-depends 或 force-overwrite。新的整批 382 包
求解和 install/configure 复验已启动，尚未结束。

本地补丁来源记录审查保存 local-patch-provenance-audit.json。
安装许可 SOURCE.json 的当前 schema 记录上游归档/源码锁摘要，
没有展开本地补丁摘要。不能据此认定补丁构建没有记录：
build-staging-receipt.py 的 build_inputs 已包含所选配方 patches
的文件摘要，SOURCE_PATCH_* 锁也有校验机制。需要继续核对
这些回执如何随候选交付、能否与实际 IPK 一一绑定。部分包
使用其他来源记录格式，单独缺 SOURCE.json 不代表缺全部来源。
当前不为审查方便修改既有 IPK 字节或重编全部库。

修补 cJSON 的新 382 候选求解/安装已全部通过：整体和逐包
382 次检查保持签名开启，install/configure 验证 382 版本，共
543 个 installed 包，基础保护文件未变。记录
common-cjson-index-fixed-382-opkg-plan.log、对应 opkg-install.log。
最终根下第一轮七库、第二轮十二库、第三轮八库、新旧 XML ABI
两种加载顺序及 cJSON 边界/包装回归全部通过；108 项清单覆盖
仍通过。a5eb3d0 快速 CI 38007200996 通过。

完整上游 GnuTLS HTTP3 示例实际可用当前 SDK 编译，不需要先
升级编译器。构建只选择 gtlsclient/gtlsserver，复用 nghttp3、
libev 开发文件。首次示例携带构建目录 RPATH，下载虽通过，
不能据此认定使用交付库。设 CMAKE_SKIP_RPATH=ON 重链接后，
CPU0 产物检查通过（24 ELF），用最终候选安装库重跑下载，
20,800 字节逐字节一致。脚本加入 RPATH/RUNPATH 拒绝检查，
记录 http3-full-examples.8PjufrUg/http3-installed-libraries-download-guarded.log。
使用 --quiet 禁止示例输出 TLS secrets；临时服务/证书/目录
清理。上游客户端未启用对端证书验证，本结果只覆盖真实
HTTP3/QUIC 和下载内容，严格证书验证仍需接入同一链路。

严格证书验证已接入测试用独立上游示例副本：上下文通过
gnutls_certificate_set_x509_trust_file 加载显式临时 CA，会话调用
gnutls_session_set_verify_cert 校验显式主机名，缺任一输入拒绝
初始化。生产库配方/SDK/设备证书未修改。改动的两上游方法
未被 GitNexus 索引，人工限制在 gtlsclient 测试初始化链路；
修正 fixture diff 上下文后仍以 fuzz=0 应用。
严格示例构建与 CPU0 检查通过（24 ELF），拒绝运行搜索路径。
最终交付安装库上正确 CA/localhost 下载 16,000 字节一致；
错误主机名、无关 CA 均出现证书/crypto 拒绝且没有下载内容；
缺少显式信任参数时进程失败关闭。记录 http3-strict-trust.AROVXwYf/
strict-http3-download-final.log。通过 quiet 抑制 secrets，临时
服务、证书及目录清理。此结果关闭本地 HTTP3 严格 TLS 链路
验收缺口，未替代设备生产源验收或全包安全/许可证审查。

嵌入式常用库补充审查：embedded-system-library-coverage-382.json
确认 GPIO/kmod/udev/systemd/ffi 等运行及开发输入已存在，不重编。
serialport、fdt、LMDB 等仍有缺口，继续补齐。libserialport 0.1.2
官方归档摘要已锁定，LGPL-3.0-or-later COPYING 已检查；匹配 SDK
构建和目标配置对象读写通过，记录 serialport-source-build.0c9KFmxK。
未打开串口或修改硬件。新增 libserialport.so.0 owner；该库仍需
IPK 和完整候选安装验收，未计入已有 382 包通过结果。
DTC 1.8.1 官方归档 SHA256 为
23526015a6f1550e0541a53fe7acea1b5a11e3697cdf3a3bdc076abc38f6045d，
LMDB_0.9.36 官方 tag 归档 SHA256 为
90a595ea500074af61b213464452d8d212405261094667a686357467ae7b57b9。
来源文件保留 embedded-extra-sources.zaiRbkoO，尚未称为构建完成。

libfdt 1.8.1、LMDB 0.9.36 配方已完成目标构建；fdt-lmdb-source-build.uXDv9K4E
保留两库日志。libfdt 仅构建/安装库和开发头，不修改启动树；
LMDB 保留默认共享 robust mutex，不关闭锁。QEMU 上环境初始化
返回 ENOTSUP，strace 确认 set_robust_list 返回 ENOSYS；没有将
该失败当作运行验收成功或改锁配置绕过。
在真实 K230 上任务 /tmp/tdvp-fdt-lmdb-uXDv9K4E 临时加载两库，
libfdt 树/坏头检查、LMDB 回滚/提交/关闭后重新打开读取通过。
归档 SHA256 为
8c7bb1fcfc13a2a1a82e11f9afb6de89914a3a8e37df47f2703ba37dc7b082cf，
上传后先验摘要，测试设置 15 秒超时；目录已按精确路径清理，
构建机原始归档保留。镜像摘要测试前后仍为 a8a531，因此只
证明临时库硬件链路，不代替配对镜像安装。未打开硬件串口、
申请 GPIO 或干预桌面。新增 libfdt.so.1/liblmdb.so owner 和三库
必需组（111 项）；仍需新 IPK、闭包和安装验收。

三库 IPK 已打包，发现 libfdt 通用 BSD 文本使用版权占位符、
LMDB 实现含独立作者声明后，为两库新增从编译组件头注释
提取的实际 copyright/SPDX notice，并纳入 SOURCE.json notice
摘要。提取工具拒绝越界、符号链接及覆盖已有输出，回归通过。
两库修订号递增为 libfdt 1.8.1-2 / liblmdb 0.9.36-2；与此前 -1
IPK 比较运行库字节完全相同，不把 notice 改动称为代码修复。
开发 staging 同时保留 notice，LMDB 增加 pkg-config 开发元数据。
新增嵌入式三库前置策略，完整快速检查本地通过（较早记录
common-embedded-portable.bTCJdqRd），新增策略后的运行记录为
common-embedded-policy-portable.Y32pu8ev。新原始池
common-embedded-raw.Ho2VMvy2 共 385 包，复用原 382 个 IPK，
生产配对已通过，日志 common-embedded-385-finalization.log；新增
策略后的完整快速检查亦通过，记录上述 Y32pu8ev/portable-ci.log。
测试签名开启的 385 包实际求解、逐包和安装已通过，日志
common-embedded-385-opkg-plan.log / common-embedded-385-opkg-install.log；
546 个已安装记录，受保护基础文件保持不变。111 项必需清单在
最终索引中齐全。已安装根上的前三组接口回归通过；ACL 回归需
在拥有安装根写权限的原容器中执行，普通宿主用户无法创建临时文件。
当前不宣称完整法律审查或配对设备安装已经完成。

新增 libmd 1.2.0-1 和 libbsd 0.12.2-1，官方 release 归档摘要已锁定，
完整 COPYING 作者与多许可证清单随包投影。构建记录
common-bsd-source-build.tmL3O2Zq。libbsd 明确依赖 libmd，启用
feed development 合并；上游无版本 libbsd.so 为链接脚本，仅留于
开发 sysroot，运行包使用版本化 ELF。两库交叉编译、SHA256 已知值、
strlcpy/strlcat 截断及 strtonum 正常/越界测试通过。使用合并开发
sysroot 的正常 -lbsd/-lmd 消费者编译、链接和目标运行通过。
两个 IPK 已通过 CPU0 ELF 与基础镜像路径覆盖校验。113 项必需配方
加入 common-portability 组；387 包完整配对仍在执行，日志
common-bsd-387-finalization.log，不将其计为已完成安装。

后续 387 包配对已通过，113 项清单最终索引齐全；隔离测试签名开启
的整源/逐包求解和实际安装仍在执行，记录 common-bsd-387-opkg-plan。
新提交 368900f 的快速 CI 38012013593 已成功。

新增 libmaxminddb 1.14.1-1，官方 release SHA256 锁定为
ca5c87d41339f8bc4daabb53e8a9356b3c995f2d2419b85d7bff823b2ecc252d。
上游 1.14.0 已加入解码资源限制，1.14.1 为当前补库选择，完整安全
审查仍未完成。构建记录 mmdb-source-build.VIozAiZu，Apache-2.0
LICENSE 投影、CPU0 ELF 和基础镜像路径覆盖校验通过。使用同一
锁定归档中的 GeoIP2-City-Test.mmdb，目标消费者 IP 查询、GB 国家
字段读取和无效地址错误检查通过，不附带或宣称生产地理数据库。
新配方与归属表加入清单（114 项），完整共享前置检查通过。复用
387 个原始 IPK 形成 388 包候选，配对正在执行，日志
common-mmdb-388-finalization.log；尚未称为正式签名发布或实机安装。

387 包实际整源求解、387 次逐包求解、安装与配置全部通过，548 个
已安装记录且受保护基础文件不变；随后 BSD 安装后检查发现 libmd
运行包含无版本开发链接 libmd.so，因此该新增库验收未通过。收紧
运行 glob 并递增 libmd 1.2.0-2，新 IPK 内容验证仅有版本化库；开发
staging 仍保留链接文件。新前置策略包含这一约束并通过，日志
common-libmd-runtime-only-preflight.log。修正后的 388 包候选正在
配对，记录 common-mmdb-libmd-fixed-388-finalization.log，不将旧候选
的安装成功用于证明此次修订完成。6320865 快速 CI 38012407820 成功。

修正候选的声明闭包拦截旧 libbsd (= libmd 1.2.0-1) 控制信息；为此
libbsd 递增 0.12.2-2，复用已有运行库重新打包，实际控制归档确认
Depends: libmd (= 1.2.0-2)。两个 -2 修订组成新 388 包候选，原始池
common-bsd-revision2-raw.miUmxlpO，配对仍在执行，日志
common-bsd-revision2-388-finalization.log。完整共享前置检查通过，
日志 common-bsd-revision2-preflight.log。旧候选和失败日志保留作对照。

修正后 388 包整源、388 次逐包求解、安装和配置通过（549 个已安装
记录），受保护基础文件不变。BSD 安装后版本/依赖/notice/无开发
链接及目标消费者回归通过，记录 common-bsd-revision2-388-opkg-plan。

新增 libkrb5 1.22.2-1 与 libtirpc 1.3.7-1。Kerberos 官方归档 SHA256
3243ffbc8ea4d4ac22ddc7dd2a1dc54c57874c40648b60ff97009763554eaf13，
TI-RPC 官方归档 b47d3ac19d3549e54a05d0019a6c400674da716123858cfdb6d3bdd70a66c702。
构建记录 kerberos-sdk-build.e4DcOg3T 与真实配方运行
kerberos-recipe-build.npWVe4wl。构造/析构和 positional printf 配置
缓存值先通过当前 SDK 目标运行测试；复用 SDK com_err，关闭上游
RPATH 后重建，保持 GSSAPI 功能。Kerberos principal/GSSAPI 名称生命
周期、XDR 整数/字符串往返及 Kerberos GSS 机制枚举通过，没有联系
KDC 或启动服务。TI-RPC 配置明确 GSS-API support: yes。
Kerberos 库及插件使用已有 runtime 包类型（16 个新 ELF），TI-RPC
共享库单独包；开发导出含 krb5-config，系统认证配置和守护服务均
未随运行包安装。完整 NOTICE/README 与 TI-RPC COPYING 保留，完整
法律、安全和网络认证审查仍待完成。Ubuntu 24.04 验证容器确认
compile_et/comerr-dev/bison 存在，CI host tools 同步补入 comerr-dev。
两个 IPK 的 CPU0/基础覆盖校验及完整共享前置检查通过。116 项必需
清单加入 authentication-rpc 组，390 包配对仍在执行，原始池
common-kerberos-rpc-indexed-raw.hdsvtCE3，日志
common-kerberos-rpc-390-finalization.log，不计为正式签名/设备安装通过。

390 包配对与 116 项最终索引覆盖随后通过。隔离测试签名开启的整源
求解、390 次逐包求解、安装和配置通过（551 个已安装记录），受保护
基础文件保持不变。Kerberos/RPC 安装后回归最初误将原始版本与配对
版本直接比较；实际最终版本含 +tdvpimg，并且索引/已安装记录相同。
测试修正为同时验证 X-TDVP-Source-Version、最终安装版本一致，以及
消费者精确依赖最终 provider。修正后 11 个无 RUNPATH 库、插件、notice
及两个目标消费者全部通过。记录 common-kerberos-rpc-390-opkg-plan。
这是离线根安装结果，仍不代替正式签名或配对设备验收。

talloc 2.5.0 和 tevent 0.17.2 官方归档摘要分别为
912afa237510ae542a7733998eb18a12bcda35ab6729c8e2ddb43e8d0ebab007 与
e53b1ac288d017d66dde0471cd429a806168ecf07179d7f019572d7a7e05f0d6。
源码审查/构建记录 talloc-tevent-source-review.9UOGojQa；两库匹配 SDK
构建安装及层级内存析构/定时器派发通过。Waf iconv 默认宿主搜索目录
改为目标 sysroot；PKGCONFIG 明确使用限定合并 sysroot 的宿主工具，
tevent 禁止捆绑另一份 talloc。新增配方构建同时补全锁定的 GNU GPL-3.0
文本与实际 copyright 声明；配方直接重跑仍在执行，尚未计为 IPK/
完整候选/实机验收完成。

后续真实配方运行 talloc-tevent-recipe-build.cejuU4dp 已通过：talloc
提取 9 个源文件作者声明，tevent 提取 22 个，均投影 LICENSE、锁定
GPL-3.0.txt 与 TDVP-COPYRIGHT-NOTICE 三份材料，SOURCE.json 记录摘要。
配方目标消费者内存析构/定时器回归通过；两个 IPK 的 CPU0 ELF 和
基础路径覆盖检查通过，完整共享前置检查日志 talloc-tevent-preflight.log
通过。当前是 standalone C 库，Python 模块未包含在此包中。新增
common-memory-events 必需组（118 项），392 包配对正在执行，原始池
common-talloc-tevent-raw.IlkzByee，日志 common-talloc-tevent-392-finalization.log。
新增安装后回归检查最终/source 版本、精确依赖、无开发链接以及三份
notice 的实际 SHA256，再运行目标消费者；该新增安装回归尚未完成。

392 包的签名开启整源、392 次逐包求解、安装和配置随后通过（553 个
已安装记录），受保护基础文件保持不变。talloc/tevent 安装后回归
最终/source 版本、精确依赖、三份 notice 摘要、无开发链接及目标
析构/定时器全部通过，记录 common-talloc-tevent-392-opkg-plan。

新增 libnsl-3 2.0.1-1，官方归档摘要
5c9e470b232a7acd3433491ac5221b4832f0c71318618dc6aa04dd05ffcd8fd9，
记录 nsl-source-review.LPAjuECv 和 kerberos-recipe-build.npWVe4wl/libnsl-build.log。
配方使用声明的 TI-RPC 开发文件，交叉构建、CPU0 ELF/基础路径覆盖、
完整共享前置检查通过。SONAME 为 libnsl.so.3，不覆盖 glibc libnsl.so.1。
目标共存测试同时加载两库，旧 yperr_string 按实际 GLIBC_2.27 兼容
版本使用 dlvsym，新旧接口地址分离，协议错误映射和字符串调用通过。
COPYING/README 保留，完整源版权与安全审查仍待完成。119 项清单
加入 common-nis-compatibility，393 包配对正在执行，原始池
common-nsl-raw.rNMlqYWR，日志 common-nsl-393-finalization.log。安装后
测试会核对版本、最终 TI-RPC 精确依赖、旧库字节/链接和目标消费者；
当前新增安装验收尚未完成。

新增 libgdbm 1.26-1，锁定 GNU 官方归档摘要
6a24504a14de4a744103dcb936be976df6fbe88ccff26065e54c1c47946f4a5e。
配方启用传统 DBM 兼容接口，记录 gdbm-recipe-build.JtQ3Y18n，
libgdbm.so.6/libgdbm_compat.so.4 构建、持久化重开及兼容读写/删除
目标测试通过，测试临时文件清理通过。COPYING/AUTHORS 保留；两个
ELF 的 CPU0/基础覆盖与完整共享前置检查通过。120 项必需清单加入
common-dbm，394 包配对正在执行，原始池 common-gdbm-raw.HJOtH8Fx，
日志 common-gdbm-394-finalization.log，安装与完整审查仍待完成。

用户批准两项非 ELF 夹具隔离修复后，显式空基础根方案被生产覆盖
检查正确拒绝（没有动态对象）。最终使用独立临时父目录下的真实
SDK 链接视图，保留 SDK 字节/摘要校验，避免自动发现外部 target。
build-staging-receipt-integration 与 split-provider-builder-integration
在 Ubuntu 24.04 下、真实 SDK 无/有相邻 target 布局全部通过。
新增 non-elf-sdk-layout-integration 自动覆盖两种布局和调用者传入
base-root 的隔离；导出/导入、字节篡改拒绝、split 临时 payload
清理与 IPK 消费检查保留。生产构建器、运行闭包和覆盖校验器未改动。

### 2026-10-10 HEVC/HEIF 正式配方验证进展

libde265 1.1.3、x265 4.3 和 libheif 1.23.6 的正式配方已在
Ubuntu 24.04 离线容器中完成交叉构建。x265 按上游 multilib 流程
合并 8/10/12 位静态库，静态链接消费者在 RISC-V QEMU 中完成三种
位深的 API、编码器初始化和头生成测试。版权收集覆盖 222 个源码文件。

HEIF 正式产物完成 HEVC（x265/libde265）和 AV1（AOM）无损平面
图像往返测试，逐像素核对 Y/Cb/Cr，并拒绝截断容器。正式 ELF
链接依赖包含 x265、libde265、AOM、JPEG、OpenJPEG 和 OpenJPH，
没有 RPATH/RUNPATH。配置确认 JPEG 2000 与 HT-J2K 后端为内置。
这些证据来自构建机 QEMU，正式 IPK 安装和板上验收仍待完成。

初次配置的 libsharpyuv 缺失提示来自验证 staging 的开发投影缺口。
现有 libwebp-7 1.5.0-2 IPK 已包含 libsharpyuv.so.0.1.1，不能据此
认定运行库缺失或新增重复 provider。HEIF 配方已声明 libwebp-7
构建依赖。随后从已有 SciPy 私有 sysroot 找回开发头文件，SharpYUV
运行库与候选 libwebp-7 IPK 字节一致。修正 include/webp/sharpyuv
路径后，HEIF 正式配方重新构建通过，ELF 依赖含 libsharpyuv.so.0；
两条图像往返及截断容器测试再次通过。正式开发收据复用仍待验证，
本地恢复过程没有生成或伪造已验证的 imported receipt。

412 包候选的整批与 412 个单包 opkg 规划通过；实际 install/configure
完成，候选版本一致，基础受保护文件未变，测试根共安装 573 包。
安装后的 AOM、libyuv、AVIF 消费者测试通过。完整共享前置检查在
Ubuntu 24.04 下通过，新增 HEIF/HEVC policy 已接入同一入口。

三项正式原始 IPK 的 SHA256：

- libde265 1.1.3-1：286cd9cd26b6c9e6a1d367b6fffa431f423f78dde79aeffa36b97e35ab82574c
- libx265 4.3-1：0802c971e24d0aceb4a97dfed853250f9918cdd8e612add6ed424e142b21729d
- libheif 1.23.6-1：320cc166fea0fef4d73f9047438f4f371799d7277e1279b28a6a71c2048553e1

415 包配对组合检查已通过，包含 CPU0 ELF/静态对象策略、镜像引用、
覆盖与历史连续性检查。隔离测试密钥签名后的完整 opkg 规划与安装
验收已启动，正式签名发布和板上验收仍待完成。

### 2026-10-10 dav1d 独立 AV1 解码器

新增官方 dav1d 1.5.3 锁定归档，SHA256 为
732010aa5ef461fa93355ed2c6c5fedb48ddc4b74e697eaabe8907eaeb943011。
正式 Meson 配方在 Ubuntu 24.04 容器中离线构建通过；该验证容器
缺少 Meson，使用只读挂载的构建机 Meson 1.7.0 纯 Python 工具。
目标编译器始终来自配对 SDK，关闭汇编、CLI、在线测试数据及示例。
产物为 libdav1d.so.7.0.0，许可证投影完成。

AOM 编码已知 16×16 I420 图像，dav1d 解码后尺寸、位深、布局和
Y/U/V 每个像素均匹配；截断 AV1 序列头被拒绝。独立配方 policy
及源码锁验证通过并接入共享前置入口。正式 IPK、安装后的消费者、
高位深/多帧测试及完整组件版权/安全检查仍待完成。

dav1d 正式 IPK 已生成并通过 CPU0 ELF 策略，SHA256 为
e13c69db926545a49a62e8a39119156036826152eb4af9cd5e59f16f2d22f653。

### x265 静态开发依赖闭包补充

此前静态 API 测试手动添加 pthread，不能证明 pkg-config 声明完整。
进一步仅使用 x265.pc 私有链接参数时，glibc 2.33 下出现 pthread_join
缺失。上游生成 .pc 时主动移除 pthread，配方现对开发投影补入
-pthread。独立 x265-pkgconfig-static-integration 回归仅从 pkg-config
获取依赖，8/10/12 位静态消费者已通过，无需重编运行库 IPK。
已构建验证 staging 的 .pc 同步修正；完整配方重跑和新开发收据仍待完成。

随后完整 x265 配方复跑通过，新生成开发文件直接通过 pkg-config
静态消费者回归，运行库未添加新的功能变更。正式开发收据仍待验证。

### 2026-10-10 gperftools 常用分配器/分析基础设施

新增 gperftools 2.18.1 官方发布归档，SHA256 与发布资产一致：
d18d919175f9e4d740ace6b52f0f4f91284160c454e91b36ffd6456282a02206。
正式配方在 Ubuntu 24.04 离线容器中完成全量共享库构建，包括
tcmalloc、debug allocator、CPU/heap profiler，显式启用 libunwind。
本地复用已有 libunwind 开发投影；按正常打包 strip 后，其运行库
与候选 libunwind IPK 字节一致，没有重编该依赖或伪造开发收据。

目标消费者在 RISC-V QEMU 中完成 malloc/realloc 数据保持、heap
profile 生成和 CPU profiler 测试，取得 24 个采样。独立分析报告
解释、异常/多线程测试、正式 IPK 安装及完整版权/安全审查仍待完成。

gperftools 原始正式 IPK 已生成，6 个运行 ELF 均通过 CPU0 策略。
SHA256 为 2b84e42aa6895c1fba69c067eb072b572bf871c2489ae19e578b9c8cacb91094，
自动运行依赖明确为 libunwind 1.8.3-1。新增 policy 及全量共享
前置检查在 Ubuntu 24.04 下通过；上述未完成验收项仍然保留。

### 2026-10-10 415 包安装与 JPEG XL 依赖进展

415 包候选已完成整批/逐包规划和实际 install/configure，版本一致、
基础受保护文件未变，共安装 576 包。安装后的 HEVC/AV1 HEIF 平面
图像往返、截断容器拒绝及 x265 8/10/12 位 API 均通过，许可证
证据和静态开发文件分离检查通过。这些结果来自构建机隔离根/QEMU。

Little CMS 2.19.1 正式配方及 ICC 序列化、RGB/Lab 转换、截断 profile
拒绝测试通过。Highway 1.2.0 初次纯 scalar 后端的 contrib 排序
触发上游断言，改用无 RVV 的软件仿真 128 位向量后，aligned allocation、
向量 API 算术及 contrib 排序通过。锁定的 CMake 输入保留通用 ABI
和路径规范化参数；随机源路径修正后重构建通过。

JPEG XL 0.12.0 正式配方和源码锁已添加，声明独立 Highway、Little CMS、
Brotli 开发依赖，关闭在线获取。正式离线构建已完成，许可证投影
成功。目标消费者完成 16×16 无损 RGBA 编解码，包含 alpha，输入
输出逐字节一致；截断码流被拒绝。正式 IPK、安装后验收及两个新
依赖的完整审查仍待完成。

### CPU0 ISA 打包门禁补充

Highway 软件仿真消费者在默认 QEMU 下通过后，正式 IPK 的 CPU0
ISA 门禁发现 libhwy_contrib 仍带 RVV 属性并正确拒绝。初次只加入
rv64imafdc/lp64d 参数仍失败，进一步定位到上游 HWY_CMAKE_RVV
默认 ON 会追加 rv64gcv1p0。配方已显式设为 OFF，并在锁定 CMake
输入中保留 CPU0 编译/链接 ISA。Highway 与 JPEG XL 重新构建和
ISA 验证正在进行；此前 QEMU 结果不构成 CPU0 兼容验收。
不兼容的 Highway IPK 没有生成或进入候选源，ISA 校验器未放宽。

关闭上游 RVV 开关后，Highway 两个运行库和 JPEG XL 三个运行库
均通过 CPU0 ISA 校验。Highway 消费者在 qemu-riscv64 的 rv64,v=false
配置下通过分配、算术和 contrib 排序测试。Little CMS 正式 IPK
通过 CPU0 检查，SHA256 为
df59531b1c770b11e760cef2435d203be3d8901849f78ca280ecb8b61f4ec6d0。

JPEG XL 消费者也在 rv64,v=false 配置下通过无损 RGBA/alpha 与
截断码流测试。三个正式原始 IPK 均已生成，CPU0 策略检查通过：

- libhwy 1.2.0-1：78472cd206a1d9bac4ae199c1640a2c1ea0ac821de7ed896cc0e3630f985ed78
- liblcms2 2.19.1-1：df59531b1c770b11e760cef2435d203be3d8901849f78ca280ecb8b61f4ec6d0
- libjxl 0.12.0-1：0117f84bddf1726a6b6545da212de5ddfb46cd7399c3ef0334a0ce155e637fd3

完整共享前置检查在 Ubuntu 24.04 容器中通过。以已验收的 415 包
原始池加入 dav1d、gperftools 和本组三个 IPK，启动 420 包配对组合
检查。原始 IPK 使用硬链接避免重复存储，索引和最终目录均独立生成。
最终组合、安装后新消费者、正式签名发布和板上验收仍待完成。

随后 420 包配对组合检查通过；已启动隔离测试密钥签名后的 opkg
整批/逐包规划和实际安装。JPEG XL 配方提交 d3df408 的快速 CI
已成功，完整源码批次仍受待批准的 Eigen 修复影响。

完整 Boost 的缺口已确认：当前 MP11 提供者不包含 filesystem、
thread、regex、serialization 等运行库。官方 Boost 1.82.0 归档
已下载并匹配官方 SHA256
a6e1ab9b0860e6a2881dd7b21fe9f737a095e5f33a3a874afc6a345228597ee6。
完整归档中 31 个 MP11 头文件与现有 boost-mp11-dev IPK 字节相同。
这只证明对应头文件身份，完整 Boost 构建、Python/ICU 等依赖兼容、
正式 provider/开发投影、安装和安全审查仍待完成。

Boost 全库交叉构建探测已在 Ubuntu 24.04 离线容器启动，目标
architecture=riscv/address-model=64，显式 rv64imafdc/lp64d，所有目标
编译器来自配对 SDK。Python 开发路径指定到目标 staging，ICU 指向
SDK 目标目录，未关闭对应库。当前两处开发头文件缺失，探测输出
不代表完整功能可交付；结束后记录实际库清单与失败项，再补输入。

首轮全库探测退出 1，主要失败项为目标 Python 的 pyconfig.h 缺失。
已有 CPython 3.13.3 缓存运行库正常 strip 后与候选 libpython3.13
3.13.3-2 IPK 字节相同，恢复对应开发头文件后，Boost.Python 3.13
针对性构建通过。完整 Boost 尚未重新验收，不以该子项替代全库门禁。

旧 ICU 开发缓存运行库 strip 后与当前候选 libicuuc 不同，未视作
匹配运行产物。另从官方锁定 ICU 73.2 源码验证了 195 个缓存公共
头文件字节一致；后续仅复用已验证的公共头文件，并使用当前 IPK
运行库验证消费者。正式开发收据与旧运行库差异解释仍待完成。

随后从当前候选四个 ICU IPK 提取真实运行库与 SOURCE.json/许可证，
建立局部测试开发投影，没有使用不同字节的旧 ICU 运行库。补齐
输入后全库 Boost 探测退出 0，38 个版本化运行库路径生成，ICU
探测为 yes。CPU0 门禁验证 38 个新 ELF 和 21 个静态对象成员通过。

Boost 实际消费者在 rv64,v=false 的 RISC-V QEMU 下完成 filesystem
目录/文件、thread join、普通正则、ICU 大小写正则、序列化往返和
Unicode locale NFC normalization 测试。该结果证明所测功能，完整
Boost 正式配方、运行包/开发文件分离、Python 扩展运行、安装后测试
和完整法律/安全审查仍待完成。

### 2026-10-10 420 包安装后消费者与 Boost.Python

420 包候选整批/逐包规划及实际 install/configure 已完成，候选版本
一致、基础受保护文件未变，共安装 581 包。安装后的 JPEG XL、
Highway、Little CMS、dav1d、gperftools 消费者在 rv64,v=false 配置下
通过；gperftools CPU profiler 本次取得 25 个样本。正式签名发布
和板上验收仍待完成。

Boost.Python 扩展在上述安装根的目标 CPython 3.13 中完成导入、函数、
类状态、C++ 异常转换与错误参数拒绝测试。夹具最初预期 RuntimeError，
实际 std::invalid_argument 对应 ValueError，修正该断言后通过；
没有修改库实现。Boost 运行库仍来自交叉构建探测目录，尚未由正式
IPK 安装，不能将这项测试记为完整 Boost 包管理交付通过。

### Boost 完整压缩后端与正式配方

Iostreams 初次产物只有 zlib/zstd，进一步确认 bzip2/LZMA 开发输入
缺失。锁定源码与缓存 bzlib.h、lzma.h 及 14 个 LZMA 子头文件字节
一致。两个旧 IPK 有许可证文本但缺 SOURCE.json，现有 split 提取器
正确拒绝；未放宽该生产提取门禁。局部消费者验证采用已签名安装
验收的 420 测试根运行库，开发收据/来源元数据缺口仍待解决。

补齐测试输入后 Iostreams gzip、bzip2、LZMA、zstd 四个后端完成
逐字节压缩/解压往返。新增 libboost 正式配方明确声明 Python、ICU、
压缩和 SDK zlib 开发依赖，宿主机 B2 bootstrap 清除目标编译环境，
目标编译显式 rv64imafdc/lp64d。运行 payload 仅投影版本化共享库，
头文件、链接名和 CMake 开发文件进入 staging。已启动干净源码的
正式离线配方构建，尚未证明该最终构建、IPK 或安装验收通过。

正式配方随后完成，38 个共享运行库通过 CPU0 ISA 门禁。使用新
开发投影和新运行库复测 C++/ICU 与四种压缩后端全部通过，MP11
31 个头文件仍与已有包字节一致。CMake 消费者通过 Boost CONFIG
目标接口以及显式 ICU 依赖完成构建和目标运行；测试适配层在原 SDK
工具链后追加 feed staging 查找/链接根，没有改动已发布 SDK。

初次打包自动依赖没有捕获 Boost.Python 所需解释器 ABI（其 Python
符号由宿主解释器提供），现显式声明 libpython3.13 3.13.3-2 并补
policy 回归，仅重新打包元数据，没有重编运行库。最终未发布原始
IPK SHA256 为 5179eaa02dfac65c2611e037bcc546d150734358c990778adf5fd5602de0a905。
运行依赖另包含 ICU、zlib、bzip2、LZMA、zstd，38 个 SONAME 已登记。
正式 IPK 安装后的消费者与完整开发收据/法律安全审查仍待完成。

包含 Boost 配方与新回归的全量共享前置检查在 Ubuntu 24.04 下通过。
已将最终 Boost IPK 加入已验收 420 包原始池，启动 421 包镜像配对
组合检查。原始库文件通过硬链接复用；未编译镜像、未签名发布或
推广 stable。完整源码批次的 Eigen 阻断仍待用户批准修复。

正式配方的 Boost.Python 开发投影再次完成扩展交叉编译；使用已安装
420 包测试根的 CPython 3.13、正式 staging 的 Boost 运行库，在
rv64,v=false 下通过导入、函数、类状态、异常转换及错误参数拒绝。
产物位于构建机 boost-formal-python-consumer.igBrbK。该结果补齐正式
配方消费者证据；Boost IPK 安装后验证和完整开发收据检查仍未完成。

### libssh 0.12.2 正式源码构建

官方源码签名与发布密钥指纹 88A228D89B07C2C77D0C780903D5DF8CFDD3E8E7
一致，SHA256 为 49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f。
Ubuntu 24.04 离线正式配方构建通过，生成 libssh.so.4.12.0，投影
COPYING、BSD、AUTHORS。客户端、服务端、SFTP、GSSAPI、zlib、PCAP
构建开关保留启用；动态依赖包含 OpenSSL、zlib、Kerberos，未发现
RPATH/RUNPATH。独立 CPU0 无 RVV 消费者完成 Ed25519 密钥生成、
公钥导入导出比对、SHA256 指纹及 session/server 对象生命周期测试。
消费者位于构建机 libssh-consumer.iw0jPV，完整共享前置检查通过。
首次前置检查因验证副本 CRLF 精确匹配失败，规范化后原断言通过。
网络认证、SFTP 传输、正式 IPK 安装、完整来源/许可证/安全审查仍待完成。

libssh 正式 IPK 的 CPU0 检查通过，SHA256 为
1ff08c54e569d721aad089171f0b5d05c95bcde955725c17d51f42481fd9cd58。
自动依赖包含平台 ABI、libcrypto-3、libz、libkrb5、libcom-err-2。
新增目标消费者通过构建机 loopback SSH 握手，取得的 Ed25519 主机
SHA256 指纹与本机 /etc/ssh/ssh_host_ed25519_key.pub 完全一致。
测试未发送凭据，不构成用户认证或 SFTP 传输通过；消费者产物位于
libssh-handshake-consumer.SjnoAc。422 包组合检查正在运行，尚未发布。

422 包组合检查随后通过，生成 paired-common-libssh-422 未发布候选。
已用隔离测试密钥启动真实镜像 opkg 的整批/逐包规划及安装配置验收；
common-libssh-422-opkg-plan 尚未完成，不能记为安装通过。正式发布
密钥未使用，设备和 stable 信任配置未改动。

421 包候选的真实镜像 opkg 整批规划与全部 421 个单包规划通过，
签名验证保持启用，受保护基础文件及状态文件未变化；安装/配置仍
在运行，尚不能记为完整安装验收通过。

Berkeley DB 官方 HTTPS 源码 db-18.1.40.tar.gz 已下载，计算 SHA256
0cecb2ef0c67b166de93732769abdeba0555086d51de1090df325e18ee8da9c8。
归档 README 确认 18.1.40，LICENSE 为 AGPLv3，另有 EXAMPLES-LICENSE。
构建机审查目录 berkeleydb-source-review.tPVPZX；尚未获得独立官方
摘要/签名核验，不构成完整来源审查通过。C/C++ API、事务与持久化、
复制及兼容 API 的交叉构建/运行验收仍待实现。

421 包安装/配置随后通过：全部候选版本一致，共安装 582 包，
基础受保护文件未变；Audacious、NetSurf、Vim 的六个已审计离线
维护钩子完成。该结果属于构建机隔离根验收，板上匹配镜像验证与
正式签名发布仍待完成。

安装后的 421 根使用仅含 ROOT/usr/lib、ROOT/usr/lib64、ROOT/lib 的
LD_LIBRARY_PATH 复测 Boost 正式消费者，未使用 staging 或探测运行库。
C++ filesystem/thread/regex/ICU/serialization/locale、四种 Iostreams
压缩往返、CMake 消费者、Boost.Python 目标 CPython 3.13 扩展全部通过。
产物目录 boost-installed-consumers.Vporxp。首次调用遗漏 filesystem
夹具所需的新目录参数，补齐后通过，无库实现修改。此项证明已安装
Boost 运行文件的所测功能；开发收据及板上验收仍未完成。

Berkeley DB 正式构建通过。全量 install 的上游文档目录缺失导致首次
安装失败，配方改用 install_include/install_lib 后干净重跑成功，
未修改运行库功能。C++ 事务消费者在 rv64,v=false 下完成 B-tree
put/get、commit/abort 与关闭后持久化重开，目录 berkeleydb-consumer.kCTpeH。
DbEnv(0) 夹具构造歧义修正为显式 u_int32_t 后通过，无上游修改。
两个运行 SONAME libdb-18.1.so/libdb_cxx-18.1.so 已登记，无 RPATH/RUNPATH，
正式 IPK CPU0 门禁验证两个 ELF 通过，SHA256 为
2f00ab1f5e4a3f539bc5ca077a20f7e84038bb99fe632d466da17d2400cccbe5。
运行依赖为精确平台 ABI、OpenSSL SSL/Crypto；复制功能、IPK 安装后的
消费者及来源/许可证/安全完整审查仍待完成，尚未签名发布。

Berkeley DB C API AES 加密消费者在 CPU0 无 RVV 环境通过：写入、
同步并关闭、正确口令重新打开读取、错误口令拒绝。负向测试的
BDB0210 metadata page checksum error 为预期拒绝输出。测试口令仅
为公开夹具值，没有使用设备或发布凭据，目录
berkeleydb-encryption-consumer.9S7fmw。此项不构成密码学安全审查通过。

常用基础库覆盖核对确认 libarchive-13、libgcrypt-20、libgpg-error-0、
libassuan-0、GnuTLS、Nettle/Hogweed、libtasn1-6、libcap-2 和 libudev-1
已有镜像运行 provider，不因缺少独立源码配方重新编译。新消费者
仅用不可变 SDK 编译，在 421 安装根、rv64,v=false 下通过 libgcrypt
SHA256 已知向量与 libarchive ZIP 内存归档逐字节往返，目录
base-archive-crypto-consumer.PLL9aJ。这只证明所测两个库的开发/运行
链路，不构成上述全部基础库功能、安全或许可证审查通过。

423 包 Berkeley DB 配对组合检查完成并通过，产物为
paired-common-berkeleydb-423。该结果覆盖索引/依赖闭包、镜像引用、
覆盖与 CPU0 门禁；尚未证明 423 包实际安装或板上验收通过。

422 包整批及全部单包 opkg 规划、实际 install/configure 完成并通过，
422 候选版本一致，共安装 583 包，基础受保护文件未变化，六个已
审计离线维护钩子完成。仅加载该安装根运行库复测 libssh 密钥/API
消费者与 loopback SSH 握手全部通过，主机指纹仍与本机公钥一致。
该结果未覆盖用户认证、SFTP 文件传输或板上验收。

Berkeley DB 已通过统一 build-all 正式构建与开发导出，事务目录为
berkeleydb-production-receipt.wQMcSa。正式收据 verify 通过，记录
libdb 一个包、11 个开发路径和 SDK manifest
cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f。
同轮 runtime closure 与 445 个非 ABI 动态对象覆盖检查通过。
开发导出与收据由真实统一构建流程生成，手工 staging 保持无收据。
后续导入/消费者及缓存重复构建避免验证仍待完成；其他 provider 的
手工开发输入缺口没有因此关闭。

PostgreSQL libpq 18.6 官方归档 SHA256 校验通过，配方保留 TLS、GSSAPI、
LDAP。客户端子目录首次安装遗漏 postgres_ext.h，补上游 src/include
安装目标后干净构建通过。CPU0 无 RVV 消费者验证 URI/TLS 参数、
非法选项拒绝、SQL 字面量二进制转义、独立 bytea 十六进制解码和
拒绝连接处理通过，目录 libpq-consumer.ZoZ5Z0。首次夹具把 SQL 转义
输出直接当作数据库 bytea 文本解码，已按官方 API 语义分离；没有
修改库实现。libpq.so.5 链接 OpenSSL、GSSAPI、LDAP，无 RPATH/RUNPATH。
真实数据库认证/查询、IPK 安装、正式开发收据与完整审查仍待完成。

libpq.so.5 已登记统一 provider，正式 IPK CPU0 门禁通过，SHA256 为
92110bb27e516e4fedcf767fe8bde7d6e5acdb657705b021d7b88dcf9216ef85。
自动依赖包含平台 ABI、OpenSSL SSL/Crypto、Kerberos、LDAP 精确版本。
Berkeley DB 正式开发收据生成时对应的共享脚本版本需要保留；后续
前置检查脚本新增 libpq 回归改变其构建输入摘要，旧收据导入不能
直接假定通过。应使用匹配生产者输入的隔离快照验证，不补写收据。

423 包整批/全部单包规划、实际 install/configure 全部通过，423 个
候选版本一致，共安装 584 包，基础受保护文件未变，六个已审计
离线维护钩子完成。仅加载安装根运行库复测 Berkeley DB C++ 事务
提交/回滚/持久化与 C API AES 加密/重开/错误口令拒绝全部通过，
产物目录 berkeleydb-installed-consumers.bxpIda。未使用 staging 运行库。
复制功能、板上验收、来源/许可证/安全审查及正式发布仍待完成。

MariaDB Connector/C 3.4.11 配方与源码锁已建立，官方 tag 指向提交
be67a4fc1e0493913732df90e562f122bff9dfe3。主库及九个动态插件生成，
保留 OpenSSL、zlib、curl、GSSAPI 与 zstd。公共 client_plugin.h 的
ma_compress.h 未被上游安装，且引用私有 ma_sys.h；开发导出补入锁定
源码头文件，并以锁定 patch 改为标准 limits.h，运行库实现未修改。
补丁 SHA256 1b33569cc4252deff6f6566a857975436af053ab9f6dda96daca9f2f30c73e9d。
正式重跑通过，CPU0 无 RVV 消费者完成初始化、UTF8 选项、六种认证
插件加载与拒绝连接处理，目录 mariadb-consumer.RqyRCz。实际数据库
认证/查询、IPK 安装、完整来源/许可证/安全与开发收据仍待完成。

MariaDB 主库与九个插件的正式 IPK CPU0 门禁验证 10 个新 ELF 通过，
SHA256 944c79ba1130c73989137ee13430eb81aaa9bd81e6b6307ccef440c7e861452a。
自动依赖包括精确 ABI、zlib、OpenSSL、Kerberos、curl、zstd，覆盖
remote_io、GSSAPI 和 zstd 插件所需依赖；主库和模块无 RPATH/RUNPATH。
公共头文件补丁、插件/依赖归属静态回归已加入完整共享前置检查。

424 包真实镜像 opkg 的整批/全部单包规划和 install/configure 全部
通过，424 候选版本一致，共安装 585 包，基础受保护文件未变化，
六个已审计离线维护钩子完成。仅加载该安装根运行库复测 libpq
URI/TLS 参数、非法选项、SQL 二进制转义、独立 hex 解码及拒绝
连接处理通过。尚未覆盖实际数据库认证/查询或板上验收。

Berkeley DB 收据与 b1f198b Git 生产者快照核对：106 输入中 59 字节
一致，47 仅有 CRLF/LF 差异，其他内容差异为零。隔离快照规范化 LF
后，原 build-staging-receipt.py 严格 verify 通过 libdb 一个包、11 个
开发路径；未修改收据、SDK 或开发字节，未重编库。快照目录
receipt-producer-b1f198b.oe2ael。未证明当前新共享检查脚本版本下可
直接导入，完整消费/缓存流程验收仍待完成。

新增 libpq 真实数据库消费者，使用目标 rv64,v=false 与 424 安装根
运行库连接本地原生 PostgreSQL 18.6 测试服务端。sslmode=verify-full
校验夹具证书和 localhost 名称，host SCRAM-SHA-256 认证启用；二进制
参数化查询逐字节往返、事务回滚后行数为零、错误口令拒绝全部通过。
测试只使用公开夹具口令，目录 libpq-real-database-consumer.PeZKPt。
初次服务启动因 Unix socket 路径过长失败，改短临时 socket 路径后
通过；服务绑定回环地址并在结束时关闭，不进入 feed/SDK/设备镜像。
此项未覆盖 Kerberos/LDAP 实际认证、板上网络或完整安全审查。

2026-10-10 只读 SSH 核对设备 image-base.json 摘要为
a8a53102d7ab54c75999e5e08d8802ffbe563c31ae2c9acc9ab38bcbd7babc31，
与当前候选锁定 13cab0042c6268976cbf795443559e30eacc671ed7670e5b2568b332b4589794
不同。因此未在该设备安装候选包或修改源配置，不能记录为当前
r12-rc2 配对镜像的板上验收通过。

MariaDB 真实数据库消费者通过：目标 rv64,v=false 客户端连接独立
回环 MariaDB 11.8.6 原生测试服务，启用 TLS 和证书验证。密码认证、
预处理二进制查询逐字节往返、事务回滚、错误口令及不受信任 CA
拒绝全部通过，目录 mariadb-real-database-consumer.aWCglY。原生
服务端和 liburing/libaio 仅解包到测试目录，没有安装系统服务。
服务使用短 socket 并在退出时关闭；客户端运行库当前来自正式
staging，425 IPK 安装后的复测尚未完成。此项未覆盖 GSSAPI/Ed25519
实际认证、设备网络或完整安全审查。

425 包告知材料清单审计生成 common-425-notice-inventory.json。文件
存在性扫描显示 219 个 IPK 无独立 notice 文件，296 个无 SOURCE.json；
不能据此作法律结论。219 项中 192 的组合计划引用镜像字节，另 27
需要继续核对，含 alias/元包/复用包及 libfft2d、libzstd 等。当前
镜像 package_sources 记录 buildroot_name、licenses、source_version，
这些元数据不能替代逐项告知文本核验。新 Boost、libssh、libdb、
libpq、libmariadb 包各有告知文件及来源记录；旧 libbz2/liblzma 有
许可证文本、缺来源记录。完整材料审查仍未完成。

425 包整批与全部单包 opkg 规划、实际 install/configure 全部通过，
425 候选版本一致，共安装 586 包，受保护基础文件未变化，六个
已审计离线维护钩子完成。仅加载安装根主库/插件复测六种认证插件
加载通过；真实数据库 TLS/密码/预处理二进制查询/回滚/错误口令/
不受信任 CA 拒绝也通过，没有 staging 运行库路径。原生测试服务
退出后关闭。板上配对验收、完整源码批次、开发收据/缓存以及材料
审查和正式签名发布仍未完成。

Berkeley DB 正式 development 导出消费者复测通过：使用匹配
b1f198b 的生产者快照执行严格收据校验，确认 1 包、11 路径；
编译时仅使用发布 SDK 和导出 development 的头文件/链接库。
rv64,v=false 执行时仅加载 425 包安装根运行库，C++ B-tree
put/get、事务提交/回滚与持久化重开全部通过，目录
berkeleydb-exported-development-consumer.IxOAda。该证据覆盖单包
正式导出消费，不代表全部软件包开发收据、跨生产者缓存复用或
板上验收已经完成。

425 包材料抽样复核：直接读取候选 IPK，libfft2d 实际携带
usr/share/licenses/libfft2d/SOURCE.json、readme.txt、readme2d.txt。
两份 readme 含上游版权及使用/复制/修改/分发条款；现有扫描器只按
文件名识别 notice，因此将这个包误列为缺少 notice。219 的原始
扫描计数不能直接作为实际缺少告知文本的数量。libzstd IPK 在
usr/share/licenses/ 和 usr/share/doc/ 下没有随包材料，仍需追溯
复用产物的来源记录和许可证交付；本次未改扫描器或生产包。

随后对全部 219 个文件名扫描阴性 IPK 检查上述目录的文件内容，
产物 common-425-notice-content-triage.json：1 包（libfft2d）的
README 存在版权与许可语句；4 包（tdvp-dev-tools、tdvp-diagnostics、
tdvp-nodejs-tools、tdvp-source-tools）有 README，但该内容启发式
未找到许可证据；214 包在这两个目录没有非 SOURCE.json 材料。
此范围不包含其他安装位置或发行版集中交付材料，也未判定元包
是否需要独立许可证。仍须按来源、镜像复用与包类型逐项核对，
不能以目录不存在直接判定侵权或完整告知缺失。

425 包范围核对：当前 cohort 的 151 个明确要求包均出现在候选
清单中；此结论只证明名称覆盖，不扩大为所有功能验收通过。
候选还包含镜像运行库 provider：PNG/JPEG、GMP/GMPXX、Gcrypt、
GnuTLS、p11-kit、cap、D-Bus、udev、mount、UUID、PAM、六个
libnl provider、libsndfile 和四个 V4L provider，因此这些类别
无需仅因 recipes 目录缺少同名条目就再次源码构建。GStreamer
在当前配方清单与候选包名中未发现，是多媒体/视觉应用扩展范围
尚需评估和补齐的类别；不能据 151 个 cohort 名称齐全宣告
“Linux 常用库全部补完”。

GStreamer 补齐准备：官方 1.28.7 核心与 gst-plugins-base 源码
已在 gstreamer-source-review.8ztCQ5 下载并通过官方 sha256sum
校验，摘要分别为
787329b2c5758e228a71d926a6dcf960bceaacca3cadd63874ba665dfcda013e、
ed6e5410f496d171818763af2265e7977154bc7f9b827e98acf8c5bed21dd5a7。
两个项目要求 Meson >= 1.4、GLib >= 2.64；匹配 SDK 提供
GLib/GObject/GModule/GIO 2.82.5。当前 Ubuntu 24.04 验证容器
没有 meson 命令，Ninja 1.11.1、Bison 3.8.2、Flex 2.6.4
存在，因此尚不能宣告这两个新增组件完成构建。Meson 应作为
可复现的主机工具输入补齐，保持目标 SDK 和运行库来源独立。

进一步追踪正式主机环境后确认，python-wheel-host-requirements.txt
已经按 SHA256 锁定 Meson 1.7.2；现有已准备 venv 中也包含 meson。
上段“没有 meson”仅适用于容器默认 PATH，不适用于正式 AI 主机
环境，不能据此重复安装主机工具或修改已锁定版本。新增 GStreamer
构建应激活并复用这个已验证环境。

GStreamer 核心 1.28.7 本地离线配方构建通过，产物目录
tdvp-command-payload.52jFvF，日志 libgstreamer-formal-build.log。
libunwind/libdw 诊断依赖保留启用；elfutils 独立恢复输出经过
相同 strip 后，libelf-0.196.so 与 libdw-0.196.so 均与 425
安装根字节一致。GLib 两个生成器使用 SDK 自带 Python 脚本，
通过 Meson machine file 显式交给主机 Python，不修改 SDK
旧 shebang、不运行目标 ELF。源许可证投影和 pkg-config
构建路径规范化通过。当前开发依赖恢复仍属本地 staging，未形成
完整导出收据；核心管线/插件扫描、IPK 安装和基础插件尚未验收。

后续核心验证：进程内插件发现、registry 生成、16 缓冲区
fakesrc/identity/fakesink EOS 与无效元素拒绝通过，回归
gstreamer-core-runtime-smoke.py。独立扫描器协议验证通过，回归
gstreamer-scanner-process-smoke.py；gst-inspect 启动单独目标
scanner，IPC 和 registry 正常，scanner exit=0。此项使用主机
QEMU 启动包装器，不代表板上原生启动已验收。核心与工具拆成
libgstreamer/gstreamer-tools，复用一次编译；IPK 摘要分别为
99af96e9abec83801cf8cd4979b227028a13eee9265129d59a3b8f15d27a1157、
cfc4dbde43147c7794d45b62dc95ee4ccfe29925605988eff3d8ffebc4b6527e。
核心 8 ELF、工具 3 ELF CPU0 检查通过。427 包组合正在进行，
实际安装、基础插件和完整开发收据仍未完成。

427 核心/工具候选组合校验随后通过，目录 paired-common-gstreamer-427，
保持未正式签名。已用隔离 fixture 密钥启动整批及逐包 opkg 规划/
实际安装任务 common-gstreamer-427-opkg-plan，结果仍待完成。
GStreamer 基础插件独立离线构建通过，产物
tdvp-command-payload.SBm41K，日志 gstreamer-plugins-base-formal-build.log；
复用 SDK 的 ALSA 1.2.13、Ogg 1.3.5、Vorbis 1.3.7、Opus 1.4、
Pango 1.54.0，没有重编这些基础库。相应开发 provider 声明已补。
当前 Theora 开发输入未提供，基础插件暂未启用它；ORC/GL 等
可选路径未验收，不计入已交付能力。基础插件的运行及 IPK 安装
尚未验收，仍需继续补齐和验证。

基础插件运行复测通过：C appsrc/identity/appsink 消费者验证二进制
缓冲区逐字节往返、EOS 与 EOS 后送数据拒绝，目录
gstreamer-app-consumer.PMF09d；视频 RGB 转换/缩放、Vorbis/Ogg
编码封装解封装解码、Opus 编解码管线均到达正常结束，回归
gstreamer-base-runtime-smoke.py。以上使用本地 staging 运行库，
仍需安装根独立复测；没有访问摄像头、显示或声卡硬件。基础包
实际生成 11 个媒体共享库和 28 个插件模块，SONAME 归属已补。

427 核心/工具候选实际 opkg 验收完成：整批与 427 单包规划
通过，427 候选版本均安装/配置，共 588 已安装包，受保护基础
文件未变化，六个已审计离线维护钩子完成。安装根
common-gstreamer-427-opkg-plan/root 独立复测核心管线和独立
scanner IPC 通过，运行库/插件/工具全部来自安装根，不包含
staging 路径。完整快速前置检查 common-gstreamer-full-preflight.log
通过，包含新增核心/基础插件策略回归。基础插件尚未进入这个
427 候选，须在后续候选重新完成安装和运行验证；全源码批次
仍有此前 Eigen 失败，未据快速检查通过推广 stable。

eb9a998 的快速 GitHub CI 38047158803 成功。包含基础插件的
428 包原始候选 common-gstreamer-base-original-raw.UPzxJS 已
启动组合校验，未提前记录为通过。磁盘回收已删除完成验收的
common-mariadb-425-opkg-plan/root（约 1.1 GB），只终止其
已完成任务的公开 fixture-keyring dirmngr；安装状态保存在
completed-installed-status/common-mariadb-425-opkg-plan.status，
日志、签名与 IPK 保留，旧根可重新生成。后续复测应使用最新
427/428 安装根，不能继续引用已删除的 425 根。

Theora 缺项补齐进展：官方 libtheora 1.2.0 的 SHA256SUMS
校验通过，摘要 ebdf77a8f5c0a8f7a9e42323844fa09502b34eb1d1fece7b5f54da41fe2122ec。
离线配方构建与 COPYING 投影通过，产物 tdvp-command-payload.cJvFA4。
复用 SDK Ogg 开发文件，没有重编 Ogg；编码器/解码器/兼容库及
开发文件已导出。基础插件修订为 1.28.7-2，新增 libtheora 构建
依赖并启用 Theora 插件，保持 1.28.7-1 旧候选身份。当前新版
基础插件重建进行中，Theora 编解码运行、负输入和安装尚未验收。

启用 Theora 的基础插件重建通过，产物 tdvp-command-payload.LFzjgg。
直接 C 消费者 theora-codec-consumer.BsWR1w 的头包、YUV 帧
编码/解码和无效头包拒绝通过。但是 Theora/Ogg 完整管线退出 0
同时产生两条 gst_event_set_seqnum 的 GStreamer-CRITICAL，不能
记为干净验收通过。四种管线隔离定位为 oggdemux 路径：编码器、
直接编解码、编码/封装均无 critical；加解封装后出现两条，日志
theora-pipeline-warning-isolation.IweUDy。回归已要求 stderr 无
GStreamer-CRITICAL，保留此失败，后续须定位并修复。

序号问题追踪：调试日志 theora-segment-debug.aCTmNe 确认上游
发送 TIME segment，oggdemux 仅在 BYTES 分支初始化 seqnum，
随后下游事件使用 INVALID。已添加源锁定补丁
ogg-push-segment-seqnum.patch（fd6959a7ecf26ee40488f2af00bfb398965d614512c6abc7b140943254a59ac7），
在非 BYTES 分支且尚无序号时采用上游事件序号，保留原 BYTES/
seek 分支。GitNexus 对第三方函数未找到目标，人工影响核对范围
为 Ogg 推送 segment/EOS；完整 seek 场景仍需补验。补丁构建
通过，产物 tdvp-command-payload.7g6iOt。428 旧基础候选已用
fixture 签名启动 opkg 安装验收，不包含 Theora 或该补丁。

修复后四条基础管线全部通过，stderr 无 GStreamer-CRITICAL。
Ogg 文件生成、duration 查询、带 FLUSH 的 accurate TIME seek
及最终 EOS 也在 G_DEBUG=fatal-criticals 下通过，目录
gstreamer-ogg-seek-consumer.lVocVT。libtheora 1.2.0 的实际 SONAME
为 libtheora.so.1/libtheoradec.so.2/libtheoraenc.so.2，归属声明
已据 ELF 修正。新版两个 IPK 已打包：libtheora 摘要
146fcdb2424dbce584a3e450f957795523aa029926cd44c3ab23bc303a5b71a1，
基础插件 1.28.7-2 摘要
25f616fbf526c5c7d82af51442e3dd9d91497b22144d0b11a1f4bce136ce87bb。
CPU0 检查分别为 3/40 ELF。429 候选已启动组合，尚未提前
记录为完成配对安装、完整开发收据或设备验收。

旧 428 基础插件候选的整批、428 单包规划及实际 install/configure
通过，共 589 已安装包，受保护基础文件未变化。安装根独立复测
视频转换、Vorbis/Ogg、Opus 及 C appsrc/appsink 缓冲区通过，目录
gstreamer-installed-base-428.oQ3Ixs；该证据使用 eb9a998 回归版本，
没有误计尚未包含的 Theora。当前 Theora 快速前置回归已接入；
首次镜像工作副本检查因 scp 更新 TSV 保留 CRLF 导致严格整行
匹配失败。首次规范化尝试又因磁盘耗尽失败；回收已完成的 427
安装根后规范化副本并启动重跑，未放宽生产断言。427 状态已
下载保存为本地 .tmp/common-gstreamer-427-installed.status，
其日志、签名和 IPK 保留；后续安装根测试应使用 428 或更新根。

本地完整 Theora 前置检查最终通过。429 包组合校验通过，目录
paired-common-theora-429；已启动整批、逐包和实际 opkg 安装任务，
日志 common-theora-429-opkg-acceptance.log，暂未计为完成。
磁盘清理另移除已无进程使用的四份早期安装根：374 twelve-repro、
382 cjson-index-fixed、385 embedded、382 third，各状态保存在
completed-installed-status；父目录规划、安装日志、缓存与输入
保留，最新 428 根保留，清理后可用约 5.9 GB。旧安装根可由
保留镜像/候选输入重建，不用于后续最新版验收。

61f0b18 的快速 CI 38048482729 成功。多媒体范围继续核对后，
开始补 gst-plugins-good 1.28.7：官方摘要
87256969c82cf3bc8574301f3e7044a90de0ac500a5a27d8ba38c4dde894dd8b
校验通过，配方声明通用 RTP/UDP/RTSP、MP4/Matroska/AVI、WAV、
图像及音频处理插件，复用 SDK JPEG/PNG/FLAC/Cairo/GdkPixbuf/
PulseAudio 开发文件，独立离线构建已启动。V4L2 采集不启用，
保留 CPU1 摄像头所有权；不改变桌面 renderer。当前 libvpx、
libsoup、mpg123、lame、speex、wavpack、taglib、twolame 的开发
输入未找到，仍属待评估补齐范围，不能把已启用插件当作完整
多媒体能力。新包尚未通过构建、管线、安装或正式发布验收。

429 实际 opkg 验收随后通过：整批、429 单包规划与 install/
configure 全部完成，590 已安装包，基础文件未变化。安装根
独立运行四条基础管线、Theora C 编解码/负头包及 fatal-criticals
文件 seek 回归通过，目录 gstreamer-installed-theora-429.bY4w1A，
无 staging 运行路径。Good 插件首轮独立离线构建通过，产物
tdvp-command-payload.ohXXkV；检查安装清单后进一步补入上游
usr/share/gstreamer-1.0/presets 的交付，需按更新配方重建后
继续管线/安装验收，不能只计插件 ELF 而漏运行数据。

Good 完整 payload 重建通过，产物 tdvp-command-payload.wZ05uy，
presets 数据已纳入。fatal-criticals 下 JPEG/PNG/FLAC、WAV、
Matroska/Theora、QuickTime/JPEG、RTP PCMA/JPEG 八条管线通过；
QuickTime 测试不扩大为所有 MP4 编码格式已验收。独立原生 UDP
接收器收到目标插件发送的 4 个回环 RTP 包，PCMA 静音负载逐字节
一致，序列号和时间戳推进正确。IPK 53 ELF CPU0 检查通过，摘要
a3ae19e3f5d90bef0bb9c42999639ca88c6201d706acf01ac9a03de41dbe86c9。
430 候选已启动组合，仍需安装根复测及完整依赖/开发收据验收。
