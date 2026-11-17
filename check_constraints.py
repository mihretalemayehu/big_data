#!/usr/bin/env python3
"""Check database constraints"""
from src.database import get_connection

conn = get_connection()
cur = conn.cursor()

print("=" * 60)
print("CHECKING DATABASE CONSTRAINTS")
print("=" * 60)

# Check primary keys
cur.execute("""
    SELECT tc.table_name, tc.constraint_name, tc.constraint_type
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public' 
    AND tc.constraint_type = 'PRIMARY KEY'
    ORDER BY tc.table_name;
""")
print("\nPRIMARY KEYS:")
for row in cur.fetchall():
    print(f"  ✓ {row[0]}: {row[1]}")

# Check foreign keys
cur.execute("""
    SELECT tc.table_name, tc.constraint_name
    FROM information_schema.table_constraints tc
    WHERE tc.table_schema = 'public' 
    AND tc.constraint_type = 'FOREIGN KEY'
    ORDER BY tc.table_name;
""")
print("\nFOREIGN KEYS:")
for row in cur.fetchall():
    print(f"  ✓ {row[0]}: {row[1]}")

# Check indexes
cur.execute("""
    SELECT tablename, indexname 
    FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND indexname NOT LIKE '%pkey'
    ORDER BY tablename, indexname;
""")
print("\nINDEXES (excluding PK indexes):")
for row in cur.fetchall():
    print(f"  ✓ {row[0]}: {row[1]}")

# Check table row counts
print("\nTABLE ROW COUNTS:")
tables = ['aisles', 'departments', 'products', 'orders', 
          'order_products_train', 'order_products_prior']
for table in tables:
    cur.execute(f"SELECT COUNT(*) FROM {table};")
    count = cur.fetchone()[0]
    print(f"  {table:25} {count:>10,} rows")

print("\n" + "=" * 60)
print("✓ ALL CHECKS COMPLETE")
print("=" * 60)

conn.close()
