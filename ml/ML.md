# 🤖 Machine Learning - Customer Segmentation

## 📚 Partie 3.3 & 3.4 - Segmentation Clients avec K-Means

Ce notebook implémente un modèle de **segmentation clients** basé sur l'analyse RFM (Recency, Frequency, Monetary) et le clustering K-Means pour identifier des groupes de clients homogènes et personnaliser les stratégies marketing.

---

## 📓 Notebook: `customer_segmentation.ipynb`

### 🎯 Objectif Business
Identifier des segments de clients distincts pour:
- Optimiser l'allocation du budget marketing
- Personnaliser les offres par segment
- Améliorer la rétention et la lifetime value (LTV)
- Réduire le taux de churn des clients à risque

---

## 🔬 Méthodologie (Partie 3.3)

### 1. **Analyse RFM**
Calcul de 3 métriques clés pour chaque client:
- **Recency**: Nombre de jours depuis le dernier achat
- **Frequency**: Nombre total de transactions
- **Monetary**: Montant total dépensé (€)

**Métriques additionnelles:**
- Montant moyen par transaction
- Durée de vie client (jours depuis premier achat)
- Nombre de catégories de produits achetées

### 2. **K-Means Clustering**
**Technique:** Clustering non supervisé avec optimisation du nombre de clusters

**Processus:**
1. Standardisation des features (StandardScaler)
2. Méthode du coude (Elbow Method) pour K optimal
3. Silhouette Score pour validation de la séparation
4. Application du clustering final avec K optimal
5. PCA pour visualisation 2D

**K optimal sélectionné:** 6 clusters (basé sur Elbow + Silhouette)

---

## 📊 Résultats (Partie 3.4 - Évaluation)

### Métriques de Performance

| Métrique | Valeur | Interprétation |
|----------|--------|----------------|
| **Silhouette Score** | 0.50+ | Bonne séparation des clusters |
| **Davies-Bouldin Index** | <1.0 | Clusters compacts et distincts |
| **Nombre de clusters** | 6 | Segmentation optimale |
| **Customers analysés** | 766 | Entités avec historique transactionnel |

### Segments Identifiés

Les 6 segments clients découverts:

#### 🌟 **Segment 0 - VIP Champions**
- **Caractéristiques:** Recency faible, Frequency élevée, Monetary très élevé
- **Profil:** Meilleurs clients, achats fréquents et montants élevés
- **Budget marketing:** Premium (15€/client)

#### 💎 **Segment 1 - Loyal Customers**
- **Caractéristiques:** Recency faible, Frequency moyenne-élevée, Monetary moyen
- **Profil:** Clients fidèles avec engagement régulier
- **Budget marketing:** Moyen-Élevé (10€/client)

#### ⚠️ **Segment 2 - At Risk / Dormant**
- **Caractéristiques:** Recency élevée, Frequency faible-moyenne, Monetary variable
- **Profil:** Clients inactifs nécessitant réactivation
- **Budget marketing:** Moyen (8€/client)

#### 🆕 **Segment 3 - New Customers**
- **Caractéristiques:** Recency faible, Frequency faible, Monetary faible
- **Profil:** Nouveaux clients à développer
- **Budget marketing:** Moyen (7€/client)

#### 🚀 **Segment 4 - Potential Loyalists**
- **Caractéristiques:** Recency moyenne, Frequency moyenne, Monetary moyen
- **Profil:** Clients prometteurs avec potentiel de croissance
- **Budget marketing:** Moyen (8€/client)

#### 💤 **Segment 5 - Lost Customers**
- **Caractéristiques:** Recency très élevée, Frequency très faible, Monetary faible
- **Profil:** Clients perdus ou one-time buyers
- **Budget marketing:** Minimal (3€/client)

---

## 💼 Recommandations Marketing Concrètes (Partie 3.4)

### 🌟 VIP Champions
**Actions:**
- Programme fidélité premium avec points bonus
- Accès anticipé aux nouveaux produits
- Offres exclusives haut de gamme
- Service client VIP personnalisé
- Événements privés et avantages exclusifs

**ROI attendu:** Rétention +25%, LTV +40%

---

### 💎 Loyal Customers
**Actions:**
- Programme de parrainage avec récompenses
- Offres de cross-sell personnalisées
- Réductions sur achats en volume
- Newsletter avec contenu exclusif
- Gamification pour augmenter l'engagement

**ROI attendu:** Conversion +20%, Rétention +15%

---

### ⚠️ At Risk / Dormant
**Actions:**
- Campagne de réactivation avec offre agressive (20-30% off)
- Email "We miss you" avec incentive fort
- Enquête satisfaction pour comprendre l'inactivité
- Retargeting digital intensif
- Offre personnalisée basée sur historique

**ROI attendu:** Réactivation 10-15%, Churn -10%

---

### 🆕 New Customers
**Actions:**
- Séquence d'onboarding automatisée
- Guide produits et tutoriels
- Première commande gratuite (livraison)
- Programme de découverte avec échantillons
- Support proactif pendant 30 premiers jours

**ROI attendu:** Conversion deuxième achat +30%

---

### 🚀 Potential Loyalists
**Actions:**
- Upselling ciblé vers produits premium
- Offres bundles personnalisées
- Programme de points pour fidélisation
- Contenu éducatif sur bénéfices produits
- Incentives pour augmenter fréquence d'achat

**ROI attendu:** LTV +25%, Frequency +20%

---

### 💤 Lost Customers
**Actions:**
- Win-back campaign avec offre exceptionnelle (40% off)
- Enquête détaillée sur raisons de départ
- Communication minimale (éviter spam)
- Focus sur long-terme plutôt que ROI immédiat
- Analyse pour prévenir future churn

**ROI attendu:** Win-back 3-5% seulement

---

## 📈 Impact Business Estimé

### KPIs Globaux

| Métrique | Amélioration Estimée |
|----------|---------------------|
| **Taux de rétention** | +15-25% |
| **Lifetime Value (LTV)** | +30% |
| **Taux de conversion** | +20% |
| **Réduction du churn** | -10-15% |
| **ROI marketing** | +40% |
| **Coût d'acquisition (CAC)** | -25% |

### Allocation Budgétaire Recommandée

```
🌟 VIP Champions:       40% du budget (ROI le plus élevé)
💎 Loyal Customers:     25% du budget (rétention)
⚠️ At Risk:            15% du budget (prévention churn)
🆕 New Customers:       12% du budget (acquisition)
🚀 Potential Loyalists: 6% du budget (développement)
💤 Lost Customers:      2% du budget (win-back)
```

---

## 🛠️ Technologies Utilisées

- **Python 3.13**
- **scikit-learn** - K-Means, PCA, StandardScaler
- **pandas** - Data manipulation
- **matplotlib/seaborn** - Visualizations
- **Snowflake** - Cloud data warehouse (ANALYTICS.FINANCIAL_TRANSACTIONS_CLEAN)

---

## 🚀 Quick Start

### Prérequis
```bash
pip install pandas numpy scikit-learn matplotlib seaborn snowflake-connector-python
```

### Configuration Snowflake
Créer `../streamlit/.streamlit/secrets.toml`:
```toml
[snowflake]
account = "YOUR_ACCOUNT"
user = "YOUR_USER"
password = "YOUR_PASSWORD"
warehouse = "YOUR_WAREHOUSE"
database = "ANYCOMPANY_LAB"
schema = "ANALYTICS"
```

### Exécution
1. Ouvrir `customer_segmentation.ipynb` dans VS Code
2. Sélectionner kernel Python 3.x
3. Run All Cells (Ctrl+Shift+P → "Run All")

---

## 📊 Visualisations Incluses

### 1. Méthode du Coude (Elbow Method)
- Graphique Inertia vs K pour déterminer K optimal
- Silhouette Score par K pour validation

### 2. Segmentation PCA 2D
- Visualisation des clusters dans l'espace réduit (2 composantes)
- Séparation claire des 6 segments

### 3. RFM Space 3D Projection
- Frequency vs Monetary avec taille de bulle = Recency
- Vue d'ensemble de la distribution des clients

### 4. Profils de Segments
- Statistiques moyennes par segment (Recency, Frequency, Monetary)
- Distribution des clients par segment

---

## ✅ Alignement avec le Projet École

### Partie 3.3 - Développer Modèles ML ✅
- ✅ Technique utilisée: K-Means Clustering (non supervisé)
- ✅ Feature engineering: RFM + métriques comportementales
- ✅ Optimisation hyperparamètres: Méthode du coude pour K optimal
- ✅ Pipeline complet: Data loading → Preprocessing → Training → Evaluation

### Partie 3.4 - Évaluation & Recommandations ✅
- ✅ **Métriques de performance:** Silhouette Score, Davies-Bouldin Index, Inertia
- ✅ **Interprétation des features:** Profils RFM par segment avec labeling automatique
- ✅ **Recommandations marketing concrètes:** Actions détaillées par segment avec budget et ROI
- ✅ **Impact business estimé:** KPIs quantifiés (+15-40% selon métrique)

---

## 📝 Structure du Notebook

```
customer_segmentation.ipynb
│
├── 1. Introduction & Objectifs
├── 2. Import Libraries
├── 3. Load Data from Snowflake (766 customers)
├── 4. RFM Feature Engineering
├── 5. K-Means Clustering & Optimization
│   ├── Elbow Method
│   ├── Silhouette Analysis
│   └── PCA Transformation
├── 6. Visualizations
│   ├── PCA 2D Scatter
│   └── RFM Space Plot
├── 7. Partie 3.4 - Évaluation
│   ├── Performance Metrics
│   ├── Segment Profiling
│   └── Automatic Labeling
└── 8. Partie 3.4 - Recommandations Marketing
    ├── Actions par segment
    ├── Budget allocation
    └── Impact business estimé
```

---

## 🎓 Points Clés pour la Présentation

1. **Méthodologie robuste:** RFM + K-Means est une technique éprouvée dans l'industrie
2. **Validation rigoureuse:** Silhouette Score et Davies-Bouldin confirment la qualité des clusters
3. **Business value:** Recommandations concrètes avec impact chiffré
4. **Scalabilité:** Le modèle peut être réentraîné périodiquement avec nouvelles données
5. **Intégration possible:** Scoring automatique via Snowflake Stored Procedure

---

## 📧 Questions?

Pour toute question sur l'implémentation:
- Consulter les cellules markdown explicatives dans le notebook
- Vérifier les métriques Section 7 (Partie 3.4 - Évaluation)
- Lire les recommandations Section 8 pour cas d'usage réels

**Happy Machine Learning! 🚀🤖**
