import os
import argparse
import sqlalchemy
from dotenv import load_dotenv
import geopandas as gpd
from .gis_package import download_feature_layer_parallel

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
            
            #download features
            gdf = download_feature_layer_parallel(url, grid_size=4, max_workers=4)

            print(f"Loading {layer_name} into PostGIS schema 'staging'...")
                
            # Postgis db loading
            with engine.begin() as conn:
                gdf.to_postgis(
                    name=layer_name,
                    con=engine,
                    schema="staging",
                    if_exists='replace',
                    index=True
                )
                    
                # 3. Explicit spatial index optimization
                conn.execute(sqlalchemy.text(f"CREATE INDEX IF NOT EXISTS idx_{layer_name}_geom ON staging.{layer_name} USING GIST (geometry);"))
                
                print(f"Successfully loaded and indexed: staging.{layer_name}")
        else:
            print(f"Skipping {layer_name} (No features returned).")

if __name__ == "__main__":
    # Setup command-line argument parsing
    parser = argparse.ArgumentParser(description="Load WSDOT data for Linear Referencing")
    parser.add_argument(
        "--mode", 
        type=str, 
        default="backbone", 
        choices=["backbone", "enterprise"],
        help="Execution mode: 'backbone' for core assets, 'enterprise' for full statewide ingestion."
    )
    args = parser.parse_args()
    
    run_etl(mode=args.mode)
