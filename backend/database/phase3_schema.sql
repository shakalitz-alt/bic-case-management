-- ============================================================
-- PHASE 3 SCHEMA EXPANSION: VISITORS & SECURITY INCIDENTS
-- ============================================================

-- 1. VISITOR & LEGAL COUNSEL ACCESS REGISTRY
CREATE TABLE IF NOT EXISTS poi_visitor_logs (
    visitor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pacir_id UUID NOT NULL,
    visitor_type VARCHAR(50) NOT NULL, -- 'LEGAL_COUNSEL', 'DIPLOMATIC_UNHCR', 'FAMILY', 'OFFICIAL'
    visitor_name VARCHAR(200) NOT NULL,
    organization_or_relation VARCHAR(200),
    id_type_number VARCHAR(100) NOT NULL,
    scheduled_start_time TIMESTAMP NOT NULL,
    entry_timestamp TIMESTAMP,
    exit_timestamp TIMESTAMP,
    consultation_room VARCHAR(50),
    logged_by_officer_id UUID,
    visit_status VARCHAR(30) DEFAULT 'SCHEDULED', -- 'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. SECURITY INCIDENTS & DISCIPLINARY LOG
CREATE TABLE IF NOT EXISTS poi_incident_logs (
    incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_ref_no VARCHAR(50) UNIQUE NOT NULL,
    compound_id UUID,
    primary_poi_id UUID,
    reporting_officer_id UUID,
    severity_level VARCHAR(20) NOT NULL, -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL_LOCKDOWN'
    incident_category VARCHAR(50) NOT NULL, -- 'CONTRABAND', 'ALTERCATION', 'PROPERTY_DAMAGE', 'SECURITY_BREACH', 'MEDICAL_EMERGENCY'
    incident_location VARCHAR(100) NOT NULL,
    incident_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    summary_description TEXT NOT NULL,
    action_taken TEXT,
    lockdown_triggered BOOLEAN DEFAULT FALSE,
    duty_manager_escalated BOOLEAN DEFAULT FALSE,
    resolution_status VARCHAR(30) DEFAULT 'OPEN', -- 'OPEN', 'UNDER_INVESTIGATION', 'RESOLVED'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- INDEXES FOR FAST QUERYING
CREATE INDEX IF NOT EXISTS idx_visitor_pacir ON poi_visitor_logs(pacir_id);
CREATE INDEX IF NOT EXISTS idx_visitor_type ON poi_visitor_logs(visitor_type);
CREATE INDEX IF NOT EXISTS idx_incident_ref ON poi_incident_logs(incident_ref_no);