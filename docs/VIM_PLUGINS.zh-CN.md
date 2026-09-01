# TDVP K230 上的 Vim

`vim` 是面向 TDVP K230 的 1232 × 568 横屏桌面的终端应用；它不把 GUI 工具包或 X11
依赖带入镜像。

## 软件包边界

| 软件包 | 职责 |
| --- | --- |
| `vim-runtime` | `/usr/share/vim` 下的 Vim 9.1 runtime、语法数据与宏 |
| `vim` | 终端可执行文件、`vi` 兼容链接、Foot 菜单入口和 TDVP `/etc/vimrc` |
| `vim-plugin-repeat` | 重复命令 helper |
| `vim-plugin-surround` | 包围/删除/修改文本对象 |
| `vim-plugin-commentary` | 行或范围注释命令 |
| `vim-plugin-sleuth` | 自动缩进识别 |

安装 `vim` 会通过精确版本的依赖同时安装四个轻量基础插件。它们位于 Vim 原生的
`/usr/share/vim/vim91/pack/tdvp/start/`，启动时自动加载；没有第二个后台插件管理器。

TDVP 的 `/etc/vimrc` 为紧凑横屏终端提供系统默认值：行号、当前行、始终可见的状态栏、
短滚动边距和保守的代码缩进。Vim mouse mode 被关闭，以免 Foot 的触控/鼠标选择和焦点
被 Vim 截获。用户的 `~/.vimrc` 会在系统配置之后读取，因此可有意覆盖所有默认项。

## 架构边界

纯 Vimscript 插件只有文本，与 CPU 架构无关；但每个插件仍必须在 feed 配方中锁定上游
commit 和 SHA-256。它们可以被打入 TDVP 的 `riscv64` feed channel，但不需要交叉编译。

带原生 helper、`.so`，或依赖 `fzf`、`ripgrep`、语言服务器、Git 等工具的插件，不能在
安装时下载上游 x86/ARM 预编译产物。只有其工具或库已从源码为 riscv64 构建、并拥有独立
IPK runtime 依赖时，才可以加入；原生 helper 不可伪装塞进 `vim-plugin-*` 脚本包。

## 新增纯插件的规则

使用 Vim 原生 package 目录，而不是会在设备上随意下载代码的插件管理器：

1. 新建 `packages/vim-plugin-<name>/package.env`，锁定上游 commit、archive URL 和 SHA-256；
2. 设置 `PACKAGE_KIND='runtime'`、精确的 `vim-runtime` 依赖和唯一的 `VIM_PLUGIN_DIRECTORY`；
3. 调用 `support/vim-plugin-build.sh`。它只允许 `autoload/` 与 `plugin/` 文本树，若发现
   可执行文件或共享对象即失败；
4. 将软件包加入候选 release 审计，并在 K230 实机验证。

个人临时实验也可放入 `~/.vim/pack/<group>/start/<plugin>/`。这类内容不属于签名的 TDVP
feed，不能作为可复现镜像或正式软件源的依赖。
