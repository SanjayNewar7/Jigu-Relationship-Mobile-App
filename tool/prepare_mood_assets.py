"""Package generated originals and resize transparent PNGs for the mood picker."""
from pathlib import Path
import json
import shutil
from PIL import Image

root = Path(__file__).resolve().parent.parent
rows = json.loads((root / 'tool/mood_asset_sources.json').read_text())
originals = root / 'design/mood-originals'
assets = root / 'assets/moods'
originals.mkdir(parents=True, exist_ok=True)
assets.mkdir(parents=True, exist_ok=True)
for row in rows:
    name = row['name']
    shutil.copyfile(row['source'], originals / f'{name}.png')
    with Image.open(row['source']) as image:
        image.convert('RGBA').resize((256, 256), Image.Resampling.LANCZOS).save(assets / f'{name}.png', optimize=True)
(originals / 'PROMPTS.md').write_text('# Jigu lily moods\n\nGenerated with the built-in image generation tool. Transparent PNG originals; app copies resized to 256 px.\n\n' + '\n\n'.join(f"## {r['name']}\n\n{r['prompt']}" for r in rows), encoding='utf-8')
print(f'Packaged {len(rows)} separate transparent mood PNGs.')
