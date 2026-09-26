-- ============================================================
-- PHASE 2 SCHEMA EXPANSION: MEDICAL & PROPERTY CUSTODY
-- ============================================================

-- 1. MEDICAL & HEALTH REGISTRY TABLE
CREATE TABLE IF NOT EXISTS poi_medical_records (
    medical_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID REFERENCES pacir_intake(pacir_id) ON DELETE CASCADE,
    medical_officer_id UUID REFERENCES system_users(user_id),
    intake_screening_completed BOOLEAN DEFAULT FALSE,
    blood_pressure VARCHAR(20),
    pulse_rate VARCHAR(20),
    temperature_c DECIMAL(4,1),
    pre_existing_conditions TEXT,
    allergies TEXT,
    medication_prescribed TEXT,
    contagious_disease_risk BOOLEAN DEFAULT FALSE,
    suicide_watch_active BOOLEAN DEFAULT FALSE,
    isolation_required BOOLEAN DEFAULT FALSE,
    fit_for_detention BOOLEAN DEFAULT TRUE,
    fit_for_travel BOOLEAN DEFAULT FALSE,
    medical_clearance_date TIMESTAMP,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. POI PROPERTY & VALUABLES CUSTODY TABLE
CREATE TABLE IF NOT EXISTS poi_property_custody (
    property_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID REFERENCES pacir_intake(pacir_id) ON DELETE CASCADE,
    receiving_officer_id UUID REFERENCES system_users(user_id),
    bag_tag_qr_code VARCHAR(100) UNIQUE NOT NULL,
    item_category VARCHAR(50) NOT NULL, -- 'CASH', 'ELECTRONICS', 'DOCUMENTS', 'LUGGAGE', 'JEWELRY'
    item_description TEXT NOT NULL,
    serial_number VARCHAR(100),
    estimated_val_pgk DECIMAL(10,2),
    custody_status VARCHAR(30) DEFAULT 'STORED', -- 'STORED', 'RETURNED_UPON_DEPORTATION', 'CONFISCATED'
    storage_locker_number VARCHAR(50),
    intake_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    released_timestamp TIMESTAMP,
    releasing_officer_id UUID REFERENCES system_users(user_id),
    notes TEXT
);

-- INDEXES FOR FAST QUERYING
CREATE INDEX IF NOT EXISTS idx_medical_pacir ON poi_medical_records(pacir_id);
CREATE INDEX IF NOT EXISTS idx_property_pacir ON poi_property_custody(pacir_id);
CREATE INDEX IF NOT EXISTS idx_property_qr ON poi_property_custody(bag_tag_qr_code);