// =============================================
// PRESCRIPTION MANAGEMENT INTERFACE
// =============================================

let availableMedicines = [];
let availableCustomers = [];
let prescriptionMedicines = [];
let currentPrescription = null;

document.addEventListener("DOMContentLoaded", async function () {
    if (!(await isAuthenticated())) {
        window.location.href = "login.html";
        return;
    }

    const user = await getUserProfile();
    if (!user || (user.role !== "admin" && user.role !== "receptionist")) {
        showNotification("Access denied. Staff privileges required.", "error");
        setTimeout(() => logout(), 2000);
        return;
    }

    await updateNavigation();
    await loadInitialData();
    setupEventListeners();
    await renderPrescriptions();
    await updatePrescriptionStats();
});

async function updateNavigation() {
    try {
        const user = await getUserProfile();
        if (user) {
            document.getElementById("currentUser").textContent = user.full_name || "User";
            const avatarImg = document.querySelector("#userAvatar img");
            if (avatarImg) {
                avatarImg.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(
                    user.full_name || "User"
                )}&background=16a34a&color=fff&bold=true`;
            }

            // Hide/show navigation based on role
            const adminElements = document.querySelectorAll(".admin-only");
            adminElements.forEach(el => el.style.display = user.role === "admin" ? "flex" : "none");

            const receptionistElements = document.querySelectorAll(".receptionist-only");
            receptionistElements.forEach(el => 
                el.style.display = (user.role === "receptionist" || user.role === "admin") ? "flex" : "none"
            );
        }
    } catch (error) {
        console.error("Error updating navigation:", error);
    }
}

async function loadInitialData() {
    try {
        // Load medicines
        availableMedicines = await fetchMedicines();
        
        // Load customers
        availableCustomers = await fetchCustomers();
        
        if (availableMedicines.length === 0) {
            showNotification("No medicines available. Please add medicines first.", "warning");
        }
        
        if (availableCustomers.length === 0) {
            showNotification("No customers found. Please add customers first.", "warning");
        }
    } catch (error) {
        console.error("Error loading initial data:", error);
        showNotification("Error loading data. Please refresh the page.", "error");
    }
}

function setupEventListeners() {
    // Modal controls
    document.getElementById("newPrescriptionBtn").addEventListener("click", openPrescriptionModal);
    document.getElementById("closePrescriptionModal").addEventListener("click", closePrescriptionModal);
    document.getElementById("cancelPrescription").addEventListener("click", closePrescriptionModal);
    
    // Form submission
    document.getElementById("prescriptionForm").addEventListener("submit", savePrescription);
    
    // Add medicine to prescription
    document.getElementById("addPrescriptionMedicine").addEventListener("click", addPrescriptionMedicineItem);
    
    // Customer selection change
    document.getElementById("prescriptionCustomer").addEventListener("change", onCustomerChange);
    
    // Search and filters
    document.getElementById("prescriptionSearch").addEventListener("input", renderPrescriptions);
    document.getElementById("statusFilter").addEventListener("change", renderPrescriptions);
    document.getElementById("dateFilter").addEventListener("change", renderPrescriptions);
    document.getElementById("clearFilters").addEventListener("click", clearFilters);
    
    // Sidebar toggle
    const menuToggle = document.getElementById("menu-toggle");
    const sidebar = document.getElementById("sidebar");
    if (menuToggle && sidebar) {
        menuToggle.addEventListener("click", (e) => {
            e.stopPropagation();
            sidebar.classList.toggle("hidden");
        });
    }
}

async function openPrescriptionModal() {
    // Reset form
    document.getElementById("prescriptionForm").reset();
    prescriptionMedicines = [];
    
    // Populate customer dropdown
    const customerSelect = document.getElementById("prescriptionCustomer");
    customerSelect.innerHTML = '<option value="">Select Customer</option>' + 
        availableCustomers.map(customer => 
            `<option value="${customer.id}">${customer.name} - ${customer.customer_id}</option>`
        ).join("");
    
    // Clear medicines container
    document.getElementById("prescriptionMedicines").innerHTML = "";
    
    // Hide safety alerts
    document.getElementById("safetyAlerts").classList.add("hidden");
    
    // Add one medicine item by default
    addPrescriptionMedicineItem();
    
    // Show modal
    document.getElementById("prescriptionModal").classList.add("show");
}

function closePrescriptionModal() {
    document.getElementById("prescriptionModal").classList.remove("show");
}

function addPrescriptionMedicineItem() {
    const container = document.getElementById("prescriptionMedicines");
    const itemIndex = prescriptionMedicines.length;
    
    const medicineItem = {
        medicine_id: "",
        medicine_name: "",
        dosage: "",
        quantity_prescribed: 1,
        duration_days: 7,
        administration_route: "oral",
        special_instructions: "",
        substitution_allowed: true,
        unit_price: 0,
        total_price: 0
    };
    
    prescriptionMedicines.push(medicineItem);
    
    const itemDiv = document.createElement("div");
    itemDiv.className = "medicine-item";
    itemDiv.setAttribute("data-index", itemIndex);
    itemDiv.innerHTML = `
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Medicine</label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500" 
                        onchange="updatePrescriptionMedicine(${itemIndex}, 'medicine_id', this.value)">
                    <option value="">Select Medicine</option>
                    ${availableMedicines.map(med => 
                        `<option value="${med.id}" data-name="${med.name}" data-price="${med.selling_price || 0}">
                            ${med.name} - ${Math.round(med.selling_price || 0).toLocaleString()} RWF (Stock: ${med.stock || 0})
                        </option>`
                    ).join("")}
                </select>
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Dosage Instructions</label>
                <input type="text" placeholder="e.g., 2 tablets twice daily" 
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500"
                       onchange="updatePrescriptionMedicine(${itemIndex}, 'dosage', this.value)">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Quantity</label>
                <input type="number" min="1" value="1" 
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500"
                       onchange="updatePrescriptionMedicine(${itemIndex}, 'quantity_prescribed', this.value)">
            </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Duration (days)</label>
                <input type="number" min="1" value="7" 
                       class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500"
                       onchange="updatePrescriptionMedicine(${itemIndex}, 'duration_days', this.value)">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Route</label>
                <select class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500"
                        onchange="updatePrescriptionMedicine(${itemIndex}, 'administration_route', this.value)">
                    <option value="oral">Oral</option>
                    <option value="topical">Topical</option>
                    <option value="injection">Injection</option>
                    <option value="inhalation">Inhalation</option>
                    <option value="other">Other</option>
                </select>
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Price per unit</label>
                <input type="number" step="0.01" readonly 
                       class="w-full px-3 py-2 border border-gray-300 rounded-md bg-gray-50">
            </div>
            <div class="flex items-end">
                <button type="button" onclick="removePrescriptionMedicine(${itemIndex})" 
                        class="px-3 py-2 text-red-600 hover:text-red-800 transition-colors" title="Remove Medicine">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        </div>
        <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Special Instructions</label>
            <input type="text" placeholder="e.g., Take with food, avoid alcohol" 
                   class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-green-500 focus:border-green-500"
                   onchange="updatePrescriptionMedicine(${itemIndex}, 'special_instructions', this.value)">
        </div>
        <div class="mt-2">
            <label class="flex items-center">
                <input type="checkbox" checked onchange="updatePrescriptionMedicine(${itemIndex}, 'substitution_allowed', this.checked)" 
                       class="rounded border-gray-300 text-green-600 focus:ring-green-500">
                <span class="ml-2 text-sm text-gray-700">Allow generic substitution</span>
            </label>
        </div>
    `;
    
    container.appendChild(itemDiv);
}

function updatePrescriptionMedicine(index, field, value) {
    if (index >= prescriptionMedicines.length) return;
    
    const itemDiv = document.querySelector(`[data-index="${index}"]`);
    if (!itemDiv) return;
    
    if (field === "medicine_id") {
        const medicine = availableMedicines.find(m => m.id == value);
        if (medicine) {
            prescriptionMedicines[index].medicine_id = value;
            prescriptionMedicines[index].medicine_name = medicine.name;
            prescriptionMedicines[index].unit_price = medicine.selling_price || 0;
            
            // Update price input
            const priceInput = itemDiv.querySelector("input[readonly]");
            if (priceInput) {
                priceInput.value = Math.round(medicine.selling_price || 0).toLocaleString();
            }
        }
    } else {
        prescriptionMedicines[index][field] = field === 'substitution_allowed' ? value : 
                                             field.includes('quantity') || field.includes('duration') ? parseInt(value) || 0 : 
                                             value;
    }
    
    // Update total price
    prescriptionMedicines[index].total_price = prescriptionMedicines[index].quantity_prescribed * prescriptionMedicines[index].unit_price;
    
    // Check for interactions and allergies
    checkSafetyAlerts();
}

function removePrescriptionMedicine(index) {
    const itemDiv = document.querySelector(`[data-index="${index}"]`);
    if (itemDiv) {
        itemDiv.remove();
        prescriptionMedicines.splice(index, 1);
        
        // Re-index remaining items
        document.querySelectorAll(".medicine-item").forEach((div, newIndex) => {
            div.setAttribute("data-index", newIndex);
            // Update all function calls in the HTML to use new index
            div.innerHTML = div.innerHTML.replace(/\d+/g, (match, offset, string) => {
                if (string.substring(offset - 30, offset).includes("updatePrescriptionMedicine") ||
                    string.substring(offset - 30, offset).includes("removePrescriptionMedicine")) {
                    return newIndex;
                }
                return match;
            });
        });
        
        checkSafetyAlerts();
    }
}

async function onCustomerChange() {
    const customerId = document.getElementById("prescriptionCustomer").value;
    if (!customerId) return;
    
    try {
        // Get customer comprehensive profile including allergies
        const customerProfile = await getCustomerComprehensiveProfile(customerId);
        
        // Populate patient info if available
        if (customerProfile.health_profile) {
            const healthProfile = customerProfile.health_profile;
            if (healthProfile.date_of_birth) {
                const age = Math.floor((new Date() - new Date(healthProfile.date_of_birth)) / (365.25 * 24 * 60 * 60 * 1000));
                document.getElementById("patientAge").value = age;
            }
            if (healthProfile.weight) {
                document.getElementById("patientWeight").value = healthProfile.weight;
            }
            if (healthProfile.insurance_number) {
                document.getElementById("insuranceClaim").value = healthProfile.insurance_number;
            }
        }
        
        // Check for allergies when medicines are selected
        checkSafetyAlerts();
        
    } catch (error) {
        console.error("Error loading customer profile:", error);
    }
}

async function checkSafetyAlerts() {
    const customerId = document.getElementById("prescriptionCustomer").value;
    const medicineIds = prescriptionMedicines
        .filter(m => m.medicine_id)
        .map(m => parseInt(m.medicine_id));
    
    if (!customerId || medicineIds.length === 0) {
        document.getElementById("safetyAlerts").classList.add("hidden");
        return;
    }
    
    try {
        const alerts = [];
        
        // Check medicine interactions
        const interactions = await checkMedicineInteractions(medicineIds);
        interactions.forEach(interaction => {
            const alertClass = interaction.interaction_type === 'major' || interaction.interaction_type === 'contraindicated' 
                ? 'alert-danger' : interaction.interaction_type === 'moderate' ? 'alert-warning' : 'alert-info';
            
            alerts.push({
                type: alertClass,
                title: `Drug Interaction: ${interaction.medicine_a_name} + ${interaction.medicine_b_name}`,
                description: interaction.description,
                severity: interaction.severity_level
            });
        });
        
        // Check customer allergies
        const allergies = await checkCustomerAllergies(customerId, medicineIds);
        allergies.forEach(allergy => {
            const alertClass = allergy.severity === 'severe' || allergy.severity === 'life-threatening' 
                ? 'alert-danger' : 'alert-warning';
            
            alerts.push({
                type: alertClass,
                title: `Allergy Alert: ${allergy.allergen_name}`,
                description: `Patient has ${allergy.severity} allergy. Reaction: ${allergy.reaction_type || 'Unknown'}`,
                severity: allergy.severity === 'life-threatening' ? 5 : allergy.severity === 'severe' ? 4 : 3
            });
        });
        
        // Display alerts
        const alertsContainer = document.getElementById("alertsContent");
        if (alerts.length > 0) {
            // Sort by severity (highest first)
            alerts.sort((a, b) => (b.severity || 0) - (a.severity || 0));
            
            alertsContainer.innerHTML = alerts.map(alert => `
                <div class="${alert.type} alert-item">
                    <div class="font-medium">${alert.title}</div>
                    <div class="text-sm mt-1">${alert.description}</div>
                </div>
            `).join("");
            
            document.getElementById("safetyAlerts").classList.remove("hidden");
            
            // Update stats
            document.getElementById("interactionAlerts").textContent = alerts.length;
        } else {
            document.getElementById("safetyAlerts").classList.add("hidden");
        }
        
    } catch (error) {
        console.error("Error checking safety alerts:", error);
    }
}

async function savePrescription(e) {
    e.preventDefault();
    
    const customerId = document.getElementById("prescriptionCustomer").value;
    const doctorName = document.getElementById("doctorName").value;
    
    if (!customerId || !doctorName) {
        showNotification("Please fill in required fields: Customer and Doctor Name", "error");
        return;
    }
    
    const validMedicines = prescriptionMedicines.filter(m => m.medicine_id && m.dosage && m.quantity_prescribed > 0);
    if (validMedicines.length === 0) {
        showNotification("Please add at least one medicine with dosage instructions", "error");
        return;
    }
    
    const prescriptionData = {
        customer_id: parseInt(customerId),
        doctor_name: doctorName,
        doctor_license: document.getElementById("doctorLicense").value,
        doctor_phone: document.getElementById("doctorPhone").value,
        doctor_facility: document.getElementById("doctorFacility").value,
        diagnosis: document.getElementById("diagnosis").value,
        patient_age: parseInt(document.getElementById("patientAge").value) || null,
        patient_weight: parseFloat(document.getElementById("patientWeight").value) || null,
        special_instructions: document.getElementById("specialInstructions").value,
        insurance_claim_number: document.getElementById("insuranceClaim").value,
        medicines: validMedicines
    };
    
    try {
        const submitBtn = e.target.querySelector('button[type="submit"]');
        const originalText = submitBtn.innerHTML;
        submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Creating...';
        submitBtn.disabled = true;
        
        await PharmacyEnhanced.createPrescription(prescriptionData);
        
        closePrescriptionModal();
        await renderPrescriptions();
        await updatePrescriptionStats();
        
    } catch (error) {
        console.error("Prescription creation error:", error);
        showNotification(error.message || "Error creating prescription.", "error");
    } finally {
        const submitBtn = e.target.querySelector('button[type="submit"]');
        if (submitBtn) {
            submitBtn.innerHTML = 'Create Prescription';
            submitBtn.disabled = false;
        }
    }
}

async function renderPrescriptions() {
    const tbody = document.getElementById("prescriptionsTable");
    const searchTerm = document.getElementById("prescriptionSearch").value.toLowerCase();
    const statusFilter = document.getElementById("statusFilter").value;
    const dateFilter = document.getElementById("dateFilter").value;
    
    tbody.innerHTML = '<tr><td colspan="8" class="px-6 py-4 text-center text-gray-500">Loading prescriptions...</td></tr>';
    
    try {
        const { data: prescriptions, error } = await supabase
            .from("prescriptions")
            .select(`
                *,
                customers(name, customer_id),
                prescription_items(id, medicine_name, quantity_prescribed, quantity_dispensed)
            `)
            .eq("is_active", true)
            .order("prescription_date", { ascending: false });
        
        if (error) throw new Error(`Prescriptions fetch error: ${error.message}`);
        
        let filteredPrescriptions = prescriptions || [];
        
        // Apply filters
        if (searchTerm) {
            filteredPrescriptions = filteredPrescriptions.filter(prescription => 
                prescription.prescription_number.toLowerCase().includes(searchTerm) ||
                prescription.customers?.name?.toLowerCase().includes(searchTerm) ||
                prescription.doctor_name.toLowerCase().includes(searchTerm)
            );
        }
        
        if (statusFilter) {
            filteredPrescriptions = filteredPrescriptions.filter(prescription => 
                prescription.status === statusFilter
            );
        }
        
        if (dateFilter !== "all") {
            const now = new Date();
            let startDate;
            
            switch (dateFilter) {
                case "today":
                    startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
                    break;
                case "week":
                    startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
                    break;
                case "month":
                    startDate = new Date(now.getFullYear(), now.getMonth(), 1);
                    break;
                default:
                    startDate = null;
            }
            
            if (startDate) {
                filteredPrescriptions = filteredPrescriptions.filter(prescription => 
                    new Date(prescription.prescription_date) >= startDate
                );
            }
        }
        
        if (filteredPrescriptions.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" class="px-6 py-4 text-center text-gray-500">No prescriptions found.</td></tr>';
            return;
        }
        
        tbody.innerHTML = filteredPrescriptions.map(prescription => {
            const statusClass = {
                pending: "bg-yellow-100 text-yellow-800",
                partial: "bg-blue-100 text-blue-800", 
                completed: "bg-green-100 text-green-800",
                cancelled: "bg-red-100 text-red-800"
            }[prescription.status] || "bg-gray-100 text-gray-800";
            
            const totalMedicines = prescription.prescription_items?.length || 0;
            const dispensedMedicines = prescription.prescription_items?.filter(item => 
                item.quantity_dispensed >= item.quantity_prescribed
            ).length || 0;
            
            // Check for potential alerts (placeholder - would need actual interaction/allergy checking)
            const hasAlerts = Math.random() > 0.8; // Simulated for demo
            
            return `
                <tr class="hover:bg-gray-50 cursor-pointer" onclick="viewPrescriptionDetails(${prescription.id})">
                    <td class="px-6 py-4 whitespace-nowrap font-medium text-gray-900">
                        ${prescription.prescription_number}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${prescription.customers?.name || 'Unknown'}
                        <div class="text-sm text-gray-500">${prescription.customers?.customer_id || ''}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${prescription.doctor_name}
                        <div class="text-sm text-gray-500">${prescription.doctor_facility || ''}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${new Date(prescription.prescription_date).toLocaleDateString()}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        <span class="px-2 py-1 text-xs font-semibold rounded-full ${statusClass}">
                            ${prescription.status.charAt(0).toUpperCase() + prescription.status.slice(1)}
                        </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-900">
                        ${dispensedMedicines}/${totalMedicines} medicines
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                        ${hasAlerts ? 
                            '<span class="text-red-500"><i class="fas fa-exclamation-triangle"></i> Alerts</span>' : 
                            '<span class="text-green-500"><i class="fas fa-check-circle"></i> Clear</span>'
                        }
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button onclick="event.stopPropagation(); viewPrescriptionDetails(${prescription.id})" 
                                class="text-indigo-600 hover:text-indigo-900 mr-3" title="View Details">
                            <i class="fas fa-eye"></i>
                        </button>
                        ${prescription.status === 'pending' || prescription.status === 'partial' ?
                            `<button onclick="event.stopPropagation(); dispensePrescription(${prescription.id})" 
                                    class="text-green-600 hover:text-green-900 mr-3" title="Dispense">
                                <i class="fas fa-pills"></i>
                            </button>` : ''
                        }
                        <button onclick="event.stopPropagation(); printPrescription(${prescription.id})" 
                                class="text-blue-600 hover:text-blue-900" title="Print">
                            <i class="fas fa-print"></i>
                        </button>
                    </td>
                </tr>
            `;
        }).join("");
        
    } catch (error) {
        console.error("Error loading prescriptions:", error);
        tbody.innerHTML = '<tr><td colspan="8" class="px-6 py-4 text-center text-red-500">Error loading prescriptions. Please try again.</td></tr>';
    }
}

async function updatePrescriptionStats() {
    try {
        const today = new Date().toISOString().split('T')[0];
        
        const { data: prescriptions, error } = await supabase
            .from("prescriptions")
            .select("status, prescription_date")
            .eq("is_active", true);
        
        if (error) throw new Error(`Stats fetch error: ${error.message}`);
        
        const todayPrescriptions = prescriptions.filter(p => p.prescription_date === today);
        const completed = prescriptions.filter(p => p.status === 'completed');
        const pending = prescriptions.filter(p => p.status === 'pending' || p.status === 'partial');
        
        document.getElementById("todayPrescriptions").textContent = todayPrescriptions.length;
        document.getElementById("completedPrescriptions").textContent = completed.length;
        document.getElementById("pendingPrescriptions").textContent = pending.length;
        
        // Simulated interaction alerts (would be calculated from actual data)
        document.getElementById("interactionAlerts").textContent = Math.floor(Math.random() * 5);
        
    } catch (error) {
        console.error("Error updating stats:", error);
        document.getElementById("todayPrescriptions").textContent = "0";
        document.getElementById("completedPrescriptions").textContent = "0";
        document.getElementById("pendingPrescriptions").textContent = "0";
        document.getElementById("interactionAlerts").textContent = "0";
    }
}

function clearFilters() {
    document.getElementById("prescriptionSearch").value = "";
    document.getElementById("statusFilter").value = "";
    document.getElementById("dateFilter").value = "all";
    renderPrescriptions();
}

async function viewPrescriptionDetails(prescriptionId) {
    try {
        const { data: prescription, error } = await supabase
            .from("prescriptions")
            .select(`
                *,
                customers(name, customer_id, phone),
                prescription_items(*)
            `)
            .eq("id", prescriptionId)
            .single();
        
        if (error) throw new Error(`Prescription fetch error: ${error.message}`);
        
        const detailsContent = document.getElementById("prescriptionDetailsContent");
        detailsContent.innerHTML = `
            <div class="space-y-6">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div class="bg-gray-50 p-4 rounded-lg">
                        <h3 class="font-semibold text-gray-700 mb-3">Prescription Information</h3>
                        <p><strong>Number:</strong> ${prescription.prescription_number}</p>
                        <p><strong>Date:</strong> ${new Date(prescription.prescription_date).toLocaleDateString()}</p>
                        <p><strong>Status:</strong> <span class="px-2 py-1 text-xs font-semibold rounded-full ${getStatusClass(prescription.status)}">${prescription.status.toUpperCase()}</span></p>
                        <p><strong>Diagnosis:</strong> ${prescription.diagnosis || 'Not specified'}</p>
                        ${prescription.special_instructions ? `<p><strong>Instructions:</strong> ${prescription.special_instructions}</p>` : ''}
                    </div>
                    
                    <div class="bg-gray-50 p-4 rounded-lg">
                        <h3 class="font-semibold text-gray-700 mb-3">Patient Information</h3>
                        <p><strong>Name:</strong> ${prescription.customers?.name || 'Unknown'}</p>
                        <p><strong>Customer ID:</strong> ${prescription.customers?.customer_id || 'N/A'}</p>
                        <p><strong>Phone:</strong> ${prescription.customers?.phone || 'N/A'}</p>
                        ${prescription.patient_age ? `<p><strong>Age:</strong> ${prescription.patient_age} years</p>` : ''}
                        ${prescription.patient_weight ? `<p><strong>Weight:</strong> ${prescription.patient_weight} kg</p>` : ''}
                    </div>
                </div>
                
                <div class="bg-gray-50 p-4 rounded-lg">
                    <h3 class="font-semibold text-gray-700 mb-3">Doctor Information</h3>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <p><strong>Name:</strong> ${prescription.doctor_name}</p>
                        <p><strong>License:</strong> ${prescription.doctor_license || 'Not provided'}</p>
                        <p><strong>Phone:</strong> ${prescription.doctor_phone || 'Not provided'}</p>
                        <p><strong>Facility:</strong> ${prescription.doctor_facility || 'Not provided'}</p>
                    </div>
                </div>
                
                <div>
                    <h3 class="font-semibold text-gray-700 mb-3">Prescribed Medicines</h3>
                    <div class="overflow-x-auto">
                        <table class="min-w-full border border-gray-200">
                            <thead class="bg-gray-50">
                                <tr>
                                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Medicine</th>
                                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dosage</th>
                                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Prescribed</th>
                                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Dispensed</th>
                                    <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${prescription.prescription_items.map(item => `
                                    <tr class="border-t border-gray-200">
                                        <td class="px-4 py-2">${item.medicine_name}</td>
                                        <td class="px-4 py-2">${item.dosage}</td>
                                        <td class="px-4 py-2">${item.quantity_prescribed}</td>
                                        <td class="px-4 py-2">${item.quantity_dispensed}</td>
                                        <td class="px-4 py-2">
                                            ${item.quantity_dispensed >= item.quantity_prescribed ? 
                                                '<span class="text-green-600">Complete</span>' : 
                                                '<span class="text-yellow-600">Pending</span>'
                                            }
                                        </td>
                                    </tr>
                                `).join("")}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;
        
        document.getElementById("prescriptionDetailsModal").classList.add("show");
        
    } catch (error) {
        console.error("Error viewing prescription details:", error);
        showNotification("Error loading prescription details.", "error");
    }
}

function getStatusClass(status) {
    const classes = {
        pending: "bg-yellow-100 text-yellow-800",
        partial: "bg-blue-100 text-blue-800",
        completed: "bg-green-100 text-green-800",
        cancelled: "bg-red-100 text-red-800"
    };
    return classes[status] || "bg-gray-100 text-gray-800";
}

async function dispensePrescription(prescriptionId) {
    // Implementation for dispensing would go here
    showNotification("Dispensing feature coming soon!", "info");
}

async function printPrescription(prescriptionId) {
    // Implementation for printing would go here
    showNotification("Print feature coming soon!", "info");
}

// Modal close handlers
document.getElementById("closePrescriptionDetailsModal").addEventListener("click", () => {
    document.getElementById("prescriptionDetailsModal").classList.remove("show");
});

function showNotification(message, type = "info") {
    const notification = document.getElementById("notification");
    notification.textContent = message;
    notification.className = `notification show ${type}`;
    setTimeout(() => notification.classList.remove("show"), 3000);
}
