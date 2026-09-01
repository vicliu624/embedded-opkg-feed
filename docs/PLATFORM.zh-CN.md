# TDVP K230 r1 平台兼容性约定

[中文（当前）](PLATFORM.zh-CN.md) | [English](PLATFORM.md)

本文件定义 `tdvp-k230-r1` 上“一个包能否安装和运行”的兼容性边界。它不是只看 CPU 架构的说明；平台 ID 代表一整套二进制兼容性约定。

## 已从目标设备确认的信息

下列值来自实际设备检查，而不是根据开发板名称推测。供脚本读取的版本见 [`platforms/tdvp-k230-r1/platform.env`](../platforms/tdvp-k230-r1/platform.env)。

| 字段 | 值 |
| --- | --- |
| 开发板标识 | TDVP K230 / `tdisplay-k230` |
| CPU 架构 | RISC-V 64 位 |
| 加载器 ABI | `riscv64-lp64d` |
| 动态加载器 | `/lib/ld-linux-riscv64-lp64d.so.1` |
| C 库 | GNU libc 2.33 |
| 内核 | 6.6.36 |
| 基础系统 | 厂商定制的 Buildroot 2025.02.1 |
| 包管理器 | opkg 0.7.0 |

## 何时必须建立新平台

`PLATFORM_ID` 表示完整的二进制兼容性约定，而不只是 CPU 名称。下列任一项发生变化时，平台维护者都必须新建平台清单和对应的软件源路径：

- Buildroot/厂商源码版本或 defconfig；
- 工具链、sysroot、glibc、C++ ABI 或硬浮点 ABI；
- 会与内核交互的软件包所依赖的内核版本；
- KPU/GPU/AI2D 运行时 ABI；
- 核心 Wayland 组件栈的 compositor/protocol ABI 发生变化。

最后一项仅指所有 Wayland 客户端都要共享的合成器或协议 ABI 变化，不是某一个应用所需的库、桌面功能或 helper 可执行文件。后者应作为带精确依赖的普通 feed 包发布，不能为此新建平台 ABI。

每个包使用下面的依赖门槛：

```text
Depends: tdvp-platform-abi (= 2025.02.1-k230.6.6.36-glibc2.33-rv64-lp64d-r1)
```

基础固件必须把这个标记包登记为已安装。若一个包不能满足此依赖，就不应使用 `--force-depends` 强行安装；正确做法是切换到匹配的平台软件源，或为新固件建立新的平台定义。

## 明确不属于应用包的内容

应用包不能替换 `/boot`、`/lib`、`/lib64`、`/usr/lib`、`/usr/lib/systemd`、`/usr/sbin` 或 `/etc` 中的文件，除非经过固件级别的专项评审和批准。

不要在本软件源发布内核模块。内核模块必须匹配精确的内核构建身份，而不仅仅是内核版本号；它们应当随固件一起构建、测试和发布。
