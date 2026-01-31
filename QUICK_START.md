# 🚀 QUICK START - 2 Steps to Launch ML Promo Planner

## ⏰ Total Time: 5 minutes

---

## ✅ STEP 1: Create ML Tables in Snowflake (2 minutes)

### Instructions:

1. **Open Snowflake** in your browser:
   - URL: https://app.snowflake.com
   - Log in with your credentials from `streamlit/.streamlit/secrets.toml`

2. **Open a new SQL Worksheet:**
   - Click "+ Worksheet" in top right
   - Or use existing worksheet

3. **Set context:**
   ```sql
   USE DATABASE ANYCOMPANY_DB;
   USE SCHEMA ANALYTICS;
   USE WAREHOUSE WH_LAB;
   ```

4. **Copy the SQL file:**
   - Open file: `sql/phase_3/2_ml_feature_tables.sql`
   - Select ALL content (Ctrl+A)
   - Copy (Ctrl+C)

5. **Paste and execute:**
   - Paste in Snowflake worksheet (Ctrl+V)
   - Click "Run All" button (or press Ctrl+Enter multiple times)
   - Wait ~30 seconds

6. **Verify success:**
   ```sql
   -- Should return 50+ rows
   SELECT COUNT(*) FROM ANALYTICS.ML_PROMO_EFFECTIVENESS;
   
   -- Should return 1000+ rows
   SELECT COUNT(*) FROM ANALYTICS.ML_SALES_FORECAST_FEATURES;
   ```

✅ **Step 1 Complete!** Tables created successfully.

---

## ✅ STEP 2: Train ML Models (2 minutes)

### Instructions:

1. **Open PowerShell** (new terminal window)

2. **Navigate to project directory:**
   ```powershell
   cd C:\Users\masis.zovikoglu\ARCHITECTURE_BIGDATA_2026
   ```

3. **Run training script:**
   ```powershell
   python streamlit/ml_models/promo_optimizer.py
   ```

4. **Wait for completion (~2 minutes)**
   
   You should see:
   ```
   ======================================================================
   PROMO ROI OPTIMIZER - MODEL TRAINING
   ======================================================================
   
   1. Loading training data from Snowflake...
   Loaded XXX promotion records
   
   2. Preparing features...
   
   3. Training classification model...
   Train Accuracy: 0.XXX
   Test Accuracy: 0.XXX
   
   4. Training regression model...
   Train R² Score: 0.XXX
   Test R² Score: 0.XXX
   
   5. Saving models...
   ✓ Classifier saved to: ...
   ✓ Regressor saved to: ...
   ✓ Label encoders saved to: ...
   
   ======================================================================
   TRAINING COMPLETE!
   ======================================================================
   ```

✅ **Step 2 Complete!** Models trained and saved.

---

## ✅ STEP 3: Test in Streamlit (1 minute)

### Instructions:

1. **Refresh Streamlit page in browser:**
   - Go to: http://localhost:8502/7_Promo_Planner
   - Press F5 to refresh

2. **You should now see:**
   - ✅ "ML models loaded successfully!" (green message)
   - Input form in sidebar
   - No more "Models not trained" error

3. **Make a test prediction:**
   - Fill in the form:
     - Category: Beverages
     - Subcategory: Soft Drinks
     - Type: Percentage Off
     - Region: North America
     - Discount: 20%
     - Duration: 7 days
   - Click "🔮 Predict ROI"
   - Should see predictions appear!

🎉 **SUCCESS!** ML Promo Planner is ready to use!

---

## 🆘 Troubleshooting

### Issue: SQL script fails in Snowflake

**Check:**
- Are you connected to ANYCOMPANY_DB?
- Does ANALYTICS schema exist?
- Do SILVER tables exist (PROMOTIONS, TRANSACTIONS, CAMPAIGNS)?

**Solution:**
```sql
-- Verify you're in right place
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();

-- Check if SILVER tables exist
SHOW TABLES IN SCHEMA SILVER;
```

---

### Issue: Training script fails "No module named sklearn"

**Solution:**
```powershell
python -m pip install scikit-learn
```

---

### Issue: Training script fails "No secrets found"

**Check:**
- Does file exist? `streamlit/.streamlit/secrets.toml`
- Does it have [snowflake] section with account, user, password?

**Solution:**
Run from correct directory:
```powershell
cd C:\Users\masis.zovikoglu\ARCHITECTURE_BIGDATA_2026
python streamlit/ml_models/promo_optimizer.py
```

---

### Issue: Streamlit still shows "Models not trained"

**Solution:**
1. Check files exist:
   - `streamlit/ml_models/saved_models/promo_classifier.pkl`
   - `streamlit/ml_models/saved_models/promo_regressor.pkl`
   - `streamlit/ml_models/saved_models/label_encoders.pkl`

2. If missing, re-run Step 2 (training script)

3. Hard refresh browser: Ctrl+Shift+R

---

## 📞 Need Help?

- **Full documentation**: `ML_IMPLEMENTATION_README.md`
- **Architecture diagram**: `ARCHITECTURE_DIAGRAM.md`
- **Deployment checklist**: `DEPLOYMENT_CHECKLIST.md`

---

## ✅ Checklist

- [ ] Step 1: SQL tables created in Snowflake
- [ ] Step 2: ML models trained and saved
- [ ] Step 3: Streamlit page shows "models loaded successfully"
- [ ] Step 4: Test prediction works

**Status:** Ready! 🚀
