-- ============================================================================
-- Stored Procedure: sp_phishing_analytics_pipeline
-- Description: Replicates the entire dbt phishing analytics pipeline logic
--              Processes raw phishing events, workforce, and training data
--              into analytical fact tables for reporting
-- 
-- Creates the following output tables:
--   - fct_employee_campaign_events (employee x campaign grain)
--   - fct_campaign_summary (campaign-level metrics)
--   - fct_business_unit_summary (business unit-level metrics)
--
-- Usage: CALL sp_phishing_analytics_pipeline();
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_phishing_analytics_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    rows_processed INT;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    result_message STRING;
BEGIN
    start_time := CURRENT_TIMESTAMP();
    
    -- ========================================================================
    -- STAGING LAYER: Clean and prepare raw data
    -- ========================================================================
    
    -- Staging: Proofpoint Events
    CREATE OR REPLACE TEMPORARY TABLE tmp_stg_proofpoint_events AS
    WITH source AS (
        SELECT * 
        FROM MILES_F_STORED_PROC_EXAMPLE.dbt_miles_freeborn_raw.raw_proofpoint_events
    ),
    cleaned AS (
        SELECT
            ingestion_run_id,
            event_id,
            event_ts::TIMESTAMP AS event_ts,
            campaign_id,
            campaign_name,
            template_name,
            employee_email,
            employee_pernr AS pernr,
            business_unit,
            event_type,
            
            -- Add useful derived fields
            event_ts::DATE AS event_date,
            DATE_TRUNC('month', event_ts::TIMESTAMP) AS event_month
            
        FROM source
    )
    SELECT * FROM cleaned;
    
    -- Staging: Training
    CREATE OR REPLACE TEMPORARY TABLE tmp_stg_training AS
    WITH source AS (
        SELECT * 
        FROM MILES_F_STORED_PROC_EXAMPLE.dbt_miles_freeborn_raw.raw_training
    ),
    cleaned AS (
        SELECT
            pernr,
            learning_content,
            assigned_date::DATE AS assigned_date,
            due_date::DATE AS due_date,
            completion_date::DATE AS completion_date,
            
            -- Derived fields
            CASE 
                WHEN completion_date IS NOT NULL THEN 1 
                ELSE 0 
            END AS is_completed,
            
            CASE 
                WHEN completion_date IS NOT NULL AND completion_date <= due_date THEN 1
                WHEN completion_date IS NOT NULL AND completion_date > due_date THEN 0
                ELSE NULL
            END AS completed_on_time,
            
            DATEDIFF(day, assigned_date::DATE, COALESCE(completion_date::DATE, CURRENT_DATE())) AS days_to_complete
            
        FROM source
    )
    SELECT * FROM cleaned;
    
    -- Staging: Workforce
    CREATE OR REPLACE TEMPORARY TABLE tmp_stg_workforce AS
    WITH source AS (
        SELECT * 
        FROM MILES_F_STORED_PROC_EXAMPLE.dbt_miles_freeborn_raw.raw_workforce
    ),
    cleaned AS (
        SELECT
            snapshot_date::DATE AS snapshot_date,
            pernr,
            email,
            full_name,
            company_code,
            business_unit,
            department,
            title,
            employee_type,
            employment_status,
            manager_pernr,
            location
            
        FROM source
    )
    SELECT * FROM cleaned;
    
    -- ========================================================================
    -- INTERMEDIATE LAYER: Business logic and transformations
    -- ========================================================================
    
    -- Intermediate: Events Consolidated
    -- Consolidates events to one record per employee per campaign (worst action)
    CREATE OR REPLACE TEMPORARY TABLE tmp_int_events_consolidated AS
    WITH events AS (
        SELECT * FROM tmp_stg_proofpoint_events
    ),
    -- Assign severity ranking to event types (lower number = worse action)
    ranked_events AS (
        SELECT
            *,
            CASE event_type
                WHEN 'DATA_SUBMISSION' THEN 1
                WHEN 'EMAIL_CLICK' THEN 2
                WHEN 'EMAIL_VIEW' THEN 3
                WHEN 'REPORTED' THEN 4
                WHEN 'NO_ACTION' THEN 5
                ELSE 99
            END AS event_severity_rank,
            
            ROW_NUMBER() OVER (
                PARTITION BY pernr, campaign_id 
                ORDER BY 
                    CASE event_type
                        WHEN 'DATA_SUBMISSION' THEN 1
                        WHEN 'EMAIL_CLICK' THEN 2
                        WHEN 'EMAIL_VIEW' THEN 3
                        WHEN 'REPORTED' THEN 4
                        WHEN 'NO_ACTION' THEN 5
                        ELSE 99
                    END,
                    event_ts
            ) AS event_rank
            
        FROM events
    ),
    -- Get one record per employee per campaign (worst action)
    consolidated AS (
        SELECT
            pernr,
            campaign_id,
            campaign_name,
            business_unit,
            event_type AS final_event_type,
            event_severity_rank,
            event_ts AS final_event_ts,
            event_date AS final_event_date,
            event_month,
            employee_email,
            
            -- Create flags for each event type
            MAX(CASE WHEN event_type = 'DATA_SUBMISSION' THEN 1 ELSE 0 END) AS had_data_submission,
            MAX(CASE WHEN event_type = 'EMAIL_CLICK' THEN 1 ELSE 0 END) AS had_email_click,
            MAX(CASE WHEN event_type = 'EMAIL_VIEW' THEN 1 ELSE 0 END) AS had_email_view,
            MAX(CASE WHEN event_type = 'REPORTED' THEN 1 ELSE 0 END) AS had_reported,
            MAX(CASE WHEN event_type = 'NO_ACTION' THEN 1 ELSE 0 END) AS had_no_action,
            
            -- Count total events per person per campaign
            COUNT(*) AS total_event_count,
            MIN(event_ts) AS first_event_ts,
            MAX(event_ts) AS last_event_ts
            
        FROM ranked_events
        WHERE event_rank = 1
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
    )
    SELECT * FROM consolidated;
    
    -- Intermediate: Employee Campaign Behavior
    -- Joins events with workforce and training data
    CREATE OR REPLACE TEMPORARY TABLE tmp_int_employee_campaign_behavior AS
    WITH consolidated_events AS (
        SELECT * FROM tmp_int_events_consolidated
    ),
    workforce AS (
        SELECT * FROM tmp_stg_workforce
    ),
    training AS (
        SELECT * FROM tmp_stg_training
    ),
    -- Join events with employee data
    events_with_employees AS (
        SELECT
            e.pernr,
            e.campaign_id,
            e.campaign_name,
            e.event_month,
            e.final_event_type,
            e.event_severity_rank,
            e.final_event_ts,
            e.final_event_date,
            e.had_data_submission,
            e.had_email_click,
            e.had_email_view,
            e.had_reported,
            e.had_no_action,
            e.total_event_count,
            e.first_event_ts,
            e.last_event_ts,
            
            -- Employee attributes
            w.full_name,
            w.email AS employee_email,
            w.business_unit,
            w.department,
            w.title,
            w.employee_type,
            w.employment_status,
            w.location,
            w.manager_pernr,
            
            -- Categorize risk level based on final event
            CASE 
                WHEN e.final_event_type = 'DATA_SUBMISSION' THEN 'Critical'
                WHEN e.final_event_type = 'EMAIL_CLICK' THEN 'High'
                WHEN e.final_event_type = 'EMAIL_VIEW' THEN 'Medium'
                WHEN e.final_event_type = 'REPORTED' THEN 'Low'
                WHEN e.final_event_type = 'NO_ACTION' THEN 'Low'
                ELSE 'Unknown'
            END AS risk_level,
            
            -- Flag for "clickers" (anyone who clicked or submitted data)
            CASE 
                WHEN e.final_event_type IN ('EMAIL_CLICK', 'DATA_SUBMISSION') THEN 1 
                ELSE 0 
            END AS is_clicker
            
        FROM consolidated_events e
        LEFT JOIN workforce w
            ON e.pernr = w.pernr
    ),
    -- Add training information for clickers
    final AS (
        SELECT
            e.*,
            t.learning_content,
            t.assigned_date AS training_assigned_date,
            t.due_date AS training_due_date,
            t.completion_date AS training_completion_date,
            t.is_completed AS training_completed,
            t.completed_on_time AS training_completed_on_time,
            t.days_to_complete AS training_days_to_complete
            
        FROM events_with_employees e
        LEFT JOIN training t
            ON e.pernr = t.pernr
            AND t.learning_content = 'Simulated Phishing Awareness 2025Q3'
    )
    SELECT * FROM final;
    
    -- ========================================================================
    -- MARTS LAYER: Final analytical fact tables
    -- ========================================================================
    
    -- Fact: Employee Campaign Events (employee x campaign grain)
    CREATE OR REPLACE TABLE MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events AS
    WITH employee_campaign_behavior AS (
        SELECT * FROM tmp_int_employee_campaign_behavior
    ),
    final AS (
        SELECT
            -- Keys
            pernr,
            campaign_id,
            campaign_name,
            event_month,
            
            -- Event details
            final_event_type,
            event_severity_rank,
            final_event_ts,
            final_event_date,
            
            -- Event flags
            had_data_submission,
            had_email_click,
            had_email_view,
            had_reported,
            had_no_action,
            total_event_count,
            first_event_ts,
            last_event_ts,
            
            -- Employee attributes
            full_name,
            employee_email,
            business_unit,
            department,
            title,
            employee_type,
            employment_status,
            location,
            manager_pernr,
            
            -- Risk assessment
            risk_level,
            is_clicker,
            
            -- Training information
            learning_content,
            training_assigned_date,
            training_due_date,
            training_completion_date,
            training_completed,
            training_completed_on_time,
            training_days_to_complete,
            
            -- Derived metrics
            DATEDIFF(second, first_event_ts, last_event_ts) AS seconds_between_first_and_last_event,
            
            CASE 
                WHEN is_clicker = 1 AND training_completed = 1 THEN 'Clicker - Trained'
                WHEN is_clicker = 1 AND training_completed = 0 THEN 'Clicker - Not Trained'
                WHEN is_clicker = 0 AND training_completed = 1 THEN 'Non-Clicker - Trained'
                WHEN is_clicker = 0 AND training_completed = 0 THEN 'Non-Clicker - Not Trained'
                ELSE 'Unknown'
            END AS training_status_category,
            
            -- Metadata
            CURRENT_TIMESTAMP() AS loaded_at
            
        FROM employee_campaign_behavior
    )
    SELECT * FROM final;
    
    -- Fact: Campaign Summary (campaign-level metrics)
    CREATE OR REPLACE TABLE MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_campaign_summary AS
    WITH employee_events AS (
        SELECT * FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events
    ),
    campaign_metrics AS (
        SELECT
            campaign_id,
            campaign_name,
            event_month,
            
            -- Overall metrics
            COUNT(DISTINCT pernr) AS total_employees_targeted,
            COUNT(DISTINCT CASE WHEN final_event_type != 'NO_ACTION' THEN pernr END) AS employees_who_engaged,
            
            -- Event type breakdowns
            COUNT(DISTINCT CASE WHEN final_event_type = 'DATA_SUBMISSION' THEN pernr END) AS employees_data_submission,
            COUNT(DISTINCT CASE WHEN final_event_type = 'EMAIL_CLICK' THEN pernr END) AS employees_clicked,
            COUNT(DISTINCT CASE WHEN final_event_type = 'EMAIL_VIEW' THEN pernr END) AS employees_viewed,
            COUNT(DISTINCT CASE WHEN final_event_type = 'REPORTED' THEN pernr END) AS employees_reported,
            COUNT(DISTINCT CASE WHEN final_event_type = 'NO_ACTION' THEN pernr END) AS employees_no_action,
            
            -- Risk metrics
            COUNT(DISTINCT CASE WHEN is_clicker = 1 THEN pernr END) AS total_clickers,
            COUNT(DISTINCT CASE WHEN risk_level = 'Critical' THEN pernr END) AS critical_risk_count,
            COUNT(DISTINCT CASE WHEN risk_level = 'High' THEN pernr END) AS high_risk_count,
            COUNT(DISTINCT CASE WHEN risk_level = 'Medium' THEN pernr END) AS medium_risk_count,
            
            -- Training metrics for clickers
            COUNT(DISTINCT CASE WHEN is_clicker = 1 AND training_completed = 1 THEN pernr END) AS clickers_completed_training,
            COUNT(DISTINCT CASE WHEN is_clicker = 1 AND training_completed = 0 THEN pernr END) AS clickers_not_completed_training,
            
            -- Calculate rates
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_clicker = 1 THEN pernr END) / 
                NULLIF(COUNT(DISTINCT pernr), 0), 2) AS click_rate_pct,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN final_event_type = 'REPORTED' THEN pernr END) / 
                NULLIF(COUNT(DISTINCT pernr), 0), 2) AS report_rate_pct,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_clicker = 1 AND training_completed = 1 THEN pernr END) / 
                NULLIF(COUNT(DISTINCT CASE WHEN is_clicker = 1 THEN pernr END), 0), 2) AS clicker_training_completion_rate_pct,
            
            -- Metadata
            CURRENT_TIMESTAMP() AS loaded_at
            
        FROM employee_events
        GROUP BY 1, 2, 3
    )
    SELECT * FROM campaign_metrics;
    
    -- Fact: Business Unit Summary (business unit-level metrics)
    CREATE OR REPLACE TABLE MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_business_unit_summary AS
    WITH employee_events AS (
        SELECT * FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events
    ),
    bu_metrics AS (
        SELECT
            business_unit,
            event_month,
            
            -- Overall metrics
            COUNT(DISTINCT pernr) AS unique_employees,
            COUNT(DISTINCT campaign_id) AS campaigns_participated,
            COUNT(*) AS total_campaign_participations,
            
            -- Event type breakdowns
            SUM(CASE WHEN final_event_type = 'DATA_SUBMISSION' THEN 1 ELSE 0 END) AS data_submissions,
            SUM(CASE WHEN final_event_type = 'EMAIL_CLICK' THEN 1 ELSE 0 END) AS email_clicks,
            SUM(CASE WHEN final_event_type = 'EMAIL_VIEW' THEN 1 ELSE 0 END) AS email_views,
            SUM(CASE WHEN final_event_type = 'REPORTED' THEN 1 ELSE 0 END) AS emails_reported,
            SUM(CASE WHEN final_event_type = 'NO_ACTION' THEN 1 ELSE 0 END) AS no_actions,
            
            -- Risk metrics
            SUM(is_clicker) AS total_click_incidents,
            COUNT(DISTINCT CASE WHEN is_clicker = 1 THEN pernr END) AS unique_clickers,
            
            -- Calculate rates
            ROUND(100.0 * SUM(is_clicker) / NULLIF(COUNT(*), 0), 2) AS click_rate_pct,
            ROUND(100.0 * SUM(CASE WHEN final_event_type = 'REPORTED' THEN 1 ELSE 0 END) / 
                NULLIF(COUNT(*), 0), 2) AS report_rate_pct,
            
            -- Average risk score (lower is worse)
            ROUND(AVG(event_severity_rank), 2) AS avg_event_severity_rank,
            
            -- Metadata
            CURRENT_TIMESTAMP() AS loaded_at
            
        FROM employee_events
        GROUP BY 1, 2
    )
    SELECT * FROM bu_metrics;
    
    -- ========================================================================
    -- Cleanup and return results
    -- ========================================================================
    
    -- Get row counts for output message
    SELECT COUNT(*) INTO :rows_processed 
    FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events;
    
    end_time := CURRENT_TIMESTAMP();
    
    result_message := 'Pipeline completed successfully. ' ||
                     'Processed ' || rows_processed || ' employee campaign events. ' ||
                     'Duration: ' || DATEDIFF(second, start_time, end_time) || ' seconds. ' ||
                     'Tables created: fct_employee_campaign_events, fct_campaign_summary, fct_business_unit_summary';
    
    RETURN result_message;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Pipeline failed with error: ' || SQLERRM;
END;
$$;

-- ============================================================================
-- Example Usage and Verification Queries
-- ============================================================================

/*

-- Execute the stored procedure
CALL sp_phishing_analytics_pipeline();

-- Verify the results
SELECT COUNT(*) AS employee_events_count 
FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events;

SELECT * 
FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_campaign_summary 
ORDER BY click_rate_pct DESC;

SELECT * 
FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_business_unit_summary 
ORDER BY business_unit, event_month;

-- Compare with dbt models (if both exist)
SELECT 'Stored Proc' AS source, COUNT(*) AS row_count
FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events
UNION ALL
SELECT 'dbt Model' AS source, COUNT(*) AS row_count
FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS_DBT.fct_employee_campaign_events;

*/

