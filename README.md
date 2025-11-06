# Phishing Analytics Project

This project analyzes phishing simulation campaign data, including employee events, workforce information, and training completion.

## Project Structure

### dbt Models

The dbt project is organized into three layers:

1. **Staging Layer** (`models/staging/`)
   - `stg_proofpoint_events.sql` - Cleaned phishing event data
   - `stg_workforce.sql` - Employee roster data
   - `stg_training.sql` - Training assignments and completions

2. **Intermediate Layer** (`models/intermediate/`)
   - `int_events_consolidated.sql` - One record per employee per campaign (worst action)
   - `int_employee_campaign_behavior.sql` - Events joined with workforce and training

3. **Marts Layer** (`models/marts/`)
   - `fct_employee_campaign_events.sql` - Employee x campaign grain fact table
   - `fct_campaign_summary.sql` - Campaign-level metrics
   - `fct_business_unit_summary.sql` - Business unit-level metrics

### Stored Procedures

The same logic is also available as a Snowflake stored procedure:

- **`sp_phishing_analytics_pipeline.sql`** - Complete pipeline in a single stored procedure
  - Located in: `stored_procedures/sp_phishing_analytics_pipeline.sql`
  - Replicates all dbt transformations in native SQL
  - Creates the same 3 fact tables in the `ANALYTICS` schema

## Usage

### Running with dbt

```bash
# Run all models
dbt run

# Run tests
dbt test

# Run specific model
dbt run --select fct_employee_campaign_events
```

### Running with Stored Procedure

```sql
-- Deploy the stored procedure (run once)
-- Execute the SQL file in your Snowflake worksheet

-- Run the pipeline
CALL MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.sp_phishing_analytics_pipeline();

-- Query the results
SELECT * FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_employee_campaign_events LIMIT 10;
SELECT * FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_campaign_summary;
SELECT * FROM MILES_F_STORED_PROC_EXAMPLE.ANALYTICS.fct_business_unit_summary;
```

## Key Metrics

- **Click Rate**: Percentage of employees who clicked phishing links
- **Report Rate**: Percentage of employees who reported phishing attempts
- **Risk Level**: Categorized as Critical, High, Medium, or Low based on actions
- **Training Completion**: Tracks which "clickers" completed remedial training

## Data Sources

- `raw_proofpoint_events` - Phishing simulation event log
- `raw_workforce` - Employee roster and organizational data
- `raw_training` - Training assignment and completion records

## Resources

- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [dbt community](https://getdbt.com/community) to learn from other analytics engineers
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
