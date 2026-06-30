#!/bin/bash
#
# 快速修复脚本（无需编译）
# 在越狱 iPhone 上通过 SSH 运行此脚本，启用 LiquidGlass 内置的兼容模式，
# 减少与 ThemePro 的 Hook 冲突。
#
# 使用方法:
#   scp quick_fix.sh root@<device-ip>:/tmp/
#   ssh root@<device-ip> "bash /tmp/quick_fix.sh"
#

WE_CHAT_BUNDLE="com.tencent.xin"

echo "=== WeChat 液态玻璃 + ThemePro 快速修复 ==="
echo ""

# 1. 启用 LiquidGlass 内置兼容模式
echo "[1] 启用 LiquidGlass 兼容模式..."
su mobile -c "defaults write ${WE_CHAT_BUNDLE} flgtb_compat_enabled -bool YES"

# 2. 禁用隐藏 TabBar 标题（可能减少 TabBar 层面的 hook 冲突）
echo "[2] 禁用隐藏 TabBar 标题..."
su mobile -c "defaults write ${WE_CHAT_BUNDLE} flgtb_hide_tabbar_titles -bool NO"

# 3. 禁用下拉小游戏（减少 hook 点）
echo "[3] 禁用下拉小游戏拦截..."
su mobile -c "defaults write ${WE_CHAT_BUNDLE} flg_disable_pulldown_miniprogram -bool YES"

# 4. 禁用语音转文字图标隐藏（减少输入工具栏 hook）
echo "[4] 禁用语音转文字图标隐藏..."
su mobile -c "defaults write ${WE_CHAT_BUNDLE} flg_hide_voice_transcribe_icon -bool NO"

# 5. 确认修改
echo ""
echo "=== 当前配置 ==="
su mobile -c "defaults read ${WE_CHAT_BUNDLE}" 2>/dev/null | grep -E "flgtb_|flg_|wclg_|xg_"

echo ""
echo "=== 修复完成 ==="
echo "请杀掉微信后重新打开:"
echo "  killall -9 WeChat"
echo ""
echo "如果仍然闪退，请更换为编译安装 AACompat 兼容桥接插件。"
echo "详见 README.md"
