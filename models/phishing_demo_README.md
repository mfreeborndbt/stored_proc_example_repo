# Phishing Simulation Demo - dbt Project

## Overview
This dbt project analyzes phishing simulation data from Q3 2025, tracking employee behavior, risk levels, and training completion rates. The data includes Proofpoint phishing simulation events, workforce roster information, and training assignments/completions.

## Project Structure

### 📁 Seeds (Raw Data)
Located in: `seeds/`
- **raw_proofpoint_events.csv** - Phishing simulation events (361 records)
- **raw_workforce.csv** - Employee roster snapshot as of 2025-09-30 (121 employees)
- **raw_training.csv** - Training assignments and completions (32 records)

### 📁 Staging Layer
Located in: `models/staging/phishing_demo/`

**Purpose:** Clean and standardize raw data with minimal transformation.

**Models:**
- `stg_proofpoint_events` - Cleaned event data with proper data types and derived date fields
- `stg_workforce` - Cleaned employee roster data
- `stg_training` - Cleaned training data with derived completion metrics

**Key Features:**
- Data type casting (timestamps, dates)
- Derived fields (event_date, event_month, is_completed, completed_on_time)
- Comprehensive data quality tests on all critical fields

### 📁 Intermediate Layer
Located in: `models/intermediate/phishing_demo/`

**Purpose:** Business logic and data consolidation.

**Models:**
1. **int_events_consolidated**
   - Consolidates multiple events per employee per campaign to a single "worst action"
   - Event severity ranking: DATA_SUBMISSION (1-worst) → EMAIL_CLICK (2) → EMAIL_VIEW (3) → REPORTED (4) → NO_ACTION (5-best)
   - Creates flags for each event type occurrence
   - Tracks first and last event timestamps

2. **int_employee_campaign_behavior**
   - Joins consolidated events with workforce data
   - Adds training information for employees who clicked
   - Calculates risk levels (Critical, High, Medium, Low)
   - Identifies "clickers" (employees who clicked or submitted data)

### 📁 Marts Layer
Located in: `models/marts/phishing_demo/`

**Purpose:** Analytics-ready fact tables optimized for reporting.

**Models:**
1. **fct_employee_campaign_events** (FACT TABLE)
   - Grain: One row per employee per campaign
   - Contains complete employee, event, and training information
   - Risk assessment and training status categorization
   - Primary table for employee-level analysis

2. **fct_campaign_summary** (AGGREGATE TABLE)
   - Grain: One row per campaign
   - Campaign-level metrics: click rates, report rates, risk distribution
   - Training completion rates for clickers
   - Perfect for campaign performance dashboards

3. **fct_business_unit_summary** (AGGREGATE TABLE)
   - Grain: One row per business unit per month
   - Business unit performance metrics
   - Identifies which BUs have the highest risk exposure
   - Useful for executive reporting

## Data Quality Tests

### Standard Tests (via schema.yml)
- **not_null** - Applied to all critical fields (IDs, timestamps, required attributes)
- **unique** - Applied to primary keys (pernr in workforce)
- **accepted_values** - Applied to categorical fields (event_type, business_unit, risk_level, etc.)
- **relationships** - Foreign key validation between tables
- **unique_combination_of_columns** - Composite uniqueness tests

### Custom Tests (via tests/ directory)
1. **test_training_date_logic.sql**
   - Validates that due_date >= assigned_date
   - Validates that completion_date >= assigned_date (when not null)

2. **test_q3_campaign_coverage.sql**
   - Ensures continuous month coverage for Q3 2025 (July, August, September)
   - Alerts if any month is missing campaigns

3. **test_duplicate_event_ids.sql** (Informational)
   - Documents intentional duplicate event_ids in the dataset
   - Used for data quality testing demonstrations

4. **test_null_emails.sql** (Informational)
   - Documents intentional null email values in the dataset
   - Used for data quality testing demonstrations

## Key Metrics & KPIs

### Employee-Level Metrics
- Risk level (Critical/High/Medium/Low)
- Click behavior (is_clicker flag)
- Training completion status
- Event type distribution

### Campaign-Level Metrics
- Click rate % (employees who clicked / total targeted)
- Report rate % (employees who reported / total targeted)
- Risk distribution (Critical/High/Medium/Low counts)
- Training completion rate for clickers

### Business Unit Metrics
- Unique clickers per BU
- Average event severity rank
- Click rate by BU
- Report rate by BU

## Data Lineage

```
Seeds (RAW schema)
    ├── raw_proofpoint_events ─┐
    ├── raw_workforce ─────────┼─→ Staging Layer (STAGING schema)
    └── raw_training ──────────┘       │
                                       ├── stg_proofpoint_events ─┐
                                       ├── stg_workforce ─────────┼─→ Intermediate Layer (INTERMEDIATE schema)
                                       └── stg_training ──────────┘       │
                                                                          ├── int_events_consolidated ─┐
                                                                          └── int_employee_campaign_behavior ─┐
                                                                                                              │
                                                                                                              └─→ Marts Layer (MARTS schema)
                                                                                                                      ├── fct_employee_campaign_events
                                                                                                                      ├── fct_campaign_summary
                                                                                                                      └── fct_business_unit_summary
```

## Usage

### Running the Project

```bash
# Load seed data
dbt seed

# Run all models
dbt run

# Run tests
dbt test

# Build everything (seeds + models + tests)
dbt build
```

### Running Specific Layers

```bash
# Run only staging models
dbt run --select staging.phishing_demo.*

# Run only marts
dbt run --select marts.phishing_demo.*

# Run a specific model and its dependencies
dbt run --select +fct_employee_campaign_events
```

### Testing

```bash
# Run all tests
dbt test

# Run tests for a specific model
dbt test --select stg_proofpoint_events

# Run custom tests only
dbt test --select test_type:singular
```

## Important Notes

### Data Quirks (By Design)
The dataset intentionally includes realistic data quality issues:
1. **Duplicate event_ids** - Some events have the same event_id (testing deduplication logic)
2. **Null employee_email** - At least one record has a null email (testing null handling)
3. **Multiple events per employee** - Employees can have multiple event types per campaign (testing consolidation logic)

### Event Consolidation Logic
When an employee has multiple events for the same campaign, we select the "worst" action:
1. DATA_SUBMISSION (highest risk)
2. EMAIL_CLICK
3. EMAIL_VIEW
4. REPORTED (good behavior)
5. NO_ACTION (neutral)

### Time Period
- Campaign Period: Q3 2025 (July 1 - September 30, 2025)
- Three simulated campaigns: CAMP-2025Q3-01, CAMP-2025Q3-02, CAMP-2025Q3-03
- Workforce snapshot: 2025-09-30

## Future Enhancements
- Add trend analysis (month-over-month improvements)
- Department-level risk scoring
- Manager rollup views
- Repeat offender identification
- Training effectiveness analysis

