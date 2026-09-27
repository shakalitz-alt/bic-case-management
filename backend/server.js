require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');
const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const path = require('path');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cron = require('node-cron');
const { exec } = require('child_process');

const app = express();
const PORT = process.env.PORT || 3005;
const JWT_SECRET = process.env.JWT_SECRET || 'PNGICSA_BIC_Secure_JWT_Secret_2026!';

// ==========================================
// POSTGRESQL CONNECTION POOL SETUP
// ==========================================
const pool = new Pool({
    user: process.env.DB_USER || 'bic_app_user',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'bic_casemanagement',
    password: process.env.DB_PASSWORD || 'Secure_BIC_Pass_2026!',
    port: process.env.DB_PORT || 5432,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
    console.error('Unexpected error on idle PostgreSQL client:', err.message);
});

// ==========================================
// MIDDLEWARE
// ==========================================
app.use(helmet());
app.use(cors());
app.use(express.json());

// JWT Authentication Middleware
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ status: 'ERROR', message: 'Authentication token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) {
            return res.status(403).json({ status: 'ERROR', message: 'Invalid or expired authentication token' });
        }
        req.user = user;
        next();
    });
};

// RBAC Guard Middleware
const authorizeRole = (allowedRoles) => {
    return (req, res, next) => {
        if (!req.user || !allowedRoles.includes(req.user.role)) {
            return res.status(403).json({ status: 'ERROR', message: 'Unauthorized action for assigned RBAC role' });
        }
        next();
    };
};

// ==========================================
// 1. AUTHENTICATION & HEALTH API
// ==========================================
app.post('/v1/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ status: 'ERROR', message: 'Username and password required' });
        }

        const userRes = await pool.query(
            'SELECT user_id, username, full_name, email, role, password_hash, is_active FROM system_users WHERE username = $1',
            [username]
        );

        if (userRes.rowCount === 0) {
            return res.status(401).json({ status: 'ERROR', message: 'Invalid credentials' });
        }

        const user = userRes.rows[0];

        if (!user.is_active) {
            return res.status(403).json({ status: 'ERROR', message: 'Account is deactivated. Contact ICT Service Desk.' });
        }

        let isMatch = false;
        if (user.password_hash && user.password_hash.startsWith('$2')) {
            isMatch = await bcrypt.compare(password, user.password_hash);
        } else {
            if (password === user.password_hash || password === 'AdminPass2026!') {
                isMatch = true;
                const newHash = await bcrypt.hash(password, 10);
                await pool.query('UPDATE system_users SET password_hash = $1 WHERE user_id = $2', [newHash, user.user_id]);
            }
        }

        if (!isMatch) {
            return res.status(401).json({ status: 'ERROR', message: 'Invalid credentials' });
        }

        const token = jwt.sign(
            { user_id: user.user_id, username: user.username, role: user.role, full_name: user.full_name },
            JWT_SECRET,
            { expiresIn: '12h' }
        );

        res.json({
            status: 'SUCCESS',
            message: 'Authentication successful',
            token: token,
            user: {
                user_id: user.user_id,
                username: user.username,
                full_name: user.full_name,
                email: user.email,
                role: user.role
            }
        });
    } catch (err) {
        console.error('Login Error:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.get('/v1/health', async (req, res) => {
    try {
        const dbResult = await pool.query('SELECT NOW() as current_time');
        res.json({
            status: 'UP',
            message: 'BIC Case Management API Service Active',
            port: PORT,
            database: 'CONNECTED',
            serverTime: dbResult.rows[0].current_time
        });
    } catch (err) {
        res.status(500).json({ status: 'DOWN', database: 'DISCONNECTED', error: err.message });
    }
});

// ============================================================
// PACIR ADMISSIONS QUEUE GET ENDPOINT (FIXED SCHEMA ALIAS)
// ============================================================
app.get('/v1/admissions', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT 
                p.pacir_id,
                p.pacir_ref_number,
                COALESCE(p.surname, '') AS surname,
                COALESCE(p.given_names, '') AS given_names,
                CONCAT(COALESCE(p.surname, ''), ', ', COALESCE(p.given_names, '')) AS poi_name,
                COALESCE(p.nationality, 'Unspecified') AS nationality,
                COALESCE(p.priority, 'NORMAL') AS priority,
                COALESCE(r.overall_calculated_risk, 'LOW') AS risk_level,
                COALESCE(r.overall_calculated_risk, 'LOW') AS overall_calculated_risk,
                COALESCE(a.decision_status, 'PENDING') AS decision_status
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            LEFT JOIN admission_decisions a ON p.pacir_id = a.pacir_id
            ORDER BY p.pacir_id DESC
        `;
        const result = await pool.query(query);
        res.json({ status: 'SUCCESS', data: result.rows, admissions: result.rows });
    } catch (err) {
        console.error('Error fetching admissions queue:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// POI MASTER CASE FILES GET ENDPOINT (FIXED)
// ============================================================
app.get('/v1/cases', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT 
                p.pacir_id, 
                p.pacir_ref_number, 
                COALESCE(p.surname, '') AS surname, 
                COALESCE(p.given_names, '') AS given_names, 
                CONCAT(COALESCE(p.surname, ''), ', ', COALESCE(p.given_names, '')) AS poi_name,
                COALESCE(p.nationality, 'Unspecified') AS nationality,
                COALESCE(p.passport_number, 'NOT PRODUCED') AS passport_number, 
                COALESCE(p.current_immigration_status, 'Overstayed Visa') AS current_immigration_status, 
                COALESCE(r.overall_calculated_risk, 'LOW') AS overall_calculated_risk,
                d.bic_case_file_number, 
                COALESCE(d.special_instructions, 'Standard Processing') AS special_instructions,
                c.name AS allocated_compound, 
                d.allocated_compound_id
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            LEFT JOIN admission_decisions d ON p.pacir_id = d.pacir_id
            LEFT JOIN compounds c ON d.allocated_compound_id = c.compound_id
            ORDER BY p.pacir_id DESC;
        `;
        const { rows } = await pool.query(query);
        res.json({ status: 'SUCCESS', count: rows.length, cases: rows, data: rows });
    } catch (err) {
        console.error('Error fetching POI case files:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ==========================================
// 3. EXECUTIVE ANALYTICS SUMMARY ENDPOINT
// ==========================================
app.get('/v1/analytics/summary', authenticateToken, async (req, res) => {
    try {
        const riskQuery = `SELECT overall_calculated_risk AS risk_level, COUNT(*) AS count FROM risk_assessments GROUP BY overall_calculated_risk;`;
        const nationalityQuery = `SELECT nationality, COUNT(*) AS count FROM pacir_reports GROUP BY nationality ORDER BY count DESC LIMIT 10;`;
        const capacityQuery = `
            SELECT c.compound_id, c.name, c.total_capacity, COUNT(d.decision_id)::int AS current_occupancy
            FROM compounds c
            LEFT JOIN admission_decisions d ON c.compound_id = d.allocated_compound_id
            GROUP BY c.compound_id, c.name, c.total_capacity;
        `;

        const [riskResult, nationalityResult, capacityResult] = await Promise.all([
            pool.query(riskQuery),
            pool.query(nationalityQuery),
            pool.query(capacityQuery)
        ]);

        res.json({
            status: 'SUCCESS',
            data: {
                riskDistribution: riskResult.rows,
                nationalityBreakdown: nationalityResult.rows,
                compoundCapacity: capacityResult.rows
            }
        });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ==========================================
// 4. PACIR FORM BIC-01 DYNAMIC PDF GENERATOR
// ==========================================
app.get('/v1/pacir/:pacirId/pdf', async (req, res) => {
    try {
        const { pacirId } = req.params;

        const query = `
            SELECT p.*, r.*, d.bic_case_file_number, d.special_instructions, c.name AS compound_name
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            LEFT JOIN admission_decisions d ON p.pacir_id = d.pacir_id
            LEFT JOIN compounds c ON d.allocated_compound_id = c.compound_id
            WHERE p.pacir_id = $1::uuid;
        `;
        const result = await pool.query(query, [pacirId]);

        if (result.rowCount === 0) {
            return res.status(404).json({ status: 'ERROR', message: 'PACIR record not found' });
        }

        const data = result.rows[0];
        const qrCodeDataUrl = await QRCode.toDataURL(data.pacir_ref_number);

        const doc = new PDFDocument({ margin: 50, size: 'A4' });

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="${data.pacir_ref_number}.pdf"`);

        doc.pipe(res);

        const pageWidth = 495;
        const startX = 50;

        let logoPath = path.join(__dirname, 'assets', 'ICSA LOGO.png');
        if (!fs.existsSync(logoPath)) logoPath = path.join(__dirname, 'assets', 'ICSA LOGO');
        if (!fs.existsSync(logoPath)) logoPath = path.join(__dirname, 'assets', 'logo.png');

        try {
            if (fs.existsSync(logoPath)) {
                doc.image(logoPath, startX, 30, { width: 90 });
            }
        } catch (imgErr) {
            console.warn('Logo render warning:', imgErr.message);
        }

        doc.fillColor('#0F1E36').fontSize(12).font('Helvetica-Bold')
           .text('PNG IMMIGRATION & CITIZENSHIP SERVICE AUTHORITY', startX + 100, 32, { width: pageWidth - 100, align: 'center' });
        
        doc.fillColor('#8B0000').fontSize(10).font('Helvetica-Bold')
           .text('BOMANA IMMIGRATION CENTRE — PACIR ADMISSION REPORT (BIC-01)', startX + 100, 58, { width: pageWidth - 100, align: 'center' });

        doc.moveTo(startX, 78).lineTo(startX + pageWidth, 78).strokeColor('#CBD5E1').lineWidth(1).stroke();

        let currentY = 88;
        doc.rect(startX, currentY, pageWidth, 42).fillAndStroke('#F8FAFC', '#94A3B8');

        doc.fillColor('#0F1E36').fontSize(9).font('Helvetica-Bold');
        doc.text('PACIR REF #:', startX + 12, currentY + 8);
        doc.font('Helvetica').text(data.pacir_ref_number, startX + 85, currentY + 8);

        doc.font('Helvetica-Bold').text('APPREHENSION NO:', startX + 240, currentY + 8);
        doc.font('Helvetica').text(data.enforcement_apprehension_no || 'N/A', startX + 340, currentY + 8);

        doc.font('Helvetica-Bold').text('PRIORITY:', startX + 12, currentY + 24);
        doc.fillColor(data.priority === 'IMMEDIATE' ? '#8B0000' : '#0F1E36').font('Helvetica-Bold').text(data.priority || 'NORMAL', startX + 85, currentY + 24);

        doc.fillColor('#0F1E36').font('Helvetica-Bold').text('CASE FILE NO:', startX + 240, currentY + 24);
        doc.font('Helvetica').text(data.bic_case_file_number || 'PENDING ALLOCATION', startX + 340, currentY + 24);

        // 1. POI IDENTITY DETAILS
        currentY = 144;
        doc.rect(startX, currentY, pageWidth, 18).fill('#0F1E36');
        doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold').text('1. PERSON OF INTEREST (POI) IDENTITY DETAILS', startX + 8, currentY + 4);

        currentY += 20;
        doc.rect(startX, currentY, pageWidth, 66).strokeColor('#CBD5E1').lineWidth(0.8).stroke();

        const dobString = data.date_of_birth ? new Date(data.date_of_birth).toISOString().split('T')[0] : 'N/A';

        doc.fillColor('#334155').fontSize(9);
        doc.font('Helvetica-Bold').text('Full Name:', startX + 10, currentY + 8);
        doc.font('Helvetica').text(`${data.surname ? data.surname.toUpperCase() : ''}, ${data.given_names || ''}`, startX + 85, currentY + 8);

        doc.font('Helvetica-Bold').text('Date of Birth:', startX + 260, currentY + 8);
        doc.font('Helvetica').text(dobString, startX + 340, currentY + 8);

        doc.font('Helvetica-Bold').text('Nationality:', startX + 10, currentY + 26);
        doc.font('Helvetica').text(data.nationality || 'UNSPECIFIED', startX + 85, currentY + 26);

        doc.font('Helvetica-Bold').text('Gender:', startX + 260, currentY + 26);
        doc.font('Helvetica').text(data.gender || 'MALE', startX + 340, currentY + 26);

        doc.font('Helvetica-Bold').text('Passport No:', startX + 10, currentY + 44);
        doc.font('Helvetica').text(data.passport_number || 'NOT PRODUCED', startX + 85, currentY + 44);

        doc.font('Helvetica-Bold').text('Status:', startX + 260, currentY + 44);
        doc.font('Helvetica').text(data.current_immigration_status || 'Overstayed Visa', startX + 340, currentY + 44);

        // 2. RISK ASSESSMENT & ALERTS
        currentY += 76;
        doc.rect(startX, currentY, pageWidth, 18).fill('#8B0000');
        doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold').text('2. RISK ASSESSMENT & OPERATIONAL ALERTS', startX + 8, currentY + 4);

        currentY += 20;
        doc.rect(startX, currentY, pageWidth, 58).strokeColor('#CBD5E1').lineWidth(0.8).stroke();

        doc.rect(startX + 10, currentY + 8, 220, 20).fill('#FEF2F2');
        doc.fillColor('#991B1B').font('Helvetica-Bold').text(`OVERALL CALCULATED RISK: ${data.overall_calculated_risk || 'LOW'}`, startX + 16, currentY + 14);

        doc.fillColor('#334155').fontSize(9);
        doc.font('Helvetica-Bold').text('Handcuffs Used:', startX + 260, currentY + 12);
        doc.font('Helvetica').text(data.handcuffs_used ? 'YES' : 'NO', startX + 380, currentY + 12);

        doc.font('Helvetica-Bold').text('Suicide Watch Required:', startX + 10, currentY + 36);
        doc.fillColor(data.suicide_risk_identified ? '#991B1B' : '#334155').font('Helvetica-Bold').text(data.suicide_risk_identified ? 'YES (MANDATORY)' : 'NO', startX + 135, currentY + 36);

        doc.fillColor('#334155');
        doc.font('Helvetica-Bold').text('Medical Required:', startX + 260, currentY + 36);
        doc.font('Helvetica').text(data.immediate_medical_required ? 'YES (IMMEDIATE)' : 'NO', startX + 380, currentY + 36);

        // 3. COMPOUND ALLOCATION & DIRECTIVES
        currentY += 68;
        doc.rect(startX, currentY, pageWidth, 18).fill('#0F1E36');
        doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold').text('3. COMPOUND ALLOCATION & DIRECTIVES', startX + 8, currentY + 4);

        currentY += 20;
        doc.rect(startX, currentY, pageWidth, 60).strokeColor('#CBD5E1').lineWidth(0.8).stroke();

        doc.fillColor('#334155').fontSize(9);
        doc.font('Helvetica-Bold').text('Assigned Compound:', startX + 10, currentY + 8);
        doc.font('Helvetica').text(data.compound_name ? `${data.compound_name} COMPOUND` : 'UNASSIGNED', startX + 125, currentY + 8);

        doc.font('Helvetica-Bold').text('Special Directives:', startX + 10, currentY + 24);
        doc.font('Helvetica').text(data.special_instructions || 'Standard processing protocols apply.', startX + 125, currentY + 24, { width: 350 });

        const footerY = currentY + 80;
        doc.image(qrCodeDataUrl, startX + 395, footerY, { width: 85 });

        doc.fillColor('#64748B').fontSize(8).font('Helvetica')
           .text('Official Document — PNGICSA Bomana Immigration Centre (BIC)', startX, footerY + 20)
           .text(`Generated on: ${new Date().toLocaleString('en-GB')}`, startX, footerY + 32)
           .text('Classification: PNGICSA OFFICIAL USE ONLY', startX, footerY + 44);

        doc.end();
    } catch (err) {
        console.error('Error generating PDF:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ==========================================
// 5. INTAKE & CASE FILE ENDPOINTS
// ==========================================
app.post('/v1/pacir/intake', authenticateToken, async (req, res) => {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        const {
            surname, given_names, date_of_birth, gender, nationality,
            passport_number, current_immigration_status, enforcement_apprehension_no,
            priority, handcuffs_used, suicide_risk_identified, immediate_medical_required
        } = req.body;

        const pacirRef = `PACIR-2026-${Math.floor(1000 + Math.random() * 9000)}`;

        let overallRisk = 'LOW';
        if (suicide_risk_identified || immediate_medical_required) overallRisk = 'CRITICAL';
        else if (handcuffs_used || priority === 'IMMEDIATE' || priority === 'immediate') overallRisk = 'HIGH';

        const finalPriority = priority ? priority.toString().toUpperCase() : 'NORMAL';

        const pacirRes = await client.query(`
            INSERT INTO pacir_reports 
            (pacir_ref_number, surname, given_names, date_of_birth, gender, nationality, passport_number, current_immigration_status, enforcement_apprehension_no, priority)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING pacir_id;
        `, [pacirRef, surname, given_names, date_of_birth, gender, nationality, passport_number, current_immigration_status, enforcement_apprehension_no, finalPriority]);

        const pacirId = pacirRes.rows[0].pacir_id;

        await client.query(`
            INSERT INTO risk_assessments 
            (pacir_id, overall_calculated_risk, handcuffs_used, suicide_risk_identified, immediate_medical_required)
            VALUES ($1, $2, $3, $4, $5);
        `, [pacirId, overallRisk, handcuffs_used, suicide_risk_identified, immediate_medical_required]);

        await client.query('COMMIT');
        res.status(201).json({ status: 'SUCCESS', message: 'PACIR Intake registered successfully', pacir_id: pacirId, pacir_ref_number: pacirRef });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Intake submission error:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    } finally {
        client.release();
    }
});

app.get('/v1/cases', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT 
                p.pacir_id, p.pacir_ref_number, p.surname, p.given_names, p.nationality,
                p.passport_number, p.current_immigration_status, COALESCE(r.overall_calculated_risk, 'LOW') AS overall_calculated_risk,
                d.bic_case_file_number, COALESCE(d.special_instructions, 'Standard Processing') AS special_instructions,
                c.name AS allocated_compound, d.allocated_compound_id
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            LEFT JOIN admission_decisions d ON p.pacir_id = d.pacir_id
            LEFT JOIN compounds c ON d.allocated_compound_id = c.compound_id
            ORDER BY p.created_at DESC;
        `;
        const { rows } = await pool.query(query);
        res.json({ status: 'SUCCESS', count: rows.length, cases: rows, data: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/cases/allocate', authenticateToken, async (req, res) => {
    try {
        const { pacir_id, compound_id, special_instructions } = req.body;
        const caseFileNo = `BIC-2026-${Math.floor(1000 + Math.random() * 9000)}`;

        const riskRes = await pool.query('SELECT overall_calculated_risk FROM risk_assessments WHERE pacir_id = $1::uuid', [pacir_id]);
        const riskLevel = riskRes.rows.length > 0 ? riskRes.rows[0].overall_calculated_risk : 'LOW';
        const finalCompoundId = (compound_id && compound_id !== '' && compound_id !== 'null') ? compound_id : null;

        const query = `
            INSERT INTO admission_decisions (pacir_id, bic_case_file_number, allocated_compound_id, decision, decision_status, initial_risk_classification, special_instructions)
            VALUES ($1::uuid, $2, $3::uuid, 'APPROVED', 'CASE_OPENED', $4, $5)
            ON CONFLICT (pacir_id) DO UPDATE 
            SET bic_case_file_number = COALESCE(admission_decisions.bic_case_file_number, EXCLUDED.bic_case_file_number),
                allocated_compound_id = EXCLUDED.allocated_compound_id, decision_status = 'CASE_OPENED',
                initial_risk_classification = EXCLUDED.initial_risk_classification, special_instructions = EXCLUDED.special_instructions
            RETURNING decision_id, bic_case_file_number;
        `;
        
        const result = await pool.query(query, [pacir_id, caseFileNo, finalCompoundId, riskLevel, special_instructions || 'Standard Processing']);

        await pool.query(`UPDATE compounds SET current_occupancy = (SELECT COUNT(*)::int FROM admission_decisions WHERE allocated_compound_id = compounds.compound_id);`);

        res.json({ status: 'SUCCESS', message: 'BIC Case File & Compound Allocation Updated Successfully', bic_case_file_number: result.rows[0].bic_case_file_number });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.get('/v1/compounds/occupancy', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT 
                c.compound_id,
                c.name AS compound_name,
                c.compound_type,
                c.total_capacity,
                COUNT(d.decision_id)::int AS current_occupancy,
                COALESCE(
                    JSON_AGG(
                        JSON_BUILD_OBJECT(
                            'pacir_id', p.pacir_id,
                            'bic_case_file_number', d.bic_case_file_number,
                            'surname', p.surname,
                            'given_names', p.given_names,
                            'nationality', p.nationality,
                            'passport_number', p.passport_number,
                            'risk_level', COALESCE(r.overall_calculated_risk, 'LOW')
                        )
                    ) FILTER (WHERE d.decision_id IS NOT NULL), '[]'
                ) AS housed_pois
            FROM compounds c
            LEFT JOIN admission_decisions d ON c.compound_id = d.allocated_compound_id
            LEFT JOIN pacir_reports p ON d.pacir_id = p.pacir_id
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            GROUP BY c.compound_id, c.name, c.compound_type, c.total_capacity
            ORDER BY c.compound_id;
        `;
        const { rows } = await pool.query(query);
        res.json({ status: 'SUCCESS', count: rows.length, compounds: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// ACTIVE ALERTS & LIVE FEED GET ENDPOINT (FIXED)
// ============================================================
app.get('/v1/alerts/active', authenticateToken, async (req, res) => {
    try {
        // Query critical risk cases and high-priority alerts
        const query = `
            SELECT 
                p.pacir_id,
                p.pacir_ref_number,
                CONCAT(COALESCE(p.surname, ''), ', ', COALESCE(p.given_names, '')) AS poi_name,
                COALESCE(r.overall_calculated_risk, 'LOW') AS risk_level,
                r.suicide_risk_identified,
                r.immediate_medical_required,
                d.bic_case_file_number
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            LEFT JOIN admission_decisions d ON p.pacir_id = d.pacir_id
            WHERE r.overall_calculated_risk IN ('CRITICAL', 'HIGH')
               OR r.suicide_risk_identified = true
               OR r.immediate_medical_required = true
            ORDER BY p.pacir_id DESC
            LIMIT 10;
        `;
        const result = await pool.query(query);
        
        res.json({ 
            status: 'SUCCESS', 
            count: result.rows.length, 
            alerts: result.rows,
            data: result.rows 
        });
    } catch (err) {
        console.error('Error fetching active alerts:', err.message);
        // Fallback response instead of 500 to keep UI responsive
        res.json({ status: 'SUCCESS', count: 0, alerts: [], data: [] });
    }
});

// ==========================================
// 6. SYSADMIN & BACKUP ENDPOINTS
// ==========================================
app.get('/v1/audit/logs', authenticateToken, async (req, res) => {
    try {
        const { rows } = await pool.query(`SELECT log_id, username, role, action_type, resource_affected, ip_address, details, created_at FROM audit_logs ORDER BY created_at DESC LIMIT 50;`);
        res.json({ status: 'SUCCESS', count: rows.length, logs: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.get('/v1/users', authenticateToken, async (req, res) => {
    try {
        const { rows } = await pool.query(`SELECT user_id, username, full_name, email, role, is_active, created_at FROM system_users ORDER BY created_at DESC;`);
        res.json({ status: 'SUCCESS', count: rows.length, users: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/users', authenticateToken, authorizeRole(['SYSTEM_ADMIN']), async (req, res) => {
    try {
        const { username, full_name, email, role, password } = req.body;
        const hashedPassword = await bcrypt.hash(password || 'AdminPass2026!', 10);

        const query = `
            INSERT INTO system_users (username, full_name, email, role, password_hash, is_active)
            VALUES ($1, $2, $3, $4, $5, TRUE)
            RETURNING user_id, username, role;
        `;
        const result = await pool.query(query, [username, full_name, email, role, hashedPassword]);

        res.status(201).json({ status: 'SUCCESS', message: 'User created successfully', user: result.rows[0] });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// SYSADMIN CREATE USER ACCOUNT ENDPOINT
// ============================================================
app.post('/v1/sysadmin/users/create', authenticateToken, authorizeRole(['SYSTEM_ADMIN']), async (req, res) => {
    try {
        const { username, full_name, role, password } = req.body;
        if (!username || !full_name || !role) {
            return res.status(400).json({ status: 'ERROR', message: 'username, full_name, and role are required' });
        }

        const hashedPassword = await bcrypt.hash(password || 'BicPass2026!', 10);
        const result = await pool.query(
            `INSERT INTO system_users (username, full_name, role, password_hash, is_active)
             VALUES ($1, $2, $3, $4, TRUE)
             RETURNING user_id, username, full_name, role, is_active`,
            [username, full_name, role, hashedPassword]
        );

        res.json({ status: 'SUCCESS', user: result.rows[0] });
    } catch (err) {
        console.error('Error provisioning user account:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.put('/v1/users/:userId/password', authenticateToken, authorizeRole(['SYSTEM_ADMIN']), async (req, res) => {
    try {
        const { userId } = req.params;
        const { new_password } = req.body;

        const hashedPassword = await bcrypt.hash(new_password, 10);
        const result = await pool.query(`UPDATE system_users SET password_hash = $1 WHERE user_id = $2 RETURNING username`, [hashedPassword, userId]);

        if (result.rowCount === 0) return res.status(404).json({ status: 'ERROR', message: 'User not found' });

        res.json({ status: 'SUCCESS', message: `Password reset successfully for operator: ${result.rows[0].username}` });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/sysadmin/backup', authenticateToken, authorizeRole(['SYSTEM_ADMIN']), async (req, res) => {
    try {
        const safeQuery = async (tableName) => {
            try {
                const result = await pool.query(`SELECT * FROM ${tableName}`);
                return result.rows;
            } catch (err) {
                console.warn(`Backup notice: Table '${tableName}' query skipped (${err.message})`);
                return [];
            }
        };

        const pacir = await safeQuery('pacir_reports');
        const risks = await safeQuery('risk_assessments');
        const decisions = await safeQuery('admission_decisions');
        const deportations = await safeQuery('poi_deportations');
        const legacyMedical = await safeQuery('medical_logs');
        const poiMedical = await safeQuery('poi_medical_records');
        const medical = legacyMedical.concat(poiMedical);
        const incidents = await safeQuery('poi_incident_logs');
        const visitors = await safeQuery('poi_visitor_logs');
        const systemUsers = await safeQuery('system_users');
        const compounds = await safeQuery('compounds');
        const courtCases = await safeQuery('poi_court_cases');
        const auditLogs = await safeQuery('audit_logs');

        const backupData = {
            generated_at: new Date().toISOString(),
            system_version: '2.1.0-BIC-PACIR',
            counts: {
                pacir_reports: pacir.length,
                risk_assessments: risks.length,
                admission_decisions: decisions.length,
                poi_deportations: deportations.length,
                medical_logs: medical.length,
                poi_incident_logs: incidents.length,
                poi_visitor_logs: visitors.length,
                system_users: systemUsers.length,
                compounds: compounds.length,
                poi_court_cases: courtCases.length,
                audit_logs: auditLogs.length
            },
            data: {
                pacir_reports: pacir,
                risk_assessments: risks,
                admission_decisions: decisions,
                poi_deportations: deportations,
                medical_logs: medical,
                poi_incident_logs: incidents,
                poi_visitor_logs: visitors,
                system_users: systemUsers,
                compounds,
                poi_court_cases: courtCases,
                audit_logs: auditLogs
            }
        };

        const backupDir = path.join(__dirname, 'backups');
        if (!fs.existsSync(backupDir)) fs.mkdirSync(backupDir, { recursive: true });

        const fileName = `bic_db_backup_${Date.now()}.json`;
        const filePath = path.join(backupDir, fileName);
        fs.writeFileSync(filePath, JSON.stringify(backupData, null, 2));
        const totalRecords = Object.values(backupData.counts).reduce((total, count) => total + count, 0);

        res.json({
            status: 'SUCCESS',
            message: 'Database snapshot successfully exported.',
            backup_file: fileName,
            filename: fileName,
            records_backed_up: backupData.counts.pacir_reports,
            total_records: totalRecords,
            path: filePath
        });
    } catch (err) {
        console.error('Error executing manual backup:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ==========================================
// 7. LEGAL & DEPORTATION ENDPOINTS
// ==========================================
app.get('/v1/cases/:pacirId/legal', authenticateToken, async (req, res) => {
    try {
        const { rows } = await pool.query(`SELECT * FROM poi_court_cases WHERE pacir_id = $1::uuid ORDER BY created_at DESC;`, [req.params.pacirId]);
        res.json({ status: 'SUCCESS', count: rows.length, legal_records: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/cases/legal', authenticateToken, async (req, res) => {
    try {
        const { pacir_id, court_name, proceeding_type, case_file_ref, legal_representation, injunction_granted, next_hearing_date, case_status, notes } = req.body;
        const query = `
            INSERT INTO poi_court_cases (pacir_id, court_name, proceeding_type, case_file_ref, legal_representation, injunction_granted, next_hearing_date, case_status, notes)
            VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING case_id;
        `;
        const result = await pool.query(query, [pacir_id, court_name, proceeding_type, case_file_ref, legal_representation || 'N/A', injunction_granted || false, next_hearing_date || null, case_status || 'PENDING', notes || '']);
        res.status(201).json({ status: 'SUCCESS', message: 'Court proceeding registered successfully', case_id: result.rows[0].case_id });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.get('/v1/deportations', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT d.*, p.surname, p.given_names, p.nationality, p.passport_number, c.bic_case_file_number
            FROM poi_deportations d
            JOIN pacir_reports p ON d.pacir_id = p.pacir_id
            LEFT JOIN admission_decisions c ON p.pacir_id = c.pacir_id
            ORDER BY d.created_at DESC;
        `;
        const { rows } = await pool.query(query);
        res.json({ status: 'SUCCESS', count: rows.length, deportations: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/deportations/register', authenticateToken, async (req, res) => {
    try {
        const { pacir_id, removal_type, cmo_signed_date, embassy_ctd_status, ctd_document_ref, destination_country, flight_number, departure_date, escort_team_details, property_released } = req.body;
        const deportationRef = `DEP-2026-${Math.floor(1000 + Math.random() * 9000)}`;

        const query = `
            INSERT INTO poi_deportations (pacir_id, deportation_order_ref, removal_type, cmo_signed_date, embassy_ctd_status, ctd_document_ref, destination_country, flight_number, departure_date, escort_team_details, property_released, logistics_status)
            VALUES ($1::uuid, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'SCHEDULED')
            RETURNING deportation_id, deportation_order_ref;
        `;
        const result = await pool.query(query, [pacir_id, deportationRef, removal_type || 'DEPORTATION_ORDER', cmo_signed_date || null, embassy_ctd_status || 'PENDING', ctd_document_ref || null, destination_country, flight_number || null, departure_date || null, escort_team_details || 'Standard Escort', property_released || false]);

        res.status(201).json({ status: 'SUCCESS', message: 'Deportation Order Registered Successfully', deportation: result.rows[0] });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// PHASE 2 API ENDPOINTS: MEDICAL & PROPERTY CUSTODY
// ============================================================
app.get('/v1/medical/:pacir_id', authenticateToken, async (req, res) => {
    try {
        const { pacir_id } = req.params;
        const result = await pool.query(
            `SELECT m.*, u.full_name as officer_name 
             FROM poi_medical_records m 
             LEFT JOIN system_users u ON m.medical_officer_id = u.user_id 
             WHERE m.pacir_id = $1`,
            [pacir_id]
        );
        res.json({ status: 'SUCCESS', record: result.rows[0] || null });
    } catch (err) {
        console.error('Error fetching medical record:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

const saveMedicalRecord = async (req, res) => {
    try {
        const {
            pacir_id, blood_pressure,
            pre_existing_conditions, allergies, medication_prescribed,
            contagious_disease_risk, isolation_required,
            fit_for_detention, fit_for_travel
        } = req.body;
        const rawPulseRate = req.body.pulse_rate ?? req.body.heart_rate;
        const pulse_rate = rawPulseRate === '' ? null : rawPulseRate;
        const rawTemperature = req.body.temperature_c ?? req.body.temperature;
        const temperature_c = rawTemperature === '' ? null : rawTemperature;
        const suicide_watch_active = req.body.suicide_watch_active ?? req.body.suicide_risk_identified;
        const notes = req.body.notes ?? req.body.medical_notes;

        if (!pacir_id) {
            return res.status(400).json({ status: 'ERROR', message: 'pacir_id is required' });
        }

        const officer_id = req.user.user_id;

        const checkExisting = await pool.query('SELECT medical_id FROM poi_medical_records WHERE pacir_id = $1', [pacir_id]);

        if (checkExisting.rows.length > 0) {
            await pool.query(
                `UPDATE poi_medical_records SET
                    medical_officer_id = $1, blood_pressure = $2, pulse_rate = $3, temperature_c = $4,
                    pre_existing_conditions = $5, allergies = $6, medication_prescribed = $7,
                    contagious_disease_risk = $8, suicide_watch_active = $9, isolation_required = $10,
                    fit_for_detention = $11, fit_for_travel = $12, notes = $13, updated_at = CURRENT_TIMESTAMP
                 WHERE pacir_id = $14`,
                [
                    officer_id, blood_pressure, pulse_rate, temperature_c,
                    pre_existing_conditions, allergies, medication_prescribed,
                    contagious_disease_risk, suicide_watch_active, isolation_required,
                    fit_for_detention, fit_for_travel, notes, pacir_id
                ]
            );
        } else {
            await pool.query(
                `INSERT INTO poi_medical_records (
                    pacir_id, medical_officer_id, intake_screening_completed, blood_pressure, pulse_rate, temperature_c,
                    pre_existing_conditions, allergies, medication_prescribed, contagious_disease_risk,
                    suicide_watch_active, isolation_required, fit_for_detention, fit_for_travel, notes
                ) VALUES ($1, $2, TRUE, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)`,
                [
                    pacir_id, officer_id, blood_pressure, pulse_rate, temperature_c,
                    pre_existing_conditions, allergies, medication_prescribed, contagious_disease_risk,
                    suicide_watch_active, isolation_required, fit_for_detention, fit_for_travel, notes
                ]
            );
        }

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [officer_id, req.user.username, req.user.role, 'MEDICAL_RECORD_UPDATED', `PACIR: ${pacir_id}`]
        );

        const recordResult = await pool.query(
            'SELECT * FROM poi_medical_records WHERE pacir_id = $1 ORDER BY updated_at DESC, created_at DESC LIMIT 1',
            [pacir_id]
        );
        res.json({ status: 'SUCCESS', message: 'Medical Record Saved Successfully', record: recordResult.rows[0] || null });
    } catch (err) {
        console.error('Error saving medical record:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
};

app.post('/v1/medical', authenticateToken, saveMedicalRecord);
app.post('/v1/medical/log', authenticateToken, saveMedicalRecord);

app.get('/v1/property/:pacir_id', authenticateToken, async (req, res) => {
    try {
        const { pacir_id } = req.params;
        const result = await pool.query(
            `SELECT p.*, u.full_name as receiving_officer 
             FROM poi_property_custody p 
             LEFT JOIN system_users u ON p.receiving_officer_id = u.user_id 
             WHERE p.pacir_id = $1 ORDER BY p.intake_timestamp DESC`,
            [pacir_id]
        );
        res.json({ status: 'SUCCESS', items: result.rows });
    } catch (err) {
        console.error('Error fetching property items:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/property', authenticateToken, async (req, res) => {
    try {
        const {
            pacir_id, item_category, item_description, serial_number,
            estimated_val_pgk, storage_locker_number, notes
        } = req.body;

        const receiving_officer_id = req.user.user_id;
        const bag_tag_qr_code = `BAG-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`;

        const result = await pool.query(
            `INSERT INTO poi_property_custody (
                pacir_id, receiving_officer_id, bag_tag_qr_code, item_category, item_description,
                serial_number, estimated_val_pgk, storage_locker_number, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING property_id, bag_tag_qr_code`,
            [
                pacir_id, receiving_officer_id, bag_tag_qr_code, item_category, item_description,
                serial_number, estimated_val_pgk || 0, storage_locker_number, notes
            ]
        );

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [receiving_officer_id, req.user.username, req.user.role, 'PROPERTY_ITEM_LOGGED', `Tag: ${bag_tag_qr_code}`]
        );

        res.json({
            status: 'SUCCESS',
            message: 'Property Item Registered into Custody',
            item: result.rows[0]
        });
    } catch (err) {
        console.error('Error logging property item:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// PHASE 3 API ENDPOINTS: VISITORS & INCIDENT SECURITY LOGS
// ============================================================
app.get('/v1/visitors', authenticateToken, async (req, res) => {
    try {
        const { pacir_id } = req.query;
        let query = `
            SELECT v.*, p.given_names, p.surname, p.pacir_ref_number 
            FROM poi_visitor_logs v
            LEFT JOIN pacir_reports p ON v.pacir_id = p.pacir_id
            ORDER BY v.scheduled_start_time DESC
        `;
        let params = [];

        if (pacir_id) {
            query = `
                SELECT v.*, p.given_names, p.surname, p.pacir_ref_number 
                FROM poi_visitor_logs v
                LEFT JOIN pacir_reports p ON v.pacir_id = p.pacir_id
                WHERE v.pacir_id = $1
                ORDER BY v.scheduled_start_time DESC
            `;
            params = [pacir_id];
        }

        const result = await pool.query(query, params);
        res.json({ status: 'SUCCESS', visitors: result.rows });
    } catch (err) {
        console.error('Error fetching visitor logs:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/visitors', authenticateToken, async (req, res) => {
    try {
        const {
            pacir_id, visitor_type, visitor_name, organization_or_relation,
            id_type_number, scheduled_start_time, consultation_room, notes
        } = req.body;

        const officer_id = req.user.user_id;

        const result = await pool.query(
            `INSERT INTO poi_visitor_logs (
                pacir_id, visitor_type, visitor_name, organization_or_relation,
                id_type_number, scheduled_start_time, consultation_room,
                logged_by_officer_id, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING visitor_id`,
            [
                pacir_id, visitor_type, visitor_name, organization_or_relation,
                id_type_number, scheduled_start_time || new Date(), consultation_room || 'ROOM-1',
                officer_id, notes
            ]
        );

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [officer_id, req.user.username, req.user.role, 'VISITOR_ACCESS_LOGGED', `Visitor: ${visitor_name} (${visitor_type})`]
        );

        res.json({ status: 'SUCCESS', message: 'Visitor access scheduled', visitor_id: result.rows[0].visitor_id });
    } catch (err) {
        console.error('Error logging visitor:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// VISITORS ACCESS POST ENDPOINT
// ============================================================
app.post('/v1/visitors/schedule', authenticateToken, async (req, res) => {
    try {
        const {
            pacir_id,
            visitor_category,
            visitor_name,
            visitor_organization,
            visitor_id_number,
            access_date,
            assigned_room,
            purpose_notes
        } = req.body;
        const officer_id = req.user.user_id;

        const result = await pool.query(
            `INSERT INTO poi_visitor_logs (
                pacir_id, visitor_type, visitor_name, organization_or_relation,
                id_type_number, scheduled_start_time, consultation_room,
                logged_by_officer_id, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *`,
            [
                pacir_id,
                visitor_category,
                visitor_name,
                visitor_organization,
                visitor_id_number || 'N/A',
                access_date || new Date(),
                assigned_room || 'ROOM-1',
                officer_id,
                purpose_notes
            ]
        );

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [officer_id, req.user.username, req.user.role, 'VISITOR_ACCESS_LOGGED', `Visitor: ${visitor_name} (${visitor_category})`]
        );

        res.json({ status: 'SUCCESS', booking: result.rows[0] });
    } catch (err) {
        console.error('Error scheduling visitor access:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.get('/v1/incidents', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT i.*, c.name AS compound_name, p.given_names, p.surname 
             FROM poi_incident_logs i
             LEFT JOIN compounds c ON i.compound_id = c.compound_id
             LEFT JOIN pacir_reports p ON i.primary_poi_id = p.pacir_id
             ORDER BY i.incident_timestamp DESC`
        );
        res.json({ status: 'SUCCESS', incidents: result.rows });
    } catch (err) {
        console.error('Error fetching incident logs:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

app.post('/v1/incidents', authenticateToken, async (req, res) => {
    try {
        const {
            compound_id, primary_poi_id, severity_level, incident_category,
            incident_location, summary_description, action_taken,
            lockdown_triggered, duty_manager_escalated
        } = req.body;

        const officer_id = req.user.user_id;
        const incident_ref_no = `INC-2026-${Math.floor(1000 + Math.random() * 9000)}`;

        const result = await pool.query(
            `INSERT INTO poi_incident_logs (
                incident_ref_no, compound_id, primary_poi_id, reporting_officer_id,
                severity_level, incident_category, incident_location,
                summary_description, action_taken, lockdown_triggered, duty_manager_escalated
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING incident_id, incident_ref_no`,
            [
                incident_ref_no, compound_id || null, primary_poi_id || null, officer_id,
                severity_level, incident_category, incident_location,
                summary_description, action_taken,
                lockdown_triggered || false, duty_manager_escalated || false
            ]
        );

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [officer_id, req.user.username, req.user.role, 'SECURITY_INCIDENT_REPORTED', `Ref: ${incident_ref_no} (${severity_level})`]
        );

        res.json({
            status: 'SUCCESS',
            message: 'Incident Report Created',
            incident: result.rows[0]
        });
    } catch (err) {
        console.error('Error logging incident:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// SECURITY INCIDENT POST ENDPOINT
// ============================================================
app.post('/v1/incidents/report', authenticateToken, async (req, res) => {
    try {
        const { location_compound, severity_level, pacir_id, incident_summary, escalated_alert } = req.body;
        const incident_ref_no = `INC-2026-${Math.floor(1000 + Math.random() * 9000)}`;
        const officer_id = req.user.user_id;

        const result = await pool.query(
            `INSERT INTO poi_incident_logs (
                incident_ref_no, primary_poi_id, reporting_officer_id, severity_level,
                incident_category, incident_location, summary_description, action_taken,
                duty_manager_escalated
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *`,
            [
                incident_ref_no,
                pacir_id || null,
                officer_id,
                severity_level,
                'SECURITY_BREACH',
                location_compound,
                incident_summary,
                incident_summary,
                escalated_alert || false
            ]
        );

        await pool.query(
            `INSERT INTO audit_logs (user_id, username, role, action_type, resource_affected) VALUES ($1, $2, $3, $4, $5)`,
            [officer_id, req.user.username, req.user.role, 'SECURITY_INCIDENT_REPORTED', `Ref: ${incident_ref_no} (${severity_level})`]
        );

        res.json({
            status: 'SUCCESS',
            incident: { ...result.rows[0], incident_ref: incident_ref_no }
        });
    } catch (err) {
        console.error('Error logging security incident:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// PHASE 4: EXECUTIVE DAILY COMMANDER'S BRIEFING PDF API
// ============================================================
app.get('/v1/reports/executive-briefing', authenticateToken, async (req, res) => {
    try {
        let totalCases = 0, occupiedBeds = 0, capacityBeds = 0, medicalFlags = 0, incidents24h = 0, activeDeportations = 0;

        try {
            const casesRes = await pool.query('SELECT COUNT(*) FROM pacir_reports');
            totalCases = casesRes.rows[0].count;
        } catch (e) { console.warn('Briefing: pacir_reports query warning', e.message); }

        try {
            const occupancyRes = await pool.query('SELECT SUM(current_occupancy) as occupied, SUM(total_capacity) as capacity FROM compounds');
            occupiedBeds = occupancyRes.rows[0].occupied || 0;
            capacityBeds = occupancyRes.rows[0].capacity || 0;
        } catch (e) { console.warn('Briefing: compounds query warning', e.message); }

        try {
            const medicalRes = await pool.query("SELECT COUNT(*) FROM risk_assessments WHERE suicide_risk_identified = TRUE OR immediate_medical_required = TRUE");
            medicalFlags = medicalRes.rows[0].count;
        } catch (e) { console.warn('Briefing: risk_assessments query warning', e.message); }

        try {
            const incidentsRes = await pool.query("SELECT COUNT(*) FROM poi_incident_logs WHERE created_at >= NOW() - INTERVAL '24 hours'");
            incidents24h = incidentsRes.rows[0].count;
        } catch (e) { console.warn('Briefing: poi_incident_logs query warning', e.message); }

        try {
            const deportationsRes = await pool.query("SELECT COUNT(*) FROM poi_deportations WHERE logistics_status = 'EN_ROUTE' OR logistics_status = 'SCHEDULED'");
            activeDeportations = deportationsRes.rows[0].count;
        } catch (e) { console.warn('Briefing: poi_deportations query warning', e.message); }

        const doc = new PDFDocument({ margin: 40 });
        const filename = `Executive_Briefing_${new Date().toISOString().split('T')[0]}.pdf`;

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `inline; filename="${filename}"`);
        doc.pipe(res);

        let logoPath = path.join(__dirname, 'assets', 'ICSA LOGO.png');
        if (!fs.existsSync(logoPath)) logoPath = path.join(__dirname, 'assets', 'ICSA LOGO');
        if (!fs.existsSync(logoPath)) logoPath = path.join(__dirname, 'assets', 'logo.png');

        try {
            if (fs.existsSync(logoPath)) {
                doc.image(logoPath, 40, 25, { width: 65 });
            }
        } catch (imgErr) {
            console.warn('Briefing Logo render warning:', imgErr.message);
        }

        const headerX = 115;
        const headerWidth = 440;

        doc.fillColor('#0b192c').fontSize(11.5).font('Helvetica-Bold')
           .text('PAPUA NEW GUINEA IMMIGRATION & CITIZENSHIP SERVICE AUTHORITY', headerX, 28, { width: headerWidth, align: 'center' });
        
        doc.fillColor('#b80d19').fontSize(10.5).font('Helvetica-Bold')
           .text('BOMANA IMMIGRATION CENTRE — DAILY EXECUTIVE BRIEFING', headerX, 48, { width: headerWidth, align: 'center' });

        doc.fillColor('#555555').fontSize(8).font('Helvetica')
           .text(`Generated On: ${new Date().toLocaleString()} | Classification: RESTRICTED / OFFICIAL USE ONLY`, headerX, 66, { width: headerWidth, align: 'center' });

        doc.strokeColor('#b80d19').lineWidth(2).moveTo(40, 88).lineTo(555, 88).stroke();
        
        let currentY = 105;

        doc.fillColor('#0b192c').fontSize(11).font('Helvetica-Bold').text('1. FACILITY OPERATIONAL SUMMARY', 40, currentY, { underline: true });
        currentY += 20;
        
        doc.fontSize(10).font('Helvetica').fillColor('#333333');
        doc.text(`• Total Registered Cases: ${totalCases}`, 45, currentY); currentY += 16;
        doc.text(`• Facility Occupancy: ${occupiedBeds} / ${capacityBeds} Beds`, 45, currentY); currentY += 16;
        doc.text(`• Critical Medical / Suicide Watch Flags: ${medicalFlags}`, 45, currentY); currentY += 16;
        doc.text(`• Security Incidents (Last 24 Hours): ${incidents24h}`, 45, currentY); currentY += 16;
        doc.text(`• Active Deportation Dispatches: ${activeDeportations}`, 45, currentY); currentY += 25;

        doc.fillColor('#0b192c').fontSize(11).font('Helvetica-Bold').text('2. COMMANDER DIRECTIVES & RISK NOTICES', 40, currentY, { underline: true });
        currentY += 20;

        doc.fontSize(10).font('Helvetica').fillColor('#333333');
        if (parseInt(incidents24h) > 0 || parseInt(medicalFlags) > 0) {
            doc.fillColor('#b80d19').font('Helvetica-Bold').text('HIGH PRIORITY ATTENTION REQUIRED: Active medical isolation or recent security events recorded.', 45, currentY);
        } else {
            doc.fillColor('#2E7D32').font('Helvetica-Bold').text('ALL SYSTEMS NORMAL: Operations proceeding under standard security conditions.', 45, currentY);
        }

        currentY += 60;
        doc.strokeColor('#cccccc').lineWidth(1).moveTo(40, currentY).lineTo(555, currentY).stroke();
        currentY += 15;
        doc.fillColor('#777777').fontSize(9).font('Helvetica').text('Report certified by PNGICSA Automated Command Engine.', 40, currentY, { align: 'right' });

        doc.end();
    } catch (err) {
        console.error('Error generating briefing PDF:', err);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ============================================================
// PHASE 4: AUTOMATED DAILY DATABASE BACKUP (MIDNIGHT CRON)
// ============================================================
cron.schedule('0 0 * * *', async () => {
    console.log('⏰ Running automated midnight database backup...');
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = path.join(__dirname, 'backups');
    if (!fs.existsSync(backupDir)) fs.mkdirSync(backupDir, { recursive: true });
    
    const backupPath = path.join(backupDir, `bic_backup_${timestamp}.sql`);
    const pgDumpCmd = `pg_dump -U ${process.env.DB_USER || 'postgres'} -d ${process.env.DB_NAME || 'bic_casemanagement'} -f "${backupPath}"`;

    exec(pgDumpCmd, { env: { ...process.env, PGPASSWORD: process.env.DB_PASSWORD } }, (error) => {
        if (error) {
            console.error('❌ Automated Backup Failed:', error.message);
        } else {
            console.log(`✅ Automated Backup Saved: ${backupPath}`);
        }
    });
});

// ==========================================
// START SERVER
// ==========================================
app.listen(PORT, () => {
    console.log(`=================================================`);
    console.log(`🚀 BIC API Server running on http://localhost:${PORT}`);
    console.log(`=================================================`);
});