# codex-honglvdeng-traffic-light

Codex 红绿灯 / Codex Traffic Light

这是一个 macOS 桌面悬浮小工具，用来显示 Codex 当前状态。

A tiny floating macOS traffic light for Codex status:

- Yellow: Codex is working.
- Green: work is done and ready to review, then auto-idles after 10 minutes.
- Red: Codex is waiting for your reply, approval, or missing input.

状态文件保存在：

```text
~/Library/Application Support/CodexTrafficLight/state.json
```

静音设置保存在：

```text
~/Library/Application Support/CodexTrafficLight/preferences.json
```

## 状态含义

- 黄灯常亮：Codex 正在干活，先别催。
- 绿灯常亮：任务完成，可以验收；10 分钟后自动变为空闲。
- 红灯先闪烁 10 秒，之后常亮：等你回复、确认、授权或补文件。
- 全暗：空闲。

## 提示声

- 黄灯：轻提示音 `Tink`，响一次。
- 绿灯：完成提示音 `Glass`，播放 3 秒。
- 红灯：等待提示音 `Basso`，只提醒 10 秒，之后停止声音和闪烁。

底部左侧有一个很淡的小圆点，是隐藏静音按钮。点一下静音，再点一下恢复；静音后红灯连续提示也会停。

## 怎么打开

双击：

```text
codex-light.command
```

第一次打开会自动编译一次 Swift 原生小窗口。打开后它会悬浮在屏幕上，可以直接拖动位置。

## Install

```bash
git clone https://github.com/st44464322/codex-honglvdeng-traffic-light.git
cd codex-honglvdeng-traffic-light
./build.command
./install-autostart.command
./install-global-command.command
```

Then make sure `~/.codex/bin` is in your shell path:

```bash
export PATH="$HOME/.codex/bin:$PATH"
```

## 怎么切换状态

方式一：双击悬浮灯，按顺序切换状态。

方式二：右键悬浮灯，选择状态。

方式三：双击这些快捷命令：

```text
黄灯-正在干活.command
绿灯-完成验收.command
红灯-等你回复.command
退出红绿灯.command
```

方式四：命令行控制：

```bash
./codex-light working
./codex-light done
./codex-light waiting
./codex-light idle
./codex-light quit
./codex-light status
```

如果已经执行过接入，也可以在任何目录直接用：

```bash
codex-light working
codex-light done
codex-light waiting
codex-light idle
```

## 后面接入脚本

以后任何脚本开始时加：

```bash
/完整路径/codex-light working
```

脚本完成时加：

```bash
/完整路径/codex-light done
```

需要你确认时加：

```bash
/完整路径/codex-light waiting
```

也可以直接包一层运行命令：

```bash
codex-light-run npm run build
codex-light-run python3 your_script.py
```

规则是：

- 命令开始：自动黄灯。
- 命令成功：自动绿灯。
- 命令失败：自动红灯。

## 当前 Codex 工作区接入

当前目录的 `AGENTS.md` 已经写入红绿灯规则。后续在这个工作区执行开发、脚本、自动化、文件处理等任务时，默认按这个规则切灯：

- 开始任务：`codex-light working`
- 完成可验收：`codex-light done`，10 分钟后自动空闲
- 等你确认：`codex-light waiting`
- 空闲：`codex-light idle`

## Codex 自动结束钩子

可以把 Codex hooks 接到：

```text
codex-light-hook
```

规则：

- `UserPromptSubmit` / `PreToolUse`：自动黄灯。
- `PermissionRequest`：自动红灯。
- `Stop`：自动绿灯；如果最后回复像是在等用户确认，会保持红灯。绿灯保持 10 分钟后自动空闲。

参考 `codex-hooks.example.toml`，把内容加入 `~/.codex/config.toml` 后，打开 Codex 执行 `/hooks` 信任一次。

## 开机自启

安装开机自启：

```text
install-autostart.command
```

卸载开机自启：

```text
uninstall-autostart.command
```

安装后，登录 macOS 时会自动打开悬浮红绿灯。
