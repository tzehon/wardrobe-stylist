import json
import struct
import unittest
from pathlib import Path


APP_ICON_SET = (
    Path(__file__).parents[2]
    / "Wardrobe"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)
MASTER_ICON = APP_ICON_SET / "AppIcon-1024.png"


class AppIconAssetTests(unittest.TestCase):
    def test_catalog_points_to_one_universal_1024_master(self) -> None:
        contents = json.loads((APP_ICON_SET / "Contents.json").read_text())

        self.assertEqual(
            contents["images"],
            [
                {
                    "filename": MASTER_ICON.name,
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                }
            ],
        )

    def test_master_icon_is_square_rgb_and_fully_opaque(self) -> None:
        data = MASTER_ICON.read_bytes()
        self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")

        ihdr_length = struct.unpack(">I", data[8:12])[0]
        self.assertEqual(data[12:16], b"IHDR")
        self.assertEqual(ihdr_length, 13)
        width, height, bit_depth, color_type = struct.unpack(">IIBB", data[16:26])

        self.assertEqual((width, height), (1024, 1024))
        self.assertEqual(bit_depth, 8)
        self.assertEqual(color_type, 2, "App icon must be opaque truecolor RGB")
        self.assertNotIn(b"tRNS", data, "App icon must not contain transparency")


if __name__ == "__main__":
    unittest.main()
