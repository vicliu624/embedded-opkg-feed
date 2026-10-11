# Eigen 与自研 profile 文档修复验收

2026-10-11，用户批准修复 Eigen 配方、四个自研 profile README 使用 MIT，
以及将完整 opkg 批量升级修复纳入镜像。此记录只描述本次 feed 验收。

## Eigen

失败批次 38016770685 在 eigen_blas 链接时混入 EM:62 的主机 Fortran 对象。
锁定归档 SHA256 为
`1f4babf536ce8fc2129dbf92ff3be54cd18ffb2171e9eb40edd00f0a045a54fa`。
其顶层配置默认开启 BLAS/LAPACK；development-only 配方现显式关闭这些扩展，
并关闭测试、示例和基准，保留 pkg-config 与 CMake package。
公共 CMake 构建 helper 和源锁未修改。

在 192.168.31.42 的 Ubuntu 24.04 容器中，使用当前锁定发布 SDK、离线归档，
真实 recipe 构建及安装通过。开发投影不含 .so/.a，包含 Eigen/Core 和
Eigen3Config.cmake。使用该投影编译 RISC-V 消费者，QEMU 运行线性求解及
对称矩阵特征值测试通过。这是构建主机模拟验收，尚未在设备运行本次产物。

证据目录：`/home/vicliu/work/eigen-approved-regression.y5p6y4`。

## README 许可证

MIT 仅覆盖 tdvp-dev-tools、tdvp-diagnostics、tdvp-nodejs-tools、
tdvp-source-tools 各自的 TDVP 自研 README。随包安装 LICENSE 和 SCOPE，
第三方依赖许可保持各自条款。
四个包修订为 1.0-6、1.1-3、1.0-7、1.6-3，
Node.js profile 精确引用 tdvp-dev-tools 1.0-6。
Debian/WSL 与 Ubuntu 24.04 隔离构建及字节检查通过。

完整共享批次前置检查通过，日志位于
`/home/vicliu/work/feed-approved-three-regression/preflight.log`。
新增两项快速 CI 检查用于防止 Eigen 可选目标和 README 许可安装回归。
本次没有正式签名、推广 stable、变更设备或编译整镜像。
