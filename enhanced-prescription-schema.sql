-- =============================================
-- ENHANCED PRESCRIPTION MANAGEMENT SYSTEM
-- =============================================

-- 1. Prescriptions Table
CREATE TABLE public.prescriptions (
    id BIGSERIAL PRIMARY KEY,
    prescription_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id BIGINT REFERENCES public.customers(id),
    doctor_name VARCHAR(255) NOT NULL,
    doctor_license VARCHAR(100),
    doctor_phone VARCHAR(50),
    doctor_facility VARCHAR(255),
    prescription_date DATE NOT NULL,
    diagnosis TEXT,
    patient_weight DECIMAL(5,2),
    patient_age INTEGER,
    special_instructions TEXT,
    total_medicines INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'completed', 'cancelled')),
    dispensed_by UUID REFERENCES auth.users(id),
    dispensed_at TIMESTAMP WITH TIME ZONE,
    insurance_claim_number VARCHAR(100),
    insurance_approved_amount DECIMAL(10,2),
    is_controlled_substance BOOLEAN DEFAULT false,
    requires_follow_up BOOLEAN DEFAULT false,
    follow_up_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Prescription Items Table
CREATE TABLE public.prescription_items (
    id BIGSERIAL PRIMARY KEY,
    prescription_id BIGINT REFERENCES public.prescriptions(id) ON DELETE CASCADE,
    medicine_id BIGINT REFERENCES public.medicines(id),
    medicine_name VARCHAR(255) NOT NULL,
    dosage VARCHAR(100) NOT NULL, -- "2 tablets twice daily"
    quantity_prescribed INTEGER NOT NULL,
    quantity_dispensed INTEGER DEFAULT 0,
    duration_days INTEGER, -- Treatment duration
    administration_route VARCHAR(50), -- oral, topical, injection
    special_instructions TEXT,
    substitution_allowed BOOLEAN DEFAULT true,
    is_generic_substituted BOOLEAN DEFAULT false,
    substituted_medicine_id BIGINT REFERENCES public.medicines(id),
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),
    insurance_covered BOOLEAN DEFAULT false,
    patient_copay DECIMAL(10,2),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Medicine Interactions Table
CREATE TABLE public.medicine_interactions (
    id BIGSERIAL PRIMARY KEY,
    medicine_a_id BIGINT REFERENCES public.medicines(id),
    medicine_b_id BIGINT REFERENCES public.medicines(id),
    interaction_type VARCHAR(50) NOT NULL CHECK (interaction_type IN ('major', 'moderate', 'minor', 'contraindicated')),
    description TEXT NOT NULL,
    clinical_effect TEXT,
    management_recommendation TEXT,
    severity_level INTEGER CHECK (severity_level BETWEEN 1 AND 5),
    evidence_level VARCHAR(20) CHECK (evidence_level IN ('established', 'probable', 'suspected', 'theoretical')),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(medicine_a_id, medicine_b_id)
);

-- 4. Customer Allergies Table
CREATE TABLE public.customer_allergies (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    allergen_type VARCHAR(50) NOT NULL CHECK (allergen_type IN ('medicine', 'food', 'environmental', 'other')),
    allergen_name VARCHAR(255) NOT NULL,
    medicine_id BIGINT REFERENCES public.medicines(id), -- if medicine allergy
    reaction_type VARCHAR(100), -- rash, swelling, anaphylaxis
    severity VARCHAR(50) CHECK (severity IN ('mild', 'moderate', 'severe', 'life-threatening')),
    symptoms TEXT,
    date_discovered DATE,
    verified_by VARCHAR(255), -- doctor/pharmacist who verified
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Medicine Batches Table (Enhanced inventory tracking)
CREATE TABLE public.medicine_batches (
    id BIGSERIAL PRIMARY KEY,
    medicine_id BIGINT REFERENCES public.medicines(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(255),
    manufacture_date DATE,
    expiry_date DATE NOT NULL,
    quantity_received INTEGER NOT NULL,
    quantity_remaining INTEGER NOT NULL,
    cost_per_unit DECIMAL(10,2),
    selling_price_per_unit DECIMAL(10,2),
    supplier_id BIGINT REFERENCES public.suppliers(id),
    storage_location VARCHAR(100),
    temperature_requirements TEXT,
    quality_status VARCHAR(50) DEFAULT 'good' CHECK (quality_status IN ('good', 'damaged', 'expired', 'recalled')),
    purchase_order_id BIGINT REFERENCES public.purchase_orders(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Sales Analytics Table (Enhanced sales tracking)
CREATE TABLE public.sales_analytics (
    id BIGSERIAL PRIMARY KEY,
    analysis_date DATE NOT NULL,
    analysis_type VARCHAR(50) NOT NULL, -- daily, weekly, monthly
    total_orders INTEGER DEFAULT 0,
    total_revenue DECIMAL(12,2) DEFAULT 0,
    total_cost DECIMAL(12,2) DEFAULT 0,
    gross_profit DECIMAL(12,2) DEFAULT 0,
    profit_margin DECIMAL(5,2) DEFAULT 0,
    cash_sales DECIMAL(12,2) DEFAULT 0,
    insurance_sales DECIMAL(12,2) DEFAULT 0,
    momo_sales DECIMAL(12,2) DEFAULT 0,
    bank_sales DECIMAL(12,2) DEFAULT 0,
    unique_customers INTEGER DEFAULT 0,
    new_customers INTEGER DEFAULT 0,
    returning_customers INTEGER DEFAULT 0,
    average_order_value DECIMAL(10,2) DEFAULT 0,
    medicines_sold INTEGER DEFAULT 0,
    prescriptions_filled INTEGER DEFAULT 0,
    peak_hour INTEGER, -- busiest hour of the day
    top_selling_medicine_id BIGINT REFERENCES public.medicines(id),
    top_selling_quantity INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Customer Health Profiles Table
CREATE TABLE public.customer_health_profiles (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other')),
    blood_type VARCHAR(10),
    weight DECIMAL(5,2),
    height DECIMAL(5,2),
    chronic_conditions TEXT[], -- array of conditions
    current_medications TEXT[], -- array of current medicines
    emergency_contact_name VARCHAR(255),
    emergency_contact_phone VARCHAR(50),
    primary_doctor VARCHAR(255),
    primary_doctor_phone VARCHAR(50),
    insurance_provider VARCHAR(255),
    insurance_number VARCHAR(100),
    insurance_expiry DATE,
    preferred_language VARCHAR(50) DEFAULT 'Kinyarwanda',
    communication_preference VARCHAR(50) DEFAULT 'sms' CHECK (communication_preference IN ('sms', 'call', 'email', 'whatsapp')),
    last_updated_by UUID REFERENCES auth.users(id),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(customer_id)
);

-- 8. Inventory Forecasting Table
CREATE TABLE public.inventory_forecasting (
    id BIGSERIAL PRIMARY KEY,
    medicine_id BIGINT REFERENCES public.medicines(id) ON DELETE CASCADE,
    forecast_date DATE NOT NULL,
    forecast_period VARCHAR(20) NOT NULL, -- daily, weekly, monthly
    predicted_demand INTEGER NOT NULL,
    current_stock INTEGER NOT NULL,
    recommended_order_quantity INTEGER DEFAULT 0,
    lead_time_days INTEGER DEFAULT 7,
    safety_stock_level INTEGER DEFAULT 0,
    seasonal_factor DECIMAL(5,2) DEFAULT 1.0,
    trend_factor DECIMAL(5,2) DEFAULT 1.0,
    confidence_level DECIMAL(3,2) DEFAULT 0.8, -- 80% confidence
    method_used VARCHAR(50) DEFAULT 'moving_average',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 9. Customer Communications Table
CREATE TABLE public.customer_communications (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT REFERENCES public.customers(id) ON DELETE CASCADE,
    communication_type VARCHAR(50) NOT NULL CHECK (communication_type IN ('sms', 'call', 'email', 'whatsapp', 'in_person')),
    subject VARCHAR(255),
    message TEXT NOT NULL,
    sent_by UUID REFERENCES auth.users(id),
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivery_status VARCHAR(50) DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'sent', 'delivered', 'failed', 'read')),
    response_required BOOLEAN DEFAULT false,
    response_received BOOLEAN DEFAULT false,
    response_text TEXT,
    response_at TIMESTAMP WITH TIME ZONE,
    related_to VARCHAR(50), -- prescription, order, reminder, promotion
    related_id BIGINT,
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. Quality Control Checks Table
CREATE TABLE public.quality_control_checks (
    id BIGSERIAL PRIMARY KEY,
    medicine_batch_id BIGINT REFERENCES public.medicine_batches(id) ON DELETE CASCADE,
    check_date DATE DEFAULT CURRENT_DATE,
    check_type VARCHAR(50) NOT NULL CHECK (check_type IN ('receiving', 'routine', 'complaint', 'recall', 'expiry')),
    checked_by UUID REFERENCES auth.users(id),
    visual_inspection BOOLEAN DEFAULT true,
    packaging_integrity BOOLEAN DEFAULT true,
    label_accuracy BOOLEAN DEFAULT true,
    expiry_date_check BOOLEAN DEFAULT true,
    storage_condition_check BOOLEAN DEFAULT true,
    temperature_log_check BOOLEAN DEFAULT true,
    overall_status VARCHAR(50) DEFAULT 'pass' CHECK (overall_status IN ('pass', 'fail', 'conditional_pass')),
    issues_found TEXT,
    corrective_actions TEXT,
    next_check_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- ENHANCED FUNCTIONS FOR NEW FEATURES
-- =============================================

-- 1. Check Medicine Interactions
CREATE OR REPLACE FUNCTION check_medicine_interactions(prescription_medicines BIGINT[])
RETURNS TABLE(
    medicine_a_name VARCHAR(255),
    medicine_b_name VARCHAR(255),
    interaction_type VARCHAR(50),
    description TEXT,
    severity_level INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ma.name,
        mb.name,
        mi.interaction_type,
        mi.description,
        mi.severity_level
    FROM public.medicine_interactions mi
    JOIN public.medicines ma ON mi.medicine_a_id = ma.id
    JOIN public.medicines mb ON mi.medicine_b_id = mb.id
    WHERE mi.medicine_a_id = ANY(prescription_medicines)
    AND mi.medicine_b_id = ANY(prescription_medicines)
    AND mi.is_active = true
    ORDER BY mi.severity_level DESC;
END;
$$ LANGUAGE plpgsql;

-- 2. Check Customer Allergies
CREATE OR REPLACE FUNCTION check_customer_allergies(p_customer_id BIGINT, medicine_ids BIGINT[])
RETURNS TABLE(
    allergen_name VARCHAR(255),
    reaction_type VARCHAR(100),
    severity VARCHAR(50),
    medicine_name VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ca.allergen_name,
        ca.reaction_type,
        ca.severity,
        m.name
    FROM public.customer_allergies ca
    LEFT JOIN public.medicines m ON ca.medicine_id = m.id
    WHERE ca.customer_id = p_customer_id
    AND ca.is_active = true
    AND (
        ca.medicine_id = ANY(medicine_ids) OR
        ca.allergen_type != 'medicine'
    )
    ORDER BY 
        CASE ca.severity
            WHEN 'life-threatening' THEN 1
            WHEN 'severe' THEN 2
            WHEN 'moderate' THEN 3
            WHEN 'mild' THEN 4
            ELSE 5
        END;
END;
$$ LANGUAGE plpgsql;

-- 3. Generate Sales Forecast
CREATE OR REPLACE FUNCTION generate_sales_forecast(p_medicine_id BIGINT, p_days_ahead INTEGER DEFAULT 30)
RETURNS TABLE(
    forecast_date DATE,
    predicted_demand INTEGER,
    confidence_level DECIMAL(3,2)
) AS $$
DECLARE
    avg_daily_sales DECIMAL(10,2);
    trend_factor DECIMAL(5,2);
    seasonal_factor DECIMAL(5,2);
BEGIN
    -- Calculate average daily sales over the last 90 days
    SELECT COALESCE(AVG(daily_quantity), 0) INTO avg_daily_sales
    FROM (
        SELECT 
            DATE(o.order_date) as sale_date,
            SUM(oi.quantity) as daily_quantity
        FROM public.orders o
        JOIN public.order_items oi ON o.id = oi.order_id
        WHERE oi.medicine_id = p_medicine_id
        AND o.order_date >= CURRENT_DATE - INTERVAL '90 days'
        AND o.status = 'completed'
        AND o.is_active = true
        GROUP BY DATE(o.order_date)
    ) daily_sales;
    
    -- Simple trend calculation (can be enhanced with more sophisticated algorithms)
    trend_factor := 1.0;
    seasonal_factor := 1.0;
    
    -- Generate forecast for each day
    FOR i IN 1..p_days_ahead LOOP
        forecast_date := CURRENT_DATE + i;
        predicted_demand := GREATEST(0, ROUND(avg_daily_sales * trend_factor * seasonal_factor));
        confidence_level := GREATEST(0.5, 1.0 - (i::DECIMAL / p_days_ahead * 0.3)); -- Decreasing confidence
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Update Customer Health Profile
CREATE OR REPLACE FUNCTION update_customer_health_profile(
    p_customer_id BIGINT,
    p_profile_data JSONB
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.customer_health_profiles (
        customer_id,
        date_of_birth,
        gender,
        blood_type,
        weight,
        height,
        chronic_conditions,
        current_medications,
        emergency_contact_name,
        emergency_contact_phone,
        insurance_provider,
        insurance_number,
        insurance_expiry,
        last_updated_by
    )
    VALUES (
        p_customer_id,
        (p_profile_data->>'date_of_birth')::DATE,
        p_profile_data->>'gender',
        p_profile_data->>'blood_type',
        (p_profile_data->>'weight')::DECIMAL(5,2),
        (p_profile_data->>'height')::DECIMAL(5,2),
        ARRAY(SELECT jsonb_array_elements_text(p_profile_data->'chronic_conditions')),
        ARRAY(SELECT jsonb_array_elements_text(p_profile_data->'current_medications')),
        p_profile_data->>'emergency_contact_name',
        p_profile_data->>'emergency_contact_phone',
        p_profile_data->>'insurance_provider',
        p_profile_data->>'insurance_number',
        (p_profile_data->>'insurance_expiry')::DATE,
        auth.uid()
    )
    ON CONFLICT (customer_id) 
    DO UPDATE SET
        date_of_birth = EXCLUDED.date_of_birth,
        gender = EXCLUDED.gender,
        blood_type = EXCLUDED.blood_type,
        weight = EXCLUDED.weight,
        height = EXCLUDED.height,
        chronic_conditions = EXCLUDED.chronic_conditions,
        current_medications = EXCLUDED.current_medications,
        emergency_contact_name = EXCLUDED.emergency_contact_name,
        emergency_contact_phone = EXCLUDED.emergency_contact_phone,
        insurance_provider = EXCLUDED.insurance_provider,
        insurance_number = EXCLUDED.insurance_number,
        insurance_expiry = EXCLUDED.insurance_expiry,
        last_updated_by = auth.uid(),
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- 5. Generate Daily Sales Analytics
CREATE OR REPLACE FUNCTION generate_daily_sales_analytics(analysis_date DATE DEFAULT CURRENT_DATE)
RETURNS void AS $$
DECLARE
    daily_stats RECORD;
    top_medicine RECORD;
BEGIN
    -- Calculate daily statistics
    SELECT 
        COUNT(DISTINCT o.id) as total_orders,
        COALESCE(SUM(o.total_amount), 0) as total_revenue,
        COALESCE(SUM(oi.quantity * m.cost_price), 0) as total_cost,
        COALESCE(SUM(CASE WHEN o.payment_method = 'cash' THEN o.total_amount ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN o.payment_method = 'insurance' THEN o.total_amount ELSE 0 END), 0) as insurance_sales,
        COALESCE(SUM(CASE WHEN o.payment_method = 'momo' THEN o.total_amount ELSE 0 END), 0) as momo_sales,
        COALESCE(SUM(CASE WHEN o.payment_method = 'bank_transfer' THEN o.total_amount ELSE 0 END), 0) as bank_sales,
        COUNT(DISTINCT o.customer_id) as unique_customers,
        COALESCE(SUM(oi.quantity), 0) as medicines_sold,
        COUNT(DISTINCT CASE WHEN p.id IS NOT NULL THEN p.id END) as prescriptions_filled
    INTO daily_stats
    FROM public.orders o
    LEFT JOIN public.order_items oi ON o.id = oi.order_id
    LEFT JOIN public.medicines m ON oi.medicine_id = m.id
    LEFT JOIN public.prescriptions p ON o.customer_id = p.customer_id AND p.dispensed_at::DATE = analysis_date
    WHERE o.order_date = analysis_date
    AND o.status = 'completed'
    AND o.is_active = true;
    
    -- Find top selling medicine
    SELECT 
        oi.medicine_id,
        SUM(oi.quantity) as total_quantity
    INTO top_medicine
    FROM public.orders o
    JOIN public.order_items oi ON o.id = oi.order_id
    WHERE o.order_date = analysis_date
    AND o.status = 'completed'
    AND o.is_active = true
    GROUP BY oi.medicine_id
    ORDER BY total_quantity DESC
    LIMIT 1;
    
    -- Insert or update analytics
    INSERT INTO public.sales_analytics (
        analysis_date,
        analysis_type,
        total_orders,
        total_revenue,
        total_cost,
        gross_profit,
        profit_margin,
        cash_sales,
        insurance_sales,
        momo_sales,
        bank_sales,
        unique_customers,
        average_order_value,
        medicines_sold,
        prescriptions_filled,
        top_selling_medicine_id,
        top_selling_quantity
    )
    VALUES (
        analysis_date,
        'daily',
        daily_stats.total_orders,
        daily_stats.total_revenue,
        daily_stats.total_cost,
        daily_stats.total_revenue - daily_stats.total_cost,
        CASE WHEN daily_stats.total_revenue > 0 
             THEN ((daily_stats.total_revenue - daily_stats.total_cost) / daily_stats.total_revenue) * 100 
             ELSE 0 END,
        daily_stats.cash_sales,
        daily_stats.insurance_sales,
        daily_stats.momo_sales,
        daily_stats.bank_sales,
        daily_stats.unique_customers,
        CASE WHEN daily_stats.total_orders > 0 
             THEN daily_stats.total_revenue / daily_stats.total_orders 
             ELSE 0 END,
        daily_stats.medicines_sold,
        daily_stats.prescriptions_filled,
        top_medicine.medicine_id,
        top_medicine.total_quantity
    )
    ON CONFLICT (analysis_date, analysis_type) 
    DO UPDATE SET
        total_orders = EXCLUDED.total_orders,
        total_revenue = EXCLUDED.total_revenue,
        total_cost = EXCLUDED.total_cost,
        gross_profit = EXCLUDED.gross_profit,
        profit_margin = EXCLUDED.profit_margin,
        cash_sales = EXCLUDED.cash_sales,
        insurance_sales = EXCLUDED.insurance_sales,
        momo_sales = EXCLUDED.momo_sales,
        bank_sales = EXCLUDED.bank_sales,
        unique_customers = EXCLUDED.unique_customers,
        average_order_value = EXCLUDED.average_order_value,
        medicines_sold = EXCLUDED.medicines_sold,
        prescriptions_filled = EXCLUDED.prescriptions_filled,
        top_selling_medicine_id = EXCLUDED.top_selling_medicine_id,
        top_selling_quantity = EXCLUDED.top_selling_quantity;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGERS FOR ENHANCED FUNCTIONALITY
-- =============================================

-- Auto-generate prescription numbers
CREATE OR REPLACE FUNCTION generate_prescription_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.prescription_number IS NULL THEN
        NEW.prescription_number := 'RX' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEW.id::text, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generate_prescription_number_trigger 
    BEFORE INSERT ON public.prescriptions 
    FOR EACH ROW EXECUTE FUNCTION generate_prescription_number();

-- Update prescription status when items are dispensed
CREATE OR REPLACE FUNCTION update_prescription_status()
RETURNS TRIGGER AS $$
DECLARE
    total_items INTEGER;
    dispensed_items INTEGER;
BEGIN
    -- Count total items and dispensed items for this prescription
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN quantity_dispensed >= quantity_prescribed THEN 1 END)
    INTO total_items, dispensed_items
    FROM public.prescription_items
    WHERE prescription_id = COALESCE(NEW.prescription_id, OLD.prescription_id)
    AND is_active = true;
    
    -- Update prescription status
    UPDATE public.prescriptions
    SET status = CASE 
        WHEN dispensed_items = 0 THEN 'pending'
        WHEN dispensed_items = total_items THEN 'completed'
        ELSE 'partial'
    END,
    total_medicines = total_items,
    updated_at = NOW()
    WHERE id = COALESCE(NEW.prescription_id, OLD.prescription_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_prescription_status_trigger 
    AFTER INSERT OR UPDATE OR DELETE ON public.prescription_items 
    FOR EACH ROW EXECUTE FUNCTION update_prescription_status();

-- Auto-update batch quantities when medicines are sold
CREATE OR REPLACE FUNCTION update_batch_quantities()
RETURNS TRIGGER AS $$
DECLARE
    remaining_quantity INTEGER;
    current_batch RECORD;
BEGIN
    remaining_quantity := NEW.quantity;
    
    -- Find batches with earliest expiry dates first (FIFO)
    FOR current_batch IN 
        SELECT id, quantity_remaining 
        FROM public.medicine_batches 
        WHERE medicine_id = NEW.medicine_id 
        AND quantity_remaining > 0 
        AND quality_status = 'good'
        ORDER BY expiry_date ASC, created_at ASC
    LOOP
        IF remaining_quantity <= 0 THEN
            EXIT;
        END IF;
        
        IF current_batch.quantity_remaining >= remaining_quantity THEN
            -- This batch has enough quantity
            UPDATE public.medicine_batches 
            SET quantity_remaining = quantity_remaining - remaining_quantity
            WHERE id = current_batch.id;
            remaining_quantity := 0;
        ELSE
            -- Use all quantity from this batch
            UPDATE public.medicine_batches 
            SET quantity_remaining = 0
            WHERE id = current_batch.id;
            remaining_quantity := remaining_quantity - current_batch.quantity_remaining;
        END IF;
    END LOOP;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply batch update trigger to order items
CREATE TRIGGER update_batch_quantities_trigger 
    AFTER INSERT ON public.order_items 
    FOR EACH ROW EXECUTE FUNCTION update_batch_quantities();

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX idx_prescriptions_customer_date ON public.prescriptions(customer_id, prescription_date);
CREATE INDEX idx_prescriptions_status ON public.prescriptions(status) WHERE is_active = true;
CREATE INDEX idx_prescription_items_prescription_id ON public.prescription_items(prescription_id);
CREATE INDEX idx_medicine_interactions_medicines ON public.medicine_interactions(medicine_a_id, medicine_b_id);
CREATE INDEX idx_customer_allergies_customer_medicine ON public.customer_allergies(customer_id, medicine_id);
CREATE INDEX idx_medicine_batches_medicine_expiry ON public.medicine_batches(medicine_id, expiry_date);
CREATE INDEX idx_medicine_batches_remaining ON public.medicine_batches(quantity_remaining) WHERE quantity_remaining > 0;
CREATE INDEX idx_sales_analytics_date_type ON public.sales_analytics(analysis_date, analysis_type);
CREATE INDEX idx_customer_health_profiles_customer ON public.customer_health_profiles(customer_id);
CREATE INDEX idx_customer_communications_customer_date ON public.customer_communications(customer_id, sent_at);
CREATE INDEX idx_quality_control_batch_date ON public.quality_control_checks(medicine_batch_id, check_date);

-- =============================================
-- RLS POLICIES FOR NEW TABLES
-- =============================================

-- Enable RLS
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_allergies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_health_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_forecasting ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quality_control_checks ENABLE ROW LEVEL SECURITY;

-- Prescription policies
CREATE POLICY "Staff can manage prescriptions" ON public.prescriptions
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Customers can view their prescriptions" ON public.prescriptions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.customers WHERE user_id = auth.uid() AND id = prescriptions.customer_id AND is_active = true)
    );

-- Other policies follow similar pattern...
CREATE POLICY "Staff can access all enhanced tables" ON public.prescription_items
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Staff can access medicine interactions" ON public.medicine_interactions
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Staff can access customer health data" ON public.customer_health_profiles
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role IN ('admin', 'receptionist') AND is_active = true)
    );

CREATE POLICY "Admins can access sales analytics" ON public.sales_analytics
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND role = 'admin' AND is_active = true)
    );

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
