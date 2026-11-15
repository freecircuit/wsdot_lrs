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
    relatedroutequalifier AS related_route_qualifier,
	lrsdate AS lrs_date,
	inventorydirection AS inventory_direction,
	globalid AS guid,
	shape__length,
    ST_Multi(
    ST_Transform(
        ST_SetSRID(geometry, 3857),
        2927
        )
    )::geometry(MultiLineStringM, 2927) AS geom,
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
	countyfipslongplacecode AS county_fips_long_place_code,
	globalid AS guid,
	shape__length,
    ST_Multi(
    ST_Transform(
        ST_SetSRID(geometry, 3857),
        2927
        )
    )::geometry(MultiLineStringM, 2927) AS geom,
	source
FROM staging.crab_rts;

ALTER TABLE ref.crab_routes ADD PRIMARY KEY (objectid);
CREATE INDEX crab_geom_idx ON ref.crab_routes USING GIST (geom);
ANALYZE ref.crab_routes;

-- Public Roads Complete
DROP TABLE IF EXISTS ref.public_roads;
CREATE TABLE ref.public_roads AS
SELECT
	objectid,
	roadname AS road_name,
    routeidentifier AS route_identifier,
	federalfunctionalclassdesc AS functional_class_description_federal,
	cityname AS city_name,
	jurisdiction,
	oldfederalfunctionalclass AS old_functional_class_federal,
	federalfunctionalclasscode AS functional_class_code_federal,
	inventorydirection AS inventory_direction,
	lrsdate AS lrs_date,
	cityfipslongplacecode AS city_fips,
	countyfipslongplacecode AS county_fips,
	globalid AS guid,
	length,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.local_public_roads;
ALTER TABLE ref.public_roads ADD PRIMARY KEY (objectid);
CREATE INDEX pub_roads_geom_idx ON ref.public_roads USING GIST (geom);
ANALYZE ref.public_roads;

-- Local Public Roads Linear Referencing
DROP TABLE IF EXISTS ref.public_roads_lrs;
CREATE TABLE ref.public_roads_lrs AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	lrsdate AS lrs_date,
	globalid AS guid,
	shape__length,
    ST_Multi(
    ST_Transform(
        ST_SetSRID(geometry, 3857),
        2927
        )
    )::geometry(MultiLineStringM, 2927) AS geom,
    source
FROM staging.local_pub_roads_rt;
ALTER TABLE ref.public_roads_lrs ADD PRIMARY KEY (objectid);
CREATE INDEX pub_roads_lrs_geom_idx ON ref.public_roads_lrs USING GIST (geom);
ANALYZE ref.public_roads_lrs;

-- Counties
DROP TABLE IF EXISTS ref.counties;
CREATE TABLE ref.counties AS
SELECT
	objectid,
	jurlbl AS name,
	jurnm AS county_name,
	jurdsg AS designation_code,
	jurfipsdsg AS fips,
	shape__area,
	shape__length,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.counties;
ALTER TABLE ref.counties ADD PRIMARY KEY (objectid);
CREATE INDEX counties_geom_idx ON ref.counties USING GIST (geom);
ANALYZE ref.counties;

-- FEATURES

--Roadway Width
DROP TABLE IF EXISTS event.roadway_width;
CREATE TABLE event.roadway_width AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	beginaccumulatedroutemile AS inital_route_mile,
	endaccumulatedroutemile AS final_route_mile,
	rdwywidth AS roadway_width,
	snapshotdate AS snapshot_date,
	beginstateroutemilepost AS inital_mile_post,
	endstateroutemilepost AS final_mile_post,
	lrsdate AS lrs_date,
	shape__length,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.roadway_width;
ALTER TABLE event.roadway_width ADD PRIMARY KEY (objectid);
CREATE INDEX roadway_width_geom_idx ON event.roadway_width USING GIST (geom);
ANALYZE event.roadway_width;

-- Traffic Counts
DROP TABLE IF EXISTS event.traffic_counts;
CREATE TABLE event.traffic_counts AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	lrsdate AS lrs_date,
	location,
	directionoftravel AS travel_direction,
	stateroutenumber AS state_route_number,
	relatedroutetype AS related_route_type,
	relatedroutequalifier AS related_route_qualifier,
	singleunittruckpct AS truck_no_trailer_pct,
	doubleunittruckpct AS truck_single_trailer_pct,
	tripleunittruckpct AS truck_double_trailer_pct,
	aadt AS daily_traffic_average_annual,
	accumulatedroutemile AS accumulated_route_miles,
	globalid AS guid,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.traffic_counts;
ALTER TABLE event.traffic_counts ADD PRIMARY KEY (objectid);
CREATE INDEX traffic_counts_geom_idx ON event.traffic_counts USING GIST (geom);
ANALYZE event.traffic_counts;

--State Route Events
DROP TABLE IF EXISTS event.state_hwy_events;
CREATE TABLE event.state_hwy_events AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	stateroutenumber AS route_number,
	relatedroutetype AS related_route_type,
	relatedroutequalifier AS related_route_qualifier,
	beginstateroutemilepost AS start_mile_post,
	endstateroutemilepost AS end_mile_post,
	beginaccumulatedroutemile AS start_mile,
	endaccumulatedroutemile AS end_mile,
	inventorydirection AS direction,
	lrsdate AS lrs_date,
	globalid AS guid,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.state_hwy_events;
ALTER TABLE event.state_hwy_events ADD PRIMARY KEY (objectid);
CREATE INDEX state_hwy_events_geom_idx ON event.state_hwy_events USING GIST (geom);
ANALYZE event.state_hwy_events;

--Non-State Route Events
DROP TABLE IF EXISTS event.nonstate_hwy_events;
CREATE TABLE event.nonstate_hwy_events AS
SELECT
	objectid,
	routeidentifier AS route_identifier,
	beginaccumulatedroutemile AS start_mile,
	endaccumulatedroutemile AS end_mile,
	nationalhighwaysystem AS national_hwy_system,
	lrsdate AS lrs_date,
	globalid AS guid,
	length,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.nonstate_hwy_events;
ALTER TABLE event.nonstate_hwy_events ADD PRIMARY KEY (objectid);
CREATE INDEX nonstate_hwy_events_geom_idx ON event.nonstate_hwy_events USING GIST (geom);
ANALYZE event.nonstate_hwy_events;

--Fish Passage Barriers
DROP TABLE IF EXISTS inventory.fish_passage_barrier_current;
CREATE TABLE inventory.fish_passage_barrier_current AS
SELECT
	objectid,
	site_num AS site_number,
	road_name,
	milepost_meas AS milepost,
	cnty_name AS county,
	stream_name AS stream,
	tribto_name AS tributary,
	wria_num AS water_resource_inventory_num,
	fishuse_desc AS fish_use,
	linealgain_meas AS linear_habitat_distance,
	significant_reach_desc AS significant_reach,
	percentagepassable AS pct_passable,
	sitestatus AS status,
	species,
	yearcorrected AS year_corrected,
	incrementalgain_meas AS incremental_gain,
	ST_Transform(
        ST_SetSRID((geometry), 3857), 
        2927
    ) AS geom,
    source
FROM staging.fish_passage_injunction_barrier_current;
ALTER TABLE inventory.fish_passage_barrier_current ADD PRIMARY KEY (objectid);
CREATE INDEX fish_passage_barrier_current_geom_idx ON inventory.fish_passage_barrier_current USING GIST (geom);
ANALYZE inventory.fish_passage_barrier_current;

-- Status of Total Fish Barriers
DROP TABLE IF EXISTS inventory.fish_passage_status;
CREATE TABLE inventory.fish_passage_status AS
SELECT 
    *,
    ST_Transform(ST_SetSRID(geometry, 3857), 2927) AS geom
FROM staging.fish_passage_inventory_barrier_status;
ALTER TABLE inventory.fish_passage_status DROP COLUMN geometry;
ALTER TABLE inventory.fish_passage_status ADD PRIMARY KEY (objectid);
CREATE INDEX fish_passage_status_geom_idx ON inventory.fish_passage_status USING GIST (geom);
ANALYZE inventory.fish_passage_status;

-- All Bridges and Tunnels
DROP TABLE IF EXISTS inventory.all_bridge_tunnel;
CREATE TABLE inventory.all_bridge_tunnel AS
SELECT 
    *,
    ST_Transform(ST_SetSRID(geometry, 3857), 2927) AS geom
FROM staging.all_bridge_and_tunnel_inventory_state_local;
ALTER TABLE inventory.all_bridge_tunnel DROP COLUMN geometry;
ALTER TABLE inventory.all_bridge_tunnel ADD PRIMARY KEY (objectid);
CREATE INDEX all_bridge_tunnel_geom_idx ON inventory.all_bridge_tunnel USING GIST (geom);
ANALYZE inventory.all_bridge_tunnel;

-- Current Projects for Dig Once Datasets
DROP TABLE IF EXISTS project.current_projects;
CREATE TABLE project.current_projects AS
SELECT 
    *,
    ST_Transform(ST_SetSRID(geometry, 3857), 2927) AS geom
FROM staging.wsdot_current_project_delivery_plan;
ALTER TABLE project.current_projects DROP COLUMN geometry;
ALTER TABLE project.current_projects ADD PRIMARY KEY (objectid);
CREATE INDEX current_projects_geom_idx ON project.current_projects USING GIST (geom);
ANALYZE project.current_projects;

-- Primary State Route reference
CREATE INDEX state_routes_lrs_route_idx
ON ref.state_routes_lrs (route_identifier);

-- County road reference
CREATE INDEX crab_routes_route_idx
ON ref.crab_routes (route_identifier);

-- Comprehensive local road network
CREATE INDEX public_roads_route_idx
ON ref.public_roads (route_identifier);

-- Local Public Roads LRS
CREATE UNIQUE INDEX public_roads_lrs_route_uidx
ON ref.public_roads_lrs (route_identifier);

-- Linear events
CREATE INDEX roadway_width_route_idx
ON event.roadway_width (route_identifier);

CREATE INDEX state_hwy_events_route_idx
ON event.state_hwy_events (route_identifier);

CREATE INDEX nonstate_hwy_events_route_idx
ON event.nonstate_hwy_events (route_identifier);

CREATE INDEX traffic_counts_route_idx
ON event.traffic_counts (route_identifier);