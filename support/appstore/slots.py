"""Display sizes for Nordic Crypto's App Store media.

Screenshot pixels are the largest size Apple accepts for that display class
(screenshot specifications, October 2026). Creative-asset pixels are the two
sizes the product-page Header and Search Results tab asks for: the 21:9 header
and the 16:9 universal image.
"""

# device folder -> where it is placed, and the exact PNG size we upload.
SLOTS = {
    "iphone-6.9": {
        "platform": "IPHONE_APP_STORE",
        "display": "IPHONE_DYNAMIC_ISLAND_LARGE_DISPLAY",
        "asc": "IOS",
        "size": (1320, 2868),
        "screens": ("today", "story", "events", "countries", "newsletter"),
    },
    "iphone-6.5": {
        "platform": "IPHONE_APP_STORE",
        "display": "IPHONE_FACE_ID_LARGE_DISPLAY",
        "asc": "IOS",
        "size": (1284, 2778),
        "screens": ("today", "story", "events", "countries", "newsletter"),
    },
    "ipad-13": {
        "platform": "IPAD_APP_STORE",
        "display": "IPAD_13_DISPLAY",
        "asc": "IOS",
        "size": (2064, 2752),
        "screens": ("today", "story", "events", "countries", "newsletter"),
    },
    "mac": {
        "platform": "MAC_APP_STORE",
        "display": "DEFAULT",
        "asc": "MAC_OS",
        "size": (2880, 1800),
        "screens": ("today", "story", "events", "countries", "newsletter"),
    },
    "appletv": {
        "platform": "TV_APP_STORE",
        "display": "DEFAULT",
        "asc": "TV_OS",
        "size": (1920, 1080),
        "screens": ("dashboard",),
    },
    "vision": {
        "platform": "VISION_PRO_APP_STORE",
        "display": "DEFAULT",
        "asc": "VISION_OS",
        "size": (3840, 2160),
        "screens": ("today", "story", "events"),
    },
}

# Generated even when no simulator ran. Placed through the Asset Library.
HEADERS = {
    "product-page-header-3840x1646.png": {
        "size": (3840, 1646),
        "placement": "PRODUCT_PAGE_HEADER_ASSET",
    },
    "universal-5244x2950.png": {
        "size": (5244, 2950),
        "placement": "APP_STORE_SEARCH_RESULTS_ASSET",
    },
}

CAPTIONS = {
    "today": "The Nordic front page",
    "story": "Every story, explained",
    "events": "What's on in the Nordics",
    "countries": "One view per country",
    "newsletter": "The weekly issue",
    "dashboard": "The information screen",
}
