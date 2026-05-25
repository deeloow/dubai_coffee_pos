#!/usr/bin/env python3
"""
Script to generate app icons from a source image for all platforms.
This script requires PIL/Pillow to be installed.
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("PIL/Pillow is required. Install it with: pip install Pillow")
    sys.exit(1)

# Define the project root
PROJECT_ROOT = Path(__file__).parent

# Define icon sizes needed for each platform
ICON_SIZES = {
    "android": {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    },
    "ios": {
        "Icon-App-20x20@1x": 20,
        "Icon-App-20x20@2x": 40,
        "Icon-App-20x20@3x": 60,
        "Icon-App-29x29@1x": 29,
        "Icon-App-29x29@2x": 58,
        "Icon-App-29x29@3x": 87,
        "Icon-App-40x40@1x": 40,
        "Icon-App-40x40@2x": 80,
        "Icon-App-40x40@3x": 120,
        "Icon-App-60x60@2x": 120,
        "Icon-App-60x60@3x": 180,
        "Icon-App-76x76@1x": 76,
        "Icon-App-76x76@2x": 152,
        "Icon-App-83.5x83.5@2x": 167,
        "Icon-App-1024x1024@1x": 1024,
    },
    "web": {
        "favicon": 32,
        "logo192": 192,
        "logo512": 512,
    },
    "windows": {
        "icon": 256,
    },
    "linux": {
        "icon": 256,
    },
    "macos": {
        "icon": 512,
    }
}

def generate_icons(source_image_path):
    """Generate icons from source image for all platforms."""
    
    if not os.path.exists(source_image_path):
        print(f"Error: Source image not found at {source_image_path}")
        sys.exit(1)
    
    # Open the source image
    try:
        img = Image.open(source_image_path)
        print(f"Loaded image: {source_image_path}")
    except Exception as e:
        print(f"Error loading image: {e}")
        sys.exit(1)
    
    # Generate Android icons
    print("\nGenerating Android icons...")
    android_res_path = PROJECT_ROOT / "android" / "app" / "src" / "main" / "res"
    for dir_name, size in ICON_SIZES["android"].items():
        output_dir = android_res_path / dir_name
        output_dir.mkdir(parents=True, exist_ok=True)
        
        icon_img = img.copy()
        icon_img.thumbnail((size, size), Image.Resampling.LANCZOS)
        # Create a new image with the desired size (square)
        new_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        offset = ((size - icon_img.size[0]) // 2, (size - icon_img.size[1]) // 2)
        new_img.paste(icon_img, offset, icon_img if icon_img.mode == "RGBA" else None)
        
        output_path = output_dir / "ic_launcher.png"
        new_img.save(output_path, "PNG")
        print(f"  ✓ {output_path}")
    
    # Generate iOS icons
    print("\nGenerating iOS icons...")
    ios_icons_path = PROJECT_ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_icons_path.mkdir(parents=True, exist_ok=True)
    for icon_name, size in ICON_SIZES["ios"].items():
        icon_img = img.copy()
        icon_img.thumbnail((size, size), Image.Resampling.LANCZOS)
        new_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        offset = ((size - icon_img.size[0]) // 2, (size - icon_img.size[1]) // 2)
        new_img.paste(icon_img, offset, icon_img if icon_img.mode == "RGBA" else None)
        
        output_path = ios_icons_path / f"{icon_name}.png"
        new_img.save(output_path, "PNG")
        print(f"  ✓ {output_path}")
    
    # Generate web icons
    print("\nGenerating web icons...")
    web_icons_path = PROJECT_ROOT / "web" / "icons"
    web_icons_path.mkdir(parents=True, exist_ok=True)
    icon_img = img.copy()
    icon_img.thumbnail((192, 192), Image.Resampling.LANCZOS)
    new_img = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    offset = ((192 - icon_img.size[0]) // 2, (192 - icon_img.size[1]) // 2)
    new_img.paste(icon_img, offset, icon_img if icon_img.mode == "RGBA" else None)
    
    output_path = web_icons_path / "Icon-192.png"
    new_img.save(output_path, "PNG")
    print(f"  ✓ {output_path}")
    
    icon_img = img.copy()
    icon_img.thumbnail((512, 512), Image.Resampling.LANCZOS)
    new_img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    offset = ((512 - icon_img.size[0]) // 2, (512 - icon_img.size[1]) // 2)
    new_img.paste(icon_img, offset, icon_img if icon_img.mode == "RGBA" else None)
    
    output_path = web_icons_path / "Icon-512.png"
    new_img.save(output_path, "PNG")
    print(f"  ✓ {output_path}")
    
    print("\n✅ All icons generated successfully!")

if __name__ == "__main__":
    source_image = PROJECT_ROOT / "assets" / "icon.png"
    if len(sys.argv) > 1:
        source_image = Path(sys.argv[1])
    
    generate_icons(str(source_image))
