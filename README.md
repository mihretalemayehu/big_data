# Instacart Big Data ETL Pipeline
### Using Python Pandas and PostgreSQL

---

## Business Problem

> **"When do customers order and how often do they return?"**

The Instacart Market Basket Analysis dataset contains over 3 million grocery orders
from more than 200,000 users. This project builds a complete ETL pipeline that:

1. **Extracts** six raw CSV files (including a 32-million-row fact table)
2. **Explores** every file using pandas and saves a full exploration report
3. **Transforms** data types, standardises columns, and creates derived columns
4. **Cleans** missing values, duplicates, and invalid records safely
5. **Loads** cleaned data into a local PostgreSQL database (`bigdata_db`)
6. **Verifies** every table using `SELECT COUNT(*)`
7. **Reports** charts and analytics answering the business question

## Instacart Grocery Orders ETL

A Python and PostgreSQL pipeline for exploring, transforming, cleaning, loading, and verifying the Instacart Market Basket Analysis dataset.

The project is designed to answer questions such as when customers place orders and how often they reorder products. It includes a chunked workflow for the large prior-order products file, which helps control memory use during exploration and database loading.

## Contents

- [Project workflow](#project-workflow)
- [Repository structure](#repository-structure)
- [Requirements](#requirements)
- [Setup](#setup)
- [Download the dataset](#download-the-dataset)
- [Configuration](#configuration)
- [Run the project](#run-the-project)
- [Database tables](#database-tables)
- [Data handling notes](#data-handling-notes)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)

## Project workflow

The full pipeline runs these stages in order:

1. **Explore:** Read the input files and write descriptive statistics to `reports/data_exploration.txt`.
2. **Transform:** Standardize names and types and add derived fields such as `is_first_order`, `order_period`, and `is_reordered`.
3. **Clean:** Remove duplicate or invalid records and invalid product/order references. First-order null values in `days_since_prior_order` are retained because they are meaningful.
4. **Save processed data:** Write cleaned CSVs for the smaller tables to `data/processed/`.
5. **Load:** Bulk-load data into PostgreSQL with `COPY FROM STDIN`.
6. **Verify:** Compare loaded row counts with PostgreSQL `COUNT(*)` results and write `reports/verification_report.txt`.

The `order_products__prior.csv` file is processed in chunks of 500,000 rows. It is not loaded into one large DataFrame or saved as a single processed CSV.

## Repository structure

```text
instacart-bigdata-etl/
├── data/                         # Local data files; ignored by Git
│   ├── raw/                      # Six source CSV files go here
│   └── processed/                # Cleaned smaller-table CSVs
├── notebooks/
│   └── exploration.ipynb         # Jupyter exploration notebook
├── reports/                      # Exploration, cleaning, verification, logs, charts
│   ├── data_exploration.txt      # Full data exploration report
│   ├── cleaning_report.txt       # Data cleaning summary
│   ├── verification_report.txt   # Database verification results
│   ├── business_insights.txt     # Business analytics results
│   └── *.png                     # Generated charts
├── sql/
│   ├── schema.sql                # PostgreSQL table definitions
│   ├── verify_counts.sql         # Row-count queries
│   └── business_analytics.sql    # Business intelligence queries
├── src/
│   ├── charts.py                 # Chart-generation functions
│   ├── clean.py                  # Data-cleaning rules
│   ├── database.py               # PostgreSQL connection helpers
│   ├── explore.py                # CSV exploration and reporting
│   ├── load.py                   # Processed-data saving and database loading
│   ├── pipeline.py               # ETL orchestration
│   ├── transform.py              # Type conversions and derived columns
│   └── verify.py                  # Database row-count verification
├── run_exploration.py            # Explore input CSVs
├── run_pipeline.py               # Main ETL entry point
├── run_verification.py           # Verify database contents
├── run_analytics.py              # Run business intelligence queries
├── requirements.txt              # Pinned Python dependencies
├── README.md                     # Project documentation
├── PROJECT_REPORT.txt            # Complete project report
├── DATA_DICTIONARY.txt           # Data dictionary with all column definitions
└── ER_DIAGRAM.txt                # Entity-relationship diagram documentation
```

The `data/` directory and `.env` file are excluded from Git. Clone the repository, then create the data folders and add the source files locally. The repository currently does not include a sample-data generator or an automated test suite.

## Requirements

- Windows, macOS, or Linux
- Python 3.11 recommended
- PostgreSQL running locally or reachable over the network
- Access to download the dataset from Kaggle

Python packages are pinned in `requirements.txt`: pandas, psycopg2-binary, python-dotenv, matplotlib, ipykernel, and notebook.

## Setup

Run these commands from the repository root. The scripts use project-relative paths for input and output files.

### 1. Create a virtual environment

Windows PowerShell:

```powershell
py -3.11 -m venv .venv
```

Activate it:

```powershell
.\.venv\Scripts\Activate.ps1
```

If PowerShell blocks activation, allow scripts for the current terminal session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

macOS or Linux:

```bash
python3.11 -m venv .venv
source .venv/bin/activate
```

### 2. Install dependencies

```powershell
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

### 3. Create local data folders

From the project root:

```powershell
New-Item -ItemType Directory -Force data\raw, data\processed | Out-Null
```

On macOS or Linux:

```bash
mkdir -p data/raw data/processed
```

## Download the dataset

Download the Instacart Market Basket Analysis data from the [Kaggle competition data page](https://www.kaggle.com/competitions/instacart-market-basket-analysis/data). Kaggle sign-in and acceptance of its dataset terms may be required.

Extract the archive and place these six files in `data/raw/`:

```text
data/raw/aisles.csv
data/raw/departments.csv
data/raw/products.csv
data/raw/orders.csv
data/raw/order_products__train.csv
data/raw/order_products__prior.csv
```

Keep the double underscores in `order_products__train.csv` and `order_products__prior.csv`. The raw data is not committed to this repository; each user downloads it from Kaggle.

## Configuration

Create a file named `.env` in the repository root. The file is ignored by Git. Set `DB_PASSWORD` to the password for your PostgreSQL user:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bigdata_db
DB_USER=postgres
DB_PASSWORD=replace_with_your_local_password
PRIOR_ROWS_LIMIT=3000000
```

`DB_PASSWORD` is required for database operations. The other database values have defaults shown above. The database user must be able to connect to the PostgreSQL maintenance database and create `bigdata_db` if it does not already exist.

`PRIOR_ROWS_LIMIT` controls how many raw rows are read from `order_products__prior.csv` for database loading:

- `3000000` (default): load up to the first three million raw rows, before cleaning.
- `0`: read and load the entire prior-order file. This can take substantially longer and requires more database storage and processing time.

The prior file is still scanned in chunks for the exploration report, regardless of this database-loading limit.

## Run the project

Run commands from the repository root with the virtual environment activated.

### Explore the source files

```powershell
python run_exploration.py
```

To use a different input directory:

```powershell
python run_exploration.py --raw-dir path\to\raw
```

The script prints summary information and writes the detailed report to `reports/data_exploration.txt`. The prior-order file is read in 500,000-row chunks.

### Run the pipeline without PostgreSQL

```powershell
python run_pipeline.py --skip-db
```

This runs exploration, transformation, cleaning, and processed-CSV saving without loading data into PostgreSQL. It still needs the source CSVs and scans the prior-order file for exploration. The cleaned smaller-table files are saved in `data/processed/`.

Use a different input directory with:

```powershell
python run_pipeline.py --raw-dir path\to\raw --skip-db
```

### Run the full ETL pipeline

Make sure PostgreSQL is running and `.env` is configured, then run:

```powershell
python run_pipeline.py
```

The pipeline creates `bigdata_db` if needed, creates the tables, loads the cleaned data, and verifies row counts. It writes logs and reports under `reports/`.

To test the connection to an already-created `bigdata_db`:

```powershell
python run_pipeline.py --test-connection
```

### Verify the database

After loading the data, run:

```powershell
python run_verification.py
```

This runs the SQL count queries and prints direct `COUNT(*)` results for the six tables. The full pipeline also writes `reports/verification_report.txt` during its verification stage.

### Run business analytics queries

After loading data into the database, run the business intelligence analysis:

```powershell
python run_analytics.py
```

This executes all queries from `sql/business_analytics.sql` and generates a comprehensive report at `reports/business_insights.txt` with:
- Customer ordering patterns (by hour, day, frequency)
- Product reorder rates
- Customer segmentation analysis
- Shopping cart statistics
- Popular products and departments

You can also run individual queries manually:

```powershell
psql -U postgres -d bigdata_db -f sql/business_analytics.sql
```

### Generate charts

After a pipeline run has created `data/processed/orders.csv`, generate the three charts with:

```powershell
python -c "import pandas as pd; from src.charts import generate_all_charts; generate_all_charts(pd.read_csv('data/processed/orders.csv'))"
```

The chart files are saved in `reports/`:

- `chart_orders_per_dow.png`
- `chart_orders_per_hour.png`
- `chart_days_since_prior.png`

### Open the notebook

```powershell
jupyter notebook notebooks/exploration.ipynb
```

## Database tables

The PostgreSQL schema contains six tables:

| Table | Contents |
| --- | --- |
| `aisles` | Product aisle names and identifiers |
| `departments` | Product department names and identifiers |
| `products` | Product names and aisle/department references |
| `orders` | Order, user, time, and prior-order interval attributes |
| `order_products_train` | Products included in training-set orders |
| `order_products_prior` | Products included in prior orders |

Primary keys, foreign keys, and indexes are added after bulk loading. The `days_since_prior_order` column is nullable; null values mark a customer's first order.

Useful derived fields include:

- `is_first_order`: true when `days_since_prior_order` is null.
- `order_period`: Morning, Afternoon, Evening, or Night, derived from `order_hour_of_day`.
- `is_reordered`: true when the source `reordered` value is 1.
- `product_name_length`: character count of the product name.

The transformed products CSV also includes `product_name_upper`; the PostgreSQL `products` table does not store that extra field.

## Data handling notes

- The pipeline truncates and reloads destination tables on each full run. Re-running it replaces the existing table contents.
- `PRIOR_ROWS_LIMIT` applies before cleaning, so the final number of loaded prior rows can be lower than the configured limit.
- The prior-order CSV is read in 500,000-row chunks to reduce memory usage.
- First-order null values in `days_since_prior_order` are valid and are preserved.
- `data/` and `.env` are ignored by Git. Do not add credentials or large raw datasets to commits.
- `reports/` contains generated outputs; rerunning the pipeline may replace existing report files.

## Documentation

The project includes comprehensive documentation:

- **README.md** - Setup instructions and quick start guide
- **PROJECT_REPORT.txt** - Complete project report with findings and analysis
- **DATA_DICTIONARY.txt** - Detailed description of all tables and columns
- **ER_DIAGRAM.txt** - Entity-relationship diagram and database design
- **sql/business_analytics.sql** - Business intelligence queries with comments

These documents provide everything needed to understand, use, and extend the project.

## Troubleshooting

### `FileNotFoundError` or “File not found” for a CSV

Check that all six Kaggle files are in `data/raw/` and that the filenames match exactly, including the double underscores in the two order-product files.

### `DB_PASSWORD is not set`

Create `.env` in the repository root and set `DB_PASSWORD`. Restart the command after saving the file.

### PostgreSQL connection refused

Make sure the PostgreSQL service is running and confirm `DB_HOST` and `DB_PORT` in `.env`. Test the connection with:

```powershell
python run_pipeline.py --test-connection
```

### Database creation fails

The configured database user must be allowed to connect to the `postgres` maintenance database and create a database. Alternatively, create `bigdata_db` with pgAdmin or `psql`, then run the pipeline again.

### Missing Python package

Activate the project virtual environment and reinstall the pinned dependencies:

```powershell
python -m pip install -r requirements.txt
```

### Pipeline takes a long time

The prior-order file is large and is scanned in chunks. Keep `PRIOR_ROWS_LIMIT=3000000` for a smaller database load; set it to `0` only when you intend to load all prior-order rows.

## Data source

Instacart Market Basket Analysis dataset: [Kaggle competition page](https://www.kaggle.com/competitions/instacart-market-basket-analysis/data).
|---|-------------|------|-----------------|
