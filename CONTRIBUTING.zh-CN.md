# 贡献应用包

[中文（当前）](CONTRIBUTING.zh-CN.md) | [English](CONTRIBUTING.md)

欢迎通过 Pull Request 提交可公开发布的应用包。本仓库不是“上传一个编译好的二进制就行”的地方，也不是适用于所有 RISC-V 设备的软件发行版。每个包都必须能够被审查、重新构建，并且明确它支持的设备平台。

## 贡献者需要提交什么

一个普通应用 PR 可以在 `packages/<包名>/` 下新增或修改一个目录，目录内容如下：

```text
package.env                 包元数据和支持的平台
build.sh                    可选的、会被评审的构建脚本
root/                       可复现构建后将被安装到设备上的文件
README.md                   给使用者看的用途、许可证和测试说明
```

如果你的应用包含原生程序，`build.sh` 必须使用目标平台锁定的 SDK/sysroot 构建，并把产物放到 `root/` 中。发布构建时不能临时下载版本未锁定的工具或预编译二进制；否则同一份源码今天和明天可能产出不同结果，维护者也无法可靠审查它。

## `package.env` 要填写什么

`package.env` 必须定义以下字段：

```sh
PACKAGE='your-github-handle-my-app'
VERSION='1.0.0-1'
MAINTAINER='Your Name <you@example.com>'
DESCRIPTION='One-line application description'
SUPPORTED_PLATFORMS='tdvp-k230-r1'
PACKAGE_DEPENDS=''
```

打包脚本会自动加入精确的 ABI 依赖。不要把 `tdvp-platform-abi` 手工写进 `PACKAGE_DEPENDS`；手工写不仅没有帮助，还可能和平台定义不一致。

## 命名与归属

- 以 `tdvp-` 开头的第一方名称只供项目维护者使用。
- 社区包使用全小写的 `<github 用户名>-<应用名>`，例如 `alice-status-panel`。
- 不要复用其他贡献者的前缀，也不要伪装成基础系统包。
- 每一份随包分发的源码和二进制资产，都必须有 OSI 兼容许可证，或有明确的再分发授权。

## PR 的边界

普通应用 PR 不应修改以下内容：

- `site/`，以及任何生成的 `.ipk`、`Packages`、`Packages.gz` 或签名文件；
- `platforms/` 下的 ABI 清单；
- `keys/`；
- 签名或发布工作流；
- [平台说明](docs/PLATFORM.zh-CN.md)中列出的固件负责目录。

PR 模板会要求你填写适用平台、构建输入、源码来源、许可证、资源占用和测试结果。维护者会检查安装内容，并在匹配的平台测试镜像上运行软件，然后才会决定是否签名发布。

## 本地验证

请在装有匹配 SDK 的 Linux 主机上运行：

```sh
./scripts/build-all.sh --platform tdvp-k230-r1 --output dist
./scripts/verify-feed.sh --platform tdvp-k230-r1 \
  dist/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/riscv64
```

仅仅成功生成 `.ipk` 并不等于可以合并。应用还必须在所声明的平台上通过功能测试；否则即使包格式正确，也不能保证设备真的能使用它。
