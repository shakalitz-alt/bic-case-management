require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');

const app = express();
const port = process.env.PORT || 3005;

// PostgreSQL Connection Pool Setup
const pool = new Pool({
    user: 'bic_app_user',
    host: 'localhost',
    database: 'bic_casemanagement',
    password: 'Secure_BIC_Pass_2026!',
    port: 5432,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Handle background pool errors to prevent process exit
pool.on('error', (err, client) => {
    console.error('Unexpected error on idle PostgreSQL client:', err.message);
});

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// 1. Health Check Endpoint
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
        console.error('Database query error on health check:', err.message);
        res.status(500).json({
            status: 'DOWN',
            database: 'DISCONNECTED',
            error: err.message
        });
    }
});

// 2. Admissions Queue Endpoint
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
        res.json({
            status: 'SUCCESS',
            count: result.rowCount,
            data: result.rows
        });
    } catch (err) {
        console.error('Error fetching queue:', err.message);
        res.status(500).json({ status: 'ERROR', message: err.message });
    }
});

// Global unhandled error handlers to prevent PM2 crash loops
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (err) => {
    console.error('Uncaught Exception thrown:', err);
});

// Start Express Server
const server = app.listen(port, () => {
    console.log(`=================================================`);
    console.log(`🚀 BIC API Server running on http://localhost:${port}`);
    console.log(`=================================================`);
});