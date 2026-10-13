# 历史包名的连续性

维护版候选源保留支持范围内的历史软件，并检查更早的 catalogue；只对比
最近一个已签名 release，无法发现较早版本中曾经丢失的包。

## 旧库名

以下兼容包没有库文件载荷。依赖在候选源 finalization 时绑定到具体
provider 身份，基础镜像保留文件归属；不复制或重新编译已有 runtime。

| 历史名称 | 当前 provider |
| --- | --- |
| libncursesw-6 | libncursesw |
| libpcre2-8-0 | libpcre2-8 |
| libpopt-0 | libpopt |
| libreadline-8 | libreadline |
| libz-1 | libz |
| libresolv-2 | tdvp-image-toolchain-external-custom |
| libutil-1 | tdvp-image-toolchain-external-custom |

库名兼容版本为 `2025.02.1-2`，高于历史的 `2025.02.1-1`。它是 feed
打包修订号。镜像引用与依赖的精确版本仍由 finalization 生成。

`libyaml-0-2`、`libmxml-1`、`libmicrohttpd-12`、`libubootenv-0` 在基础镜像
中不存在，使用锁定的源代码配方构建，并导出开发 staging 供后续消费者
复用。WebP 和 NetSurf 已有独立配方，MPV 使用配对镜像提供的应用载荷。

## GBA 应用旧名称

`tdvp-cardputer-zero-gba` 的 r11 过渡配方位于
`packages/tdvp-cardputer-zero-gba-compat/`，版本 `0.1.0-13` 高于 r1 的
`0.1.0-12`。它提供空载荷并依赖 `tdvp-gba`，后者提供当前应用和桌面入口。
原 r1 配方继续保留，只在 r1 生效，不改变历史 release 的归档内容。
旧应用与当前应用的安装路径不同；升级测试仍需确认旧文件清理与新依赖安装。

## 明确退役的包

- `libdisplay`、`libv4l2-drm`、`libv4l2-drm++`、`libvvcam`：旧 CPU0
  摄像头 HAL，当前平台的摄像头与 AI 资源由 CPU1 托管，不能恢复这条旧链路。
- `tdvp-hello`：r1/r2 的最小打包测试夹具；继续用于 CI，不进入生产候选源。

这些条目仍可在不可变历史目录中审计。退役不意味着允许安装旧架构或
未经当前 ABI、ISA、依赖闭包验证的载荷。

## 发布前检查

`verify-historical-package-continuity.py` 比对仓库中所有归档 `Packages` 的
包名。缺少受支持的历史名称、恢复退役包，或缺少历史索引证据，都会拒绝
候选源；该检查已接入 `finalize-image-backed-feed.sh`。配对候选的历史
核对范围为 204 个名称，退役例外只有上述 5 项。

库名兼容配方的本地自动检查覆盖空载荷、重复生成、缺少基础库拒绝、
错误 provider 拒绝、禁止库载荷模式，以及保护用户已有的 payload 目录。
全源 finalization、原生 opkg 安装/升级/卸载和目标设备正常入口验收，
必须使用最终的配对镜像和 SDK；已有实验结果不替代正式配对发布。
