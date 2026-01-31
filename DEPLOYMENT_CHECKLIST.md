# ✅ ML Deployment Checklist

## Pre-Deployment Verification

### 1. Prerequisites ✓
- [x] Snowflake connection working (test with existing Streamlit pages)
- [x] Python environment configured
- [x] scikit-learn installed (`pip install scikit-learn`)
- [x] streamlit, pandas, snowflake-connector-python installed

### 2. SQL Setup (5 minutes)
- [ ] Open Snowflake Web UI
- [ ] Navigate to ANYCOMPANY_DB database
- [ ] Open new SQL worksheet
- [ ] Copy contents of `sql/phase_3/2_ml_feature_tables.sql`
- [ ] Execute entire script
- [ ] Verify tables created:
  ```sql
  SELECT COUNT(*) FROM ANALYTICS.ML_PROMO_EFFECTIVENESS;
  SELECT COUNT(*) FROM ANALYTICS.ML_SALES_FORECAST_FEATURES;
  ```
- [ ] Both queries should return positive counts (50+ promos, 1000+ days)

### 3. Model Training (2 minutes)
- [ ] Open PowerShell in project directory
- [ ] Run: `python streamlit/ml_models/promo_optimizer.py`
- [ ] Wait for completion (~2 minutes)
- [ ] Check for success messages:
  - [ ] "Loading X promotion records"
  - [ ] "Train Accuracy: 0.XXX"
  - [ ] "✓ Models saved successfully!"
- [ ] Verify files created:
  - [ ] `streamlit/ml_models/saved_models/promo_classifier.pkl`
  - [ ] `streamlit/ml_models/saved_models/promo_regressor.pkl`
  - [ ] `streamlit/ml_models/saved_models/label_encoders.pkl`

### 4. Streamlit Integration (1 minute)
- [ ] Streamlit app already running? Stop it (Ctrl+C)
- [ ] Restart: `cd streamlit; python -m streamlit run Home.py`
- [ ] Browser opens to http://localhost:8502
- [ ] Check sidebar - "7_Promo_Planner" should appear
- [ ] Click on "7_Promo_Planner"
- [ ] Should see: "✅ ML models loaded successfully!"

---

## Testing & Validation

### 5. Smoke Test (2 minutes)
**Test Case 1: High Success Scenario**
- [ ] Open Promo Planner page
- [ ] Fill in sidebar:
  - Category: Beverages
  - Subcategory: Soft Drinks
  - Type: Percentage Off
  - Region: North America
  - Discount: 25%
  - Duration: 7 days
  - Start Date: Any date in Dec 2026
  - Campaign: Yes (1 campaign)
- [ ] Click "Predict ROI"
- [ ] Expected results:
  - [ ] Success Probability: 70-85%
  - [ ] Sales Lift: +10% to +20%
  - [ ] ROI: 1.5x to 3.0x
  - [ ] Recommendation: "STRONG GO" or "OPTIMIZE"

**Test Case 2: Low Success Scenario**
- [ ] Change parameters:
  - Discount: 5%
  - Start Date: Any date in Feb 2026 (not holiday)
  - Campaign: No
- [ ] Click "Predict ROI"
- [ ] Expected results:
  - [ ] Lower success probability (<60%)
  - [ ] Lower sales lift (<10%)
  - [ ] Lower ROI
  - [ ] Different recommendation

**Test Case 3: What-If Analysis**
- [ ] Scroll to "What-If Analysis" table
- [ ] Should show 5 rows with different discount levels
- [ ] Values should vary across rows
- [ ] Higher discount ≠ always better ROI

### 6. Error Handling
- [ ] Test invalid inputs (if possible)
- [ ] Check page doesn't crash
- [ ] Error messages are user-friendly

---

## Performance Validation

### 7. Model Quality Checks
- [ ] Review training output from Step 3
- [ ] Classification accuracy > 60%? (Target: >70%)
- [ ] Regression R² > 0.5? (Target: >0.6)
- [ ] Cross-validation scores reasonable?
- [ ] Feature importance makes business sense?

### 8. Prediction Sanity Checks
- [ ] Success probabilities between 0-100%? ✓
- [ ] Sales lift values reasonable (-20% to +100%)? ✓
- [ ] ROI values positive for most cases? ✓
- [ ] Predictions change when inputs change? ✓

---

## User Acceptance Testing (UAT)

### 9. Stakeholder Demo
- [ ] Schedule demo with Marketing team
- [ ] Show live prediction with real-world scenario
- [ ] Walk through interpretation of results
- [ ] Demonstrate what-if analysis
- [ ] Collect feedback

### 10. Business Value Validation
- [ ] Can users understand predictions? 
- [ ] Are recommendations actionable?
- [ ] Does it save time vs manual analysis?
- [ ] Would they trust these predictions?

---

## Documentation

### 11. User Documentation
- [ ] `ML_IMPLEMENTATION_README.md` complete
- [ ] `SETUP_INSTRUCTIONS.txt` clear and tested
- [ ] `IMPLEMENTATION_SUMMARY.md` accurate
- [ ] `ARCHITECTURE_DIAGRAM.md` up-to-date
- [ ] In-app instructions in Promo Planner page

### 12. Technical Documentation
- [ ] SQL scripts commented
- [ ] Python code documented
- [ ] Model architecture explained
- [ ] File structure clear

---

## Production Readiness

### 13. Monitoring Setup
- [ ] Plan to track prediction accuracy
  - Log predictions to Snowflake table?
  - Compare predicted vs actual ROI monthly?
- [ ] Plan to monitor usage
  - How many predictions per week?
  - Which users most active?
- [ ] Plan to retrain models
  - Monthly with new data?
  - Automated or manual?

### 14. Backup & Recovery
- [ ] Models backed up (saved_models/ folder)
- [ ] SQL scripts in version control
- [ ] Snowflake tables have backup/recovery plan

### 15. Access Control
- [ ] Who should have access to Promo Planner?
- [ ] Snowflake permissions configured?
- [ ] Streamlit authentication needed?

---

## Launch Communication

### 16. Announcement
- [ ] Email to Marketing team
- [ ] Subject: "🚀 New AI-Powered Promo Planning Tool Available!"
- [ ] Include:
  - [ ] What it does (predict ROI before launch)
  - [ ] How to access (Streamlit URL)
  - [ ] Quick start guide link
  - [ ] Contact for questions

### 17. Training Session
- [ ] Schedule 30-min training session
- [ ] Cover:
  - [ ] How to input promo parameters
  - [ ] How to interpret predictions
  - [ ] How to use what-if analysis
  - [ ] What to do if predictions seem wrong
- [ ] Q&A time

---

## Post-Launch

### 18. First Week Monitoring
- [ ] Day 1: Check for any errors/crashes
- [ ] Day 3: Collect initial user feedback
- [ ] Day 5: Review usage stats
- [ ] Day 7: First accuracy check (if promos launched)

### 19. First Month Review
- [ ] Track KPIs:
  - [ ] Number of predictions made
  - [ ] Adoption rate (% of promos planned via tool)
  - [ ] User satisfaction scores
  - [ ] Prediction accuracy (predicted vs actual)
- [ ] Identify improvements needed
- [ ] Plan model retraining

### 20. Continuous Improvement
- [ ] Collect feedback from users
- [ ] Add new features based on requests
- [ ] Retrain models with more data
- [ ] Expand to Use Case 1 (Sales Forecasting)

---

## Sign-Off

**Deployment completed by:** _______________________

**Date:** _______________________

**Verified by:** _______________________

**Go-Live approved:** ☐ YES  ☐ NO  ☐ NEEDS FIXES

**Notes:**
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

---

## Quick Reference

**If something breaks:**
1. Check Streamlit terminal for Python errors
2. Check Snowflake query history for SQL errors
3. Review `ML_IMPLEMENTATION_README.md` troubleshooting section
4. Retrain models if predictions seem wrong
5. Contact: Data Science team

**Key Files:**
- SQL: `sql/phase_3/2_ml_feature_tables.sql`
- Training: `streamlit/ml_models/promo_optimizer.py`
- UI: `streamlit/pages/7_Promo_Planner.py`
- Docs: `ML_IMPLEMENTATION_README.md`

**URLs:**
- Streamlit: http://localhost:8502
- Promo Planner: http://localhost:8502/7_Promo_Planner
- Snowflake: https://app.snowflake.com

**Commands:**
```powershell
# Start Streamlit
cd streamlit
python -m streamlit run Home.py

# Retrain models
python streamlit/ml_models/promo_optimizer.py

# Install dependencies
pip install scikit-learn
```

---

**Status:** ☐ Not Started  ☐ In Progress  ☐ Complete  ☐ Blocked

**Overall Progress:** ___% complete
