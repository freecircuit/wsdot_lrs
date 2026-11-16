-- Dig Once summary data checks
--Total matches and stats
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

    COUNT(*) FILTER (
        WHERE COALESCE(c.has_route_match, FALSE)
    ) AS projects_with_route_match,

    COUNT(*) FILTER (
        WHERE NOT COALESCE(c.has_route_match, FALSE)
    ) AS projects_without_route_match,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE COALESCE(c.has_route_match, FALSE)
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS matched_percent,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE NOT COALESCE(c.has_route_match, FALSE)
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS unmatched_percent

FROM analysis.dig_once p

LEFT JOIN candidate_summary c
    ON p.objectid = c.objectid;

-- Unmatched projects to state route lrs

SELECT
    stateroutenumber,

    project_route_identifier,

    project_related_route_type,

    project_related_route_qualifier,

    project_direction,

    COUNT(DISTINCT objectid) AS project_count,

    ARRAY_AGG(
        DISTINCT projectnumber
        ORDER BY projectnumber
    ) AS project_numbers

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

-- Relationship between reference tables and missing projects
WITH unmatched AS (

    SELECT DISTINCT
        objectid,
        projectnumber,
        projecttitle,

        BTRIM(stateroutenumber::text)
            AS state_route_number_key,

        NULLIF(
            UPPER(BTRIM(project_related_route_type)),
            ''
        ) AS related_type_key,

        NULLIF(
            UPPER(BTRIM(project_related_route_qualifier)),
            ''
        ) AS related_qualifier_key,

        UPPER(
            NULLIF(BTRIM(project_direction), '')
        ) AS project_direction_key

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

        ARRAY_AGG(
            projectnumber
            ORDER BY projectnumber
        ) AS project_numbers

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

        -- ================================================
        -- STAGING REFERENCE COVERAGE
        -- ================================================

        s.route_number_count AS staging_number_count,
        s.route_type_count AS staging_type_count,
        s.route_key_count AS staging_key_count,
        s.staging_i_count,
        s.staging_d_count,
        s.staging_route_identifiers,

        -- ================================================
        -- CLEANED REFERENCE COVERAGE
        -- ================================================

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
                WHERE NULLIF(
                    UPPER(BTRIM(s.relatedroutetype)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key
            ) AS route_type_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(s.relatedroutetype)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(s.relatedroutequalifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS route_key_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(s.relatedroutetype)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(s.relatedroutequalifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key

                AND LOWER(BTRIM(s.inventorydirection)) = 'i'
            ) AS staging_i_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(s.relatedroutetype)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(s.relatedroutequalifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key

                AND LOWER(BTRIM(s.inventorydirection)) = 'd'
            ) AS staging_d_count,

            ARRAY_AGG(
                DISTINCT BTRIM(s.routeidentifier)
                ORDER BY BTRIM(s.routeidentifier)
            ) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(s.relatedroutetype)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(s.relatedroutequalifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS staging_route_identifiers

        FROM staging.state_route_lrs s

        WHERE BTRIM(s.stateroutenumber::text)
            = k.state_route_number_key

    ) s ON TRUE

    LEFT JOIN LATERAL (

        SELECT

            COUNT(*) AS route_number_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(r.related_route_type)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key
            ) AS route_type_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(r.related_route_type)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(r.related_route_qualifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS route_key_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(r.related_route_type)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(r.related_route_qualifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key

                AND LOWER(BTRIM(r.inventory_direction)) = 'i'
            ) AS ref_i_count,

            COUNT(*) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(r.related_route_type)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(r.related_route_qualifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key

                AND LOWER(BTRIM(r.inventory_direction)) = 'd'
            ) AS ref_d_count,

            ARRAY_AGG(
                DISTINCT r.route_identifier
                ORDER BY r.route_identifier
            ) FILTER (
                WHERE NULLIF(
                    UPPER(BTRIM(r.related_route_type)),
                    ''
                ) IS NOT DISTINCT FROM k.related_type_key

                AND NULLIF(
                    UPPER(BTRIM(r.related_route_qualifier)),
                    ''
                ) IS NOT DISTINCT FROM k.related_qualifier_key
            ) AS ref_route_identifiers

        FROM ref.state_route_lrs r

        WHERE BTRIM(r.state_route_number::text)
            = k.state_route_number_key

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

        WHEN project_direction_key = 'I'
             AND ref_i_count = 0
            THEN 'Increasing route direction absent from ref'

        WHEN project_direction_key = 'D'
             AND ref_d_count = 0
            THEN 'Decreasing route direction absent from ref'

        WHEN project_direction_key = 'B'
             AND ref_i_count = 0
             AND ref_d_count = 0
            THEN 'Both route directions absent from ref'

        WHEN project_direction_key = 'B'
             AND (
                 ref_i_count = 0
                 OR ref_d_count = 0
             )
            THEN 'Partial bidirectional coverage in ref'

        ELSE 'Reference key exists - investigate matching logic'

    END AS coverage_gap_status

FROM coverage

ORDER BY
    project_count DESC,
    state_route_number_key,
    related_type_key,
    related_qualifier_key;

-- Missing project's values
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

-- Missing routes
WITH missing_keys AS (

    SELECT DISTINCT
        stateroutenumber,

        NULLIF(
            UPPER(BTRIM(project_related_route_type)),
            ''
        ) AS related_route_type,

        NULLIF(
            UPPER(BTRIM(project_related_route_qualifier)),
            ''
        ) AS related_route_qualifier

    FROM analysis.dig_once_lrs_candidates

    WHERE lrs_status = 'No route match'
)

SELECT
    COUNT(*) AS distinct_missing_route_combinations,

    COUNT(DISTINCT stateroutenumber)
        AS distinct_state_route_numbers,

    COUNT(*) FILTER (
        WHERE related_route_type IS NULL
    ) AS missing_mainline_combinations,

    COUNT(*) FILTER (
        WHERE related_route_type IS NOT NULL
    ) AS missing_related_route_combinations

FROM missing_keys;

-- Final representation of missing projects relationship
SELECT
    coverage_gap_status,

    COUNT(*) AS missing_route_combinations,

    SUM(project_count) AS affected_projects,

    ROUND(
        100.0 * SUM(project_count)
        / NULLIF(
            SUM(SUM(project_count)) OVER (),
            0
        ),
        2
    ) AS percent_of_unmatched_projects

FROM qa.dig_once_lrs_coverage_gaps

GROUP BY coverage_gap_status

ORDER BY affected_projects DESC;