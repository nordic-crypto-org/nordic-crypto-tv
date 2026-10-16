"""Place screenshots and creative assets through the App Store Connect Asset Library.

The library is the current API (the older appScreenshots resource is deprecated).
Reference data is read at runtime so a new display class does not need a code
change. This module never creates a review submission: placements on a version
that is still Prepare for Submission are reviewed when that version is submitted
by hand.
"""
import os

from slots import HEADERS, SLOTS

SCREENSHOT = "APP_SCREENSHOT"
HEADER = "PRODUCT_PAGE_HEADER_ASSET"
SEARCH = "APP_STORE_SEARCH_RESULTS_ASSET"
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}


def ref_attributes(payload):
    data = payload.get("data")
    if isinstance(data, list):
        if not data:
            raise SystemExit("App Store Connect returned no asset-library reference data.")
        data = data[0]
    if not isinstance(data, dict):
        raise SystemExit("Unexpected appAssetLibraryRefData response.")
    return data.get("attributes") or {}


def library_id(payload):
    data = payload.get("data")
    if isinstance(data, list):
        data = data[0] if data else None
    if not isinstance(data, dict) or not data.get("id"):
        raise SystemExit(
            "This app has no Asset Library yet. Open the app in App Store Connect once "
            "(the library is created there), then run the workflow again."
        )
    return data["id"]


def _specs(attrs):
    return [s for s in (attrs.get("imageSpecs") or []) if isinstance(s, dict)]


def spec_matches(spec, size):
    dim = spec.get("dimensions") or {}
    w, h = size
    return (dim.get("minWidth"), dim.get("maxWidth"), dim.get("minHeight"), dim.get("maxHeight")) == (w, w, h, h)


def mapping_specs(attrs, placement_type, group_id):
    for entry in attrs.get("placementTypes") or []:
        if entry.get("placementTypeId") != placement_type:
            continue
        for mapping in entry.get("specMappings") or []:
            if mapping.get("placementGroupId") == group_id:
                return list(mapping.get("specs") or [])
        return []
    return []


def screenshot_group(attrs, slot):
    """The placement group for this display, confirmed against the pixel size."""
    groups = [
        g for g in (attrs.get("placementProfileGroups") or [])
        if g.get("platform") == slot["platform"] and g.get("placementProfileGroupId")
    ]
    exact = [g for g in groups if g.get("displayClassId") == slot["display"]]
    if not exact and slot["display"] == "DEFAULT":
        exact = [g for g in groups if g.get("displayClassId") in (None, "DEFAULT")] or groups
    if not exact:
        known = sorted({g.get("displayClassId") for g in groups})
        raise SystemExit(
            f"No placement group for {slot['platform']} / {slot['display']}. "
            f"Groups on that platform use {known or 'none'}."
        )
    wanted = slot["size"]
    for group in exact:
        gid = group["placementProfileGroupId"]
        ids = mapping_specs(attrs, SCREENSHOT, gid)
        for spec in _specs(attrs):
            if spec.get("specId") in ids and spec_matches(spec, wanted):
                return gid
    accepted = []
    for group in exact:
        ids = set(mapping_specs(attrs, SCREENSHOT, group["placementProfileGroupId"]))
        for spec in _specs(attrs):
            if spec.get("specId") in ids:
                dim = spec.get("dimensions") or {}
                accepted.append(f"{dim.get('minWidth')}x{dim.get('minHeight')}")
    raise SystemExit(
        f"No {wanted[0]}x{wanted[1]} screenshot spec for {slot['platform']} / {slot['display']}. "
        f"Apple currently accepts: {', '.join(accepted) or 'nothing'}."
    )


def creative_group(attrs, size, placement_type):
    """A group that accepts this exact creative-asset size, or None when Apple has no such spec."""
    matching = [s for s in _specs(attrs) if spec_matches(s, size)]
    if not matching:
        return None
    usable = []
    for spec in matching:
        types = spec.get("compatiblePlacementTypes") or []
        if placement_type in types or (spec.get("universalAsset") and placement_type in (HEADER, SEARCH)):
            usable.append(spec)
    if not usable:
        return None
    spec_ids = {s.get("specId") for s in usable}
    candidates = []
    for entry in attrs.get("placementTypes") or []:
        if entry.get("placementTypeId") != placement_type:
            continue
        categories = entry.get("acceptsAssetCategories") or []
        if categories and "CREATIVE_ASSETS" not in categories:
            return None
        for mapping in entry.get("specMappings") or []:
            if spec_ids.intersection(mapping.get("specs") or []):
                candidates.append(mapping.get("placementGroupId"))
    if not candidates:
        return None
    groups = {g.get("placementProfileGroupId"): g for g in attrs.get("placementProfileGroups") or []}
    def rank(gid):
        platform = (groups.get(gid) or {}).get("platform") or ""
        return {"IPHONE_APP_STORE": 0, "ANY": 1, "IPAD_APP_STORE": 2}.get(platform, 3)
    return sorted(candidates, key=rank)[0]


def upload_image(asc, library, path, category, reference):
    data = open(path, "rb").read()
    res = asc.write("POST", "/appAssetLibraryImages", {"data": {
        "type": "appAssetLibraryImages",
        "attributes": {
            "fileName": os.path.basename(path),
            "fileSize": len(data),
            "category": category,
            "referenceName": reference,
        },
        "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library}}},
    }})
    image = res.get("data") or {}
    if asc.dry_run:
        return "dry-run"
    ops = (image.get("attributes") or {}).get("uploadOperations") or []
    asc.send_operations(ops, data)
    asc.write("PATCH", f"/appAssetLibraryImages/{image['id']}", {"data": {
        "type": "appAssetLibraryImages", "id": image["id"], "attributes": {"uploaded": True},
    }})
    return image["id"]


def clear_placements(asc, loc_id, placement_type, group_id):
    page = asc.get(
        f"/appStoreVersionLocalizations/{loc_id}/placements",
        **{"filter[placementType]": placement_type, "filter[placementGroup]": group_id, "limit": 50},
    )
    for item in page.get("data") or []:
        asc.remove(f"/appAssetLibraryPlacements/{item['id']}")


def place(asc, loc_id, image_id, placement_type, group_id):
    res = asc.write("POST", "/appAssetLibraryPlacements", {"data": {
        "type": "appAssetLibraryPlacements",
        "attributes": {"placementType": placement_type, "placementGroup": group_id},
        "relationships": {
            "image": {"data": {"type": "appAssetLibraryImages", "id": image_id}},
            "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}},
        },
    }})
    placed = (res.get("data") or {}).get("id")
    if not asc.dry_run and not placed:
        raise SystemExit(f"App Store Connect did not return a placement id for {placement_type}.")
    return placed


def order(asc, loc_id, group_id, placement_ids):
    if len(placement_ids) < 2 or any(i in (None, "dry-run") for i in placement_ids):
        return
    try:
        asc.write("POST", "/appAssetLibraryPlacementOrderingRequests", {"data": {
            "type": "appAssetLibraryPlacementOrderingRequests",
            "attributes": {"placementGroup": group_id},
            "relationships": {
                "orderedPlacements": {"data": [{"type": "appAssetLibraryPlacements", "id": i} for i in placement_ids]},
                "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}},
            },
        }})
    except Exception:
        note(f"Screenshot order for {group_id} was not accepted; the images are still uploaded.")


def files_for(screenshots_dir, device):
    folder = os.path.join(screenshots_dir, device, "en")
    if not os.path.isdir(folder):
        return []
    return sorted(os.path.join(folder, name) for name in os.listdir(folder) if name.lower().endswith(".png"))


def _place_creative(asc, attrs, library, locs, headers_dir, version_name, filename, placement, gaps):
    spec = HEADERS[filename]
    path = os.path.join(headers_dir, filename)
    if not os.path.exists(path):
        gaps.append(f"{filename} was not generated.")
        return False
    group = creative_group(attrs, spec["size"], placement)
    if group is None:
        gaps.append(
            f"{filename} ({spec['size'][0]}×{spec['size'][1]}) has no {placement} specification "
            "in the Asset Library reference data. The file is a workflow artifact; add it by hand "
            "under Header and Search Results."
        )
        return False
    image_id = upload_image(asc, library, path, "CREATIVE_ASSETS", f"nc-{version_name}-{filename}")
    for loc in locs:
        clear_placements(asc, loc["id"], placement, group)
        place(asc, loc["id"], image_id, placement, group)
    note(f"iOS {placement}: {filename} on {len(locs)} localizations ({group}). Not submitted for review.")
    return True


def note(message):
    print(message)
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as fh:
            fh.write(message + "\n")


def upload_media(asc, app_id, version_name, screenshots_dir, headers_dir):
    """Upload framed screenshots and the two creative assets. Never submits for review."""
    attrs = ref_attributes(asc.get("/appAssetLibraryRefData", **{
        "fields[appAssetLibraryRefData]": "imageSpecs,placementProfileGroups,placementTypes",
        "limit": 5,
    }))
    library = library_id(asc.get(f"/apps/{app_id}/assetLibrary"))
    versions = asc.get(f"/apps/{app_id}/appStoreVersions", **{"limit": 50})["data"]
    gaps = []
    by_platform = {}
    for version in versions:
        platform = version["attributes"]["platform"]
        state = version["attributes"]["appStoreState"]
        if version["attributes"]["versionString"] == version_name and state in EDITABLE:
            by_platform[platform] = version
        elif version["attributes"]["versionString"] == version_name:
            note(f"{platform} {version_name} is {state}; left untouched (not an editable version).")

    needed = sorted({slot["asc"] for slot in SLOTS.values()})
    missing = [p for p in needed if p not in by_platform]
    if missing:
        raise SystemExit(
            f"{version_name} is not editable on {', '.join(missing)}. "
            "The workflow only updates a version in Prepare for Submission "
            "(or rejected metadata). It does not create a version and it does not submit for review."
        )

    for platform, version in by_platform.items():
        devices = [name for name, slot in SLOTS.items() if slot["asc"] == platform]
        if not devices:
            continue
        locs = asc.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations", **{"limit": 200})["data"]
        if not locs:
            raise SystemExit(f"{platform} {version_name} has no localizations to attach screenshots to.")
        for device in devices:
            paths = files_for(screenshots_dir, device)
            if not paths:
                raise SystemExit(f"No framed screenshots for {device} in {screenshots_dir}.")
            group = screenshot_group(attrs, SLOTS[device])
            image_ids = []
            for path in paths[:10]:
                image_ids.append(upload_image(
                    asc, library, path, "APP_SCREENSHOTS_AND_PREVIEWS",
                    f"nc-{version_name}-{device}-{os.path.basename(path)}",
                ))
            for loc in locs:
                clear_placements(asc, loc["id"], SCREENSHOT, group)
                placed = [place(asc, loc["id"], image_id, SCREENSHOT, group) for image_id in image_ids]
                order(asc, loc["id"], group, placed)
            note(f"{platform} {device}: {len(paths[:10])} screenshots on {len(locs)} localizations ({group}).")

    ios = by_platform.get("IOS")
    if ios is None:
        gaps.append("No editable iOS version, so the header and search images were not placed.")
    else:
        locs = asc.get(f"/appStoreVersions/{ios['id']}/appStoreVersionLocalizations", **{"limit": 200})["data"]
        placed_header = _place_creative(
            asc, attrs, library, locs, headers_dir, version_name,
            "product-page-header-3840x1646.png", HEADER, gaps,
        )
        search_name = "universal-5244x2950.png"
        search_size = HEADERS[search_name]["size"]
        if creative_group(attrs, search_size, SEARCH):
            _place_creative(asc, attrs, library, locs, headers_dir, version_name, search_name, SEARCH, gaps)
        elif not placed_header and creative_group(attrs, search_size, HEADER):
            _place_creative(asc, attrs, library, locs, headers_dir, version_name, search_name, HEADER, gaps)
        else:
            gaps.append(
                "5244×2950 is Apple's universal creative (one PNG for the header and for search). "
                "The Asset Library reference data for this app does not accept that size as the "
                "search-results placement; search wants a 3:2 image from 1920×1280 up to 3840×2560. "
                "The file is kept as a workflow artifact. On the iOS 1.1.0 version, open "
                "Header and Search Results and choose “Use header asset in search results” if the "
                "same picture should appear in both places, or add a 3:2 search image by hand."
            )
            note("Kept universal-5244x2950.png as an artifact; see the manual step below.")

    if gaps:
        note("Manual step in App Store Connect:\n" + "\n".join(f"- {g}" for g in gaps))
    return gaps
