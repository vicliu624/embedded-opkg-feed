# AI、视觉与常用 Linux 库验收记录

本记录对应 2026-10-09 的本地配对候选。公共 stable 的内容以已签名的索引为准。
新增配方、构建成功、实机运行和发布是独立状态，不能互相替代。

## 配对身份

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
