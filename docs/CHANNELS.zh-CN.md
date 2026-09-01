# Feed snapshot 与 stable 通道

[中文（当前）](CHANNELS.zh-CN.md) | [English](CHANNELS.md)

TDVP 的固件镜像应当低频发布；应用、运行时库和桌面程序的 feed 可以高频发布。为同时保证
可复现性和现场更新能力，本仓库把**不可变 snapshot**与**设备通道**分开。

```text
镜像（低频）
  公钥 + ABI 身份 + .../<PLATFORM_ID>/stable/<ARCH>

Feed（高频）
  .../<PLATFORM_ID>/r7/<ARCH>       不可变 snapshot
  .../<PLATFORM_ID>/r8/<ARCH>       不可变 snapshot
  .../<PLATFORM_ID>/stable/<ARCH>   当前已批准 snapshot 的完整视图
```

## 不变量

- `rN` 一经公开，绝不覆盖、重签或删除；新增应用和依赖必须发布新的 rN。
- `stable` 不是 release；它是设备唯一配置的、ABI 固定的交付通道。
- `stable` 只允许完整提升一份已经验证签名的 rN。它的每个 IPK、`Packages`、`Packages.gz`、
  `Packages.asc` 和 `Packages.gz.asc` 必须与来源 rN 字节一致。
- 设备只依赖 `opkg` 对 detached Packages signature、包哈希、架构和精确
  `tdvp-platform-abi` Depends 的已有校验。`release.json` 是可审计描述，不是新的信任根。
- 回滚是把 `stable` 提升回一个先前验证过的 rN；绝不修改该旧 rN。

## 发布操作

候选通过构建、实机验证和离线签名后，先将它作为 immutable snapshot 暂存，再明确执行提升：

```sh
bash scripts/stage-site.sh --platform tdvp-k230-r1 --release r8 \
  /absolute/path/to/signed/r8/riscv64

bash scripts/promote-stable-channel.sh --platform tdvp-k230-r1 --release r8
bash scripts/verify-stable-channel.sh --platform tdvp-k230-r1

# .ipk 由通用 .gitignore 忽略；公开发布时必须显式纳入两份完整目录。
git add -- site
git add -f -- \
  site/feed/<PLATFORM_ID>/r8/riscv64/*.ipk \
  site/feed/<PLATFORM_ID>/stable/riscv64/*.ipk
```

第三步会验证签名、ABI 依赖、索引哈希和 rN 到 `stable` 的逐包字节一致性。通用 `.gitignore`
会忽略 `.ipk`，因此第四步的强制暂存是发布完整 opkg 目录所必需的；它不代表绕过签名或校验。
把 snapshot 与 stable 的同一次变更提交到受保护的 `release` 分支后，Pages 工作流会重复验证再部署。

不得把未签名候选、任意本机构建目录或某个开发分支直接指向 `stable`。镜像也不得配置 rN URL；
那会使每次应用发布都错误地变成固件发布。

## 何时需要重打镜像

新增或更新 LoFiBox、`ffprobe`、共享库、图标或桌面应用时，只需发布并提升 Feed。只有 ABI、
内核/驱动、glibc/动态加载器、核心桌面栈、`opkg` 语义或发布公钥发生兼容性变化时，才需要新的
TDVP 基础镜像和新的 `PLATFORM_ID`。
