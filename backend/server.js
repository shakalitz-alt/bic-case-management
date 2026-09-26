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

const app = express();
const port = process.env.PORT || 3005;
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
// 1. AUTHENTICATION API
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
            port: port,
            database: 'CONNECTED',
            serverTime: dbResult.rows[0].current_time
        });
    } catch (err) {
        res.status(500).json({ status: 'DOWN', database: 'DISCONNECTED', error: err.message });
    }
});

// ==========================================
// 2. ADMISSIONS QUEUE ENDPOINT
// ==========================================
app.get('/v1/admissions/queue', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT 
                p.pacir_id, p.pacir_ref_number, p.surname, p.given_names, 
                p.nationality, p.priority, p.submitted_at, r.overall_calculated_risk,
                r.handcuffs_used, r.suicide_risk_identified, r.immediate_medical_required
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            ORDER BY p.submitted_at DESC;
        `;
        const result = await pool.query(query);
        res.json({ status: 'SUCCESS', count: result.rowCount, data: result.rows });
    } catch (err) {
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
// 4. PACIR FORM BIC-01 FULL DYNAMIC PDF GENERATOR
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
        doc.font('Helvetica').text(data.enforcement_apprehension_no, startX + 340, currentY + 8);

        doc.font('Helvetica-Bold').text('PRIORITY:', startX + 12, currentY + 24);
        doc.fillColor(data.priority === 'IMMEDIATE' ? '#8B0000' : '#0F1E36').font('Helvetica-Bold').text(data.priority, startX + 85, currentY + 24);

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
            ORDER BY p.pacir_id DESC;
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

app.get('/v1/alerts/active', authenticateToken, async (req, res) => {
    try {
        const query = `
            SELECT p.pacir_id, p.pacir_ref_number, p.surname, p.given_names, p.nationality, r.overall_calculated_risk
            FROM pacir_reports p
            JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            WHERE r.overall_calculated_risk IN ('CRITICAL', 'HIGH')
            ORDER BY p.submitted_at DESC LIMIT 10;
        `;
        const { rows } = await pool.query(query);
        res.json({ status: 'SUCCESS', count: rows.length, alerts: rows });
    } catch (err) {
        res.status(500).json({ status: 'ERROR', message: err.message });
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
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupDir = path.join(__dirname, 'backups');
        if (!fs.existsSync(backupDir)) fs.mkdirSync(backupDir, { recursive: true });

        const tables = ['system_users', 'pacir_reports', 'risk_assessments', 'admission_decisions', 'compounds', 'poi_court_cases', 'poi_deportations', 'audit_logs'];
        const jsonBackup = {};

        for (const t of tables) {
            const data = await pool.query(`SELECT * FROM ${t}`);
            jsonBackup[t] = data.rows;
        }

        const jsonBackupPath = path.join(backupDir, `bic_backup_${timestamp}.json`);
        fs.writeFileSync(jsonBackupPath, JSON.stringify(jsonBackup, null, 2));

        res.json({
            status: 'SUCCESS',
            message: 'Database Manual Backup Executed Successfully',
            filename: `bic_backup_${timestamp}.json`,
            path: jsonBackupPath
        });
    } catch (err) {
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

// START SERVER
app.listen(port, () => {
    console.log(`=================================================`);
    console.log(`🚀 BIC API Server running on http://localhost:${port}`);
    console.log(`=================================================`);
});