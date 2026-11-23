-- Create tables and views from reference tables for QA/QC checks
-- and analysis results for the qa and analysis schemas.
-- Assumes EPSG:2927 (Washington South, US survey feet) on ref geometries.

CREATE SCHEMA IF NOT EXISTS qa;
CREATE SCHEMA IF NOT EXISTS analysis;

-- ============================================================
-- 00. DROP EXISTING QA & ANALYSIS OBJECTS IN DEPENDENCY ORDER
-- ============================================================

DROP VIEW IF EXISTS qa.dig_once_lrs_coverage_gaps;
DROP VIEW IF EXISTS qa.dig_once_lrs_review;
DROP MATERIALIZED VIEW IF EXISTS analysis.dig_once_lrs;
DROP VIEW IF EXISTS analysis.dig_once_lrs_candidates;
DROP VIEW IF EXISTS analysis.dig_once;

DROP VIEW IF EXISTS qa.vw_bt_arm_sensitivity;
DROP VIEW IF EXISTS qa.vw_bt_arm;
DROP VIEW IF EXISTS qa.bt_pub;
DROP VIEW IF EXISTS qa.bt_arm_descrepancy;
DROP MATERIALIZED VIEW IF EXISTS qa.bt_crab_evw;
DROP MATERIALIZED VIEW IF EXISTS qa.bt_pub_rd_evw;
DROP MATERIALIZED VIEW IF EXISTS qa.sr_bridge_tunnel_evw;


-- ============================================================
-- 01. MILEPOST TO STATE ROUTE LRS LOCATION TABLES
-- ============================================================

-- One-mile LRS
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
    ST_LocateAlong(sr.geom, mp.actual_route_mile) AS lrs_location,
    ST_Distance(mp.geom, ST_LocateAlong(sr.geom, mp.actual_route_mile)) AS offset_distance
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

-- Five-mile LRS
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
    ST_LocateAlong(sr.geom, mp.actual_route_mile) AS lrs_location,
    ST_Distance(mp.geom, ST_LocateAlong(sr.geom, mp.actual_route_mile)) AS offset_distance
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

-- Ten-mile LRS
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
    ST_LocateAlong(sr.geom, mp.actual_route_mile) AS lrs_location,
    ST_Distance(mp.geom, ST_LocateAlong(sr.geom, mp.actual_route_mile)) AS offset_distance
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

-- Tenth-of-a-mile LRS
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
    ST_LocateAlong(sr.geom, mp.actual_route_mile) AS lrs_location,
    ST_Distance(mp.geom, ST_LocateAlong(sr.geom, mp.actual_route_mile)) AS offset_distance
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


-- ============================================================
-- 02. BRIDGE & TUNNEL LRS / ARM QA MATERIALIZED VIEWS
-- ============================================================

-- State Route bridges and tunnels
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
    matched.derived_arm - b.lrsarm AS arm_difference_miles,
    abs(matched.derived_arm - b.lrsarm) * 5280::double precision AS arm_difference_feet,
    CASE
        WHEN b.geom IS NULL THEN 'Missing source geometry'
        WHEN matched.route_identifier IS NULL THEN 'No State Route match'
        WHEN matched.derived_arm IS NULL THEN 'Matched - no derived ARM'
        WHEN b.lrsarm IS NULL THEN 'Matched - no reported ARM'
        WHEN abs(matched.derived_arm - b.lrsarm) <= 0.01
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
        ST_InterpolatePoint(d.geom, b.geom) AS derived_arm,
        ST_Distance(b.geom, d.geom) AS distance_to_route
    FROM ref.state_route_lrs sr
    CROSS JOIN LATERAL ST_Dump(sr.geom) d(path, geom)
    WHERE
        b.geom IS NOT NULL
        AND upper(
            regexp_replace(
                sr.route_identifier,
                '[id]$',
                '',
                'i'
            )
        ) = upper(NULLIF(btrim(b.lrsrouteid), ''))
    ORDER BY
        CASE
            WHEN upper(b.lrsinventorydirection) = 'I'
                 AND lower(sr.inventory_direction) = 'i'
                THEN 0
            WHEN upper(b.lrsinventorydirection) = 'D'
                 AND lower(sr.inventory_direction) = 'd'
                THEN 0
            ELSE 1
        END,
        ST_Distance(b.geom, d.geom)
    LIMIT 1
) matched ON true;

CREATE INDEX idx_sr_bridge_prl_objectid ON qa.sr_bridge_tunnel_evw (objectid);
CREATE INDEX idx_sr_bridge_prl_status ON qa.sr_bridge_tunnel_evw (arm_qa_status);
CREATE INDEX idx_sr_bridge_prl_route ON qa.sr_bridge_tunnel_evw (route_identifier);
ANALYZE qa.sr_bridge_tunnel_evw;

-- Local Public Roads LRS bridges and tunnels (unmatched on State Routes)
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
    matched.derived_arm - b.lrsarm AS arm_difference_miles,
    ABS(matched.derived_arm - b.lrsarm) * 5280 AS arm_difference_feet,
    CASE
        WHEN b.geom IS NULL THEN 'Missing source geometry'
        WHEN NULLIF(BTRIM(b.lrsrouteid), '') IS NULL THEN 'Missing route identifier'
        WHEN matched.route_identifier IS NULL THEN 'No prl match'
        WHEN matched.derived_arm IS NULL THEN 'Matched - no derived ARM'
        WHEN b.lrsarm IS NULL THEN 'Matched - no reported ARM'
        WHEN ABS(matched.derived_arm - b.lrsarm) <= 0.01 THEN 'ARM agreement within 0.01 mi'
        ELSE 'ARM descrepancy'
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
        ST_InterpolatePoint(d.geom, b.geom) AS derived_arm,
        ST_Distance(b.geom, d.geom) AS distance_to_route
    FROM ref.public_roads_lrs prl
    CROSS JOIN LATERAL ST_Dump(prl.geom) AS d
    WHERE b.geom IS NOT NULL
      AND (
          UPPER(prl.route_identifier) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
          OR UPPER(REGEXP_REPLACE(prl.route_identifier, '[id]$', '', 'i'))
             = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
      )
    ORDER BY
        CASE
            WHEN UPPER(prl.route_identifier) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
                THEN 0
            ELSE 1
        END,
        ST_Distance(b.geom, d.geom)
    LIMIT 1
) AS matched ON TRUE;

CREATE INDEX idx_mv_bridge_prl_objectid ON qa.bt_pub_rd_evw (objectid);
CREATE INDEX idx_mv_bridge_prl_status ON qa.bt_pub_rd_evw (arm_qa_status);
CREATE INDEX idx_mv_bridge_prl_route ON qa.bt_pub_rd_evw (route_identifier);
ANALYZE qa.bt_pub_rd_evw;

-- CRAB routes bridges and tunnels (unmatched on State Routes and Public Roads LRS)
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
    matched.derived_arm - b.lrsarm AS arm_difference_miles,
    ABS(matched.derived_arm - b.lrsarm) * 5280 AS arm_difference_feet,
    CASE
        WHEN b.geom IS NULL THEN 'Missing source geometry'
        WHEN NULLIF(BTRIM(b.lrsrouteid), '') IS NULL THEN 'Missing route identifier'
        WHEN matched.route_identifier IS NULL THEN 'No CRAB match'
        WHEN matched.derived_arm IS NULL THEN 'Matched - no derived ARM'
        WHEN b.lrsarm IS NULL THEN 'Matched - no reported ARM'
        WHEN ABS(matched.derived_arm - b.lrsarm) <= 0.01 THEN 'ARM agreement within 0.01 mi'
        ELSE 'ARM descrepancy'
    END AS arm_qa_status
FROM ref.all_bridge_tunnel b
JOIN qa.bt_pub_rd_evw prqa
    ON prqa.objectid = b.objectid
   AND prqa.route_identifier IS NULL
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
        ST_InterpolatePoint(d.geom, b.geom) AS derived_arm,
        ST_Distance(b.geom, d.geom) AS distance_to_route
    FROM ref.crab_routes crab
    CROSS JOIN LATERAL ST_Dump(crab.geom) AS d
    WHERE b.geom IS NOT NULL
      AND (
          UPPER(crab.route_identifier) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
          OR UPPER(REGEXP_REPLACE(crab.route_identifier, '[id]$', '', 'i'))
             = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
      )
    ORDER BY
        CASE
            WHEN UPPER(crab.route_identifier) = UPPER(NULLIF(BTRIM(b.lrsrouteid), ''))
                THEN 0
            ELSE 1
        END,
        ST_Distance(b.geom, d.geom)
    LIMIT 1
) AS matched ON TRUE;

CREATE INDEX idx_crab_bridge_prl_objectid ON qa.bt_crab_evw (objectid);
CREATE INDEX idx_crab_bridge_prl_status ON qa.bt_crab_evw (arm_qa_status);
CREATE INDEX idx_crab_bridge_prl_route ON qa.bt_crab_evw (route_identifier);
ANALYZE qa.bt_crab_evw;


-- ============================================================
-- 03. BRIDGE & TUNNEL QA / SENSITIVITY VIEWS
-- ============================================================

CREATE VIEW qa.bt_arm_descrepancy AS
SELECT
    br.*,
    srbr.derived_arm,
    srbr.distance_to_route,
    ROUND(srbr.arm_difference_feet::numeric, 3) AS diff_feet,
    srbr.arm_qa_status
FROM qa.sr_bridge_tunnel_evw srbr
JOIN ref.all_bridge_tunnel br
    ON br.objectid = srbr.objectid;

CREATE VIEW qa.bt_pub AS
SELECT
    br.*,
    pub.derived_arm,
    pub.distance_to_route,
    ROUND(pub.arm_difference_feet::numeric, 3) AS diff_feet,
    pub.arm_qa_status
FROM qa.bt_pub_rd_evw pub
JOIN ref.all_bridge_tunnel br
    ON br.objectid = pub.objectid;

CREATE VIEW qa.vw_bt_arm AS
SELECT
    br.*,
    qa.route_identifier,
    qa.inventory_direction,
    qa.reported_milepost,
    qa.reported_arm,
    qa.derived_arm,
    qa.distance_to_route,
    qa.arm_difference_miles,
    qa.arm_difference_feet
FROM qa.sr_bridge_tunnel_evw qa
JOIN ref.all_bridge_tunnel br
    ON br.objectid = qa.objectid
WHERE qa.route_identifier IS NOT NULL
  AND qa.reported_arm IS NOT NULL
  AND qa.derived_arm IS NOT NULL;

CREATE VIEW qa.vw_bt_arm_sensitivity AS
SELECT
    *,
    ABS(arm_difference_miles) AS absolute_arm_difference,
    CASE
        WHEN ABS(arm_difference_miles) <= 0.01 THEN 'Within 0.01 mi'
        WHEN ABS(arm_difference_miles) <= 0.05 THEN '0.01–0.05 mi'
        WHEN ABS(arm_difference_miles) <= 0.10 THEN '0.05–0.10 mi'
        ELSE 'Greater than 0.10 mi'
    END AS descrepancy_band
FROM qa.vw_bt_arm;


-- ============================================================
-- 04. DIG ONCE BROADBAND PROJECTS & STATE ROUTE LRS RECONSTRUCTION
-- ============================================================

CREATE VIEW analysis.dig_once AS
SELECT *
FROM ref.current_projects
WHERE to_timestamp(AdDate) > '2025-01-01 07:59:59'::TIMESTAMP
  AND ProgramCode IN ('I', 'P', 'Q');

CREATE VIEW analysis.dig_once_lrs_candidates AS
WITH route_measure_bounds AS (
    SELECT
        sr.objectid AS sr_objectid,
        sr.route_identifier,
        sr.state_route_number,
        sr.related_route_type,
        sr.related_route_qualifier,
        sr.inventory_direction,
        sr.geom,
        MIN(ST_M((dp).geom)) AS route_min_m,
        MAX(ST_M((dp).geom)) AS route_max_m
    FROM ref.state_route_lrs sr
    LEFT JOIN LATERAL ST_DumpPoints(sr.geom) AS dp ON TRUE
    GROUP BY
        sr.objectid,
        sr.route_identifier,
        sr.state_route_number,
        sr.related_route_type,
        sr.related_route_qualifier,
        sr.inventory_direction,
        sr.geom
),
route_matches AS (
    SELECT
        p.objectid,
        p.projectnumber,
        p.projecttitle,
        BTRIM(p.routeidentifier) AS project_route_identifier,
        p.stateroutenumber,
        p.relatedroutetype AS project_related_route_type,
        p.relatedroutequalifier AS project_related_route_qualifier,
        p.inventorydirection AS project_direction,
        sr.route_identifier,
        sr.state_route_number,
        sr.related_route_type,
        sr.related_route_qualifier,
        sr.inventory_direction AS lrs_direction,
        p.beginaccumulatedroutemile,
        p.endaccumulatedroutemile,
        p.beginstateroutemilepost,
        p.endstateroutemilepost,
        p.geom AS source_project_geom,
        sr.geom AS reference_route_geom,
        sr.route_min_m,
        sr.route_max_m,
        ST_Distance(ST_Force2D(p.geom), ST_Force2D(sr.geom)) AS project_to_route_distance_ft,
        CASE
            WHEN UPPER(BTRIM(p.inventorydirection)) = 'B'
                THEN 'Both directions - inspect candidates'
            WHEN UPPER(BTRIM(p.inventorydirection)) = 'I'
                 AND LOWER(BTRIM(sr.inventory_direction)) = 'i'
                THEN 'Direction agrees'
            WHEN UPPER(BTRIM(p.inventorydirection)) = 'D'
                 AND LOWER(BTRIM(sr.inventory_direction)) = 'd'
                THEN 'Direction agrees'
            WHEN NULLIF(BTRIM(p.inventorydirection), '') IS NULL
                THEN 'Missing project direction - inspect candidates'
            WHEN UPPER(BTRIM(p.inventorydirection)) NOT IN ('B', 'I', 'D')
                THEN 'Unrecognized project direction - inspect candidates'
            ELSE 'Direction differs'
        END AS direction_check
    FROM analysis.dig_once p
    LEFT JOIN route_measure_bounds sr
        ON BTRIM(sr.state_route_number::text) = BTRIM(p.stateroutenumber::text)
       AND COALESCE(UPPER(BTRIM(sr.related_route_type)), '') = COALESCE(UPPER(BTRIM(p.relatedroutetype)), '')
       AND COALESCE(UPPER(BTRIM(sr.related_route_qualifier)), '') = COALESCE(UPPER(BTRIM(p.relatedroutequalifier)), '')
       AND (
           UPPER(BTRIM(p.inventorydirection)) = 'B'
           OR (UPPER(BTRIM(p.inventorydirection)) = 'I' AND LOWER(BTRIM(sr.inventory_direction)) = 'i')
           OR (UPPER(BTRIM(p.inventorydirection)) = 'D' AND LOWER(BTRIM(sr.inventory_direction)) = 'd')
           OR COALESCE(UPPER(NULLIF(BTRIM(p.inventorydirection), '')), '') NOT IN ('B', 'I', 'D')
       )
),
segments AS (
    SELECT
        *,
        CASE
            WHEN reference_route_geom IS NOT NULL
                 AND beginaccumulatedroutemile IS NOT NULL
                 AND endaccumulatedroutemile IS NOT NULL
                THEN ST_LocateBetween(
                    reference_route_geom,
                    LEAST(beginaccumulatedroutemile, endaccumulatedroutemile),
                    GREATEST(beginaccumulatedroutemile, endaccumulatedroutemile)
                )
            ELSE NULL
        END AS lrs_segment
    FROM route_matches
),
metrics AS (
    SELECT
        *,
        ST_Length(ST_Force2D(source_project_geom)) AS source_length_ft,
        CASE
            WHEN lrs_segment IS NOT NULL AND NOT ST_IsEmpty(lrs_segment)
                THEN ST_Length(ST_Force2D(lrs_segment))
            ELSE NULL
        END AS lrs_length_ft,
        CASE
            WHEN source_project_geom IS NOT NULL
                 AND lrs_segment IS NOT NULL
                 AND NOT ST_IsEmpty(lrs_segment)
                THEN ST_Distance(ST_Force2D(source_project_geom), ST_Force2D(lrs_segment))
            ELSE NULL
        END AS minimum_separation_ft,
        CASE
            WHEN source_project_geom IS NOT NULL
                 AND lrs_segment IS NOT NULL
                 AND NOT ST_IsEmpty(lrs_segment)
                THEN ST_HausdorffDistance(ST_Force2D(source_project_geom), ST_Force2D(lrs_segment))
            ELSE NULL
        END AS hausdorff_distance_ft
    FROM segments
),
classified AS (
    SELECT
        *,
        ABS(source_length_ft - lrs_length_ft) AS length_difference_ft,
        CASE
            WHEN route_identifier IS NULL
                THEN 'No route match'
            WHEN beginaccumulatedroutemile IS NULL OR endaccumulatedroutemile IS NULL
                THEN 'Missing ARM values'
            WHEN route_min_m IS NOT NULL
                 AND route_max_m IS NOT NULL
                 AND (
                     LEAST(beginaccumulatedroutemile, endaccumulatedroutemile) < route_min_m - 0.00000001
                     OR GREATEST(beginaccumulatedroutemile, endaccumulatedroutemile) > route_max_m + 0.00000001
                 )
                THEN 'Outside route measure range'
            WHEN ABS(endaccumulatedroutemile - beginaccumulatedroutemile) <= 0.0000000001
                THEN 'Zero-length measure interval'
            WHEN lrs_segment IS NULL OR ST_IsEmpty(lrs_segment)
                THEN 'No segment reconstructed'
            WHEN lrs_length_ft <= 0.000001
                THEN 'Zero-length measure interval'
            ELSE 'Segment reconstructed'
        END AS lrs_status
    FROM metrics
)
SELECT
    objectid,
    projectnumber,
    projecttitle,
    project_route_identifier,
    stateroutenumber,
    project_related_route_type,
    project_related_route_qualifier,
    project_direction,
    route_identifier,
    state_route_number,
    related_route_type,
    related_route_qualifier,
    lrs_direction,
    beginaccumulatedroutemile,
    endaccumulatedroutemile,
    beginstateroutemilepost,
    endstateroutemilepost,
    route_min_m,
    route_max_m,
    source_project_geom,
    lrs_segment,
    project_to_route_distance_ft,
    direction_check,
    source_length_ft,
    lrs_length_ft,
    minimum_separation_ft,
    hausdorff_distance_ft,
    length_difference_ft,
    lrs_status
FROM classified;

CREATE MATERIALIZED VIEW analysis.dig_once_lrs AS
WITH candidate_summary AS (
    SELECT
        objectid,
        COUNT(route_identifier) AS route_candidate_count,
        COUNT(*) FILTER (WHERE lrs_status = 'Segment reconstructed') AS reconstructed_candidate_count,
        COUNT(*) FILTER (
            WHERE route_identifier IS NOT NULL
              AND lrs_status <> 'Segment reconstructed'
        ) AS candidate_exception_count,
        COUNT(*) FILTER (WHERE lrs_status = 'Outside route measure range') AS outside_measure_range_count,
        COUNT(*) FILTER (WHERE lrs_status = 'Zero-length measure interval') AS zero_length_interval_count,
        COALESCE(
            BOOL_OR(LOWER(BTRIM(lrs_direction)) = 'i') FILTER (WHERE route_identifier IS NOT NULL),
            FALSE
        ) AS has_i_candidate,
        COALESCE(
            BOOL_OR(LOWER(BTRIM(lrs_direction)) = 'd') FILTER (WHERE route_identifier IS NOT NULL),
            FALSE
        ) AS has_d_candidate,
        ARRAY_AGG(DISTINCT route_identifier ORDER BY route_identifier)
            FILTER (WHERE route_identifier IS NOT NULL) AS matched_route_identifiers,
        ARRAY_AGG(DISTINCT lrs_direction ORDER BY lrs_direction)
            FILTER (WHERE route_identifier IS NOT NULL) AS matched_lrs_directions,
        ARRAY_AGG(DISTINCT lrs_status ORDER BY lrs_status)
            FILTER (WHERE route_identifier IS NOT NULL) AS candidate_lrs_statuses,
        ST_UnaryUnion(
            ST_Collect(ST_Force2D(lrs_segment)) FILTER (
                WHERE lrs_status = 'Segment reconstructed'
                  AND lrs_segment IS NOT NULL
                  AND NOT ST_IsEmpty(lrs_segment)
            )
        ) AS combined_lrs_segment
    FROM analysis.dig_once_lrs_candidates
    GROUP BY objectid
),
project_metrics AS (
    SELECT
        p.objectid,
        p.projectnumber,
        p.projecttitle,
        BTRIM(p.routeidentifier) AS project_route_identifier,
        p.stateroutenumber,
        p.relatedroutetype AS project_related_route_type,
        p.relatedroutequalifier AS project_related_route_qualifier,
        p.inventorydirection AS project_direction,
        p.beginaccumulatedroutemile,
        p.endaccumulatedroutemile,
        p.beginstateroutemilepost,
        p.endstateroutemilepost,
        p.geom AS source_project_geom,
        COALESCE(c.route_candidate_count, 0) AS route_candidate_count,
        COALESCE(c.reconstructed_candidate_count, 0) AS reconstructed_candidate_count,
        COALESCE(c.candidate_exception_count, 0) AS candidate_exception_count,
        COALESCE(c.outside_measure_range_count, 0) AS outside_measure_range_count,
        COALESCE(c.zero_length_interval_count, 0) AS zero_length_interval_count,
        COALESCE(c.has_i_candidate, FALSE) AS has_i_candidate,
        COALESCE(c.has_d_candidate, FALSE) AS has_d_candidate,
        c.matched_route_identifiers,
        c.matched_lrs_directions,
        c.candidate_lrs_statuses,
        c.combined_lrs_segment,
        ST_Length(ST_Force2D(p.geom)) AS source_length_ft,
        CASE
            WHEN c.combined_lrs_segment IS NOT NULL AND NOT ST_IsEmpty(c.combined_lrs_segment)
                THEN ST_Length(c.combined_lrs_segment)
            ELSE NULL
        END AS reconstructed_length_ft,
        CASE
            WHEN p.geom IS NOT NULL
                 AND c.combined_lrs_segment IS NOT NULL
                 AND NOT ST_IsEmpty(c.combined_lrs_segment)
                THEN ST_Distance(ST_Force2D(p.geom), c.combined_lrs_segment)
            ELSE NULL
        END AS minimum_separation_ft,
        CASE
            WHEN p.geom IS NOT NULL
                 AND c.combined_lrs_segment IS NOT NULL
                 AND NOT ST_IsEmpty(c.combined_lrs_segment)
                THEN ST_HausdorffDistance(ST_Force2D(p.geom), c.combined_lrs_segment)
            ELSE NULL
        END AS hausdorff_distance_ft
    FROM analysis.dig_once p
    LEFT JOIN candidate_summary c
        ON p.objectid = c.objectid
),
project_status AS (
    SELECT
        *,
        ABS(source_length_ft - reconstructed_length_ft) AS length_difference_ft,
        CASE
            WHEN route_candidate_count = 0
                THEN 'No route match'
            WHEN beginaccumulatedroutemile IS NULL OR endaccumulatedroutemile IS NULL
                THEN 'Missing ARM values'
            WHEN NULLIF(UPPER(BTRIM(project_direction)), '') IS NULL
                 OR UPPER(BTRIM(project_direction)) NOT IN ('B', 'I', 'D')
                THEN 'Missing or unrecognized project direction'
            WHEN reconstructed_candidate_count = 0 AND outside_measure_range_count > 0
                THEN 'Outside route measure range'
            WHEN reconstructed_candidate_count = 0 AND zero_length_interval_count > 0
                THEN 'Zero-length measure interval'
            WHEN reconstructed_candidate_count = 0
                THEN 'No segment reconstructed'
            WHEN UPPER(BTRIM(project_direction)) = 'B'
                 AND (NOT has_i_candidate OR NOT has_d_candidate)
                THEN 'Incomplete bidirectional match'
            WHEN candidate_exception_count > 0
                THEN 'Partial candidate exception'
            ELSE 'Segment reconstructed'
        END AS project_lrs_status
    FROM project_metrics
),
geometry_status AS (
    SELECT
        *,
        CASE
            WHEN source_project_geom IS NULL
                THEN 'Missing source project geometry'
            WHEN combined_lrs_segment IS NULL OR ST_IsEmpty(combined_lrs_segment)
                THEN 'No reconstructed geometry'
            WHEN length_difference_ft <= 1 AND hausdorff_distance_ft <= 1
                THEN 'Strong geometric agreement (<= 1 ft)'
            WHEN length_difference_ft <= 10 AND hausdorff_distance_ft <= 10
                THEN 'Close geometric agreement (<= 10 ft)'
            ELSE 'Review geometry'
        END AS geometry_qa_status
    FROM project_status
)
SELECT
    *,
    CASE
        WHEN project_lrs_status <> 'Segment reconstructed'
            THEN TRUE
        WHEN geometry_qa_status NOT IN (
            'Strong geometric agreement (<= 1 ft)',
            'Close geometric agreement (<= 10 ft)'
        )
            THEN TRUE
        ELSE FALSE
    END AS review_required
FROM geometry_status;

CREATE INDEX idx_dig_once_objectid ON analysis.dig_once_lrs (objectid);
CREATE INDEX idx_do_project_number ON analysis.dig_once_lrs (projectnumber);
CREATE INDEX idx_do_source_project_geom ON analysis.dig_once_lrs USING GIST (source_project_geom);
CREATE INDEX idx_do_lrs_segment_geom ON analysis.dig_once_lrs USING GIST (combined_lrs_segment);

CREATE VIEW qa.dig_once_lrs_review AS
SELECT *
FROM analysis.dig_once_lrs
WHERE review_required;

CREATE VIEW qa.dig_once_lrs_coverage_gaps AS
WITH unmatched AS (
    SELECT DISTINCT
        objectid,
        projectnumber,
        projecttitle,
        BTRIM(stateroutenumber::text) AS state_route_number_key,
        NULLIF(UPPER(BTRIM(project_related_route_type)), '') AS related_type_key,
        NULLIF(UPPER(BTRIM(project_related_route_qualifier)), '') AS related_qualifier_key,
        UPPER(NULLIF(BTRIM(project_direction), '')) AS project_direction_key
    FROM analysis.dig_once_lrs_candidates
    WHERE lrs_status = 'No route match'
),
unmatched_keys AS (
    SELECT
        state_route_number_key,
        related_type_key,
        related_qualifier_key,
        project_direction_key,
        COUNT(*) AS project_count,
        ARRAY_AGG(projectnumber ORDER BY projectnumber) AS project_numbers
    FROM unmatched
    GROUP BY
        state_route_number_key,
        related_type_key,
        related_qualifier_key,
        project_direction_key
),
coverage AS (
    SELECT
        k.*,
        s.route_number_count AS staging_number_count,
        s.route_type_count AS staging_type_count,
        s.route_key_count AS staging_key_count,
        s.staging_i_count,
        s.staging_d_count,
        s.staging_route_identifiers,
        r.route_number_count AS ref_number_count,
        r.route_type_count AS ref_type_count,
        r.route_key_count AS ref_key_count,
        r.ref_i_count,
        r.ref_d_count,
        r.ref_route_identifiers
    FROM unmatched_keys k
    LEFT JOIN LATERAL (
        SELECT
            COUNT(*) AS route_number_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(s.relatedroutetype)), '') IS NOT DISTINCT FROM k.related_type_key
            ) AS route_type_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(s.relatedroutetype)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(s.relatedroutequalifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS route_key_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(s.relatedroutetype)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(s.relatedroutequalifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                  AND LOWER(BTRIM(s.inventorydirection)) = 'i'
            ) AS staging_i_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(s.relatedroutetype)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(s.relatedroutequalifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                  AND LOWER(BTRIM(s.inventorydirection)) = 'd'
            ) AS staging_d_count,
            ARRAY_AGG(DISTINCT BTRIM(s.routeidentifier) ORDER BY BTRIM(s.routeidentifier))
                FILTER (
                    WHERE NULLIF(UPPER(BTRIM(s.relatedroutetype)), '') IS NOT DISTINCT FROM k.related_type_key
                      AND NULLIF(UPPER(BTRIM(s.relatedroutequalifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                ) AS staging_route_identifiers
        FROM staging.state_route_lrs s
        WHERE BTRIM(s.stateroutenumber::text) = k.state_route_number_key
    ) s ON TRUE
    LEFT JOIN LATERAL (
        SELECT
            COUNT(*) AS route_number_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(r.related_route_type)), '') IS NOT DISTINCT FROM k.related_type_key
            ) AS route_type_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(r.related_route_type)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(r.related_route_qualifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS route_key_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(r.related_route_type)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(r.related_route_qualifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                  AND LOWER(BTRIM(r.inventory_direction)) = 'i'
            ) AS ref_i_count,
            COUNT(*) FILTER (
                WHERE NULLIF(UPPER(BTRIM(r.related_route_type)), '') IS NOT DISTINCT FROM k.related_type_key
                  AND NULLIF(UPPER(BTRIM(r.related_route_qualifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                  AND LOWER(BTRIM(r.inventory_direction)) = 'd'
            ) AS ref_d_count,
            ARRAY_AGG(DISTINCT r.route_identifier ORDER BY r.route_identifier)
                FILTER (
                    WHERE NULLIF(UPPER(BTRIM(r.related_route_type)), '') IS NOT DISTINCT FROM k.related_type_key
                      AND NULLIF(UPPER(BTRIM(r.related_route_qualifier)), '') IS NOT DISTINCT FROM k.related_qualifier_key
                ) AS ref_route_identifiers
        FROM ref.state_route_lrs r
        WHERE BTRIM(r.state_route_number::text) = k.state_route_number_key
    ) r ON TRUE
)
SELECT
    *,
    CASE
        WHEN staging_number_count = 0
            THEN 'State Route number absent from staging'
        WHEN staging_type_count = 0
            THEN 'Related-route type absent from staging'
        WHEN staging_key_count = 0
            THEN 'Related-route qualifier absent from staging'
        WHEN ref_key_count = 0
            THEN 'Present in staging, absent from ref'
        WHEN project_direction_key = 'I' AND ref_i_count = 0
            THEN 'Increasing route direction absent from ref'
        WHEN project_direction_key = 'D' AND ref_d_count = 0
            THEN 'Decreasing route direction absent from ref'
        WHEN project_direction_key = 'B' AND ref_i_count = 0 AND ref_d_count = 0
            THEN 'Both route directions absent from ref'
        WHEN project_direction_key = 'B' AND (ref_i_count = 0 OR ref_d_count = 0)
            THEN 'Partial bidirectional coverage in ref'
        ELSE 'Reference key exists - investigate matching logic'
    END AS coverage_gap_status
FROM coverage
ORDER BY
    project_count DESC,
    state_route_number_key,
    related_type_key,
    related_qualifier_key;