#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
printf '\nCodex Pace · 额度节奏\n\n'
if [[ ! -x /Applications/CodexBar.app/Contents/Helpers/CodexBarCLI ]]; then
  BREW="$(command -v brew || true)"
  [[ -n "$BREW" ]] || [[ ! -x /opt/homebrew/bin/brew ]] || BREW=/opt/homebrew/bin/brew
  [[ -n "$BREW" ]] || [[ ! -x /usr/local/bin/brew ]] || BREW=/usr/local/bin/brew
  if [[ -z "$BREW" ]]; then
    printf '请先从 https://github.com/steipete/CodexBar/releases 安装 CodexBar 到“应用程序”，再运行本安装程序。\n'
    open https://github.com/steipete/CodexBar/releases
    read -r -p '按回车退出。' _reply
    exit 1
  fi
  "$BREW" install --cask codexbar
fi
mkdir -p "$HOME/Applications"
APP="$HOME/Applications/Codex Pace.app"
if [[ -d "$APP" ]]; then
  BACKUP="$HOME/Applications/Codex Pace-backup-$(date +%Y%m%d-%H%M%S).app"
  mv "$APP" "$BACKUP"
fi
ditto 'Codex Pace.app' "$APP"
open "$APP"
printf '\n已安装到 ~/Applications。鼠标移到右侧小条即可查看“已用”和“应到”。\n'
printf '微信绿=累计已用，橙线=当前本应达到；超过橙线表示用得偏快。\n'
printf '若 macOS 阻止打开，请前往“系统设置 → 隐私与安全性”允许打开 Codex Pace。\n'
read -r -p '按回车关闭本窗口。' _reply
