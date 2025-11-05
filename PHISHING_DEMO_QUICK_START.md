# Phishing Demo - Quick Start Guide

## 🚀 Getting Started

### 1. Install dbt Packages
```bash
dbt deps
```

### 2. Load Seed Data
```bash
dbt seed
```

### 3. Run All Models
```bash
dbt run
```

### 4. Run Tests
```bash
dbt test
```

### 5. OR: Do Everything at Once
```bash
dbt build
```

---

## 📊 What Was Built

### Seeds (3 CSV files in RAW schema)
- ✅ `raw_proofpoint_events` - 361 phishing simulation events
- ✅ `raw_workforce` - 121 employee records
- ✅ `raw_training` - 32 training assignments

### Staging Models (3 models in STAGING schema)
- ✅ `stg_proofpoint_events` - Cleaned event data
- ✅ `stg_workforce` - Cleaned employee data  
- ✅ `stg_training` - Cleaned training data with completion metrics

### Intermediate Models (2 models in INTERMEDIATE schema)
- ✅ `int_events_consolidated` - One row per employee per campaign (worst action)
- ✅ `int_employee_campaign_behavior` - Events + workforce + training joined

### Mart Models (3 tables in MARTS schema)
- ✅ `fct_employee_campaign_events` - **Main fact table** (employee x campaign grain)
- ✅ `fct_campaign_summary` - Campaign-level metrics and KPIs
- ✅ `fct_business_unit_summary` - Business unit performance metrics

### Data Quality Tests
- ✅ **Standard tests**: 40+ tests on critical fields (not_null, unique, accepted_values, relationships)
- ✅ **Custom tests**: 4 custom validation tests
  - Training date logic validation
  - Q3 campaign coverage check
  - Duplicate event ID documentation (informational)
  - Null email documentation (informational)

---

## 🎯 Key Concepts

### Event Severity Ranking
When employees have multiple events per campaign, we consolidate to the "worst" action:
1. **DATA_SUBMISSION** (Rank 1) - Critical Risk ⚠️
2. **EMAIL_CLICK** (Rank 2) - High Risk ⚠️
3. **EMAIL_VIEW** (Rank 3) - Medium Risk
4. **REPORTED** (Rank 4) - Low Risk ✅
5. **NO_ACTION** (Rank 5) - Low Risk

### Risk Levels
- **Critical**: Submitted data to phishing site
- **High**: Clicked phishing link
- **Medium**: Viewed/opened phishing email
- **Low**: Reported email or took no action

### "Clickers"
Employees who clicked on the phishing link OR submitted data (severity rank 1-2)

---

## 📈 Key Metrics Available

### From `fct_employee_campaign_events`
- Individual employee risk levels
- Click behavior by employee
- Training completion status
- Event timelines and patterns

### From `fct_campaign_summary`
- Click rate % per campaign
- Report rate % per campaign  
- Risk distribution
- Training effectiveness for clickers

### From `fct_business_unit_summary`
- Click rates by business unit
- Unique clickers per BU
- Average risk scores by BU
- Performance trends over Q3

---

## 🗂️ Project Structure
```
stored_proc_example_repo/
├── seeds/
│   ├── raw_proofpoint_events.csv
│   ├── raw_workforce.csv
│   ├── raw_training.csv
│   └── seeds.yml
├── models/
│   ├── staging/phishing_demo/
│   │   ├── sources.yml
│   │   ├── stg_schema.yml
│   │   ├── stg_proofpoint_events.sql
│   │   ├── stg_workforce.sql
│   │   └── stg_training.sql
│   ├── intermediate/phishing_demo/
│   │   ├── int_schema.yml
│   │   ├── int_events_consolidated.sql
│   │   └── int_employee_campaign_behavior.sql
│   ├── marts/phishing_demo/
│   │   ├── marts_schema.yml
│   │   ├── fct_employee_campaign_events.sql
│   │   ├── fct_campaign_summary.sql
│   │   └── fct_business_unit_summary.sql
│   └── phishing_demo_README.md
├── tests/
│   ├── test_training_date_logic.sql
│   ├── test_q3_campaign_coverage.sql
│   ├── test_duplicate_event_ids.sql
│   └── test_null_emails.sql
├── dbt_project.yml (configured)
└── packages.yml (dbt_utils)
```

---

## 🔍 Sample Queries

### Get All Critical Risk Employees
```sql
SELECT 
    pernr,
    full_name,
    campaign_name,
    final_event_type,
    risk_level
FROM marts.fct_employee_campaign_events
WHERE risk_level = 'Critical'
ORDER BY final_event_date DESC;
```

### Campaign Performance Overview
```sql
SELECT
    campaign_name,
    total_employees_targeted,
    click_rate_pct,
    report_rate_pct,
    clicker_training_completion_rate_pct
FROM marts.fct_campaign_summary
ORDER BY click_rate_pct DESC;
```

### Business Unit Risk Ranking
```sql
SELECT
    business_unit,
    unique_clickers,
    click_rate_pct,
    avg_event_severity_rank
FROM marts.fct_business_unit_summary
ORDER BY click_rate_pct DESC;
```

### Clickers Who Haven't Completed Training
```sql
SELECT
    pernr,
    full_name,
    business_unit,
    campaign_name,
    training_assigned_date,
    training_due_date
FROM marts.fct_employee_campaign_events
WHERE is_clicker = 1
  AND training_completed = 0
ORDER BY training_due_date;
```

---

## ⚙️ Configuration Details

### Materializations
- **Staging**: Views (always fresh data from seeds)
- **Intermediate**: Views (composable business logic)
- **Marts**: Tables (optimized for analytics queries)

### Schemas
- Seeds → **RAW** schema
- Staging → **STAGING** schema  
- Intermediate → **INTERMEDIATE** schema
- Marts → **MARTS** schema

### Dependencies
- **dbt_utils** package for advanced testing (unique_combination_of_columns)

---

## 📝 Notes

### Intentional Data Quality Issues
The dataset includes realistic DQ issues for testing:
- ✓ Duplicate event_ids (some events share the same ID)
- ✓ Null employee emails (at least one record)
- ✓ Multiple events per employee per campaign

These are handled appropriately in the intermediate layer through consolidation logic.

### Time Period
- **Q3 2025**: July 1 - September 30, 2025
- **3 Campaigns**: CAMP-2025Q3-01, CAMP-2025Q3-02, CAMP-2025Q3-03
- **Workforce Snapshot**: 2025-09-30

---

## 🎓 For Demos
This project demonstrates:
- ✅ Modern dbt project structure (staging → intermediate → marts)
- ✅ Data quality testing (standard + custom tests)
- ✅ Business logic implementation (event consolidation, risk scoring)
- ✅ Comprehensive documentation
- ✅ Seed file management
- ✅ Incremental complexity (simple staging → complex marts)
- ✅ Real-world data scenarios (duplicates, nulls, many-to-many relationships)

Perfect for showing data engineering best practices! 🚀

