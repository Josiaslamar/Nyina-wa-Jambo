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

-- 3. Customers Table
CREATE TABLE public.customers (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50),
    email VARCHAR(255),
    address TEXT,
    notes TEXT,
    last_visit DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Orders Table
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Stock Movements Table
CREATE TABLE public.stock_movements (
    id BIGSERIAL PRIMARY KEY,
    medicine_id BIGINT REFERENCES public.medicines(id) ON DELETE CASCADE,
    medicine_name VARCHAR(255) NOT NULL,
    movement_type VARCHAR(50) NOT NULL, -- 'in' for stock addition, 'out' for stock reduction
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
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;

-- Create policies to allow full access (you can customize these later)
CREATE POLICY "Allow all operations on medicines" ON public.medicines FOR ALL USING (true);
CREATE POLICY "Allow all operations on suppliers" ON public.suppliers FOR ALL USING (true);
CREATE POLICY "Allow all operations on customers" ON public.customers FOR ALL USING (true);
CREATE POLICY "Allow all operations on orders" ON public.orders FOR ALL USING (true);
CREATE POLICY "Allow all operations on stock_movements" ON public.stock_movements FOR ALL USING (true);

-- Insert some sample data for testing

-- Sample Medicines
INSERT INTO public.medicines (name, category, price, stock, supplier, description) VALUES
('Paracetamol 500mg', 'Pain Relief', 5.99, 150, 'MediSupply Co', 'Pain and fever relief tablets'),
('Amoxicillin 250mg', 'Antibiotics', 12.50, 75, 'PharmaPlus', 'Antibiotic for bacterial infections'),
('Ibuprofen 400mg', 'Pain Relief', 8.75, 200, 'HealthCorp', 'Anti-inflammatory pain relief'),
('Vitamin C 1000mg', 'Vitamins', 15.99, 300, 'VitaLife', 'Immune system support'),
('Aspirin 100mg', 'Cardiovascular', 6.25, 120, 'CardioMed', 'Low-dose aspirin for heart health');

-- Sample Suppliers
INSERT INTO public.suppliers (name, contact_person, phone, email, address, city, country) VALUES
('MediSupply Co', 'John Smith', '+1-555-0123', 'john@medisupply.com', '123 Medical Ave', 'New York', 'USA'),
('PharmaPlus', 'Sarah Johnson', '+1-555-0456', 'sarah@pharmaplus.com', '456 Health St', 'Los Angeles', 'USA'),
('HealthCorp', 'Mike Wilson', '+1-555-0789', 'mike@healthcorp.com', '789 Wellness Blvd', 'Chicago', 'USA'),
('VitaLife', 'Emma Davis', '+1-555-0321', 'emma@vitalife.com', '321 Nutrition Dr', 'Miami', 'USA'),
('CardioMed', 'David Brown', '+1-555-0654', 'david@cardiomed.com', '654 Heart Lane', 'Houston', 'USA');

-- Sample Customers
INSERT INTO public.customers (name, phone, email, address, notes, last_visit) VALUES
('Alice Johnson', '+1-555-1001', 'alice@email.com', '123 Main St, Anytown', 'Regular customer, prefers generic brands', '2025-08-28'),
('Bob Smith', '+1-555-1002', 'bob@email.com', '456 Oak Ave, Somewhere', 'Diabetic patient, needs insulin regularly', '2025-08-27'),
('Carol Williams', '+1-555-1003', 'carol@email.com', '789 Pine Rd, Elsewhere', 'Senior citizen, multiple medications', '2025-08-26'),
('David Miller', '+1-555-1004', 'david@email.com', '321 Elm St, Nowhere', 'Young parent, often buys children medications', '2025-08-25'),
('Eva Garcia', '+1-555-1005', 'eva@email.com', '654 Maple Dr, Anywhere', 'Prefers natural/herbal remedies when possible', '2025-08-24');

-- Sample Orders
INSERT INTO public.orders (customer_name, medicine_name, quantity, unit_price, total, status, order_date) VALUES
('Alice Johnson', 'Paracetamol 500mg', 2, 5.99, 11.98, 'completed', '2025-08-28'),
('Bob Smith', 'Amoxicillin 250mg', 1, 12.50, 12.50, 'completed', '2025-08-27'),
('Carol Williams', 'Ibuprofen 400mg', 3, 8.75, 26.25, 'pending', '2025-08-29'),
('David Miller', 'Vitamin C 1000mg', 1, 15.99, 15.99, 'completed', '2025-08-26'),
('Eva Garcia', 'Aspirin 100mg', 2, 6.25, 12.50, 'processing', '2025-08-28');

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
CREATE INDEX idx_customers_name ON public.customers(name);
CREATE INDEX idx_orders_date ON public.orders(order_date);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_stock_movements_medicine_id ON public.stock_movements(medicine_id);
CREATE INDEX idx_stock_movements_date ON public.stock_movements(movement_date);
CREATE INDEX idx_stock_movements_type ON public.stock_movements(movement_type);
