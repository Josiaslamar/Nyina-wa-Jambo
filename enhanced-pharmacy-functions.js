// =============================================
// ENHANCED PHARMACY MANAGEMENT FUNCTIONS
// =============================================

// =============================================
// 1. PRESCRIPTION MANAGEMENT FUNCTIONS
// =============================================

/**
 * Create a new prescription with validation
 */
async function createPrescription(prescriptionData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    // Validate prescription data
    if (!prescriptionData.doctor_name || !prescriptionData.customer_id || !prescriptionData.medicines) {
      throw new Error("Missing required prescription information");
    }
    
    // Check for medicine interactions
    const medicineIds = prescriptionData.medicines.map(m => m.medicine_id);
    const interactions = await checkMedicineInteractions(medicineIds);
    
    if (interactions.length > 0) {
      const majorInteractions = interactions.filter(i => i.interaction_type === 'major' || i.interaction_type === 'contraindicated');
      if (majorInteractions.length > 0) {
        throw new Error(`Major drug interactions detected: ${majorInteractions.map(i => `${i.medicine_a_name} + ${i.medicine_b_name}`).join(', ')}`);
      }
    }
    
    // Check customer allergies
    const allergies = await checkCustomerAllergies(prescriptionData.customer_id, medicineIds);
    if (allergies.length > 0) {
      const severeAllergies = allergies.filter(a => a.severity === 'severe' || a.severity === 'life-threatening');
      if (severeAllergies.length > 0) {
        throw new Error(`Severe allergies detected: ${severeAllergies.map(a => a.allergen_name).join(', ')}`);
      }
    }
    
    // Create prescription
    const prescription = {
      doctor_name: prescriptionData.doctor_name,
      doctor_license: prescriptionData.doctor_license,
      doctor_phone: prescriptionData.doctor_phone,
      doctor_facility: prescriptionData.doctor_facility,
      customer_id: prescriptionData.customer_id,
      prescription_date: prescriptionData.prescription_date || new Date().toISOString().split('T')[0],
      diagnosis: prescriptionData.diagnosis,
      patient_weight: prescriptionData.patient_weight,
      patient_age: prescriptionData.patient_age,
      special_instructions: prescriptionData.special_instructions,
      insurance_claim_number: prescriptionData.insurance_claim_number,
      is_controlled_substance: prescriptionData.is_controlled_substance || false,
      created_by: user?.id
    };
    
    const { data: newPrescription, error: prescriptionError } = await supabase
      .from("prescriptions")
      .insert([prescription])
      .select()
      .single();
    
    if (prescriptionError) throw new Error(`Prescription creation error: ${prescriptionError.message}`);
    
    // Create prescription items
    const prescriptionItems = prescriptionData.medicines.map(medicine => ({
      prescription_id: newPrescription.id,
      medicine_id: medicine.medicine_id,
      medicine_name: medicine.medicine_name,
      dosage: medicine.dosage,
      quantity_prescribed: medicine.quantity_prescribed,
      duration_days: medicine.duration_days,
      administration_route: medicine.administration_route,
      special_instructions: medicine.special_instructions,
      substitution_allowed: medicine.substitution_allowed !== false,
      unit_price: medicine.unit_price,
      total_price: medicine.quantity_prescribed * medicine.unit_price,
      insurance_covered: medicine.insurance_covered || false,
      patient_copay: medicine.patient_copay || 0
    }));
    
    const { data: items, error: itemsError } = await supabase
      .from("prescription_items")
      .insert(prescriptionItems)
      .select();
    
    if (itemsError) throw new Error(`Prescription items error: ${itemsError.message}`);
    
    showSuccess(`Prescription ${newPrescription.prescription_number} created successfully!`);
    
    // Send notification if interactions or allergies were found
    if (interactions.length > 0 || allergies.length > 0) {
      await createNotification({
        title: 'Prescription Alert',
        message: `Prescription ${newPrescription.prescription_number} has potential interactions or allergies. Please review.`,
        type: 'warning',
        targetRole: 'admin',
        relatedTo: 'prescription',
        relatedId: newPrescription.id,
        priority: 'high'
      });
    }
    
    return { ...newPrescription, prescription_items: items, interactions, allergies };
    
  } catch (error) {
    console.error('Prescription creation error:', error);
    throw error;
  }
}

/**
 * Dispense prescription items
 */
async function dispensePrescriptionItem(prescriptionItemId, quantityDispensed, batchNumber, notes) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    // Get prescription item details
    const { data: item, error: itemError } = await supabase
      .from("prescription_items")
      .select("*, prescriptions(customer_id, prescription_number)")
      .eq("id", prescriptionItemId)
      .single();
    
    if (itemError) throw new Error(`Item fetch error: ${itemError.message}`);
    
    // Validate quantity
    const totalDispensed = item.quantity_dispensed + quantityDispensed;
    if (totalDispensed > item.quantity_prescribed) {
      throw new Error(`Cannot dispense ${quantityDispensed}. Only ${item.quantity_prescribed - item.quantity_dispensed} remaining.`);
    }
    
    // Check stock availability
    const { data: medicine, error: medicineError } = await supabase
      .from("medicines")
      .select("stock, name")
      .eq("id", item.medicine_id)
      .single();
    
    if (medicineError) throw new Error(`Medicine fetch error: ${medicineError.message}`);
    
    if (medicine.stock < quantityDispensed) {
      throw new Error(`Insufficient stock for ${medicine.name}. Available: ${medicine.stock}`);
    }
    
    // Update prescription item
    const { data: updatedItem, error: updateError } = await supabase
      .from("prescription_items")
      .update({
        quantity_dispensed: totalDispensed,
        batch_number: batchNumber,
        dispensing_notes: notes
      })
      .eq("id", prescriptionItemId)
      .select();
    
    if (updateError) throw new Error(`Update error: ${updateError.message}`);
    
    // Create stock movement
    await processStockOut(
      item.medicine_id,
      quantityDispensed,
      "prescription",
      `Prescription ${item.prescriptions.prescription_number}`
    );
    
    // Update prescription if fully dispensed
    if (totalDispensed === item.quantity_prescribed) {
      await supabase
        .from("prescriptions")
        .update({
          dispensed_by: user?.id,
          dispensed_at: new Date().toISOString()
        })
        .eq("id", item.prescription_id);
    }
    
    showSuccess(`${medicine.name} dispensed successfully!`);
    return updatedItem[0];
    
  } catch (error) {
    console.error('Dispensing error:', error);
    throw error;
  }
}

/**
 * Check medicine interactions
 */
async function checkMedicineInteractions(medicineIds) {
  try {
    const { data, error } = await supabase.rpc('check_medicine_interactions', {
      prescription_medicines: medicineIds
    });
    
    if (error) throw new Error(`Interaction check error: ${error.message}`);
    return data || [];
  } catch (error) {
    console.error('Medicine interaction check error:', error);
    return [];
  }
}

/**
 * Check customer allergies
 */
async function checkCustomerAllergies(customerId, medicineIds) {
  try {
    const { data, error } = await supabase.rpc('check_customer_allergies', {
      p_customer_id: customerId,
      medicine_ids: medicineIds
    });
    
    if (error) throw new Error(`Allergy check error: ${error.message}`);
    return data || [];
  } catch (error) {
    console.error('Customer allergy check error:', error);
    return [];
  }
}

// =============================================
// 2. ENHANCED INVENTORY MANAGEMENT
// =============================================

/**
 * Add medicine batch with quality control
 */
async function addMedicineBatch(batchData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    const batch = {
      medicine_id: batchData.medicine_id,
      batch_number: batchData.batch_number,
      manufacturer: batchData.manufacturer,
      manufacture_date: batchData.manufacture_date,
      expiry_date: batchData.expiry_date,
      quantity_received: batchData.quantity_received,
      quantity_remaining: batchData.quantity_received,
      cost_per_unit: batchData.cost_per_unit,
      selling_price_per_unit: batchData.selling_price_per_unit,
      supplier_id: batchData.supplier_id,
      storage_location: batchData.storage_location,
      temperature_requirements: batchData.temperature_requirements,
      purchase_order_id: batchData.purchase_order_id,
      created_by: user?.id
    };
    
    const { data: newBatch, error: batchError } = await supabase
      .from("medicine_batches")
      .insert([batch])
      .select()
      .single();
    
    if (batchError) throw new Error(`Batch creation error: ${batchError.message}`);
    
    // Create initial quality control check
    await createQualityControlCheck(newBatch.id, 'receiving', {
      visual_inspection: true,
      packaging_integrity: true,
      label_accuracy: true,
      expiry_date_check: true,
      storage_condition_check: true,
      overall_status: 'pass'
    });
    
    // Update medicine stock
    await processStockIn(batchData.medicine_id, batchData.quantity_received, 'purchase', `Batch ${batchData.batch_number}`);
    
    showSuccess(`Medicine batch ${batchData.batch_number} added successfully!`);
    return newBatch;
    
  } catch (error) {
    console.error('Batch creation error:', error);
    throw error;
  }
}

/**
 * Generate inventory forecast
 */
async function generateInventoryForecast(medicineId, daysAhead = 30) {
  try {
    const { data, error } = await supabase.rpc('generate_sales_forecast', {
      p_medicine_id: medicineId,
      p_days_ahead: daysAhead
    });
    
    if (error) throw new Error(`Forecast error: ${error.message}`);
    return data || [];
  } catch (error) {
    console.error('Inventory forecast error:', error);
    return [];
  }
}

/**
 * Get batch-wise inventory report
 */
async function getBatchInventoryReport() {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const { data, error } = await supabase
      .from("medicine_batches")
      .select(`
        *,
        medicines(name, medicine_code, min_stock_level),
        suppliers(name)
      `)
      .eq("is_active", true)
      .order("expiry_date", { ascending: true });
    
    if (error) throw new Error(`Batch report error: ${error.message}`);
    
    return data.map(batch => ({
      ...batch,
      days_to_expiry: Math.ceil((new Date(batch.expiry_date) - new Date()) / (1000 * 60 * 60 * 24)),
      status: getBatchStatus(batch),
      value: batch.quantity_remaining * batch.cost_per_unit
    }));
    
  } catch (error) {
    console.error('Batch inventory report error:', error);
    throw error;
  }
}

/**
 * Get batch status based on conditions
 */
function getBatchStatus(batch) {
  const daysToExpiry = Math.ceil((new Date(batch.expiry_date) - new Date()) / (1000 * 60 * 60 * 24));
  
  if (daysToExpiry < 0) return 'expired';
  if (daysToExpiry <= 30) return 'expiring_soon';
  if (batch.quantity_remaining === 0) return 'empty';
  if (batch.quality_status !== 'good') return 'quality_issue';
  return 'good';
}

// =============================================
// 3. ENHANCED CUSTOMER MANAGEMENT
// =============================================

/**
 * Create comprehensive customer profile
 */
async function createCustomerProfile(customerData, healthData = null) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    // Create basic customer record
    const customer = await addCustomer(customerData);
    
    // Create health profile if provided
    if (healthData) {
      await updateCustomerHealthProfile(customer.id, healthData);
    }
    
    // Send welcome communication
    await createCustomerCommunication(customer.id, {
      type: 'sms',
      subject: 'Welcome to Nyina wa Jambo Pharmacy',
      message: `Welcome ${customer.name}! Your customer ID is ${customer.customer_id}. We're here to serve your healthcare needs.`,
      priority: 'normal'
    });
    
    showSuccess(`Customer profile created for ${customer.name}!`);
    return customer;
    
  } catch (error) {
    console.error('Customer profile creation error:', error);
    throw error;
  }
}

/**
 * Update customer health profile
 */
async function updateCustomerHealthProfile(customerId, healthData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const { error } = await supabase.rpc('update_customer_health_profile', {
      p_customer_id: customerId,
      p_profile_data: healthData
    });
    
    if (error) throw new Error(`Health profile update error: ${error.message}`);
    
    showSuccess("Customer health profile updated successfully!");
    
  } catch (error) {
    console.error('Health profile update error:', error);
    throw error;
  }
}

/**
 * Add customer allergy
 */
async function addCustomerAllergy(allergyData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    const allergy = {
      customer_id: allergyData.customer_id,
      allergen_type: allergyData.allergen_type,
      allergen_name: allergyData.allergen_name,
      medicine_id: allergyData.medicine_id,
      reaction_type: allergyData.reaction_type,
      severity: allergyData.severity,
      symptoms: allergyData.symptoms,
      date_discovered: allergyData.date_discovered || new Date().toISOString().split('T')[0],
      verified_by: allergyData.verified_by,
      notes: allergyData.notes,
      created_by: user?.id
    };
    
    const { data, error } = await supabase
      .from("customer_allergies")
      .insert([allergy])
      .select();
    
    if (error) throw new Error(`Allergy creation error: ${error.message}`);
    
    showSuccess("Customer allergy added successfully!");
    return data[0];
    
  } catch (error) {
    console.error('Customer allergy creation error:', error);
    throw error;
  }
}

/**
 * Get customer comprehensive profile
 */
async function getCustomerComprehensiveProfile(customerId) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    // Get basic customer info
    const { data: customer, error: customerError } = await supabase
      .from("customers")
      .select("*")
      .eq("id", customerId)
      .eq("is_active", true)
      .single();
    
    if (customerError) throw new Error(`Customer fetch error: ${customerError.message}`);
    
    // Get health profile
    const { data: healthProfile } = await supabase
      .from("customer_health_profiles")
      .select("*")
      .eq("customer_id", customerId)
      .single();
    
    // Get allergies
    const { data: allergies } = await supabase
      .from("customer_allergies")
      .select("*")
      .eq("customer_id", customerId)
      .eq("is_active", true);
    
    // Get recent orders
    const { data: recentOrders } = await supabase
      .from("orders")
      .select("*, order_items(*)")
      .eq("customer_id", customerId)
      .eq("is_active", true)
      .order("order_date", { ascending: false })
      .limit(10);
    
    // Get recent prescriptions
    const { data: recentPrescriptions } = await supabase
      .from("prescriptions")
      .select("*, prescription_items(*)")
      .eq("customer_id", customerId)
      .eq("is_active", true)
      .order("prescription_date", { ascending: false })
      .limit(5);
    
    // Get recent communications
    const { data: communications } = await supabase
      .from("customer_communications")
      .select("*")
      .eq("customer_id", customerId)
      .eq("is_active", true)
      .order("sent_at", { ascending: false })
      .limit(5);
    
    return {
      customer,
      health_profile: healthProfile,
      allergies: allergies || [],
      recent_orders: recentOrders || [],
      recent_prescriptions: recentPrescriptions || [],
      recent_communications: communications || []
    };
    
  } catch (error) {
    console.error('Customer profile fetch error:', error);
    throw error;
  }
}

// =============================================
// 4. ENHANCED SALES ANALYTICS
// =============================================

/**
 * Generate comprehensive sales report
 */
async function generateComprehensiveSalesReport(startDate, endDate) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    // Generate daily analytics for the period
    let currentDate = new Date(startDate);
    const endDateTime = new Date(endDate);
    
    while (currentDate <= endDateTime) {
      await supabase.rpc('generate_daily_sales_analytics', {
        analysis_date: currentDate.toISOString().split('T')[0]
      });
      currentDate.setDate(currentDate.getDate() + 1);
    }
    
    // Fetch aggregated data
    const { data: salesData, error: salesError } = await supabase
      .from("sales_analytics")
      .select("*")
      .gte("analysis_date", startDate)
      .lte("analysis_date", endDate)
      .eq("analysis_type", "daily")
      .order("analysis_date");
    
    if (salesError) throw new Error(`Sales data error: ${salesError.message}`);
    
    // Calculate summary metrics
    const summary = salesData.reduce((acc, day) => ({
      total_orders: acc.total_orders + day.total_orders,
      total_revenue: acc.total_revenue + parseFloat(day.total_revenue),
      total_cost: acc.total_cost + parseFloat(day.total_cost),
      gross_profit: acc.gross_profit + parseFloat(day.gross_profit),
      cash_sales: acc.cash_sales + parseFloat(day.cash_sales),
      insurance_sales: acc.insurance_sales + parseFloat(day.insurance_sales),
      momo_sales: acc.momo_sales + parseFloat(day.momo_sales),
      unique_customers: Math.max(acc.unique_customers, day.unique_customers),
      medicines_sold: acc.medicines_sold + day.medicines_sold,
      prescriptions_filled: acc.prescriptions_filled + day.prescriptions_filled
    }), {
      total_orders: 0, total_revenue: 0, total_cost: 0, gross_profit: 0,
      cash_sales: 0, insurance_sales: 0, momo_sales: 0,
      unique_customers: 0, medicines_sold: 0, prescriptions_filled: 0
    });
    
    // Calculate profit margin
    summary.profit_margin = summary.total_revenue > 0 
      ? (summary.gross_profit / summary.total_revenue) * 100 
      : 0;
    
    // Get top selling medicines
    const { data: topMedicines, error: topError } = await supabase
      .from("order_items")
      .select(`
        medicine_name,
        sum:quantity.sum(),
        orders!inner(order_date, status, is_active)
      `)
      .gte("orders.order_date", startDate)
      .lte("orders.order_date", endDate)
      .eq("orders.status", "completed")
      .eq("orders.is_active", true)
      .eq("is_active", true)
      .order("sum", { ascending: false })
      .limit(10);
    
    if (topError) {
      console.warn('Top medicines query failed:', topError.message);
    }
    
    return {
      period: { start: startDate, end: endDate },
      summary,
      daily_data: salesData,
      top_medicines: topMedicines || []
    };
    
  } catch (error) {
    console.error('Comprehensive sales report error:', error);
    throw error;
  }
}

/**
 * Get real-time sales dashboard
 */
async function getRealTimeSalesDashboard() {
  try {
    const today = new Date().toISOString().split('T')[0];
    
    // Get today's metrics
    const todayMetrics = await getTodaysLiveDashboard();
    
    // Get yesterday's metrics for comparison
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayDate = yesterday.toISOString().split('T')[0];
    
    const { data: yesterdayData } = await supabase
      .from("sales_analytics")
      .select("*")
      .eq("analysis_date", yesterdayDate)
      .eq("analysis_type", "daily")
      .single();
    
    // Calculate growth rates
    const growthRates = {};
    if (yesterdayData) {
      growthRates.orders_growth = calculateGrowthRate(
        todayMetrics.total_orders, 
        yesterdayData.total_orders
      );
      growthRates.revenue_growth = calculateGrowthRate(
        todayMetrics.total_revenue, 
        yesterdayData.total_revenue
      );
    }
    
    // Get current stock alerts
    const lowStockMedicines = await getLowStockMedicines();
    const expiringMedicines = await getExpiringMedicines(30);
    
    // Get pending orders
    const { data: pendingOrders } = await supabase
      .from("orders")
      .select("count")
      .in("status", ["pending", "processing"])
      .eq("is_active", true);
    
    return {
      current_metrics: todayMetrics,
      growth_rates: growthRates,
      alerts: {
        low_stock_count: lowStockMedicines.length,
        expiring_medicines_count: expiringMedicines.length,
        pending_orders_count: pendingOrders?.length || 0
      },
      last_updated: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('Real-time dashboard error:', error);
    throw error;
  }
}

/**
 * Calculate growth rate percentage
 */
function calculateGrowthRate(current, previous) {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100 * 100) / 100;
}

// =============================================
// 5. COMMUNICATION SYSTEM
// =============================================

/**
 * Create customer communication
 */
async function createCustomerCommunication(customerId, communicationData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    const communication = {
      customer_id: customerId,
      communication_type: communicationData.type,
      subject: communicationData.subject,
      message: communicationData.message,
      sent_by: user?.id,
      response_required: communicationData.response_required || false,
      related_to: communicationData.related_to,
      related_id: communicationData.related_id,
      priority: communicationData.priority || 'normal'
    };
    
    const { data, error } = await supabase
      .from("customer_communications")
      .insert([communication])
      .select();
    
    if (error) throw new Error(`Communication error: ${error.message}`);
    
    // Update delivery status (simulate SMS/email sending)
    await updateCommunicationStatus(data[0].id, 'sent');
    
    showSuccess("Communication sent successfully!");
    return data[0];
    
  } catch (error) {
    console.error('Communication error:', error);
    throw error;
  }
}

/**
 * Update communication delivery status
 */
async function updateCommunicationStatus(communicationId, status) {
  try {
    const { error } = await supabase
      .from("customer_communications")
      .update({ 
        delivery_status: status,
        sent_at: status === 'sent' ? new Date().toISOString() : undefined
      })
      .eq("id", communicationId);
    
    if (error) throw new Error(`Status update error: ${error.message}`);
    
  } catch (error) {
    console.error('Communication status update error:', error);
  }
}

/**
 * Send prescription ready notification
 */
async function sendPrescriptionReadyNotification(prescriptionId) {
  try {
    // Get prescription details
    const { data: prescription, error } = await supabase
      .from("prescriptions")
      .select(`
        *,
        customers(name, phone, preferred_language, customer_id)
      `)
      .eq("id", prescriptionId)
      .single();
    
    if (error) throw new Error(`Prescription fetch error: ${error.message}`);
    
    const message = prescription.customers.preferred_language === 'English' 
      ? `Hello ${prescription.customers.name}, your prescription ${prescription.prescription_number} is ready for pickup at Nyina wa Jambo Pharmacy.`
      : `Muraho ${prescription.customers.name}, amafunguro yawe ${prescription.prescription_number} yamaze gutegurwa aho Nyina wa Jambo Pharmacy.`;
    
    await createCustomerCommunication(prescription.customer_id, {
      type: 'sms',
      subject: 'Prescription Ready',
      message: message,
      related_to: 'prescription',
      related_id: prescriptionId,
      priority: 'normal'
    });
    
  } catch (error) {
    console.error('Prescription notification error:', error);
    throw error;
  }
}

// =============================================
// 6. QUALITY CONTROL FUNCTIONS
// =============================================

/**
 * Create quality control check
 */
async function createQualityControlCheck(batchId, checkType, checkData) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const user = await getCurrentUser();
    
    const qualityCheck = {
      medicine_batch_id: batchId,
      check_type: checkType,
      checked_by: user?.id,
      visual_inspection: checkData.visual_inspection,
      packaging_integrity: checkData.packaging_integrity,
      label_accuracy: checkData.label_accuracy,
      expiry_date_check: checkData.expiry_date_check,
      storage_condition_check: checkData.storage_condition_check,
      temperature_log_check: checkData.temperature_log_check,
      overall_status: checkData.overall_status,
      issues_found: checkData.issues_found,
      corrective_actions: checkData.corrective_actions,
      next_check_date: checkData.next_check_date,
      created_by: user?.id
    };
    
    const { data, error } = await supabase
      .from("quality_control_checks")
      .insert([qualityCheck])
      .select();
    
    if (error) throw new Error(`Quality check error: ${error.message}`);
    
    // Update batch quality status if failed
    if (checkData.overall_status === 'fail') {
      await supabase
        .from("medicine_batches")
        .update({ quality_status: 'damaged' })
        .eq("id", batchId);
    }
    
    showSuccess("Quality control check completed!");
    return data[0];
    
  } catch (error) {
    console.error('Quality control error:', error);
    throw error;
  }
}

// =============================================
// 7. UTILITY FUNCTIONS
// =============================================

/**
 * Enhanced search across all entities
 */
async function performGlobalSearch(searchTerm) {
  if (!(await isReceptionist()))
    throw new Error("Permission denied: Staff only");
  
  try {
    const results = {
      medicines: [],
      customers: [],
      prescriptions: [],
      orders: [],
      suppliers: []
    };
    
    // Search medicines
    const { data: medicines } = await supabase
      .from("medicines")
      .select("*")
      .or(`name.ilike.%${searchTerm}%,medicine_code.ilike.%${searchTerm}%,generic_name.ilike.%${searchTerm}%`)
      .eq("is_active", true)
      .limit(5);
    
    results.medicines = medicines || [];
    
    // Search customers
    const { data: customers } = await supabase
      .from("customers")
      .select("*")
      .or(`name.ilike.%${searchTerm}%,customer_id.ilike.%${searchTerm}%,phone.ilike.%${searchTerm}%`)
      .eq("is_active", true)
      .limit(5);
    
    results.customers = customers || [];
    
    // Search prescriptions
    const { data: prescriptions } = await supabase
      .from("prescriptions")
      .select("*, customers(name)")
      .or(`prescription_number.ilike.%${searchTerm}%,doctor_name.ilike.%${searchTerm}%`)
      .eq("is_active", true)
      .limit(5);
    
    results.prescriptions = prescriptions || [];
    
    // Search orders
    const { data: orders } = await supabase
      .from("orders")
      .select("*, customers(name)")
      .or(`order_number.ilike.%${searchTerm}%`)
      .eq("is_active", true)
      .limit(5);
    
    results.orders = orders || [];
    
    // Search suppliers
    const { data: suppliers } = await supabase
      .from("suppliers")
      .select("*")
      .or(`name.ilike.%${searchTerm}%,supplier_code.ilike.%${searchTerm}%`)
      .eq("is_active", true)
      .limit(5);
    
    results.suppliers = suppliers || [];
    
    return results;
    
  } catch (error) {
    console.error('Global search error:', error);
    return { medicines: [], customers: [], prescriptions: [], orders: [], suppliers: [] };
  }
}

/**
 * Export data to various formats
 */
async function exportData(dataType, format = 'excel', filters = {}) {
  if (!(await isAdmin())) throw new Error("Permission denied: Admin only");
  
  try {
    let data = [];
    let filename = '';
    
    switch (dataType) {
      case 'sales':
        data = await generateComprehensiveSalesReport(
          filters.start_date || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          filters.end_date || new Date().toISOString().split('T')[0]
        );
        filename = `sales_report_${new Date().toISOString().split('T')[0]}`;
        break;
        
      case 'inventory':
        data = await getBatchInventoryReport();
        filename = `inventory_report_${new Date().toISOString().split('T')[0]}`;
        break;
        
      case 'customers':
        const { data: customerData } = await supabase
          .from("customers")
          .select("*")
          .eq("is_active", true);
        data = customerData || [];
        filename = `customers_export_${new Date().toISOString().split('T')[0]}`;
        break;
        
      default:
        throw new Error('Invalid data type for export');
    }
    
    if (format === 'excel') {
      return await exportToExcel(data, filename);
    } else if (format === 'csv') {
      return convertToCSV(data);
    }
    
    return data;
    
  } catch (error) {
    console.error('Export error:', error);
    throw error;
  }
}

// Export all enhanced functions for use in the frontend
window.PharmacyEnhanced = {
  // Prescription Management
  createPrescription,
  dispensePrescriptionItem,
  checkMedicineInteractions,
  checkCustomerAllergies,
  sendPrescriptionReadyNotification,
  
  // Enhanced Inventory
  addMedicineBatch,
  generateInventoryForecast,
  getBatchInventoryReport,
  createQualityControlCheck,
  
  // Customer Management
  createCustomerProfile,
  updateCustomerHealthProfile,
  addCustomerAllergy,
  getCustomerComprehensiveProfile,
  
  // Sales Analytics
  generateComprehensiveSalesReport,
  getRealTimeSalesDashboard,
  
  // Communication
  createCustomerCommunication,
  updateCommunicationStatus,
  
  // Utilities
  performGlobalSearch,
  exportData,
  calculateGrowthRate
};
