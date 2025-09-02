const SUPABASE_URL = "https://jcmscgxrxicwowsezbui.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpjbXNjZ3hyeGljd293c2V6YnVpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NjExNzcsImV4cCI6MjA3MjMzNzE3N30.QqfFKCqV4oIsuNw5TAJoCbE7tVu7m8s8g8M6YzwcU68";

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function getCurrentUser() {
  const { data: { user }, error } = await supabase.auth.getUser();
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

async function updateUserRole(userId, newRole) {
  if (!await isAdmin()) throw new Error("Permission denied: Admin only");
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

async function signIn(email, password, rememberMe = false) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw new Error(`Sign in error: ${error.message}`);
  if (rememberMe) {
    localStorage.setItem("rememberUser", email);
  }
  return data.user;
}

async function signUp(email, password, fullName, role = "customer", additionalData = {}) {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: { data: { full_name: fullName, role, ...additionalData } },
  });
  if (error) throw new Error(`Sign up error: ${error.message}`);
  if (data.user) await createUserProfile(data.user, fullName, role, additionalData);
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
  const { data, error } = await supabase.from("user_profiles").insert([profileData]);
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
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
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
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
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
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
  const { data, error } = await supabase.rpc("deactivate_record", { p_table_name: "medicines", p_record_id: id });
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
  if (!await isAdmin()) throw new Error("Permission denied: Admin only");
  const user = await getCurrentUser();
  const medicinesWithMeta = medicines.map(m => ({ ...m, created_by: user?.id }));
  const { data, error } = await supabase.from("medicines").insert(medicinesWithMeta).select();
  if (error) throw new Error(`Bulk insert error: ${error.message}`);
  showSuccess(`${medicines.length} medicines added!`);
  return data;
}

async function fetchOrders() {
  const { data, error } = await supabase
    .from("orders")
    .select(`
      *, 
      order_items(id, medicine_id, medicine_name, quantity, unit_price, total_price, batch_number, expiry_date),
      customers(name, customer_id),
      user_profiles!orders_created_by_fkey(full_name)
    `)
    .eq("is_active", true)
    .order("order_date", { ascending: false });
  if (error) throw new Error(`Orders fetch error: ${error.message}`);
  return data || [];
}

async function getCustomerOrderHistory(customerId) {
  if (!(await isCustomer() || await isReceptionist())) throw new Error("Permission denied");
  const { data, error } = await supabase
    .from("orders")
    .select(`
      *, 
      order_items(id, medicine_id, medicine_name, quantity, unit_price, total_price, batch_number, expiry_date)
    `)
    .eq("customer_id", customerId)
    .eq("is_active", true)
    .order("order_date", { ascending: false });
  if (error) throw new Error(`Order history fetch error: ${error.message}`);
  return data || [];
}

async function createOrder(orderData, orderItems) {
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data: order, error: orderError } = await supabase
    .from("orders")
    .insert([{ ...orderData, created_by: user?.id, served_by: user?.id }])
    .select()
    .single();
  if (orderError) throw new Error(`Order creation error: ${orderError.message}`);

  const itemsWithOrderId = orderItems.map(item => ({
    ...item,
    order_id: order.id,
    total_price: item.quantity * item.unit_price,
  }));
  const { data: items, error: itemsError } = await supabase
    .from("order_items")
    .insert(itemsWithOrderId)
    .select();
  if (itemsError) throw new Error(`Order items creation error: ${itemsError.message}`);

  for (const item of orderItems) {
    await processStockOut(item.medicine_id, item.quantity, "sale", `Order ${order.order_number}`);
  }
  showSuccess(`Order ${order.order_number} created!`);
  return { ...order, order_items: items };
}

async function updateMedicineStock(medicineId, newStock, movementType, quantity, reason, notes = null) {
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
  const { data: medicine, error: fetchError } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (fetchError) throw new Error(`Medicine fetch error: ${fetchError.message}`);

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
  const { error: movementError } = await supabase.from("stock_movements").insert([movement]);
  if (movementError) throw new Error(`Stock movement error: ${movementError.message}`);

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

async function processStockIn(medicineId, quantity, reason = "purchase", notes = null) {
  const { data: medicine, error } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (error) throw new Error(`Medicine fetch error: ${error.message}`);
  return await updateMedicineStock(medicineId, medicine.stock + quantity, "in", quantity, reason, notes);
}

async function processStockOut(medicineId, quantity, reason = "sale", notes = null) {
  const { data: medicine, error } = await supabase
    .from("medicines")
    .select("stock, name")
    .eq("id", medicineId)
    .eq("is_active", true)
    .single();
  if (error) throw new Error(`Medicine fetch error: ${error.message}`);
  if (medicine.stock < quantity) throw new Error(`Insufficient stock: ${medicine.name} has ${medicine.stock} units`);
  return await updateMedicineStock(medicineId, medicine.stock - quantity, "out", quantity, reason, notes);
}

async function fetchStockMovements() {
  const { data, error } = await supabase
    .from("stock_movements")
    .select("*, medicines(name), suppliers(name)")
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
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
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
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
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

async function archiveSupplier(id) {
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
  const { data, error } = await supabase.rpc("deactivate_record", { p_table_name: "suppliers", p_record_id: id });
  if (error) throw new Error(`Supplier archive error: ${error.message}`);
  showSuccess("Supplier archived!");
  return data;
}

async function fetchPurchaseOrders() {
  const { data, error } = await supabase
    .from("purchase_orders")
    .select(`
      *, 
      purchase_order_items(id, medicine_id, medicine_name, quantity_ordered, quantity_received, unit_cost, total_cost),
      suppliers(name)
    `)
    .eq("is_active", true)
    .order("order_date", { ascending: false });
  if (error) throw new Error(`Purchase orders fetch error: ${error.message}`);
  return data || [];
}

async function createPurchaseOrder(poData, poItems) {
  if (!await isReceptionist()) throw new Error("Permission denied: Staff only");
  const user = await getCurrentUser();
  const { data: po, error: poError } = await supabase
    .from("purchase_orders")
    .insert([{ ...poData, created_by: user?.id }])
    .select()
    .single();
  if (poError) throw new Error(`Purchase order creation error: ${poError.message}`);

  const itemsWithPoId = poItems.map(item => ({
    ...item,
    po_id: po.id,
    total_cost: item.quantity_ordered * item.unit_cost,
  }));
  const { data: items, error: itemsError } = await supabase
    .from("purchase_order_items")
    .insert(itemsWithPoId)
    .select();
  if (itemsError) throw new Error(`Purchase order items creation error: ${itemsError.message}`);
  showSuccess(`Purchase order ${po.po_number} created!`);
  return { ...po, purchase_order_items: items };
}

async function fetchAuditLogs(limit = 100) {
  if (!await isAdmin()) throw new Error("Permission denied: Admin only");
  const { data, error } = await supabase
    .from("vw_audit_log_report")
    .select("*")
    .limit(limit)
    .order("created_at", { ascending: false });
  if (error) throw new Error(`Audit logs fetch error: ${error.message}`);
  return data.map(log => ({
    ...log,
    record_id: String(log.record_id)
  })) || [];
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
  const { data, error } = await supabase.rpc("get_expiring_medicines", { days_ahead: daysAhead });
  if (error) throw new Error(`Expiring medicines fetch error: ${error.message}`);
  return data || [];
}

async function fetchNotifications() {
  const user = await getCurrentUser();
  const profile = await getUserProfile();
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("is_active", true)
    .or(`user_id.eq.${user?.id},target_role.eq.${profile?.role},target_role.eq.all`)
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
  return (roleHierarchy[profile.role] || 0) >= (roleHierarchy[requiredRole] || 0);
}

function formatCurrency(amount) {
  return new Intl.NumberFormat("rw-RW", { style: "currency", currency: "RWF", minimumFractionDigits: 0 }).format(amount);
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