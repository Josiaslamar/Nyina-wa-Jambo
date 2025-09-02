-- Single Healthcare Facility Management System (Refactored)
-- Focused on inventory, stock, orders, sales, suppliers
-- Removes patient care features to avoid eHealth regulations
-- Each deployment is for ONE specific facility
-- Includes soft delete, audit logging, role-based access

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
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, new_values, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), auth.uid());
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, old_values, new_values, changes, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), to_jsonb(NEW) - to_jsonb(OLD), auth.uid());
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