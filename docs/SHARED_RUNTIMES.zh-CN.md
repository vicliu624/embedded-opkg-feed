# 共享运行时包约定

[中文（当前）](SHARED_RUNTIMES.zh-CN.md) | [English](SHARED_RUNTIMES.md)

TDVP K230 feed 有三种经审核的包类型：

```text
application       命令行工具、桌面程序、设备应用、数据和文档
shared-library    由 recipe 构建、可被多个程序复用的运行时 SONAME 库
runtime           从已验证 target 提取的共享运行时、插件或运行时数据
```

这不是通用 RISC-V 仓库。每个包均为 `riscv64`，属于一个不可变 TDVP feed revision，并由平台清单自动获得精确的 `tdvp-platform-abi` 依赖。

## 可组合所有权契约

从 r4 起，这不是“应用 + 若干例外库”的软件源，而是一份可组合的、发行版式用户态 catalogue。基础镜像唯一可以被应用隐式假定的运行时是 ABI seed：所有目标动态加载器、glibc 的 `libc/libdl/libm/libpthread/librt`、`libgcc_s`、`libstdc++`，以及内核、驱动与启动链；它们不能由 opkg 升级。

**每一个被纳入某个 feed release 的其他动态 SONAME，在该 release 中必须有且只有一个独立 IPK 所有者。** 这个 catalogue 本来就是逐步补全的：新应用可能首次暴露此前 release 不需要的库。发布叶子应用前，该库必须作为可复用 provider 加入新的 feed release，不能静态塞入应用，也不能从 target rootfs 暗中借用。每个 release 的 runtime catalogue 会从经过验证的 target 中打包其选择的非 ABI SONAME、运行时数据和可加载模块；例如 GTK3/GLib、Wayland/EGL/Mesa、ALSA/PulseAudio、SDL2、libmGBA、libcurl、libpng、libjpeg、libutf8proc、FFmpeg/MPV，以及 `gtk3-data`、`gdk-pixbuf-loaders`、`glib-networking`、`pulse-modules`、`tdvp-gdk-committed-compat`、`tdvp-hardware-runtime`、`tdvp-runtime-libexec` 和 `shared-mime-info`。发布检查同时扫描 `/usr/lib`、`/usr/libexec`、`/usr/local/lib` 与 `/usr/local/libexec`；纳入本地库目录是为了让自定义共享对象不能再成为基础镜像的隐式依赖。

因此 `tdvp-gba`、`tdvp-netsurf`、`tdvp-mpv`、`audacious` 都是叶子应用：它们不携带静态副本，不从基础镜像暗中借用通用库，而是通过精确版本的 `Depends` 取得所有直接运行时需求。Audacious 被拆分为可复用的 `audacious-core` 运行时（三个公开 `libaud*` SONAME）、`audacious-plugins` 运行时（私有 GTK3/FFmpeg/ALSA/PulseAudio 模块树）以及 `audacious` 桌面叶子包。镜像可为了首次桌面启动而带有与 r6 字节一致的兼容副本，但这不改变依赖契约：闭包检查把 feed package 而不是 base rootfs 作为每个非 ABI SONAME、私有动态 helper、插件和运行时模块的 provider，安装后该 IPK 是唯一的软件包所有者。TDVP 自有动态对象必须放入 `/usr/lib`；审计 `/usr/local/lib` 的目的正是让错误放置的私有共享对象不能成为未声明的镜像依赖。

自动闭包检查读取的是 ELF `NEEDED`，无法推导程序通过 `exec` 启动的子进程。需要外部命令的 recipe 必须在 `PACKAGE_DEPENDS` 写出该命令的 IPK provider；所选 target 没有 provider 时，先在同一 feed release 新增普通工具包。这是应用/软件包依赖，不是平台 ABI 或固件变更；LoFiBox 的 `ffprobe` 是这一规则的参考案例。

一个库在一个 ABI/feed release 中只构建或提取一次，任意后续程序直接复用相同版本的 IPK；添加应用不会重新编译或静态塞入 SDL、GTK、curl、图像库等基础库。

## Recipe 元数据

每个 recipe 同时声明构建顺序和安装后的运行时依赖：

```sh
PACKAGE_KIND='shared-library'        # 或 application / runtime
PACKAGE_RELEASES='r6'
PACKAGE_SECTION='libraries'          # 例如 libraries、utils、desktop、games
PACKAGE_BUILD_DEPENDS='sdl2'         # 仅构建 staging
PACKAGE_DEPENDS='sdl2 (= 2.30.11-1)' # opkg 运行时关系
PACKAGE_AUTO_RUNTIME_DEPENDS=1       # 由 ELF NEEDED 生成其余精确依赖
```

`build-all.sh` 为一次 release 创建一个临时 `TDVP_FEED_STAGING_ROOT`。库 recipe 的头文件、CMake 元数据和未版本化 linker symlink 只进入此 staging；最终 `.ipk` 只能包含运行时 `lib*.so*` 和属于该包的许可/文档。平台 catalog 还会把 target 中所有非 ABI SONAME、模块和运行时数据拆成独立 `runtime` 包，并生成 SONAME → `Package (= Version)` 所有者图。应用从同一 staging 动态链接，不能再复制这些库到自身载荷。

## 强制发布检查

不可变 feed 签名前，发布构建会验证：

- 任何非 ABI SONAME 在 feed 中恰好只有一个 provider；
- 基础目标 `/usr/lib` 与 `/usr/libexec` 内的每一个非 ABI 动态对象都必须有一个字节一致的 feed owner；
- 每个应用或模块的直接 `NEEDED` SONAME 都由其精确 `Depends` 覆盖，不能以 target rootfs 作为后门 provider；
- 允许覆盖基础镜像的内容时，文件字节、权限和 symlink 目标都必须相同，确保这是 package ownership 的接管而不是替换；
- 共享库不得写入受保护的 loader/glibc/libstdc++ 文件；
- 两个 feed 包不能导出同一 ELF SONAME；
- 新增载荷 ELF 不得携带 RPATH/RUNPATH；遗留 target ELF 仅可保留经字节一致性审计的 RPATH/RUNPATH；
- 叶子应用不得静态打包或私自复制通用运行时库。

构建含共享库的 feed 时必须提供 `TDVP_FEED_BASE_ROOT=<匹配的 Buildroot target>`。只看 recipe 元数据不足以签发一个库 release。

`tdvp-` 只保留给 TDVP 平台拥有的包（例如 `tdvp-gba`），并不是通用第三方库的前缀。通用库保留上游名称；由 feed 的平台 ABI 依赖与 `Architecture: riscv64` 限定其安全安装范围。
