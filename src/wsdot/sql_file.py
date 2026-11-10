# src/wsdot/db_setup.py
import sqlalchemy
from pathlib import Path

def run_sql_script(engine, sql_filename):
    """Executes an external .sql file against the database engine."""
    # sql files in sql folder from wsdot root
    sql_path = Path(__file__).resolve().parents[2] / "sql" / sql_filename
    
    if not sql_path.exists():
        raise FileNotFoundError(f"SQL file not found at: {sql_path}")
    
    print(f"-- Executing SQL script: {sql_filename} --")
    sql_content = sql_path.read_text(encoding="utf-8")
    
    with engine.begin() as conn:
        conn.execute(sqlalchemy.text(sql_content))
        
    print(f"Successfully executed: {sql_filename}")
