import argparse
import os
from urllib.parse import quote_plus

from dotenv import load_dotenv
import pandas as pd
from shapely.geometry import LineString, MultiLineString, Point, Polygon
import sqlalchemy

from .config import WSDOT_ENTERPRISE_LAYERS, WSDOT_TPS_BACKBONE_LAYERS
from .gis_package import download_feature_layer_parallel

load_dotenv()


def _create_db_engine() -> sqlalchemy.Engine:
    if database_url := os.getenv("DATABASE_URL"):
        return sqlalchemy.create_engine(database_url, pool_pre_ping=True)

    user = os.getenv("DB_USERNAME") or os.getenv("PGUSER") or "postgres"
    password = os.getenv("DB_PASSWORD") or os.getenv("PGPASSWORD") or ""
    host = os.getenv("DB_HOST") or os.getenv("PGHOST") or "localhost"
    port = os.getenv("DB_PORT") or os.getenv("PGPORT") or "5432"
    dbname = os.getenv("DB_NAME") or os.getenv("PGDATABASE") or "wsdot"

    encoded_user = quote_plus(user)
    auth = f"{encoded_user}:{quote_plus(password)}" if password else encoded_user
    url = f"postgresql+psycopg://{auth}@{host}:{port}/{dbname}"
    return sqlalchemy.create_engine(url, pool_pre_ping=True)


def parse_wkt_safely(g):
    """Safely converts Shapely objects, WKT strings, or Esri JSON dicts (with M-values) into WKT text."""
    if g is None or (isinstance(g, float) and pd.isna(g)):
        return None
    try:
        # 1. If it's already a Shapely object
        if hasattr(g, "wkt"):
            return g.wkt
        # 2. If it's already a WKT string
        if isinstance(g, str):
            stripped = g.strip()
            if not stripped or stripped.lower() in {"nan", "none", "null"}:
                return None
            return stripped
        # 3. If it's an Esri JSON geometry dictionary from the ArcGIS REST API
        if isinstance(g, dict):
            if "paths" in g and g["paths"]:
                paths = g["paths"]
                lines = [LineString(p) for p in paths]
                geom = lines[0] if len(lines) == 1 else MultiLineString(lines)
                return geom.wkt
            if "rings" in g and g["rings"]:
                rings = g["rings"]
                geom = Polygon(rings[0], rings[1:]) if len(rings) > 1 else Polygon(rings[0])
                return geom.wkt
            if "x" in g and "y" in g and g["x"] is not None and g["y"] is not None:
                coords = (g["x"], g["y"], g.get("m")) if g.get("m") is not None else (g["x"], g["y"])
                geom = Point(coords)
                return geom.wkt
    except Exception as e:
        print(f"Geometry parse warning: {e}")
        return None
    return None


def _sanitize_ident(name: str) -> str:
    return "".join(ch if (ch.isalnum() or ch == "_") else "_" for ch in name.lower())


def run_etl(engine: sqlalchemy.Engine, mode: str = "backbone") -> None:
    """
    ETL - Rest API, Python request call, load into PostGIS.
    Backbone: lightweight essential tables, Enterprise: full WSDOT suite.
    """
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
            df_to_load.columns = [_sanitize_ident(col) for col in df_to_load.columns]

            db_table = _sanitize_ident(layer_name)
            print(f"Loading {layer_name} into PostGIS schema 'staging.{db_table}'...")

            if "geometry" in df_to_load.columns and not df_to_load["geometry"].isna().all():
                df_to_load["geometry"] = df_to_load["geometry"].apply(parse_wkt_safely)
                df_to_load["geometry"] = df_to_load["geometry"].where(df_to_load["geometry"].notna(), None)
                has_spatial = not df_to_load["geometry"].isna().all()
            else:
                has_spatial = False

            if not has_spatial:
                print(f"WARNING: No valid geometry found for {layer_name}. Treating as pure tabular.")

            try:
                # Replace drops and recreates staging.<db_table> cleanly in chunks
                df_to_load.to_sql(
                    name=db_table,
                    con=engine,
                    schema="staging",
                    if_exists="replace",
                    index=False,
                    chunksize=500,
                )

                if has_spatial:
                    print("Batch insert complete. Converting WKT text to native PostGIS geometries (preserving M-values)...")
                    with engine.begin() as conn:
                        conn.exec_driver_sql(
                            f"""
                            ALTER TABLE staging.{db_table}
                            ALTER COLUMN geometry TYPE geometry
                            USING ST_GeomFromText(geometry);
                            """
                        )
                        conn.exec_driver_sql(
                            f"""
                            CREATE INDEX IF NOT EXISTS idx_{db_table}_geom
                            ON staging.{db_table} USING GIST (geometry);
                            """
                        )
                    print(f"Successfully loaded, measured, and indexed spatial layer: staging.{db_table}")
                else:
                    print(f"Successfully loaded tabular layer: staging.{db_table}")

            except Exception as e:
                print(f"FAILED during safe load for staging.{db_table}: {e}")
                raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load WSDOT data for Linear Referencing")
    parser.add_argument(
        "--mode",
        type=str,
        default="backbone",
        choices=["backbone", "enterprise"],
        help="Execution mode: 'backbone' for core assets, 'enterprise' for full statewide ingestion.",
    )
    args = parser.parse_args()

    cli_engine = _create_db_engine()
    run_etl(cli_engine, mode=args.mode)