-- Drop and recreate the get_staff_performance_analysis function with correct return type
DROP FUNCTION IF EXISTS get_staff_performance_analysis(DATE, INTEGER);

CREATE OR REPLACE FUNCTION get_staff_performance_analysis(
    analysis_date DATE DEFAULT CURRENT_DATE,
    period_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    staff_id UUID,
    staff_name TEXT,
    days_worked BIGINT,
    total_hours_worked NUMERIC,
    total_orders BIGINT,
    total_sales NUMERIC,
    average_order_value NUMERIC,
    orders_per_hour NUMERIC,
    sales_per_hour NUMERIC,
    average_transaction_time INTEGER,
    accuracy_rate NUMERIC,
    customer_per_day NUMERIC,
    efficiency_rank BIGINT,
    performance_grade TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH staff_metrics AS (
        SELECT 
            up.id as staff_id,
            up.full_name::TEXT as staff_name,
            COUNT(DISTINCT ss.shift_date) as days_worked,
            COALESCE(SUM(ss.actual_hours), 0)::NUMERIC as total_hours_worked,
            COUNT(o.id) as total_orders,
            COALESCE(SUM(o.total_amount), 0)::NUMERIC as total_sales,
            COALESCE(AVG(o.total_amount), 0)::NUMERIC as average_order_value,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN (COUNT(o.id)::NUMERIC / SUM(ss.actual_hours))
                ELSE 0::NUMERIC
            END as orders_per_hour,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN (COALESCE(SUM(o.total_amount), 0)::NUMERIC / SUM(ss.actual_hours))
                ELSE 0::NUMERIC
            END as sales_per_hour,
            COALESCE(AVG(tp.processing_duration), 0)::INTEGER as average_transaction_time,
            COALESCE(AVG(sp.accuracy_rate), 100)::NUMERIC as accuracy_rate,
            CASE 
                WHEN COUNT(DISTINCT ss.shift_date) > 0 
                THEN (COUNT(DISTINCT o.customer_id)::NUMERIC / COUNT(DISTINCT ss.shift_date)::NUMERIC)
                ELSE 0::NUMERIC
            END as customer_per_day
        FROM public.user_profiles up
        LEFT JOIN public.staff_shifts ss ON up.id = ss.staff_id 
            AND ss.shift_date BETWEEN analysis_date - INTERVAL '1 day' * period_days AND analysis_date
            AND ss.is_active = true
        LEFT JOIN public.orders o ON up.id = o.served_by 
            AND o.order_date BETWEEN analysis_date - INTERVAL '1 day' * period_days AND analysis_date
            AND o.status = 'completed' AND o.is_active = true
        LEFT JOIN public.transaction_performance tp ON o.id = tp.order_id
        LEFT JOIN public.staff_performance sp ON up.id = sp.staff_id 
            AND sp.performance_date BETWEEN analysis_date - INTERVAL '1 day' * period_days AND analysis_date
        WHERE up.role IN ('admin', 'receptionist') AND up.is_active = true
        GROUP BY up.id, up.full_name
    ),
    ranked_staff AS (
        SELECT 
            sm.*,
            ROW_NUMBER() OVER (ORDER BY sm.sales_per_hour DESC, sm.accuracy_rate DESC) as efficiency_rank
        FROM staff_metrics sm
    )
    SELECT 
        rs.staff_id,
        rs.staff_name,
        rs.days_worked,
        rs.total_hours_worked,
        rs.total_orders,
        rs.total_sales,
        rs.average_order_value,
        rs.orders_per_hour,
        rs.sales_per_hour,
        rs.average_transaction_time,
        rs.accuracy_rate,
        rs.customer_per_day,
        rs.efficiency_rank,
        CASE 
            WHEN rs.accuracy_rate >= 98 AND rs.sales_per_hour >= 100 THEN 'A+'::TEXT
            WHEN rs.accuracy_rate >= 95 AND rs.sales_per_hour >= 80 THEN 'A'::TEXT
            WHEN rs.accuracy_rate >= 90 AND rs.sales_per_hour >= 60 THEN 'B'::TEXT
            WHEN rs.accuracy_rate >= 85 THEN 'C'::TEXT
            ELSE 'D'::TEXT
        END as performance_grade
    FROM ranked_staff rs
    WHERE rs.days_worked > 0
    ORDER BY rs.efficiency_rank;
END;
$$ LANGUAGE plpgsql;