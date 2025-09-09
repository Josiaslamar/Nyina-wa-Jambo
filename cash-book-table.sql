-- =============================================
-- CASH BOOK TABLE FOR PHARMACY MANAGEMENT
-- =============================================

-- Create cash_book table
CREATE TABLE IF NOT EXISTS public.cash_book (
    id BIGSERIAL PRIMARY KEY,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    ticket_moderator DECIMAL(10,2) DEFAULT 0,
    
    -- Cash In Categories
    pharmacie DECIMAL(12,2) DEFAULT 0,
    laboratoire DECIMAL(12,2) DEFAULT 0,
    general DECIMAL(12,2) DEFAULT 0,
    other_cash_in DECIMAL(12,2) DEFAULT 0,
    total_cash_in DECIMAL(12,2) DEFAULT 0,
    
    -- Cash Out Categories
    depense DECIMAL(12,2) DEFAULT 0,
    credit DECIMAL(12,2) DEFAULT 0,
    total_cash_out DECIMAL(12,2) DEFAULT 0,
    
    -- Balance and metadata
    balance DECIMAL(12,2) DEFAULT 0,
    notes TEXT,
    reference VARCHAR(100),
    
    -- Audit fields
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Enable RLS
ALTER TABLE public.cash_book ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Admins have full access to cash_book" ON public.cash_book
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

-- Triggers for updated_at and audit
CREATE TRIGGER update_cash_book_updated_at 
    BEFORE UPDATE ON public.cash_book 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER audit_cash_book 
    AFTER INSERT OR UPDATE OR DELETE ON public.cash_book 
    FOR EACH ROW 
    EXECUTE FUNCTION log_audit_action();

-- Function to automatically calculate totals
CREATE OR REPLACE FUNCTION calculate_cash_book_totals()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate total cash in
    NEW.total_cash_in := COALESCE(NEW.pharmacie, 0) + COALESCE(NEW.laboratoire, 0) + 
                        COALESCE(NEW.general, 0) + COALESCE(NEW.other_cash_in, 0);
    
    -- Calculate total cash out
    NEW.total_cash_out := COALESCE(NEW.depense, 0) + COALESCE(NEW.credit, 0);
    
    -- Calculate balance
    NEW.balance := NEW.total_cash_in - NEW.total_cash_out;
    
    -- Set updated_by for updates
    IF TG_OP = 'UPDATE' THEN
        NEW.updated_by := auth.uid();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to calculate totals automatically
CREATE TRIGGER calculate_cash_book_totals_trigger 
    BEFORE INSERT OR UPDATE ON public.cash_book 
    FOR EACH ROW 
    EXECUTE FUNCTION calculate_cash_book_totals();

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_cash_book_date ON public.cash_book(entry_date) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_cash_book_created_by ON public.cash_book(created_by) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_cash_book_active ON public.cash_book(is_active);

-- Add explicit foreign key constraints with known names
ALTER TABLE public.cash_book 
DROP CONSTRAINT IF EXISTS fk_cash_book_created_by;

ALTER TABLE public.cash_book 
ADD CONSTRAINT fk_cash_book_created_by 
FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.cash_book 
DROP CONSTRAINT IF EXISTS fk_cash_book_updated_by;

ALTER TABLE public.cash_book 
ADD CONSTRAINT fk_cash_book_updated_by 
FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;

-- Grant permissions
GRANT ALL ON public.cash_book TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.cash_book_id_seq TO authenticated;

-- View for cash book summary
CREATE VIEW vw_cash_book_summary AS
SELECT 
    cb.*,
    up.full_name as created_by_name,
    up2.full_name as updated_by_name
FROM public.cash_book cb
LEFT JOIN public.user_profiles up ON cb.created_by = up.id
LEFT JOIN public.user_profiles up2 ON cb.updated_by = up2.id
WHERE cb.is_active = true
ORDER BY cb.entry_date DESC, cb.created_at DESC;

-- Function to get cash book entries with filters
CREATE OR REPLACE FUNCTION get_cash_book_entries(
    start_date DATE DEFAULT NULL,
    end_date DATE DEFAULT NULL,
    limit_records INTEGER DEFAULT 100
)
RETURNS TABLE(
    id BIGINT,
    entry_date DATE,
    ticket_moderator DECIMAL(10,2),
    pharmacie DECIMAL(12,2),
    laboratoire DECIMAL(12,2),
    general DECIMAL(12,2),
    other_cash_in DECIMAL(12,2),
    total_cash_in DECIMAL(12,2),
    depense DECIMAL(12,2),
    credit DECIMAL(12,2),
    total_cash_out DECIMAL(12,2),
    balance DECIMAL(12,2),
    notes TEXT,
    reference VARCHAR(100),
    created_by_name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cb.id,
        cb.entry_date,
        cb.ticket_moderator,
        cb.pharmacie,
        cb.laboratoire,
        cb.general,
        cb.other_cash_in,
        cb.total_cash_in,
        cb.depense,
        cb.credit,
        cb.total_cash_out,
        cb.balance,
        cb.notes,
        cb.reference,
        up.full_name as created_by_name,
        cb.created_at
    FROM public.cash_book cb
    LEFT JOIN public.user_profiles up ON cb.created_by = up.id
    WHERE cb.is_active = true
    AND (start_date IS NULL OR cb.entry_date >= start_date)
    AND (end_date IS NULL OR cb.entry_date <= end_date)
    ORDER BY cb.entry_date DESC, cb.created_at DESC
    LIMIT limit_records;
END;
$$ LANGUAGE plpgsql;

-- Function to get cash book statistics
CREATE OR REPLACE FUNCTION get_cash_book_stats(
    start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
    stats JSON;
BEGIN
    SELECT json_build_object(
        'period', json_build_object(
            'start_date', start_date,
            'end_date', end_date
        ),
        'totals', json_build_object(
            'total_cash_in', COALESCE(SUM(total_cash_in), 0),
            'total_cash_out', COALESCE(SUM(total_cash_out), 0),
            'net_balance', COALESCE(SUM(total_cash_in) - SUM(total_cash_out), 0),
            'entries_count', COUNT(*)
        ),
        'categories', json_build_object(
            'pharmacie', COALESCE(SUM(pharmacie), 0),
            'laboratoire', COALESCE(SUM(laboratoire), 0),
            'general', COALESCE(SUM(general), 0),
            'other_cash_in', COALESCE(SUM(other_cash_in), 0),
            'depense', COALESCE(SUM(depense), 0),
            'credit', COALESCE(SUM(credit), 0)
        ),
        'today', json_build_object(
            'entries_count', (
                SELECT COUNT(*) 
                FROM public.cash_book 
                WHERE entry_date = CURRENT_DATE AND is_active = true
            ),
            'cash_in', (
                SELECT COALESCE(SUM(total_cash_in), 0) 
                FROM public.cash_book 
                WHERE entry_date = CURRENT_DATE AND is_active = true
            ),
            'cash_out', (
                SELECT COALESCE(SUM(total_cash_out), 0) 
                FROM public.cash_book 
                WHERE entry_date = CURRENT_DATE AND is_active = true
            )
        )
    ) INTO stats
    FROM public.cash_book
    WHERE is_active = true
    AND entry_date BETWEEN start_date AND end_date;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql;

-- Insert some sample data for testing (using actual user IDs from your system)
INSERT INTO public.cash_book (
    entry_date, ticket_moderator, pharmacie, laboratoire, general, 
    other_cash_in, depense, credit, notes, reference, created_by
) VALUES
(CURRENT_DATE, 150.00, 250000, 50000, 30000, 20000, 150000, 0, 'Daily sales and purchases', 'TXN-001', 'a3e58214-90de-481d-9249-938ff1cf3b70'),
(CURRENT_DATE - 1, 200.00, 180000, 75000, 45000, 0, 80000, 25000, 'Medicine sales and lab supplies', 'TXN-002', '09d69007-0124-45cb-b8cc-f546f46259ee'),
(CURRENT_DATE - 2, 100.00, 320000, 60000, 25000, 15000, 200000, 50000, 'High sales day with staff payments', 'TXN-003', 'a3e58214-90de-481d-9249-938ff1cf3b70'),
(CURRENT_DATE - 3, 300.00, 290000, 40000, 35000, 10000, 120000, 30000, 'Regular operations', 'TXN-004', '09d69007-0124-45cb-b8cc-f546f46259ee'),
(CURRENT_DATE - 4, 250.00, 275000, 85000, 20000, 5000, 380000, 75000, 'Large supplier payment day', 'TXN-005', 'a3e58214-90de-481d-9249-938ff1cf3b70')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.cash_book IS 'Cash book entries for tracking all cash transactions in the pharmacy';
COMMENT ON COLUMN public.cash_book.ticket_moderator IS 'Commission or fee for ticket moderation services';
COMMENT ON COLUMN public.cash_book.pharmacie IS 'Cash received from pharmacy sales';
COMMENT ON COLUMN public.cash_book.laboratoire IS 'Cash received from laboratory services';
COMMENT ON COLUMN public.cash_book.general IS 'Cash received from general services';
COMMENT ON COLUMN public.cash_book.other_cash_in IS 'Other sources of cash income';
COMMENT ON COLUMN public.cash_book.depense IS 'Cash spent on expenses';
COMMENT ON COLUMN public.cash_book.credit IS 'Cash given as credit or loans';
COMMENT ON COLUMN public.cash_book.balance IS 'Net balance (cash in - cash out)';
