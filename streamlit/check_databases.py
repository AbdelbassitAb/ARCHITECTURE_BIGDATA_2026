"""
Check which database has the ML tables
"""
import snowflake.connector
import toml
import os

# Load secrets
secrets_path = os.path.join(os.path.dirname(__file__), '.streamlit', 'secrets.toml')
with open(secrets_path, 'r') as f:
    secrets = toml.load(f)

cfg = secrets['snowflake']

# Connect
conn = snowflake.connector.connect(
    account=cfg['account'],
    user=cfg['user'],
    password=cfg['password'],
    warehouse=cfg['warehouse'],
    role=cfg.get('role', 'SYSADMIN')
)

cursor = conn.cursor()

print("=" * 70)
print("CHECKING FOR ML TABLES IN BOTH DATABASES")
print("=" * 70)

# Check ANYCOMPANY_DB
print("\n1. Checking ANYCOMPANY_DB.ANALYTICS...")
try:
    cursor.execute("USE DATABASE ANYCOMPANY_DB")
    cursor.execute("USE SCHEMA ANALYTICS")
    cursor.execute("SELECT COUNT(*) FROM ML_PROMO_EFFECTIVENESS")
    result = cursor.fetchone()
    print(f"   ✅ Found ML_PROMO_EFFECTIVENESS with {result[0]} records")
    print(f"   ✅ Database: ANYCOMPANY_DB.ANALYTICS")
except Exception as e:
    print(f"   ❌ Not found in ANYCOMPANY_DB.ANALYTICS")
    print(f"   Error: {str(e)[:100]}")

# Check ANYCOMPANY_LAB
print("\n2. Checking ANYCOMPANY_LAB.ANALYTICS...")
try:
    cursor.execute("USE DATABASE ANYCOMPANY_LAB")
    cursor.execute("USE SCHEMA ANALYTICS")
    cursor.execute("SELECT COUNT(*) FROM ML_PROMO_EFFECTIVENESS")
    result = cursor.fetchone()
    print(f"   ✅ Found ML_PROMO_EFFECTIVENESS with {result[0]} records")
    print(f"   ✅ Database: ANYCOMPANY_LAB.ANALYTICS")
except Exception as e:
    print(f"   ❌ Not found in ANYCOMPANY_LAB.ANALYTICS")
    print(f"   Error: {str(e)[:100]}")

# Check which schemas exist in ANYCOMPANY_LAB
print("\n3. Checking schemas in ANYCOMPANY_LAB...")
try:
    cursor.execute("USE DATABASE ANYCOMPANY_LAB")
    cursor.execute("SHOW SCHEMAS")
    schemas = cursor.fetchall()
    print(f"   Available schemas:")
    for schema in schemas:
        print(f"   - {schema[1]}")
except Exception as e:
    print(f"   Error: {e}")

# Check if SILVER tables exist
print("\n4. Checking SILVER tables (needed for ML features)...")
try:
    cursor.execute("USE DATABASE ANYCOMPANY_LAB")
    cursor.execute("USE SCHEMA SILVER")
    tables = ['PROMOTIONS', 'TRANSACTIONS', 'CAMPAIGNS']
    for table in tables:
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table}")
            result = cursor.fetchone()
            print(f"   ✅ {table}: {result[0]} records")
        except:
            print(f"   ❌ {table}: Not found")
except Exception as e:
    print(f"   Error: {e}")

print("\n" + "=" * 70)
print("RECOMMENDATION:")
print("=" * 70)
print("\nYour secrets.toml points to: ANYCOMPANY_LAB")
print("The SQL script creates tables in: ANYCOMPANY_DB")
print("\nOption 1: Re-run SQL in ANYCOMPANY_LAB database")
print("   - Change line 7 in 2_ml_feature_tables.sql to:")
print("   - USE DATABASE ANYCOMPANY_LAB;")
print("\nOption 2: Update secrets.toml to use ANYCOMPANY_DB")
print("   - Change database = \"ANYCOMPANY_LAB\" to \"ANYCOMPANY_DB\"")

conn.close()
