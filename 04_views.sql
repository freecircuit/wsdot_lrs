-- Create views from reference tables for QA/QC checks
-- and analysis results for the qa and analysis schemas

-- QA/QC view joining mileposts with state route LRS table
CREATE OR REPLACE VIEW qa.sr_mp_locations_evw AS
SELECT
    mp.objectid,
    mp.route_id,
    mp.direction,
    mp.actual_route_mile,
    mp.mile_post,

    sr.route_identifier,
    sr.inventory_direction,
	sr.geom AS sr_lrs_geom,

    ST_Distance(mp.geom, sr.geom) AS section_distance,

    mp.geom AS source_location,

    ST_LocateAlong(
        sr.geom,
        mp.actual_route_mile
    ) AS lrs_location,

    ST_Distance(
        mp.geom,
        ST_LocateAlong(sr.geom, mp.actual_route_mile)
    ) AS offset_distance

FROM ref.milepost_one_mile mp

LEFT JOIN LATERAL (
    SELECT
        sr.route_identifier,
        sr.inventory_direction,
        sr.geom

    FROM ref.state_route_lrs sr

    WHERE sr.state_route_number = mp.route_id
      AND sr.inventory_direction = mp.direction

    ORDER BY ST_Distance(mp.geom, sr.geom)

    LIMIT 1

) sr ON TRUE

WHERE mp.actual_route_mile IS NOT NULL;