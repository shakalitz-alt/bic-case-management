-- ============================================================
-- PHASE 4: MEDICAL, DEPORTATION, AND PROPERTY LEDGER
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS poi_medical_records (
    medical_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID NOT NULL REFERENCES pacir_reports(pacir_id) ON DELETE CASCADE,
    screening_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    medical_officer_id INTEGER REFERENCES system_users(user_id) ON DELETE SET NULL,
    medical_officer VARCHAR(200),
    fit_for_custody BOOLEAN NOT NULL DEFAULT TRUE,
    fit_to_travel BOOLEAN NOT NULL DEFAULT FALSE,
    chronic_conditions TEXT,
    medications_prescribed TEXT,
    emergency_referral_required BOOLEAN NOT NULL DEFAULT FALSE,
    clinical_notes TEXT,
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
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE poi_medical_records
    ADD COLUMN IF NOT EXISTS screening_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS medical_officer_id INTEGER,
    ADD COLUMN IF NOT EXISTS medical_officer VARCHAR(200),
    ADD COLUMN IF NOT EXISTS fit_for_custody BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS fit_to_travel BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS chronic_conditions TEXT,
    ADD COLUMN IF NOT EXISTS medications_prescribed TEXT,
    ADD COLUMN IF NOT EXISTS emergency_referral_required BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS clinical_notes TEXT,
    ADD COLUMN IF NOT EXISTS intake_screening_completed BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS blood_pressure VARCHAR(20),
    ADD COLUMN IF NOT EXISTS pulse_rate VARCHAR(20),
    ADD COLUMN IF NOT EXISTS temperature_c DECIMAL(4,1),
    ADD COLUMN IF NOT EXISTS pre_existing_conditions TEXT,
    ADD COLUMN IF NOT EXISTS allergies TEXT,
    ADD COLUMN IF NOT EXISTS medication_prescribed TEXT,
    ADD COLUMN IF NOT EXISTS contagious_disease_risk BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS suicide_watch_active BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS isolation_required BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS fit_for_detention BOOLEAN DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS fit_for_travel BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS medical_clearance_date TIMESTAMP,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

CREATE TABLE IF NOT EXISTS poi_deportations (
    deportation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID NOT NULL REFERENCES pacir_reports(pacir_id) ON DELETE CASCADE,
    deportation_order_ref VARCHAR(50) UNIQUE NOT NULL,
    removal_type VARCHAR(50) NOT NULL DEFAULT 'DEPORTATION_ORDER',
    removal_order_status VARCHAR(50) DEFAULT 'PENDING',
    cmo_signed_date DATE,
    embassy_ctd_status VARCHAR(50) DEFAULT 'PENDING',
    etc_issued BOOLEAN NOT NULL DEFAULT FALSE,
    ctd_document_ref VARCHAR(100),
    destination_country VARCHAR(100) NOT NULL,
    transit_route TEXT,
    flight_number VARCHAR(50),
    airline VARCHAR(150),
    departure_date TIMESTAMPTZ,
    escort_required BOOLEAN DEFAULT FALSE,
    lead_escort_officer VARCHAR(200),
    secondary_escort_officer VARCHAR(200),
    escort_team_details TEXT,
    clearance_status VARCHAR(50) DEFAULT 'PENDING',
    property_released BOOLEAN DEFAULT FALSE,
    remarks TEXT,
    logistics_status VARCHAR(50) DEFAULT 'SCHEDULED',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE poi_deportations
    ADD COLUMN IF NOT EXISTS removal_order_status VARCHAR(50) DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS etc_issued BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS airline VARCHAR(150),
    ADD COLUMN IF NOT EXISTS lead_escort_officer VARCHAR(200),
    ADD COLUMN IF NOT EXISTS secondary_escort_officer VARCHAR(200),
    ADD COLUMN IF NOT EXISTS clearance_status VARCHAR(50) DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS remarks TEXT;

CREATE TABLE IF NOT EXISTS poi_property_ledger (
    ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID NOT NULL REFERENCES pacir_reports(pacir_id) ON DELETE CASCADE,
    intake_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    item_category VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    serial_number_or_notes TEXT,
    currency_amount NUMERIC(12,2),
    currency_code VARCHAR(3),
    storage_locker_ref VARCHAR(100),
    custody_status VARCHAR(40) NOT NULL DEFAULT 'IN_CUSTODY',
    handling_officer VARCHAR(200),
    handling_officer_id INTEGER REFERENCES system_users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE poi_property_ledger
    ADD COLUMN IF NOT EXISTS intake_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS item_category VARCHAR(100),
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS serial_number_or_notes TEXT,
    ADD COLUMN IF NOT EXISTS currency_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS currency_code VARCHAR(3),
    ADD COLUMN IF NOT EXISTS storage_locker_ref VARCHAR(100),
    ADD COLUMN IF NOT EXISTS custody_status VARCHAR(40) DEFAULT 'IN_CUSTODY',
    ADD COLUMN IF NOT EXISTS handling_officer VARCHAR(200),
    ADD COLUMN IF NOT EXISTS handling_officer_id INTEGER,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_medical_records_pacir_date ON poi_medical_records (pacir_id, screening_date DESC);
CREATE INDEX IF NOT EXISTS idx_deportations_pacir_date ON poi_deportations (pacir_id, departure_date DESC);
CREATE INDEX IF NOT EXISTS idx_property_ledger_pacir_date ON poi_property_ledger (pacir_id, intake_date DESC);

COMMIT;
