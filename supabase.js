// Supabase client setup for browser
// Replace with your Supabase project URL and public anon key
const SUPABASE_URL = "https://qeprqgdkearetdpbvcyr.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFlcHJxZ2RrZWFyZXRkcGJ2Y3lyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY0NjExNTgsImV4cCI6MjA3MjAzNzE1OH0.BCSWHF7RCm-QJVP3X3JzlUXtfvLxWAT9aFUWx9ig3y0";

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Medicines CRUD
async function fetchMedicines() {
  const { data, error } = await supabase.from('medicines').select('*');
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

async function addMedicine(medicine) {
  const { data, error } = await supabase.from('medicines').insert([medicine]);
  if (error) {
    console.error('Supabase insert error:', error);
    return null;
  }
  return data;
}

async function updateMedicine(id, updates) {
  const { data, error } = await supabase.from('medicines').update(updates).eq('id', id);
  if (error) {
    console.error('Supabase update error:', error);
    return null;
  }
  return data;
}

async function deleteMedicine(id) {
  const { data, error } = await supabase.from('medicines').delete().eq('id', id);
  if (error) {
    console.error('Supabase delete error:', error);
    return null;
  }
  return data;
}

// Suppliers CRUD
async function fetchSuppliers() {
  const { data, error } = await supabase.from('suppliers').select('*');
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

async function addSupplier(supplier) {
  const { data, error } = await supabase.from('suppliers').insert([supplier]);
  if (error) {
    console.error('Supabase insert error:', error);
    return null;
  }
  return data;
}

async function updateSupplier(id, updates) {
  const { data, error } = await supabase.from('suppliers').update(updates).eq('id', id);
  if (error) {
    console.error('Supabase update error:', error);
    return null;
  }
  return data;
}

async function deleteSupplier(id) {
  const { data, error } = await supabase.from('suppliers').delete().eq('id', id);
  if (error) {
    console.error('Supabase delete error:', error);
    return null;
  }
  return data;
}

// Customers CRUD
async function fetchCustomers() {
  const { data, error } = await supabase.from('customers').select('*');
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

async function addCustomer(customer) {
  const { data, error } = await supabase.from('customers').insert([customer]);
  if (error) {
    console.error('Supabase insert error:', error);
    return null;
  }
  return data;
}

async function updateCustomer(id, updates) {
  const { data, error } = await supabase.from('customers').update(updates).eq('id', id);
  if (error) {
    console.error('Supabase update error:', error);
    return null;
  }
  return data;
}

async function deleteCustomer(id) {
  const { data, error } = await supabase.from('customers').delete().eq('id', id);
  if (error) {
    console.error('Supabase delete error:', error);
    return null;
  }
  return data;
}

// Orders CRUD
async function fetchOrders() {
  const { data, error } = await supabase.from('orders').select('*');
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

async function addOrder(order) {
  const { data, error } = await supabase.from('orders').insert([order]);
  if (error) {
    console.error('Supabase insert error:', error);
    return null;
  }
  return data;
}

async function updateOrder(id, updates) {
  const { data, error } = await supabase.from('orders').update(updates).eq('id', id);
  if (error) {
    console.error('Supabase update error:', error);
    return null;
  }
  return data;
}

async function deleteOrder(id) {
  const { data, error } = await supabase.from('orders').delete().eq('id', id);
  if (error) {
    console.error('Supabase delete error:', error);
    return null;
  }
  return data;
}

// Stock Movements CRUD
async function fetchStockMovements() {
  const { data, error } = await supabase.from('stock_movements').select('*').order('movement_date', { ascending: false });
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

async function addStockMovement(movement) {
  const { data, error } = await supabase.from('stock_movements').insert([movement]);
  if (error) {
    console.error('Supabase insert error:', error);
    return null;
  }
  return data;
}

async function getStockMovementsByMedicine(medicineId) {
  const { data, error } = await supabase
    .from('stock_movements')
    .select('*')
    .eq('medicine_id', medicineId)
    .order('movement_date', { ascending: false });
  if (error) {
    console.error('Supabase fetch error:', error);
    return [];
  }
  return data;
}

// Stock Management Functions
async function updateMedicineStock(medicineId, newStock, movementType, quantity, reason, notes = null) {
  try {
    // Get current medicine data
    const { data: medicine, error: fetchError } = await supabase
      .from('medicines')
      .select('*')
      .eq('id', medicineId)
      .single();
    
    if (fetchError) {
      console.error('Error fetching medicine:', fetchError);
      return null;
    }

    if (!medicine) {
      console.error('Medicine not found with ID:', medicineId);
      return null;
    }

    const previousStock = medicine.stock || 0;
    
    // Update medicine stock
    const { data: updateData, error: updateError } = await supabase
      .from('medicines')
      .update({ stock: newStock })
      .eq('id', medicineId)
      .select();
    
    if (updateError) {
      console.error('Error updating medicine stock:', updateError);
      return null;
    }

    // Record stock movement
    const movement = {
      medicine_id: medicineId,
      medicine_name: medicine.name,
      movement_type: movementType,
      quantity: quantity,
      previous_stock: previousStock,
      new_stock: newStock,
      reason: reason,
      notes: notes,
      movement_date: new Date().toISOString().split('T')[0]
    };

    const movementResult = await addStockMovement(movement);
    
    if (!movementResult) {
      console.error('Warning: Stock updated but movement logging failed');
      // Still return success since the main operation (stock update) succeeded
    }
    
    console.log(`Stock update successful: ${medicine.name} stock updated from ${previousStock} to ${newStock}`);
    return updateData;
  } catch (error) {
    console.error('Error in updateMedicineStock:', error);
    return null;
  }
}

async function processStockIn(medicineId, quantity, reason = 'purchase', notes = null) {
  try {
    const { data: medicine, error } = await supabase
      .from('medicines')
      .select('stock, name')
      .eq('id', medicineId)
      .single();
    
    if (error) {
      console.error('Error fetching medicine:', error);
      return null;
    }

    if (!medicine) {
      console.error('Medicine not found');
      return null;
    }

    const currentStock = medicine.stock || 0;
    const newStock = currentStock + quantity;
    
    const result = await updateMedicineStock(medicineId, newStock, 'in', quantity, reason, notes);
    
    if (result) {
      console.log(`Stock IN successful: ${medicine.name} - Added ${quantity} units (${currentStock} → ${newStock})`);
    }
    
    return result;
  } catch (error) {
    console.error('Error in processStockIn:', error);
    return null;
  }
}

async function processStockOut(medicineId, quantity, reason = 'sale', notes = null) {
  try {
    const { data: medicine, error } = await supabase
      .from('medicines')
      .select('stock, name')
      .eq('id', medicineId)
      .single();
    
    if (error) {
      console.error('Error fetching medicine:', error);
      return null;
    }

    if (!medicine) {
      console.error('Medicine not found');
      return null;
    }

    const currentStock = medicine.stock || 0;
    
    if (currentStock < quantity) {
      console.error(`Insufficient stock: ${medicine.name} has only ${currentStock} units, but ${quantity} requested`);
      return null;
    }
    
    const newStock = currentStock - quantity;
    
    const result = await updateMedicineStock(medicineId, newStock, 'out', quantity, reason, notes);
    
    if (result) {
      console.log(`Stock OUT successful: ${medicine.name} - Removed ${quantity} units (${currentStock} → ${newStock})`);
    }
    
    return result;
  } catch (error) {
    console.error('Error in processStockOut:', error);
    return null;
  }
}
