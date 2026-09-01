# 签名与发布安全策略

[中文（当前）](SIGNING.zh-CN.md) | [English](SIGNING.md)

本文件说明谁可以签名、密钥应当放在哪里，以及公开软件源为什么不能只依赖 HTTPS。HTTPS 保护传输过程；签名让设备能确认索引确实来自本仓库的发布者。

## 密钥角色

| 密钥/凭据 | 存放位置 | 用途 |
| --- | --- | --- |
| 私有发布密钥 | 离线签名主机、HSM 或受保护的自托管 Runner | 对软件包索引载荷签名 |
| 公开发布密钥 | `keys/tdvp-repo-public.asc` 和下一版基础固件 | 验证发布内容 |
| GitHub 部署令牌 | 临时 GitHub Actions OIDC 令牌 | 发布已经签名的静态文件 |

只有公开密钥可以提交到 Git。私钥不能出现在 Git、GitHub Actions 日志、GitHub Actions Secrets、设备或 GitHub Pages 中。设备上保存的是公开密钥，不是能创建新签名的私钥。

当前发布公钥的完整指纹为：

```text
2B091A2A8E5810954FB9FD64EA9D1CD5EFC81500
```

将 `keys/tdvp-repo-public.asc` 内置到固件或信任一份复制出的公钥前，请先核对这个完整指纹。

## GPG 索引签名约定

当前仓库骨架采用分离式、ASCII 装甲的 GPG 签名：

```text
Packages
Packages.asc
Packages.gz
Packages.gz.asc
```

`offline-sign-gpg-index.sh` 只应在受保护的签名主机上运行。它不会生成密钥，并且在没有明确指定密钥指纹时会拒绝执行。这是刻意设计的：构建服务器可以生成候选包，但不应自动拥有发布私钥。

TDVP K230 r1 基础镜像使用这套 `gpg-asc` 约定，其中包括 `check_signature 1`、`/etc/opkg/gpg` 和按需执行的 `/usr/local/sbin/tdvp-opkg` 包装器。包装器只会在操作者调用 opkg 前导入内置公开密钥；它有意不是 `greetd` 或桌面的开机服务。固件发布前仍必须验证两个预期签名后缀、密钥环位置和全部拒绝行为。

## 不可变发布

不要覆盖一个已经公开发布的 `rN` 软件源目录。新的 ABI 或固件约定必须使用新的
`PLATFORM_ID`；即使 ABI 未变，只要需要新增包、共享库或索引，也必须发布新的不可变 feed
revision，例如 `site/feed/<PLATFORM_ID>/r2/riscv64/`。已发布的 r1 路径保持原样，绝不重签或
覆盖。

设备不直接配置 rN，而是配置 `site/feed/<PLATFORM_ID>/stable/<ARCH>/`。`stable` 是唯一可变
目录，但不是不受控的索引：每次提升必须完整复制一份已经用同一公钥验证过的 rN 目录，保持
所有 IPK、`Packages`、`Packages.gz` 和两份 detached signature 字节一致。Pages CI 会验证这种
对应关系。设备安全性仍然来自已签名的 Packages 索引；`stable` 只是使高频 Feed 发布不需要
重打固件镜像的交付通道。

`release` 分支必须要求评审。直接从 `main` 发布，会让一次普通构建修改直接变成设备更新，缺少发布闸门。

社区 Pull Request 绝不会直接发布软件源。它们需要先经过应用审查、匹配平台验证、受保护 `release` 分支变更和离线签名，之后才会成为设备可下载的公开内容。
