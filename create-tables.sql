
-- =============================================
-- CORE TABLES
-- =============================================

-- 1. System Settings Table (for this specific facility)
CREATE TABLE public.facility_settings (
    id BIGSERIAL PRIMARY KEY,
    facility_name VARCHAR(255) NOT NULL,
    facility_type VARCHAR(50) NOT NULL CHECK (facility_type IN ('dispensary', 'pharmacy')),
    license_number VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    province VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Rwanda',
    logo_url TEXT,
    currency VARCHAR(10) DEFAULT 'RWF',
    tax_rate DECIMAL(5,2) DEFAULT 0,
    business_hours JSONB, -- {"monday": {"open": "08:00", "close": "18:00"}, ...}
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- 2. User Profiles Table (extends Supabase auth.users)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'receptionist', 'customer')),
    is_active BOOLEAN DEFAULT true,
    phone VARCHAR(50),
    address TEXT,
    last_login TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Receptionists Table
CREATE TABLE public.receptionists (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
    employee_id VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    department VARCHAR(100),
    shift VARCHAR(20), -- morning, afternoon, night
    salary DECIMAL(10,2),
    hire_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Suppliers Table
CREATE TABLE public.suppliers (
    id BIGSERIAL PRIMARY KEY,
    supplier_code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    payment_terms VARCHAR(100), -- "Net 30", "Cash on delivery"
    credit_limit DECIMAL(12,2) DEFAULT 0,
    current_balance DECIMAL(12,2) DEFAULT 0,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Medicine Categories Table
CREATE TABLE public.medicine_categories (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Medicines Table
CREATE TABLE public.medicines (
    id BIGSERIAL PRIMARY KEY,
    medicine_code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    generic_name VARCHAR(255),
    brand_name VARCHAR(255),
    category_id BIGINT REFERENCES public.medicine_categories(id),
    dosage_form VARCHAR(50), -- tablet, capsule, syrup, injection, cream
    strength VARCHAR(50), -- 500mg, 250ml, 10mg/ml
    unit VARCHAR(20), -- pieces, bottles, tubes
    cost_price DECIMAL(10,2) DEFAULT 0,
    selling_price DECIMAL(10,2) DEFAULT 0,
    stock INTEGER DEFAULT 0,
    supplier_id BIGINT REFERENCES public.suppliers(id),
    sale_type VARCHAR(50) CHECK (sale_type IN ('Private', 'Mutuel', 'Both')),
    requires_prescription BOOLEAN DEFAULT false,
    description TEXT,
    storage_conditions TEXT,
    expiry_date DATE,
    batch_number VARCHAR(100),
    manufacturer VARCHAR(255),
    min_stock_level INTEGER DEFAULT 10,
    max_stock_level INTEGER DEFAULT 1000,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
 controlled_substance BOOLEAN DEFAULT false,
 insurance_coverage BOOLEAN DEFAULT false,
 tax_rate DECIMAL(5,2) DEFAULT 0,
 updated_by UUID REFERENCES auth.users(id),
 side_effects TEXT,
 usage_instructions TEXT,
 contraindications TEXT;

);

-- 7. Customers Table (simplified, no health data)
CREATE TABLE public.customers (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    customer_id VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    preferred_language VARCHAR(20) DEFAULT 'Kinyarwanda',
    last_purchase DATE,
    total_purchases INTEGER DEFAULT 0,
    total_spent DECIMAL(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Orders Table
CREATE TABLE public.orders (
    id BIGSERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id BIGINT REFERENCES public.customers(id),
    order_type VARCHAR(50) DEFAULT 'direct' CHECK (order_type IN ('direct', 'insurance')),
    subtotal DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'cancelled', 'refunded')),
    payment_status VARCHAR(50) DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'partial', 'refunded')),
    payment_method VARCHAR(50), -- cash, momo, bank_transfer, insurance
    insurance_claim_number VARCHAR(100),
    served_by UUID REFERENCES auth.users(id),
    order_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Order Items Table
CREATE TABLE public.order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT REFERENCES public.orders(id) ON DELETE CASCADE,
    medicine_id BIGINT REFERENCES public.medicines(id),
    medicine_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    batch_number VARCHAR(100),
    expiry_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. Stock Movements Table
CREATE TABLE public.stock_movements (
    id BIGSERIAL PRIMARY KEY,
    medicine_id BIGINT REFERENCES public.medicines(id) ON DELETE CASCADE,
    medicine_name VARCHAR(255) NOT NULL,
    movement_type VARCHAR(50) NOT NULL CHECK (movement_type IN ('in', 'out', 'adjustment', 'return', 'expired', 'damaged')),
    quantity INTEGER NOT NULL,
    previous_stock INTEGER DEFAULT 0,
    new_stock INTEGER DEFAULT 0,
    reason VARCHAR(255) NOT NULL,
    reference_type VARCHAR(50), -- 'order', 'purchase', 'adjustment', 'return'
    reference_id BIGINT,
    unit_cost DECIMAL(10,2),
    total_cost DECIMAL(10,2),
    supplier_id BIGINT REFERENCES public.suppliers(id),
    batch_number VARCHAR(100),
    expiry_date DATE,
    notes TEXT,
    movement_date DATE DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 11. Purchase Orders Table
CREATE TABLE public.purchase_orders (
    id BIGSERIAL PRIMARY KEY,
    po_number VARCHAR(50) UNIQUE NOT NULL,
    supplier_id BIGINT REFERENCES public.suppliers(id),
    order_date DATE DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    subtotal DECIMAL(12,2) DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'confirmed', 'partial_received', 'received', 'cancelled')),
    payment_status VARCHAR(50) DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'paid', 'partial')),
    payment_terms VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 12. Purchase Order Items Table
CREATE TABLE public.purchase_order_items (
    id BIGSERIAL PRIMARY KEY,
    po_id BIGINT REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
    medicine_id BIGINT REFERENCES public.medicines(id),
    medicine_name VARCHAR(255) NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    quantity_received INTEGER DEFAULT 0,
    unit_cost DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(10,2) NOT NULL,
    batch_number VARCHAR(100),
    expiry_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 13. Audit Log Table
CREATE TABLE public.audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DEACTIVATE', 'ACTIVATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 14. Notifications Table
CREATE TABLE public.notifications (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) DEFAULT 'info' CHECK (notification_type IN ('info', 'warning', 'error', 'success')),
    user_id UUID REFERENCES auth.users(id),
    target_role VARCHAR(20) CHECK (target_role IN ('admin', 'receptionist', 'customer', 'all')),
    related_to VARCHAR(50), -- 'medicine', 'order', 'purchase_order', 'stock'
    related_id BIGINT,
    priority VARCHAR(10) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    action_required BOOLEAN DEFAULT false,
    action_url TEXT,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 15. Daily Sales Summary Table
CREATE TABLE public.daily_sales (
    id BIGSERIAL PRIMARY KEY,
    sale_date DATE UNIQUE NOT NULL DEFAULT CURRENT_DATE,
    total_orders INTEGER DEFAULT 0,
    gross_sales DECIMAL(12,2) DEFAULT 0,
    discounts DECIMAL(12,2) DEFAULT 0,
    tax_collected DECIMAL(12,2) DEFAULT 0,
    net_sales DECIMAL(12,2) DEFAULT 0,
    cash_sales DECIMAL(12,2) DEFAULT 0,
    insurance_sales DECIMAL(12,2) DEFAULT 0,
    momo_sales DECIMAL(12,2) DEFAULT 0,
    bank_sales DECIMAL(12,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- POS ANALYTICS SYSTEM FOR HEALTHCARE FACILITIES
-- =============================================

-- 1. Staff Shifts Tracking Table
CREATE TABLE public.staff_shifts (
    id BIGSERIAL PRIMARY KEY,
    staff_id UUID REFERENCES auth.users(id),
    shift_date DATE DEFAULT CURRENT_DATE,
    shift_type VARCHAR(20) DEFAULT 'full_day', -- morning, afternoon, evening, night, full_day
    clock_in_time TIMESTAMP WITH TIME ZONE,
    clock_out_time TIMESTAMP WITH TIME ZONE,
    planned_hours DECIMAL(4,2) DEFAULT 8.0,
    actual_hours DECIMAL(4,2),
    break_duration INTEGER DEFAULT 60, -- minutes
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Staff Performance Metrics Table
CREATE TABLE public.staff_performance (
    id BIGSERIAL PRIMARY KEY,
    staff_id UUID REFERENCES auth.users(id),
    shift_id BIGINT REFERENCES public.staff_shifts(id),
    performance_date DATE DEFAULT CURRENT_DATE,
    orders_processed INTEGER DEFAULT 0,
    total_sales_amount DECIMAL(12,2) DEFAULT 0,
    average_transaction_time INTEGER DEFAULT 0, -- seconds
    customer_count INTEGER DEFAULT 0,
    returns_handled INTEGER DEFAULT 0,
    errors_made INTEGER DEFAULT 0,
    medicines_dispensed INTEGER DEFAULT 0,
    cash_handled DECIMAL(12,2) DEFAULT 0,
    accuracy_rate DECIMAL(5,2) DEFAULT 100.0, -- percentage
    efficiency_score DECIMAL(5,2) DEFAULT 0, -- calculated score
    customer_rating DECIMAL(3,2) DEFAULT 0, -- if applicable
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Transaction Performance Tracking
CREATE TABLE public.transaction_performance (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT REFERENCES public.orders(id),
    staff_id UUID REFERENCES auth.users(id),
    transaction_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transaction_end_time TIMESTAMP WITH TIME ZONE,
    processing_duration INTEGER, -- seconds
    items_count INTEGER DEFAULT 0,
    complexity_score INTEGER DEFAULT 1, -- 1-5 scale
    customer_wait_time INTEGER DEFAULT 0,
    was_error BOOLEAN DEFAULT false,
    error_type VARCHAR(100),
    was_returned BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Cash Register Sessions
CREATE TABLE public.cash_register_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(50) UNIQUE NOT NULL,
    staff_id UUID REFERENCES auth.users(id),
    shift_id BIGINT REFERENCES public.staff_shifts(id),
    session_date DATE DEFAULT CURRENT_DATE,
    opening_balance DECIMAL(12,2) DEFAULT 0,
    closing_balance DECIMAL(12,2) DEFAULT 0,
    total_cash_sales DECIMAL(12,2) DEFAULT 0,
    total_transactions INTEGER DEFAULT 0,
    cash_variance DECIMAL(12,2) DEFAULT 0, -- difference between expected and actual
    session_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end_time TIMESTAMP WITH TIME ZONE,
    is_balanced BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Daily POS Summary
CREATE TABLE public.daily_pos_summary (
    id BIGSERIAL PRIMARY KEY,
    summary_date DATE UNIQUE DEFAULT CURRENT_DATE,
    total_transactions INTEGER DEFAULT 0,
    gross_sales DECIMAL(12,2) DEFAULT 0,
    net_sales DECIMAL(12,2) DEFAULT 0,
    cash_sales DECIMAL(12,2) DEFAULT 0,
    insurance_sales DECIMAL(12,2) DEFAULT 0,
    momo_sales DECIMAL(12,2) DEFAULT 0,
    bank_sales DECIMAL(12,2) DEFAULT 0,
    returns_amount DECIMAL(12,2) DEFAULT 0,
    discounts_given DECIMAL(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    staff_on_duty INTEGER DEFAULT 0,
    peak_hour_start TIME,
    peak_hour_end TIME,
    average_transaction_time INTEGER DEFAULT 0,
    medicines_sold_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- =============================================
-- ENABLE ROW LEVEL SECURITY
-- =============================================

ALTER TABLE public.facility_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.receptionists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_sales ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS POLICIES
-- =============================================

-- Admin full access
CREATE POLICY "Admins have full access to facility_settings" ON public.facility_settings
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE POLICY "Admins have full access to user_profiles" ON public.user_profiles
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE POLICY "Admins have full access to receptionists" ON public.receptionists
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE POLICY "Admins have full access to audit_log" ON public.audit_log
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE POLICY "Admins have full access to daily_sales" ON public.daily_sales
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

-- Facility settings view access
CREATE POLICY "Authenticated users can view facility settings" ON public.facility_settings
    FOR SELECT USING (auth.role() = 'authenticated');

-- User profile access
CREATE POLICY "Users can view their own profile" ON public.user_profiles
    FOR SELECT USING (auth.uid() = id AND is_active = true);

CREATE POLICY "Users can update their own profile" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = id AND is_active = true);

-- Medicine categories access
CREATE POLICY "Staff can view active medicine categories" ON public.medicine_categories
    FOR SELECT USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Staff can manage medicine categories" ON public.medicine_categories
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Medicines access
CREATE POLICY "Staff can view active medicines" ON public.medicines
    FOR SELECT USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Staff can manage medicines" ON public.medicines
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Staff can update medicines" ON public.medicines
    FOR UPDATE USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Suppliers access
CREATE POLICY "Staff can access active suppliers" ON public.suppliers
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Customers access
CREATE POLICY "Staff can access active customers" ON public.customers
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Users can view their own customer record" ON public.customers
    FOR SELECT USING (user_id = auth.uid() AND is_active = true);

-- Orders access
CREATE POLICY "Staff can access active orders" ON public.orders
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Customers can view their own active orders" ON public.orders
    FOR SELECT USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.customers WHERE id = orders.customer_id AND user_id = auth.uid() AND is_active = true)
    );

-- Order items access
CREATE POLICY "Staff can access active order items" ON public.order_items
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Stock movements access
CREATE POLICY "Staff can access active stock movements" ON public.stock_movements
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Purchase orders access
CREATE POLICY "Staff can access active purchase orders" ON public.purchase_orders
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Purchase order items access
CREATE POLICY "Staff can access active purchase order items" ON public.purchase_order_items
    FOR ALL USING (
        is_active = true AND
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

-- Notifications access
CREATE POLICY "Users can view their notifications" ON public.notifications
    FOR SELECT USING (
        is_active = true AND (
            user_id = auth.uid() OR
            target_role = (SELECT role FROM public.user_profiles WHERE id = auth.uid()) OR
            target_role = 'all'
        )
    );

CREATE POLICY "Users can update their notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid() AND is_active = true);

-- =============================================
-- UTILITY FUNCTIONS
-- =============================================

-- Generate unique IDs
CREATE OR REPLACE FUNCTION generate_unique_id(prefix TEXT, table_name TEXT, column_name TEXT)
RETURNS TEXT AS $$
DECLARE
    new_id TEXT;
    counter INTEGER := 1;
    year_suffix TEXT := TO_CHAR(NOW(), 'YY');
BEGIN
    LOOP
        new_id := prefix || year_suffix || LPAD(counter::text, 4, '0');
        EXECUTE format('SELECT 1 FROM public.%I WHERE %I = $1 AND is_active = true', table_name, column_name) 
        USING new_id;
        IF NOT FOUND THEN
            RETURN new_id;
        END IF;
        counter := counter + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Audit logging
CREATE OR REPLACE FUNCTION log_audit_action()
RETURNS TRIGGER AS $$
DECLARE
    changes_json JSONB := '{}';
    old_json JSONB;
    new_json JSONB;
    key TEXT;
    old_val JSONB;
    new_val JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, new_values, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), auth.uid());
    ELSIF TG_OP = 'UPDATE' THEN
        -- Calculate changes manually
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);
        
        -- Compare each field
        FOR key IN SELECT jsonb_object_keys(new_json)
        LOOP
            old_val := old_json -> key;
            new_val := new_json -> key;
            
            -- If values are different, add to changes
            IF old_val IS DISTINCT FROM new_val THEN
                changes_json := changes_json || jsonb_build_object(key, jsonb_build_object('old', old_val, 'new', new_val));
            END IF;
        END LOOP;
        
        INSERT INTO public.audit_log (table_name, record_id, action, old_values, new_values, changes, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', old_json, new_json, changes_json, auth.uid());
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, old_values, created_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), auth.uid());
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Deactivate record
CREATE OR REPLACE FUNCTION deactivate_record(p_table_name TEXT, p_record_id BIGINT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('UPDATE public.%I SET is_active = false WHERE id = $1', p_table_name) 
    USING p_record_id;
    INSERT INTO public.audit_log (table_name, record_id, action, changes, created_by)
    VALUES (p_table_name, p_record_id, 'DEACTIVATE', jsonb_build_object('is_active', false), auth.uid());
END;
$$ LANGUAGE plpgsql;

-- Activate record
CREATE OR REPLACE FUNCTION activate_record(p_table_name TEXT, p_record_id BIGINT)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('UPDATE public.%I SET is_active = true WHERE id = $1', p_table_name) 
    USING p_record_id;
    INSERT INTO public.audit_log (table_name, record_id, action, changes, created_by)
    VALUES (p_table_name, p_record_id, 'ACTIVATE', jsonb_build_object('is_active', true), auth.uid());
END;
$$ LANGUAGE plpgsql;

-- Update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create role-specific records
CREATE OR REPLACE FUNCTION create_role_specific_record()
RETURNS TRIGGER AS $$
DECLARE
    user_email TEXT;
BEGIN
    SELECT email INTO user_email FROM auth.users WHERE id = NEW.id;
    IF NEW.role = 'receptionist' THEN
        INSERT INTO public.receptionists (user_id, employee_id, full_name, phone, email, created_by)
        VALUES (NEW.id, generate_unique_id('EMP', 'receptionists', 'employee_id'), NEW.full_name, NEW.phone, user_email, NEW.created_by);
    ELSIF NEW.role = 'customer' THEN
        INSERT INTO public.customers (user_id, customer_id, name, phone, email, created_by)
        VALUES (NEW.id, generate_unique_id('CUS', 'customers', 'customer_id'), NEW.full_name, NEW.phone, user_email, NEW.created_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update medicine stock
CREATE OR REPLACE FUNCTION update_medicine_stock()
RETURNS TRIGGER AS $$
DECLARE
    medicine_record RECORD;
BEGIN
    SELECT * INTO medicine_record FROM public.medicines WHERE id = NEW.medicine_id;
    NEW.previous_stock := medicine_record.stock;
    IF NEW.movement_type = 'in' THEN
        NEW.new_stock := medicine_record.stock + NEW.quantity;
        UPDATE public.medicines SET stock = stock + NEW.quantity WHERE id = NEW.medicine_id;
    ELSIF NEW.movement_type = 'out' THEN
        NEW.new_stock := medicine_record.stock - NEW.quantity;
        UPDATE public.medicines SET stock = stock - NEW.quantity WHERE id = NEW.medicine_id;
    ELSIF NEW.movement_type IN ('expired', 'damaged', 'return') THEN
        NEW.new_stock := medicine_record.stock - NEW.quantity;
        UPDATE public.medicines SET stock = stock - NEW.quantity WHERE id = NEW.medicine_id;
    ELSIF NEW.movement_type = 'adjustment' THEN
        NEW.new_stock := NEW.quantity;
        UPDATE public.medicines SET stock = NEW.quantity WHERE id = NEW.medicine_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update customer stats
CREATE OR REPLACE FUNCTION update_customer_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.customers 
    SET 
        total_purchases = (
            SELECT COUNT(*) FROM public.orders 
            WHERE customer_id = NEW.customer_id AND is_active = true AND status = 'completed'
        ),
        total_spent = (
            SELECT COALESCE(SUM(total_amount), 0) FROM public.orders 
            WHERE customer_id = NEW.customer_id AND is_active = true AND status = 'completed'
        ),
        last_purchase = CURRENT_DATE
    WHERE id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update daily sales
CREATE OR REPLACE FUNCTION update_daily_sales()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.daily_sales (sale_date, total_orders, gross_sales, net_sales)
    VALUES (
        CURRENT_DATE,
        1,
        NEW.total_amount,
        NEW.total_amount
    )
    ON CONFLICT (sale_date)
    DO UPDATE SET
        total_orders = daily_sales.total_orders + 1,
        gross_sales = daily_sales.gross_sales + NEW.total_amount,
        net_sales = daily_sales.net_sales + NEW.total_amount,
        updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update order total
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.orders 
    SET 
        subtotal = (
            SELECT COALESCE(SUM(total_price), 0) 
            FROM public.order_items 
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id) AND is_active = true
        ),
        total_amount = (
            SELECT COALESCE(SUM(total_price), 0) 
            FROM public.order_items 
            WHERE order_id = COALESCE(NEW.order_id, OLD.order_id) AND is_active = true
        )
    WHERE id = COALESCE(NEW.order_id, OLD.order_id) AND is_active = true;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Update purchase order total
CREATE OR REPLACE FUNCTION update_purchase_order_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.purchase_orders 
    SET 
        subtotal = (
            SELECT COALESCE(SUM(total_cost), 0) 
            FROM public.purchase_order_items 
            WHERE po_id = COALESCE(NEW.po_id, OLD.po_id) AND is_active = true
        ),
        total_amount = (
            SELECT COALESCE(SUM(total_cost), 0) 
            FROM public.purchase_order_items 
            WHERE po_id = COALESCE(NEW.po_id, OLD.po_id) AND is_active = true
        )
    WHERE id = COALESCE(NEW.po_id, OLD.po_id) AND is_active = true;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGERS
-- =============================================

-- Audit triggers
CREATE TRIGGER audit_facility_settings AFTER INSERT OR UPDATE OR DELETE ON public.facility_settings FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_user_profiles AFTER INSERT OR UPDATE OR DELETE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_receptionists AFTER INSERT OR UPDATE OR DELETE ON public.receptionists FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_suppliers AFTER INSERT OR UPDATE OR DELETE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_medicines AFTER INSERT OR UPDATE OR DELETE ON public.medicines FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_customers AFTER INSERT OR UPDATE OR DELETE ON public.customers FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_orders AFTER INSERT OR UPDATE OR DELETE ON public.orders FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_purchase_orders AFTER INSERT OR UPDATE OR DELETE ON public.purchase_orders FOR EACH ROW EXECUTE FUNCTION log_audit_action();
CREATE TRIGGER audit_stock_movements AFTER INSERT OR UPDATE OR DELETE ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION log_audit_action();

-- Updated_at triggers
CREATE TRIGGER update_facility_settings_updated_at BEFORE UPDATE ON public.facility_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_receptionists_updated_at BEFORE UPDATE ON public.receptionists FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_suppliers_updated_at BEFORE UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_medicines_updated_at BEFORE UPDATE ON public.medicines FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_purchase_orders_updated_at BEFORE UPDATE ON public.purchase_orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_stock_movements_updated_at BEFORE UPDATE ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_daily_sales_updated_at BEFORE UPDATE ON public.daily_sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Role-specific record creation
CREATE TRIGGER create_role_record AFTER INSERT ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION create_role_specific_record();

-- Generate unique numbers
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number := 'ORD' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEW.id::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.po_number IS NULL THEN
        NEW.po_number := 'PO' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEW.id::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_order_number_trigger BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION generate_order_number();
CREATE TRIGGER generate_po_number_trigger BEFORE INSERT ON public.purchase_orders FOR EACH ROW EXECUTE FUNCTION generate_po_number();

-- Order and purchase order totals
CREATE TRIGGER update_order_total_trigger AFTER INSERT OR UPDATE OR DELETE ON public.order_items FOR EACH ROW EXECUTE FUNCTION update_order_total();
CREATE TRIGGER update_purchase_order_total_trigger AFTER INSERT OR UPDATE OR DELETE ON public.purchase_order_items FOR EACH ROW EXECUTE FUNCTION update_purchase_order_total();

-- Stock movement
CREATE TRIGGER update_medicine_stock_trigger BEFORE INSERT ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION update_medicine_stock();

-- Customer stats
CREATE TRIGGER update_customer_stats_order AFTER UPDATE ON public.orders FOR EACH ROW 
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed') 
    EXECUTE FUNCTION update_customer_stats();

-- Daily sales
CREATE TRIGGER update_daily_sales_trigger AFTER UPDATE ON public.orders FOR EACH ROW 
    WHEN (NEW.status = 'completed' AND OLD.status != 'completed') 
    EXECUTE FUNCTION update_daily_sales();

-- Notifications for low stock
CREATE OR REPLACE FUNCTION check_low_stock_and_notify()
RETURNS TRIGGER AS $$
DECLARE
    medicine_record RECORD;
BEGIN
    SELECT * INTO medicine_record FROM public.medicines WHERE id = NEW.medicine_id;
    IF NEW.new_stock <= medicine_record.min_stock_level AND NEW.movement_type = 'out' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications 
            WHERE related_to = 'medicine' 
            AND related_id = NEW.medicine_id 
            AND is_read = false 
            AND is_active = true
            AND title = 'Low Stock Alert'
            AND created_at > CURRENT_DATE - INTERVAL '1 day'
        ) THEN
            INSERT INTO public.notifications (title, message, notification_type, target_role, related_to, related_id, priority)
            VALUES (
                'Low Stock Alert',
                'Medicine "' || NEW.medicine_name || '" is running low. Current stock: ' || NEW.new_stock || ' units (Min: ' || medicine_record.min_stock_level || ')',
                'warning',
                'admin',
                'medicine',
                NEW.medicine_id,
                'high'
            );
        END IF;
    END IF;
    IF NEW.new_stock = 0 AND NEW.movement_type = 'out' THEN
        INSERT INTO public.notifications (title, message, notification_type, target_role, related_to, related_id, priority)
        VALUES (
            'Out of Stock Alert',
            'Medicine "' || NEW.medicine_name || '" is now out of stock!',
            'error',
            'admin',
            'medicine',
            NEW.medicine_id,
            'urgent'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER low_stock_notification_trigger AFTER INSERT ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION check_low_stock_and_notify();

-- Medicine expiry notifications
CREATE OR REPLACE FUNCTION check_medicine_expiry()
RETURNS void AS $$
BEGIN
    INSERT INTO public.notifications (title, message, notification_type, target_role, related_to, related_id, priority)
    SELECT 
        'Medicine Expiry Alert',
        'Medicine "' || name || '" will expire on ' || TO_CHAR(expiry_date, 'YYYY-MM-DD') || '. Current stock: ' || stock || ' units.',
        'warning',
        'admin',
        'medicine',
        id,
        'high'
    FROM public.medicines
    WHERE expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    AND is_active = true
    AND stock > 0
    AND NOT EXISTS (
        SELECT 1 FROM public.notifications 
        WHERE related_to = 'medicine' 
        AND related_id = medicines.id 
        AND title = 'Medicine Expiry Alert'
        AND is_read = false 
        AND is_active = true
        AND created_at > CURRENT_DATE - INTERVAL '7 days'
    );
    INSERT INTO public.notifications (title, message, notification_type, target_role, related_to, related_id, priority)
    SELECT 
        'Expired Medicine Alert',
        'Medicine "' || name || '" expired on ' || TO_CHAR(expiry_date, 'YYYY-MM-DD') || '. Current stock: ' || stock || ' units. Please remove from inventory.',
        'error',
        'admin',
        'medicine',
        id,
        'urgent'
    FROM public.medicines
    WHERE expiry_date < CURRENT_DATE
    AND is_active = true
    AND stock > 0
    AND NOT EXISTS (
        SELECT 1 FROM public.notifications 
        WHERE related_to = 'medicine' 
        AND related_id = medicines.id 
        AND title = 'Expired Medicine Alert'
        AND is_read = false 
        AND is_active = true
        AND created_at > CURRENT_DATE - INTERVAL '1 day'
    );
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- PERFORMANCE INDEXES
-- =============================================

CREATE INDEX idx_facility_settings_type ON public.facility_settings(facility_type);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role) WHERE is_active = true;
CREATE INDEX idx_user_profiles_username ON public.user_profiles(username) WHERE is_active = true;
CREATE INDEX idx_user_profiles_active ON public.user_profiles(is_active);
CREATE INDEX idx_receptionists_user_id ON public.receptionists(user_id) WHERE is_active = true;
CREATE INDEX idx_receptionists_employee_id ON public.receptionists(employee_id) WHERE is_active = true;
CREATE INDEX idx_suppliers_code ON public.suppliers(supplier_code) WHERE is_active = true;
CREATE INDEX idx_suppliers_name ON public.suppliers(name) WHERE is_active = true;
CREATE INDEX idx_medicine_categories_name ON public.medicine_categories(name) WHERE is_active = true;
CREATE INDEX idx_medicines_code ON public.medicines(medicine_code) WHERE is_active = true;
CREATE INDEX idx_medicines_name ON public.medicines(name) WHERE is_active = true;
CREATE INDEX idx_medicines_category ON public.medicines(category_id) WHERE is_active = true;
CREATE INDEX idx_medicines_stock ON public.medicines(stock) WHERE is_active = true;
CREATE INDEX idx_medicines_expiry ON public.medicines(expiry_date) WHERE is_active = true;
CREATE INDEX idx_medicines_supplier ON public.medicines(supplier_id) WHERE is_active = true;
CREATE INDEX idx_customers_user_id ON public.customers(user_id) WHERE is_active = true;
CREATE INDEX idx_customers_customer_id ON public.customers(customer_id) WHERE is_active = true;
CREATE INDEX idx_customers_name ON public.customers(name) WHERE is_active = true;
CREATE INDEX idx_orders_customer_id ON public.orders(customer_id) WHERE is_active = true;
CREATE INDEX idx_orders_date ON public.orders(order_date) WHERE is_active = true;
CREATE INDEX idx_orders_status ON public.orders(status) WHERE is_active = true;
CREATE INDEX idx_orders_payment_status ON public.orders(payment_status) WHERE is_active = true;
CREATE INDEX idx_stock_movements_medicine_id ON public.stock_movements(medicine_id) WHERE is_active = true;
CREATE INDEX idx_stock_movements_date ON public.stock_movements(movement_date) WHERE is_active = true;
CREATE INDEX idx_stock_movements_type ON public.stock_movements(movement_type) WHERE is_active = true;
CREATE INDEX idx_purchase_orders_supplier_id ON public.purchase_orders(supplier_id) WHERE is_active = true;
CREATE INDEX idx_purchase_orders_date ON public.purchase_orders(order_date) WHERE is_active = true;
CREATE INDEX idx_purchase_orders_status ON public.purchase_orders(status) WHERE is_active = true;
CREATE INDEX idx_audit_log_table_record ON public.audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_created_at ON public.audit_log(created_at);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id) WHERE is_active = true;
CREATE INDEX idx_notifications_target_role ON public.notifications(target_role) WHERE is_active = true;
CREATE INDEX idx_notifications_related ON public.notifications(related_to, related_id) WHERE is_active = true;
CREATE INDEX idx_daily_sales_date ON public.daily_sales(sale_date);

-- =============================================
-- VIEWS FOR REPORTING
-- =============================================

CREATE VIEW vw_medicines_stock_status AS
SELECT 
    m.*,
    c.name as category_name,
    s.name as supplier_name,
    CASE 
        WHEN m.stock = 0 THEN 'Out of Stock'
        WHEN m.stock <= m.min_stock_level THEN 'Low Stock'
        WHEN m.expiry_date <= CURRENT_DATE THEN 'Expired'
        WHEN m.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
        WHEN m.stock >= m.max_stock_level THEN 'Overstock'
        ELSE 'Good'
    END as stock_status,
    (m.selling_price - m.cost_price) as profit_margin
FROM public.medicines m
LEFT JOIN public.medicine_categories c ON m.category_id = c.id
LEFT JOIN public.suppliers s ON m.supplier_id = s.id
WHERE m.is_active = true;

CREATE VIEW vw_customer_summary AS
SELECT 
    c.*,
    COUNT(DISTINCT o.id) as total_orders,
    COALESCE(MAX(o.order_date), c.last_purchase) as last_purchase_date,
    CASE 
        WHEN c.total_spent > 100000 THEN 'VIP'
        WHEN c.total_spent > 50000 THEN 'Regular'
        WHEN c.total_purchases > 5 THEN 'Frequent'
        ELSE 'New'
    END as customer_category
FROM public.customers c
LEFT JOIN public.orders o ON c.id = o.customer_id AND o.is_active = true
WHERE c.is_active = true
GROUP BY c.id;

CREATE VIEW vw_sales_summary AS
SELECT 
    DATE_TRUNC('month', o.order_date) as month,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_sales,
    AVG(o.total_amount) as average_order_value,
    COUNT(DISTINCT o.customer_id) as unique_customers
FROM public.orders o
WHERE o.is_active = true AND o.status = 'completed'
GROUP BY DATE_TRUNC('month', o.order_date)
ORDER BY month DESC;

CREATE VIEW vw_stock_movements_analysis AS
SELECT 
    m.name as medicine_name,
    m.medicine_code,
    SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END) as total_received,
    SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END) as total_sold,
    SUM(CASE WHEN sm.movement_type = 'expired' THEN sm.quantity ELSE 0 END) as total_expired,
    SUM(CASE WHEN sm.movement_type = 'damaged' THEN sm.quantity ELSE 0 END) as total_damaged,
    m.stock as current_stock
FROM public.medicines m
LEFT JOIN public.stock_movements sm ON m.id = sm.medicine_id AND sm.is_active = true
WHERE m.is_active = true
GROUP BY m.id, m.name, m.medicine_code, m.stock;

-- =============================================
-- INITIAL DATA SETUP
-- =============================================

INSERT INTO public.medicine_categories (name, description) VALUES
('Analgesics', 'Pain relief medications'),
('Antibiotics', 'Bacterial infection treatments'),
('Antihypertensives', 'Blood pressure medications'),
('Antidiabetics', 'Diabetes management medications'),
('Vitamins & Supplements', 'Nutritional supplements'),
('Respiratory', 'Cough, cold, and respiratory medications'),
('Gastrointestinal', 'Digestive system medications'),
('Dermatological', 'Skin condition treatments');

-- Grant permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- =============================================
-- MAINTENANCE PROCEDURES
-- =============================================

CREATE OR REPLACE FUNCTION run_daily_maintenance()
RETURNS void AS $$
BEGIN
    PERFORM check_medicine_expiry();
    UPDATE public.notifications 
    SET is_active = false 
    WHERE is_read = true 
    AND read_at < CURRENT_DATE - INTERVAL '30 days'
    AND is_active = true;
    UPDATE public.notifications 
    SET is_active = false 
    WHERE expires_at IS NOT NULL 
    AND expires_at < NOW()
    AND is_active = true;
    UPDATE public.customers 
    SET last_purchase = (
        SELECT MAX(o.order_date)
        FROM public.orders o
        WHERE o.customer_id = customers.id
        AND o.is_active = true
    )
    WHERE is_active = true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_sales_report(
    start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    report_date DATE,
    total_orders BIGINT,
    gross_sales DECIMAL(12,2),
    net_sales DECIMAL(12,2),
    top_selling_medicine TEXT,
    top_selling_quantity BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_stats AS (
        SELECT 
            ds.sale_date,
            ds.total_orders,
            ds.gross_sales,
            ds.net_sales
        FROM public.daily_sales ds
        WHERE ds.sale_date BETWEEN start_date AND end_date
    ),
    top_medicines AS (
        SELECT 
            oi.order_date,
            oi.medicine_name,
            SUM(oi.quantity) as total_quantity,
            ROW_NUMBER() OVER (PARTITION BY oi.order_date ORDER BY SUM(oi.quantity) DESC) as rn
        FROM (
            SELECT 
                o.order_date,
                oi.medicine_name,
                oi.quantity
            FROM public.orders o
            JOIN public.order_items oi ON o.id = oi.order_id
            WHERE o.order_date BETWEEN start_date AND end_date
            AND o.is_active = true AND oi.is_active = true
            AND o.status = 'completed'
        ) oi
        GROUP BY oi.order_date, oi.medicine_name
    )
    SELECT 
        ds.sale_date,
        COALESCE(ds.total_orders, 0),
        COALESCE(ds.gross_sales, 0),
        COALESCE(ds.net_sales, 0),
        COALESCE(tm.medicine_name, 'N/A'),
        COALESCE(tm.total_quantity, 0)
    FROM daily_stats ds
    LEFT JOIN top_medicines tm ON ds.sale_date = tm.order_date AND tm.rn = 1
    ORDER BY ds.sale_date;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_low_stock_medicines()
RETURNS TABLE(
    medicine_id BIGINT,
    medicine_code VARCHAR(50),
    medicine_name VARCHAR(255),
    current_stock INTEGER,
    min_stock_level INTEGER,
    days_until_out INTEGER,
    supplier_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.medicine_code,
        m.name,
        m.stock,
        m.min_stock_level,
        CASE 
            WHEN avg_daily_usage.daily_avg > 0 
            THEN (m.stock / avg_daily_usage.daily_avg)::INTEGER
            ELSE 999
        END as days_until_out,
        s.name as supplier_name
    FROM public.medicines m
    LEFT JOIN public.suppliers s ON m.supplier_id = s.id
    LEFT JOIN (
        SELECT 
            medicine_id,
            AVG(quantity) as daily_avg
        FROM public.stock_movements
        WHERE movement_type = 'out'
        AND movement_date >= CURRENT_DATE - INTERVAL '30 days'
        AND is_active = true
        GROUP BY medicine_id
    ) avg_daily_usage ON m.id = avg_daily_usage.medicine_id
    WHERE m.is_active = true
    AND m.stock <= m.min_stock_level
    ORDER BY m.stock ASC, days_until_out ASC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_expiring_medicines(days_ahead INTEGER DEFAULT 90)
RETURNS TABLE(
    medicine_id BIGINT,
    medicine_code VARCHAR(50),
    medicine_name VARCHAR(255),
    batch_number VARCHAR(100),
    expiry_date DATE,
    days_until_expiry INTEGER,
    current_stock INTEGER,
    estimated_value DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.medicine_code,
        m.name,
        m.batch_number,
        m.expiry_date,
        (m.expiry_date - CURRENT_DATE)::INTEGER as days_until_expiry,
        m.stock,
        (m.stock * m.cost_price) as estimated_value
    FROM public.medicines m
    WHERE m.is_active = true
    AND m.expiry_date IS NOT NULL
    AND m.expiry_date <= CURRENT_DATE + INTERVAL '1 day' * days_ahead
    AND m.stock > 0
    ORDER BY m.expiry_date ASC, estimated_value DESC;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- INITIAL SETUP
-- =============================================

INSERT INTO public.facility_settings (
    facility_name, 
    facility_type, 
    license_number, 
    phone, 
    email, 
    address, 
    city, 
    province, 
    country,
    currency,
    business_hours
) VALUES (
    'Sample Pharmacy', 
    'pharmacy', 
    'PH-001-2024', 
    '+250788000000', 
    'info@samplepharmacy.rw', 
    'KN 15 St, Sample District', 
    'Kigali', 
    'Kigali City', 
    'Rwanda',
    'RWF',
    '{
        "monday": {"open": "08:00", "close": "17:00"},
        "tuesday": {"open": "08:00", "close": "17:00"},
        "wednesday": {"open": "08:00", "close": "17:00"},
        "thursday": {"open": "08:00", "close": "17:00"},
        "friday": {"open": "08:00", "close": "17:00"},
        "saturday": {"open": "08:00", "close": "13:00"},
        "sunday": {"open": null, "close": null}
    }'::jsonb
) ON CONFLICT DO NOTHING;

-- =============================================
-- SECURITY ENHANCEMENTS
-- =============================================

CREATE OR REPLACE FUNCTION log_user_session()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.user_profiles 
    SET last_login = NOW() 
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE POLICY "Only admins can delete audit logs" ON public.audit_log
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE POLICY "Only admins can modify facility settings" ON public.facility_settings
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

CREATE OR REPLACE FUNCTION check_user_permission(user_role TEXT, required_permission TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    CASE required_permission
        WHEN 'manage_users' THEN
            RETURN user_role = 'admin';
        WHEN 'manage_medicines' THEN
            RETURN user_role IN ('admin', 'receptionist');
        WHEN 'manage_orders' THEN
            RETURN user_role IN ('admin', 'receptionist');
        WHEN 'view_reports' THEN
            RETURN user_role = 'admin';
        WHEN 'manage_suppliers' THEN
            RETURN user_role IN ('admin', 'receptionist');
        ELSE
            RETURN FALSE;
    END CASE;
END;
$$ LANGUAGE plpgsql;


-- =============================================
-- POS ANALYTICS FUNCTIONS
-- =============================================

-- 1. Today's Live Dashboard Metrics
CREATE OR REPLACE FUNCTION get_todays_pos_metrics()
RETURNS JSON AS $$
DECLARE
    metrics JSON;
BEGIN
    SELECT json_build_object(
        'date', CURRENT_DATE,
        'total_orders', COUNT(o.id),
        'total_revenue', COALESCE(SUM(o.total_amount), 0),
        'cash_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'cash' THEN o.total_amount ELSE 0 END), 0),
        'insurance_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'insurance' THEN o.total_amount ELSE 0 END), 0),
        'momo_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'momo' THEN o.total_amount ELSE 0 END), 0),
        'unique_customers', COUNT(DISTINCT o.customer_id),
        'average_order_value', COALESCE(AVG(o.total_amount), 0),
        'items_sold', COALESCE(SUM(oi.quantity), 0),
        'active_staff', (
            SELECT COUNT(DISTINCT staff_id) 
            FROM public.staff_shifts 
            WHERE shift_date = CURRENT_DATE 
            AND clock_out_time IS NULL 
            AND is_active = true
        ),
        'current_hour_sales', (
            SELECT COALESCE(SUM(o2.total_amount), 0)
            FROM public.orders o2 
            WHERE DATE_TRUNC('hour', o2.created_at) = DATE_TRUNC('hour', NOW())
            AND o2.status = 'completed' AND o2.is_active = true
        ),
        'pending_orders', (
            SELECT COUNT(*) 
            FROM public.orders o3 
            WHERE o3.order_date = CURRENT_DATE 
            AND o3.status IN ('pending', 'processing') 
            AND o3.is_active = true
        )
    ) INTO metrics
    FROM public.orders o
    LEFT JOIN public.order_items oi ON o.id = oi.order_id
    WHERE o.order_date = CURRENT_DATE
    AND o.status = 'completed' AND o.is_active = true;
    
    RETURN metrics;
END;
$$ LANGUAGE plpgsql;

-- 2. Staff Performance Analysis
CREATE OR REPLACE FUNCTION get_staff_performance_analysis(
    analysis_date DATE DEFAULT CURRENT_DATE,
    period_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    staff_id UUID,
    staff_name VARCHAR(255),
    days_worked INTEGER,
    total_hours_worked DECIMAL(10,2),
    total_orders INTEGER,
    total_sales DECIMAL(12,2),
    average_order_value DECIMAL(10,2),
    orders_per_hour DECIMAL(10,2),
    sales_per_hour DECIMAL(12,2),
    average_transaction_time INTEGER,
    accuracy_rate DECIMAL(5,2),
    customer_per_day DECIMAL(10,2),
    efficiency_rank INTEGER,
    performance_grade VARCHAR(2)
) AS $$
BEGIN
    RETURN QUERY
    WITH staff_metrics AS (
        SELECT 
            up.id as staff_id,
            up.full_name as staff_name,
            COUNT(DISTINCT ss.shift_date) as days_worked,
            COALESCE(SUM(ss.actual_hours), 0) as total_hours_worked,
            COUNT(o.id) as total_orders,
            COALESCE(SUM(o.total_amount), 0) as total_sales,
            COALESCE(AVG(o.total_amount), 0) as average_order_value,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN COUNT(o.id)::DECIMAL / SUM(ss.actual_hours) 
                ELSE 0 
            END as orders_per_hour,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN COALESCE(SUM(o.total_amount), 0) / SUM(ss.actual_hours) 
                ELSE 0 
            END as sales_per_hour,
            COALESCE(AVG(tp.processing_duration), 0)::INTEGER as average_transaction_time,
            COALESCE(AVG(sp.accuracy_rate), 100) as accuracy_rate,
            CASE 
                WHEN COUNT(DISTINCT ss.shift_date) > 0 
                THEN COUNT(DISTINCT o.customer_id)::DECIMAL / COUNT(DISTINCT ss.shift_date)
                ELSE 0 
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
            WHEN rs.accuracy_rate >= 98 AND rs.sales_per_hour >= 100 THEN 'A+'
            WHEN rs.accuracy_rate >= 95 AND rs.sales_per_hour >= 80 THEN 'A'
            WHEN rs.accuracy_rate >= 90 AND rs.sales_per_hour >= 60 THEN 'B'
            WHEN rs.accuracy_rate >= 85 THEN 'C'
            ELSE 'D'
        END as performance_grade
    FROM ranked_staff rs
    WHERE rs.days_worked > 0
    ORDER BY rs.efficiency_rank;
END;
$$ LANGUAGE plpgsql;

-- 3. Peak Hours Analysis
CREATE OR REPLACE FUNCTION get_peak_hours_analysis(
    analysis_date DATE DEFAULT CURRENT_DATE,
    period_days INTEGER DEFAULT 30
)
RETURNS TABLE(
    hour_of_day INTEGER,
    average_orders DECIMAL(10,2),
    average_revenue DECIMAL(12,2),
    peak_staff_needed INTEGER,
    customer_wait_time INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(HOUR FROM o.created_at)::INTEGER as hour_of_day,
        (COUNT(o.id)::DECIMAL / period_days) as average_orders,
        (COALESCE(SUM(o.total_amount), 0) / period_days) as average_revenue,
        CEIL((COUNT(o.id)::DECIMAL / period_days) / 10)::INTEGER as peak_staff_needed, -- assuming 10 orders per staff per hour
        COALESCE(AVG(tp.customer_wait_time), 0)::INTEGER as customer_wait_time
    FROM public.orders o
    LEFT JOIN public.transaction_performance tp ON o.id = tp.order_id
    WHERE o.order_date BETWEEN analysis_date - INTERVAL '1 day' * period_days AND analysis_date
    AND o.status = 'completed' AND o.is_active = true
    GROUP BY EXTRACT(HOUR FROM o.created_at)
    ORDER BY hour_of_day;
END;
$$ LANGUAGE plpgsql;

-- 4. Daily Cash Reconciliation
CREATE OR REPLACE FUNCTION get_daily_cash_reconciliation(
    reconciliation_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
    reconciliation JSON;
BEGIN
    SELECT json_build_object(
        'date', reconciliation_date,
        'expected_cash', (
            SELECT COALESCE(SUM(o.total_amount), 0)
            FROM public.orders o 
            WHERE o.order_date = reconciliation_date 
            AND o.payment_method = 'cash'
            AND o.status = 'completed' AND o.is_active = true
        ),
        'actual_cash_collected', (
            SELECT COALESCE(SUM(crs.total_cash_sales), 0)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
            AND crs.is_balanced = true
        ),
        'cash_variance', (
            SELECT COALESCE(SUM(crs.cash_variance), 0)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
        ),
        'total_sessions', (
            SELECT COUNT(*)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
        ),
        'unbalanced_sessions', (
            SELECT COUNT(*)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
            AND crs.is_balanced = false
        ),
        'staff_cash_performance', (
            SELECT json_agg(
                json_build_object(
                    'staff_name', up.full_name,
                    'cash_handled', crs.total_cash_sales,
                    'variance', crs.cash_variance,
                    'is_balanced', crs.is_balanced
                )
            )
            FROM public.cash_register_sessions crs
            JOIN public.user_profiles up ON crs.staff_id = up.id
            WHERE crs.session_date = reconciliation_date
        )
    ) INTO reconciliation;
    
    RETURN reconciliation;
END;
$$ LANGUAGE plpgsql;

-- 5. Medicine Dispensing Performance
CREATE OR REPLACE FUNCTION get_medicine_dispensing_performance(
    start_date DATE DEFAULT CURRENT_DATE - INTERVAL '7 days',
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    medicine_name VARCHAR(255),
    total_dispensed BIGINT,
    dispensing_staff_count INTEGER,
    average_per_staff DECIMAL(10,2),
    fastest_dispensing_time INTEGER,
    slowest_dispensing_time INTEGER,
    error_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        oi.medicine_name,
        SUM(oi.quantity) as total_dispensed,
        COUNT(DISTINCT o.served_by) as dispensing_staff_count,
        (SUM(oi.quantity)::DECIMAL / NULLIF(COUNT(DISTINCT o.served_by), 0)) as average_per_staff,
        MIN(tp.processing_duration) as fastest_dispensing_time,
        MAX(tp.processing_duration) as slowest_dispensing_time,
        CASE 
            WHEN COUNT(tp.id) > 0 
            THEN (COUNT(CASE WHEN tp.was_error = true THEN 1 END)::DECIMAL / COUNT(tp.id)) * 100
            ELSE 0 
        END as error_rate
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    LEFT JOIN public.transaction_performance tp ON o.id = tp.order_id
    WHERE o.order_date BETWEEN start_date AND end_date
    AND o.status = 'completed' AND o.is_active = true AND oi.is_active = true
    GROUP BY oi.medicine_name
    HAVING SUM(oi.quantity) > 0
    ORDER BY total_dispensed DESC;
END;
$$ LANGUAGE plpgsql;

-- 6. Shift Handover Report
CREATE OR REPLACE FUNCTION get_shift_handover_report(
    shift_date DATE DEFAULT CURRENT_DATE,
    shift_type VARCHAR(20) DEFAULT 'morning'
)
RETURNS JSON AS $$
DECLARE
    handover_report JSON;
BEGIN
    SELECT json_build_object(
        'shift_info', json_build_object(
            'date', shift_date,
            'shift_type', shift_type,
            'staff_count', COUNT(DISTINCT ss.staff_id),
            'total_hours_planned', SUM(ss.planned_hours),
            'total_hours_worked', SUM(ss.actual_hours)
        ),
        'sales_summary', json_build_object(
            'total_orders', COUNT(o.id),
            'total_revenue', COALESCE(SUM(o.total_amount), 0),
            'cash_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'cash' THEN o.total_amount ELSE 0 END), 0),
            'insurance_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'insurance' THEN o.total_amount ELSE 0 END), 0),
            'unique_customers', COUNT(DISTINCT o.customer_id)
        ),
        'inventory_alerts', (
            SELECT json_agg(
                json_build_object(
                    'medicine_name', m.name,
                    'current_stock', m.stock,
                    'min_level', m.min_stock_level,
                    'status', CASE 
                        WHEN m.stock = 0 THEN 'OUT_OF_STOCK'
                        WHEN m.stock <= m.min_stock_level THEN 'LOW_STOCK'
                        ELSE 'OK'
                    END
                )
            )
            FROM public.medicines m
            WHERE m.stock <= m.min_stock_level AND m.is_active = true
        ),
        'staff_performance', (
            SELECT json_agg(
                json_build_object(
                    'staff_name', up.full_name,
                    'orders_processed', COUNT(o2.id),
                    'sales_amount', COALESCE(SUM(o2.total_amount), 0),
                    'hours_worked', ss2.actual_hours,
                    'performance_rating', CASE 
                        WHEN COUNT(o2.id) > 20 THEN 'Excellent'
                        WHEN COUNT(o2.id) > 15 THEN 'Good'
                        WHEN COUNT(o2.id) > 10 THEN 'Average'
                        ELSE 'Below Average'
                    END
                )
            )
            FROM public.staff_shifts ss2
            JOIN public.user_profiles up ON ss2.staff_id = up.id
            LEFT JOIN public.orders o2 ON ss2.staff_id = o2.served_by 
                AND o2.order_date = shift_date
                AND o2.status = 'completed'
            WHERE ss2.shift_date = shift_date 
            AND ss2.shift_type = shift_type
            AND ss2.is_active = true
            GROUP BY up.full_name, ss2.actual_hours
        )
    ) INTO handover_report
    FROM public.staff_shifts ss
    LEFT JOIN public.orders o ON ss.staff_id = o.served_by 
        AND o.order_date = shift_date
        AND o.status = 'completed' AND o.is_active = true
    WHERE ss.shift_date = shift_date 
    AND ss.shift_type = shift_type
    AND ss.is_active = true;
    
    RETURN handover_report;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGERS FOR AUTOMATIC PERFORMANCE TRACKING
-- =============================================

-- Update staff performance when order is completed
CREATE OR REPLACE FUNCTION update_staff_performance_on_order()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Insert or update staff performance for today
        INSERT INTO public.staff_performance (
            staff_id, performance_date, orders_processed, total_sales_amount, 
            customer_count, medicines_dispensed
        )
        VALUES (
            NEW.served_by, NEW.order_date, 1, NEW.total_amount, 1,
            (SELECT COALESCE(SUM(quantity), 0) FROM public.order_items WHERE order_id = NEW.id)
        )
        ON CONFLICT (staff_id, performance_date) 
        DO UPDATE SET
            orders_processed = staff_performance.orders_processed + 1,
            total_sales_amount = staff_performance.total_sales_amount + NEW.total_amount,
            customer_count = staff_performance.customer_count + 1,
            medicines_dispensed = staff_performance.medicines_dispensed + 
                (SELECT COALESCE(SUM(quantity), 0) FROM public.order_items WHERE order_id = NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_staff_performance_trigger 
    AFTER UPDATE ON public.orders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_staff_performance_on_order();

-- Auto-calculate shift hours
CREATE OR REPLACE FUNCTION calculate_shift_hours()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.clock_out_time IS NOT NULL AND NEW.clock_in_time IS NOT NULL THEN
        NEW.actual_hours := EXTRACT(EPOCH FROM (NEW.clock_out_time - NEW.clock_in_time)) / 3600.0 - (NEW.break_duration / 60.0);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_shift_hours_trigger 
    BEFORE INSERT OR UPDATE ON public.staff_shifts 
    FOR EACH ROW 
    EXECUTE FUNCTION calculate_shift_hours();

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX idx_staff_shifts_date_staff ON public.staff_shifts(shift_date, staff_id);
CREATE INDEX idx_staff_performance_date_staff ON public.staff_performance(performance_date, staff_id);
CREATE INDEX idx_transaction_performance_staff_time ON public.transaction_performance(staff_id, transaction_start_time);
CREATE INDEX idx_cash_register_sessions_date_staff ON public.cash_register_sessions(session_date, staff_id);
CREATE INDEX idx_daily_pos_summary_date ON public.daily_pos_summary(summary_date);

-- Add unique constraint for staff performance per date
ALTER TABLE public.staff_performance ADD CONSTRAINT unique_staff_performance_per_date 
    UNIQUE (staff_id, performance_date);

-- =============================================
-- INITIAL SETUP
-- =============================================

-- Grant permissions for new tables
ALTER TABLE public.staff_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_register_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_pos_summary ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Staff can manage their own shifts" ON public.staff_shifts
    FOR ALL USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Staff can view their own performance" ON public.staff_performance
    FOR SELECT USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist')));

CREATE POLICY "Admins can view all transaction performance" ON public.transaction_performance
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Staff can manage their cash sessions" ON public.cash_register_sessions
    FOR ALL USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Staff can view daily POS summary" ON public.daily_pos_summary
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist'))
    );

-- =============================================
-- POS ANALYTICS SYSTEM FOR HEALTHCARE FACILITIES
-- =============================================

-- 1. Staff Shifts Tracking Table
CREATE TABLE public.staff_shifts (
    id BIGSERIAL PRIMARY KEY,
    staff_id UUID REFERENCES auth.users(id),
    shift_date DATE DEFAULT CURRENT_DATE,
    shift_type VARCHAR(20) DEFAULT 'full_day', -- morning, afternoon, evening, night, full_day
    clock_in_time TIMESTAMP WITH TIME ZONE,
    clock_out_time TIMESTAMP WITH TIME ZONE,
    planned_hours DECIMAL(4,2) DEFAULT 8.0,
    actual_hours DECIMAL(4,2),
    break_duration INTEGER DEFAULT 60, -- minutes
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Staff Performance Metrics Table
CREATE TABLE public.staff_performance (
    id BIGSERIAL PRIMARY KEY,
    staff_id UUID REFERENCES auth.users(id),
    shift_id BIGINT REFERENCES public.staff_shifts(id),
    performance_date DATE DEFAULT CURRENT_DATE,
    orders_processed INTEGER DEFAULT 0,
    total_sales_amount DECIMAL(12,2) DEFAULT 0,
    average_transaction_time INTEGER DEFAULT 0, -- seconds
    customer_count INTEGER DEFAULT 0,
    returns_handled INTEGER DEFAULT 0,
    errors_made INTEGER DEFAULT 0,
    medicines_dispensed INTEGER DEFAULT 0,
    cash_handled DECIMAL(12,2) DEFAULT 0,
    accuracy_rate DECIMAL(5,2) DEFAULT 100.0, -- percentage
    efficiency_score DECIMAL(5,2) DEFAULT 0, -- calculated score
    customer_rating DECIMAL(3,2) DEFAULT 0, -- if applicable
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Transaction Performance Tracking
CREATE TABLE public.transaction_performance (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT REFERENCES public.orders(id),
    staff_id UUID REFERENCES auth.users(id),
    transaction_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transaction_end_time TIMESTAMP WITH TIME ZONE,
    processing_duration INTEGER, -- seconds
    items_count INTEGER DEFAULT 0,
    complexity_score INTEGER DEFAULT 1, -- 1-5 scale
    customer_wait_time INTEGER DEFAULT 0,
    was_error BOOLEAN DEFAULT false,
    error_type VARCHAR(100),
    was_returned BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Cash Register Sessions
CREATE TABLE public.cash_register_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id VARCHAR(50) UNIQUE NOT NULL,
    staff_id UUID REFERENCES auth.users(id),
    shift_id BIGINT REFERENCES public.staff_shifts(id),
    session_date DATE DEFAULT CURRENT_DATE,
    opening_balance DECIMAL(12,2) DEFAULT 0,
    closing_balance DECIMAL(12,2) DEFAULT 0,
    total_cash_sales DECIMAL(12,2) DEFAULT 0,
    total_transactions INTEGER DEFAULT 0,
    cash_variance DECIMAL(12,2) DEFAULT 0, -- difference between expected and actual
    session_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_end_time TIMESTAMP WITH TIME ZONE,
    is_balanced BOOLEAN DEFAULT false,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Daily POS Summary
CREATE TABLE public.daily_pos_summary (
    id BIGSERIAL PRIMARY KEY,
    summary_date DATE UNIQUE DEFAULT CURRENT_DATE,
    total_transactions INTEGER DEFAULT 0,
    gross_sales DECIMAL(12,2) DEFAULT 0,
    net_sales DECIMAL(12,2) DEFAULT 0,
    cash_sales DECIMAL(12,2) DEFAULT 0,
    insurance_sales DECIMAL(12,2) DEFAULT 0,
    momo_sales DECIMAL(12,2) DEFAULT 0,
    bank_sales DECIMAL(12,2) DEFAULT 0,
    returns_amount DECIMAL(12,2) DEFAULT 0,
    discounts_given DECIMAL(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    staff_on_duty INTEGER DEFAULT 0,
    peak_hour_start TIME,
    peak_hour_end TIME,
    average_transaction_time INTEGER DEFAULT 0,
    medicines_sold_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- POS ANALYTICS FUNCTIONS
-- =============================================

-- 1. Today's Live Dashboard Metrics
CREATE OR REPLACE FUNCTION get_todays_pos_metrics()
RETURNS JSON AS $$
DECLARE
    metrics JSON;
BEGIN
    SELECT json_build_object(
        'date', CURRENT_DATE,
        'total_orders', COUNT(o.id),
        'total_revenue', COALESCE(SUM(o.total_amount), 0),
        'cash_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'cash' THEN o.total_amount ELSE 0 END), 0),
        'insurance_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'insurance' THEN o.total_amount ELSE 0 END), 0),
        'momo_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'momo' THEN o.total_amount ELSE 0 END), 0),
        'unique_customers', COUNT(DISTINCT o.customer_id),
        'average_order_value', COALESCE(AVG(o.total_amount), 0),
        'items_sold', COALESCE(SUM(oi.quantity), 0),
        'active_staff', (
            SELECT COUNT(DISTINCT staff_id) 
            FROM public.staff_shifts 
            WHERE shift_date = CURRENT_DATE 
            AND clock_out_time IS NULL 
            AND is_active = true
        ),
        'current_hour_sales', (
            SELECT COALESCE(SUM(o2.total_amount), 0)
            FROM public.orders o2 
            WHERE DATE_TRUNC('hour', o2.created_at) = DATE_TRUNC('hour', NOW())
            AND o2.status = 'completed' AND o2.is_active = true
        ),
        'pending_orders', (
            SELECT COUNT(*) 
            FROM public.orders o3 
            WHERE o3.order_date = CURRENT_DATE 
            AND o3.status IN ('pending', 'processing') 
            AND o3.is_active = true
        )
    ) INTO metrics
    FROM public.orders o
    LEFT JOIN public.order_items oi ON o.id = oi.order_id
    WHERE o.order_date = CURRENT_DATE
    AND o.status = 'completed' AND o.is_active = true;
    
    RETURN metrics;
END;
$$ LANGUAGE plpgsql;

-- 2. Staff Performance Analysis
CREATE OR REPLACE FUNCTION get_staff_performance_analysis(
    analysis_date DATE DEFAULT CURRENT_DATE,
    period_days INTEGER DEFAULT 7
)
RETURNS TABLE(
    staff_id UUID,
    staff_name VARCHAR(255),
    days_worked INTEGER,
    total_hours_worked DECIMAL(10,2),
    total_orders INTEGER,
    total_sales DECIMAL(12,2),
    average_order_value DECIMAL(10,2),
    orders_per_hour DECIMAL(10,2),
    sales_per_hour DECIMAL(12,2),
    average_transaction_time INTEGER,
    accuracy_rate DECIMAL(5,2),
    customer_per_day DECIMAL(10,2),
    efficiency_rank INTEGER,
    performance_grade VARCHAR(2)
) AS $$
BEGIN
    RETURN QUERY
    WITH staff_metrics AS (
        SELECT 
            up.id as staff_id,
            up.full_name as staff_name,
            COUNT(DISTINCT ss.shift_date) as days_worked,
            COALESCE(SUM(ss.actual_hours), 0) as total_hours_worked,
            COUNT(o.id) as total_orders,
            COALESCE(SUM(o.total_amount), 0) as total_sales,
            COALESCE(AVG(o.total_amount), 0) as average_order_value,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN COUNT(o.id)::DECIMAL / SUM(ss.actual_hours) 
                ELSE 0 
            END as orders_per_hour,
            CASE 
                WHEN SUM(ss.actual_hours) > 0 
                THEN COALESCE(SUM(o.total_amount), 0) / SUM(ss.actual_hours) 
                ELSE 0 
            END as sales_per_hour,
            COALESCE(AVG(tp.processing_duration), 0)::INTEGER as average_transaction_time,
            COALESCE(AVG(sp.accuracy_rate), 100) as accuracy_rate,
            CASE 
                WHEN COUNT(DISTINCT ss.shift_date) > 0 
                THEN COUNT(DISTINCT o.customer_id)::DECIMAL / COUNT(DISTINCT ss.shift_date)
                ELSE 0 
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
            WHEN rs.accuracy_rate >= 98 AND rs.sales_per_hour >= (SELECT AVG(sales_per_hour) * 1.2 FROM ranked_staff) THEN 'A+'
            WHEN rs.accuracy_rate >= 95 AND rs.sales_per_hour >= (SELECT AVG(sales_per_hour) * 1.1 FROM ranked_staff) THEN 'A'
            WHEN rs.accuracy_rate >= 90 AND rs.sales_per_hour >= (SELECT AVG(sales_per_hour) FROM ranked_staff) THEN 'B'
            WHEN rs.accuracy_rate >= 85 THEN 'C'
            ELSE 'D'
        END as performance_grade
    FROM ranked_staff rs
    WHERE rs.days_worked > 0
    ORDER BY rs.efficiency_rank;
END;
$$ LANGUAGE plpgsql;

-- 3. Peak Hours Analysis
CREATE OR REPLACE FUNCTION get_peak_hours_analysis(
    analysis_date DATE DEFAULT CURRENT_DATE,
    period_days INTEGER DEFAULT 30
)
RETURNS TABLE(
    hour_of_day INTEGER,
    average_orders DECIMAL(10,2),
    average_revenue DECIMAL(12,2),
    peak_staff_needed INTEGER,
    customer_wait_time INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(HOUR FROM o.created_at)::INTEGER as hour_of_day,
        (COUNT(o.id)::DECIMAL / period_days) as average_orders,
        (COALESCE(SUM(o.total_amount), 0) / period_days) as average_revenue,
        CEIL((COUNT(o.id)::DECIMAL / period_days) / 10)::INTEGER as peak_staff_needed, -- assuming 10 orders per staff per hour
        COALESCE(AVG(tp.customer_wait_time), 0)::INTEGER as customer_wait_time
    FROM public.orders o
    LEFT JOIN public.transaction_performance tp ON o.id = tp.order_id
    WHERE o.order_date BETWEEN analysis_date - INTERVAL '1 day' * period_days AND analysis_date
    AND o.status = 'completed' AND o.is_active = true
    GROUP BY EXTRACT(HOUR FROM o.created_at)
    ORDER BY hour_of_day;
END;
$$ LANGUAGE plpgsql;

-- 4. Daily Cash Reconciliation
CREATE OR REPLACE FUNCTION get_daily_cash_reconciliation(
    reconciliation_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSON AS $$
DECLARE
    reconciliation JSON;
BEGIN
    SELECT json_build_object(
        'date', reconciliation_date,
        'expected_cash', (
            SELECT COALESCE(SUM(o.total_amount), 0)
            FROM public.orders o 
            WHERE o.order_date = reconciliation_date 
            AND o.payment_method = 'cash'
            AND o.status = 'completed' AND o.is_active = true
        ),
        'actual_cash_collected', (
            SELECT COALESCE(SUM(crs.total_cash_sales), 0)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
            AND crs.is_balanced = true
        ),
        'cash_variance', (
            SELECT COALESCE(SUM(crs.cash_variance), 0)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
        ),
        'total_sessions', (
            SELECT COUNT(*)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
        ),
        'unbalanced_sessions', (
            SELECT COUNT(*)
            FROM public.cash_register_sessions crs
            WHERE crs.session_date = reconciliation_date
            AND crs.is_balanced = false
        ),
        'staff_cash_performance', (
            SELECT json_agg(
                json_build_object(
                    'staff_name', up.full_name,
                    'cash_handled', crs.total_cash_sales,
                    'variance', crs.cash_variance,
                    'is_balanced', crs.is_balanced
                )
            )
            FROM public.cash_register_sessions crs
            JOIN public.user_profiles up ON crs.staff_id = up.id
            WHERE crs.session_date = reconciliation_date
        )
    ) INTO reconciliation;
    
    RETURN reconciliation;
END;
$$ LANGUAGE plpgsql;

-- 5. Medicine Dispensing Performance
CREATE OR REPLACE FUNCTION get_medicine_dispensing_performance(
    start_date DATE DEFAULT CURRENT_DATE - INTERVAL '7 days',
    end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE(
    medicine_name VARCHAR(255),
    total_dispensed BIGINT,
    dispensing_staff_count INTEGER,
    average_per_staff DECIMAL(10,2),
    fastest_dispensing_time INTEGER,
    slowest_dispensing_time INTEGER,
    error_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        oi.medicine_name,
        SUM(oi.quantity) as total_dispensed,
        COUNT(DISTINCT o.served_by) as dispensing_staff_count,
        (SUM(oi.quantity)::DECIMAL / NULLIF(COUNT(DISTINCT o.served_by), 0)) as average_per_staff,
        MIN(tp.processing_duration) as fastest_dispensing_time,
        MAX(tp.processing_duration) as slowest_dispensing_time,
        CASE 
            WHEN COUNT(tp.id) > 0 
            THEN (COUNT(CASE WHEN tp.was_error = true THEN 1 END)::DECIMAL / COUNT(tp.id)) * 100
            ELSE 0 
        END as error_rate
    FROM public.order_items oi
    JOIN public.orders o ON oi.order_id = o.id
    LEFT JOIN public.transaction_performance tp ON o.id = tp.order_id
    WHERE o.order_date BETWEEN start_date AND end_date
    AND o.status = 'completed' AND o.is_active = true AND oi.is_active = true
    GROUP BY oi.medicine_name
    HAVING SUM(oi.quantity) > 0
    ORDER BY total_dispensed DESC;
END;
$$ LANGUAGE plpgsql;

-- 6. Shift Handover Report
CREATE OR REPLACE FUNCTION get_shift_handover_report(
    shift_date DATE DEFAULT CURRENT_DATE,
    shift_type VARCHAR(20) DEFAULT 'morning'
)
RETURNS JSON AS $$
DECLARE
    handover_report JSON;
BEGIN
    SELECT json_build_object(
        'shift_info', json_build_object(
            'date', shift_date,
            'shift_type', shift_type,
            'staff_count', COUNT(DISTINCT ss.staff_id),
            'total_hours_planned', SUM(ss.planned_hours),
            'total_hours_worked', SUM(ss.actual_hours)
        ),
        'sales_summary', json_build_object(
            'total_orders', COUNT(o.id),
            'total_revenue', COALESCE(SUM(o.total_amount), 0),
            'cash_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'cash' THEN o.total_amount ELSE 0 END), 0),
            'insurance_sales', COALESCE(SUM(CASE WHEN o.payment_method = 'insurance' THEN o.total_amount ELSE 0 END), 0),
            'unique_customers', COUNT(DISTINCT o.customer_id)
        ),
        'inventory_alerts', (
            SELECT json_agg(
                json_build_object(
                    'medicine_name', m.name,
                    'current_stock', m.stock,
                    'min_level', m.min_stock_level,
                    'status', CASE 
                        WHEN m.stock = 0 THEN 'OUT_OF_STOCK'
                        WHEN m.stock <= m.min_stock_level THEN 'LOW_STOCK'
                        ELSE 'OK'
                    END
                )
            )
            FROM public.medicines m
            WHERE m.stock <= m.min_stock_level AND m.is_active = true
        ),
        'staff_performance', (
            SELECT json_agg(
                json_build_object(
                    'staff_name', up.full_name,
                    'orders_processed', COUNT(o2.id),
                    'sales_amount', COALESCE(SUM(o2.total_amount), 0),
                    'hours_worked', ss2.actual_hours,
                    'performance_rating', CASE 
                        WHEN COUNT(o2.id) > 20 THEN 'Excellent'
                        WHEN COUNT(o2.id) > 15 THEN 'Good'
                        WHEN COUNT(o2.id) > 10 THEN 'Average'
                        ELSE 'Below Average'
                    END
                )
            )
            FROM public.staff_shifts ss2
            JOIN public.user_profiles up ON ss2.staff_id = up.id
            LEFT JOIN public.orders o2 ON ss2.staff_id = o2.served_by 
                AND o2.order_date = shift_date
                AND o2.status = 'completed'
            WHERE ss2.shift_date = shift_date 
            AND ss2.shift_type = shift_type
            AND ss2.is_active = true
            GROUP BY up.full_name, ss2.actual_hours
        )
    ) INTO handover_report
    FROM public.staff_shifts ss
    LEFT JOIN public.orders o ON ss.staff_id = o.served_by 
        AND o.order_date = shift_date
        AND o.status = 'completed' AND o.is_active = true
    WHERE ss.shift_date = shift_date 
    AND ss.shift_type = shift_type
    AND ss.is_active = true;
    
    RETURN handover_report;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGERS FOR AUTOMATIC PERFORMANCE TRACKING
-- =============================================

-- Update staff performance when order is completed
CREATE OR REPLACE FUNCTION update_staff_performance_on_order()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
        -- Insert or update staff performance for today
        INSERT INTO public.staff_performance (
            staff_id, performance_date, orders_processed, total_sales_amount, 
            customer_count, medicines_dispensed
        )
        VALUES (
            NEW.served_by, NEW.order_date, 1, NEW.total_amount, 1,
            (SELECT COALESCE(SUM(quantity), 0) FROM public.order_items WHERE order_id = NEW.id)
        )
        ON CONFLICT (staff_id, performance_date) 
        DO UPDATE SET
            orders_processed = staff_performance.orders_processed + 1,
            total_sales_amount = staff_performance.total_sales_amount + NEW.total_amount,
            customer_count = staff_performance.customer_count + 1,
            medicines_dispensed = staff_performance.medicines_dispensed + 
                (SELECT COALESCE(SUM(quantity), 0) FROM public.order_items WHERE order_id = NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_staff_performance_trigger 
    AFTER UPDATE ON public.orders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_staff_performance_on_order();

-- Auto-calculate shift hours
CREATE OR REPLACE FUNCTION calculate_shift_hours()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.clock_out_time IS NOT NULL AND NEW.clock_in_time IS NOT NULL THEN
        NEW.actual_hours := EXTRACT(EPOCH FROM (NEW.clock_out_time - NEW.clock_in_time)) / 3600.0 - (NEW.break_duration / 60.0);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_shift_hours_trigger 
    BEFORE INSERT OR UPDATE ON public.staff_shifts 
    FOR EACH ROW 
    EXECUTE FUNCTION calculate_shift_hours();

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX idx_staff_shifts_date_staff ON public.staff_shifts(shift_date, staff_id);
CREATE INDEX idx_staff_performance_date_staff ON public.staff_performance(performance_date, staff_id);
CREATE INDEX idx_transaction_performance_staff_time ON public.transaction_performance(staff_id, transaction_start_time);
CREATE INDEX idx_cash_register_sessions_date_staff ON public.cash_register_sessions(session_date, staff_id);
CREATE INDEX idx_daily_pos_summary_date ON public.daily_pos_summary(summary_date);

-- Add unique constraint for staff performance per date
ALTER TABLE public.staff_performance ADD CONSTRAINT unique_staff_performance_per_date 
    UNIQUE (staff_id, performance_date);

-- =============================================
-- INITIAL SETUP
-- =============================================

-- Grant permissions for new tables
ALTER TABLE public.staff_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_register_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_pos_summary ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Staff can manage their own shifts" ON public.staff_shifts
    FOR ALL USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Staff can view their own performance" ON public.staff_performance
    FOR SELECT USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist')));

CREATE POLICY "Admins can view all transaction performance" ON public.transaction_performance
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin')
    );

CREATE POLICY "Staff can manage their cash sessions" ON public.cash_register_sessions
    FOR ALL USING (staff_id = auth.uid() OR 
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Staff can view daily POS summary" ON public.daily_pos_summary
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist'))
    );
    -- =============================================
-- CASH BOOK TABLE FOR PHARMACY MANAGEMENT
-- =============================================

-- Create cash_book table
CREATE TABLE public.cash_book (
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
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
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
CREATE INDEX idx_cash_book_date ON public.cash_book(entry_date) WHERE is_active = true;
CREATE INDEX idx_cash_book_created_by ON public.cash_book(created_by) WHERE is_active = true;
CREATE INDEX idx_cash_book_active ON public.cash_book(is_active);

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

-- Insert some sample data for testing
INSERT INTO public.cash_book (
    entry_date, ticket_moderator, pharmacie, laboratoire, general, 
    other_cash_in, depense, credit, notes, reference
) VALUES
(CURRENT_DATE, 150.00, 250000, 50000, 30000, 20000, 150000, 0, 'Daily sales and purchases', 'TXN-001'),
(CURRENT_DATE - 1, 200.00, 180000, 75000, 45000, 0, 80000, 25000, 'Medicine sales and lab supplies', 'TXN-002'),
(CURRENT_DATE - 2, 100.00, 320000, 60000, 25000, 15000, 200000, 50000, 'High sales day with staff payments', 'TXN-003'),
(CURRENT_DATE - 3, 300.00, 290000, 40000, 35000, 10000, 120000, 30000, 'Regular operations', 'TXN-004'),
(CURRENT_DATE - 4, 250.00, 275000, 85000, 20000, 5000, 380000, 75000, 'Large supplier payment day', 'TXN-005')
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
