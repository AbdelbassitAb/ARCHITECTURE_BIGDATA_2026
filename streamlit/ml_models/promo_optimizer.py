"""
Promo ROI Optimizer - ML Model Training
Purpose: Predict promotion effectiveness and ROI
Created: 2026-01-31
"""

import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, mean_absolute_error, r2_score
import pickle
import sys
import os
import snowflake.connector
import toml

def get_snowflake_connection():
    """Get Snowflake connection without Streamlit context"""
    # Try to find secrets.toml
    possible_paths = [
        os.path.join(os.path.dirname(__file__), '..', '.streamlit', 'secrets.toml'),
        os.path.join(os.path.expanduser('~'), '.streamlit', 'secrets.toml'),
    ]
    
    secrets = None
    for path in possible_paths:
        if os.path.exists(path):
            with open(path, 'r') as f:
                secrets = toml.load(f)
            break
    
    if not secrets or 'snowflake' not in secrets:
        raise Exception(f"Could not find secrets.toml with [snowflake] section. Tried: {possible_paths}")
    
    cfg = secrets['snowflake']
    
    return snowflake.connector.connect(
        account=cfg['account'],
        user=cfg['user'],
        password=cfg['password'],
        warehouse=cfg['warehouse'],
        database=cfg['database'],
        schema=cfg['schema']
    )

def run_query_standalone(query):
    """Run query without Streamlit caching"""
    conn = get_snowflake_connection()
    try:
        df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

def load_training_data():
    """Load ML features from Snowflake"""
    query = """
    SELECT 
        -- Features
        PRODUCT_CATEGORY,
        DISCOUNT_PERCENTAGE,
        PROMOTION_TYPE,
        REGION,
        DURATION_DAYS,
        BASELINE_AVG_TRANSACTION,
        BASELINE_DAILY_TRANSACTIONS,
        BASELINE_DAILY_SALES,
        HAS_CAMPAIGN_OVERLAP,
        NUM_OVERLAPPING_CAMPAIGNS,
        START_MONTH,
        START_QUARTER,
        START_DAY_OF_WEEK,
        IS_HOLIDAY_SEASON,
        STARTS_ON_WEEKEND,
        
        -- Targets
        IS_SUCCESSFUL,
        SALES_LIFT_RATIO,
        ROI_PROXY
        
    FROM ANALYTICS.ML_PROMO_EFFECTIVENESS
    WHERE BASELINE_DAILY_SALES > 0  -- Filter out promos without baseline
    """
    
    try:
        df = run_query_standalone(query)
        print(f"Loaded {len(df)} promotion records")
        return df
    except Exception as e:
        if 'does not exist' in str(e):
            print("\n" + "=" * 70)
            print("❌ ERROR: ML_PROMO_EFFECTIVENESS table not found!")
            print("=" * 70)
            print("\nYou need to create the ML feature tables first.")
            print("\n📋 STEP 1: Execute SQL in Snowflake")
            print("-" * 70)
            print("1. Open Snowflake Web UI: https://app.snowflake.com")
            print("2. Open a new SQL worksheet")
            print("3. Copy the entire contents of:")
            print("   sql/phase_3/2_ml_feature_tables.sql")
            print("4. Paste and click 'Run All'")
            print("5. Wait ~30 seconds for completion")
            print("6. Run this training script again")
            print("\n" + "=" * 70)
            raise SystemExit(1)
        else:
            raise

def prepare_features(df):
    """Encode categorical features and prepare X, y"""
    
    # Make a copy to avoid modifying original
    df = df.copy()
    
    # Clean data: remove rows with NaN or infinite values in targets
    print(f"Initial records: {len(df)}")
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.dropna(subset=['SALES_LIFT_RATIO', 'IS_SUCCESSFUL'])
    print(f"After removing NaN/inf: {len(df)}")
    
    if len(df) < 10:
        raise ValueError(f"Not enough data after cleaning. Only {len(df)} records remaining.")
    
    # Encode categorical variables
    categorical_cols = ['PRODUCT_CATEGORY', 'PROMOTION_TYPE', 'REGION']
    label_encoders = {}
    
    for col in categorical_cols:
        le = LabelEncoder()
        df[col + '_ENCODED'] = le.fit_transform(df[col].astype(str))
        label_encoders[col] = le
    
    # Select feature columns
    feature_cols = [
        'PRODUCT_CATEGORY_ENCODED',
        'DISCOUNT_PERCENTAGE',
        'PROMOTION_TYPE_ENCODED',
        'REGION_ENCODED',
        'DURATION_DAYS',
        'BASELINE_AVG_TRANSACTION',
        'BASELINE_DAILY_TRANSACTIONS',
        'BASELINE_DAILY_SALES',
        'HAS_CAMPAIGN_OVERLAP',
        'NUM_OVERLAPPING_CAMPAIGNS',
        'START_MONTH',
        'START_QUARTER',
        'START_DAY_OF_WEEK',
        'IS_HOLIDAY_SEASON',
        'STARTS_ON_WEEKEND'
    ]
    
    X = df[feature_cols]
    y_classification = df['IS_SUCCESSFUL']
    y_regression = df['SALES_LIFT_RATIO']
    
    # Clip extreme values in regression target
    y_regression = y_regression.clip(-10, 100)  # Limit to reasonable range
    
    return X, y_classification, y_regression, label_encoders

def train_classification_model(X, y):
    """Train binary classifier: Will promo be successful?"""
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print("\n=== Training Classification Model (Success Prediction) ===")
    print(f"Training set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    print(f"Positive class (successful): {y_train.sum()} ({y_train.mean():.1%})")
    
    # Train Gradient Boosting Classifier
    clf = GradientBoostingClassifier(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=4,
        random_state=42
    )
    
    clf.fit(X_train, y_train)
    
    # Evaluate
    train_score = clf.score(X_train, y_train)
    test_score = clf.score(X_test, y_test)
    
    print(f"\nTrain Accuracy: {train_score:.3f}")
    print(f"Test Accuracy: {test_score:.3f}")
    
    # Cross-validation
    cv_scores = cross_val_score(clf, X_train, y_train, cv=5)
    print(f"Cross-Val Accuracy: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})")
    
    # Detailed test set metrics
    y_pred = clf.predict(X_test)
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=['Unsuccessful', 'Successful']))
    
    # Feature importance
    feature_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': clf.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print("\nTop 5 Most Important Features:")
    print(feature_importance.head())
    
    return clf, X_test, y_test

def train_regression_model(X, y):
    """Train regressor: Predict sales lift ratio"""
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    print("\n\n=== Training Regression Model (Sales Lift Prediction) ===")
    print(f"Training set: {len(X_train)} samples")
    print(f"Test set: {len(X_test)} samples")
    print(f"Mean sales lift: {y_train.mean():.3f}")
    
    # Train Gradient Boosting Regressor
    reg = GradientBoostingRegressor(
        n_estimators=100,
        learning_rate=0.1,
        max_depth=4,
        random_state=42
    )
    
    reg.fit(X_train, y_train)
    
    # Evaluate
    train_score = reg.score(X_train, y_train)
    test_score = reg.score(X_test, y_test)
    
    y_pred = reg.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    
    print(f"\nTrain R² Score: {train_score:.3f}")
    print(f"Test R² Score: {test_score:.3f}")
    print(f"Mean Absolute Error: {mae:.3f}")
    
    # Cross-validation
    cv_scores = cross_val_score(reg, X_train, y_train, cv=5, scoring='r2')
    print(f"Cross-Val R² Score: {cv_scores.mean():.3f} (+/- {cv_scores.std():.3f})")
    
    # Feature importance
    feature_importance = pd.DataFrame({
        'feature': X.columns,
        'importance': reg.feature_importances_
    }).sort_values('importance', ascending=False)
    
    print("\nTop 5 Most Important Features:")
    print(feature_importance.head())
    
    return reg, X_test, y_test

def save_models(clf, reg, label_encoders):
    """Save trained models and encoders"""
    
    model_dir = os.path.join(os.path.dirname(__file__), 'saved_models')
    os.makedirs(model_dir, exist_ok=True)
    
    # Save classifier
    clf_path = os.path.join(model_dir, 'promo_classifier.pkl')
    with open(clf_path, 'wb') as f:
        pickle.dump(clf, f)
    print(f"\n✓ Classifier saved to: {clf_path}")
    
    # Save regressor
    reg_path = os.path.join(model_dir, 'promo_regressor.pkl')
    with open(reg_path, 'wb') as f:
        pickle.dump(reg, f)
    print(f"✓ Regressor saved to: {reg_path}")
    
    # Save label encoders
    le_path = os.path.join(model_dir, 'label_encoders.pkl')
    with open(le_path, 'wb') as f:
        pickle.dump(label_encoders, f)
    print(f"✓ Label encoders saved to: {le_path}")

def main():
    """Main training pipeline"""
    
    print("=" * 70)
    print("PROMO ROI OPTIMIZER - MODEL TRAINING")
    print("=" * 70)
    
    # Load data
    print("\n1. Loading training data from Snowflake...")
    df = load_training_data()
    
    # Prepare features
    print("\n2. Preparing features...")
    X, y_clf, y_reg, label_encoders = prepare_features(df)
    
    # Train classification model
    print("\n3. Training classification model...")
    clf, X_test_clf, y_test_clf = train_classification_model(X, y_clf)
    
    # Train regression model
    print("\n4. Training regression model...")
    reg, X_test_reg, y_test_reg = train_regression_model(X, y_reg)
    
    # Save models
    print("\n5. Saving models...")
    save_models(clf, reg, label_encoders)
    
    print("\n" + "=" * 70)
    print("TRAINING COMPLETE!")
    print("=" * 70)
    print("\nNext steps:")
    print("1. Run the Streamlit app: streamlit run Home.py")
    print("2. Navigate to 'Promo Planner' page")
    print("3. Input promo parameters to get predictions")

if __name__ == "__main__":
    main()
