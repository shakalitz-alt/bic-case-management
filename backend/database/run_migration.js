const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'bic_casemanagement',
    password: process.env.DB_PASSWORD || '5Ann3hy3t!!2026',
    port: process.env.DB_PORT || 5432,
});

async function runMigration() {
    try {
        const sqlPath = path.join(__dirname, 'phase2_schema.sql');
        const sql = fs.readFileSync(sqlPath, 'utf8');
        console.log('Running Phase 2 Schema Migration...');
        await pool.query(sql);
        console.log('✅ Phase 2 Tables Created Successfully!');
    } catch (err) {
        console.error('❌ Migration Error:', err.message);
    } finally {
        await pool.end();
    }
}

runMigration();