# ⚠️ DATABASE NAME FIX

## Issue Found
The SQL script was targeting `ANYCOMPANY_DB` but your Snowflake database is `ANYCOMPANY_LAB`.

## ✅ Fixed
I've updated the SQL script to use `ANYCOMPANY_LAB`.

## 📋 Next Steps

### Step 1: Execute Fixed SQL in Snowflake (2 min)

1. **Open Snowflake**: https://app.snowflake.com

2. **Open NEW SQL worksheet**

3. **Copy the UPDATED file**:
   - File: `sql/phase_3/2_ml_feature_tables.sql`
   - It now starts with: `USE DATABASE ANYCOMPANY_LAB;`

4. **Paste and Run All** in Snowflake

5. **Verify success**:
   ```sql
   SELECT COUNT(*) FROM ANYCOMPANY_LAB.ANALYTICS.ML_PROMO_EFFECTIVENESS;
   -- Should return 50+ rows
   ```

### Step 2: Train Models (2 min)

Once SQL completes successfully:

```powershell
python streamlit/ml_models/promo_optimizer.py
```

Should now work! ✅

---

## What Changed

**Before (wrong):**
```sql
USE DATABASE ANYCOMPANY_DB;  ❌
```

**After (correct):**
```sql
USE DATABASE ANYCOMPANY_LAB;  ✅
```

---

**Ready to go!** Copy the updated SQL file to Snowflake now. 🚀
