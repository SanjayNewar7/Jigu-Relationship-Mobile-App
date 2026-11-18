"""Resize the generated artwork into platform launcher assets."""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parent.parent
image = Image.open(root / 'assets/jigu_logo.png').convert('RGB')
res = root / 'android/app/src/main/res'
for density, size in {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}.items():
    image.resize((size,size), Image.Resampling.LANCZOS).save(res / f'mipmap-{density}/ic_launcher.png')
# Adaptive foreground inset protects petals from circular launcher masks.
foreground = Image.open(root / 'assets/jigu_lily_foreground.png').convert('RGBA')
foreground.resize((432,432), Image.Resampling.LANCZOS).save(res / 'drawable/jigu_lily_icon.png')
store = root / 'release/store'
store.mkdir(parents=True, exist_ok=True)
image.resize((512,512), Image.Resampling.LANCZOS).convert('RGBA').save(store / 'jigu-icon-512.png', optimize=True)
icons = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((icons / 'Contents.json').read_text())['images']:
    size = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
    image.resize((size,size), Image.Resampling.LANCZOS).save(icons / item['filename'])
