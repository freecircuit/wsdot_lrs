-- Create tables and views from reference tables for QA/QC checks
-- and analysis results for the qa and analysis schemas

-- QA/QC table joining mileposts with state route LRS table
-- One mile LRS
DROP TABLE IF EXISTS qa.sr_mp_locations;
CREATE TABLE qa.sr_mp_locations AS
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
ALTER TABLE qa.sr_mp_locations ADD PRIMARY KEY (objectid);
CREATE INDEX sr_mp_locations_geom_idx ON qa.sr_mp_locations USING GIST (sr_lrs_geom);
CREATE INDEX sr_mp_locations2_geom_idx ON qa.sr_mp_locations USING GIST (source_location);
CREATE INDEX sr_mp_locations3_geom_idx ON qa.sr_mp_locations USING GIST (lrs_location);
ANALYZE qa.sr_mp_locations;

-- 5 mile LRS
DROP TABLE IF EXISTS qa.sr_5m_locations;
CREATE TABLE qa.sr_5m_locations AS
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

FROM ref.milepost_five_mile mp

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
ALTER TABLE qa.sr_5m_locations ADD PRIMARY KEY (objectid);
CREATE INDEX sr_5m_locations_geom_idx ON qa.sr_5m_locations USING GIST (sr_lrs_geom);
CREATE INDEX sr_5m_locations2_geom_idx ON qa.sr_5m_locations USING GIST (source_location);
CREATE INDEX sr_5m_locations3_geom_idx ON qa.sr_5m_locations USING GIST (lrs_location);
ANALYZE qa.sr_5m_locations;

--10 Mile LRS
DROP TABLE IF EXISTS qa.sr_10m_locations;
CREATE TABLE qa.sr_10m_locations AS
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

FROM ref.milepost_ten_mile mp

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
ALTER TABLE qa.sr_10m_locations ADD PRIMARY KEY (objectid);
CREATE INDEX sr_10m_locations_geom_idx ON qa.sr_10m_locations USING GIST (sr_lrs_geom);
CREATE INDEX sr_10m_locations2_geom_idx ON qa.sr_10m_locations USING GIST (source_location);
CREATE INDEX sr_10m_locations3_geom_idx ON qa.sr_10m_locations USING GIST (lrs_location);
ANALYZE qa.sr_10m_locations;

--tenth of mile LRS
DROP TABLE IF EXISTS qa.sr_10thm_locations;
CREATE TABLE qa.sr_10thm_locations AS
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

FROM ref.milepost_tenth_mile mp

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
ALTER TABLE qa.sr_10thm_locations ADD PRIMARY KEY (objectid);
CREATE INDEX sr_10thm_locations_geom_idx ON qa.sr_10thm_locations USING GIST (sr_lrs_geom);
CREATE INDEX sr_10thm_locations2_geom_idx ON qa.sr_10thm_locations USING GIST (source_location);
CREATE INDEX sr_10thm_locations3_geom_idx ON qa.sr_10thm_locations USING GIST (lrs_location);
ANALYZE qa.sr_10thm_locations;

-- LRS located bridges and tunnels along SR
DROP VIEW IF EXISTS qa.sr_bridge_tunnel_evw;
CREATE MATERIALIZED VIEW qa.sr_bridge_tunnel_evw AS

SELECT
    b.objectid,
    b.lrsrouteid,
    b.lrsmilepost AS reported_milepost,
    b.lrsarm AS reported_arm,

    matched.route_identifier,
    matched.inventory_direction,
    matched.related_route_type,
    matched.related_route_qualifier,

    matched.derived_arm,
    matched.distance_to_route,

    matched.derived_arm - b.lrsarm
        AS arm_difference_miles,

    ABS(matched.derived_arm - b.lrsarm) * 5280
        AS arm_difference_feet,

    CASE
        WHEN b.geom IS NULL
            THEN 'Missing source geometry'

        WHEN matched.route_identifier IS NULL
            THEN 'No State Route match'

        WHEN matched.derived_arm IS NULL
            THEN 'Matched - no derived ARM'

        WHEN b.lrsarm IS NULL
            THEN 'Matched - no reported ARM'

        WHEN ABS(matched.derived_arm - b.lrsarm) <= 0.01
            THEN 'ARM agreement within 0.01 mi'

        ELSE 'ARM discrepancy'
    END AS arm_qa_status

FROM ref.all_bridge_tunnel b

LEFT JOIN LATERAL (

    SELECT
        sr.route_identifier,
        sr.inventory_direction,
        sr.related_route_type,
        sr.related_route_qualifier,

        ST_InterpolatePoint(
            d.geom,
            b.geom
        ) AS derived_arm,

        ST_Distance(
            b.geom,
            d.geom
        ) AS distance_to_route

    FROM ref.state_route_lrs sr

    CROSS JOIN LATERAL ST_Dump(sr.geom) AS d

    WHERE UPPER(
        REGEXP_REPLACE(
            sr.route_identifier,
            '[id]$',
            '',
            'i'
        )
    ) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))

      AND b.geom IS NOT NULL

    ORDER BY
        ST_Distance(b.geom, d.geom)

    LIMIT 1

) AS matched ON TRUE;

CREATE INDEX idx_mv_bridge_prl_objectid
ON qa.sr_bridge_tunnel_evw(objectid);

CREATE INDEX idx_mv_bridge_prl_status
ON qa.sr_bridge_tunnel_evw (arm_qa_status);

CREATE INDEX idx_mv_bridge_prl_route
ON qa.sr_bridge_tunnel_evw (route_identifier);

-- Local Public Roads LRS bridges & tunnels
DROP VIEW qa.bt_pub_rd_evw;
CREATE MATERIALIZED VIEW qa.bt_pub_rd_evw AS

SELECT
    b.objectid,
    b.lrsrouteid,
    b.lrsmilepost AS reported_milepost,
    b.lrsarm AS reported_arm,

    matched.route_identifier,
    matched.inventory_direction,
    matched.related_route_type,
    matched.related_route_qualifier,

    matched.derived_arm,
    matched.distance_to_route,

    matched.derived_arm - b.lrsarm
        AS arm_difference_miles,

    ABS(matched.derived_arm - b.lrsarm) * 5280
        AS arm_difference_feet,

    CASE
        WHEN b.geom IS NULL
            THEN 'Missing source geometry'

        WHEN NULLIF(BTRIM(b.lrsrouteid), '') IS NULL
            THEN 'Missing route identifier'

        WHEN matched.route_identifier IS NULL
            THEN 'No prl match'

        WHEN matched.derived_arm IS NULL
            THEN 'Matched - no derived ARM'

        WHEN b.lrsarm IS NULL
            THEN 'Matched - no reported ARM'

        WHEN ABS(matched.derived_arm - b.lrsarm) <= 0.01
            THEN 'ARM agreement within 0.01 mi'

        ELSE 'ARM discrepancy'
    END AS arm_qa_status

FROM ref.all_bridge_tunnel b

JOIN qa.sr_bridge_tunnel_evw srqa
    ON srqa.objectid = b.objectid
    AND srqa.route_identifier IS NULL

LEFT JOIN LATERAL (

    SELECT
        prl.route_identifier,

        CASE
            WHEN RIGHT(LOWER(prl.route_identifier), 1) IN ('i', 'd')
                THEN RIGHT(LOWER(prl.route_identifier), 1)
            ELSE NULL
        END AS inventory_direction,

        NULL::text AS related_route_type,
        NULL::text AS related_route_qualifier,

        ST_InterpolatePoint(
            d.geom,
            b.geom
        ) AS derived_arm,

        ST_Distance(
            b.geom,
            d.geom
        ) AS distance_to_route

    FROM ref.public_roads_lrs prl

    CROSS JOIN LATERAL ST_Dump(prl.geom) AS d

    WHERE b.geom IS NOT NULL

      AND (
          UPPER(prl.route_identifier) =
              UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))

          OR

          UPPER(
              REGEXP_REPLACE(
                  prl.route_identifier,
                  '[id]$',
                  '',
                  'i'
              )
          ) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
      )

    ORDER BY
        CASE
            WHEN UPPER(prl.route_identifier) =
                 UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
                THEN 0
            ELSE 1
        END,

        ST_Distance(b.geom, d.geom)

    LIMIT 1

) AS matched ON TRUE;

CREATE INDEX idx_mv_bridge_prl_objectid
ON qa.bt_pub_rd_evw (objectid);

CREATE INDEX idx_mv_bridge_prl_status
ON qa.bt_pub_rd_evw (arm_qa_status);

CREATE INDEX idx_mv_bridge_prl_route
ON qa.bt_pub_rd_evw (route_identifier);

-- Crab Routes Bridges and Tunnels
DROP VIEW IF EXISTS qa.bt_crab_evw;
CREATE MATERIALIZED VIEW qa.bt_crab_evw AS
SELECT
    b.objectid,
    b.lrsrouteid,
    b.lrsmilepost AS reported_milepost,
    b.lrsarm AS reported_arm,

    matched.route_identifier,
    matched.inventory_direction,
    matched.related_route_type,
    matched.related_route_qualifier,

    matched.derived_arm,
    matched.distance_to_route,

    matched.derived_arm - b.lrsarm
        AS arm_difference_miles,

    ABS(matched.derived_arm - b.lrsarm) * 5280
        AS arm_difference_feet,

    CASE
        WHEN b.geom IS NULL
            THEN 'Missing source geometry'

        WHEN NULLIF(BTRIM(b.lrsrouteid), '') IS NULL
            THEN 'Missing route identifier'

        WHEN matched.route_identifier IS NULL
            THEN 'No CRAB match'

        WHEN matched.derived_arm IS NULL
            THEN 'Matched - no derived ARM'

        WHEN b.lrsarm IS NULL
            THEN 'Matched - no reported ARM'

        WHEN ABS(matched.derived_arm - b.lrsarm) <= 0.01
            THEN 'ARM agreement within 0.01 mi'

        ELSE 'ARM discrepancy'
    END AS arm_qa_status

FROM ref.all_bridge_tunnel b

JOIN qa.bt_pub_rd_evw srqa
    ON srqa.objectid = b.objectid
    AND srqa.route_identifier IS NULL

LEFT JOIN LATERAL (

    SELECT
        crab.route_identifier,

        CASE
            WHEN RIGHT(LOWER(crab.route_identifier), 1) IN ('i', 'd')
                THEN RIGHT(LOWER(crab.route_identifier), 1)
            ELSE NULL
        END AS inventory_direction,

        NULL::text AS related_route_type,
        NULL::text AS related_route_qualifier,

        ST_InterpolatePoint(
            d.geom,
            b.geom
        ) AS derived_arm,

        ST_Distance(
            b.geom,
            d.geom
        ) AS distance_to_route

    FROM ref.crab_routes crab

    CROSS JOIN LATERAL ST_Dump(crab.geom) AS d

    WHERE b.geom IS NOT NULL

      AND (
          UPPER(crab.route_identifier) =
              UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))

          OR

          UPPER(
              REGEXP_REPLACE(
                  crab.route_identifier,
                  '[id]$',
                  '',
                  'i'
              )
          ) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
      )

    ORDER BY
        CASE
            WHEN UPPER(crab.route_identifier) =
                 UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
                THEN 0
            ELSE 1
        END,

        ST_Distance(b.geom, d.geom)

    LIMIT 1

) AS matched ON TRUE;

CREATE INDEX idx_mv_bridge_prl_objectid
ON qa.bt_crab_evw (objectid);

CREATE INDEX idx_mv_bridge_prl_status
ON qa.bt_crab_evw (arm_qa_status);

CREATE INDEX idx_mv_bridge_prl_route
ON qa.bt_crab_evw (route_identifier);

-- SR bridges and Tunnels with > 0.1 mile descrepancy
CREATE OR REPLACE VIEW qa.bt_arm_discrepancy AS
SELECT br.*, srbr.derived_arm, srbr.distance_to_route, ROUND(srbr.arm_difference_feet::numeric, 3) AS diff_feet
FROM qa.sr_bridge_tunnel_evw srbr
JOIN ref.all_bridge_tunnel br
ON br.objectid = srbr.objectid
where arm_qa_status LIKE 'ARM discrepancy';

-- Public Roads Bridges View
CREATE OR REPLACE VIEW qa.bt_pub AS
SELECT br.*, pub.derived_arm, pub.distance_to_route, ROUND(pub.arm_difference_feet::numeric, 3) AS diff_feet, pub.arm_qa_status
FROM qa.bt_pub_rd_evw pub
JOIN ref.all_bridge_tunnel br
ON br.objectid = pub.objectid;
