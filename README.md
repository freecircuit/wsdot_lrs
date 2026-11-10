# WSDOT LRS Spatial ETL Pipeline

A ETL pipeline for Washington State Department of Transportation (WSDOT) datasets, transitioning raw ArcGIS REST services into a PostGIS database.

---

## Features

* **Parallelized Bounding-Box Ingestion:** Splits statewide extents into a spatial grid and uses multi-threading (`ThreadPoolExecutor`) for high-speed extraction.
* **Smart Geometry Parsing:** Automatically handles `Point`, `LineString`, `MultiLineString`, and `Polygon` types by inspecting Esri JSON structures (`paths`, `rings`, `x`, `y`).
* **Resilient Pagination & Retries:** Automatically manages large feature layers, M-value support (`returnM=true`), and network fluctuations.

---

## Stack

* **Language:** Python & SQL 
* **Spatial Libraries:** GeoPandas, Shapely, SQLAlchemy
* **Database:** PostgreSQL & PostGIS
* **Package Management:** `uv`
* **Data Source:** [WSDOT ArcGIS REST Services](https://data.wsdot.wa.gov/arcgis/rest/services)

---

## Quickstart

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/freecircuit/wsdot_lrs.git](https://github.com/freecircuit/wsdot_lrs.git)
   cd wsdot_lrs
