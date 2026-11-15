import os
import argparse
import sqlalchemy
from dotenv import load_dotenv
import geopandas as gpd
import pandas as pd
from shapely.geometry import shape
from .gis_package import download_feature_layer_parallel
from shapely.geometry import LineString, MultiLineString, Point, Polygon

# Dictionaries
from .config import WSDOT_TPS_BACKBONE_LAYERS, WSDOT_ENTERPRISE_LAYERS

load_dotenv()

DB_USER = os.getenv('DB_USERNAME')
DB_PASS = os.getenv('DB_PASSWORD')
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')

if DB_HOST:
    connection_string = f'postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}'
else:
    connection_string = f'postgresql://{DB_USER}:{DB_PASS}@/{DB_NAME}'

engine = sqlalchemy.create_engine(connection_string)

def parse_wkt_safely(g):
    """Safely converts Shapely objects, WKT strings, or Esri JSON dicts (with M-values) into WKT text."""
    if g is None:
        return None
    try:
        # 1. If it's already a Shapely object
        if hasattr(g, 'wkt'):
            return g.wkt
        # 2. If it's already a WKT string
        if isinstance(g, str):
            return g
        # 3. If it's an Esri JSON geometry dictionary from the ArcGIS REST API
        if isinstance(g, dict):
            if 'paths' in g:
                # LineString or MultiLineString (retains M-values if present in coordinate arrays)
                paths = g['paths']
                lines = [LineString(p) for p in paths]
                geom = lines[0] if len(lines) == 1 else MultiLineString(lines)
                return geom.wkt
            elif 'rings' in g:
                # Polygon
                rings = g['rings']
                geom = Polygon(rings[0], rings[1:]) if len(rings) > 1 else Polygon(rings[0])
                return geom.wkt
            elif 'x' in g and 'y' in g:
                # Point
                coords = (g['x'], g['y'], g.get('m')) if 'm' in g else (g['x'], g['y'])
                geom = Point(coords)
                return geom.wkt
    except Exception as e:
        print(f"Geometry parse warning: {e}")
        return None
    return None

def run_etl(engine, mode="backbone"):
    """
    ETL - Rest API, Python request call, load into Postgis,
    Backbone: lightweight essential tables, Enterprise: Full WSDOT suite
    """
    # Select dictionary based on mode
    if mode == "backbone":
        target_dict = WSDOT_TPS_BACKBONE_LAYERS
        print(">>> Running ETL in BACKBONE mode (Core LRS, CRAB, Bridges, Characteristics)")
    elif mode == "enterprise":
        target_dict = WSDOT_ENTERPRISE_LAYERS
        print(">>> Running ETL in ENTERPRISE mode (Full State Ecosystem)")
    else:
        raise ValueError(f"Unknown mode: {mode}. Use 'backbone' or 'enterprise'.")

    for category, layers in target_dict.items():
        print(f"\n--- Processing Category: {category} ---")
        for layer_name, url in layers.items():
            print(f"Extracting {layer_name}...")
            
            # 1. Download features via parallel grid extraction (returns a pandas DataFrame with WKT geometry strings)
            raw_data = download_feature_layer_parallel(url, grid_size=4, max_workers=4)
            df_to_load = raw_data.copy()

            print(f"Loading {layer_name} into PostGIS schema 'staging'...")
            db_table = layer_name.lower()

            with engine.begin() as conn:
                # 2. Wipe out the old table
                conn.execute(sqlalchemy.text(f"DROP TABLE IF EXISTS staging.{db_table} CASCADE;"))

            # 3. Check if geometry column exists and has data
            if 'geometry' in df_to_load.columns and not df_to_load['geometry'].isna().all():
                print("Detected geometry WKT column. Streaming via chunked SQL...")
                has_spatial = True
            else:
                print(f"WARNING: No valid geometry found for {layer_name}. Treating as pure tabular.")
                has_spatial = False

            try:
                # 4. Stream rows using standard pandas insert
                # Normaliz columns
                df_to_load.columns = [col.lower() for col in df_to_load.columns]

                df_to_load.to_sql(
                    name=db_table,
                    con=engine,
                    schema="staging",
                    if_exists="replace",
                    index=False,
                    chunksize=500
                )

                # 5. Post-process spatial casting to native PostGIS measured geometries
                if has_spatial:
                    print("Batch insert complete. Converting WKT text to native PostGIS geometries (preserving M-values)...")
                    with engine.begin() as conn:
                        conn.execute(sqlalchemy.text(f"""
                            ALTER TABLE staging.{db_table} 
                            ALTER COLUMN geometry TYPE geometry 
                            USING ST_GeomFromText(geometry);
                        """))
                        
                        conn.execute(sqlalchemy.text(
                            f"CREATE INDEX IF NOT EXISTS idx_{db_table}_geom ON staging.{db_table} USING GIST (geometry);"
                        ))
                    print(f"Successfully loaded, measured, and indexed spatial layer: staging.{db_table}")
                else:
                    print(f"Successfully loaded tabular layer: staging.{db_table}")

            except Exception as e:
                print(f"FAILED during safe load: {e}")
                raise
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load WSDOT data for Linear Referencing")
    parser.add_argument(
        "--mode", 
        type=str, 
        default="backbone", 
        choices=["backbone", "enterprise"],
        help="Execution mode: 'backbone' for core assets, 'enterprise' for full statewide ingestion."
    )
    args = parser.parse_args()
    
    run_etl(engine, mode=args.mode)