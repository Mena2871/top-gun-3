"""
The gist of this file is to define the data structures that make up a sprite.
ASEPRITE is used to create the sprites and export them as JSON.
This JSON is then converted to a binary format that is used by the SNES.

What this script exports
========================
This script converts an Aseprite sprite into a binary format that can be used
in the game. The script takes a single argument, which is the path to the
sprite's directory. The directory should contain the following files:
    {directory_name}.json
    {directory_name}.bin
    {directory_name}.pal

Exporting from Aseprite
=======================
When exporting from Aseprite, the following options should be selected:

    Grid Size: 16x16

    Layout
    ------
    Sheet Type: Packed
    Constraints: Fixed Width: 128px
    [x] Merge Duplicates
    [x] Ignore Empty

    Sprite
    ------
    Layers: Visible layers
    Frames: All frames
    [x] Split Layers
    [x] Split Tags

    Borders
    -------
    Border Padding: 0px
    Spacing: 0px
    Inner Padding: 0px
    [x] Trim Sprite
    [x] Trim Cels
    [x] By Grid
    [ ] Extrude

    Output
    ------
    [x] Output File
    [x] JSON data
    [Hash]
    Meta:
        [x] Layers
        [x] Tags
        [x] Slices
    Item Filename: {tag}__{tagframe}__{layer}

Understanding the JSON format
=============================
When you follow the above steps, Aseprite will generate a JSON file that looks:

{
    "frames": {
        "Forward__0__Plane": {
            "frame": { "x": 0, "y": 0, "w": 64, "h": 32 },
            "rotated": false,
            "trimmed": false,
            "spriteSourceSize": { "x": 0, "y": 0, "w": 64, "h": 32 },
            "sourceSize": { "w": 64, "h": 32 },
            "duration": 100
        },
        "Forward__1__Plane": { ...
        "Forward__2__Plane": { ...
    },

A JSON "Frame" embeds information about the sprite in the name.
- The name is in the format of "Tag__Frame__Layer". 
- The "Tag" is the name of the animation.
- The "Frame" is the index of the frame in the animation.
- The "Layer" is the name of the layer in the frame. Only used for organization.

So, using the example above:
- Tag: Forward
- Frame: 0
- Layer: Plane
- Direction: Forward
- Duration: 100ms
- Image: plane.png
- Offset: (0, 0)
- Size: (64, 32)

The next section is the "meta" section. This is used to define the sprite.

    "meta": {
        "image": "plane.png",
        "size": { "w": 128, "h": 96 },
        "frameTags": [
            { "name": "Forward", "from": 0, "to": 0, "direction": "forward" },
        ],
        "layers": [
            { "name": "Plane", "opacity": 255, "blendMode": "normal" }
        ],
    }
}

The "meta" section is used to define the sprite.
- The "image" is the name of the image file that contains the sprite.
- The "size" is the size of the image file.
- The "frameTags" is a list of animations that make up the sprite.
- The "layers" is a list of layers that make up the sprite.

So, using the example above:
- Image: plane.png
- Size: (128, 96)
- FrameTags: [Forward]
- Layers: [Plane]
"""
import struct
import json
import logging
import pprint
import cv2
import numpy as np

from collections import defaultdict
from pathlib import Path
from dataclasses import dataclass
from typing import List

import struct
from dataclasses import dataclass, field
from typing import List, Tuple


logger_build = logging.getLogger('build')
logger_serialize = logging.getLogger('serialize')


class Helpers:
    """
    Helper functions for serializing data and converting between formats.
    """
    OAM_SIZE_LARGE = 32
    """The large size of the OAM entry in pixels."""

    OAM_SIZE_SMALL = 8
    """The small size of the OAM entry in pixels."""

    OAM_SIZE_LARGE_PROG = 0x10 * 4
    OAM_SIZE_SMALL_PROG = 0x10

    OAM_GROUP_TO_SIZE = { 'small': OAM_SIZE_SMALL, 'big': OAM_SIZE_LARGE }
    """Converts a size group to a size."""

    OAM_GROUP_TO_PROG = { 'small': OAM_SIZE_SMALL_PROG, 'big': OAM_SIZE_LARGE_PROG }

    @staticmethod
    def rgb_to_bgr555(rgbpal: bytearray) -> bytearray:
        """
        Converts a byte array of RGB data to BGR555 bytearray.
        """
        array = np.array([np.reshape(np.frombuffer(rgbpal, dtype=np.uint8), (-1, 3))])
        return cv2.cvtColor(array, cv2.COLOR_BGR2BGR555).flatten()


    @staticmethod
    def to_bytes(data: List[any]) -> bytes:
        """
        :param data: List of data to serialize.
        """
        return b"".join(_.to_bytes() for _ in data)

    @staticmethod
    def oam_to_size_group(w: int, h: int) -> Tuple[int, str, int]:
        """
        Converts the width and height of a tile to a size group.
        :param w: Width of the tile in pixels.
        :param h: Height of the tile in pixels.
        :return: (size, size_group, num_tiles)
        """
        size = Helpers.OAM_SIZE_LARGE
        group = 'big'
        if w < Helpers.OAM_SIZE_LARGE or h < Helpers.OAM_SIZE_LARGE:
            size = Helpers.OAM_SIZE_SMALL
            group = 'small'
        num_tiles = int(np.ceil(max(w, h) / size))
        return (size, group, num_tiles)


@dataclass
class TileHeader:
    """
    A Tile is a single SNES object that makes up a larger sprite.
    This is the fundamental unit of a sprite. It is either large or small.
    """
    prog_ram_addr: int = 0  # Address of tile data in program RAM
    oam_size: int = 0       # Size of OAM entry (small or large)
    rx: int = 0             # Relative X position of tile to the layer
    ry: int = 0             # Relative Y position of tile to the layer

    def to_bytes(self) -> bytes:
        """
        :return: Serialized tile header.
        """
        logger_serialize.debug("\t\t\t\t\tSerializing Tile: prog_ram_addr=%d, oam_size=%d, rx=%d, ry=%d",
            self.prog_ram_addr, self.oam_size, self.rx, self.ry)
        return struct.pack("<3sBBBB",
                           B"TIL",
                           self.prog_ram_addr,
                           self.oam_size,
                           self.rx,
                           self.ry)


@dataclass
class LayerHeader:
    """
    A Layer is a collection of tiles that make up a single SNES object.
    """
    layer_id: int = 0       # Layer index mapping to a layer object (with metadata)
    rx: int = 0             # Relative X position of layer to the sprite
    ry: int = 0             # Relative Y position of layer to the sprite
    tile_data: List[TileHeader] = field(default_factory=list)

    def to_bytes(self) -> bytes:
        """
        :return: Serialized layer header and all of its tile data.
        """
        offset = 0
        tile_data_bytes = Helpers.to_bytes(self.tile_data)

        tile_count = len(self.tile_data)
        tile_offset = offset
        offset += len(tile_data_bytes)

        logger_serialize.debug("\t\t\t\tSerializing Layer: layer_id=%d, rx=%d, ry=%d, num_tiles=%d",
            self.layer_id, self.rx, self.ry, tile_count)

        return (struct.pack("<3sBBBBH",
                            B"LYR",
                            self.layer_id,
                            self.rx,
                            self.ry,
                            tile_count,
                            tile_offset)
                + tile_data_bytes)


@dataclass
class FrameLayerMetadataHeader:
    """
    A Frame is a collection of layers that make up a single SNES object.
    This metadata is used to inform where the layers are in program ROM.
    """
    layer_id: int = 0       # Layer index mapping to a layer object (with metadata)
    offset: int = 0         # Offset to the layer data

    def to_bytes(self) -> bytes:
        """
        :return: Serialized frame layer metadata header.
        """
        logger_serialize.debug("\t\t\t\tSerializing FrameLayerMetadata: layer_id=%d, offset=%d",
            self.layer_id, self.offset)
        return struct.pack("<3sBH", 
                           b"FLM",
                           self.layer_id,
                           self.offset)


@dataclass
class FrameHeader:
    """
    A Frame is a collection of layers that make up a single SNES object.
    """
    num_layers: int = 0        # Number of layers in this frame
    # [FrameLayerMetadataHeader, ...]
    # [Layer Bytes]

    # Fields that are not serialized and used for computing offsets
    layer_data: List[LayerHeader] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: dict) -> "FrameHeader":
        pass

    def to_bytes(self) -> bytes:
        """
        :return: Serialized frame header and all of its layer metadata and data.
        """
        logger_serialize.debug("\t\t\tSerializing Frame: num_layers=%d", self.num_layers)
        layer_data = b''
        running_offset = 0
        layer_metadatas = []
        for i, layer in enumerate(self.layer_data, start=1):
            layer_metadatas.append(
                FrameLayerMetadataHeader(layer.layer_id, running_offset))
            layer_bytes = layer.to_bytes()
            running_offset += len(layer_bytes)
            layer_data += layer_bytes
            num_tiles = len(layer.tile_data)
            logger_serialize.debug("\t\t\t\tSerializing Layer %d: layer_id=%d, rx=%d, ry=%d, num_tiles=%d",
                i, layer.layer_id, layer.rx, layer.ry, num_tiles)

        offset = 0
        layer_metadata_bytes = Helpers.to_bytes(layer_metadatas)

        frame_layer_metadata_count = len(layer_metadatas)
        frame_layer_metadata_offset = offset
        offset += len(layer_metadata_bytes)

        layer_count = len(self.layer_data)
        layer_offset = offset
        offset += len(layer_data)

        return (struct.pack("<3sBBHBH",
                            b"FRM",
                            self.num_layers,
                            frame_layer_metadata_count,
                            frame_layer_metadata_offset,
                            layer_count,
                            layer_offset)
            + layer_metadata_bytes
            + layer_data)


@dataclass
class TagFrameMetadataHeader:
    """
    A Tag is a collection of frames that make up a single SNES object.
    This metadata is used to inform where the frames are in program ROM.
    """
    offset: int = 0         # Offset to the frame data

    def to_bytes(self) -> bytes:
        """
        :return: Serialized tag frame metadata header.
        """
        logger_serialize.debug("\t\tSerializing tag frame metadata: offset=%d", self.offset)
        return struct.pack("<3sH", b"FMD", self.offset)


@dataclass
class TagHeader:
    """
    A Tag is a collection of frames that make up a single SNES object.
    """
    name: str = ""               # Name of the tag
    direction: int = 0           # Animation direction (forward, reverse, ping-pong)
    oam_count: int = 0           # Number of OAM tiles needed for this tag
    frame_data: List[FrameHeader] = field(default_factory=list)
        
    def to_bytes(self) -> bytes:
        frame_data = b''
        running_offset = 0
        frame_metadatas = []
        logger_serialize.debug("\tSerializing tag: %d frames with OAM %d",
                     self.num_frames, self.oam_count)
        for i, frame in enumerate(self.frame_data, start=1):
            frame_metadatas.append(TagFrameMetadataHeader(running_offset))
            frame_bytes = frame.to_bytes()
            logger_build.debug("\t\tFrame %d: %d bytes", i, len(frame_bytes))
            running_offset += len(frame_bytes)
            frame_data += frame_bytes

        offset = 0
        frame_metadatas_bytes = Helpers.to_bytes(frame_metadatas)
        
        frame_metadata_count = len(frame_metadatas)
        frame_metadata_offset = offset
        offset += len(frame_metadatas_bytes)

        frame_count = self.num_frames
        frame_offset = offset
        offset += len(frame_data)

        return (struct.pack("<3sBBBHBH",
                            b"TAG",
                            self.direction,
                            self.oam_count,
                            frame_metadata_count,
                            frame_metadata_offset,
                            frame_count,
                            frame_offset)
                + frame_metadatas_bytes
                + Helpers.to_bytes(self.frame_data))


@dataclass
class TagMetadataHeader:
    """
    A Tag is a collection of frames that make up a single SNES object.
    This metadata is used to inform where the tags are in program ROM.
    """
    offset: int = 0         # Offset to the tag data

    def to_bytes(self) -> bytes:
        logger_serialize.debug("\tSerializing tag metadata: offset=%d", self.offset)
        return struct.pack("<3sH", b"TMD", self.offset)


@dataclass
class SpriteHeader:
    """
    A Sprite is a collection of tags that make up a single SNES object.
    """
    name: str = ""                      # Name of the sprite
    sheet_data: bytearray = field(default_factory=bytearray)
    tag_data: List[TagHeader] = field(default_factory=list)
    tag_metadata: List[TagMetadataHeader] = field(default_factory=list)
    tag_metadata_offset: int = 0
    tag_offset: int = 0

    @classmethod
    def from_dict(cls, data:dict) -> "SpriteHeader":
        """
        Transforms a dictionary representation of the Aseprite sprite into
        a SpriteHeader object.
        """
        logger_build.info("Building sprite header from dictionary")
        data_frames = data["frames"]

        # Identify how many OAM tiles are needed for each layer
        layer_to_frame = defaultdict(set)
        logger_build.debug("Identifying OAM tiles for each layer")
        logger_build.info("Sprite has %d frames", len(data_frames))
        for i, (name, obj) in enumerate(data_frames.items(), start=1):
            f = obj["frame"]
            s = obj["spriteSourceSize"]
            *_, layer = name.split("__")
            x, y, w, h = f["x"], f["y"], s["w"], s["h"]
            logger_build.debug("\tFrame-%d %s = (%s, %d, %d, %d, %d)",
                         i, name, layer, x, y, w, h)
            layer_to_frame[layer].add((x, y, w, h))

        # Identify how many total OAM tiles are needed for each layer
        # This works by iterating through each frame in the layer and
        # calculating the number of tiles needed for each frame.
        layer_to_oam = defaultdict(lambda: {'big': 0, 'small': 0})
        size_to_num_tiles = {'big': 0, 'small': 0}
        logger_build.info("Calculating OAM tiles for each layer")
        for layer, frames in layer_to_frame.items():
            for (x, y, w, h) in frames:
                size, group, num_tiles = Helpers.oam_to_size_group(w, h)
                layer_to_oam[layer][group] += num_tiles
                size_to_num_tiles[group] += num_tiles
                logger_build.debug("\t\tlayer_to_oam[%s][%s] = %d tiles (added %d tiles)",
                    layer, group, layer_to_oam[layer][group], num_tiles)
                logger_build.debug("\t\tsize_to_num_tiles[%s] = %d tiles (added %d tiles)",
                    group, size_to_num_tiles[group], num_tiles)
            logger_build.info("\tLayer %s with %d big tiles and %d small tiles",
                layer, layer_to_oam[layer]['big'], layer_to_oam[layer]['small'])

        # Debug print to show the number of OAM tiles needed for each layer
        if logger_build.isEnabledFor(logging.DEBUG):
            logger_build.debug("layer_to_oam = \n%s",
                         pprint.pformat(dict(layer_to_oam)))
            logger_build.debug("size_to_num_tiles = \n%s",
                         pprint.pformat(dict(size_to_num_tiles)))

        sheet = Path(data["meta"]["image"])
        logger_build.info("Loading sprite sheet %s", sheet)

        # Load the sprite sheet
        sprite_header = cls()
        sprite_header.name = sheet.stem
        sprite_header.num_tags = len(data["meta"]["frameTags"])
        sprite_header.num_layers = len(data["meta"]["layers"])

        # Temporary variables for dimensions
        sheet_width = data["meta"]["size"]["w"]

        # Build the pal data
        pal_bin = sheet.with_suffix(".pal").resolve()
        if not pal_bin.is_file():
            logger_build.error("The palette data %s does not exist. "
                               "Did you run the SNES GFX Tool against your "
                               "sprite?", pal_bin)
            raise FileNotFoundError(pal_bin)
        with open(pal_bin, "rb") as f:
            pal_data = Helpers.rgb_to_bgr555(f.read())
        sprite_header.pal_data = bytearray(pal_data)
        logger_build.info("\tLoaded %d bytes from %s", len(pal_data), pal_bin)

        # Build the sheet data
        sheet_bin = sheet.with_suffix(".bin").resolve()
        if not sheet_bin.is_file():
            logger_build.error("The 4BPP sprite sheet %s does not exist. "
                               "Did you run the SNES GFX Tool against your "
                               "sprite?", sheet_bin)
            raise FileNotFoundError(sheet_bin)
        with open(sheet_bin, "rb") as f:
            sheet_data = f.read()
        sprite_header.sheet_data = bytearray(sheet_data)
        logger_build.info("\tLoaded %d bytes from %s", len(sheet_data), sheet_bin)

        # Build the layers
        layer_names = []
        for i, layer in enumerate(data["meta"]["layers"]):
            name = layer["name"]
            logger_build.debug("\tFound layer %s", name)
            layer_names.append(name)
        layer_names.reverse()

        direction_map = {
            "forward": 0,
            "reverse": 1,
            "pingpong": 2,
        }

        # Build the tags
        logger_build.info("Building tags")
        for i, tag_dict in enumerate(data["meta"]["frameTags"]):
            tag_header = TagHeader()
            tag_name = tag_dict["name"]
            tag_header.name = tag_name
            tag_header.num_frames = tag_dict["to"] - tag_dict["from"] + 1
            tag_header.direction = direction_map[tag_dict["direction"]]

            logger_build.info("\tTag %d: %s with %d frames (dir=%s)",
                i + 1, tag_name, tag_header.num_frames,
                tag_dict["direction"])

            # Build the frames for this tag
            oam_count = 0
            for tag_frame in range(tag_header.num_frames):
                frame_header = FrameHeader()

                logger_build.debug("\t\tFrame %d: Building from layers.", tag_frame + 1)

                # Find layer data for this frame
                layer_count = 0
                for layer_name in layer_names:
                    key = f"{tag_name}__{tag_frame}__{layer_name}"
                    obj = data_frames.get(key)
                    if not obj:
                        logger_build.debug("\t\t\tSkipping %s", key)
                        continue

                    # Build the layer header
                    layer_header = LayerHeader()
                    layer_header.rx = 0
                    layer_header.ry = 0

                    # Get the frame data we need
                    f_data = obj["frame"]

                    # Parse large/small tiles
                    for pretty_name in ("big", "small"):
                        tile_size = Helpers.OAM_GROUP_TO_SIZE[pretty_name]

                        # We don't build layers that don't have any tiles
                        if not layer_to_oam[layer_name][pretty_name]:
                            continue

                        # Get the sprite source size data we need, which will be
                        # used to determine the offset of the tile in the OAM.
                        sss_data = obj["spriteSourceSize"]
                        rx, ry = sss_data["x"], sss_data["y"]
                        x, y = f_data["x"], f_data["y"]
                        w, h = f_data["w"], f_data["h"]

                        # OAM tiles are split between small and big tiles, so
                        # we need to split the tiles based on the determined
                        # tile size.
                        logger_build.debug("\t\t\t%s: %s tile_size=%d (%dx%d)",
                            key, layer_name, tile_size, w, h)
                        k_tile = 0
                        prog_ram_base = 16 * (y // 8) + (x // 8)
                        for i in range(int(np.ceil(h / tile_size))):
                            for j in range(int(np.ceil(w / tile_size))):
                                # Build the tile header
                                k_tile += 1
                                tile_header = TileHeader()
                                tile_header.prog_ram_addr =  prog_ram_base + j * (tile_size // 8)
                                tile_header.oam_size = 1 if pretty_name == "big" else 0
                                tile_header.rx = rx
                                tile_header.ry = ry

                                logger_build.debug("\t\t\t\tTile %d: %d,%d at %d,%d (%d, %d) (rom=%s)",
                                    k_tile, j, i, x, y, rx, ry, hex(tile_header.prog_ram_addr * 16 + 0x7000))

                                # Add the tile header to the layer
                                layer_header.tile_data.append(tile_header)

                                # Add new offsets
                                x += tile_size
                                rx += tile_size

                            # Add new offsets
                            y += tile_size
                            ry += tile_size
                            rx = sss_data["x"]
                            x = f_data["x"]
                            prog_ram_base += Helpers.OAM_GROUP_TO_PROG[pretty_name]
                        frame_header.layer_data.append(layer_header)
                        layer_count += len(layer_header.tile_data)
                    oam_count = max(oam_count, layer_count)
                frame_header.num_layers = len(frame_header.layer_data)
                tag_header.frame_data.append(frame_header)
            tag_header.oam_count = oam_count
            logger_build.debug("\tTag %d (%s) with %d OAM tiles",
                         i + 1, tag_name, oam_count)
            sprite_header.tag_data.append(tag_header)
        logger_build.info("Done building sprite header")
        return sprite_header

    def to_bytes(self) -> bytes:
        # Maximum of 8-bytes for the sprite name
        name_bytes = self.name.encode("ascii", "replace")[:8]

        # Build the tag metadata dynamically
        self.tag_metadatas = []
        tag_data = b''
        running_offset = 0
        logger_serialize.debug("Serializing sprite header: %s", self.name)
        for i, tag in enumerate(self.tag_data, start=1):
            self.tag_metadatas.append(TagMetadataHeader(running_offset))
            data = tag.to_bytes()
            logger_build.debug("\tTag %d: %d bytes", i, len(data))
            running_offset += len(data)
            tag_data += data

        # Computed fields
        magic = b"SPR"
        tag_metadata_bytes = Helpers.to_bytes(self.tag_metadatas)

        offset = 0

        # The count is the number of 16-bit words
        pal_data_count = len(self.pal_data) // 2
        pal_data_offset = offset
        offset += len(self.pal_data)
        logger_build.info("PAL data is at offset %d", pal_data_offset)

        # The count is the number of 16-bit words
        sheet_data_count = len(self.sheet_data) // 2
        sheet_data_offset = offset
        offset += len(self.sheet_data)
        logger_build.info("Sprite sheet data is at offset %d", sheet_data_offset)

        tag_metadata_count = len(self.tag_metadatas)
        tag_metadata_offset = offset
        self.tag_metadata_offset = offset
        offset += len(tag_metadata_bytes)
        logger_build.info("Tag metadata is at offset %d", tag_metadata_offset)

        tag_count = len(self.tag_data)
        tag_offset = offset
        self.tag_offset = offset
        logger_build.info("Tag data is at offset %d", tag_offset)

        # See sprite.asm for the format of the sprite header
        return (struct.pack("<3s8s" "HH" "HH" "BH" "BH",
                            magic,
                            name_bytes,
                            pal_data_count,
                            pal_data_offset,
                            sheet_data_count,
                            sheet_data_offset,
                            tag_metadata_count,
                            tag_metadata_offset,
                            tag_count,
                            tag_offset)
                + self.pal_data
                + self.sheet_data
                + tag_metadata_bytes
                + Helpers.to_bytes(self.tag_data))


class AsepriteParser:
    """
    Top-level parser for an Aseprite sprite exported as a JSON file.
    """
    sprite_dir: Path        # The directory containing the Aseprite sprite data.

    def __init__(self, sprite_dir: Path):
        import os

        # Check if the provided path is a directory, which is needed to
        # read the relatvie paths within the JSON file
        logger_build.info("Reading Aseprite sprite from %s", sprite_dir)
        if not sprite_dir.is_dir():
            raise NotADirectoryError(f"{sprite_dir} is not a directory")
        self.sprite_dir = sprite_dir

        # Read the JSON file from the sprite directory
        basename = sprite_dir.name + ".json"
        json_path = self.sprite_dir / basename
        logger_build.info("Reading Asesprite JSON data from %s", json_path)
        with open(json_path, "r") as json_file:
            json_data = json_file.read()

        # Parse the JSON data and create a SpriteHeader instance
        prev_path = os.getcwd()
        os.chdir(self.sprite_dir)
        self.sprite_header = self.parse_json(json_data)
        os.chdir(prev_path)

    def parse_json(self, json_data: str) -> None:
        """
        Parses the provided JSON string and creates a SpriteHeader instance
        with the corresponding data.

        :param json_data: JSON string containing the Aseprite animation data.
        :return: A SpriteHeader instance with the parsed data.
        """
        data = json.loads(json_data)
        return SpriteHeader.from_dict(data)


def main(argv):
    import argparse

    parser = argparse.ArgumentParser(
        description="Aseprite to SNES Sprite Converter",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        epilog="Example: python aseprite2bin.py -i path_to_sprite_dir")
    parser.add_argument("-i", "--input", type=str, required=True)
    parser.add_argument("-b", "--bank", type=int, required=True)
    parser.add_argument("-l", "--logmode", nargs="*", default=[])
    args = parser.parse_args(argv)

    loggers = {
        "build": logger_build,
        "serialize": logger_serialize
    }

    # Setup basic logging configuration
    logging.basicConfig(level=logging.INFO)

    # Set the log level for each logger
    for logmode in args.logmode:
        if ':' not in logmode:
            valid_loggers = ", ".join(loggers.keys())
            raise ValueError(f"Invalid logmode: {logmode}. "
                             f"Expected format: <logger>:<level>. "
                             f"Logger must be one of {valid_loggers}.")
        logger, log_level = logmode.split(":")
        loggers.get(logger, logging).setLevel(log_level)

    # Parse the Aseprite sprite
    path = Path(args.input).resolve()
    name = path.name
    asepite_parser = AsepriteParser(path)

    # Write the output file
    output_fname = asepite_parser.sprite_dir.name + ".sprite"
    output_path = asepite_parser.sprite_dir / output_fname
    with open(output_path, "wb") as output_file:
        logger_serialize.debug("Serializing sprite header to %s", output_path)
        num_bytes = output_file.write(asepite_parser.sprite_header.to_bytes())
        logger_serialize.info("Wrote sprite header to %s (%d bytes)",
            output_path, num_bytes)

    # Write the animation mapper
    n = name
    pretty_n = name.title().replace('-', '_')
    output_fname = asepite_parser.sprite_dir.name + ".i"
    output_path = asepite_parser.sprite_dir / output_fname
    output_info = f'; Generated by aseprite2bin.py for {n}\n'
    output_info += f'Sprite_{pretty_n}@Data: .incbin "resources/sprites/{n}/{n}.sprite"\n'
    for i, tag_header in enumerate(asepite_parser.sprite_header.tag_data):
        tag_md = asepite_parser.sprite_header.tag_metadatas[i]
        offset = tag_md.offset + asepite_parser.sprite_header.tag_offset
        hex_offset = hex(offset).replace('0x', '$').upper()
        tag_name = tag_header.name.replace('-', '_')
        define_name = f'Sprite_{pretty_n}@Tag@{tag_name}'.ljust(40)
        output_info += f'.define {define_name} {hex_offset} ; {offset}\n'
    bank_name = f'Sprite_{pretty_n}@Bank'.ljust(40)
    output_info += f'.define {bank_name} {args.bank}'
    with open(output_path, "w") as output_file:
        logger_build.debug("Writing animation mapper to %s", output_path)
        num_bytes = output_file.write(output_info)
        logger_build.info("Wrote animation mapper to %s (%d bytes)",
            output_path, num_bytes)

    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv[1:]))