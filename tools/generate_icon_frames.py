"""Generate matching Classic icon frames and an artwork mask (32-bit TGA)."""
from pathlib import Path
import math
import struct

SIZE, SAMPLES = 128, 4
MEDIA = Path(__file__).resolve().parents[1] / 'BagSmith' / 'Media'


def distance(x, y):
    return min(x - .015, y - .015, .985 - x, .985 - y,
               (x + y - .10) / math.sqrt(2),
               (1 - x + y - .10) / math.sqrt(2),
               (x + 1 - y - .10) / math.sqrt(2),
               (2 - x - y - .10) / math.sqrt(2))


def generate():
    pixels = {name: bytearray() for name in ('frame', 'frame-bold', 'mask')}
    for y in range(SIZE):
        for x in range(SIZE):
            ring = inside = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    d = distance((x + (sx + .5) / SAMPLES) / SIZE,
                                 (y + (sy + .5) / SAMPLES) / SIZE)
                    ring += 0 <= d <= .035
                    inside += d >= .030
            alpha = round(255 * ring / SAMPLES**2)
            # A subtle bevel; Bold changes RGB only, never coverage.
            shade = round(140 + 35 * (y + SIZE - x) / (2 * SIZE))
            for name, value in (('frame', shade), ('frame-bold', shade + 80)):
                pixels[name].extend((value, value, value, alpha))
            pixels['mask'].extend((255, 255, 255, round(255 * inside / SAMPLES**2)))
    header = struct.pack('<BBBHHBHHHHBB', 0, 0, 10, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 8)
    for name, data in pixels.items():
        encoded = bytearray()
        for row in range(SIZE):
            pos, end = row * SIZE * 4, (row + 1) * SIZE * 4
            while pos < end:
                pixel = data[pos:pos + 4]
                count = 1
                while pos + count * 4 < end and count < 128 and data[pos + count * 4:pos + count * 4 + 4] == pixel:
                    count += 1
                encoded.append(127 + count)
                encoded.extend(pixel)
                pos += count * 4
        (MEDIA / f'ui-icon-{name}.tga').write_bytes(header + encoded)


if __name__ == '__main__':
    generate()
