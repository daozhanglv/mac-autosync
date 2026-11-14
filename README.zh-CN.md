# mac-autosync

[English](README.md)

装一次就不用再管的 Mac 配置备份工具，把配置文件自动备份到你自己的 Git 仓库。

安装之后，你的 Mac 每天夜里会自动完成：

1. 把你列出的配置文件（`.zshrc`、`.gitconfig` 等）复制进这个仓库；
2. 把已安装的 Homebrew 软件清单保存到 `Brewfile`；
3. 用 [gitleaks](https://github.com/gitleaks/gitleaks) 扫描改动里有没有密码和 token，发现就中止；
4. 提交并推送到你的仓库；
5. （可选）执行 `brew update`、`brew upgrade`、`brew cleanup`。

换新电脑时，一条命令就能把配置文件放回原位，并重新装好所有软件。

整个工具是大约 300 行 Bash 脚本，加上 macOS 自带的定时机制（launchd）。不需要学新命令，也没有常驻后台的程序。

## 适合你吗

| | mac-autosync | [chezmoi](https://www.chezmoi.io) |
|---|---|---|
| 日常使用 | 什么都不用做，每天夜里自动备份 | 需要自己运行 `chezmoi add` 并推送 |
| 密钥保护 | 每次提交前自动扫描 | 用模板配合密码管理器，需要自己配置 |
| Homebrew 软件清单 | 自动保存 | 不包含 |
| 多台电脑使用不同配置 | 不支持 | 支持（模板） |
| 平台 | 仅 macOS | macOS、Linux、Windows |
| 文件夹 | 只支持单个文件 | 文件和文件夹都支持 |

如果你只有一台 Mac，想要一个完全不用操心的备份，选 mac-autosync。如果你要管理多台机器，或者需要每台机器的配置有差异，选 chezmoi。

## 环境要求

- macOS，已安装 [Homebrew](https://brew.sh)
- Git 推送到你的仓库时**不能弹出密码输入**（备份在夜里运行，没有人操作）。例如：HTTPS 配合 macOS 钥匙串或 `gh auth login`，或者不需要输入口令的 SSH 密钥。

## 安装

1. 在 GitHub 上点击 **Use this template → Create a new repository**。**请把你的仓库设为私有**：配置文件里可能有你的邮箱、主机名等信息。
2. 克隆你的新仓库。不要放在“桌面”“文稿”“下载”文件夹里，macOS 可能会阻止后台任务读取这些位置。

   ```bash
   git clone https://github.com/<你的用户名>/<你的仓库>.git ~/Developer/mac-autosync
   cd ~/Developer/mac-autosync
   ```

3. 编辑 `files.txt`（要备份哪些文件）；需要的话再改 `config.sh`（时间和选项）。
4. 检查、安装，并运行第一次备份：

   ```bash
   bash install.sh --check   # 只显示会做什么，不做任何改动
   bash install.sh           # 安装每日任务
   bash sync.sh              # 立即运行第一次备份
   ```

## 选择要备份的文件

`files.txt` 每行写一个文件，路径相对于家目录：

```
.zshrc
.gitconfig
.config/starship.toml
```

加一行，备份和还原就都会包含这个文件。目前只支持单个文件，不支持文件夹。

不要把私钥和 token 文件写进去。常见的敏感文件（`.ssh/id_*`、`*.pem`、`.aws/credentials`、`.netrc`、`.npmrc` 等）即使写了也会被拒绝；其余内容在每次提交前都会经过 gitleaks 扫描。

## 设置

所有设置都在 `config.sh` 里。改完后重新运行一次 `bash install.sh` 生效。

| 设置项 | 默认值 | 含义 |
|---|---|---|
| `SYNC_HOUR`、`SYNC_MINUTE` | 05:23 | 每日备份的时间 |
| `BREWFILE` | `true` | 是否把 Homebrew 软件清单保存到 `Brewfile` |
| `BREW_DAILY` | `true` | 是否每天执行 Homebrew 更新、升级和清理 |
| `BREW_HOUR`、`BREW_MINUTE` | 04:41 | Homebrew 维护的时间 |
| `BREW_UPGRADE_CASKS` | `true` | 是否同时升级用 `brew install --cask` 安装的 App |
| `BREW_CLEANUP_DAYS` | `30` | 清理多少天之前的旧版本和下载缓存 |

如果到点时 Mac 在睡眠，任务会在唤醒后运行；如果 Mac 是关机状态，当天跳过。

如果访问 GitHub 需要代理，在仓库里新建一个 `proxy.env` 文件，写入类似 `export https_proxy=http://127.0.0.1:7890` 的内容。这个文件不会被提交。

## 在新 Mac 上还原

先安装 Homebrew，然后：

```bash
git clone https://github.com/<你的用户名>/<你的仓库>.git ~/Developer/mac-autosync
cd ~/Developer/mac-autosync
bash install.sh --restore   # 把文件放回家目录，并安装 Brewfile 里的所有软件
bash install.sh             # 重新开启每日备份
```

如果某个文件已经存在且内容不同，旧文件会保留为 `<文件名>.bak`。

## 日志

```
~/.local/state/mac-autosync/logs/sync.log
~/.local/state/mac-autosync/logs/brew-daily.log
```

发现疑似密钥时，备份会中止，不会提交任何内容，并弹出一条 macOS 通知。日志里会写明是哪个文件的哪一行。

## 卸载

```bash
bash install.sh --uninstall
```

只会移除两个 launchd 定时任务。你的仓库、配置文件和日志都不会被改动。

## 当前状态

这些脚本是从作者自己 Mac（Apple Silicon）上每天在运行的一套配置整理出来的通用版本。通用版本已通过 shellcheck 检查，以及备份、推送重试、还原和“发现密钥即中止”流程的模拟测试（扫描器用替身程序代替），但它的 launchd 安装步骤还没有在一台全新的 Mac 上实际运行过。建议先运行 `bash install.sh --check`；遇到问题欢迎提 issue。

## 许可证

[MIT](LICENSE)
