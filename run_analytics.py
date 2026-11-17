#!/usr/bin/env python3
"""
run_analytics.py
Run business intelligence queries and generate insights report
"""

import os
import sys
import logging
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv()
except ModuleNotFoundError:
    pass

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parent
SQL_DIR = ROOT / "sql"
REPORTS_DIR = ROOT / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)


def get_connection():
    """Get PostgreSQL database connection"""
    from src.database import get_connection
    return get_connection()


def run_query(conn, query, description):
    """Run a single query and return results"""
    logger.info(f"Running: {description}")
    try:
        with conn.cursor() as cur:
            cur.execute(query)
            columns = [desc[0] for desc in cur.description] if cur.description else []
            results = cur.fetchall() if cur.description else []
            return columns, results
    except Exception as e:
        logger.error(f"Query failed: {e}")
        return None, None


def format_table(columns, rows, title=None):
    """Format query results as a text table"""
    if not rows:
        return "No results\n"
    
    output = []
    
    if title:
        output.append("\n" + "=" * 80)
        output.append(title)
        output.append("=" * 80)
    
    # Calculate column widths
    col_widths = [len(str(col)) for col in columns]
    for row in rows:
        for i, val in enumerate(row):
            col_widths[i] = max(col_widths[i], len(str(val)))
    
    # Header
    header = " | ".join(str(col).ljust(col_widths[i]) for i, col in enumerate(columns))
    output.append(header)
    output.append("-" * len(header))
    
    # Rows
    for row in rows:
        row_str = " | ".join(str(val).ljust(col_widths[i]) for i, val in enumerate(row))
        output.append(row_str)
    
    output.append("")
    return "\n".join(output)


def run_all_analytics(conn):
    """Run all business analytics queries"""
    
    report_lines = []
    report_lines.append("=" * 80)
    report_lines.append("         INSTACART BUSINESS INTELLIGENCE REPORT")
    report_lines.append("=" * 80)
    report_lines.append("")
    
    # Query 1.1: Orders by hour
    query = """
    SELECT 
        order_hour_of_day AS hour,
        COUNT(*) AS total_orders,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM orders
    GROUP BY order_hour_of_day
    ORDER BY order_hour_of_day;
    """
    cols, rows = run_query(conn, query, "Orders by hour of day")
    if rows:
        report_lines.append(format_table(cols, rows, "Q1.1: Orders by Hour of Day"))
    
    # Query 1.2: Orders by day of week
    query = """
    SELECT 
        order_dow AS day_of_week,
        CASE order_dow
            WHEN 0 THEN 'Sunday'
            WHEN 1 THEN 'Monday'
            WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday'
            WHEN 4 THEN 'Thursday'
            WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END AS day_name,
        COUNT(*) AS total_orders,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM orders
    GROUP BY order_dow
    ORDER BY order_dow;
    """
    cols, rows = run_query(conn, query, "Orders by day of week")
    if rows:
        report_lines.append(format_table(cols, rows, "Q1.2: Orders by Day of Week"))
    
    # Query 1.3: Order frequency
    query = """
    SELECT 
        CASE 
            WHEN days_since_prior_order IS NULL THEN 'First Order'
            WHEN days_since_prior_order <= 7 THEN '0-7 days (Weekly)'
            WHEN days_since_prior_order <= 14 THEN '8-14 days (Bi-weekly)'
            WHEN days_since_prior_order <= 21 THEN '15-21 days (Tri-weekly)'
            WHEN days_since_prior_order <= 30 THEN '22-30 days (Monthly)'
            ELSE '30+ days (Rare)'
        END AS order_frequency,
        COUNT(*) AS order_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM orders
    GROUP BY 
        CASE 
            WHEN days_since_prior_order IS NULL THEN 'First Order'
            WHEN days_since_prior_order <= 7 THEN '0-7 days (Weekly)'
            WHEN days_since_prior_order <= 14 THEN '8-14 days (Bi-weekly)'
            WHEN days_since_prior_order <= 21 THEN '15-21 days (Tri-weekly)'
            WHEN days_since_prior_order <= 30 THEN '22-30 days (Monthly)'
            ELSE '30+ days (Rare)'
        END
    ORDER BY order_count DESC;
    """
    cols, rows = run_query(conn, query, "Order frequency distribution")
    if rows:
        report_lines.append(format_table(cols, rows, "Q1.3: Days Between Orders"))
    
    # Query 1.5: Customer segmentation
    query = """
    SELECT 
        CASE 
            WHEN max_order_num = 1 THEN '1 order (One-time buyer)'
            WHEN max_order_num BETWEEN 2 AND 5 THEN '2-5 orders (Occasional)'
            WHEN max_order_num BETWEEN 6 AND 10 THEN '6-10 orders (Regular)'
            WHEN max_order_num BETWEEN 11 AND 20 THEN '11-20 orders (Loyal)'
            ELSE '20+ orders (Power user)'
        END AS customer_segment,
        COUNT(*) AS customer_count,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM (
        SELECT user_id, MAX(order_number) AS max_order_num
        FROM orders
        GROUP BY user_id
    ) AS user_orders
    GROUP BY 
        CASE 
            WHEN max_order_num = 1 THEN '1 order (One-time buyer)'
            WHEN max_order_num BETWEEN 2 AND 5 THEN '2-5 orders (Occasional)'
            WHEN max_order_num BETWEEN 6 AND 10 THEN '6-10 orders (Regular)'
            WHEN max_order_num BETWEEN 11 AND 20 THEN '11-20 orders (Loyal)'
            ELSE '20+ orders (Power user)'
        END
    ORDER BY customer_count DESC;
    """
    cols, rows = run_query(conn, query, "Customer segmentation")
    if rows:
        report_lines.append(format_table(cols, rows, "Q1.5: Customer Segments by Order Count"))
    
    # Query 2.1: Overall reorder rate
    query = """
    SELECT 
        'Overall Reorder Rate' AS metric,
        COUNT(*) AS total_products,
        SUM(CASE WHEN is_reordered THEN 1 ELSE 0 END) AS reordered_count,
        ROUND(100.0 * SUM(CASE WHEN is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_percentage
    FROM order_products_train;
    """
    cols, rows = run_query(conn, query, "Overall reorder rate")
    if rows:
        report_lines.append(format_table(cols, rows, "Q2.1: Overall Product Reorder Rate"))
    
    # Query 2.3: Reorder rate by department
    query = """
    SELECT 
        d.department_name,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) AS reorder_count,
        ROUND(100.0 * SUM(CASE WHEN opt.is_reordered THEN 1 ELSE 0 END) / COUNT(*), 2) AS reorder_rate
    FROM order_products_train opt
    JOIN products p ON opt.product_id = p.product_id
    JOIN departments d ON p.department_id = d.department_id
    GROUP BY d.department_name
    ORDER BY reorder_rate DESC;
    """
    cols, rows = run_query(conn, query, "Reorder rate by department")
    if rows:
        report_lines.append(format_table(cols, rows, "Q2.3: Reorder Rate by Department"))
    
    # Query 3.1: Average cart size by day
    query = """
    SELECT 
        o.order_dow,
        CASE o.order_dow
            WHEN 0 THEN 'Sunday'
            WHEN 1 THEN 'Monday'
            WHEN 2 THEN 'Tuesday'
            WHEN 3 THEN 'Wednesday'
            WHEN 4 THEN 'Thursday'
            WHEN 5 THEN 'Friday'
            WHEN 6 THEN 'Saturday'
        END AS day_name,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(COUNT(opt.product_id)::NUMERIC / COUNT(DISTINCT o.order_id), 2) AS avg_cart_size
    FROM orders o
    JOIN order_products_train opt ON o.order_id = opt.order_id
    GROUP BY o.order_dow
    ORDER BY o.order_dow;
    """
    cols, rows = run_query(conn, query, "Average cart size by day")
    if rows:
        report_lines.append(format_table(cols, rows, "Q3.1: Average Cart Size by Day of Week"))
    
    # Query 4.2: Most popular departments
    query = """
    SELECT 
        d.department_name,
        COUNT(DISTINCT p.product_id) AS unique_products,
        COUNT(*) AS total_orders,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
    FROM order_products_train opt
    JOIN products p ON opt.product_id = p.product_id
    JOIN departments d ON p.department_id = d.department_id
    GROUP BY d.department_name
    ORDER BY total_orders DESC;
    """
    cols, rows = run_query(conn, query, "Most popular departments")
    if rows:
        report_lines.append(format_table(cols, rows, "Q4.2: Most Popular Departments"))
    
    # Query 6.1: Database summary
    query = """
    SELECT 
        'Total Aisles' AS metric, COUNT(*)::TEXT AS value FROM aisles
    UNION ALL
    SELECT 'Total Departments', COUNT(*)::TEXT FROM departments
    UNION ALL
    SELECT 'Total Products', COUNT(*)::TEXT FROM products
    UNION ALL
    SELECT 'Total Orders', COUNT(*)::TEXT FROM orders
    UNION ALL
    SELECT 'Unique Customers', COUNT(DISTINCT user_id)::TEXT FROM orders
    UNION ALL
    SELECT 'Train Order Items', COUNT(*)::TEXT FROM order_products_train
    UNION ALL
    SELECT 'Prior Order Items', COUNT(*)::TEXT FROM order_products_prior;
    """
    cols, rows = run_query(conn, query, "Database summary")
    if rows:
        report_lines.append(format_table(cols, rows, "Q6.1: Database Summary Statistics"))
    
    report_lines.append("=" * 80)
    report_lines.append("END OF REPORT")
    report_lines.append("=" * 80)
    
    return "\n".join(report_lines)


def main():
    """Main entry point"""
    logger.info("=" * 50)
    logger.info("  INSTACART BUSINESS ANALYTICS")
    logger.info("=" * 50)
    
    try:
        conn = get_connection()
        logger.info("Connected to database successfully")
        
        report = run_all_analytics(conn)
        
        # Save report
        output_file = REPORTS_DIR / "business_insights.txt"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        logger.info(f"Report saved to: {output_file}")
        
        # Also print to console
        print("\n" + report)
        
        conn.close()
        logger.info("Analytics completed successfully!")
        
    except Exception as e:
        logger.error(f"Analytics failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
