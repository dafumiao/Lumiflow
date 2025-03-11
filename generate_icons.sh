#!/bin/bash

# 检查原始图标是否存在
if [ ! -f "icon_original.png" ]; then
    echo "错误：找不到icon_original.png文件"
    echo "请将MidJourney生成的图标放在当前目录并命名为icon_original.png"
    exit 1
fi

# 检查ImageMagick是否已安装
if ! command -v convert &> /dev/null; then
    echo "错误：找不到ImageMagick的convert命令"
    echo "请先安装ImageMagick："
    echo "macOS: brew install imagemagick"
    echo "Ubuntu: sudo apt-get install imagemagick"
    exit 1
fi

# 创建目标目录
mkdir -p Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset

# 生成iPhone图标
convert icon_original.png -resize 120x120 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-60@2x.png
convert icon_original.png -resize 180x180 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-60@3x.png

# 生成iPad图标
convert icon_original.png -resize 76x76 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-76.png
convert icon_original.png -resize 152x152 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-76@2x.png
convert icon_original.png -resize 167x167 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-83.5@2x.png

# 生成App Store图标
convert icon_original.png -resize 1024x1024 Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png

echo "图标生成完成！"
echo "已在Lumiflow/Lumiflow/Assets.xcassets/AppIcon.appiconset目录中创建所有所需尺寸的图标" 