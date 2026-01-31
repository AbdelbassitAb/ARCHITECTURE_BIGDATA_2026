"""
Quick check: Verify SQL tables exist before training
"""
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from _utils import run_query
    
    print("=" * 70)
    print("CHECKING IF SQL TABLES EXIST...")
    print("=" * 70)
    
    # Check if ML_PROMO_EFFECTIVENESS exists
    try:
        result = run_query("SELECT COUNT(*) as count FROM ANALYTICS.ML_PROMO_EFFECTIVENESS")
        promo_count = result['COUNT'].values[0]
        print(f"\n✅ ML_PROMO_EFFECTIVENESS exists with {promo_count} records")
        
        # Check if ML_SALES_FORECAST_FEATURES exists
        result2 = run_query("SELECT COUNT(*) as count FROM ANALYTICS.ML_SALES_FORECAST_FEATURES")
        forecast_count = result2['COUNT'].values[0]
        print(f"✅ ML_SALES_FORECAST_FEATURES exists with {forecast_count} records")
        
        print("\n" + "=" * 70)
        print("✅ SQL TABLES READY - You can now train the models!")
        print("=" * 70)
        print("\nRun: python streamlit/ml_models/promo_optimizer.py")
        
    except Exception as e:
        print(f"\n❌ SQL tables not found!")
        print(f"Error: {str(e)}")
        print("\n" + "=" * 70)
        print("⚠️  NEXT STEP: Execute SQL script in Snowflake")
        print("=" * 70)
        print("\n1. Open Snowflake Web UI: https://app.snowflake.com")
        print("2. Log in with your credentials")
        print("3. Open a new SQL worksheet")
        print("4. Copy and paste the entire contents of:")
        print("   sql/phase_3/2_ml_feature_tables.sql")
        print("5. Click 'Run All' (or Ctrl+Enter)")
        print("6. Wait for completion (~30 seconds)")
        print("7. Run this check script again")
        print("\n" + "=" * 70)
        
except ImportError as e:
    print(f"Error importing _utils: {e}")
    print("Make sure you're running from the project directory")
