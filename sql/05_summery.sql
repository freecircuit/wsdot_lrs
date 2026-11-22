-- ============================================================
-- 01. OVERALL ROUTE MATCH SUMMARY
-- ============================================================

WITH candidate_summary AS (
    SELECT
        objectid,
        COUNT(route_identifier) AS matched_candidates,
        BOOL_OR(route_identifier IS NOT NULL) AS has_route_match
    FROM analysis.dig_once_lrs_candidates
    GROUP BY objectid
)
SELECT
    COUNT(*) AS total_projects,
    COUNT(*) FILTER (WHERE COALESCE(c.has_route_match, FALSE)) AS projects_with_route_match,
    COUNT(*) FILTER (WHERE NOT COALESCE(c.has_route_match, FALSE)) AS projects_without_route_match,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE COALESCE(c.has_route_match, FALSE)) / NULLIF(COUNT(*), 0),
        2
    ) AS matched_percent,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE NOT COALESCE(c.has_route_match, FALSE)) / NULLIF(COUNT(*), 0),
        2
    ) AS unmatched_percent
FROM analysis.dig_once p
LEFT JOIN candidate_summary c
    ON p.objectid = c.objectid;


-- ============================================================
-- 02. UNMATCHED PROJECTS GROUPED BY ROUTE & DIRECTION
-- ============================================================

SELECT
    stateroutenumber,
    project_route_identifier,
    project_related_route_type,
    project_related_route_qualifier,
    project_direction,
    COUNT(DISTINCT objectid) AS project_count,
    ARRAY_AGG(DISTINCT projectnumber ORDER BY projectnumber) AS project_numbers
FROM analysis.dig_once_lrs_candidates
WHERE lrs_status = 'No route match'
GROUP BY
    stateroutenumber,
    project_route_identifier,
    project_related_route_type,
    project_related_route_qualifier,
    project_direction
ORDER BY
    project_count DESC,
    stateroutenumber;


-- ============================================================
-- 03. DETAILED COVERAGE GAP TABLE (FROM QA VIEW)
-- ============================================================

SELECT *
FROM qa.dig_once_lrs_coverage_gaps
ORDER BY
    project_count DESC,
    state_route_number_key,
    related_type_key,
    related_qualifier_key;


-- ============================================================
-- 04. UNMATCHED PROJECT ROW-LEVEL DETAIL
-- ============================================================

SELECT
    objectid,
    projectnumber,
    projecttitle,
    project_route_identifier,
    stateroutenumber,
    project_related_route_type,
    project_related_route_qualifier,
    project_direction,
    beginaccumulatedroutemile,
    endaccumulatedroutemile,
    beginstateroutemilepost,
    endstateroutemilepost,
    lrs_status
FROM analysis.dig_once_lrs_candidates
WHERE lrs_status = 'No route match'
ORDER BY
    stateroutenumber,
    project_related_route_type,
    project_related_route_qualifier,
    projectnumber;


-- ============================================================
-- 05. MISSING ROUTE COMBINATION COUNTS
-- ============================================================

WITH missing_keys AS (
    SELECT DISTINCT
        stateroutenumber,
        NULLIF(UPPER(BTRIM(project_related_route_type)), '') AS related_route_type,
        NULLIF(UPPER(BTRIM(project_related_route_qualifier)), '') AS related_route_qualifier
    FROM analysis.dig_once_lrs_candidates
    WHERE lrs_status = 'No route match'
)
SELECT
    COUNT(*) AS distinct_missing_route_combinations,
    COUNT(DISTINCT stateroutenumber) AS distinct_state_route_numbers,
    COUNT(*) FILTER (WHERE related_route_type IS NULL) AS missing_mainline_combinations,
    COUNT(*) FILTER (WHERE related_route_type IS NOT NULL) AS missing_related_route_combinations
FROM missing_keys;


-- ============================================================
-- 06. SUMMARY OF UNMATCHED PROJECTS BY COVERAGE GAP STATUS
-- ============================================================

SELECT
    coverage_gap_status,
    COUNT(*) AS missing_route_combinations,
    SUM(project_count) AS affected_projects,
    ROUND(
        100.0 * SUM(project_count) / NULLIF(SUM(SUM(project_count)) OVER (), 0),
        2
    ) AS percent_of_unmatched_projects
FROM qa.dig_once_lrs_coverage_gaps
GROUP BY coverage_gap_status
ORDER BY affected_projects DESC;

--- ============================================================
-- 07. QA on successful M value import
-- ============================================================

DO $$
DECLARE
    v_sql text;
BEGIN
    SELECT string_agg(
        format(
            $sql$
            SELECT
                %L::text AS table_name,
                COUNT(*) AS total_rows,
                COUNT(*) FILTER (WHERE geometry IS NOT NULL AND ST_HasM(geometry)) AS rows_with_m,
                COUNT(*) FILTER (WHERE geometry IS NOT NULL AND NOT ST_HasM(geometry)) AS rows_without_m,
                array_agg(DISTINCT ST_GeometryType(geometry)) FILTER (WHERE geometry IS NOT NULL) AS geom_types
            FROM staging.%I
            $sql$,
            table_name,
            table_name
        ),
        E'\nUNION ALL\n'
    )
    INTO v_sql
    FROM information_schema.columns
    WHERE table_schema = 'staging'
      AND column_name = 'geometry';

    DROP TABLE IF EXISTS pg_temp.m_value_audit;

    IF v_sql IS NOT NULL THEN
        EXECUTE format('CREATE TEMP TABLE m_value_audit AS %s', v_sql);
    ELSE
        CREATE TEMP TABLE m_value_audit (
            table_name text,
            total_rows bigint,
            rows_with_m bigint,
            rows_without_m bigint,
            geom_types text[]
        );
    END IF;
END
$$;

SELECT *
FROM pg_temp.m_value_audit
ORDER BY table_name;