"""
Converts a Tiled map to the binary format used by the game.
See engine/map.asm for the format specification.
"""
import pathlib
import argparse
import struct
import pytmx
import logging
import cv2
import numpy as np


logger = logging.getLogger(__name__)

class Exporter:

    # This field is specifically mapped to the tileset struct in the game.
    fields = []

    def __init__(self):
        """
        Initialize the tileset with default values.
        """
        self.data = []
        for name, fmt in self.fields:
            setattr(self, name, 0)

    def append(self, obj) -> None:
        """
        Append data to the end of the struct.
        """
        self.data.append(obj)

    def pack(self) -> bytes:
        """
        Pack the object into a binary string based on the fields.
        Appends the data as bytes to the end of the string.
        """
        # Initially create the pack string with the fields.
        pack_str = ''.join(fmt for _, fmt in self.fields)

        # Pack the data from the children.
        packed_data = bytearray([])
        for obj in self.data:
            if isinstance(obj, Exporter):
                packed_data.extend(obj.pack())
            else:
                packed_data.extend(bytearray([obj]))

        # Add the data to the end of the pack string.
        pack_str += f'{len(packed_data)}B'
        
        all_data = []
        for name, width in self.fields:
            obj = getattr(self, name)
            if isinstance(obj, bytearray):
                width = int(width.replace('B', ''))
                all_data.extend(obj)
                if len(obj) < width:
                    for i in range(width - len(obj)):
                        all_data.append(0)
            else:
                all_data.append(obj)
        all_data.extend(packed_data)

        return struct.pack(pack_str, *all_data)

    def num_bytes(self) -> int:
        """
        Return the number of bytes that will be written to the file.
        """
        return len(self.pack())


class Tile(Exporter):
    fields = [
        ('id', 'H'),
        ('index', 'H'),
    ]

    def __init__(self, pk, version, index):
        super().__init__()
        self.id = pk
        self.index = index

class Background(Exporter):
    fields = [
        ('id', 'H'),
        ('num_tiles', 'H'),
    ]


class SpriteSheet(Exporter):
    fields = [
        ('magic', '3B'),
        ('bpp', 'B'),
        ('size', 'H'),
        ('width', 'B'),
        ('height', 'B'),
        ('num_rows', 'B'),
        ('num_cols', 'B'),
    ]

class Palette(Exporter):
    fields = [
        ('magic', '3B'),
        ('num_colors', 'B'),
        ('size', 'H'),
    ]


class Map(Exporter):
    fields = [
        ('magic', '3B'),
        ('version', 'B'),
        ('name', '16B'),
        ('num_backgrounds', 'B'),
        ('num_objects', 'B'),
        ('tile_width', 'B'),
        ('tile_height', 'B'),
        ('height', 'B'),
        ('width', 'B'),
        ('background_offset', 'H'),
        ('sprite_offset', 'H'),
        ('palette_offset', 'H'),
        ('object_offset', 'H'),
    ]

    def __init__(self, tmx_map):
        super().__init__()
        self.load(tmx_map)

    def rgb_to_bgr555(self, rgbpal: bytearray) -> bytearray:
        """
        Converts a byte array of RGB data to BGR555 bytearray.
        """
        array = np.array([np.reshape(np.frombuffer(rgbpal, dtype=np.uint8), (-1, 3))])
        return cv2.cvtColor(array, cv2.COLOR_BGR2BGR555).flatten()

    def load(self, tmx_map):
        """
        Loads a TMX map and converts it to the binary format.
        """
        # Set the magic number and version.
        self.magic = bytearray(b'TMX')
        self.version = 1

        tiled_map = pytmx.TiledMap(tmx_map, allow_duplicate_names=True, load_all_tiles=True)

        # Set the common map properties.
        self.name = bytearray(tiled_map.name.encode('ascii'))
        self.tile_width = tiled_map.tilewidth
        self.tile_height = tiled_map.tileheight
        self.width = tiled_map.width
        self.height = tiled_map.height

        # (HACK): Background offset is fixed by field offset in the map struct.
        self.background_offset = sum(struct.calcsize(fmt) for _, fmt in self.fields)

        # This will be updated as each tile is added
        self.sprite_offset = self.background_offset

        # (HACK): Not supporting multiple layers
        layer = tiled_map.layers[0]

        # (HACK): Not support multiple sprite sheets
        sprite_sheet = pathlib.Path(tmx_map).parent / pathlib.Path(tiled_map.tilesets[0].source)

        # Load all non-zero tile from the layer.
        for layer in tiled_map.layers:
            if not layer.name.startswith('BG'):
                continue

            background = Background()
            background.num_tiles = 0
            background.id = int(layer.name[-1])
            for x, y, gid in layer.iter_data():
                if gid == 0:
                    continue

                tid = tiled_map.tiledgidmap[gid]

                # Add the tile and increment the counter tracking
                index = (y * 0x20) + x # (HACK): Hardcoded map size and assumes 8x8
                ntid = 2 * (tid - 1)
                ntid += ((tid - 1) // 8) * 16
                tile = Tile(ntid, version=0, index=index)
                background.append(tile)
                background.num_tiles += 1
            print(f'num_tiles: {hex(background.num_tiles)}')

            # Update the sprite offset for data tracking
            self.sprite_offset += background.num_bytes()
            self.num_backgrounds += 1

            # Update the background data for the map
            self.append(background)

        # Update the palette offset for data tracking
        self.palette_offset = self.sprite_offset

        # Get the sprite sheet and load the palette.
        sprite = SpriteSheet()
        sprite.magic = bytearray(b'SPR')
        sprite.bpp = 4
        sprite.width = 16
        sprite.height = 16
        sprite.num_rows = 3
        sprite.num_cols = 3
        path = sprite_sheet.with_suffix('.bin')
        with open(path, 'rb') as fd:
            data_4bpp = fd.read()
            sprite.data.extend(data_4bpp)
            sprite.size = len(data_4bpp)
        self.append(sprite)

        # Update the palette offset for data tracking
        self.palette_offset += sprite.num_bytes()

        # Load color data for the sprite sheet.
        palette = Palette()
        palette.magic = bytearray(b'PAL')
        palette.num_colors = 16
        path = sprite_sheet.with_suffix('.pal')
        self.object_offset = self.palette_offset
        with open(path, 'rb') as fd:
            data_pal = fd.read()
            bgr555_data = self.rgb_to_bgr555(data_pal)
            palette.size = len(bgr555_data)
            print('pal', palette.size)
            palette.data.extend(bgr555_data)
        self.append(palette)

        # Update the object offset for data tracking
        self.object_offset += palette.num_bytes()

        print(self.sprite_offset)
        print(self.palette_offset)


def main():
    """
    Load a Tiled map and export it to a binary file that can be
    loaded by the game.
    """
    args = argparse.ArgumentParser()
    args.add_argument('input')
    args.add_argument('output')
    parsed = args.parse_args()

    # Create the map and export it.
    tile_map = Map(parsed.input)
    with open(parsed.output, 'wb') as f:
        f.write(tile_map.pack())
    
if __name__ == '__main__':
    main()