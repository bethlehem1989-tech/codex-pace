# Codex Pace · Codex 额度节奏

一个简单的 macOS 屏幕边缘悬浮条，只看两种进度：

- **微信绿（#07C160）**：整个额度周期累计用了多少。
- **橙线（#FF9500）**：按当前时间，本应累计用到多少。

绿色越过橙线表示用得偏快；还没到橙线表示用得偏慢。收起时只有一条短条，没有数字。鼠标移上去只显示「已用 xx%」和「应到 xx%」，移开收起。拖动调整位置，点击固定这两个数字，右键刷新或退出。

## 下载与安装

[**下载最新版 macOS 安装包**](https://github.com/bethlehem1989-tech/codex-pace/releases/latest)

支持 **macOS 14+，Apple Silicon 和 Intel**。需要本机已有 Codex 登录，以及单独安装的 [CodexBar](https://github.com/steipete/CodexBar)。CodexBar 不需要保持打开。

1. 下载并解压 `Codex-Pace-1.0.1-macOS-universal.zip`。
2. 双击 `Install.command`。若已有 Homebrew，会自动安装缺少的 CodexBar，再安装到 `~/Applications` 并打开。
3. 将鼠标移到屏幕右侧的小条上。

没有 Homebrew 时，可以先从 [CodexBar Releases](https://github.com/steipete/CodexBar/releases) 安装 CodexBar 到 `/Applications`，再把 `Codex Pace.app` 拖到「应用程序」打开。

安装包是临时本地签名，**尚未 Apple 公证**。首次打开若被系统阻止，请前往「系统设置 → 隐私与安全性」允许打开。不需要关闭系统安全保护。默认不注册后台启动项；如有需要，可在 macOS 登录项中自行添加。

## 橙线怎么算

```text
周期开始 = 服务端重置时间 − 服务端窗口时长
橙线进度 = (当前时间 − 周期开始) / 周期总时长 × 100%
绿色进度 = 100% − 剩余额度
```

橙线随当前时间推进，表示在本周期内匀速使用额度的参考位置。例如绿色 40%、橙线 20%，说明当前实际使用比匀速进度快 20 个百分点。

百分比是额度用量，不是固定 Token 数，也不是 Credits。无需为了追上橙线而消耗不需要的额度。缺少周期信息或周期已过期时，不显示虚构的目标。每分钟更新额度，每 30 秒更新时间进度；悬停时若读取过期或刷新失败，会注明「上次读数」。目前面向拥有每周额度窗口的账号，短期窗口缺失不影响使用。

## 本地开发

需要 macOS 14+ 和 Xcode Command Line Tools / Xcode；没有第三方 Swift 包依赖。

```bash
git clone https://github.com/bethlehem1989-tech/codex-pace.git
cd codex-pace
./script/check_pace.sh
./script/build_app.sh
open "dist/Codex Pace.app"
./script/package_release.sh
```

完整 Xcode 下可运行 `swift test`。`./script/check_pace.sh --live` 会额外读取本机真实额度；默认测试和 CI 使用合成数据，不需要登录。

悬停窗口检查：

```bash
"dist/Codex Pace.app/Contents/MacOS/CodexUsageNano" --self-test-hover
```

内部模块和可执行文件名称沿用 `CodexUsageNano`，桌面应用名称为 Codex Pace。

## 隐私与卸载

没有遥测、自己的服务器或账号注册。应用只调用本机 `/Applications/CodexBar.app/Contents/Helpers/CodexBarCLI`，通过当前 Codex 登录读取额度。不会把凭据、会话记录或账号数据发送到本项目或 GitHub。

显示快照仅含额度和时间，位于 `~/Library/Application Support/CodexPace/` 和 `/private/tmp/codex-pace/`；窗口偏好使用 `io.github.bethlehem1989tech.CodexPace` 域。源码和发布包不含用户账号数据。

卸载时先右键退出，再移除 App；需要时可删除上述快照目录。

## 开源与致谢

MIT License。基于 [AkiGarage/codex-usage-nano](https://github.com/AkiGarage/codex-usage-nano) 修改，保留上游版权与许可；额度读取依赖单独安装的 [steipete/CodexBar](https://github.com/steipete/CodexBar)。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

这是独立社区项目，与 OpenAI 无隶属关系。
