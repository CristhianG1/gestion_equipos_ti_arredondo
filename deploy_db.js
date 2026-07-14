const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config();

// Configuración de la base de datos
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'root',
    database: process.env.DB_NAME || 'soportefisi',
    port: process.env.DB_PORT || 3306
};

// Parser para separar sentencias SQL respetando DELIMITER
function splitSqlScript(content) {
    content = content.replace(/\r\n/g, '\n');
    const lines = content.split('\n');
    const queries = [];
    let currentQuery = '';
    let delimiter = ';';
    
    for (let line of lines) {
        let cleanLine = line;
        const commentIndex = line.indexOf('--');
        if (commentIndex !== -1) {
            const prefix = line.substring(0, commentIndex);
            const doubleQuotesCount = (prefix.match(/"/g) || []).length;
            const singleQuotesCount = (prefix.match(/'/g) || []).length;
            const backticksCount = (prefix.match(/`/g) || []).length;
            if (doubleQuotesCount % 2 === 0 && singleQuotesCount % 2 === 0 && backticksCount % 2 === 0) {
                cleanLine = prefix;
            }
        }
        const trimmedLine = cleanLine.trim();
        
        // Omitir líneas vacías o comentarios puros
        if (trimmedLine === '' || trimmedLine.startsWith('--') || trimmedLine.startsWith('#')) {
            continue;
        }
        
        // Cambiar delimitador
        if (trimmedLine.toUpperCase().startsWith('DELIMITER')) {
            const parts = trimmedLine.split(/\s+/);
            if (parts.length > 1) {
                delimiter = parts[1];
            }
            continue;
        }
        
        currentQuery += line + '\n';
        
        // Comprobar si la línea termina con el delimitador actual
        if (trimmedLine.endsWith(delimiter)) {
            let queryToPush = currentQuery.trim();
            if (queryToPush.endsWith(delimiter)) {
                queryToPush = queryToPush.slice(0, -delimiter.length);
            }
            if (queryToPush.trim() !== '') {
                queries.push(queryToPush.trim());
            }
            currentQuery = '';
        }
    }
    
    if (currentQuery.trim() !== '') {
        queries.push(currentQuery.trim());
    }
    
    return queries;
}

async function runDeploy() {
    console.log('🔌 Conectando a MySQL en:', dbConfig.host, 'puerto:', dbConfig.port);
    // Primero nos conectamos sin base de datos para recrearla de forma limpia
    const tempConnection = await mysql.createConnection({
        host: dbConfig.host,
        user: dbConfig.user,
        password: dbConfig.password,
        port: dbConfig.port
    });
    
    console.log('✅ Conexión inicial exitosa.');
    await tempConnection.query(`DROP DATABASE IF EXISTS \`${dbConfig.database}\``);
    await tempConnection.query(`CREATE DATABASE \`${dbConfig.database}\``);
    console.log(`📁 Base de datos "${dbConfig.database}" recreada limpia.`);
    await tempConnection.end();

    // Ahora nos conectamos a la base de datos específica
    const connection = await mysql.createConnection(dbConfig);
    
    // Lista de scripts a desplegar en orden
    const filesToDeploy = [
        { path: 'database/schema_and_data/setup_completo.sql' },
        { path: 'database/schema_and_data/data_prueba.sql' },
        { path: 'database/views.sql' },
        { path: 'database/usuario/sp_usuario.sql' },
        { path: 'database/usuario/sp_jefe.sql' },
        { path: 'database/tecnico/practicante.sql' },
        { path: 'database/tecnico/tecnico.sql' },
        { path: 'database/admin/administrador.sql' },
        { path: 'database/roles.sql' },
        { path: 'triggers/triggers.sql' }
    ];

    try {
        for (const fileObj of filesToDeploy) {
            const absolutePath = path.join(__dirname, fileObj.path);
            
            if (!fs.existsSync(absolutePath)) {
                console.log(`⚠️ Archivo no encontrado, omitiendo: ${fileObj.path}`);
                continue;
            }

            console.log(`🚀 Desplegando archivo: ${fileObj.path}...`);
            const content = fs.readFileSync(absolutePath, 'utf8');
            const queries = splitSqlScript(content);
            
            for (let i = 0; i < queries.length; i++) {
                const query = queries[i];
                try {
                    await connection.query(query);
                } catch (err) {
                    console.error(`❌ Error en query #${i+1} del archivo ${fileObj.path}:`);
                    console.error(`Query: ${query.substring(0, 150)}...`);
                    console.error(`Error: ${err.message}`);
                    throw err; // Detener flujo ante errores críticos de despliegue
                }
            }
            console.log(`   ✅ Completado con éxito: ${fileObj.path} (${queries.length} sentencias ejecutadas).`);
        }
        
        console.log('\n🎉 ¡Despliegue e importación de la Base de Datos finalizado con éxito!');
    } catch (err) {
        console.error('\n💥 El despliegue de la Base de Datos ha fallado.');
    } finally {
        await connection.end();
    }
}

runDeploy();
