const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const backupDir = path.resolve(__dirname, '..', 'backups');
const retentionMs = 30 * 24 * 60 * 60 * 1000;

function quoteShellArgument(value) {
    const text = String(value);
    if (process.platform === 'win32') return `"${text.replace(/"/g, '\\"')}"`;
    return `'${text.replace(/'/g, `'\\''`)}'`;
}

function removeExpiredBackups(now = Date.now()) {
    const cutoff = now - retentionMs;
    for (const entry of fs.readdirSync(backupDir, { withFileTypes: true })) {
        if (!entry.isFile() || !['.sql', '.tar'].includes(path.extname(entry.name).toLowerCase())) continue;
        const filePath = path.join(backupDir, entry.name);
        if (fs.statSync(filePath).mtimeMs < cutoff) {
            fs.unlinkSync(filePath);
            console.log(`Removed expired backup: ${entry.name}`);
        }
    }
}

async function runBackup() {
    const settings = {
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASS || process.env.DB_PASSWORD
    };
    const settingNames = {
        host: 'DB_HOST',
        port: 'DB_PORT',
        database: 'DB_NAME',
        user: 'DB_USER',
        password: 'DB_PASS'
    };
    const missingSettings = Object.entries(settings)
        .filter(([, value]) => !value)
        .map(([name]) => settingNames[name]);
    if (missingSettings.length) {
        throw new Error(`Missing database settings: ${missingSettings.join(', ')}`);
    }
    if (!/^\d+$/.test(settings.port) || Number(settings.port) < 1 || Number(settings.port) > 65535) {
        throw new Error('DB_PORT must be a valid TCP port.');
    }

    fs.mkdirSync(backupDir, { recursive: true });
    removeExpiredBackups();

    const generatedAt = new Date();
    const timestamp = generatedAt.toISOString();
    const fileTimestamp = timestamp.replace(/[:.]/g, '-');
    const filename = `bic_casemanagement_${fileTimestamp}.sql`;
    const backupPath = path.join(backupDir, filename);
    const command = `pg_dump --format=plain --file=${quoteShellArgument(backupPath)}`;

    return new Promise((resolve, reject) => {
        exec(command, {
            env: {
                ...process.env,
                PGPASSWORD: settings.password,
                PGHOST: settings.host,
                PGPORT: settings.port,
                PGDATABASE: settings.database,
                PGUSER: settings.user
            },
            maxBuffer: 10 * 1024 * 1024
        }, (error, stdout, stderr) => {
            if (error) {
                if (fs.existsSync(backupPath)) fs.unlinkSync(backupPath);
                reject(new Error((stderr || error.message).trim()));
                return;
            }
            resolve({ filename, timestamp, path: backupPath });
        });
    });
}

module.exports = { runBackup };

if (require.main === module) {
    runBackup()
        .then(({ filename, timestamp }) => {
            console.log(`Database backup saved: ${filename} (${timestamp})`);
        })
        .catch(error => {
            console.error('Database backup failed:', error.message);
            process.exitCode = 1;
        });
}