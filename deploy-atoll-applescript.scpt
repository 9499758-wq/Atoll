-- 用系统管理员权限弹窗部署 Atoll（密码框由 macOS 弹出，不经过任何脚本参数）
-- 双击本文件，或在终端运行： osascript deploy-atoll-applescript.scpt
do shell script "zsh /Users/yunyinglaohe/Documents/Codex/Atoll-src/deploy-atoll.sh" with administrator privileges
