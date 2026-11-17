# src/wsdot/__init__.py
import os
import argparse
import sqlalchemy
from dotenv import load_dotenv

from .sql_file import run_sql_script
from .etl import run_etl

load_dotenv()

def main():
    parser = argparse.ArgumentParser(description="WSDOT ELT Pipeline and LRS")
    parser.add_argument(
        "--mode", 
        type=str, 
        default="backbone", 
        choices=["backbone", "enterprise"],
        help="ETL extraction mode: 'backbone' for core assets, 'enterprise' for full statewide ingestion."
    )
    parser.add_argument(
        "--skip-sql", 
        action="store_true", 
        help="Skip database bootstrapping scripts and run Python ETL only."
    )
    
    args = parser.parse_args()

    # Establish Database Connection
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

    print(">>> WSDOT Spatial Pipeline Initialized")

    # --- Database Infrastructure & Schemas ---
    if not args.skip_sql:
        print("\n=== Creating Database Extensions & Schemas ===")
        try:
            # 1. Enable PostGIS extensions
            run_sql_script(engine, "01_init.sql")
            
            # 2. Build schemas
            run_sql_script(engine, "02_core.sql")
            
        except Exception as e:
            print(f"Error during database initialization: {e}")
            raise

    # --- Drop dependancies on cleaned tables ---
    run_sql_script(engine, "00_drop_derived.sql")
    
    # --- Python Ingestion (Staging Layer) ---
    print(f"\n=== Executing Python Ingestion ({args.mode.upper()} mode) ===")
    run_etl(engine, mode=args.mode)

    print("\n>>> Pipeline execution completed successfully!")

    print("Cleaning reference tables and creating QA/QC Views")
    run_sql_script(engine, "03_tables.sql")
    run_sql_script(engine, "04_views.sql")
    


if __name__ == "__main__":
    main()
