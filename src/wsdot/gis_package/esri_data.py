from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
import pandas as pd
import geopandas as gpd
from shapely.geometry import shape
from shapely.geometry import MultiLineString, LineString, Point, Polygon

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
    """Download features from an ArcGIS FeatureServer layer with pagination, supporting M-values via Esri JSON."""
    features, offset, spatial_reference = [], 0, None
    coords = _extract_bbox_coords(bbox)
    
    query_url = url if url.endswith('/query') else f"{url.rstrip('/')}/query"

    while True:
        params = {
            'where': where,
            'outFields': '*',
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
        return gpd.GeoDataFrame(columns=['geometry'])

    # PARSING ESRI JSON GEOMETRY:
    records = []
    for f in features:
        geom_dict = f.get("geometry")
        shapely_geom = None
        
        if geom_dict:
            if "paths" in geom_dict:
                all_paths = geom_dict["paths"]
                if len(all_paths) == 1:
                    shapely_geom = LineString(all_paths[0])
                else:
                    shapely_geom = MultiLineString(all_paths)
            elif "rings" in geom_dict:
                shapely_geom = Polygon(geom_dict["rings"][0])
            elif "x" in geom_dict and "y" in geom_dict:
                # ADDED: Handles point features like mileposts (x, y coordinates)
                shapely_geom = Point(geom_dict["x"], geom_dict["y"])
                
        attributes = f.get("attributes", {})
        attributes["geometry"] = shapely_geom
        records.append(attributes)

    gdf = gpd.GeoDataFrame(records, geometry="geometry", crs=spatial_reference)
    
    if not source_name:
        url_segments = [seg for seg in url.split('/') if seg]
        gdf['source'] = url_segments[-2] if len(url_segments) >= 2 else url_segments[-1]
    else:
        gdf['source'] = source_name

    return gdf

def download_feature_layer_parallel(url, bbox=None, *, grid_size=4, max_workers=4, chunk_size=1000, where="1=1", source_name=None):
    """Splits a target bounding box into a grid and downloads features using parallel threads."""
    in_sr, base_url = None, url.split('/query')[0].rstrip('/')
    
    if bbox is None:
        try:
            r = requests.get(f"{base_url}?f=json", timeout=15)
            r.raise_for_status()
            extent = r.json().get('extent', {})
            if 'xmin' in extent:
                bbox = [extent['xmin'], extent['ymin'], extent['xmax'], extent['ymax']]
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
    all_gdfs = []
    
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
                gdf_chunk = future.result()
                if not gdf_chunk.empty and 'geometry' in gdf_chunk.columns:
                    all_gdfs.append(gdf_chunk)
                else:
                    print(f"[{idx}/{len(grid_boxes)}] Empty grid zone.")
            except Exception as exc:
                print(f"Grid box execution error: {exc}")

    if not all_gdfs:
        return gpd.GeoDataFrame(columns=['geometry'])

    combined_gdf = gpd.GeoDataFrame(pd.concat(all_gdfs, ignore_index=True), geometry='geometry')
    
    id_col = next((c for c in combined_gdf.columns if c.upper() in ['OBJECTID', 'FID', 'ID']), None)
    if id_col:
        combined_gdf = combined_gdf.drop_duplicates(subset=[id_col])
        
    print(f"Download complete. Total unique records extracted: {len(combined_gdf)}")
    return combined_gdf

def combine_layers(urls, source_names=None, **kwargs):
    """Download multiple FeatureServer layers and combine them into a single GeoDataFrame."""
    if source_names and len(source_names) != len(urls):
        raise ValueError('If provided, source_names must match the number of URLs.')

    # Optimizing Touch: Safe fallback generation if source_names is not passed
    names = source_names if source_names else [None] * len(urls)
    all_gdfs = []

    # Optimizing Touch: Zip pairing eliminates index management checks
    for url, name in zip(urls, names):
        # FIXED: **kwargs cleanly unpacks parameters down to download_feature_layer
        gdf = download_feature_layer(url, source_name=name, **kwargs)
        if not gdf.empty:
            all_gdfs.append(gdf)

    if all_gdfs:
        combined_gdf = gpd.GeoDataFrame(pd.concat(all_gdfs, ignore_index=True), geometry='geometry')
        print(f'Combined total features: {len(combined_gdf)} from {len(urls)} distinct layers.')
        return combined_gdf
    
    print("No valid features to combine.")
    return gpd.GeoDataFrame(columns=['geometry'])

from shapely.geometry import shape

def parse_arcgis_to_geodataframe(features):
    """
    Parses raw ArcGIS GeoJSON features into a GeoPandas GeoDataFrame,
    automatically handling Points, LineStrings, and Polygons.
    """
    import geopandas as gpd
    
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
            except Exception as e:
                # Skip malformed geometries gracefully
                continue
                
    # Create the GeoDataFrame with the correct geometry column
    gdf = gpd.GeoDataFrame(records, geometry=geometries, crs="EPSG:4326")
    return gdf
