"""Checks framed screenshots and header images, and the Asset Library placement plan."""
import os
import tempfile
import unittest

from PIL import Image

import frame_media
import library
from slots import HEADERS, SLOTS

TEAL = frame_media.TEAL
GOLD = frame_media.GOLD


def _catalog():
    def spec(sid, w, h, types, universal=False):
        return {
            "specId": sid,
            "dimensions": {"minWidth": w, "maxWidth": w, "minHeight": h, "maxHeight": h},
            "compatiblePlacementTypes": types,
            "universalAsset": universal,
            "alphaAllowed": False,
        }
    return {
        "placementProfileGroups": [
            {"placementProfileGroupId": "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE",
             "platform": "IPHONE_APP_STORE", "displayClassId": "IPHONE_DYNAMIC_ISLAND_LARGE_DISPLAY"},
            {"placementProfileGroupId": "IPHONE_FACE_ID_LARGE_PROFILE",
             "platform": "IPHONE_APP_STORE", "displayClassId": "IPHONE_FACE_ID_LARGE_DISPLAY"},
            {"placementProfileGroupId": "IPAD_13_PROFILE",
             "platform": "IPAD_APP_STORE", "displayClassId": "IPAD_13_DISPLAY"},
            {"placementProfileGroupId": "MAC_PROFILE", "platform": "MAC_APP_STORE", "displayClassId": "DEFAULT"},
            {"placementProfileGroupId": "TV_PROFILE", "platform": "TV_APP_STORE", "displayClassId": "DEFAULT"},
            {"placementProfileGroupId": "VISION_PROFILE", "platform": "VISION_PRO_APP_STORE", "displayClassId": "DEFAULT"},
            {"placementProfileGroupId": "CREATIVE_IOS", "platform": "IPHONE_APP_STORE", "displayClassId": "DEFAULT"},
        ],
        "imageSpecs": [
            spec("s69", 1320, 2868, ["APP_SCREENSHOT"]),
            spec("s65", 1284, 2778, ["APP_SCREENSHOT"]),
            spec("s13", 2064, 2752, ["APP_SCREENSHOT"]),
            spec("smac", 2880, 1800, ["APP_SCREENSHOT"]),
            spec("stv", 1920, 1080, ["APP_SCREENSHOT"]),
            spec("svis", 3840, 2160, ["APP_SCREENSHOT"]),
            spec("header", 3840, 1646, ["PRODUCT_PAGE_HEADER_ASSET"]),
            spec("universal", 5244, 2950, ["PRODUCT_PAGE_HEADER_ASSET", "APP_STORE_SEARCH_RESULTS_ASSET"], universal=True),
        ],
        "placementTypes": [
            {"placementTypeId": "APP_SCREENSHOT", "acceptsAssetCategories": ["APP_SCREENSHOTS_AND_PREVIEWS"],
             "specMappings": [
                 {"placementGroupId": "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE", "specs": ["s69"]},
                 {"placementGroupId": "IPHONE_FACE_ID_LARGE_PROFILE", "specs": ["s65"]},
                 {"placementGroupId": "IPAD_13_PROFILE", "specs": ["s13"]},
                 {"placementGroupId": "MAC_PROFILE", "specs": ["smac"]},
                 {"placementGroupId": "TV_PROFILE", "specs": ["stv"]},
                 {"placementGroupId": "VISION_PROFILE", "specs": ["svis"]},
             ]},
            {"placementTypeId": "PRODUCT_PAGE_HEADER_ASSET", "acceptsAssetCategories": ["CREATIVE_ASSETS"],
             "specMappings": [{"placementGroupId": "CREATIVE_IOS", "specs": ["header", "universal"]}]},
            {"placementTypeId": "APP_STORE_SEARCH_RESULTS_ASSET", "acceptsAssetCategories": ["CREATIVE_ASSETS"],
             "specMappings": [{"placementGroupId": "CREATIVE_IOS", "specs": ["universal"]}]},
        ],
    }


class FrameTests(unittest.TestCase):
    def test_frames_and_headers_are_exact_rgb(self):
        with tempfile.TemporaryDirectory() as tmp:
            raw, out, headers = (os.path.join(tmp, name) for name in ("raw", "out", "headers"))
            for device in SLOTS:
                folder = os.path.join(raw, device)
                os.makedirs(folder)
                Image.new("RGB", (80, 140), (20, 40, 50)).save(os.path.join(folder, "01-today.png"))
            frame_media.generate(raw, out, headers)
            self.assertEqual(frame_media.verify(out, headers), [])
            for name, spec in HEADERS.items():
                img = Image.open(os.path.join(headers, name))
                self.assertEqual(img.mode, "RGB")
                self.assertEqual(img.size, spec["size"])
                self.assertEqual(img.getpixel((0, 0)), TEAL)
                self.assertEqual(img.getpixel((img.size[0] - 1, img.size[1] - 1)), TEAL)
                self.assertTrue(self._has_gold(img), name)

    def _has_gold(self, img):
        w, h = img.size
        # The wordmark rule is a solid gold rectangle. Sample the columns where the lockup and the list sit.
        for frac in (0.32, 0.50, 0.56, 0.70):
            x = min(w - 1, max(0, int(w * frac)))
            for y in range(0, h, 2):
                if img.getpixel((x, y)) == GOLD:
                    return True
        return False


class LibraryPlanTests(unittest.TestCase):
    def test_screenshot_groups_follow_the_display_class(self):
        attrs = _catalog()
        self.assertEqual(library.screenshot_group(attrs, SLOTS["iphone-6.9"]), "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE")
        self.assertEqual(library.screenshot_group(attrs, SLOTS["iphone-6.5"]), "IPHONE_FACE_ID_LARGE_PROFILE")
        self.assertEqual(library.screenshot_group(attrs, SLOTS["ipad-13"]), "IPAD_13_PROFILE")
        self.assertEqual(library.screenshot_group(attrs, SLOTS["mac"]), "MAC_PROFILE")
        self.assertEqual(library.screenshot_group(attrs, SLOTS["appletv"]), "TV_PROFILE")
        self.assertEqual(library.screenshot_group(attrs, SLOTS["vision"]), "VISION_PROFILE")

    def test_header_and_universal_search_resolve(self):
        attrs = _catalog()
        self.assertEqual(
            library.creative_group(attrs, (3840, 1646), "PRODUCT_PAGE_HEADER_ASSET"), "CREATIVE_IOS")
        self.assertEqual(
            library.creative_group(attrs, (5244, 2950), "APP_STORE_SEARCH_RESULTS_ASSET"), "CREATIVE_IOS")
        self.assertIsNone(library.creative_group(attrs, (100, 100), "PRODUCT_PAGE_HEADER_ASSET"))

    def test_search_gap_when_only_the_header_size_exists(self):
        attrs = _catalog()
        attrs["imageSpecs"] = [s for s in attrs["imageSpecs"] if s["specId"] != "universal"]
        attrs["placementTypes"][2]["specMappings"] = []
        self.assertIsNone(library.creative_group(attrs, (5244, 2950), "APP_STORE_SEARCH_RESULTS_ASSET"))
        self.assertEqual(library.creative_group(attrs, (3840, 1646), "PRODUCT_PAGE_HEADER_ASSET"), "CREATIVE_IOS")

    def test_ref_payload_shapes(self):
        self.assertEqual(library.ref_attributes({"data": [{"attributes": {"imageSpecs": []}}]}), {"imageSpecs": []})
        self.assertEqual(library.library_id({"data": {"id": "lib", "type": "appAssetLibraries"}}), "lib")


if __name__ == "__main__":
    unittest.main()
