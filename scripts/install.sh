#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

make sign
make install
make register
open "$HOME/Applications/ReviveRight.app"

echo ""
echo "ReviveRight（右键复活）已安装到 ~/Applications/ReviveRight.app"
echo "扩展已注册并启用（com.shining.rightkit.FinderSync）。"
echo "若右键菜单未出现：系统设置 → 通用 → 登录项与扩展 → 文件提供程序 → 启用「右键复活扩展」。"
