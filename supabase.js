const SUPABASE_URL = "https://jcmscgxrxicwowsezbui.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjbXNjZ3hyeGljd293c2V6YnVpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NjExNzcsImV4cCI6MjA3MjMzNzE3N30.QqfFKCqV4oIsuNw5TAJoCbE7tVu7m8s8g8M6YzwcU68";

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function adminCreateUser(email, password, fullName, role = "receptionist", additionalData = {}) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");

  try {
    const { data: { session }, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !session) {
      throw new Error("Authentication required");
    }

    // Use SUPABASE_URL instead of undefined SUPABASE_API
    const response = await fetch(`${SUPABASE_URL}/functions/v1/admin-create-user`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${session.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        password,
        fullName,
        role,
        username: additionalData.username,
        phone: additionalData.phone,
        address: additionalData.address
      })
    });

    const result = await response.json();

    if (!response.ok) {
      throw new Error(result.error || 'User creation failed');
    }

    return result.user;
  } catch (error) {
    console.error("Admin create user error:", error);
    throw error;
  }
}

async function getCurrentUser() {
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (error) throw new Error(`Auth error: ${error.message}`);
  return user;
}

async function getUserProfile() {
  const user = await getCurrentUser();
  if (!user) return null;
  const { data, error } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("id", user.id)
    .eq("is_active", true)
    .single();
  if (error) throw new Error(`Profile fetch error: ${error.message}`);
  return data;
}

async function isAuthenticated() {
  return !!(await getCurrentUser());
}

async function hasRole(role) {
  const profile = await getUserProfile();
  return profile?.role === role;
}

async function isAdmin() {
  return await hasRole("admin");
}

async function isReceptionist() {
  const profile = await getUserProfile();
  return profile?.role === "receptionist" || profile?.role === "admin";
}

async function isCustomer() {
  return await hasRole("customer");
}

async function fetchAllUserProfiles() {
  const { data, error } = await supabase
    .from("user_profiles")
    .select("*")
    .eq("is_active", true)
    .order("full_name");
  if (error) throw new Error(`Fetch profiles error: ${error.message}`);
  return data || [];
}

async function fetchAllUsersForAdmin() {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  const { data, error } = await supabase
    .from("user_profiles")
    .select("*")
    .order("created_at", { ascending: false });
  
  if (error) throw new Error(`Fetch all users error: ${error.message}`);
  
  // Add email from auth metadata if available, otherwise use username-based email
  const usersWithEmail = (data || []).map(user => ({
    ...user,
    email: user.username ? `${user.username}@pharmacy.local` : 'No email'
  }));
  
  return usersWithEmail;
}

async function updateUserRole(userId, newRole) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("user_profiles")
    .update({ role: newRole, updated_by: user?.id })
    .eq("id", userId)
    .eq("is_active", true)
    .select();
  if (error) throw new Error(`Role update error: ${error.message}`);
  showSuccess("User role updated!");
  return data;
}

async function updateUserStatus(userId, isActive) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("user_profiles")
    .update({ 
      is_active: isActive, 
      updated_by: user?.id,
      updated_at: new Date().toISOString()
    })
    .eq("id", userId)
    .select();
  if (error) throw new Error(`User status update error: ${error.message}`);
  return data;
}

async function deleteUser(userId) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  const user = await getCurrentUser();
  
  // Soft delete by setting is_active to false
  const { data, error } = await supabase
    .from("user_profiles")
    .update({ 
      is_active: false, 
      updated_by: user?.id,
      updated_at: new Date().toISOString()
    })
    .eq("id", userId)
    .select();
  if (error) throw new Error(`User deletion error: ${error.message}`);
  return data;
}

async function getAllUsersWithDetails() {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  const { data, error } = await supabase
    .from("user_profiles")
    .select("*")
    .order("created_at", { ascending: false });
  
  if (error) throw new Error(`Fetch users error: ${error.message}`);
  return data || [];
}

async function searchUsers(searchTerm, role = null, isActive = null) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  let query = supabase
    .from("user_profiles")
    .select("*");
  
  if (searchTerm) {
    query = query.or(`full_name.ilike.%${searchTerm}%,username.ilike.%${searchTerm}%,email.ilike.%${searchTerm}%`);
  }
  
  if (role) {
    query = query.eq("role", role);
  }
  
  if (isActive !== null) {
    query = query.eq("is_active", isActive);
  }
  
  query = query.order("full_name");
  
  const { data, error } = await query;
  if (error) throw new Error(`Search users error: ${error.message}`);
  return data || [];
}

async function signIn(email, password, rememberMe = false) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });
  if (error) throw new Error(`Sign in error: ${error.message}`);
  if (rememberMe) {
    localStorage.setItem("rememberUser", email);
  }
  return data.user;
}

async function adminCreateUser(
  email,
  password,
  fullName,
  role = "receptionist",
  additionalData = {}
) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");

  // Admin still calls signUp for now
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName, role, ...additionalData } },
  });

  if (error) throw new Error(`Admin sign up error: ${error.message}`);
  return data.user;
}

async function createUserProfile(user, fullName, role, additionalData = {}) {
  const profileData = {
    id: user.id,
    username: additionalData.username || user.email.split("@")[0],
    full_name: fullName,
    role,
    phone: additionalData.phone || null,
    address: additionalData.address || null,
    created_by: user.id,
  };
  const { data, error } = await supabase
    .from("user_profiles")
    .insert([profileData]);
  if (error) throw new Error(`Profile creation error: ${error.message}`);
  return data;
}

async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw new Error(`Sign out error: ${error.message}`);
  localStorage.removeItem("rememberUser");
  window.location.href = "login.html";
}

supabase.auth.onAuthStateChange((event, session) => {
  if (event === "SIGNED_IN") {
    console.log("User signed in:", session.user);
  } else if (event === "SIGNED_OUT") {
    console.log("User signed out");
    if (window.location.pathname !== "/login.html") {
      window.location.href = "login.html";
    }
  }
});

async function fetchMedicines() {
  const { data, error } = await supabase
    .from("medicines")
    .select("*, medicine_categories(name), suppliers(name)")
    .eq("is_active", true)
    .order("name");
  if (error) throw new Error(`Medicines fetch error: ${error.message}`);
  return data || [];
}

async function addMedicine(medicine) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("medicines")
    .insert([{ ...medicine, created_by: user?.id }])
    .select();
  if (error) throw new Error(`Medicine insert error: ${error.message}`);
  showSuccess("Medicine added!");
  return data;
}

async function updateMedicine(id, updates) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("medicines")
    .update({ ...updates, updated_by: user?.id })
    .eq("id", id)
    .eq("is_active", true)
    .select();
  if (error) throw new Error(`Medicine update error: ${error.message}`);
  showSuccess("Medicine updated!");
  return data;
}

async function archiveMedicine(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const { data, error } = await supabase.rpc("deactivate_record", {
    p_table_name: "medicines",
    p_record_id: id,
  });
  if (error) throw new Error(`Medicine archive error: ${error.message}`);
  showSuccess("Medicine archived!");
  return data;
}

async function getLowStockMedicines() {
  const { data, error } = await supabase.rpc("get_low_stock_medicines");
  if (error) throw new Error(`Low stock fetch error: ${error.message}`);
  return data || [];
}

async function bulkAddMedicines(medicines) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  const user = await getCurrentUser();
  const medicinesWithMeta = medicines.map((m) => ({
    ...m,
    created_by: user?.id,
  }));
  const { data, error } = await supabase
    .from("medicines")
    .insert(medicinesWithMeta)
    .select();
  if (error) throw new Error(`Bulk insert error: ${error.message}`);
  showSuccess(`${medicines.length} medicines added!`);
  return data;
}

async function fetchOrders() {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    // First, fetch orders with basic relationships
    const { data: orders, error } = await supabase
      .from("orders")
      .select(`
        *,
        order_items(
          id, 
          medicine_id, 
          medicine_name, 
          quantity, 
          unit_price, 
          total_price, 
          batch_number, 
          expiry_date
        ),
        customers(
          name, 
          customer_id
        )
      `)
      .eq("is_active", true)
      .order("order_date", { ascending: false });
    
    if (error) throw new Error(`Orders fetch error: ${error.message}`);
    
    // If no orders, return empty array
    if (!orders || orders.length === 0) return [];
    
    // Get unique served_by user IDs
    const servedByIds = [...new Set(orders.map(order => order.served_by).filter(Boolean))];
    
    // Fetch user profiles for served_by users
    let userProfiles = {};
    if (servedByIds.length > 0) {
      const { data: profiles, error: profilesError } = await supabase
        .from("user_profiles")
        .select("id, full_name")
        .in("id", servedByIds);
      
      if (profilesError) {
        console.warn("Could not fetch user profiles:", profilesError.message);
      } else {
        // Create a lookup map
        userProfiles = profiles.reduce((acc, profile) => {
          acc[profile.id] = profile;
          return acc;
        }, {});
      }
    }
    
    // Process the data to add computed fields and served_by info
    const processedData = orders.map(order => ({
      ...order,
      customer_name: order.customers?.name || 'Walk-in Customer',
      served_by_name: userProfiles[order.served_by]?.full_name || 'Unknown',
      quantity: order.order_items?.reduce((sum, item) => sum + (item.quantity || 0), 0) || 0,
      items_count: order.order_items?.length || 0,
      total: order.total_amount || 0
    }));
    
    return processedData;
    
  } catch (error) {
    console.error("Fetch orders error:", error);
    throw error;
  }
}

async function getOrderStatistics(dateRange = 30) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - dateRange);
    
    const { data, error } = await supabase
      .from("orders")
      .select(`
        id,
        status,
        total_amount,
        order_date,
        payment_method
      `)
      .eq("is_active", true)
      .gte("order_date", startDate.toISOString().split('T')[0]);
    
    if (error) throw new Error(`Order statistics error: ${error.message}`);
    
    const stats = {
      total_orders: data.length,
      completed_orders: data.filter(o => o.status === 'completed').length,
      pending_orders: data.filter(o => o.status === 'pending').length,
      processing_orders: data.filter(o => o.status === 'processing').length,
      cancelled_orders: data.filter(o => o.status === 'cancelled').length,
      total_revenue: data
        .filter(o => o.status === 'completed')
        .reduce((sum, o) => sum + parseFloat(o.total_amount || 0), 0),
      average_order_value: 0,
      cash_orders: data.filter(o => o.payment_method === 'cash').length,
      insurance_orders: data.filter(o => o.payment_method === 'insurance').length,
      momo_orders: data.filter(o => o.payment_method === 'momo').length
    };
    
    stats.average_order_value = stats.completed_orders > 0 
      ? stats.total_revenue / stats.completed_orders 
      : 0;
    
    return stats;
    
  } catch (error) {
    console.error("Order statistics error:", error);
    throw error;
  }
}


async function getCustomerOrderHistory(customerId) {
  if (!((await isCustomer()) || (await isReceptionist())))
    throw new Error("Permission denied");
  const { data, error } = await supabase
    .from("orders")
    .select(
      `
      *, 
      order_items(id, medicine_id, medicine_name, quantity, unit_price, total_price, batch_number, expiry_date)
    `
    )
    .eq("customer_id", customerId)
    .eq("is_active", true)
    .order("order_date", { ascending: false });
  if (error) throw new Error(`Order history fetch error: ${error.message}`);
  return data || [];
}

async function createOrder(orderData, orderItems) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .insert([{ ...orderData, created_by: user?.id, served_by: user?.id }])
    .select()
    .single();
  if (orderError)
    throw new Error(`Order creation error: ${orderError.message}`);

  const itemsWithOrderId = orderItems.map((item) => ({
    ...item,
    order_id: order.id,
    total_price: item.quantity * item.unit_price,
  }));
  const { data: items, error: itemsError } = await supabase
    .from("order_items")
    .insert(itemsWithOrderId)
    .select();
  if (itemsError)
    throw new Error(`Order items creation error: ${itemsError.message}`);

  for (const item of orderItems) {
    await processStockOut(
      item.medicine_id,
      item.quantity,
      "sale",
      `Order ${order.order_number}`
    );
  }
  showSuccess(`Order ${order.order_number} created!`);
  return { ...order, order_items: items };
}

async function updateMedicineStock(
  medicineId,
  newStock,
  movementType,
  quantity,
  reason,
  notes = null
) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const { data: medicine, error: fetchError } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (fetchError)
    throw new Error(`Medicine fetch error: ${fetchError.message}`);

  const user = await getCurrentUser();
  const movement = {
    medicine_id: medicineId,
    medicine_name: medicine.name,
    movement_type: movementType,
    quantity,
    previous_stock: medicine.stock,
    new_stock: newStock,
    reason,
    notes,
    created_by: user?.id,
    movement_date: new Date().toISOString().split("T")[0],
  };
  const { error: movementError } = await supabase
    .from("stock_movements")
    .insert([movement]);
  if (movementError)
    throw new Error(`Stock movement error: ${movementError.message}`);

  const { data, error } = await supabase
    .from("medicines")
    .update({ stock: newStock })
    .eq("id", medicineId)
    .eq("is_active", true)
    .select();
  if (error) throw new Error(`Stock update error: ${error.message}`);
  showSuccess("Stock updated!");
  return data;
}

async function processStockIn(
  medicineId,
  quantity,
  reason = "purchase",
  notes = null
) {
  const { data: medicine, error } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (error) throw new Error(`Medicine fetch error: ${error.message}`);
  return await updateMedicineStock(
    medicineId,
    medicine.stock + quantity,
    "in",
    quantity,
    reason,
    notes
  );
}

async function processStockOut(
  medicineId,
  quantity,
  reason = "sale",
  notes = null
) {
  const { data: medicine, error } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (error) throw new Error(`Medicine fetch error: ${error.message}`);
  if (medicine.stock < quantity)
    throw new Error(
      `Insufficient stock: ${medicine.name} has ${medicine.stock} units`
    );
  return await updateMedicineStock(
    medicineId,
    medicine.stock - quantity,
    "out",
    quantity,
    reason,
    notes
  );
}

async function fetchStockMovements() {
  const { data, error } = await supabase
    .from("stock_movements")
    .select("*, medicines(name, strength), suppliers(name)")
    .eq("is_active", true)
    .order("movement_date", { ascending: false });
  if (error) throw new Error(`Stock movements fetch error: ${error.message}`);
  return data || [];
}

async function fetchSuppliers() {
  const { data, error } = await supabase
    .from("suppliers")
    .select("*")
    .eq("is_active", true)
    .order("name");
  if (error) throw new Error(`Suppliers fetch error: ${error.message}`);
  return data || [];
}

async function addSupplier(supplier) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("suppliers")
    .insert([{ ...supplier, created_by: user?.id }])
    .select();
  if (error) throw new Error(`Supplier insert error: ${error.message}`);
  showSuccess("Supplier added!");
  return data;
}

async function updateSupplier(id, updates) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("suppliers")
    .update({ ...updates, updated_by: user?.id })
    .eq("id", id)
    .eq("is_active", true)
    .select();
  if (error) throw new Error(`Supplier update error: ${error.message}`);
  showSuccess("Supplier updated!");
  return data;
}

async function deleteSupplier(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const { data, error } = await supabase.rpc("deactivate_record", {
    p_table_name: "suppliers",
    p_record_id: id,
  });
  if (error) throw new Error(`Supplier deletion error: ${error.message}`);
  showSuccess("Supplier deleted!");
  return data;
}

async function archiveSupplier(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const { data, error } = await supabase.rpc("deactivate_record", {
    p_table_name: "suppliers",
    p_record_id: id,
  });
  if (error) throw new Error(`Supplier archive error: ${error.message}`);
  showSuccess("Supplier archived!");
  return data;
}

async function fetchPurchaseOrders() {
  const { data, error } = await supabase
    .from("purchase_orders")
    .select(
      `
      *, 
      purchase_order_items(id, medicine_id, medicine_name, quantity_ordered, quantity_received, unit_cost, total_cost),
      suppliers(name)
    `
    )
    .eq("is_active", true)
    .order("order_date", { ascending: false });
  if (error) throw new Error(`Purchase orders fetch error: ${error.message}`);
  return data || [];
}

async function createPurchaseOrder(poData, poItems) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data: po, error: poError } = await supabase
    .from("purchase_orders")
    .insert([{ ...poData, created_by: user?.id }])
    .select()
    .single();
  if (poError)
    throw new Error(`Purchase order creation error: ${poError.message}`);

  const itemsWithPoId = poItems.map((item) => ({
    ...item,
    po_id: po.id,
    total_cost: item.quantity_ordered * item.unit_cost,
  }));
  const { data: items, error: itemsError } = await supabase
    .from("purchase_order_items")
    .insert(itemsWithPoId)
    .select();
  if (itemsError)
    throw new Error(
      `Purchase order items creation error: ${itemsError.message}`
    );
  showSuccess(`Purchase order ${po.po_number} created!`);
  return { ...po, purchase_order_items: items };
}

async function fetchAuditLogs(limit = 100) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  const { data, error } = await supabase
    .from("vw_audit_log_report")
    .select("*")
    .limit(limit)
    .order("created_at", { ascending: false });
  if (error) throw new Error(`Audit logs fetch error: ${error.message}`);
  return (
    data.map((log) => ({
      ...log,
      record_id: String(log.record_id),
    })) || []
  );
}

async function getSalesReport(startDate, endDate) {
  const { data, error } = await supabase.rpc("generate_sales_report", {
    start_date: startDate,
    end_date: endDate,
  });
  if (error) throw new Error(`Sales report error: ${error.message}`);
  return data || [];
}

async function getExpiringMedicines(daysAhead = 90) {
  const { data, error } = await supabase.rpc("get_expiring_medicines", {
    days_ahead: daysAhead,
  });
  if (error)
    throw new Error(`Expiring medicines fetch error: ${error.message}`);
  return data || [];
}

async function fetchNotifications() {
  const user = await getCurrentUser();
  const profile = await getUserProfile();
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("is_active", true)
    .or(
      `user_id.eq.${user?.id},target_role.eq.${profile?.role},target_role.eq.all`
    )
    .order("created_at", { ascending: false });
  if (error) throw new Error(`Notifications fetch error: ${error.message}`);
  return data || [];
}

async function markNotificationAsRead(notificationId) {
  const { data, error } = await supabase
    .from("notifications")
    .update({ is_read: true, read_at: new Date().toISOString() })
    .eq("id", notificationId)
    .eq("is_active", true)
    .select();
  if (error) throw new Error(`Notification update error: ${error.message}`);
  return data;
}

async function checkPermission(requiredRole) {
  const profile = await getUserProfile();
  if (!profile) return false;
  const roleHierarchy = { customer: 1, receptionist: 2, admin: 3 };
  return (
    (roleHierarchy[profile.role] || 0) >= (roleHierarchy[requiredRole] || 0)
  );
}

function formatCurrency(amount) {
  return new Intl.NumberFormat("rw-RW", {
    style: "currency",
    currency: "RWF",
    minimumFractionDigits: 0,
  }).format(amount);
}

function showError(message, container = null) {
  const errorDiv = document.createElement("div");
  errorDiv.className = "notification error";
  errorDiv.innerHTML = `
    <span>${message}</span>
    <button onclick="this.parentElement.remove()" class="ml-3">
      <i class="fas fa-times"></i>
    </button>
  `;
  (container || document.body).appendChild(errorDiv);
  setTimeout(() => errorDiv.classList.add("show"), 100);
  setTimeout(() => {
    errorDiv.classList.remove("show");
    setTimeout(() => errorDiv.remove(), 300);
  }, 5000);
}

function showSuccess(message, container = null) {
  const successDiv = document.createElement("div");
  successDiv.className = "notification success";
  successDiv.innerHTML = `
    <span>${message}</span>
    <button onclick="this.parentElement.remove()" class="ml-3">
      <i class="fas fa-times"></i>
    </button>
  `;
  (container || document.body).appendChild(successDiv);
  setTimeout(() => successDiv.classList.add("show"), 100);
  setTimeout(() => {
    successDiv.classList.remove("show");
    setTimeout(() => successDiv.remove(), 300);
  }, 3000);
}

function showLoading(element) {
  if (element) element.innerHTML = '<div class="loading">Loading...</div>';
}

function hideLoading(element, originalContent) {
  if (element) element.innerHTML = originalContent;
}

// =============================================
// POS ANALYTICS API FUNCTIONS FOR FRONTEND
// =============================================

// 1. TODAY'S LIVE DASHBOARD METRICS
async function getTodaysLiveDashboard() {
  try {
    const { data, error } = await supabase.rpc('get_todays_pos_metrics');
    if (error) throw new Error(`Live dashboard error: ${error.message}`);
    return data;
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 2. STAFF PERFORMANCE ANALYTICS
async function getStaffPerformanceAnalysis(days = 7) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    const { data, error } = await supabase.rpc('get_staff_performance_analysis', {
      analysis_date: new Date().toISOString().split('T')[0],
      period_days: days
    });
    if (error) throw new Error(`Staff performance error: ${error.message}`);
    return data || [];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 3. INDIVIDUAL STAFF PERFORMANCE
async function getIndividualStaffMetrics(staffId, days = 30) {
  if (!(await isAdmin()) && staffId !== (await getCurrentUser())?.id) {
    throw new Error("Permission denied");
  }
  
  try {
    const { data, error } = await supabase
      .from('staff_performance')
      .select(`
        *,
        staff_shifts(
          shift_date,
          actual_hours,
          shift_type
        )
      `)
      .eq('staff_id', staffId)
      .gte('performance_date', new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
      .order('performance_date', { ascending: false });
    
    if (error) throw new Error(`Individual metrics error: ${error.message}`);
    return data || [];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 4. PEAK HOURS ANALYSIS (Simplified)
async function getPeakHoursAnalysis(days = 30) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    // Try the RPC function first, fall back to basic query if it fails
    try {
      const { data, error } = await supabase.rpc('get_peak_hours_analysis', {
        analysis_date: new Date().toISOString().split('T')[0],
        period_days: days
      });
      if (error) throw error;
      return data || [];
    } catch (rpcError) {
      console.warn('Peak hours RPC failed, using fallback query:', rpcError.message);
      
      // Fallback: Basic query for peak hours
      const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
      const { data, error } = await supabase
        .from('orders')
        .select('created_at, total_amount')
        .gte('order_date', startDate)
        .eq('status', 'completed')
        .eq('is_active', true);
      
      if (error) throw error;
      
      // Process data to group by hour
      const hourStats = {};
      data.forEach(order => {
        const hour = new Date(order.created_at).getHours();
        if (!hourStats[hour]) {
          hourStats[hour] = {
            hour_of_day: hour,
            average_orders: 0,
            average_revenue: 0,
            peak_staff_needed: 1,
            customer_wait_time: 0,
            order_count: 0
          };
        }
        hourStats[hour].order_count += 1;
        hourStats[hour].average_revenue += parseFloat(order.total_amount || 0);
      });
      
      // Calculate averages
      Object.values(hourStats).forEach(stat => {
        stat.average_orders = stat.order_count / days;
        stat.average_revenue = stat.average_revenue / days;
      });
      
      return Object.values(hourStats).sort((a, b) => b.average_orders - a.average_orders);
    }
  } catch (error) {
    console.error('Peak hours analysis error:', error.message);
    return [];
  }
}

// 5. DAILY CASH RECONCILIATION
async function getDailyCashReconciliation(date = null) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  const reconciliationDate = date || new Date().toISOString().split('T')[0];
  
  try {
    const { data, error } = await supabase.rpc('get_daily_cash_reconciliation', {
      reconciliation_date: reconciliationDate
    });
    if (error) throw new Error(`Cash reconciliation error: ${error.message}`);
    return data;
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 6. SHIFT MANAGEMENT
async function clockInStaff(shiftType = 'full_day') {
  try {
    const user = await getCurrentUser();
    const { data, error } = await supabase
      .from('staff_shifts')
      .insert([{
        staff_id: user.id,
        shift_type: shiftType,
        clock_in_time: new Date().toISOString(),
        shift_date: new Date().toISOString().split('T')[0]
      }])
      .select();
    
    if (error) throw new Error(`Clock in error: ${error.message}`);
    showSuccess('Clocked in successfully!');
    return data[0];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

async function clockOutStaff(shiftId, notes = null) {
  try {
    const { data, error } = await supabase
      .from('staff_shifts')
      .update({
        clock_out_time: new Date().toISOString(),
        notes: notes
      })
      .eq('id', shiftId)
      .eq('staff_id', (await getCurrentUser()).id)
      .select();
    
    if (error) throw new Error(`Clock out error: ${error.message}`);
    showSuccess('Clocked out successfully!');
    return data[0];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 7. CASH REGISTER SESSION MANAGEMENT
async function openCashRegisterSession(openingBalance = 0) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    const sessionId = `CS${Date.now()}`;
    
    const { data, error } = await supabase
      .from('cash_register_sessions')
      .insert([{
        session_id: sessionId,
        staff_id: user.id,
        opening_balance: openingBalance,
        session_date: new Date().toISOString().split('T')[0]
      }])
      .select();
    
    if (error) throw new Error(`Cash session error: ${error.message}`);
    showSuccess('Cash register session opened!');
    return data[0];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

async function closeCashRegisterSession(sessionId, closingBalance, notes = null) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    // Get session data first
    const { data: session, error: sessionError } = await supabase
      .from('cash_register_sessions')
      .select('*')
      .eq('session_id', sessionId)
      .eq('staff_id', (await getCurrentUser()).id)
      .single();
    
    if (sessionError) throw new Error(`Session fetch error: ${sessionError.message}`);
    
    // Calculate expected cash from orders
    const { data: cashOrders, error: ordersError } = await supabase
      .from('orders')
      .select('total_amount')
      .eq('payment_method', 'cash')
      .eq('order_date', session.session_date)
      .eq('served_by', session.staff_id)
      .eq('status', 'completed');
    
    if (ordersError) throw new Error(`Orders fetch error: ${ordersError.message}`);
    
    const expectedCash = session.opening_balance + (cashOrders?.reduce((sum, order) => sum + parseFloat(order.total_amount), 0) || 0);
    const variance = closingBalance - expectedCash;
    
    const { data, error } = await supabase
      .from('cash_register_sessions')
      .update({
        session_end_time: new Date().toISOString(),
        closing_balance: closingBalance,
        total_cash_sales: expectedCash - session.opening_balance,
        cash_variance: variance,
        is_balanced: Math.abs(variance) < 100, // Allow 100 RWF tolerance
        notes: notes
      })
      .eq('session_id', sessionId)
      .select();
    
    if (error) throw new Error(`Cash session close error: ${error.message}`);
    
    if (Math.abs(variance) >= 100) {
      showError(`Cash variance detected: ${formatCurrency(variance)}. Please check your counts.`);
    } else {
      showSuccess('Cash register session closed successfully!');
    }
    
    return data[0];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 8. MEDICINE DISPENSING PERFORMANCE (Simplified)
async function getMedicineDispensingPerformance(days = 7) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    const startDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const endDate = new Date().toISOString().split('T')[0];
    
    // Try the RPC function first, fall back to basic query if it fails
    try {
      const { data, error } = await supabase.rpc('get_medicine_dispensing_performance', {
        start_date: startDate,
        end_date: endDate
      });
      
      if (error) throw error;
      return data || [];
    } catch (rpcError) {
      console.warn('RPC function failed, using fallback query:', rpcError.message);
      
      // Fallback: Basic query for medicine performance
      const { data, error } = await supabase
        .from('order_items')
        .select(`
          medicine_name,
          quantity,
          medicines!inner(
            strength
          ),
          orders!inner(
            order_date,
            status,
            is_active
          )
        `)
        .gte('orders.order_date', startDate)
        .lte('orders.order_date', endDate)
        .eq('orders.status', 'completed')
        .eq('orders.is_active', true)
        .eq('is_active', true);
      
      if (error) throw error;
      
      // Process data to group by medicine
      const medicineStats = {};
      data.forEach(item => {
        const medicineKey = `${item.medicine_name}${item.medicines?.strength ? ` (${item.medicines.strength})` : ''}`;
        if (!medicineStats[medicineKey]) {
          medicineStats[medicineKey] = {
            medicine_name: medicineKey,
            total_dispensed: 0,
            dispensing_staff_count: 1,
            average_per_staff: 0,
            fastest_dispensing_time: 0,
            slowest_dispensing_time: 0,
            error_rate: 0
          };
        }
        medicineStats[medicineKey].total_dispensed += item.quantity;
      });
      
      return Object.values(medicineStats).sort((a, b) => b.total_dispensed - a.total_dispensed);
    }
  } catch (error) {
    console.error('Medicine dispensing performance error:', error.message);
    return [];
  }
}

// 9. SHIFT HANDOVER REPORT
async function getShiftHandoverReport(date = null, shiftType = 'morning') {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    const reportDate = date || new Date().toISOString().split('T')[0];
    
    const { data, error } = await supabase.rpc('get_shift_handover_report', {
      shift_date: reportDate,
      shift_type: shiftType
    });
    
    if (error) throw new Error(`Handover report error: ${error.message}`);
    return data;
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 10. TRANSACTION PERFORMANCE TRACKING
async function startTransactionTimer(orderId) {
  try {
    const user = await getCurrentUser();
    const { data, error } = await supabase
      .from('transaction_performance')
      .insert([{
        order_id: orderId,
        staff_id: user.id,
        transaction_start_time: new Date().toISOString()
      }])
      .select();
    
    if (error) throw new Error(`Transaction timer error: ${error.message}`);
    return data[0];
  } catch (error) {
    console.error('Transaction timer error:', error.message);
    return null;
  }
}

async function endTransactionTimer(orderId, itemsCount = 1, wasError = false, errorType = null) {
  try {
    const endTime = new Date().toISOString();
    
    // Get start time
    const { data: transaction, error: fetchError } = await supabase
      .from('transaction_performance')
      .select('transaction_start_time')
      .eq('order_id', orderId)
      .single();
    
    if (fetchError) {
      console.error('Transaction fetch error:', fetchError.message);
      return null;
    }
    
    const startTime = new Date(transaction.transaction_start_time);
    const duration = Math.round((new Date(endTime) - startTime) / 1000);
    
    const { data, error } = await supabase
      .from('transaction_performance')
      .update({
        transaction_end_time: endTime,
        processing_duration: duration,
        items_count: itemsCount,
        was_error: wasError,
        error_type: errorType
      })
      .eq('order_id', orderId)
      .select();
    
    if (error) throw new Error(`Transaction end error: ${error.message}`);
    return data[0];
  } catch (error) {
    console.error('Transaction end error:', error.message);
    return null;
  }
}

// 11. STAFF EFFICIENCY RANKING
async function getStaffEfficiencyRanking(period = 'weekly') {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    let days;
    switch (period) {
      case 'daily': days = 1; break;
      case 'weekly': days = 7; break;
      case 'monthly': days = 30; break;
      default: days = 7;
    }
    
    const { data, error } = await supabase.rpc('get_staff_performance_analysis', {
      analysis_date: new Date().toISOString().split('T')[0],
      period_days: days
    });
    
    if (error) throw new Error(`Staff ranking error: ${error.message}`);
    return data || [];
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 12. CUSTOMER FLOW ANALYSIS
async function getCustomerFlowAnalysis(days = 30) {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    const { data, error } = await supabase
      .from('orders')
      .select(`
        created_at,
        order_date,
        customer_id,
        total_amount,
        transaction_performance(processing_duration, customer_wait_time)
      `)
      .gte('order_date', new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
      .eq('status', 'completed')
      .eq('is_active', true)
      .order('created_at', { ascending: false });
    
    if (error) throw new Error(`Customer flow error: ${error.message}`);
    
    // Process data for flow analysis
    const flowData = data?.reduce((acc, order) => {
      const hour = new Date(order.created_at).getHours();
      if (!acc[hour]) {
        acc[hour] = {
          hour,
          customer_count: 0,
          average_wait_time: 0,
          total_wait_time: 0,
          revenue: 0
        };
      }
      
      acc[hour].customer_count += 1;
      acc[hour].revenue += parseFloat(order.total_amount);
      
      if (order.transaction_performance?.[0]?.customer_wait_time) {
        acc[hour].total_wait_time += order.transaction_performance[0].customer_wait_time;
        acc[hour].average_wait_time = acc[hour].total_wait_time / acc[hour].customer_count;
      }
      
      return acc;
    }, {}) || {};
    
    return Object.values(flowData).sort((a, b) => a.hour - b.hour);
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// 13. WEEKLY PERFORMANCE SUMMARY (Simplified)
async function getWeeklyPerformanceSummary() {
  if (!(await isReceptionist())) throw new Error("Permission denied: Staff only");
  
  try {
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - startOfWeek.getDay());
    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(endOfWeek.getDate() + 6);
    
    // Try RPC function first, fall back to basic query
    try {
      const { data: weeklyData, error } = await supabase.rpc('generate_sales_report', {
        start_date: startOfWeek.toISOString().split('T')[0],
        end_date: endOfWeek.toISOString().split('T')[0]
      });
      
      if (error) throw error;
      
      // Calculate totals from daily data
      const totals = weeklyData?.reduce((acc, day) => ({
        total_orders: acc.total_orders + (day.total_orders || 0),
        total_revenue: acc.total_revenue + (day.gross_sales || 0),
        avg_order_value: 0, // Will calculate after
        top_medicines_count: 0
      }), { total_orders: 0, total_revenue: 0, avg_order_value: 0, top_medicines_count: 0 }) || {};
      
      if (totals.total_orders > 0) {
        totals.avg_order_value = totals.total_revenue / totals.total_orders;
      }
      
      return {
        sales_data: totals,
        top_medicines: [],
        week_start: startOfWeek.toISOString().split('T')[0],
        week_end: endOfWeek.toISOString().split('T')[0]
      };
      
    } catch (rpcError) {
      console.warn('Weekly summary RPC failed, using fallback:', rpcError.message);
      
      // Fallback: Basic query for weekly summary
      const { data, error } = await supabase
        .from('orders')
        .select('total_amount, order_date')
        .gte('order_date', startOfWeek.toISOString().split('T')[0])
        .lte('order_date', endOfWeek.toISOString().split('T')[0])
        .eq('status', 'completed')
        .eq('is_active', true);
      
      if (error) throw error;
      
      const totals = {
        total_orders: data.length,
        total_revenue: data.reduce((sum, order) => sum + parseFloat(order.total_amount || 0), 0),
        avg_order_value: 0,
        top_medicines_count: 0
      };
      
      if (totals.total_orders > 0) {
        totals.avg_order_value = totals.total_revenue / totals.total_orders;
      }
      
      return {
        sales_data: totals,
        top_medicines: [],
        week_start: startOfWeek.toISOString().split('T')[0],
        week_end: endOfWeek.toISOString().split('T')[0]
      };
    }
  } catch (error) {
    console.warn('Weekly summary error:', error.message);
    return {
      sales_data: { total_orders: 0, total_revenue: 0, avg_order_value: 0, top_medicines_count: 0 },
      top_medicines: [],
      week_start: startOfWeek.toISOString().split('T')[0],
      week_end: endOfWeek.toISOString().split('T')[0]
    };
  }
}

// 14. REAL-TIME ALERTS
async function checkRealTimeAlerts() {
  try {
    const alerts = [];
    
    // Check low stock
    const lowStock = await getLowStockMedicines();
    if (lowStock.length > 0) {
      alerts.push({
        type: 'warning',
        title: 'Low Stock Alert',
        message: `${lowStock.length} medicines are running low`,
        action_url: '/inventory',
        priority: 'high'
      });
    }
    
    // Check unbalanced cash sessions from today
    const { data: unbalancedSessions } = await supabase
      .from('cash_register_sessions')
      .select('staff_id, cash_variance, user_profiles(full_name)')
      .eq('session_date', new Date().toISOString().split('T')[0])
      .eq('is_balanced', false);
    
    if (unbalancedSessions?.length > 0) {
      alerts.push({
        type: 'error',
        title: 'Cash Variance Detected',
        message: `${unbalancedSessions.length} cash sessions have variances`,
        action_url: '/cash-reconciliation',
        priority: 'urgent'
      });
    }
    
    // Check pending orders older than 30 minutes
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    const { data: oldPendingOrders } = await supabase
      .from('orders')
      .select('id, order_number, created_at')
      .in('status', ['pending', 'processing'])
      .lt('created_at', thirtyMinutesAgo)
      .eq('is_active', true);
    
    if (oldPendingOrders?.length > 0) {
      alerts.push({
        type: 'warning',
        title: 'Pending Orders Alert',
        message: `${oldPendingOrders.length} orders pending for over 30 minutes`,
        action_url: '/orders',
        priority: 'medium'
      });
    }
    
    return alerts;
  } catch (error) {
    console.error('Real-time alerts error:', error.message);
    return [];
  }
}

// 15. PERFORMANCE COMPARISON
async function getPerformanceComparison(currentPeriod = 7, comparisonPeriod = 7) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    const currentEnd = new Date().toISOString().split('T')[0];
    const currentStart = new Date(Date.now() - currentPeriod * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    const comparisonEnd = new Date(Date.now() - currentPeriod * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const comparisonStart = new Date(Date.now() - (currentPeriod + comparisonPeriod) * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    // Current period metrics
    const currentMetrics = await supabase.rpc('get_dashboard_metrics', {
      start_date: currentStart,
      end_date: currentEnd,
      compare_previous: false
    });
    
    // Comparison period metrics
    const comparisonMetrics = await supabase.rpc('get_dashboard_metrics', {
      start_date: comparisonStart,
      end_date: comparisonEnd,
      compare_previous: false
    });
    
    if (currentMetrics.error) throw new Error(`Current metrics error: ${currentMetrics.error.message}`);
    if (comparisonMetrics.error) throw new Error(`Comparison metrics error: ${comparisonMetrics.error.message}`);
    
    return {
      current: currentMetrics.data?.current,
      previous: comparisonMetrics.data?.current,
      growth_rates: calculateGrowthRates(currentMetrics.data?.current, comparisonMetrics.data?.current)
    };
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

// Helper function to calculate growth rates
function calculateGrowthRates(current, previous) {
  if (!current || !previous) return {};
  
  const calculateGrowth = (curr, prev) => {
    if (prev === 0) return curr > 0 ? 100 : 0;
    return Math.round(((curr - prev) / prev) * 100 * 100) / 100;
  };
  
  return {
    orders_growth: calculateGrowth(current.total_orders, previous.total_orders),
    revenue_growth: calculateGrowth(current.total_revenue, previous.total_revenue),
    customers_growth: calculateGrowth(current.total_customers, previous.total_customers),
    avg_order_growth: calculateGrowth(current.average_order_value, previous.average_order_value)
  };
}

// 16. EXPORT FUNCTIONS FOR REPORTS
async function exportStaffPerformanceReport(days = 30, format = 'json') {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    const performanceData = await getStaffPerformanceAnalysis(days);
    const exportData = {
      report_type: 'Staff Performance Report',
      period_days: days,
      generated_at: new Date().toISOString(),
      data: performanceData
    };
    
    if (format === 'csv') {
      return convertToCSV(performanceData);
    }
    
    return exportData;
  } catch (error) {
    showError(error.message);
    throw error;
  }
}

function convertToCSV(data) {
  if (!data || data.length === 0) return '';
  
  const headers = Object.keys(data[0]);
  const csvContent = [
    headers.join(','),
    ...data.map(row => headers.map(header => `"${row[header] || ''}"`).join(','))
  ].join('\n');
  
  return csvContent;
}

// Check daily notification limits based on priority
async function checkNotificationLimits(priority) {
  try {
    const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format

    // Define limits
    const limits = {
      'urgent': 3,    // Critical notifications: 3 per day
      'high': 3,      // Critical notifications: 3 per day
      'medium': 2,    // Medium notifications: 2 per day
      'low': 10,      // Low priority: 10 per day (reasonable limit)
      'normal': 5     // Normal: 5 per day
    };

    const limit = limits[priority] || 5;

    // Count notifications created today with this priority
    const { data: todaysNotifications, error } = await supabase
      .from('notifications')
      .select('id')
      .eq('priority', priority)
      .gte('created_at', `${today}T00:00:00.000Z`)
      .lt('created_at', `${today}T23:59:59.999Z`);

    if (error) {
      console.error('Error checking notification limits:', error);
      return true; // Allow notification if we can't check limits
    }

    const count = todaysNotifications ? todaysNotifications.length : 0;
    return count < limit;
  } catch (error) {
    console.error('Error in checkNotificationLimits:', error);
    return true; // Allow notification if there's an error
  }
}

async function createNotification(notificationData) {
  try {
    // Check daily limits based on priority
    const canCreate = await checkNotificationLimits(notificationData.priority || 'low');
    if (!canCreate) {
      console.log(`Daily limit reached for ${notificationData.priority || 'low'} priority notifications`);
      return null; // Silently skip creating notification
    }

    const { data, error } = await supabase
      .from("notifications")
      .insert([{
        title: notificationData.title,
        message: notificationData.message,
        notification_type: notificationData.type || 'warning',
        target_role: notificationData.targetRole || 'admin',
        related_to: notificationData.relatedTo || 'medicine',
        related_id: notificationData.relatedId,
        priority: notificationData.priority || 'low',
        action_required: notificationData.actionRequired || false,
        action_url: notificationData.actionUrl
      }])
      .select();

    if (error) throw new Error(`Notification creation error: ${error.message}`);
    return data[0];
  } catch (error) {
    console.error('Error creating notification:', error);
    throw error;
  }
}

// Helper function to create notifications for both admins and receptionists
async function createNotificationForStaff(notificationData) {
  try {
    // Create notification for admin
    const adminNotification = await createNotification({
      ...notificationData,
      targetRole: 'admin'
    });

    // Create notification for receptionist
    const receptionistNotification = await createNotification({
      ...notificationData,
      targetRole: 'receptionist'
    });

    return { adminNotification, receptionistNotification };
  } catch (error) {
    console.error('Error creating staff notifications:', error);
    throw error;
  }
}

// Function to check and create automatic notifications for low stock and expiring medicines
async function checkAndCreateStockNotifications() {
  try {
    // Check for low stock medicines
    const lowStockMedicines = await getLowStockMedicines();
    if (lowStockMedicines.length > 0) {
      // Check if we already have a recent notification for low stock
      const { data: recentNotifications } = await supabase
        .from('notifications')
        .select('id')
        .eq('related_to', 'stock')
        .eq('notification_type', 'warning')
        .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()) // Last 24 hours
        .limit(1);

      if (!recentNotifications || recentNotifications.length === 0) {
        await createNotificationForStaff({
          title: 'Low Stock Alert',
          message: `${lowStockMedicines.length} medicine${lowStockMedicines.length > 1 ? 's are' : ' is'} running low on stock`,
          type: 'warning',
          relatedTo: 'stock',
          priority: 'high',
          actionUrl: 'medicines.html'
        });
      }
    }

    // Check for expiring medicines (within 30 days)
    const expiringMedicines = await getExpiringMedicines(30);
    if (expiringMedicines.length > 0) {
      // Check if we already have a recent notification for expiring medicines
      const { data: recentExpiryNotifications } = await supabase
        .from('notifications')
        .select('id')
        .eq('related_to', 'expiry')
        .eq('notification_type', 'warning')
        .gte('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()) // Last 24 hours
        .limit(1);

      if (!recentExpiryNotifications || recentExpiryNotifications.length === 0) {
        await createNotificationForStaff({
          title: 'Medicine Expiry Alert',
          message: `${expiringMedicines.length} medicine${expiringMedicines.length > 1 ? 's are' : ' is'} expiring within 30 days`,
          type: 'warning',
          relatedTo: 'expiry',
          priority: 'medium',
          actionUrl: 'medicines.html'
        });
      }
    }

    return { lowStock: lowStockMedicines.length, expiring: expiringMedicines.length };
  } catch (error) {
    console.error('Error checking stock notifications:', error);
    return { lowStock: 0, expiring: 0 };
  }
}

// Fetch all notifications with pagination
async function fetchAllNotifications(page = 1, limit = 50, filters = {}) {
  try {
    const user = await getCurrentUser();
    if (!user) return { notifications: [], total: 0 };

    const userProfile = await getUserProfile();
    if (!userProfile) return { notifications: [], total: 0 };

    let query = supabase
      .from('notifications')
      .select('*', { count: 'exact' })
      .eq('target_role', userProfile.role)
      .order('created_at', { ascending: false });

    // Apply filters
    if (filters.priority) {
      query = query.eq('priority', filters.priority);
    }
    if (filters.type) {
      query = query.eq('notification_type', filters.type);
    }
    if (filters.isRead !== undefined) {
      query = query.eq('is_read', filters.isRead);
    }
    if (filters.dateFrom) {
      query = query.gte('created_at', filters.dateFrom);
    }
    if (filters.dateTo) {
      query = query.lt('created_at', filters.dateTo);
    }

    // Apply pagination
    const from = (page - 1) * limit;
    const to = from + limit - 1;
    query = query.range(from, to);

    const { data, error, count } = await query;

    if (error) throw new Error(`Fetch notifications error: ${error.message}`);

    return {
      notifications: data || [],
      total: count || 0,
      page,
      limit,
      totalPages: Math.ceil((count || 0) / limit)
    };
  } catch (error) {
    console.error('Error fetching all notifications:', error);
    return { notifications: [], total: 0, page, limit, totalPages: 0 };
  }
}

// Mark notification as read
async function markNotificationAsRead(notificationId) {
  try {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', notificationId);

    if (error) throw new Error(`Mark as read error: ${error.message}`);
  } catch (error) {
    console.error('Error marking notification as read:', error);
    throw error;
  }
}

// Get notification statistics
async function getNotificationStats() {
  try {
    const user = await getCurrentUser();
    if (!user) return {};

    const userProfile = await getUserProfile();
    if (!userProfile) return {};

    const today = new Date().toISOString().split('T')[0];

    // Get today's notifications count by priority
    const { data: todayStats, error: todayError } = await supabase
      .from('notifications')
      .select('priority')
      .eq('target_role', userProfile.role)
      .gte('created_at', `${today}T00:00:00.000Z`)
      .lt('created_at', `${today}T23:59:59.999Z`);

    if (todayError) {
      console.error('Error fetching today stats:', todayError);
    }

    // Get unread count
    const { count: unreadCount, error: unreadError } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('target_role', userProfile.role)
      .eq('is_read', false);

    if (unreadError) {
      console.error('Error fetching unread count:', unreadError);
    }

    // Count by priority
    const priorityCounts = {};
    if (todayStats) {
      todayStats.forEach(notification => {
        priorityCounts[notification.priority] = (priorityCounts[notification.priority] || 0) + 1;
      });
    }

    return {
      todayByPriority: priorityCounts,
      unreadCount: unreadCount || 0,
      limits: {
        urgent: 3,
        high: 3,
        medium: 2,
        low: 10,
        normal: 5
      }
    };
  } catch (error) {
    console.error('Error getting notification stats:', error);
    return {};
  }
}

// =============================================
// CUSTOMERS API FUNCTIONS
// =============================================

async function fetchCustomers() {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const { data, error } = await supabase
    .from("customers")
    .select("*")
    .eq("is_active", true)
    .order("name");
  
  if (error) throw new Error(`Customers fetch error: ${error.message}`);
  return data || [];
}

async function addCustomer(customer) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const user = await getCurrentUser();
  const customerData = {
    customer_id: `CUS${Date.now()}`,
    name: customer.name,
    phone: customer.phone,
    email: customer.email,
    address: customer.address,
    created_by: user?.id
  };
  
  const { data, error } = await supabase
    .from("customers")
    .insert([customerData])
    .select();
  
  if (error) throw new Error(`Customer insert error: ${error.message}`);
  showSuccess("Customer added successfully!");
  return data[0];
}

async function updateCustomer(id, updates) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const user = await getCurrentUser();
  const { data, error } = await supabase
    .from("customers")
    .update({ ...updates, updated_at: new Date().toISOString() })
    .eq("id", id)
    .eq("is_active", true)
    .select();
  
  if (error) throw new Error(`Customer update error: ${error.message}`);
  showSuccess("Customer updated successfully!");
  return data[0];
}

async function deleteCustomer(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const { data, error } = await supabase
    .from("customers")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select();
  
  if (error) throw new Error(`Customer deletion error: ${error.message}`);
  showSuccess("Customer deleted successfully!");
  return data[0];
}

// =============================================
// ORDERS API FUNCTIONS
// =============================================

async function addOrder(orderData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const user = await getCurrentUser();
  
  try {
    // Generate order number
    const orderNumber = `ORD${Date.now()}`;
    
    // Create the order
    const newOrder = {
      order_number: orderNumber,
      customer_id: orderData.customerId || null, // Allow null for walk-in customers
      order_type: 'direct',
      subtotal: orderData.total,
      total_amount: orderData.total,
      status: orderData.status || 'pending',
      payment_status: 'unpaid',
      payment_method: 'cash',
      served_by: user?.id,
      order_date: orderData.date || new Date().toISOString().split('T')[0],
      created_by: user?.id
    };
    
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert([newOrder])
      .select()
      .single();
    
    if (orderError) throw new Error(`Order creation error: ${orderError.message}`);
    
    // Create order items
    if (orderData.medicines && orderData.medicines.length > 0) {
      const orderItems = orderData.medicines.map(medicine => ({
        order_id: order.id,
        medicine_id: medicine.medicineId,
        medicine_name: medicine.medicineName || 'Unknown Medicine',
        quantity: medicine.quantity,
        unit_price: medicine.price,
        total_price: medicine.quantity * medicine.price
      }));
      
      const { data: items, error: itemsError } = await supabase
        .from("order_items")
        .insert(orderItems)
        .select();
      
      if (itemsError) throw new Error(`Order items creation error: ${itemsError.message}`);
      
      // Update medicine stock for each item
      for (const medicine of orderData.medicines) {
        try {
          await processStockOut(
            medicine.medicineId,
            medicine.quantity,
            "sale",
            `Order ${orderNumber}`
          );
        } catch (stockError) {
          console.warn(`Stock update warning for medicine ${medicine.medicineId}: ${stockError.message}`);
          // Create notification for stock issues for both admin and receptionist
            await createNotificationForStaff({
            title: 'Stock Update Warning',
            message: `Stock update failed for order ${orderNumber}: ${stockError.message}`,
            type: 'warning',
            relatedTo: 'order',
            relatedId: order.id,
            priority: 'normal'
            }).catch(err => console.warn('Notification creation failed:', err));
        }
      }
    }
    
    showSuccess(`Order ${orderNumber} created successfully!`);
    return order;
  } catch (error) {
    console.error('Error creating order:', error);
    throw error;
  }
}

async function deleteOrder(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const { data, error } = await supabase
    .from("orders")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("id", id)
    .select();
  
  if (error) throw new Error(`Order deletion error: ${error.message}`);
  showSuccess("Order deleted successfully!");
  return data[0];
}

async function updateOrderStatus(id, status) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  const { data, error } = await supabase
    .from("orders")
    .update({ 
      status: status, 
      updated_at: new Date().toISOString(),
      ...(status === 'completed' && { payment_status: 'paid' })
    })
    .eq("id", id)
    .eq("is_active", true)
    .select();
  
  if (error) throw new Error(`Order status update error: ${error.message}`);
  showSuccess(`Order status updated to ${status}!`);
  return data[0];
}

async function getOrderDetails(id) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    // Fetch order details
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select(`
        *,
        customers(name, customer_id, phone)
      `)
      .eq("id", id)
      .eq("is_active", true)
      .single();
    
    if (orderError) throw new Error(`Order fetch error: ${orderError.message}`);
    
    // Fetch order items
    const { data: items, error: itemsError } = await supabase
      .from("order_items")
      .select("*, medicines(strength)")
      .eq("order_id", id)
      .eq("is_active", true);
    
    if (itemsError) throw new Error(`Order items fetch error: ${itemsError.message}`);
    
    // Fetch served_by user profile
    let servedByProfile = null;
    if (order.served_by) {
      const { data: profile, error: profileError } = await supabase
        .from("user_profiles")
        .select("full_name")
        .eq("id", order.served_by)
        .single();
      
      if (!profileError) {
        servedByProfile = profile;
      }
    }
    
    return {
      ...order,
      order_items: items || [],
      served_by_name: servedByProfile?.full_name || 'Unknown',
      customer_name: order.customers?.name || 'Walk-in Customer'
    };
    
  } catch (error) {
    console.error("Get order details error:", error);
    throw error;
  }
}

// =============================================
// EXPORT FUNCTIONS TO WINDOW
// =============================================

// Make notification functions globally available
window.fetchAllNotifications = fetchAllNotifications;
window.markNotificationAsRead = markNotificationAsRead;
window.getNotificationStats = getNotificationStats;
window.checkNotificationLimits = checkNotificationLimits;