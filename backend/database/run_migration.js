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
        const availableMigrations = new Set(['phase2_schema.sql', 'phase3_schema.sql', 'phase4_schema.sql']);
        const migrationFile = process.argv[2] || 'phase3_schema.sql';
        if (!availableMigrations.has(migrationFile)) {
            throw new Error(`Unknown migration '${migrationFile}'. Choose phase2_schema.sql, phase3_schema.sql, or phase4_schema.sql.`);
        }

        const sqlPath = path.join(__dirname, migrationFile);
        const sql = fs.readFileSync(sqlPath, 'utf8');
        console.log(`Running ${migrationFile}...`);
        await pool.query(sql);
        console.log(`✅ ${migrationFile} completed successfully.`);
    } catch (err) {
        console.error('❌ Migration Error:', err.message);
    } finally {
        await pool.end();
    }
}

runMigration();