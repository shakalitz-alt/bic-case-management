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

function getPgDumpPath() {
    const configuredPath = String(process.env.PG_DUMP_PATH || '').replace(/^"|"$/g, '');
    if (configuredPath && fs.existsSync(configuredPath) && fs.statSync(configuredPath).isFile()) {
        return configuredPath;
    }

    if (process.platform === 'win32') {
        const postgres18Path = path.join('C:\\Program Files', 'PostgreSQL', '18', 'bin', 'pg_dump.exe');
        if (fs.existsSync(postgres18Path) && fs.statSync(postgres18Path).isFile()) return postgres18Path;

        const programFilesDirs = [process.env.ProgramW6432, process.env.ProgramFiles, process.env['ProgramFiles(x86)']]
            .filter(Boolean);
        for (const baseDir of [...new Set(programFilesDirs)]) {
            for (const version of ['18', '17', '16', '15', '14', '13', '12', '11', '10']) {
                const candidate = path.join(baseDir, 'PostgreSQL', version, 'bin', 'pg_dump.exe');
                if (fs.existsSync(candidate) && fs.statSync(candidate).isFile()) return candidate;
            }
        }
    }

    return 'pg_dump';
}

function quoteSqlIdentifier(value) {
    return `"${String(value).replace(/"/g, '""')}"`;
}

function quoteSqlLiteral(value) {
    return `'${String(value).replace(/'/g, "''")}'`;
}

async function dumpDatabaseWithPool(backupPath, settings) {
    const { Pool } = require('pg');
    const pool = new Pool({
        host: settings.host,
        port: Number(settings.port),
        database: settings.database,
        user: settings.user,
        password: settings.password,
        max: 1,
        connectionTimeoutMillis: 10000
    });
    let client;
    try {
        client = await pool.connect();
        await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
        const tablesResult = await client.query(
            `SELECT table_schema, table_name
             FROM information_schema.tables
             WHERE table_type = 'BASE TABLE'
               AND table_schema NOT IN ('pg_catalog', 'information_schema')
             ORDER BY table_schema, table_name`
        );
        const sequencesResult = await client.query(
            `SELECT ns.nspname AS sequence_schema,
                    seq.relname AS sequence_name,
                    pg_sequence.seqstart AS start_value,
                    pg_sequence.seqincrement AS increment_by,
                    pg_sequence.seqmin AS min_value,
                    pg_sequence.seqmax AS max_value,
                    pg_sequence.seqcache AS cache_size,
                    pg_sequence.seqcycle AS cycle,
                    dependency.deptype
             FROM pg_class AS seq
             JOIN pg_namespace AS ns ON ns.oid = seq.relnamespace
             JOIN pg_sequence ON pg_sequence.seqrelid = seq.oid
             LEFT JOIN pg_depend AS dependency
               ON dependency.classid = 'pg_class'::regclass
              AND dependency.objid = seq.oid
              AND dependency.refclassid = 'pg_class'::regclass
              AND dependency.deptype IN ('a', 'i')
             WHERE seq.relkind = 'S'
               AND ns.nspname NOT IN ('pg_catalog', 'information_schema')
             ORDER BY ns.nspname, seq.relname`
        );

        let sql = '-- PostgreSQL SQL backup created by backup_db.js\nSET standard_conforming_strings = on;\nBEGIN;\n';
        for (const table of tablesResult.rows) {
            sql += `CREATE SCHEMA IF NOT EXISTS ${quoteSqlIdentifier(table.table_schema)};\n`;
        }
        for (const schemaName of new Set(sequencesResult.rows.map(sequence => sequence.sequence_schema))) {
            if (!tablesResult.rows.some(table => table.table_schema === schemaName)) {
                sql += `CREATE SCHEMA IF NOT EXISTS ${quoteSqlIdentifier(schemaName)};\n`;
            }
        }
        for (const sequence of sequencesResult.rows) {
            const qualifiedSequence = `${quoteSqlIdentifier(sequence.sequence_schema)}.${quoteSqlIdentifier(sequence.sequence_name)}`;
            if (sequence.deptype !== 'i') {
                sql += `CREATE SEQUENCE ${qualifiedSequence} INCREMENT BY ${sequence.increment_by} MINVALUE ${sequence.min_value} MAXVALUE ${sequence.max_value} START WITH ${sequence.start_value} CACHE ${sequence.cache_size} ${sequence.cycle ? 'CYCLE' : 'NO CYCLE'};\n`;
            }
        }

        const tableMetadata = [];
        for (const table of tablesResult.rows) {
            const qualifiedTable = `${quoteSqlIdentifier(table.table_schema)}.${quoteSqlIdentifier(table.table_name)}`;
            const columnsResult = await client.query(
                `SELECT attribute.attname AS column_name,
                        pg_catalog.format_type(attribute.atttypid, attribute.atttypmod) AS column_type,
                        attribute.attnotnull AS not_null,
                        attribute.attidentity AS identity_kind,
                        attribute.attgenerated AS generated_kind,
                        pg_catalog.pg_get_expr(default_value.adbin, default_value.adrelid) AS column_default
                 FROM pg_catalog.pg_attribute AS attribute
                 JOIN pg_catalog.pg_class AS relation ON relation.oid = attribute.attrelid
                 JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
                 LEFT JOIN pg_catalog.pg_attrdef AS default_value
                   ON default_value.adrelid = relation.oid AND default_value.adnum = attribute.attnum
                 WHERE namespace.nspname = $1
                   AND relation.relname = $2
                   AND attribute.attnum > 0
                   AND NOT attribute.attisdropped
                 ORDER BY attribute.attnum`,
                [table.table_schema, table.table_name]
            );
            const columns = columnsResult.rows;
            const createColumnDefinitions = columns.map(column => {
                let definition = `${quoteSqlIdentifier(column.column_name)} ${column.column_type}`;
                if (column.identity_kind === 'a') definition += ' GENERATED ALWAYS AS IDENTITY';
                else if (column.identity_kind === 'd') definition += ' GENERATED BY DEFAULT AS IDENTITY';
                else if (column.generated_kind === 's' && column.column_default) definition += ` GENERATED ALWAYS AS (${column.column_default}) STORED`;
                else if (column.column_default) definition += ` DEFAULT ${column.column_default}`;
                if (column.not_null) definition += ' NOT NULL';
                return definition;
            });
            const constraintResult = await client.query(
                `SELECT constraint_name, pg_catalog.pg_get_constraintdef(constraint_oid.oid) AS definition
                 FROM information_schema.table_constraints AS table_constraint
                 JOIN pg_catalog.pg_constraint AS constraint_oid
                   ON constraint_oid.conname = table_constraint.constraint_name
                  AND constraint_oid.conrelid = to_regclass(format('%I.%I', table_constraint.table_schema, table_constraint.table_name))
                 WHERE table_constraint.table_schema = $1 AND table_constraint.table_name = $2
                 ORDER BY table_constraint.constraint_name`,
                [table.table_schema, table.table_name]
            );
            const indexResult = await client.query(
                `SELECT index_relation.relname AS index_name, pg_catalog.pg_get_indexdef(index_relation.oid) AS definition
                 FROM pg_catalog.pg_index AS index_data
                 JOIN pg_catalog.pg_class AS index_relation ON index_relation.oid = index_data.indexrelid
                 WHERE index_data.indrelid = to_regclass(format('%I.%I', $1, $2))
                   AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint WHERE conindid = index_data.indexrelid)
                 ORDER BY index_relation.relname`,
                [table.table_schema, table.table_name]
            );

            sql += `CREATE TABLE ${qualifiedTable} (\n  ${createColumnDefinitions.join(',\n  ')}\n);\n`;
            tableMetadata.push({
                ...table,
                columns,
                constraints: constraintResult.rows,
                indexes: indexResult.rows
            });
        }

        await fs.promises.writeFile(backupPath, sql, 'utf8');
        for (const table of tableMetadata) {
            const qualifiedTable = `${quoteSqlIdentifier(table.table_schema)}.${quoteSqlIdentifier(table.table_name)}`;
            const dataColumns = table.columns.filter(column => column.generated_kind !== 's');
            if (!dataColumns.length) continue;
            const projectedColumns = dataColumns.map(column => `${quoteSqlIdentifier(column.column_name)}::text AS ${quoteSqlIdentifier(column.column_name)}`).join(', ');
            const countResult = await client.query(`SELECT COUNT(*)::bigint AS row_count FROM ${qualifiedTable}`);
            const rowCount = Number(countResult.rows[0].row_count);
            const identityOverride = dataColumns.some(column => column.identity_kind) ? ' OVERRIDING SYSTEM VALUE' : '';
            for (let offset = 0; offset < rowCount; offset += 500) {
                const dataResult = await client.query(
                    `SELECT ${projectedColumns} FROM ${qualifiedTable} LIMIT 500 OFFSET $1`,
                    [offset]
                );
                const inserts = dataResult.rows.map(row => {
                    const values = dataColumns.map(column => {
                        const value = row[column.column_name];
                        return value === null ? 'NULL' : quoteSqlLiteral(value);
                    });
                    return `INSERT INTO ${qualifiedTable} (${dataColumns.map(column => quoteSqlIdentifier(column.column_name)).join(', ')})${identityOverride} VALUES (${values.join(', ')});`;
                }).join('\n');
                await fs.promises.appendFile(backupPath, `${inserts}\n`, 'utf8');
            }
        }

        sql = '';
        for (const table of tableMetadata) {
            const qualifiedTable = `${quoteSqlIdentifier(table.table_schema)}.${quoteSqlIdentifier(table.table_name)}`;
            for (const constraint of table.constraints) {
                sql += `ALTER TABLE ${qualifiedTable} ADD CONSTRAINT ${quoteSqlIdentifier(constraint.constraint_name)} ${constraint.definition};\n`;
            }
            for (const index of table.indexes) sql += `${index.definition};\n`;
        }
        for (const sequence of sequencesResult.rows) {
            const qualifiedSequence = `${quoteSqlIdentifier(sequence.sequence_schema)}.${quoteSqlIdentifier(sequence.sequence_name)}`;
            const stateResult = await client.query(`SELECT last_value::text, is_called FROM ${qualifiedSequence}`);
            if (stateResult.rows.length && stateResult.rows[0].last_value !== null) {
                const sequenceRegclass = `${quoteSqlIdentifier(sequence.sequence_schema)}.${quoteSqlIdentifier(sequence.sequence_name)}`;
                sql += `SELECT pg_catalog.setval(${quoteSqlLiteral(sequenceRegclass)}::regclass, ${stateResult.rows[0].last_value}, ${stateResult.rows[0].is_called});\n`;
            }
        }
        sql += 'COMMIT;\n';
        await fs.promises.appendFile(backupPath, sql, 'utf8');
        await client.query('COMMIT');
    } catch (error) {
        try {
            if (client) await client.query('ROLLBACK');
        } catch (rollbackError) {}
        try {
            await fs.promises.unlink(backupPath);
        } catch (unlinkError) {}
        throw error;
    } finally {
        if (client) client.release();
        await pool.end();
    }
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
    const pgDumpPath = getPgDumpPath();
    const pgDumpExecutable = pgDumpPath === 'pg_dump' ? pgDumpPath : quoteShellArgument(pgDumpPath);
    const command = `${pgDumpExecutable} --format=plain --file=${quoteShellArgument(backupPath)}`;

    try {
        await new Promise((resolve, reject) => {
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
                    try {
                        if (fs.existsSync(backupPath)) fs.unlinkSync(backupPath);
                    } catch (unlinkError) {}
                    reject(new Error((stderr || error.message).trim()));
                    return;
                }
                resolve();
            });
        });
        if (!fs.existsSync(backupPath) || fs.statSync(backupPath).size === 0) {
            throw new Error('pg_dump completed without creating a non-empty backup file.');
        }
        return { filename, timestamp, path: backupPath, method: 'pg_dump' };
    } catch (pgDumpError) {
        console.warn(`pg_dump failed (${pgDumpError.message}); trying PostgreSQL pool SQL export.`);
        try {
            await dumpDatabaseWithPool(backupPath, settings);
            return { filename, timestamp, path: backupPath, method: 'pg' };
        } catch (fallbackError) {
            throw new Error(`pg_dump failed: ${pgDumpError.message}. Pool SQL fallback failed: ${fallbackError.message}`);
        }
    }
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