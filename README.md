# TDVP 嵌入式 Linux 软件包仓库

中文（当前） | [English](README.en.md)

这是一个**面向嵌入式 Linux 设备的公开、发行版式用户态软件包仓库**。它让设备通过 `opkg` 安装经过测试、与设备 ABI 严格匹配的通用库、命令行工具、桌面程序和设备应用；通用运行库只构建一次，并由多个包通过正常的 `Depends` 关系复用。

这里不是“所有 RISC-V 软件都能装”的通用仓库。嵌入式设备上的 C 库、CPU ABI、内核和系统组件往往彼此绑定；装错包轻则无法运行，重则破坏系统。因此，每个包都会明确声明支持哪些设备平台，仓库只发布经过维护者构建和验证的包。

## 我应该看哪一份文档？

| 你的目标 | 从这里开始 |
| --- | --- |
| 我想在设备上安装软件 | [设备使用说明](docs/USAGE.zh-CN.md) |
| 我想提交程序或库 | [贡献说明](CONTRIBUTING.zh-CN.md) |
| 我是平台/固件维护者，要让新设备接入 | [平台说明](docs/PLATFORM.zh-CN.md) |
| 我负责打包、签名和发布 | [发布说明](docs/RELEASE.zh-CN.md) |
| 我需要修复设备端的 opkg 与签名支持 | [设备引导说明](docs/DEVICE_BOOTSTRAP.zh-CN.md) |

## 三句话了解这个仓库

1. **开发者提交用户态软件或共享库的源码和打包描述；维护者负责构建、测试、签名和发布。**
2. **GitHub Pages 是公开下载地址；签名索引用于证明下载内容确实由仓库维护者发布。**
3. **仓库包不能替换不可变的系统核心部分。** libc、内核、系统服务、启动链、`opkg` 本身和 KPU 驱动都属于固件责任范围，不从这里升级。

目标模型与正常 Linux 发行版的职责划分一致：基础镜像只保留小而稳定的硬件相关引导与桌面种子，feed 是可扩展的用户态软件目录。后续的通用库、命令行工具、桌面程序和设备专属应用都应作为带有明确依赖的独立包进入这里。它并不是任意 RISC-V 板子都能使用的二进制堆放区；每个 feed release 都严格绑定一个声明过的 TDVP 平台 ABI。

## 当前支持的平台

第一个接入的平台是 `tdvp-k230-r1`：

| 项目 | 当前值 |
| --- | --- |
| 设备 SoC | Kendryte K230 |
| 系统基线 | Buildroot 2025.02.1 |
| CPU 架构 | RISC-V 64 位，LP64D |
| C 库 | glibc 2.33 |
| 内核基线 | Linux 6.6.36 |
| 平台 ABI 标识 | `tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1` |

完整平台边界见 [平台说明](docs/PLATFORM.zh-CN.md)。如果你的设备与这些条件不同，请不要直接安装本平台的包；应先为你的设备建立新的平台定义。

## 对设备使用者：什么时候可以安全安装？

只能把本仓库用于对应的、已经签名发布的 TDVP K230 基础固件。这个长期维护的键盘掌机发行版会内置本仓库公钥、提供精确的 `tdvp-platform-abi` 标记，并在操作者实际使用软件源时通过 `tdvp-opkg` 初始化密钥环、强制验证已签名索引；它有意不是桌面启动前的前置条件。不要让旧镜像或其他 RISC-V 发行版直接使用此 URL。

刷入该 bootstrap 镜像并且已发布签名软件源后，使用者通常只需要执行：

```sh
sudo tdvp-opkg update
sudo tdvp-opkg list
sudo tdvp-opkg install tdvp-gba
tdvp-gba
```

真实仓库地址、密钥安装方式和故障排查在 [设备使用说明](docs/USAGE.zh-CN.md) 中。`tdvp-gba` 由经审查、锁定提交的源码树和精确 TDVP SDK 构建，不是通用的 RISC-V 二进制；它显式依赖本 feed 的 `sdl2`、`sdl2-ttf` 与 `libmgba`。这些库均为 `riscv64`、精确 TDVP ABI 构建，且只在一个 feed release 中构建一次。已经发布的 r1 旧包 `tdvp-cardputer-zero-gba` 保持不可变，仅作为历史兼容记录。

## 对软件包开发者：怎样贡献？

最常见的流程如下：

1. Fork 本仓库并新建分支。
2. 复制 `packages/_template/`，把目录和 `package.env` 改成你的程序或库信息。
3. 程序把运行文件放进 `root/`；共享库 recipe 只可放经审核的 SONAME 文件到 `/usr/lib`，其开发文件仅进入临时 staging sysroot，绝不进入用户设备。
4. 在你的开发环境中运行构建和检查命令。
5. 提交 Pull Request，说明应用用途、适用平台、依赖和测试方法。

示例：

```sh
TDVP_SDK_ROOT=/path/to/output/host \
TDVP_FEED_BASE_ROOT=/path/to/output/target \
./scripts/build-all.sh --platform tdvp-k230-r1 --release r2 --output dist
./scripts/verify-feed.sh --platform tdvp-k230-r1 \
  dist/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r2/riscv64
```

开发者只需要提交**可审查的源码、构建脚本和包描述**。不要提交生成的 `.ipk`、`Packages`、`Packages.gz`、签名文件或 `site/feed/` 内容；这些是发布流程的产物。更详细、带检查清单的说明见 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。

## 对维护者：发布是怎样发生的？

```text
开发者 Pull Request
        ↓
CI 校验配方、来源锁定和可移植的构建工具
        ↓
维护者使用精确 K230 SDK 构建、测试并离线签名索引
        ↓
GitHub Actions 校验签名并发布到 GitHub Pages
        ↓
设备通过 opkg 下载并验证
```

私钥绝不进入 Git、Pull Request 或 GitHub Pages。发布者在离线/受控环境中对 `Packages.gz` 签名；仓库只保存公开密钥。具体步骤见 [签名说明](docs/SIGNING.zh-CN.md) 和 [发布说明](docs/RELEASE.zh-CN.md)。

## 命名和安全边界

- `tdvp-` 前缀保留给平台维护者发布的官方包，例如 `tdvp-gba`。
- 通用上游库保留它们的正常包名，例如 `sdl2`、`sdl2-ttf`、`libmgba`；ABI 兼容性由平台依赖和 `Architecture` 保障，而不是靠给库名加 TDVP 前缀。
- 社区应用建议使用 `<github 用户名>-<应用名>`，例如 `alice-status-panel`，以避免重名。
- 包必须声明支持的平台。构建脚本会自动加入该平台的 ABI 依赖，不能靠手工省略。
- `application` 包不允许写入或替换 `/boot`、`/lib`、`/lib64`、`/usr/lib`、`/usr/lib/systemd`、`/usr/sbin`。只有维护者审核的 `shared-library` recipe 可安装受控的 `/usr/lib/lib*.so*`，并且构建器会拒绝基础镜像冲突、受保护运行时替换、重复 SONAME、RPATH 和未声明的动态依赖。

## 本地仓库开发

仓库中的 shell 脚本面向 POSIX shell；Windows 开发者可用 WSL。开始前至少需要 `bash`、`tar`、`gzip`、`ar` 和 `sha256sum`。发布签名还需要 GnuPG。

```sh
# 查看全部可用命令和说明
ls scripts

# 创建第一个应用包时，从模板开始
cp -a packages/_template packages/<你的包名>
```

如果遇到“ABI 不匹配”“不能写入系统目录”或“索引签名无效”，先不要绕过检查；这些提示通常是在阻止一个不能安全安装的包。请按相应文档修复元数据、基础固件或签名流程。

## 仓库布局

```text
platforms/    每个受支持设备的 ABI 和平台定义
packages/     用户态软件包源码、构建描述和安装文件
scripts/      构建、索引、校验、签名和站点准备工具
keys/         仅公开的仓库签名密钥
docs/         使用、平台、设备引导、签名和发布文档
site/         将被 GitHub Pages 发布的静态站点内容
```

## 许可和行为准则

请在提出 PR 前阅读 [CONTRIBUTING.zh-CN.md](CONTRIBUTING.zh-CN.md)。新增第三方应用时，请确认你有权分发其源码、二进制和依赖，并在 PR 中清楚说明许可证。

---

英文版请见 [README.en.md](README.en.md)。
