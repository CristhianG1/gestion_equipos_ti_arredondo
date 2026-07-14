const express = require('express');
const mysql = require('mysql2');
require('dotenv').config();
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para parsear JSON y servir archivos estáticos
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Pool de conexión a MySQL
const pool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'root',
    database: process.env.DB_NAME || 'soportefisi',
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 15,
    queueLimit: 0
});

const promisePool = pool.promise();

// Helper para ejecutar consultas bajo el contexto del técnico actual para auditorías
async function runWithSession(tecnicoId, callback) {
    const connection = await pool.promise().getConnection();
    try {
        if (tecnicoId) {
            await connection.query('SET @current_tecnico_id = ?', [tecnicoId]);
        } else {
            await connection.query('SET @current_tecnico_id = NULL');
        }
        return await callback(connection);
    } finally {
        connection.release();
    }
}

// =============================================================================
// RUTAS DE AUTENTICACIÓN SIMULADA Y USUARIOS COMUNES
// =============================================================================

// Listar usuarios comunes activos
app.get('/api/roles/usuarios', async (req, res) => {
    try {
        const [rows] = await promisePool.query(
            'SELECT id_usuario, nombres, apellidos, cargo FROM usuario WHERE estado = true'
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al conectar con la Base de Datos.' });
    }
});

// Listar personal técnico activo
app.get('/api/roles/tecnicos', async (req, res) => {
    try {
        const [rows] = await promisePool.query(
            'SELECT id_tecnico, nombres, apellidos, rango FROM tecnico WHERE estado = true'
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al conectar con la Base de Datos.' });
    }
});

// Listar todos los equipos activos
app.get('/api/equipos', async (req, res) => {
    try {
        const [rows] = await promisePool.query(
            'SELECT id_equipo, codigo_inventario, tipo, marca, estado FROM equipo WHERE estado != "baja"'
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al listar equipos de la base de datos.' });
    }
});

// Listar catálogo de software
app.get('/api/inventario/software/catalogo', async (req, res) => {
    try {
        const [rows] = await promisePool.query(
            'SELECT id_software, nombre FROM software ORDER BY nombre ASC'
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener catálogo de software.' });
    }
});

// Obtener métricas rápidas de un técnico (tickets asignados, pendientes, resueltos)
app.get('/api/tecnicos/metricas-individuales/:id_tecnico', async (req, res) => {
    const { id_tecnico } = req.params;
    try {
        const [rows] = await promisePool.query(
            'SELECT fn_tickets_asignados(?) AS asignados, fn_total_incidentes_pendientes(?) AS pendientes, fn_tickets_resueltos(?) AS resueltos',
            [id_tecnico, id_tecnico, id_tecnico]
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener métricas del técnico.' });
    }
});

// =============================================================================
// RUTAS DE EMPLEADO
// =============================================================================

// Obtener lista de los equipos del área del usuario (Para el formulario de incidencias)
app.get('/api/equipos/usuario/:id_usuario', async (req, res) => {
    const { id_usuario } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_revisar_equipos_por_area_usuario(?)',
            [id_usuario]
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener equipos del área del usuario.' });
    }
});

// Registrar Incidencia (Llama al SP: sp_registrar_incidencia_usuario)
app.post('/api/empleado/incidencia', async (req, res) => {
    const { id_usuario, id_equipo, prioridad, descripcion } = req.body;
    
    if (!id_usuario || !id_equipo || !prioridad || !descripcion) {
        return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
    }

    try {
        await promisePool.query(
            'CALL sp_registrar_incidencia_usuario(?, ?, ?, ?)', 
            [id_usuario, id_equipo, prioridad, descripcion]
        );
        res.json({ success: true, message: 'Incidencia registrada con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al ejecutar sp_registrar_incidencia_usuario.' });
    }
});

// Listar incidencias reportadas por un usuario
app.get('/api/empleado/incidencias/:id_usuario', async (req, res) => {
    const { id_usuario } = req.params;
    try {
        const [rows] = await promisePool.query(
            'SELECT id_incidencia, id_equipo, descripcion, estado FROM vw_revision_incidencias_is_usuario WHERE id_usuario_reporta = ?',
            [id_usuario]
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al consultar vw_revision_incidencias_is_usuario.' });
    }
});

// Ver estado de incidencia (Llama al SP: sp_revisar_incidencia_usuario)
app.get('/api/empleado/incidencias/detalle/:id_incidencia', async (req, res) => {
    const { id_incidencia } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_revisar_incidencia_usuario(?)',
            [id_incidencia]
        );
        res.json(rows[0][0] || null);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al ejecutar sp_revisar_incidencia_usuario.' });
    }
});

// Ver seguimiento de incidencia (Llama al SP: sp_ver_seguimiento_incidencia)
app.get('/api/empleado/incidencias/seguimiento/:id_incidencia', async (req, res) => {
    const { id_incidencia } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_seguimiento_incidencia(?)',
            [id_incidencia]
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al ejecutar sp_ver_seguimiento_incidencia.' });
    }
});

// =============================================================================
// RUTAS PARA JEFES (SOLICITUDES)
// =============================================================================

// Crear Solicitud (Llama al SP: sp_crear_solicitud_jefe)
app.post('/api/jefe/solicitud', async (req, res) => {
    const { id_usuario, tipo, descripcion } = req.body;

    if (!id_usuario || !tipo || !descripcion) {
        return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
    }

    try {
        await promisePool.query(
            'CALL sp_crear_solicitud_jefe(?, ?, ?)',
            [id_usuario, tipo, descripcion]
        );
        res.json({ success: true, message: 'Solicitud creada con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al ejecutar sp_crear_solicitud_jefe.' });
    }
});

// Listar solicitudes de un jefe
app.get('/api/jefe/solicitudes/:id_usuario', async (req, res) => {
    const { id_usuario } = req.params;
    try {
        const [rows] = await promisePool.query(
            'SELECT id_solicitud, tipo, descripcion, estado, fecha_solicitud FROM solicitud WHERE id_usuario_solicita = ?',
            [id_usuario]
        );
        res.json(rows);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al listar solicitudes del jefe.' });
    }
});

// Ver estado de solicitud (Llama al SP: sp_ver_estado_solicitud)
app.get('/api/jefe/solicitudes/detalle/:id_solicitud', async (req, res) => {
    const { id_solicitud } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_estado_solicitud(?)',
            [id_solicitud]
        );
        res.json(rows[0][0] || null);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al ejecutar sp_ver_estado_solicitud.' });
    }
});

// =============================================================================
// RUTAS PARA SOPORTE (PRACTICANTE Y TÉCNICO) - INCIDENCIAS Y SEGUIMIENTOS
// =============================================================================

// Listar todas las incidencias (Practicante/Técnico ve todo; Empleado/Jefe ve lo suyo)
app.get('/api/soporte/incidencias/:id_sesion', async (req, res) => {
    const { id_sesion } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_incidencias(?)',
            [id_sesion]
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener lista de incidencias.' });
    }
});

// Ver detalle de incidencia para soporte
app.get('/api/soporte/incidencias/detalle/:id_incidencia', async (req, res) => {
    const { id_incidencia } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_detalle_incidencia(?)',
            [id_incidencia]
        );
        res.json(rows[0][0] || null);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener detalle de la incidencia.' });
    }
});

// Registrar seguimiento de incidencia (Practicante)
app.post('/api/soporte/seguimiento/practicante', async (req, res) => {
    const { id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, id_componente_cambiado, nuevo_estado } = req.body;
    try {
        await runWithSession(id_tecnico, async (connection) => {
            await connection.query(
                'CALL sp_registrar_seguimiento_incidencia(?, ?, ?, ?, ?, ?, ?)',
                [id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, id_componente_cambiado || null, nuevo_estado || null]
            );
        });
        res.json({ success: true, message: 'Seguimiento registrado con éxito por el practicante.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar seguimiento de practicante.' });
    }
});

// Registrar seguimiento de incidencia (Técnico)
app.post('/api/soporte/seguimiento/tecnico', async (req, res) => {
    const { id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, nuevo_estado } = req.body;
    try {
        await runWithSession(id_tecnico, async (connection) => {
            await connection.query(
                'CALL sp_registrar_seguimiento_tecnico(?, ?, ?, ?, ?, ?)',
                [id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, nuevo_estado || null]
            );
        });
        res.json({ success: true, message: 'Seguimiento registrado con éxito por el técnico.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar seguimiento de técnico.' });
    }
});

// Asignar personal técnico a una incidencia (Técnico y Admin)
app.post('/api/soporte/incidencia/asignar', async (req, res) => {
    const { id_incidencia, id_tecnico_asignador, id_tecnico_asignado } = req.body;
    try {
        await runWithSession(id_tecnico_asignador, async (connection) => {
            await connection.query(
                'CALL sp_asignar_personal_incidencia(?, ?, ?)',
                [id_incidencia, id_tecnico_asignador, id_tecnico_asignado]
            );
        });
        res.json({ success: true, message: 'Técnico asignado a la incidencia con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al asignar técnico.' });
    }
});

// Asignar componente a PC de escritorio (Técnico y Administrador)
app.post('/api/soporte/componentes/asignar-pc', async (req, res) => {
    const { id_tecnico_sesion, id_componente, id_equipo } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_asignar_componente_pc_escritorio(?, ?, ?)',
                [id_tecnico_sesion, id_componente, id_equipo]
            );
        });
        res.json({ success: true, message: 'Componente asignado al equipo PC de escritorio con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al asignar componente al equipo.' });
    }
});

// Registrar incidencia por parte de soporte (Técnico)
app.post('/api/soporte/incidencia/tecnico', async (req, res) => {
    const { id_tecnico, id_equipo, prioridad, descripcion } = req.body;
    try {
        await runWithSession(id_tecnico, async (connection) => {
            await connection.query(
                'CALL sp_registrar_incidencia_tecnico(?, ?, ?, ?)',
                [id_tecnico, id_equipo, prioridad, descripcion]
            );
        });
        res.json({ success: true, message: 'Incidencia técnica reportada correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar incidencia técnica.' });
    }
});

// Ver listado de todas las solicitudes de Jefes (Técnico y Admin)
app.get('/api/soporte/solicitudes', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_ver_solicitudes()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener solicitudes.' });
    }
});

// Ver detalle de una solicitud para soporte (Técnico y Admin)
app.get('/api/soporte/solicitudes/detalle/:id_solicitud', async (req, res) => {
    const { id_solicitud } = req.params;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_detalle_solicitud(?)',
            [id_solicitud]
        );
        res.json(rows[0][0] || null);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener el detalle de la solicitud.' });
    }
});

// Ver todos los componentes (Común para Practicante, Técnico y Admin)
app.get('/api/componentes/todos', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_ver_todos_componentes()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al consultar componentes del inventario.' });
    }
});

// =============================================================================
// RUTAS DE INVENTARIO (TÉCNICO) - REGISTRO DE EQUIPOS Y COMPONENTES
// =============================================================================

// Registrar Equipos en lote (Técnico)
app.post('/api/inventario/equipo', async (req, res) => {
    const { codigo_inventario, tipo, tipo_origen, marca, estado, cantidad, id_ambiente, id_usuario, id_tecnico_sesion } = req.body;
    try {
        let insertedId = null;
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_registrar_equipo(?, ?, ?, ?, ?, ?, ?, ?)',
                [codigo_inventario, tipo, tipo_origen, marca || null, estado, cantidad, id_ambiente, id_usuario || null]
            );
            
            // Obtener el ID del último equipo insertado para enlazar componentes de inmediato en la UI
            const [lastEq] = await connection.query(
                'SELECT id_equipo FROM equipo WHERE codigo_inventario = ?',
                [codigo_inventario]
            );
            if (lastEq.length > 0) {
                insertedId = lastEq[0].id_equipo;
            }
        });
        res.json({ success: true, message: 'Equipos registrados con éxito.', last_inserted_id: insertedId });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar equipos.' });
    }
});

// Registrar Componentes de Laptop
app.post('/api/inventario/componentes/laptop', async (req, res) => {
    const { id_equipo, modelo_laptop, codigo_serie_base, marca_procesador, modelo_procesador, tipo_ram, capacidad_ram, tipo_almacenamiento, capacidad_almacenamiento, tipo_graficos, modelo_grafica, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_registrar_componentes_laptop(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [id_equipo, modelo_laptop, codigo_serie_base || null, marca_procesador, modelo_procesador, tipo_ram, capacidad_ram, tipo_almacenamiento, capacidad_almacenamiento, tipo_graficos, modelo_grafica || null]
            );
        });
        res.json({ success: true, message: 'Componentes de Laptop registrados correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar componentes de laptop.' });
    }
});

// Registrar Componentes de PC
app.post('/api/inventario/componentes/pc', async (req, res) => {
    const {
        id_equipo, marca_procesador, modelo_procesador, marca_ram, capacidad_ram, tipo_ram,
        marca_almacenamiento, modelo_almacenamiento, tipo_disco, capacidad_almacenamiento,
        marca_placa, modelo_placa, socket_placa, tamano_placa, marca_fuente, modelo_fuente,
        potencia_fuente, certificacion_fuente, marca_grafica, modelo_gpu, vram_gpu, id_tecnico_sesion
    } = req.body;

    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_registrar_componentes_pc(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    id_equipo, marca_procesador, modelo_procesador, marca_ram, capacidad_ram, tipo_ram,
                    marca_almacenamiento, modelo_almacenamiento, tipo_disco, capacidad_almacenamiento,
                    marca_placa, modelo_placa, socket_placa, tamano_placa, marca_fuente, modelo_fuente,
                    potencia_fuente, certificacion_fuente || null, marca_grafica || null, modelo_gpu || null, vram_gpu || null
                ]
            );
        });
        res.json({ success: true, message: 'Componentes de PC de escritorio registrados correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar componentes de PC.' });
    }
});

// Registrar software en catálogo (Técnico)
app.post('/api/inventario/software', async (req, res) => {
    const { nombre, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query('CALL sp_registrar_software(?)', [nombre]);
        });
        res.json({ success: true, message: 'Software registrado en catálogo correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar software.' });
    }
});

// Registrar instalación de software (Técnico)
app.post('/api/inventario/software/instalar', async (req, res) => {
    const { id_equipo, id_software, tipo_licencia, clave_licencia, fecha_instalacion, fecha_expiracion, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_registrar_instalacion_software(?, ?, ?, ?, ?, ?)',
                [id_equipo, id_software, tipo_licencia, clave_licencia || null, fecha_instalacion, fecha_expiracion || null]
            );
        });
        res.json({ success: true, message: 'Instalación de software registrada correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar instalación.' });
    }
});

// Ver auditoría de software instalado (Técnico)
app.get('/api/inventario/software/instalado', async (req, res) => {
    const { codigo_inventario, nombre_software } = req.query;
    try {
        const [rows] = await promisePool.query(
            'CALL sp_ver_software_instalado_tecnico(?, ?)',
            [codigo_inventario || null, nombre_software || null]
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al consultar software instalado.' });
    }
});

// Editar software instalado (Técnico)
app.put('/api/inventario/software/instalado', async (req, res) => {
    const { id_equipo, id_software, tipo_licencia, clave_licencia, fecha_instalacion, fecha_expiracion, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_editar_software_instalado(?, ?, ?, ?, ?, ?)',
                [id_equipo, id_software, tipo_licencia, clave_licencia || null, fecha_instalacion, fecha_expiracion || null]
            );
        });
        res.json({ success: true, message: 'Registro de instalación actualizado.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al editar instalación de software.' });
    }
});

// =============================================================================
// RUTAS DE ADMINISTRACIÓN (ADMINISTRADOR)
// =============================================================================

// Obtener KPIs de Administración (Llama a funciones UDF del administrador)
app.get('/api/admin/kpis', async (req, res) => {
    try {
        const [rows] = await promisePool.query(
            'SELECT fn_total_equipos_activos() AS equipos_activos, fn_total_incidencias_activas() AS incidencias_activas, fn_total_personal_tecnico() AS personal_tecnico, fn_total_solicitudes() AS solicitudes_pendientes'
        );
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al consultar KPIs administrativos.' });
    }
});

// Obtener últimos 5 incidentes globales
app.get('/api/admin/ultimos-incidentes', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ultimos_5_incidentes_globales()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener últimos incidentes globales.' });
    }
});

// Procesar (Aceptar o Rechazar) solicitudes
app.post('/api/admin/procesar-solicitud', async (req, res) => {
    const { id_solicitud, nuevo_estado, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_procesar_solicitud(?, ?)',
                [id_solicitud, nuevo_estado]
            );
        });
        res.json({ success: true, message: `Solicitud marcada como ${nuevo_estado} con éxito.` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al procesar solicitud.' });
    }
});

// Ver todos los usuarios
app.get('/api/admin/usuarios', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ver_usuarios()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener listado de usuarios.' });
    }
});

// Registrar nuevo usuario
app.post('/api/admin/usuarios', async (req, res) => {
    const { id_area, cargo, nombres, apellidos, correo, telefono, contrasena, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_registrar_usuario(?, ?, ?, ?, ?, ?, ?)',
                [id_area, cargo, nombres, apellidos, correo, telefono || null, contrasena]
            );
        });
        res.json({ success: true, message: 'Usuario registrado correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar usuario.' });
    }
});

// Editar usuario
app.put('/api/admin/usuarios/:id_usuario', async (req, res) => {
    const { id_usuario } = req.params;
    const { id_area, cargo, nombres, apellidos, correo, telefono, estado, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_editar_usuario(?, ?, ?, ?, ?, ?, ?, ?)',
                [id_usuario, id_area, cargo, nombres, apellidos, correo, telefono || null, estado]
            );
        });
        res.json({ success: true, message: 'Usuario editado con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al editar usuario.' });
    }
});

// Eliminar usuario (baja lógica)
app.delete('/api/admin/usuarios/:id_usuario', async (req, res) => {
    const { id_usuario } = req.params;
    const { id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query('CALL sp_admin_eliminar_usuario(?)', [id_usuario]);
        });
        res.json({ success: true, message: 'Usuario dado de baja (inactivo) correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al dar de baja usuario.' });
    }
});

// Ver todos los técnicos
app.get('/api/admin/tecnicos', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ver_tecnicos()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener listado de técnicos.' });
    }
});

// Registrar nuevo técnico
app.post('/api/admin/tecnicos', async (req, res) => {
    const { rango, nombres, apellidos, correo, telefono, contrasena, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_registrar_tecnico(?, ?, ?, ?, ?, ?)',
                [rango, nombres, apellidos, correo, telefono || null, contrasena]
            );
        });
        res.json({ success: true, message: 'Personal técnico registrado correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar técnico.' });
    }
});

// Editar técnico
app.put('/api/admin/tecnicos/:id_tecnico', async (req, res) => {
    const { id_tecnico } = req.params;
    const { rango, nombres, apellidos, correo, telefono, estado, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_editar_tecnico(?, ?, ?, ?, ?, ?, ?)',
                [id_tecnico, rango, nombres, apellidos, correo, telefono || null, estado]
            );
        });
        res.json({ success: true, message: 'Técnico editado con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al editar técnico.' });
    }
});

// Eliminar técnico (baja lógica)
app.delete('/api/admin/tecnicos/:id_tecnico', async (req, res) => {
    const { id_tecnico } = req.params;
    const { id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query('CALL sp_admin_eliminar_tecnico(?)', [id_tecnico]);
        });
        res.json({ success: true, message: 'Técnico dado de baja (inactivo) correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al dar de baja técnico.' });
    }
});

// Ver todas las áreas (ambientes)
app.get('/api/admin/areas', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ver_areas()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener áreas.' });
    }
});

// Registrar nueva área
app.post('/api/admin/areas', async (req, res) => {
    const { numero, nombre, pabellon, piso, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_registrar_area(?, ?, ?, ?)',
                [numero, nombre, pabellon, piso]
            );
        });
        res.json({ success: true, message: 'Ambiente/Área registrado correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar área.' });
    }
});

// Eliminar área (ambiente)
app.delete('/api/admin/areas/:id_area', async (req, res) => {
    const { id_area } = req.params;
    const { id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query('CALL sp_admin_eliminar_area(?)', [id_area]);
        });
        res.json({ success: true, message: 'Área eliminada correctamente.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al eliminar área. Podría tener dependencias activas.' });
    }
});

// Registrar Componente Individual (Administración global)
app.post('/api/admin/componentes', async (req, res) => {
    const { id_equipo, id_ambiente, estado_componente, tipo_componente, marca, modelo, capacidad_o_vram, tipo_detalle, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_registrar_componente(?, ?, ?, ?, ?, ?, ?, ?)',
                [id_equipo || null, id_ambiente || null, estado_componente, tipo_componente, marca, modelo, capacidad_o_vram || null, tipo_detalle || null]
            );
        });
        res.json({ success: true, message: 'Componente registrado correctamente en inventario.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al registrar componente administrativo.' });
    }
});

// Editar Componente Individual
app.put('/api/admin/componentes/:id_componente', async (req, res) => {
    const { id_componente } = req.params;
    const { id_equipo, id_ambiente, estado_componente, tipo_componente, marca, modelo, capacidad_o_vram, tipo_detalle, id_tecnico_sesion } = req.body;
    try {
        await runWithSession(id_tecnico_sesion, async (connection) => {
            await connection.query(
                'CALL sp_admin_editar_componente(?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [id_componente, id_equipo || null, id_ambiente || null, estado_componente, tipo_componente, marca, modelo, capacidad_o_vram || null, tipo_detalle || null]
            );
        });
        res.json({ success: true, message: 'Componente editado con éxito.' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: error.sqlMessage || 'Error al editar componente administrativo.' });
    }
});

// Ver logs de auditoría
app.get('/api/admin/auditoria', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ver_auditoria()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener auditorías.' });
    }
});

// Ver métricas globales de rendimiento de técnicos
app.get('/api/admin/metricas-tecnicos', async (req, res) => {
    try {
        const [rows] = await promisePool.query('CALL sp_admin_ver_metricas_tecnicos()');
        res.json(rows[0]);
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Error al obtener métricas de técnicos.' });
    }
});

// Ruta comodín para redirigir cualquier otra petición a index.html (SPA fallback)
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`Servidor de Soporte TI corriendo en http://localhost:${PORT}`);
});
