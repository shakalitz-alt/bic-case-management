require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');
const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const path = require('path');
const fs = require('fs');

const app = express();
const port = process.env.PORT || 3005;

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

// ==========================================
// 1. HEALTH CHECK ENDPOINT
// ==========================================
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
        console.error('Database connection error:', err.message);
        res.status(500).json({ status: 'DOWN', database: 'DISCONNECTED', error: err.message });
    }
});

// ==========================================
// 2. ADMISSIONS QUEUE ENDPOINT
// ==========================================
app.get('/v1/admissions/queue', async (req, res) => {
    try {
        const query = `
            SELECT 
                p.pacir_id, 
                p.pacir_ref_number, 
                p.surname, 
                p.given_names, 
                p.nationality, 
                p.priority, 
                p.submitted_at,
                r.overall_calculated_risk,
                r.handcuffs_used, 
                r.suicide_risk_identified, 
                r.immediate_medical_required
            FROM pacir_reports p
            LEFT JOIN risk_assessments r ON p.pacir_id = r.pacir_id
            ORDER BY p.submitted_at DESC;
        `;
        const result = await pool.query(query);
        res.json({ status: 'SUCCESS', count: result.rowCount, data: result.rows });
    } catch (err) {
        console.error('Error fetching queue:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// ==========================================
// 3. EXECUTIVE ANALYTICS SUMMARY ENDPOINT
// ==========================================
app.get('/v1/analytics/summary', async (req, res) => {
    try {
        const riskQuery = `
            SELECT overall_calculated_risk AS risk_level, COUNT(*) AS count
            FROM risk_assessments
            GROUP BY overall_calculated_risk;
        `;
        const nationalityQuery = `
            SELECT nationality, COUNT(*) AS count
            FROM pacir_reports
            GROUP BY nationality
            ORDER BY count DESC
            LIMIT 10;
        `;
        const capacityQuery = `
            SELECT name, total_capacity, current_occupancy
            FROM compounds;
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
        console.error('Error fetching analytics:', err.message);
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
            WHERE p.pacir_id = $1;
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

        const pageWidth = 495; // 595.28 (A4 width) - 100 (50pt margins)
        const startX = 50;

        // --- HEADER & BRANDING WITH LOGO ---
        let logoPath = path.join(__dirname, 'assets', 'ICSA LOGO.png');
        if (!fs.existsSync(logoPath)) {
            logoPath = path.join(__dirname, 'assets', 'ICSA LOGO');
        }
        if (!fs.existsSync(logoPath)) {
            logoPath = path.join(__dirname, 'assets', 'logo.png');
        }

        try {
            if (fs.existsSync(logoPath)) {
                // Sized and aligned cleanly on the top-left
                doc.image(logoPath, startX, 30, { width: 90 });
            }
        } catch (imgErr) {
            console.warn('Logo render warning:', imgErr.message);
        }

        // Title Header Text - Right aligned with comfortable margins
        doc.fillColor('#0F1E36').fontSize(12).font('Helvetica-Bold')
           .text('PNG IMMIGRATION & CITIZENSHIP SERVICE AUTHORITY', startX + 100, 32, { width: pageWidth - 100, align: 'center' });
        
        doc.fillColor('#8B0000').fontSize(10).font('Helvetica-Bold')
           .text('BOMANA IMMIGRATION CENTRE — PACIR ADMISSION REPORT (BIC-01)', startX + 100, 58, { width: pageWidth - 100, align: 'center' });

        // Clean Horizontal Divider Line
        doc.moveTo(startX, 78).lineTo(startX + pageWidth, 78).strokeColor('#CBD5E1').lineWidth(1).stroke();

        // --- SUMMARY METADATA BANNER ---
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

        // --- SECTION 1: POI IDENTITY DETAILS ---
        currentY = 144;

        doc.rect(startX, currentY, pageWidth, 18).fill('#0F1E36');
        doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold').text('1. PERSON OF INTEREST (POI) IDENTITY DETAILS', startX + 8, currentY + 4);

        currentY += 20;
        doc.rect(startX, currentY, pageWidth, 66).strokeColor('#CBD5E1').lineWidth(0.8).stroke();

        doc.fillColor('#334155').fontSize(9);

        // Row 1
        doc.font('Helvetica-Bold').text('Full Name:', startX + 10, currentY + 8);
        doc.font('Helvetica').text(`${data.surname.toUpperCase()}, ${data.given_names}`, startX + 85, currentY + 8);

        doc.font('Helvetica-Bold').text('Date of Birth:', startX + 260, currentY + 8);
        doc.font('Helvetica').text(new Date(data.date_of_birth).toISOString().split('T')[0], startX + 340, currentY + 8);

        // Row 2
        doc.font('Helvetica-Bold').text('Nationality:', startX + 10, currentY + 26);
        doc.font('Helvetica').text(data.nationality, startX + 85, currentY + 26);

        doc.font('Helvetica-Bold').text('Gender:', startX + 260, currentY + 26);
        doc.font('Helvetica').text(data.gender, startX + 340, currentY + 26);

        // Row 3
        doc.font('Helvetica-Bold').text('Passport No:', startX + 10, currentY + 44);
        doc.font('Helvetica').text(data.passport_number || 'NOT PRODUCED', startX + 85, currentY + 44);

        doc.font('Helvetica-Bold').text('Status:', startX + 260, currentY + 44);
        doc.font('Helvetica').text(data.current_immigration_status, startX + 340, currentY + 44);

        // --- SECTION 2: RISK ASSESSMENT & ALERTS ---
        currentY += 76;

        doc.rect(startX, currentY, pageWidth, 18).fill('#8B0000');
        doc.fillColor('#FFFFFF').fontSize(9).font('Helvetica-Bold').text('2. RISK ASSESSMENT & OPERATIONAL ALERTS', startX + 8, currentY + 4);

        currentY += 20;
        doc.rect(startX, currentY, pageWidth, 58).strokeColor('#CBD5E1').lineWidth(0.8).stroke();

        doc.rect(startX + 10, currentY + 8, 220, 20).fill('#FEF2F2');
        doc.fillColor('#991B1B').font('Helvetica-Bold').text(`OVERALL CALCULATED RISK: ${data.overall_calculated_risk}`, startX + 16, currentY + 14);

        doc.fillColor('#334155').fontSize(9);
        doc.font('Helvetica-Bold').text('Handcuffs Used:', startX + 260, currentY + 12);
        doc.font('Helvetica').text(data.handcuffs_used ? 'YES' : 'NO', startX + 380, currentY + 12);

        doc.font('Helvetica-Bold').text('Suicide Watch Required:', startX + 10, currentY + 36);
        doc.fillColor(data.suicide_risk_identified ? '#991B1B' : '#334155').font('Helvetica-Bold').text(data.suicide_risk_identified ? 'YES (MANDATORY)' : 'NO', startX + 135, currentY + 36);

        doc.fillColor('#334155');
        doc.font('Helvetica-Bold').text('Medical Required:', startX + 260, currentY + 36);
        doc.font('Helvetica').text(data.immediate_medical_required ? 'YES (IMMEDIATE)' : 'NO', startX + 380, currentY + 36);

        // --- SECTION 3: CUSTODY & ALLOCATION ---
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

        // --- FOOTER & QR CODE (DYNAMIC FLOW POSITIONING) ---
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
// UNHANDLED EXCEPTION HARDENING
// ==========================================
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception thrown:', err);
});

// ==========================================
// START SERVER
// ==========================================
app.listen(port, () => {
    console.log(`=================================================`);
    console.log(`🚀 BIC API Server running on http://localhost:${port}`);
    console.log(`=================================================`);
});