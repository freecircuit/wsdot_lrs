import argparse
import os
from urllib.parse import quote_plus

from dotenv import load_dotenv
import sqlalchemy

from .etl import run_etl
from .sql_file import run_sql_script

load_dotenv()


def _create_db_engine() -> sqlalchemy.Engine:
    if database_url := os.getenv("DATABASE_URL"):
        return sqlalchemy.create_engine(database_url, pool_pre_ping=True)

    user = os.getenv("DB_USERNAME", "postgres")
    password = os.getenv("DB_PASSWORD", "")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    dbname = os.getenv("DB_NAME", "wsdot")

    encoded_user = quote_plus(user)
    auth = f"{encoded_user}:{quote_plus(password)}" if password else encoded_user
    location = f"{host}:{port}" if host else ""
    url = f"postgresql+psycopg://{auth}@{location}/{dbname}"
    return sqlalchemy.create_engine(url, pool_pre_ping=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="WSDOT ELT Pipeline and LRS")
    parser.add_argument(
        "--mode",
        type=str,
        default="backbone",
        choices=["backbone", "enterprise"],
        help="ETL extraction mode: 'backbone' for core assets, 'enterprise' for full statewide ingestion.",
    )
    parser.add_argument(
        "--skip-sql",
        action="store_true",
        help="Skip database bootstrapping scripts and run Python ETL only.",
    )

    args = parser.parse_args()
    engine = _create_db_engine()

    print(">>> WSDOT Spatial Pipeline Initialized")

    # --- Database Infrastructure & Schemas ---
    if not args.skip_sql:
        print("\n=== Creating Database Extensions & Schemas ===")
        try:
            run_sql_script(engine, "01_init.sql")
            run_sql_script(engine, "02_core.sql")
        except Exception as e:
            print(f"Error during database initialization: {e}")
            raise

    # --- Drop dependent views/materialized views before recreation ---
    run_sql_script(engine, "00_drop_derived.sql")

    # --- Python Ingestion (Staging Layer) ---
    print(f"\n=== Executing Python Ingestion ({args.mode.upper()} mode) ===")
    run_etl(engine, mode=args.mode)

    print("\nCleaning reference tables and creating QA/QC Views")
    run_sql_script(engine, "03_tables.sql")
    run_sql_script(engine, "04_views.sql")

    print("\n>>> Pipeline execution completed successfully!")


if __name__ == "__main__":
    main()