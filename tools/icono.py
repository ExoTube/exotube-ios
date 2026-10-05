"""Genera el ícono de la app de iPhone (1024 × 1024) y el catálogo de recursos.

Es el mismo dibujo que el ícono de Android (anillo verde y botón de reproducir, en un lienzo de
108), sobre negro: iPhone no admite íconos con transparencia y les redondea las esquinas solo.
Uso: python tools/icono.py
"""
import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'ExoTube', 'Assets.xcassets')
GREEN = (0x2E, 0xE6, 0x7A)
SIZE = 1024


def icon() -> Image.Image:
    scale = 4  # se dibuja 4 veces más grande y se reduce: bordes suaves
    big = Image.new('RGB', (SIZE * scale, SIZE * scale), (0, 0, 0))
    d = ImageDraw.Draw(big)
    # En Android el dibujo ocupa la zona segura de 66 de 108; aquí un poco más grande.
    k = SIZE * scale / 84
    off = (108 - 84) / 2
    pt = lambda x, y: ((x - off) * k, (y - off) * k)
    (x0, y0), (x1, y1) = pt(54 - 28.5, 54 - 28.5), pt(54 + 28.5, 54 + 28.5)
    d.ellipse([x0, y0, x1, y1], fill=GREEN)
    (x0, y0), (x1, y1) = pt(54 - 23.5, 54 - 23.5), pt(54 + 23.5, 54 + 23.5)
    d.ellipse([x0, y0, x1, y1], fill=(0, 0, 0))
    d.polygon([pt(47, 40.5), pt(68, 54), pt(47, 67.5)], fill=GREEN)
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)


write_json(os.path.join(ASSETS, 'Contents.json'), {'info': {'author': 'xcode', 'version': 1}})
icon_dir = os.path.join(ASSETS, 'AppIcon.appiconset')
os.makedirs(icon_dir, exist_ok=True)
icon().save(os.path.join(icon_dir, 'icono-1024.png'))
write_json(os.path.join(icon_dir, 'Contents.json'), {
    'images': [{'filename': 'icono-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
    'info': {'author': 'xcode', 'version': 1},
})
# El color de la pantalla de arranque: negro, como la app.
write_json(os.path.join(ASSETS, 'LaunchBackground.colorset', 'Contents.json'), {
    'colors': [{'idiom': 'universal', 'color': {'color-space': 'srgb', 'components': {
        'red': '0.000', 'green': '0.000', 'blue': '0.000', 'alpha': '1.000'}}}],
    'info': {'author': 'xcode', 'version': 1},
})
print('ícono y recursos listos en', ASSETS)
