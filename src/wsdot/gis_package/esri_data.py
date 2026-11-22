from concurrent.futures import ThreadPoolExecutor, as_completed
import pandas as pd
import requests


def safe_float(val, default=0.0):
    """Safely convert a value to float, returning a default if None or empty."""
    if val is None or val == "":
        return default
    try:
        return float(val)
    except (ValueError, TypeError):
        return default


def _extract_bbox_coords(bbox):
    """Cleanly extracts a [xmin, ymin, xmax, ymax] list from any input format."""
    if bbox is None:
        return None
    if hasattr(bbox, "total_bounds"):
        return list(bbox.total_bounds)
    if hasattr(bbox, "bounds"):
        return list(bbox.bounds)
    if isinstance(bbox, (list, tuple)) and len(bbox) == 4:
        return list(bbox)
    raise ValueError("bbox must be a tuple, list, shapely geometry, or GeoDataFrame/GeoSeries.")


def _format_path_coords(paths, *, has_z=False, has_m=False):
    """Formats Esri JSON path arrays into WKT coordinate text with consistent Z/M dimensions."""
    path_strs = []

    # Detect if any point in the paths actually carries extra coordinates
    detected_z = has_z
    detected_m = has_m
    if not (detected_z or detected_m):
        for path in paths:
            for pt in path:
                if len(pt) >= 4 and pt[3] is not None:
                    detected_z = True
                    detected_m = True
                elif len(pt) >= 3 and pt[2] is not None:
                    detected_m = True

    for path in paths:
        pt_strs = []
        for pt in path:
            x, y = pt[0], pt[1]
            if detected_z and detected_m:
                z = pt[2] if len(pt) >= 3 and pt[2] is not None else 0
                m = pt[3] if len(pt) >= 4 and pt[3] is not None else 0
                pt_strs.append(f"{x} {y} {z} {m}")
            elif detected_m:
                m = pt[2] if len(pt) >= 3 and pt[2] is not None else 0
                pt_strs.append(f"{x} {y} {m}")
            elif detected_z:
                z = pt[2] if len(pt) >= 3 and pt[2] is not None else 0
                pt_strs.append(f"{x} {y} {z}")
            else:
                pt_strs.append(f"{x} {y}")
        path_strs.append(f"({', '.join(pt_strs)})")

    return path_strs, detected_z, detected_m


def download_feature_layer(
    url,
    bbox=None,
    in_sr=None,
    *,
    chunk_size=1000,
    where="1=1",
    source_name=None,
):
    """Download features from an ArcGIS FeatureServer layer, preserving M-values as WKT text strings."""
    features, offset = [], 0
    coords = _extract_bbox_coords(bbox)

    query_url = url if url.endswith("/query") else f"{url.rstrip('/')}/query"

    while True:
        params = {
            "where": where,
            "outFields": "*",
            "returnGeometry": "true",
            "f": "json",
            "returnM": "true",
            "resultOffset": offset,
            "resultRecordCount": chunk_size,
        }

        if coords:
            params.update({
                "geometry": ",".join(map(str, coords)),
                "geometryType": "esriGeometryEnvelope",
                "spatialRel": "esriSpatialRelIntersects",
            })
            if in_sr:
                params["inSR"] = str(in_sr)

        try:
            r = requests.get(query_url, params=params, timeout=30)
            r.raise_for_status()
            data = r.json()
        except Exception as e:
            raise RuntimeError(f"Error fetching data at offset {offset} from {query_url}: {e}") from e

        if "error" in data:
            raise RuntimeError(f"ArcGIS REST error at offset {offset} from {query_url}: {data['error']}")

        feats = data.get("features", [])
        if not feats:
            break
        features.extend(feats)

        if len(feats) < chunk_size and not data.get("exceededTransferLimit"):
            break
        offset += chunk_size

    if not features:
        return pd.DataFrame(columns=["geometry"])

    records = []

    for f in features:
        geom_dict = f.get("geometry")
        wkt_str = None

        if geom_dict:
            try:
                if "paths" in geom_dict and geom_dict["paths"]:
                    path_strs, has_z, has_m = _format_path_coords(geom_dict["paths"])
                    if len(path_strs) == 1:
                        if has_z and has_m:
                            wkt_tag = "LINESTRING ZM"
                        elif has_m:
                            wkt_tag = "LINESTRING M"
                        elif has_z:
                            wkt_tag = "LINESTRING Z"
                        else:
                            wkt_tag = "LINESTRING"
                        wkt_str = f"{wkt_tag} {path_strs[0]}"
                    else:
                        if has_z and has_m:
                            wkt_tag = "MULTILINESTRING ZM"
                        elif has_m:
                            wkt_tag = "MULTILINESTRING M"
                        elif has_z:
                            wkt_tag = "MULTILINESTRING Z"
                        else:
                            wkt_tag = "MULTILINESTRING"
                        wkt_str = f"{wkt_tag} ({', '.join(path_strs)})"

                elif "rings" in geom_dict and geom_dict["rings"]:
                    parts = []
                    for ring in geom_dict["rings"]:
                        pt_strs = [f"{pt[0]} {pt[1]}" for pt in ring]
                        parts.append(f"({', '.join(pt_strs)})")
                    wkt_str = f"POLYGON ({', '.join(parts)})"

                elif "x" in geom_dict and "y" in geom_dict:
                    x, y = geom_dict["x"], geom_dict["y"]
                    if x is not None and y is not None:
                        m = geom_dict.get("m")
                        if m is not None:
                            wkt_str = f"POINT M ({x} {y} {m})"
                        else:
                            wkt_str = f"POINT ({x} {y})"
            except Exception:
                wkt_str = None

        attributes = dict(f.get("attributes") or {})
        attributes["geometry"] = wkt_str
        records.append(attributes)

    df = pd.DataFrame(records)
    if "geometry" not in df.columns:
        df["geometry"] = None
    else:
        df["geometry"] = df["geometry"].where(df["geometry"].notna(), None)

    if not source_name:
        url_segments = [seg for seg in url.split("/") if seg]
        derived_source = url_segments[-2] if len(url_segments) >= 2 else url_segments[-1]
    else:
        derived_source = source_name

    existing_source_col = next((c for c in df.columns if c.lower() == "source"), None)
    if existing_source_col:
        df = df.rename(columns={existing_source_col: "layer_source"})

    df["source"] = derived_source
    return df


def download_feature_layer_parallel(
    url,
    bbox=None,
    *,
    grid_size=4,
    max_workers=4,
    chunk_size=1000,
    where="1=1",
    source_name=None,
):
    """Splits a target bounding box into a grid and downloads features using parallel threads, returning a standard DataFrame."""
    in_sr, base_url = None, url.split("/query")[0].rstrip("/")

    if bbox is None:
        try:
            r = requests.get(f"{base_url}?f=json", timeout=15)
            r.raise_for_status()
            extent = r.json().get("extent", {})

            required_keys = ["xmin", "ymin", "xmax", "ymax"]
            if all(extent.get(k) is not None for k in required_keys):
                bbox = [
                    float(extent["xmin"]),
                    float(extent["ymin"]),
                    float(extent["xmax"]),
                    float(extent["ymax"]),
                ]
                in_sr = extent.get("spatialReference", {}).get("wkid")
                print(f"Fetched full layer extent: {bbox} (SRID: {in_sr})")
            else:
                raise ValueError("Could not find 'extent' metadata on the server.")
        except Exception as e:
            raise RuntimeError(f"Failed to automatically retrieve layer extent: {e}") from e

    xmin, ymin, xmax, ymax = _extract_bbox_coords(bbox)
    x_step, y_step = (xmax - xmin) / grid_size, (ymax - ymin) / grid_size

    grid_boxes = [
        [
            xmin + (i * x_step),
            ymin + (j * y_step),
            xmin + ((i + 1) * x_step),
            ymin + ((j + 1) * y_step),
        ]
        for i in range(grid_size)
        for j in range(grid_size)
    ]

    print(f"Starting parallel download with {max_workers} threads across {len(grid_boxes)} grid cells...")
    all_dfs = []

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_bbox = {
            executor.submit(
                download_feature_layer,
                url,
                bbox=box,
                in_sr=in_sr,
                chunk_size=chunk_size,
                where=where,
                source_name=source_name,
            ): box
            for box in grid_boxes
        }

        for idx, future in enumerate(as_completed(future_to_bbox), 1):
            try:
                df_chunk = future.result()
                if not df_chunk.empty and "geometry" in df_chunk.columns:
                    all_dfs.append(df_chunk)
                else:
                    print(f"[{idx}/{len(grid_boxes)}] Empty grid zone.")
            except Exception as exc:
                raise RuntimeError(f"Grid box execution error: {exc}") from exc

    if not all_dfs:
        return pd.DataFrame(columns=["geometry"])

    combined_df = pd.concat(all_dfs, ignore_index=True)

    id_col = next((c for c in combined_df.columns if c.upper() in ["OBJECTID", "FID", "ID"]), None)
    if id_col:
        combined_df = combined_df.drop_duplicates(subset=[id_col])
    else:
        dedup_cols = [c for c in combined_df.columns if c != "geometry"]
        if dedup_cols:
            combined_df = combined_df.drop_duplicates(subset=dedup_cols)

    print(f"Download complete. Total unique records extracted: {len(combined_df)}")
    return combined_df