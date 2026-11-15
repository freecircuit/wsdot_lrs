-- Clean column names, set CRS to EPSG:2927
-- And assign to schema ref for non-writing reference tables

-- State Route Linear Referencing
DROP TABLE IF EXISTS ref.state_routes_lrs;

CREATE TABLE ref.state_routes_lrs AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	label,
	symbolcode AS symbol_code,
	stateroutenumber AS state_route_number,
	relatedroutetype AS related_route_type,
	lrsdate AS lrs_date,
	inventorydirection AS inventory_direction,
	globalid AS guid,
	shape__length,
	    ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.state_route_lrs;
ALTER TABLE ref.state_routes_lrs ADD PRIMARY KEY (objectid);
CREATE INDEX state_lrs_geom_idx ON ref.state_routes_lrs USING GIST (geom);
ANALYZE ref.state_routes_lrs;

-- CRAB Routes Linear Referencing
DROP TABLE IF EXISTS ref.crab_routes;

CREATE TABLE ref.crab_routes AS
SELECT
	objectid,
	roadnumber AS road_number,
	routeidentifier AS route_identifier,
	lrsdate AS lrs_date,
	countyfipslongplacecode AS county_fips_code,
	globalid AS guid,
	shape__length,
	    ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
	source
FROM staging.crab_rts;

ALTER TABLE ref.crab_routes ADD PRIMARY KEY (objectid);
CREATE INDEX crab_geom_idx ON ref.crab_routes USING GIST (geom);
ANALYZE ref.crab_routes;
--