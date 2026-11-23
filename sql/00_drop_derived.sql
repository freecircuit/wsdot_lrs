-- Create Schemas
CREATE SCHEMA IF NOT EXISTS qa; 
CREATE SCHEMA IF NOT EXISTS analysis;

-- Dig Once analysis dependencies
DROP VIEW IF EXISTS qa.dig_once_lrs_coverage_gaps;
DROP VIEW IF EXISTS qa.dig_once_lrs_review;
DROP MATERIALIZED VIEW IF EXISTS analysis.dig_once_lrs;
DROP VIEW IF EXISTS analysis.dig_once_lrs_candidates;


-- Bridge/tunnel downstream dependencies
DROP VIEW IF EXISTS qa.bt_pub;
DROP MATERIALIZED VIEW IF EXISTS qa.bt_crab_evw;
DROP MATERIALIZED VIEW IF EXISTS qa.bt_pub_rd_evw;

-- ARM discrepancy downstream views
DROP VIEW IF EXISTS qa.vw_bt_arm_sensitivity;
DROP VIEW IF EXISTS qa.bt_arm_discrepancy;
DROP VIEW IF EXISTS qa.bt_arm_001;
DROP VIEW IF EXISTS qa.bt_arm_005;
DROP VIEW IF EXISTS qa.bt_arm_01;
DROP VIEW IF EXISTS qa.vw_bt_arm;

-- Primary bridge/tunnel materialized view
DROP MATERIALIZED VIEW IF EXISTS qa.sr_bridge_tunnel_evw;

-- ARM descrepancy views
DROP VIEW IF EXISTS qa.bt_arm_001;
DROP VIEW IF EXISTS qa.bt_arm_005;
DROP VIEW IF EXISTS qa.bt_arm_01;
DROP VIEW IF EXISTS qa.vw_bt_arm_sensitivity;
DROP VIEW IF EXISTS qa.bt_arm_descrepancy;
DROP VIEW IF EXISTS qa.vw_bt_arm;

-- Primary bridge/tunnel materialized view
DROP MATERIALIZED VIEW IF EXISTS qa.sr_bridge_tunnel_evw;

-- Base project-filtering view
DROP VIEW IF EXISTS analysis.dig_once;