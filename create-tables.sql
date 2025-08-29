-- SQL Script to create all required tables for Pharmacy Management System
-- Run this in your Supabase SQL Editor

-- 1. Medicines Table
CREATE TABLE public.medicines (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    price DECIMAL(10,2) DEFAULT 0,
    stock INTEGER DEFAULT 0,
    supplier VARCHAR(255),
    sale_on VARCHAR(50) CHECK (sale_on IN ('Private', 'Mutuel')),
    description TEXT,
    expiry_date DATE,
    batch_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Suppliers Table
CREATE TABLE public.suppliers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Users Table (Authentication & Role Management)
CREATE TABLE public.users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'receptionist', 'customer')),
    is_active BOOLEAN DEFAULT true,
    phone VARCHAR(50),
    address TEXT,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Customers Table
CREATE TABLE public.customers (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES public.users(id) ON DELETE SET NULL,
    customer_id VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    notes TEXT,
    last_visit DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Orders Table
CREATE TABLE public.orders (
    id BIGSERIAL PRIMARY KEY,
    customer_name VARCHAR(255),
    customer_id BIGINT REFERENCES public.customers(id),
    medicine_name VARCHAR(255),
    medicine_id BIGINT REFERENCES public.medicines(id),
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2) DEFAULT 0,
    status VARCHAR(50) DEFAULT 'pending',
    order_date DATE DEFAULT CURRENT_DATE,
    created_by BIGINT REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. Stock Movements Table
CREATE TABLE public.stock_movements (
    id BIGSERIAL PRIMARY KEY,
    medicine_id BIGINT REFERENCES public.medicines(id) ON DELETE CASCADE,
    medicine_name VARCHAR(255) NOT NULL,
    movement_type VARCHAR(50) NOT NULL, 
    quantity INTEGER NOT NULL,
    previous_stock INTEGER DEFAULT 0,
    new_stock INTEGER DEFAULT 0,
    reason VARCHAR(255), -- 'purchase', 'sale', 'expired', 'damaged', 'adjustment'
    reference_id BIGINT, -- can reference orders.id or other related records
    notes TEXT,
    movement_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS) for all tables
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

-- Create policies to allow full access (you can customize these later)
CREATE POLICY "Allow all operations on medicines" ON public.medicines FOR ALL USING (true);
CREATE POLICY "Allow all operations on suppliers" ON public.suppliers FOR ALL USING (true);
CREATE POLICY "Allow all operations on users" ON public.users FOR ALL USING (true);
CREATE POLICY "Allow all operations on customers" ON public.customers FOR ALL USING (true);
CREATE POLICY "Allow all operations on orders" ON public.orders FOR ALL USING (true);
CREATE POLICY "Allow all operations on stock_movements" ON public.stock_movements FOR ALL USING (true);

-- Insert some sample data for testing

-- Sample Users (Default password for all users: 'password123')
-- Note: In production, passwords should be properly hashed
INSERT INTO public.users (username, email, password_hash, full_name, role, phone, address) VALUES
('admin', 'admin@nyinawajambo.com', '$2b$10$rQZ8YKzZKGKg5yqhKgB.4eqVZJ5VzK3K3K3K3K3K3K3K3K3K3K3K3K', 'System Administrator', 'admin', '+250-700-000-001', 'Kigali, Rwanda'),
('receptionist1', 'receptionist@nyinawajambo.com', '$2b$10$rQZ8YKzZKGKg5yqhKgB.4eqVZJ5VzK3K3K3K3K3K3K3K3K3K3K3K3K', 'Marie Uwimana', 'receptionist', '+250-700-000-002', 'Kigali, Rwanda'),
('receptionist2', 'receptionist2@nyinawajambo.com', '$2b$10$rQZ8YKzZKGKg5yqhKgB.4eqVZJ5VzK3K3K3K3K3K3K3K3K3K3K3K3K', 'Jean Baptiste', 'receptionist', '+250-700-000-003', 'Kigali, Rwanda');

-- Sample Medicines
INSERT INTO public.medicines (name, category, price, stock, supplier, sale_on, description) VALUES
('Paracetamol 500mg', 'Pain Relief', 500, 150, 'MediSupply Co', 'Private', 'Pain and fever relief tablets'),
('Amoxicillin 250mg', 'Antibiotics', 1250, 75, 'PharmaPlus', 'Mutuel', 'Antibiotic for bacterial infections'),
('Ibuprofen 400mg', 'Pain Relief', 875, 200, 'HealthCorp', 'Private', 'Anti-inflammatory pain relief'),
('Vitamin C 1000mg', 'Vitamins', 1599, 300, 'VitaLife', 'Mutuel', 'Immune system support'),
('Aspirin 100mg', 'Cardiovascular', 625, 120, 'CardioMed', 'Private', 'Low-dose aspirin for heart health');

-- Sample Suppliers
INSERT INTO public.suppliers (name, contact_person, phone, email, address, city, country) VALUES
('MediSupply Co', 'John Smith', '+1-555-0123', 'john@medisupply.com', '123 Medical Ave', 'New York', 'USA'),
('PharmaPlus', 'Sarah Johnson', '+1-555-0456', 'sarah@pharmaplus.com', '456 Health St', 'Los Angeles', 'USA'),
('HealthCorp', 'Mike Wilson', '+1-555-0789', 'mike@healthcorp.com', '789 Wellness Blvd', 'Chicago', 'USA'),
('VitaLife', 'Emma Davis', '+1-555-0321', 'emma@vitalife.com', '321 Nutrition Dr', 'Miami', 'USA'),
('CardioMed', 'David Brown', '+1-555-0654', 'david@cardiomed.com', '654 Heart Lane', 'Houston', 'USA');

-- Sample Customers (linking to users for customer accounts)
INSERT INTO public.customers (customer_id, name, phone, email, address, notes, last_visit) VALUES
('CUS001', 'Alice Johnson', '+250-700-001-001', 'alice@email.com', '123 Main St, Kigali', 'Regular customer, prefers generic brands', '2025-08-28'),
('CUS002', 'Bob Smith', '+250-700-001-002', 'bob@email.com', '456 Oak Ave, Kigali', 'Diabetic patient, needs insulin regularly', '2025-08-27'),
('CUS003', 'Carol Williams', '+250-700-001-003', 'carol@email.com', '789 Pine Rd, Kigali', 'Senior citizen, multiple medications', '2025-08-26'),
('CUS004', 'David Miller', '+250-700-001-004', 'david@email.com', '321 Elm St, Kigali', 'Young parent, often buys children medications', '2025-08-25'),
('CUS005', 'Eva Garcia', '+250-700-001-005', 'eva@email.com', '654 Maple Dr, Kigali', 'Prefers natural/herbal remedies when possible', '2025-08-24');

-- Sample Orders
INSERT INTO public.orders (customer_name, medicine_name, quantity, unit_price, total, status, order_date) VALUES
('Alice Johnson', 'Paracetamol 500mg', 2, 500, 1000, 'completed', '2025-08-28'),
('Bob Smith', 'Amoxicillin 250mg', 1, 1250, 1250, 'completed', '2025-08-27'),
('Carol Williams', 'Ibuprofen 400mg', 3, 875, 2625, 'pending', '2025-08-29'),
('David Miller', 'Vitamin C 1000mg', 1, 1599, 1599, 'completed', '2025-08-26'),
('Eva Garcia', 'Aspirin 100mg', 2, 625, 1250, 'processing', '2025-08-28');

-- Sample Stock Movements
INSERT INTO public.stock_movements (medicine_id, medicine_name, movement_type, quantity, previous_stock, new_stock, reason, movement_date) VALUES
(1, 'Paracetamol 500mg', 'in', 200, 0, 200, 'initial_stock', '2025-08-25'),
(1, 'Paracetamol 500mg', 'out', 50, 200, 150, 'sale', '2025-08-28'),
(2, 'Amoxicillin 250mg', 'in', 100, 0, 100, 'initial_stock', '2025-08-25'),
(2, 'Amoxicillin 250mg', 'out', 25, 100, 75, 'sale', '2025-08-27'),
(3, 'Ibuprofen 400mg', 'in', 250, 0, 250, 'initial_stock', '2025-08-25'),
(3, 'Ibuprofen 400mg', 'out', 50, 250, 200, 'sale', '2025-08-28'),
(4, 'Vitamin C 1000mg', 'in', 350, 0, 350, 'initial_stock', '2025-08-25'),
(4, 'Vitamin C 1000mg', 'out', 50, 350, 300, 'sale', '2025-08-26'),
(5, 'Aspirin 100mg', 'in', 150, 0, 150, 'initial_stock', '2025-08-25'),
(5, 'Aspirin 100mg', 'out', 30, 150, 120, 'sale', '2025-08-28');

-- Create indexes for better performance
CREATE INDEX idx_medicines_name ON public.medicines(name);
CREATE INDEX idx_medicines_category ON public.medicines(category);
CREATE INDEX idx_suppliers_name ON public.suppliers(name);
CREATE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_customers_name ON public.customers(name);
CREATE INDEX idx_customers_customer_id ON public.customers(customer_id);
CREATE INDEX idx_orders_date ON public.orders(order_date);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_stock_movements_medicine_id ON public.stock_movements(medicine_id);
CREATE INDEX idx_stock_movements_date ON public.stock_movements(movement_date);
CREATE INDEX idx_stock_movements_type ON public.stock_movements(movement_type);

-- =====================================================================
-- ALTER STATEMENTS (Use these if adding customer_id to existing table)
-- =====================================================================
-- If you need to add customer_id to an existing customers table, use:
-- ALTER TABLE public.customers ADD COLUMN customer_id VARCHAR(20) UNIQUE;
-- ALTER TABLE public.customers ALTER COLUMN customer_id SET NOT NULL;
-- 
-- To update existing customers with auto-generated IDs:
-- UPDATE public.customers SET customer_id = 'CUS' || LPAD(id::text, 3, '0') WHERE customer_id IS NULL;
-- =====================================================================
