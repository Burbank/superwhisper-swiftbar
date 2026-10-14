#!/usr/bin/env python3
"""Draw the Language Flash dock icon.

The picture is a full-bleed square. macOS masks it to a squircle.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4
N = SIZE * SCALE

RED = (174, 28, 40, 255)
WHITE = (255, 255, 255, 255)
BLUE = (33, 70, 139, 255)
INK = (28, 35, 51, 255)
PAPER = (244, 241, 234, 255)
US_RED = (178, 34, 52, 255)
US_BLUE = (60, 59, 110, 255)


def rounded_mask(box: list[float], radius: int) -> Image.Image:
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def paste_rounded(base: Image.Image, layer: Image.Image, box: list[float], radius: int) -> Image.Image:
    layer.putalpha(rounded_mask(box, radius))
    return Image.alpha_composite(base, layer)


def star(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, fill) -> None:
    points: list[tuple[float, float]] = []
    inner = radius * 0.381966
    angle = math.pi / 2
    step = math.pi / 5
    for index in range(10):
        distance = radius if index % 2 == 0 else inner
        points.append((cx + math.cos(angle) * distance, cy - math.sin(angle) * distance))
        angle -= step
    draw.polygon(points, fill=fill)


def netherlands(box: list[float]) -> Image.Image:
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    band = (y1 - y0) / 3
    for index, color in enumerate((RED, WHITE, BLUE)):
        top = y0 + band * index
        draw.rectangle([x0, top, x1, top + band + SCALE], fill=color)
    return layer


def united_states(box: list[float]) -> Image.Image:
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    stripe = (y1 - y0) / 13
    for index in range(13):
        color = US_RED if index % 2 == 0 else WHITE
        top = y0 + stripe * index
        draw.rectangle([x0, top, x1, top + stripe + SCALE], fill=color)
    canton = [x0, y0, x0 + (x1 - x0) * 0.40, y0 + stripe * 7]
    draw.rectangle(canton, fill=US_BLUE)
    row_height = (canton[3] - canton[1]) / 9
    column_width = (canton[2] - canton[0]) / 6
    radius = min(row_height, column_width) * 0.34
    for row in range(9):
        count = 6 if row % 2 == 0 else 5
        cy = canton[1] + (row + 0.5) * row_height
        for column in range(count):
            if count == 6:
                cx = canton[0] + (column + 0.5) * column_width
            else:
                cx = canton[0] + (column + 1) * column_width
            star(draw, cx, cy, radius, WHITE)
    return layer


def shadow(box: list[float], radius: int) -> Image.Image:
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shifted = [box[0], box[1] + N * 0.012, box[2], box[3] + N * 0.012]
    ImageDraw.Draw(layer).rounded_rectangle(shifted, radius=radius, fill=(20, 24, 32, 80))
    return layer.filter(ImageFilter.GaussianBlur(radius=N * 0.012))


def main() -> None:
    image = Image.new("RGBA", (N, N), PAPER)
    main_box = [N * 0.14, N * 0.30, N * 0.86, N * 0.70]
    main_radius = int(N * 0.035)
    image = Image.alpha_composite(image, shadow(main_box, main_radius))
    image = paste_rounded(image, netherlands(main_box), main_box, main_radius)

    badge = [N * 0.52, N * 0.56, N * 0.90, N * 0.78]
    badge_radius = int(N * 0.028)
    ring = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    pad = N * 0.012
    ring_box = [badge[0] - pad, badge[1] - pad, badge[2] + pad, badge[3] + pad]
    ImageDraw.Draw(ring).rounded_rectangle(ring_box, radius=badge_radius + int(pad), fill=PAPER)
    image = Image.alpha_composite(image, shadow(ring_box, badge_radius + int(pad)))
    image = paste_rounded(image, ring, ring_box, badge_radius + int(pad))
    image = paste_rounded(image, united_states(badge), badge, badge_radius)

    border = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    draw = ImageDraw.Draw(border)
    draw.rounded_rectangle(main_box, radius=main_radius, outline=(*INK[:3], 50), width=SCALE * 3)
    image = Image.alpha_composite(image, border)

    output = image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    destination = Path(__file__).with_name("language-flash-icon.png")
    output.save(destination, "PNG")
    print(destination)


if __name__ == "__main__":
    main()
