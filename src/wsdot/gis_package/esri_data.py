from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
import pandas as pd
import geopandas as gpd

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
    if hasattr(bbox, 'total_bounds'):
        return list(bbox.total_bounds)
    if hasattr(bbox, "bounds"):
        return list(bbox.bounds)
    if isinstance(bbox, (list, tuple)) and len(bbox) == 4:
        return list(bbox)
    raise ValueError("bbox must be a tuple, list, shapely geometry, or GeoDataFrame/GeoSeries.")

def download_feature_layer(url, bbox=None, in_sr=None, *, chunk_size=1000, where="1=1", source_name=None):
    """Download features from an ArcGIS FeatureServer layer, preserving M-values as WKT text strings."""
    features, offset, spatial_reference = [], 0, None
    coords = _extract_bbox_coords(bbox)
    
    query_url = url if url.endswith('/query') else f"{url.rstrip('/')}/query"

    while True:
        params = {
            'where': where,
            'outFields': '*',
            'returnGeometry': 'true',
            'f': 'json',
            'returnM': 'true', 
            'resultOffset': offset,
            'resultRecordCount': chunk_size
        }
        
        if coords:
            params.update({
                "geometry": ",".join(map(str, coords)),
                "geometryType": "esriGeometryEnvelope",
                "spatialRel": "esriSpatialRelIntersects"
            })
            if in_sr:
                params['inSR'] = str(in_sr)
            
        try:
            r = requests.get(query_url, params=params, timeout=30)
            r.raise_for_status()
            data = r.json()
        except Exception as e:
            print(f"Error fetching data at offset {offset}: {e}")
            break
        
        if not spatial_reference:
            spatial_reference = data.get("spatialReference", {}).get("wkid", 4326)

        feats = data.get('features', [])
        if not feats:
            break
        features.extend(feats)
        
        if len(feats) < chunk_size:
            break
        offset += chunk_size

    if not features:
        return pd.DataFrame(columns=['geometry'])

    records = []
    
    for f in features:
        geom_dict = f.get("geometry")
        wkt_str = None
        
        if geom_dict:
            try:
                if "paths" in geom_dict:
                    has_m = False
                    all_paths_strs = []
                    for path in geom_dict["paths"]:
                        pt_strs = []
                        for pt in path:
                            if len(pt) >= 3 and pt[2] is not None:
                                has_m = True
                                if len(pt) >= 4 and pt[3] is not None:
                                    pt_strs.append(f"{pt[0]} {pt[1]} {pt[2]} {pt[3]}")
                                else:
                                    pt_strs.append(f"{pt[0]} {pt[1]} {pt[2]}")
                            else:
                                pt_strs.append(f"{pt[0]} {pt[1]}")
                        all_paths_strs.append(f"({', '.join(pt_strs)})")
                    
                    # Correctly format single vs multi-part linestrings without illegal double parentheses
                    if len(all_paths_strs) == 1:
                        wkt_tag = "LINESTRING M" if has_m else "LINESTRING"
                        wkt_str = f"{wkt_tag} {all_paths_strs[0]}"
                    else:
                        wkt_tag = "MULTILINESTRING M" if has_m else "MULTILINESTRING"
                        wkt_str = f"{wkt_tag} ({', '.join(all_paths_strs)})"
                    
                elif "rings" in geom_dict:
                    parts = []
                    for ring in geom_dict["rings"]:
                        pt_strs = [f"{pt[0]} {pt[1]}" for pt in ring]
                        parts.append(f"({', '.join(pt_strs)})")
                    wkt_str = f"POLYGON ({', '.join(parts)})"
                    
                elif "x" in geom_dict and "y" in geom_dict:
                    x, y = geom_dict["x"], geom_dict["y"]
                    m = geom_dict.get("m")
                    if m is not None:
                        wkt_str = f"POINT M ({x} {y} {m})"
                    else:
                        wkt_str = f"POINT ({x} {y})"
            except Exception:
                wkt_str = None
                
        attributes = f.get("attributes", {})
        attributes["geometry"] = wkt_str
        records.append(attributes)
   
    df = pd.DataFrame(records)
    if 'geometry' not in df.columns:
        df['geometry'] = None

    if not source_name:
        url_segments = [seg for seg in url.split('/') if seg]
        derived_source = url_segments[-2] if len(url_segments) >= 2 else url_segments[-1]
    else:
        derived_source = source_name

    # Check if 'source' (case-insensitive) already exists in the ArcGIS data attributes
    existing_source_col = next((c for c in df.columns if c.lower() == 'source'), None)
    
    if existing_source_col:
        # If the layer already has a source column, rename it to avoid collision
        df = df.rename(columns={existing_source_col: 'layer_source'})
    
    df['source'] = derived_source

    return df

def download_feature_layer_parallel(url, bbox=None, *, grid_size=4, max_workers=4, chunk_size=1000, where="1=1", source_name=None):
    """Splits a target bounding box into a grid and downloads features using parallel threads, returning a standard DataFrame."""
    in_sr, base_url = None, url.split('/query')[0].rstrip('/')
    
    if bbox is None:
        try:
            r = requests.get(f"{base_url}?f=json", timeout=15)
            r.raise_for_status()
            extent = r.json().get('extent', {})

            required_keys = ['xmin', 'ymin', 'xmax', 'ymax']
            if all(extent.get(k) is not None for k in required_keys):
                bbox = [
                    float(extent['xmin']), 
                    float(extent['ymin']), 
                    float(extent['xmax']), 
                    float(extent['ymax'])
                ]
                in_sr = extent.get('spatialReference', {}).get('wkid')
                print(f"Fetched full layer extent: {bbox} (SRID: {in_sr})")
            else:
                raise ValueError("Could not find 'extent' metadata on the server.")
        except Exception as e:
            raise RuntimeError(f"Failed to automatically retrieve layer extent: {e}")

    xmin, ymin, xmax, ymax = _extract_bbox_coords(bbox)
    x_step, y_step = (xmax - xmin) / grid_size, (ymax - ymin) / grid_size
    
    grid_boxes = [
        [xmin + (i * x_step), ymin + (j * y_step), xmin + ((i + 1) * x_step), ymin + ((j + 1) * y_step)]
        for i in range(grid_size) for j in range(grid_size)
    ]

    print(f"Starting parallel download with {max_workers} threads across {len(grid_boxes)} grid cells...")
    all_dfs = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_bbox = {
            executor.submit(
                download_feature_layer, url, bbox=box, in_sr=in_sr, 
                chunk_size=chunk_size, where=where, source_name=source_name
            ): box 
            for box in grid_boxes
        }
        
        for idx, future in enumerate(as_completed(future_to_bbox), 1):
            try:
                df_chunk = future.result()
                if not df_chunk.empty and 'geometry' in df_chunk.columns:
                    all_dfs.append(df_chunk)
                else:
                    print(f"[{idx}/{len(grid_boxes)}] Empty grid zone.")
            except Exception as exc:
                print(f"Grid box execution error: {exc}")

    if not all_dfs:
        return pd.DataFrame(columns=['geometry'])

    combined_df = pd.concat(all_dfs, ignore_index=True)
    
    id_col = next((c for c in combined_df.columns if c.upper() in ['OBJECTID', 'FID', 'ID']), None)
    if id_col:
        combined_df = combined_df.drop_duplicates(subset=[id_col])
        
    print(f"Download complete. Total unique records extracted: {len(combined_df)}")
    return combined_df

def parse_arcgis_to_geodataframe(features):
    """
    Parses raw ArcGIS GeoJSON features into a GeoPandas GeoDataFrame,
    automatically handling Points, LineStrings, and Polygons.
    """
    records = []
    geometries = []
    
    for feat in features:
        geom_json = feat.get("geometry")
        properties = feat.get("attributes", feat.get("properties", {}))
        
        if geom_json:
            try:
                geom = shape(geom_json)
                if geom and not geom.is_empty:
                    geometries.append(geom)
                    records.append(properties)
            except Exception:
                continue
                
    return gpd.GeoDataFrame(records, geometry=geometries, crs="EPSG:4326")