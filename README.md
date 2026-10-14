# Codex Pace · Codex 额度节奏

一个轻巧的 macOS 屏幕边缘悬浮条：看剩余额度，也看今天应该用到哪里。

**蓝绿色 = 本周期累计已用；橙线 = 今日累计目标；旁边的「今 xx%」就是目标值。**

- 蓝绿色越过橙线：已超过今日参考目标，今天可以放慢。
- 蓝绿色尚未到橙线：还没达到今日参考目标。
- 鼠标移上去：显示剩余额度、实际已用、当前匀速进度、今晚累计目标及重置时间。
- 鼠标移开：收回小条；拖动调整位置；点击固定详情；右键刷新或退出。
- 每分钟更新额度；目标随时间更新。请求失败显示上次读数，缺少周期信息时不编造目标。

## 下载与安装

[**下载最新版 macOS 安装包**](https://github.com/bethlehem1989-tech/codex-pace/releases/latest)

支持 **macOS 14+，Apple Silicon 和 Intel**。需要本机已有 Codex 登录，以及单独安装的 [CodexBar](https://github.com/steipete/CodexBar)。CodexBar 不需要保持打开。

1. 下载并解压 `Codex-Pace-1.0.0-macOS-universal.zip`。
2. 双击 `Install.command`。若已有 Homebrew，会自动安装缺少的 CodexBar，再将 Codex Pace 安装到 `~/Applications` 并打开。
3. 将鼠标移到屏幕右侧的小条上。

没有 Homebrew时，可以先从 [CodexBar Releases](https://github.com/steipete/CodexBar/releases) 安装 CodexBar 到 `/Applications`，再把 `Codex Pace.app` 拖到「应用程序」打开。

安装包是临时本地签名，**尚未 Apple 公证**。首次打开若被系统阻止，请前往「系统设置 → 隐私与安全性」允许打开。不需要关闭系统安全保护。

需要登录后自动启动时，可以在 macOS「系统设置 → 通用 → 登录项」中添加 Codex Pace。默认不会注册后台启动项。

## 目标怎么算

目标按**额度窗口内均匀使用**计算，与固定 Token 数量不同：

```text
周期开始 = 服务端重置时间 − 服务端窗口时长
当前参考进度 = 已经过的周期时间 / 周期总时长 × 100%
今日累计目标 = min(中国时间次日 00:00, 重置时间) 对应的周期进度
实际已用 = 100% − 剩余额度
```

例如：今日目标 35%，实际累计已用 48%，蓝绿条就会超过橙线，提示「已超过今日目标 13 个百分点」。实际只用了 20%，则还差 15 个百分点。

这是一条规划参考线，不是必须消耗的额度，也不能保证精确预测剩余请求数。不同任务和模型的额度消耗可能不同。`Credits` 是服务端单独返回的余额，不拿来充当 Token 数或每日目标。目标日界按 **Asia/Shanghai（中国时间）**；今天更早重置时，目标截止到重置时刻。

当前面向拥有每周窗口的 Codex 账号；服务端未返回每周窗口时会显示读取错误，缺少短期窗口时则正常显示每周用量。

## 本地开发

需要 macOS 14+ 和 Xcode Command Line Tools / Xcode。没有第三方 Swift 包依赖。

```bash
git clone https://github.com/bethlehem1989-tech/codex-pace.git
cd codex-pace
./script/check_pace.sh           # 可在仅安装 Command Line Tools 的机器上运行
./script/build_app.sh            # 构建本机架构的 App
open "dist/Codex Pace.app"
./script/package_release.sh      # 构建 Apple Silicon + Intel 通用安装包
```

安装了完整 Xcode 的机器也可以运行 `swift test`。`./script/check_pace.sh --live` 会额外读取本机真实账号额度；默认测试和 CI 不需要登录，也不访问账号数据。

悬停窗口集成检查：

```bash
"dist/Codex Pace.app/Contents/MacOS/CodexUsageNano" --self-test-hover
```

内部 Swift 模块与可执行文件名称沿用了 `CodexUsageNano`，桌面应用名称是 Codex Pace。

## 隐私与卸载

没有遥测、自己的服务器或账号注册。应用仅调用本机 `/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI`，由它通过当前 Codex 登录读取额度。不会将凭据、会话记录或账号数据发送到本项目或 GitHub。

显示快照仅包含额度和时间，保存在 `~/Library/Application Support/CodexPace/` 和 `/private/tmp/codex-pace/`；窗口偏好保存在 `io.github.bethlehem1989tech.CodexPace` 域中。源码和发布包均不包含任何用户账号数据。

卸载时先右键退出，再移除 `Codex Pace.app`。需要时可一并删除上述显示快照目录。

## 开源与致谢

MIT License。基于 [AkiGarage/codex-usage-nano](https://github.com/AkiGarage/codex-usage-nano) 修改，保留上游版权及许可；额度读取依赖单独安装的 [steipete/CodexBar](https://github.com/steipete/CodexBar)。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

这是独立社区项目，与 OpenAI 无隶属关系。
