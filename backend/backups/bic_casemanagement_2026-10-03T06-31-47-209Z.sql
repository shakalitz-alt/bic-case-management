--
-- PostgreSQL database dump
--

\restrict pFA25BbawDl0zTmsyjF18CWWXKPNIkHvcX9ijoG2FDQgCaIq11HPX1ZMoFpXyHg

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: admission_decision_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.admission_decision_enum AS ENUM (
    'ACCEPTED',
    'ACCEPTED_WITH_CONDITIONS',
    'DEFERRED',
    'REFUSED',
    'APPROVED'
);


ALTER TYPE public.admission_decision_enum OWNER TO postgres;

--
-- Name: compound_name_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.compound_name_enum AS ENUM (
    'BALUS',
    'DIWAI',
    'KARANAS',
    'KUNAI',
    'RAUNWARA'
);


ALTER TYPE public.compound_name_enum OWNER TO postgres;

--
-- Name: gender_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.gender_enum AS ENUM (
    'MALE',
    'FEMALE',
    'OTHER'
);


ALTER TYPE public.gender_enum OWNER TO postgres;

--
-- Name: priority_level_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.priority_level_enum AS ENUM (
    'ROUTINE',
    'URGENT',
    'IMMEDIATE'
);


ALTER TYPE public.priority_level_enum OWNER TO postgres;

--
-- Name: risk_level_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.risk_level_enum AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL'
);


ALTER TYPE public.risk_level_enum OWNER TO postgres;

--
-- Name: room_status_enum; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.room_status_enum AS ENUM (
    'AVAILABLE',
    'OCCUPIED',
    'RESERVED',
    'MAINTENANCE'
);


ALTER TYPE public.room_status_enum OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admission_decisions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admission_decisions (
    decision_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    pacir_id uuid,
    receiving_officer_id uuid,
    decision public.admission_decision_enum DEFAULT 'APPROVED'::public.admission_decision_enum,
    decision_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    allocated_compound_id uuid,
    allocated_room_id uuid,
    assigned_case_officer_id uuid,
    initial_risk_classification public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    bic_case_file_number character varying(50),
    special_instructions text,
    decision_status character varying(50) DEFAULT 'CASE_OPENED'::character varying
);


ALTER TABLE public.admission_decisions OWNER TO postgres;

--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_logs (
    log_id integer NOT NULL,
    user_id integer,
    username character varying(100) NOT NULL,
    role character varying(50) NOT NULL,
    action_type character varying(100) NOT NULL,
    resource_affected character varying(150),
    ip_address character varying(45) DEFAULT '127.0.0.1'::character varying,
    details jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audit_logs OWNER TO postgres;

--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_logs_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_logs_log_id_seq OWNER TO postgres;

--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_logs_log_id_seq OWNED BY public.audit_logs.log_id;


--
-- Name: compounds; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.compounds (
    compound_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name public.compound_name_enum NOT NULL,
    description text,
    total_capacity integer NOT NULL,
    current_occupancy integer DEFAULT 0,
    compound_type character varying(50) DEFAULT 'General'::character varying
);


ALTER TABLE public.compounds OWNER TO postgres;

--
-- Name: confiscated_properties; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.confiscated_properties (
    property_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    pacir_id uuid,
    receipt_docket_number character varying(50) NOT NULL,
    was_property_taken boolean DEFAULT false,
    categories_taken text[],
    additional_notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.confiscated_properties OWNER TO postgres;

--
-- Name: onsite_staff_roster; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.onsite_staff_roster (
    roster_id integer NOT NULL,
    officer_name character varying(150) NOT NULL,
    role_title character varying(100) NOT NULL,
    assigned_post character varying(100) NOT NULL,
    shift_period character varying(50) NOT NULL,
    callsign character varying(50),
    status character varying(50) DEFAULT 'ON_DUTY'::character varying,
    logged_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.onsite_staff_roster OWNER TO postgres;

--
-- Name: onsite_staff_roster_roster_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.onsite_staff_roster_roster_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.onsite_staff_roster_roster_id_seq OWNER TO postgres;

--
-- Name: onsite_staff_roster_roster_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.onsite_staff_roster_roster_id_seq OWNED BY public.onsite_staff_roster.roster_id;


--
-- Name: pacir_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pacir_reports (
    pacir_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    pacir_ref_number character varying(50) NOT NULL,
    enforcement_apprehension_no character varying(50) NOT NULL,
    apprehension_date date DEFAULT CURRENT_DATE NOT NULL,
    apprehension_time time without time zone DEFAULT CURRENT_TIME NOT NULL,
    referring_branch character varying(100) DEFAULT 'ENFORCEMENT_AND_COMPLIANCE'::character varying,
    referring_unit character varying(100) DEFAULT 'Compliance Operations Unit'::character varying,
    referring_officer_id uuid,
    operation_name_ref character varying(100),
    priority character varying(50) DEFAULT 'NORMAL'::character varying,
    surname character varying(100) NOT NULL,
    given_names character varying(100) NOT NULL,
    aliases character varying(150),
    date_of_birth date NOT NULL,
    gender public.gender_enum NOT NULL,
    nationality character varying(100) NOT NULL,
    country_of_birth character varying(100),
    passport_number character varying(50),
    passport_expiry_date date,
    visa_reference_number character varying(50),
    current_immigration_status character varying(100) NOT NULL,
    passport_produced boolean DEFAULT false,
    identity_confirmed boolean DEFAULT false,
    interpreter_required boolean DEFAULT false,
    interpreter_language character varying(50),
    photograph_attached boolean DEFAULT false,
    grounds_for_detention text[] DEFAULT ARRAY['Unlawful Non-Citizen / Visa Breach'::text],
    legislative_provision character varying(255) DEFAULT 'Migration Act 1978 — Section 16'::character varying,
    location_of_apprehension character varying(255) DEFAULT 'Port Moresby NCD'::character varying,
    circumstances_summary text,
    submitted_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    assigned_case_officer character varying(100) DEFAULT 'UNASSIGNED'::character varying,
    assigned_ops_officer character varying(100) DEFAULT 'UNASSIGNED'::character varying,
    assignment_updated_at timestamp without time zone DEFAULT now(),
    bic_case_file_number character varying(100),
    overall_calculated_risk character varying(50) DEFAULT 'LOW'::character varying,
    allocated_compound character varying(100) DEFAULT 'UNALLOCATED'::character varying
);


ALTER TABLE public.pacir_reports OWNER TO postgres;

--
-- Name: poi_court_cases; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poi_court_cases (
    case_id integer NOT NULL,
    pacir_id uuid,
    court_name character varying(150) NOT NULL,
    proceeding_type character varying(100) NOT NULL,
    case_file_ref character varying(100) NOT NULL,
    legal_representation character varying(200),
    injunction_granted boolean DEFAULT false,
    next_hearing_date date,
    statutory_hold_expiry timestamp with time zone,
    case_status character varying(50) DEFAULT 'PENDING'::character varying,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.poi_court_cases OWNER TO postgres;

--
-- Name: poi_court_cases_case_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.poi_court_cases_case_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.poi_court_cases_case_id_seq OWNER TO postgres;

--
-- Name: poi_court_cases_case_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.poi_court_cases_case_id_seq OWNED BY public.poi_court_cases.case_id;


--
-- Name: poi_deportations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poi_deportations (
    deportation_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pacir_id uuid NOT NULL,
    deportation_order_ref character varying(100) NOT NULL,
    removal_type character varying(50) DEFAULT 'DEPORTATION_ORDER'::character varying NOT NULL,
    cmo_signed_date date,
    embassy_ctd_status character varying(50) DEFAULT 'PENDING'::character varying,
    ctd_document_ref character varying(100),
    destination_country character varying(100) NOT NULL,
    transit_route character varying(255),
    flight_number character varying(50),
    departure_date timestamp with time zone,
    escort_required boolean DEFAULT false,
    escort_team_details text,
    property_released boolean DEFAULT false,
    logistics_status character varying(50) DEFAULT 'SCHEDULED'::character varying,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    removal_order_status character varying(50) DEFAULT 'PENDING'::character varying,
    etc_issued boolean DEFAULT false NOT NULL,
    airline character varying(150),
    lead_escort_officer character varying(200),
    secondary_escort_officer character varying(200),
    clearance_status character varying(50) DEFAULT 'PENDING'::character varying,
    remarks text
);


ALTER TABLE public.poi_deportations OWNER TO postgres;

--
-- Name: poi_incident_logs; Type: TABLE; Schema: public; Owner: bic_app_user
--

CREATE TABLE public.poi_incident_logs (
    incident_id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_ref_no character varying(50) NOT NULL,
    compound_id uuid,
    primary_poi_id uuid,
    reporting_officer_id uuid,
    severity_level character varying(20) NOT NULL,
    incident_category character varying(50) NOT NULL,
    incident_location character varying(100) NOT NULL,
    incident_timestamp timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    summary_description text NOT NULL,
    action_taken text,
    lockdown_triggered boolean DEFAULT false,
    duty_manager_escalated boolean DEFAULT false,
    resolution_status character varying(30) DEFAULT 'OPEN'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.poi_incident_logs OWNER TO bic_app_user;

--
-- Name: poi_medical_records; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poi_medical_records (
    medical_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pacir_id uuid NOT NULL,
    screening_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    medical_officer_id integer,
    medical_officer character varying(200),
    fit_for_custody boolean DEFAULT true NOT NULL,
    fit_to_travel boolean DEFAULT false NOT NULL,
    chronic_conditions text,
    medications_prescribed text,
    emergency_referral_required boolean DEFAULT false NOT NULL,
    clinical_notes text,
    intake_screening_completed boolean DEFAULT false,
    blood_pressure character varying(20),
    pulse_rate character varying(20),
    temperature_c numeric(4,1),
    pre_existing_conditions text,
    allergies text,
    medication_prescribed text,
    contagious_disease_risk boolean DEFAULT false,
    suicide_watch_active boolean DEFAULT false,
    isolation_required boolean DEFAULT false,
    fit_for_detention boolean DEFAULT true,
    fit_for_travel boolean DEFAULT false,
    medical_clearance_date timestamp without time zone,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.poi_medical_records OWNER TO postgres;

--
-- Name: poi_property_ledger; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.poi_property_ledger (
    ledger_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pacir_id uuid NOT NULL,
    intake_date timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    item_category character varying(100) NOT NULL,
    description text NOT NULL,
    serial_number_or_notes text,
    currency_amount numeric(12,2),
    currency_code character varying(3),
    storage_locker_ref character varying(100),
    custody_status character varying(40) DEFAULT 'IN_CUSTODY'::character varying NOT NULL,
    handling_officer character varying(200),
    handling_officer_id integer,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.poi_property_ledger OWNER TO postgres;

--
-- Name: poi_visitor_logs; Type: TABLE; Schema: public; Owner: bic_app_user
--

CREATE TABLE public.poi_visitor_logs (
    visitor_id uuid DEFAULT gen_random_uuid() NOT NULL,
    pacir_id uuid NOT NULL,
    visitor_type character varying(50) NOT NULL,
    visitor_name character varying(200) NOT NULL,
    organization_or_relation character varying(200),
    id_type_number character varying(100) NOT NULL,
    scheduled_start_time timestamp without time zone NOT NULL,
    entry_timestamp timestamp without time zone,
    exit_timestamp timestamp without time zone,
    consultation_room character varying(50),
    logged_by_officer_id uuid,
    visit_status character varying(30) DEFAULT 'SCHEDULED'::character varying,
    notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.poi_visitor_logs OWNER TO bic_app_user;

--
-- Name: risk_assessments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.risk_assessments (
    risk_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    pacir_id uuid,
    escape_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    violence_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    self_harm_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    medical_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    behavioral_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    security_risk public.risk_level_enum DEFAULT 'LOW'::public.risk_level_enum,
    overall_calculated_risk public.risk_level_enum NOT NULL,
    handcuffs_used boolean DEFAULT false,
    contraband_located boolean DEFAULT false,
    weapons_located boolean DEFAULT false,
    interpreter_required boolean DEFAULT false,
    immediate_medical_required boolean DEFAULT false,
    suicide_risk_identified boolean DEFAULT false,
    escape_history_known boolean DEFAULT false,
    aggressive_behaviour_observed boolean DEFAULT false,
    assessment_comments text,
    recommended_management text
);


ALTER TABLE public.risk_assessments OWNER TO postgres;

--
-- Name: rooms; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rooms (
    room_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    compound_id uuid,
    room_number character varying(20) NOT NULL,
    capacity integer DEFAULT 1,
    status public.room_status_enum DEFAULT 'AVAILABLE'::public.room_status_enum,
    is_isolation_room boolean DEFAULT false,
    room_type character varying(50) DEFAULT 'Standard'::character varying,
    occupied_beds integer DEFAULT 0
);


ALTER TABLE public.rooms OWNER TO postgres;

--
-- Name: system_users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.system_users (
    user_id integer NOT NULL,
    username character varying(100) NOT NULL,
    full_name character varying(150) NOT NULL,
    email character varying(150),
    role character varying(50) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    password_hash character varying(255) DEFAULT '••••••••••••'::character varying,
    CONSTRAINT system_users_role_check CHECK (((role)::text = ANY ((ARRAY['DUTY_MANAGER'::character varying, 'COMPLIANCE_OFFICER'::character varying, 'CASE_OFFICER'::character varying, 'SYSTEM_ADMIN'::character varying])::text[])))
);


ALTER TABLE public.system_users OWNER TO postgres;

--
-- Name: system_users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.system_users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.system_users_user_id_seq OWNER TO postgres;

--
-- Name: system_users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.system_users_user_id_seq OWNED BY public.system_users.user_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email character varying(255) NOT NULL,
    full_name character varying(150) NOT NULL,
    designation character varying(100),
    department character varying(100) NOT NULL,
    role character varying(50) NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: audit_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN log_id SET DEFAULT nextval('public.audit_logs_log_id_seq'::regclass);


--
-- Name: onsite_staff_roster roster_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.onsite_staff_roster ALTER COLUMN roster_id SET DEFAULT nextval('public.onsite_staff_roster_roster_id_seq'::regclass);


--
-- Name: poi_court_cases case_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_court_cases ALTER COLUMN case_id SET DEFAULT nextval('public.poi_court_cases_case_id_seq'::regclass);


--
-- Name: system_users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_users ALTER COLUMN user_id SET DEFAULT nextval('public.system_users_user_id_seq'::regclass);


--
-- Data for Name: admission_decisions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admission_decisions (decision_id, pacir_id, receiving_officer_id, decision, decision_date, allocated_compound_id, allocated_room_id, assigned_case_officer_id, initial_risk_classification, bic_case_file_number, special_instructions, decision_status) FROM stdin;
1c63173f-120e-452e-a1ef-b9022777e409	c8a0024f-d009-4c8d-8a21-93c42a220011	b100cd00-0d1c-5f09-cc7e-7cc0ce491b22	ACCEPTED_WITH_CONDITIONS	2026-09-23 23:28:41.779874+10	1291d8f1-d565-4758-bdd2-a224172901a7	1a2b3c4d-5e6f-4a8b-9c0d-1e2f3a4b5c6d	c200de11-1e2d-4000-dd8f-8dd1df502c33	CRITICAL	BIC-2026-0248	Mandatory 1-on-1 suicide watch protocol upon admission. Immediate medical evaluation by BIC health team prior to compound transfer.	CASE_OPENED
5edbf488-497f-4e20-8e9d-d69c7ce4ddb3	36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	\N	\N	2026-09-24 16:31:07.397827+10	a933d817-b27c-43b9-a0a6-624c44bdbdcd	\N	\N	CRITICAL	BIC-2026-4848	Standard Processing	CASE_OPENED
9eb345e6-04e9-485e-9818-9c1607c6f751	8970a691-efa0-4735-adeb-39a7cf915316	\N	APPROVED	2026-09-25 09:11:43.054071+10	a933d817-b27c-43b9-a0a6-624c44bdbdcd	\N	\N	CRITICAL	BIC-2026-3261	Standard Processing	CASE_OPENED
7c09efce-1109-44ae-ab3c-2dc0315e78ae	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	\N	APPROVED	2026-09-27 21:18:53.474347+10	56744853-2815-49f8-836e-53e9171a3e8d	\N	\N	CRITICAL	BIC-2026-8801	Mandatory 15-minute suicide watch checks.	CASE_OPENED
e6bed6a0-d62c-4de8-b3bb-4c82022b62b7	b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22	\N	APPROVED	2026-09-27 21:18:53.474347+10	eb97da91-3332-4c3e-97f6-788992536ea1	\N	\N	HIGH	BIC-2026-8802	Standard security monitoring.	CASE_OPENED
434cfe22-c92e-4ec2-9d3e-fc294f66262a	c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	\N	\N	2026-09-24 16:29:52.819953+10	a933d817-b27c-43b9-a0a6-624c44bdbdcd	\N	\N	CRITICAL	BIC-2026-8369	Standard Processing	CASE_OPENED
216cc6d7-2080-4c48-ad7a-89ef4c30a544	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33	\N	APPROVED	2026-09-27 21:37:28.561708+10	56744853-2815-49f8-836e-53e9171a3e8d	\N	\N	LOW	BIC-2026-3011	Standard Processing	CASE_OPENED
6ec68331-0a77-40d8-a49b-6b7c2694282d	13e6e502-f271-485f-b4a9-d8ee12af32e6	\N	APPROVED	2026-09-27 21:40:26.516656+10	1291d8f1-d565-4758-bdd2-a224172901a7	\N	\N	CRITICAL	BIC-2026-2983	Standard Processing	CASE_OPENED
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_logs (log_id, user_id, username, role, action_type, resource_affected, ip_address, details, created_at) FROM stdin;
1	\N	admin.kila	DUTY_MANAGER	SYSTEM_INITIALIZATION	BIC_DATABASE	127.0.0.1	{"status": "SUCCESS", "message": "Master DB Schema Patched for Modules 1-5"}	2026-09-24 13:57:01.311385+10
2	\N	admin.kila	DUTY_MANAGER	LEGAL_RECORD_ADDED	PACIR_ID:c8a0024f-d009-4c8d-8a21-93c42a220011	127.0.0.1	{"court_ref": "OS-2026-088", "proceeding": "DEPORTATION_INJUNCTION"}	2026-09-24 15:52:24.802626+10
3	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	127.0.0.1	{"case_no": "BIC-2026-8369"}	2026-09-24 16:29:53.015061+10
4	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	127.0.0.1	{"case_no": "BIC-2026-8369"}	2026-09-24 16:30:22.654239+10
5	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848"}	2026-09-24 16:31:07.42162+10
6	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848"}	2026-09-24 16:31:25.199053+10
7	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848"}	2026-09-24 16:31:41.29204+10
8	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	127.0.0.1	{"case_no": "BIC-2026-8369", "compound": "56744853-2815-49f8-836e-53e9171a3e8d"}	2026-09-24 16:52:53.048883+10
9	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848", "compound": "56744853-2815-49f8-836e-53e9171a3e8d"}	2026-09-24 16:53:00.463215+10
10	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848", "compound": "eb97da91-3332-4c3e-97f6-788992536ea1"}	2026-09-24 16:53:12.550531+10
11	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848", "compound": "a933d817-b27c-43b9-a0a6-624c44bdbdcd"}	2026-09-24 16:53:30.078489+10
12	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848", "compound": "06833443-9ba8-4315-8814-4d79e8219265"}	2026-09-24 16:53:40.882696+10
13	\N	admin.kila	DUTY_MANAGER	CASE_ALLOCATION_UPDATED	PACIR_ID:36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	127.0.0.1	{"case_no": "BIC-2026-4848", "compound": "a933d817-b27c-43b9-a0a6-624c44bdbdcd"}	2026-09-24 17:02:00.045503+10
14	\N	admin.kila	DUTY_MANAGER	DEPORTATION_ORDER_ISSUED	PACIR_ID:c8a0024f-d009-4c8d-8a21-93c42a220011	127.0.0.1	{"ref": "DEP-2026-7865", "destination": "Indonesia"}	2026-09-24 22:10:17.948163+10
15	\N	admin.kila	SYSTEM_ADMIN	USER_CREATED	USER:shakalitz	127.0.0.1	{"assigned_role": "SYSTEM_ADMIN"}	2026-09-24 22:13:09.582762+10
16	\N	admin.kila	SYSTEM_ADMIN	USER_PASSWORD_RESET	USER:shakalitz	127.0.0.1	{"reset_by": "System Administrator"}	2026-09-24 22:37:20.284103+10
17	\N	admin.kila	DUTY_MANAGER	USER_LOGIN_SUCCESS	USER:admin.kila	127.0.0.1	{"login_time": "2026-09-24T12:55:24.180Z"}	2026-09-24 22:55:24.403647+10
18	\N	admin.kila	DUTY_MANAGER	USER_LOGIN_SUCCESS	USER:admin.kila	127.0.0.1	{"login_time": "2026-09-24T12:55:48.145Z"}	2026-09-24 22:55:48.14619+10
19	\N	admin.kila	DUTY_MANAGER	USER_LOGIN_SUCCESS	USER:admin.kila	127.0.0.1	{"login_time": "2026-09-24T12:56:10.619Z"}	2026-09-24 22:56:10.620595+10
20	\N	admin.kila	DUTY_MANAGER	USER_LOGIN_SUCCESS	USER:admin.kila	127.0.0.1	{"login_time": "2026-09-24T12:57:29.585Z"}	2026-09-24 22:57:29.960637+10
21	\N	sys.admin	SYSTEM_ADMIN	USER_LOGIN_SUCCESS	USER:sys.admin	127.0.0.1	{"login_time": "2026-09-24T13:03:56.401Z"}	2026-09-24 23:03:56.402921+10
22	\N	sys.admin	SYSTEM_ADMIN	USER_LOGIN_SUCCESS	USER:sys.admin	127.0.0.1	{"login_time": "2026-09-24T13:22:55.226Z"}	2026-09-24 23:22:55.226796+10
25	5	test_admin	SYSTEM_ADMIN	MEDICAL_RECORD_UPDATED	POI_MEDICAL_RECORDS:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Medical record saved for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:41:40.707+10
26	5	test_admin	SYSTEM_ADMIN	MEDICAL_RECORD_VIEWED	POI_MEDICAL_RECORDS:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Retrieved medical record for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:41:41.269+10
27	5	test_admin	SYSTEM_ADMIN	DEPORTATION_REGISTERED	POI_DEPORTATIONS:f7cbe26b-0547-4edb-a8ac-8082568a99e7	::1	{"target_id": "f7cbe26b-0547-4edb-a8ac-8082568a99e7", "description": "Registered removal order DEP-1790671301311-4541 for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:41:41.354+10
28	5	test_admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 5 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:41:41.394+10
29	5	test_admin	SYSTEM_ADMIN	PROPERTY_ITEM_LOGGED	POI_PROPERTY_LEDGER:e905a25f-cb8b-42e2-bf3e-7f4ad8dea8dd	::1	{"target_id": "e905a25f-cb8b-42e2-bf3e-7f4ad8dea8dd", "description": "Property item registered for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:41:41.462+10
30	5	test_admin	SYSTEM_ADMIN	PROPERTY_LEDGER_VIEWED	POI_PROPERTY_LEDGER:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Retrieved 1 property items for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:41:41.482+10
31	5	test_admin	SYSTEM_ADMIN	MEDICAL_RECORD_UPDATED	POI_MEDICAL_RECORDS:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Medical record saved for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:42:29.293+10
32	5	test_admin	SYSTEM_ADMIN	MEDICAL_RECORD_VIEWED	POI_MEDICAL_RECORDS:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Retrieved medical record for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:42:29.399+10
33	5	test_admin	SYSTEM_ADMIN	DEPORTATION_REGISTERED	POI_DEPORTATIONS:cfcff0c3-5ab8-4ac8-bf47-7766f7dcccc6	::1	{"target_id": "cfcff0c3-5ab8-4ac8-bf47-7766f7dcccc6", "description": "Registered removal order DEP-1790671349411-1422 for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:42:29.427+10
34	5	test_admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:42:29.441+10
35	5	test_admin	SYSTEM_ADMIN	PROPERTY_ITEM_LOGGED	POI_PROPERTY_LEDGER:74cceeb1-e087-4e0b-b885-09dc64afa695	::1	{"target_id": "74cceeb1-e087-4e0b-b885-09dc64afa695", "description": "Property item registered for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:42:29.46+10
36	5	test_admin	SYSTEM_ADMIN	PROPERTY_LEDGER_VIEWED	POI_PROPERTY_LEDGER:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Retrieved 2 property items for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:42:29.471+10
37	5	test_admin	SYSTEM_ADMIN	BIC01_REPORT_GENERATED	REPORTS:c8a0024f-d009-4c8d-8a21-93c42a220011	::1	{"target_id": "c8a0024f-d009-4c8d-8a21-93c42a220011", "description": "Generated Form BIC-01 aggregated report for PACIR c8a0024f-d009-4c8d-8a21-93c42a220011", "target_module": "REPORTS"}	2026-09-29 18:42:29.552+10
39	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:46:42.028+10
38	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:46:42.042+10
40	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:46:42.027+10
41	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:46:54.876+10
42	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:47:04.717+10
43	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-29 18:47:09.429+10
44	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-29 18:47:34.457+10
45	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-29 18:47:56.987+10
48	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-30 09:02:41.22+10
47	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-30 09:02:41.218+10
46	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-30 09:02:41.22+10
49	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-09-30 09:03:09.29+10
50	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-09-30 09:03:12.811+10
51	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-09-30 09:03:16.091+10
53	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 13:09:00.793+10
52	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 13:09:00.788+10
54	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 13:09:00.778+10
55	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 13:12:17.646+10
56	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 13:12:20.679+10
57	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 13:12:22.671+10
58	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:15:45.98+10
59	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:15:47.613+10
60	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:16:16.086+10
61	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:16:24.596+10
62	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:16:30.989+10
64	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:39:14.397+10
63	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:39:14.398+10
65	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:39:14.398+10
66	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:39:23.812+10
68	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:40:24.986+10
67	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:40:24.971+10
69	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:40:25.091+10
70	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:40:43.433+10
71	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:40:46+10
72	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:40:48.288+10
73	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:40:51.48+10
74	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:40:53.151+10
75	4	sys.admin	SYSTEM_ADMIN	DATA_EXPORT	AUDIT_LOGS:ALL	::1	{"target_id": "ALL", "description": "Exported 72 audit-trail records as CSV", "target_module": "AUDIT_LOGS"}	2026-10-03 14:41:18.179+10
76	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:46:29.159+10
77	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:46:31.893+10
78	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:46:33.343+10
79	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:46:58.808+10
80	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:46:59.887+10
81	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 14:47:34.239+10
82	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 14:47:35.495+10
83	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 14:47:36.513+10
84	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:10:13.742+10
85	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:10:13.733+10
86	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:10:13.828+10
87	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:10:30.221+10
88	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:26:32.876+10
89	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:26:32.973+10
90	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:26:33+10
91	4	sys.admin	SYSTEM_ADMIN	USER_CREATED	SYSTEM_USERS:8	::1	{"role": "CASE_OFFICER", "status": "ACTIVE", "username": "tuser", "target_id": "8", "description": "Created system user tuser", "target_module": "SYSTEM_USERS"}	2026-10-03 15:30:28.443+10
92	4	sys.admin	SYSTEM_ADMIN	USER_STATUS_UPDATED	SYSTEM_USERS:8	::1	{"status": "DISABLED", "username": "tuser", "target_id": "8", "description": "Set operator tuser status to DISABLED", "target_module": "SYSTEM_USERS", "previous_status": "ACTIVE"}	2026-10-03 15:30:42.906+10
93	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:31:32.134+10
94	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:31:32.323+10
95	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:31:32.371+10
97	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:42:42.807+10
96	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:42:42.789+10
98	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:42:42.835+10
99	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:45:09.015+10
100	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:56:39.794+10
102	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:56:39.883+10
101	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:56:39.864+10
103	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:58:21.834+10
105	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 15:58:34.305+10
104	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 15:58:34.287+10
106	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:58:34.338+10
107	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 15:58:37.502+10
108	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 16:14:50.519+10
109	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 16:14:50.526+10
110	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 16:14:50.571+10
111	4	sys.admin	SYSTEM_ADMIN	DEPORTATIONS_VIEWED	POI_DEPORTATIONS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 6 deportation records", "target_module": "POI_DEPORTATIONS"}	2026-10-03 16:31:32.164+10
112	4	sys.admin	SYSTEM_ADMIN	PROPERTY_REGISTRY_VIEWED	POI_PROPERTY_LEDGER:ALL	::1	{"target_id": "ALL", "description": "Retrieved 2 property items", "target_module": "POI_PROPERTY_LEDGER"}	2026-10-03 16:31:32.341+10
113	4	sys.admin	SYSTEM_ADMIN	MEDICAL_REGISTRY_VIEWED	POI_MEDICAL_RECORDS:ALL	::1	{"target_id": "ALL", "description": "Retrieved 1 medical records", "target_module": "POI_MEDICAL_RECORDS"}	2026-10-03 16:31:32.348+10
\.


--
-- Data for Name: compounds; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.compounds (compound_id, name, description, total_capacity, current_occupancy, compound_type) FROM stdin;
1291d8f1-d565-4758-bdd2-a224172901a7	BALUS	Isolation / Initial Intake Compound	25	2	General
56744853-2815-49f8-836e-53e9171a3e8d	DIWAI	General Population Male Compound A	25	2	General
06833443-9ba8-4315-8814-4d79e8219265	KARANAS	General Population Male Compound B	24	0	General
a933d817-b27c-43b9-a0a6-624c44bdbdcd	KUNAI	Vulnerable / Medical Care Compound	24	3	General
eb97da91-3332-4c3e-97f6-788992536ea1	RAUNWARA	Pre-Removal / Departure Compound	24	1	General
\.


--
-- Data for Name: confiscated_properties; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.confiscated_properties (property_id, pacir_id, receipt_docket_number, was_property_taken, categories_taken, additional_notes, created_at) FROM stdin;
b6fb37e9-5b9c-470d-a545-e5bd80390062	c8a0024f-d009-4c8d-8a21-93c42a220011	PR-2026-9921	t	{PASSPORT,CASH,MOBILE_PHONE,LUGGAGE}	Property stored in Secure Storage Locker B-12. Passport transferred to Legal Records.	2026-09-23 23:28:41.779874+10
\.


--
-- Data for Name: onsite_staff_roster; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.onsite_staff_roster (roster_id, officer_name, role_title, assigned_post, shift_period, callsign, status, logged_at) FROM stdin;
1	Maru, John	Case Officer	Case Management Office	Day Shift (0700-1900)	DELTA-1	ON_DUTY	2026-09-28 01:18:22.130336
2	Kila, Sarah	Compliance Officer	Admissions Desk	Day Shift (0700-1900)	ALPHA-2	ON_DUTY	2026-09-28 01:18:22.130336
3	Bau, Stephen	Security Officer	Diwai / Main Gate	Day Shift (0700-1900)	SIERRA-4	ON_DUTY	2026-09-28 01:18:22.130336
4	Litz, Shak A.	Duty Manager	Command Center	Day Shift (0700-1900)	COMMAND-1	ON_DUTY	2026-09-28 01:18:22.130336
\.


--
-- Data for Name: pacir_reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pacir_reports (pacir_id, pacir_ref_number, enforcement_apprehension_no, apprehension_date, apprehension_time, referring_branch, referring_unit, referring_officer_id, operation_name_ref, priority, surname, given_names, aliases, date_of_birth, gender, nationality, country_of_birth, passport_number, passport_expiry_date, visa_reference_number, current_immigration_status, passport_produced, identity_confirmed, interpreter_required, interpreter_language, photograph_attached, grounds_for_detention, legislative_provision, location_of_apprehension, circumstances_summary, submitted_at, created_by, assigned_case_officer, assigned_ops_officer, assignment_updated_at, bic_case_file_number, overall_calculated_risk, allocated_compound) FROM stdin;
c8a0024f-d009-4c8d-8a21-93c42a220011	PACIR-2026-0089	ENF-2026-9921	2026-09-23	14:30:00	Compliance & Enforcement	Field Operations Unit	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	Op Guardian	IMMEDIATE	DOE	John	Johnny	1985-04-12	MALE	Indonesia	Indonesia	P12998201	2028-11-20	VRN-88301	Unlawful Non-Citizen	t	t	t	Bahasa Indonesia	t	{UNLAWFUL_NON_CITIZEN,OVERSTAYER}	Section 15B, Migration Act 1978	Port Moresby Seaport	Apprehended during routine maritime vessel inspection without valid entry permit or visa status.	2026-09-23 23:28:41.779874+10	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-c8a0	LOW	UNALLOCATED
c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	PACIR-2026-4280	ENF-2026-9798	2026-09-24	11:04:21	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	IMMEDIATE	WONG	Kevin Wei	\N	1988-11-23	MALE	China	\N	E92018821	\N	\N	Overstayed Visa	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-24 11:04:21.120246+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-c3bd	LOW	UNALLOCATED
36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	PACIR-2026-3559	ENF-2026-7214	2026-09-24	11:28:14	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	IMMEDIATE	Kim	Min-Soo	\N	1992-05-14	MALE	South Korea	\N	M18204928	\N	\N	Overstayed Visa	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-24 11:28:14.467906+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-36d8	LOW	UNALLOCATED
8970a691-efa0-4735-adeb-39a7cf915316	PACIR-2026-5046	ENF-2026-9997	2026-09-24	23:33:36.539783	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	IMMEDIATE	keke	Man	\N	1988-02-17	MALE	Fijian	\N	F1020202	\N	\N	Overstayed Visa	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-24 23:33:36.539783+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-8970	LOW	UNALLOCATED
a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	PACIR-2026-1001	APP-2026-089	2026-09-27	21:18:53.474347	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	IMMEDIATE	KUMAR	Aarav	\N	1988-05-14	MALE	India	\N	P9823411	\N	\N	Overstayed Visa	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-27 21:18:53.474347+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-a0ee	LOW	UNALLOCATED
b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22	PACIR-2026-1002	APP-2026-090	2026-09-27	21:18:53.474347	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	ZHANG	Wei	\N	1992-11-20	MALE	China	\N	E4421098	\N	\N	Unlawful Entry	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-27 21:18:53.474347+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-b0ee	LOW	UNALLOCATED
c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33	PACIR-2026-1003	APP-2026-091	2026-09-27	21:18:53.474347	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	LESI	Tevita	\N	1995-02-03	MALE	Fiji	\N	FJ883012	\N	\N	Expired Work Permit	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-27 21:18:53.474347+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-c0ee	LOW	UNALLOCATED
13e6e502-f271-485f-b4a9-d8ee12af32e6	PACIR-2026-2768	ENF-2026-8400	2026-09-27	21:26:08.106105	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	Keke	Man	\N	1989-10-25	MALE	Mexico	\N	M18204978	\N	\N	Overstayed Visa	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-27 21:26:08.106105+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 01:18:22.130336	BIC-2026-13e6	LOW	UNALLOCATED
e7af932e-a657-4835-a21e-79f923abe705	PACIR-2026-001	EAN-2026-001	2026-09-28	10:05:48.023938	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	DOE	John	\N	1988-05-12	MALE	Indonesia	\N	\N	\N	\N	Unlawful Non-Citizen	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-28 10:05:48.023938+10	\N	Maru, John	Bau, Stephen	2026-09-28 10:05:48.023938	BIC-2026-e7af	LOW	UNALLOCATED
db39854b-0a1a-44ab-98f5-8ef0ca3f1bc1	PACIR-2026-002	EAN-2026-002	2026-09-28	10:05:48.023938	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	WANG	Wei	\N	1992-09-20	MALE	China	\N	\N	\N	\N	Visa Expired	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-28 10:05:48.023938+10	\N	Kila, Sarah	Bau, Stephen	2026-09-28 10:05:48.023938	BIC-2026-db39	LOW	UNALLOCATED
b49840a5-59d2-431c-9373-58514948a42b	PACIR-2026-003	EAN-2026-003	2026-09-28	10:05:48.023938	ENFORCEMENT_AND_COMPLIANCE	Compliance Operations Unit	\N	\N	NORMAL	SINGH	Rajesh	\N	1985-03-15	MALE	India	\N	\N	\N	\N	Prohibited Non-Citizen	f	f	f	\N	f	{"Unlawful Non-Citizen / Visa Breach"}	Migration Act 1978 — Section 16	Port Moresby NCD	\N	2026-09-28 10:05:48.023938+10	\N	UNASSIGNED	UNASSIGNED	2026-09-28 10:05:48.023938	BIC-2026-b498	LOW	UNALLOCATED
\.


--
-- Data for Name: poi_court_cases; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.poi_court_cases (case_id, pacir_id, court_name, proceeding_type, case_file_ref, legal_representation, injunction_granted, next_hearing_date, statutory_hold_expiry, case_status, notes, created_at) FROM stdin;
1	c8a0024f-d009-4c8d-8a21-93c42a220011	National Court of PNG	DEPORTATION_INJUNCTION	OS-2026-088	Keke Man Lawyers	t	2026-10-10	\N	PENDING	Test legal proceedings	2026-09-24 15:52:24.193459+10
\.


--
-- Data for Name: poi_deportations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.poi_deportations (deportation_id, pacir_id, deportation_order_ref, removal_type, cmo_signed_date, embassy_ctd_status, ctd_document_ref, destination_country, transit_route, flight_number, departure_date, escort_required, escort_team_details, property_released, logistics_status, created_at, removal_order_status, etc_issued, airline, lead_escort_officer, secondary_escort_officer, clearance_status, remarks) FROM stdin;
c4b4e284-05d0-4511-b674-2c0b18db97b0	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-2026-7865	DEPORTATION_ORDER	2026-10-09	ISSUED	\N	Indonesia	Port Moresby (POM) -> Direct Flight	PX393	2026-10-10 09:00:00+10	f	ICSA Enforcement	t	SCHEDULED	2026-09-24 22:10:17.706161+10	PENDING	f	\N	\N	\N	PENDING	\N
37564a25-50d0-4f9f-b766-f15fc76219ae	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-2026-6564	DEPORTATION_ORDER	\N	ISSUED	\N	Philipines	\N	PX008	2026-10-10 00:00:00+10	f	Standard Escort	f	SCHEDULED	2026-09-27 22:15:16.125939+10	PENDING	f	\N	\N	\N	PENDING	\N
10544834-cfb3-426b-a766-415379580a99	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-1790671020158-2089	DEPORTATION_ORDER	\N	CLEARED	\N	Australia	\N	PX008	2026-10-02 18:37:00.13+10	t	Senior Escort K. Namaliu; Escort Off. T. Buka	f	APPROVED	2026-09-29 18:37:00.159652+10	APPROVED	t	Air Niugini	Senior Escort K. Namaliu	Escort Off. T. Buka	CLEARED	Direct repatriation dispatch verified
a422dc38-0f22-4a0c-9113-79dee3f4ea7f	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-1790671145269-5426	DEPORTATION_ORDER	\N	CLEARED	\N	Australia	\N	PX008	2026-10-02 18:39:05.268+10	t	Senior Escort K. Namaliu; Escort Off. T. Buka	f	APPROVED	2026-09-29 18:39:05.293729+10	APPROVED	t	Air Niugini	Senior Escort K. Namaliu	Escort Off. T. Buka	CLEARED	Direct repatriation dispatch verified
f7cbe26b-0547-4edb-a8ac-8082568a99e7	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-1790671301311-4541	DEPORTATION_ORDER	\N	CLEARED	\N	Australia	\N	PX008	2026-10-02 18:41:41.32+10	t	Senior Escort K. Namaliu; Escort Off. T. Buka	f	APPROVED	2026-09-29 18:41:41.324957+10	APPROVED	t	Air Niugini	Senior Escort K. Namaliu	Escort Off. T. Buka	CLEARED	Direct repatriation dispatch verified
cfcff0c3-5ab8-4ac8-bf47-7766f7dcccc6	c8a0024f-d009-4c8d-8a21-93c42a220011	DEP-1790671349411-1422	DEPORTATION_ORDER	\N	CLEARED	\N	Australia	\N	PX008	2026-10-02 18:42:29.41+10	t	Senior Escort K. Namaliu; Escort Off. T. Buka	f	APPROVED	2026-09-29 18:42:29.41294+10	APPROVED	t	Air Niugini	Senior Escort K. Namaliu	Escort Off. T. Buka	CLEARED	Direct repatriation dispatch verified
\.


--
-- Data for Name: poi_incident_logs; Type: TABLE DATA; Schema: public; Owner: bic_app_user
--

COPY public.poi_incident_logs (incident_id, incident_ref_no, compound_id, primary_poi_id, reporting_officer_id, severity_level, incident_category, incident_location, incident_timestamp, summary_description, action_taken, lockdown_triggered, duty_manager_escalated, resolution_status, created_at) FROM stdin;
\.


--
-- Data for Name: poi_medical_records; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.poi_medical_records (medical_id, pacir_id, screening_date, medical_officer_id, medical_officer, fit_for_custody, fit_to_travel, chronic_conditions, medications_prescribed, emergency_referral_required, clinical_notes, intake_screening_completed, blood_pressure, pulse_rate, temperature_c, pre_existing_conditions, allergies, medication_prescribed, contagious_disease_risk, suicide_watch_active, isolation_required, fit_for_detention, fit_for_travel, medical_clearance_date, notes, created_at, updated_at) FROM stdin;
601b7ae9-1d5c-47a3-bb40-b800d6829204	c8a0024f-d009-4c8d-8a21-93c42a220011	2026-09-29 18:42:29.091+10	5	Dr. Test Officer	t	t	Mild Hypertension	Amlodipine 5mg	f	Automated test screening assessment note.	t	\N	\N	\N	Mild Hypertension	\N	Amlodipine 5mg	f	f	f	t	t	\N	Automated test screening assessment note.	2026-09-29 18:41:40.592126+10	2026-09-29 18:42:29.142415+10
\.


--
-- Data for Name: poi_property_ledger; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.poi_property_ledger (ledger_id, pacir_id, intake_date, item_category, description, serial_number_or_notes, currency_amount, currency_code, storage_locker_ref, custody_status, handling_officer, handling_officer_id, created_at, updated_at) FROM stdin;
e905a25f-cb8b-42e2-bf3e-7f4ad8dea8dd	c8a0024f-d009-4c8d-8a21-93c42a220011	2026-09-29 18:41:41.426+10	VALUABLES	Gold ring and Samsung Galaxy smartphone	IMEI: 990001234567890	350.50	PGK	LOCKER-4B	IN_CUSTODY	Custody Officer P. Kua	5	2026-09-29 18:41:41.428659+10	2026-09-29 18:41:41.428659+10
74cceeb1-e087-4e0b-b885-09dc64afa695	c8a0024f-d009-4c8d-8a21-93c42a220011	2026-09-29 18:42:29.451+10	VALUABLES	Gold ring and Samsung Galaxy smartphone	IMEI: 990001234567890	350.50	PGK	LOCKER-4B	IN_CUSTODY	Custody Officer P. Kua	5	2026-09-29 18:42:29.453741+10	2026-09-29 18:42:29.453741+10
\.


--
-- Data for Name: poi_visitor_logs; Type: TABLE DATA; Schema: public; Owner: bic_app_user
--

COPY public.poi_visitor_logs (visitor_id, pacir_id, visitor_type, visitor_name, organization_or_relation, id_type_number, scheduled_start_time, entry_timestamp, exit_timestamp, consultation_room, logged_by_officer_id, visit_status, notes, created_at) FROM stdin;
\.


--
-- Data for Name: risk_assessments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.risk_assessments (risk_id, pacir_id, escape_risk, violence_risk, self_harm_risk, medical_risk, behavioral_risk, security_risk, overall_calculated_risk, handcuffs_used, contraband_located, weapons_located, interpreter_required, immediate_medical_required, suicide_risk_identified, escape_history_known, aggressive_behaviour_observed, assessment_comments, recommended_management) FROM stdin;
f179db18-0ead-489e-b657-509c43ba3541	c8a0024f-d009-4c8d-8a21-93c42a220011	HIGH	LOW	CRITICAL	MEDIUM	MEDIUM	HIGH	CRITICAL	t	f	f	t	t	t	f	f	POI exhibited acute emotional distress during transport and expressed self-harm ideation.	Place in Balus Compound isolation room with mandatory 1-on-1 suicide watch protocol. Immediate medical screening required upon admission.
cf545837-f057-4840-9e2c-f9b9d2c1fa72	c3bd6f41-90ee-4b98-a3f5-28a9061e34f8	LOW	LOW	LOW	LOW	LOW	LOW	CRITICAL	t	f	f	f	t	f	f	f	\N	\N
b90c31ce-cbfc-42f8-b3f6-1a360cbd3043	36d8a0fb-d47c-4889-b4e6-c2fdf3ecee5c	LOW	LOW	LOW	LOW	LOW	LOW	CRITICAL	t	f	f	f	f	t	f	f	\N	\N
71136cf8-f2e7-4bb0-a44c-f56e2c1811e5	8970a691-efa0-4735-adeb-39a7cf915316	LOW	LOW	LOW	LOW	LOW	LOW	CRITICAL	t	f	f	f	t	t	f	f	\N	\N
f1e1779a-ed4f-4d3b-8e0b-5723d60e1532	a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	LOW	LOW	LOW	LOW	LOW	LOW	CRITICAL	t	f	f	f	t	t	f	f	\N	\N
c742b227-9a4a-4376-8fa4-ecf4a445a6f0	b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22	LOW	LOW	LOW	LOW	LOW	LOW	HIGH	f	f	f	f	f	f	f	f	\N	\N
7e2c54fb-774b-4ff3-9039-3994b122ab02	c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33	LOW	LOW	LOW	LOW	LOW	LOW	LOW	f	f	f	f	f	f	f	f	\N	\N
2f345fe9-1670-42cd-9938-1b103f4bf2ad	13e6e502-f271-485f-b4a9-d8ee12af32e6	LOW	LOW	LOW	LOW	LOW	LOW	CRITICAL	f	f	f	f	t	f	f	f	\N	\N
\.


--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rooms (room_id, compound_id, room_number, capacity, status, is_isolation_room, room_type, occupied_beds) FROM stdin;
9bc3d868-21c1-427a-91c2-2fd77019c45c	1291d8f1-d565-4758-bdd2-a224172901a7	ROOM-102	1	AVAILABLE	f	Standard	0
483c9a82-024f-4ec0-84be-96873912aa02	1291d8f1-d565-4758-bdd2-a224172901a7	ROOM-103	1	AVAILABLE	f	Standard	0
1a2b3c4d-5e6f-4a8b-9c0d-1e2f3a4b5c6d	1291d8f1-d565-4758-bdd2-a224172901a7	ROOM-101	1	RESERVED	t	Standard	0
a19cf989-c7f9-4f0f-a189-c52bc7b073c6	1291d8f1-d565-4758-bdd2-a224172901a7	B-101	2	AVAILABLE	f	Single Isolation	1
dc3dced4-2d65-4d8d-ba24-7fb14627216a	1291d8f1-d565-4758-bdd2-a224172901a7	B-102	2	AVAILABLE	f	Single Isolation	2
23a93f8c-599c-4fa8-99f6-ffed67e34fa8	56744853-2815-49f8-836e-53e9171a3e8d	D-201	4	AVAILABLE	f	General Dorm	3
\.


--
-- Data for Name: system_users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.system_users (user_id, username, full_name, email, role, is_active, created_at, password_hash) FROM stdin;
5	shakalitz	Shane Hakalitz	shakalitz@icsa.gov.pg	SYSTEM_ADMIN	t	2026-09-24 22:13:09.476499+10	5ann3hy3t!!
4	sys.admin	System Administrator	ict.security@immigration.gov.pg	SYSTEM_ADMIN	t	2026-09-24 13:57:01.311385+10	$2b$10$5cvVBWBnHj5JKQKYTEBQIuS/M9shqUh1vkmeLzAuJSUdaOIa1DDAe
2	maru.j	Jacob Maru	jmaru@immigration.gov.pg	COMPLIANCE_OFFICER	t	2026-09-24 13:57:01.311385+10	$2a$10$Xx/RO9Dvy26KuNCKzW2gSem8DnrHjg44oEvWQ94HyU08HdOp1BBZS
3	bau.s	Sarah Bau	sbau@immigration.gov.pg	CASE_OFFICER	t	2026-09-24 13:57:01.311385+10	$2a$10$0neIR5hCmtcbUeOozblQy.vdsyYMTfJndhiMqu0gi9G0KWiUwUs/S
1	admin.kila	Duty Manager Kila	kila.duty@immigration.gov.pg	DUTY_MANAGER	t	2026-09-24 13:57:01.311385+10	$2a$10$SAS5Ucn4zWqGKk2.V7OLMeyj/vlucUX5IjAjD7aGhzsfyYUJgXOwK
8	tuser	Test User	tuser@icsa.gov.pg	CASE_OFFICER	f	2026-10-03 15:30:28.354512+10	$2a$12$kcHyM93Bj.MtdgISRfKna.XXTHzQTVG8rPXOdlgOf2B.9tbXbDCYm
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, email, full_name, designation, department, role, is_active, created_at) FROM stdin;
a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11	j.maru@immigration.gov.pg	Jacob MARU	Senior Compliance Officer	Compliance & Enforcement	OFFICER	t	2026-09-23 23:28:41.779874+10
b100cd00-0d1c-5f09-cc7e-7cc0ce491b22	m.kila@immigration.gov.pg	Duty Manager KILA	Duty Manager	BIC Operations & Security	DUTY_MANAGER	t	2026-09-23 23:28:41.779874+10
c200de11-1e2d-4000-dd8f-8dd1df502c33	s.bau@immigration.gov.pg	Case Officer BAU	Case Management Officer	BIC Case Management	CASE_OFFICER	t	2026-09-23 23:28:41.779874+10
\.


--
-- Name: audit_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_logs_log_id_seq', 113, true);


--
-- Name: onsite_staff_roster_roster_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.onsite_staff_roster_roster_id_seq', 4, true);


--
-- Name: poi_court_cases_case_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.poi_court_cases_case_id_seq', 1, true);


--
-- Name: system_users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.system_users_user_id_seq', 8, true);


--
-- Name: admission_decisions admission_decisions_bic_case_file_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_bic_case_file_number_key UNIQUE (bic_case_file_number);


--
-- Name: admission_decisions admission_decisions_pacir_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_pacir_id_key UNIQUE (pacir_id);


--
-- Name: admission_decisions admission_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_pkey PRIMARY KEY (decision_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- Name: compounds compounds_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compounds
    ADD CONSTRAINT compounds_name_key UNIQUE (name);


--
-- Name: compounds compounds_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compounds
    ADD CONSTRAINT compounds_pkey PRIMARY KEY (compound_id);


--
-- Name: confiscated_properties confiscated_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.confiscated_properties
    ADD CONSTRAINT confiscated_properties_pkey PRIMARY KEY (property_id);


--
-- Name: onsite_staff_roster onsite_staff_roster_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.onsite_staff_roster
    ADD CONSTRAINT onsite_staff_roster_pkey PRIMARY KEY (roster_id);


--
-- Name: pacir_reports pacir_reports_pacir_ref_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pacir_reports
    ADD CONSTRAINT pacir_reports_pacir_ref_number_key UNIQUE (pacir_ref_number);


--
-- Name: pacir_reports pacir_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pacir_reports
    ADD CONSTRAINT pacir_reports_pkey PRIMARY KEY (pacir_id);


--
-- Name: poi_court_cases poi_court_cases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_court_cases
    ADD CONSTRAINT poi_court_cases_pkey PRIMARY KEY (case_id);


--
-- Name: poi_deportations poi_deportations_deportation_order_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_deportations
    ADD CONSTRAINT poi_deportations_deportation_order_ref_key UNIQUE (deportation_order_ref);


--
-- Name: poi_deportations poi_deportations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_deportations
    ADD CONSTRAINT poi_deportations_pkey PRIMARY KEY (deportation_id);


--
-- Name: poi_incident_logs poi_incident_logs_incident_ref_no_key; Type: CONSTRAINT; Schema: public; Owner: bic_app_user
--

ALTER TABLE ONLY public.poi_incident_logs
    ADD CONSTRAINT poi_incident_logs_incident_ref_no_key UNIQUE (incident_ref_no);


--
-- Name: poi_incident_logs poi_incident_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: bic_app_user
--

ALTER TABLE ONLY public.poi_incident_logs
    ADD CONSTRAINT poi_incident_logs_pkey PRIMARY KEY (incident_id);


--
-- Name: poi_medical_records poi_medical_records_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_medical_records
    ADD CONSTRAINT poi_medical_records_pkey PRIMARY KEY (medical_id);


--
-- Name: poi_property_ledger poi_property_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_property_ledger
    ADD CONSTRAINT poi_property_ledger_pkey PRIMARY KEY (ledger_id);


--
-- Name: poi_visitor_logs poi_visitor_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: bic_app_user
--

ALTER TABLE ONLY public.poi_visitor_logs
    ADD CONSTRAINT poi_visitor_logs_pkey PRIMARY KEY (visitor_id);


--
-- Name: risk_assessments risk_assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.risk_assessments
    ADD CONSTRAINT risk_assessments_pkey PRIMARY KEY (risk_id);


--
-- Name: rooms rooms_compound_id_room_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_compound_id_room_number_key UNIQUE (compound_id, room_number);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (room_id);


--
-- Name: system_users system_users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_users
    ADD CONSTRAINT system_users_pkey PRIMARY KEY (user_id);


--
-- Name: system_users system_users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.system_users
    ADD CONSTRAINT system_users_username_key UNIQUE (username);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_admission_decisions_case_no; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_admission_decisions_case_no ON public.admission_decisions USING btree (bic_case_file_number);


--
-- Name: idx_audit_logs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_audit_logs_created_at ON public.audit_logs USING btree (created_at DESC);


--
-- Name: idx_deportations_pacir_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_deportations_pacir_date ON public.poi_deportations USING btree (pacir_id, departure_date DESC);


--
-- Name: idx_incident_ref; Type: INDEX; Schema: public; Owner: bic_app_user
--

CREATE INDEX idx_incident_ref ON public.poi_incident_logs USING btree (incident_ref_no);


--
-- Name: idx_medical_records_pacir_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_medical_records_pacir_date ON public.poi_medical_records USING btree (pacir_id, screening_date DESC);


--
-- Name: idx_pacir_reports_submitted_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pacir_reports_submitted_at ON public.pacir_reports USING btree (submitted_at DESC);


--
-- Name: idx_poi_court_cases_pacir; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_poi_court_cases_pacir ON public.poi_court_cases USING btree (pacir_id);


--
-- Name: idx_property_ledger_pacir_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_property_ledger_pacir_date ON public.poi_property_ledger USING btree (pacir_id, intake_date DESC);


--
-- Name: idx_risk_assessments_risk_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_risk_assessments_risk_level ON public.risk_assessments USING btree (overall_calculated_risk);


--
-- Name: idx_visitor_pacir; Type: INDEX; Schema: public; Owner: bic_app_user
--

CREATE INDEX idx_visitor_pacir ON public.poi_visitor_logs USING btree (pacir_id);


--
-- Name: idx_visitor_type; Type: INDEX; Schema: public; Owner: bic_app_user
--

CREATE INDEX idx_visitor_type ON public.poi_visitor_logs USING btree (visitor_type);


--
-- Name: admission_decisions admission_decisions_allocated_compound_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_allocated_compound_id_fkey FOREIGN KEY (allocated_compound_id) REFERENCES public.compounds(compound_id);


--
-- Name: admission_decisions admission_decisions_allocated_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_allocated_room_id_fkey FOREIGN KEY (allocated_room_id) REFERENCES public.rooms(room_id);


--
-- Name: admission_decisions admission_decisions_assigned_case_officer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_assigned_case_officer_id_fkey FOREIGN KEY (assigned_case_officer_id) REFERENCES public.users(user_id);


--
-- Name: admission_decisions admission_decisions_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: admission_decisions admission_decisions_receiving_officer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admission_decisions
    ADD CONSTRAINT admission_decisions_receiving_officer_id_fkey FOREIGN KEY (receiving_officer_id) REFERENCES public.users(user_id);


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.system_users(user_id) ON DELETE SET NULL;


--
-- Name: confiscated_properties confiscated_properties_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.confiscated_properties
    ADD CONSTRAINT confiscated_properties_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: pacir_reports pacir_reports_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pacir_reports
    ADD CONSTRAINT pacir_reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: pacir_reports pacir_reports_referring_officer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pacir_reports
    ADD CONSTRAINT pacir_reports_referring_officer_id_fkey FOREIGN KEY (referring_officer_id) REFERENCES public.users(user_id);


--
-- Name: poi_court_cases poi_court_cases_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_court_cases
    ADD CONSTRAINT poi_court_cases_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: poi_deportations poi_deportations_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_deportations
    ADD CONSTRAINT poi_deportations_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: poi_medical_records poi_medical_records_medical_officer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_medical_records
    ADD CONSTRAINT poi_medical_records_medical_officer_id_fkey FOREIGN KEY (medical_officer_id) REFERENCES public.system_users(user_id) ON DELETE SET NULL;


--
-- Name: poi_medical_records poi_medical_records_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_medical_records
    ADD CONSTRAINT poi_medical_records_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: poi_property_ledger poi_property_ledger_handling_officer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_property_ledger
    ADD CONSTRAINT poi_property_ledger_handling_officer_id_fkey FOREIGN KEY (handling_officer_id) REFERENCES public.system_users(user_id) ON DELETE SET NULL;


--
-- Name: poi_property_ledger poi_property_ledger_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.poi_property_ledger
    ADD CONSTRAINT poi_property_ledger_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: risk_assessments risk_assessments_pacir_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.risk_assessments
    ADD CONSTRAINT risk_assessments_pacir_id_fkey FOREIGN KEY (pacir_id) REFERENCES public.pacir_reports(pacir_id) ON DELETE CASCADE;


--
-- Name: rooms rooms_compound_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_compound_id_fkey FOREIGN KEY (compound_id) REFERENCES public.compounds(compound_id);


--
-- Name: TABLE admission_decisions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.admission_decisions TO bic_app_user;


--
-- Name: TABLE audit_logs; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.audit_logs TO bic_app_user;


--
-- Name: SEQUENCE audit_logs_log_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.audit_logs_log_id_seq TO bic_app_user;


--
-- Name: TABLE compounds; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.compounds TO bic_app_user;


--
-- Name: TABLE confiscated_properties; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.confiscated_properties TO bic_app_user;


--
-- Name: TABLE onsite_staff_roster; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.onsite_staff_roster TO bic_app_user;


--
-- Name: SEQUENCE onsite_staff_roster_roster_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.onsite_staff_roster_roster_id_seq TO bic_app_user;


--
-- Name: TABLE pacir_reports; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.pacir_reports TO bic_app_user;


--
-- Name: TABLE poi_court_cases; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.poi_court_cases TO bic_app_user;


--
-- Name: SEQUENCE poi_court_cases_case_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.poi_court_cases_case_id_seq TO bic_app_user;


--
-- Name: TABLE poi_deportations; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.poi_deportations TO bic_app_user;


--
-- Name: TABLE poi_medical_records; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.poi_medical_records TO bic_app_user;


--
-- Name: TABLE poi_property_ledger; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.poi_property_ledger TO bic_app_user;


--
-- Name: TABLE risk_assessments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.risk_assessments TO bic_app_user;


--
-- Name: TABLE rooms; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.rooms TO bic_app_user;


--
-- Name: TABLE system_users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.system_users TO bic_app_user;


--
-- Name: SEQUENCE system_users_user_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.system_users_user_id_seq TO bic_app_user;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO bic_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO bic_app_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO bic_app_user;


--
-- PostgreSQL database dump complete
--

\unrestrict pFA25BbawDl0zTmsyjF18CWWXKPNIkHvcX9ijoG2FDQgCaIq11HPX1ZMoFpXyHg

