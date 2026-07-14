-- =============================================================================
-- TRIGGERS COMPLETOS - Sistema de Soporte FISI (soportefisi)
-- Archivo de Disparadores para Auditoría e Integridad de Datos
-- =============================================================================

USE `soportefisi`;

-- -----------------------------------------------------------------------------
-- Eliminación de disparadores previos para evitar duplicados
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `tr_auditoria_equipo_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_equipo_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_equipo_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_componente_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_componente_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_componente_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_incidencia_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_incidencia_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_seguimiento_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_seguimiento_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_seguimiento_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_software_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_software_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_software_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_tecnico_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_tecnico_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_tecnico_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_usuario_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_usuario_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_usuario_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_solicitud_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_solicitud_delete`;
DROP TRIGGER IF EXISTS `tr_auditoria_ambiente_insert`;
DROP TRIGGER IF EXISTS `tr_auditoria_ambiente_update`;
DROP TRIGGER IF EXISTS `tr_auditoria_ambiente_delete`;
DROP TRIGGER IF EXISTS `tr_equipo_cambio_estado_componente`;
DROP TRIGGER IF EXISTS `tr_limitar_incidencias_practicante`;
DROP TRIGGER IF EXISTS `tr_cerrar_asignacion_anterior`;
DROP TRIGGER IF EXISTS `tr_desvincular_software_baja_equipo`;
DROP TRIGGER IF EXISTS `tr_incidencia_asignacion_valida`;

-- =============================================================================
-- 1. TRIGGERS DE AUDITORÍA (Monitoreo de Acciones del Personal Técnico)
-- =============================================================================

DELIMITER $$

-- Auditoría de Equipos (Inserción)
CREATE TRIGGER `tr_auditoria_equipo_insert`
AFTER INSERT ON `equipo`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'equipo',
            'INSERT',
            JSON_OBJECT(
                'id_equipo', NEW.id_equipo,
                'codigo_inventario', NEW.codigo_inventario,
                'tipo', NEW.tipo,
                'tipo_origen', NEW.tipo_origen,
                'marca', NEW.marca,
                'estado', NEW.estado,
                'id_usuario', NEW.id_usuario,
                'id_ambiente', NEW.id_ambiente
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Equipos (Modificación)
CREATE TRIGGER `tr_auditoria_equipo_update`
AFTER UPDATE ON `equipo`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'equipo',
            'UPDATE',
            JSON_OBJECT(
                'id_equipo', NEW.id_equipo,
                'codigo_inventario', NEW.codigo_inventario,
                'tipo', NEW.tipo,
                'tipo_origen', NEW.tipo_origen,
                'marca', NEW.marca,
                'estado', NEW.estado,
                'id_usuario', NEW.id_usuario,
                'id_ambiente', NEW.id_ambiente
            ),
            JSON_OBJECT(
                'id_equipo', OLD.id_equipo,
                'codigo_inventario', OLD.codigo_inventario,
                'tipo', OLD.tipo,
                'tipo_origen', OLD.tipo_origen,
                'marca', OLD.marca,
                'estado', OLD.estado,
                'id_usuario', OLD.id_usuario,
                'id_ambiente', OLD.id_ambiente
            )
        );
    END IF;
END $$

-- Auditoría de Componentes (Inserción)
CREATE TRIGGER `tr_auditoria_componente_insert`
AFTER INSERT ON `componente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'componente',
            'INSERT',
            JSON_OBJECT(
                'id_componente', NEW.id_componente,
                'id_equipo', NEW.id_equipo,
                'id_ambiente', NEW.id_ambiente,
                'estado_componente', NEW.estado_componente
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Componentes (Modificación)
CREATE TRIGGER `tr_auditoria_componente_update`
AFTER UPDATE ON `componente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'componente',
            'UPDATE',
            JSON_OBJECT(
                'id_componente', NEW.id_componente,
                'id_equipo', NEW.id_equipo,
                'id_ambiente', NEW.id_ambiente,
                'estado_componente', NEW.estado_componente
            ),
            JSON_OBJECT(
                'id_componente', OLD.id_componente,
                'id_equipo', OLD.id_equipo,
                'id_ambiente', OLD.id_ambiente,
                'estado_componente', OLD.estado_componente
            )
        );
    END IF;
END $$

-- Auditoría de Incidencias (Modificación de estados o técnicos asignados)
CREATE TRIGGER `tr_auditoria_incidencia_update`
AFTER UPDATE ON `incidencia`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'incidencia',
            'UPDATE',
            JSON_OBJECT(
                'id_incidencia', NEW.id_incidencia,
                'id_tecnico_recibe', NEW.id_tecnico_recibe,
                'estado', NEW.estado,
                'prioridad', NEW.prioridad
            ),
            JSON_OBJECT(
                'id_incidencia', OLD.id_incidencia,
                'id_tecnico_recibe', OLD.id_tecnico_recibe,
                'estado', OLD.estado,
                'prioridad', OLD.prioridad
            )
        );
    END IF;
END $$

-- Auditoría de Seguimiento de Incidencias (Avances técnicos)
CREATE TRIGGER `tr_auditoria_seguimiento_insert`
AFTER INSERT ON `seguimiento_incidencia`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'seguimiento_incidencia',
            'INSERT',
            JSON_OBJECT(
                'id_seguimiento', NEW.id_seguimiento,
                'id_incidencia', NEW.id_incidencia,
                'id_tecnico', NEW.id_tecnico,
                'diagnostico', NEW.diagnostico,
                'trabajo_realizado', NEW.trabajo_realizado,
                'horas_invertidas', NEW.horas_invertidas
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Software Instalado (Nuevas instalaciones)
CREATE TRIGGER `tr_auditoria_software_insert`
AFTER INSERT ON `software_instalado`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'software_instalado',
            'INSERT',
            JSON_OBJECT(
                'id_software_instalado', NEW.id_software_instalado,
                'id_equipo', NEW.id_equipo,
                'id_software', NEW.id_software,
                'tipo_licencia', NEW.tipo_licencia
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Software Instalado (Desinstalaciones)
CREATE TRIGGER `tr_auditoria_software_delete`
BEFORE DELETE ON `software_instalado`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'software_instalado',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_software_instalado', OLD.id_software_instalado,
                'id_equipo', OLD.id_equipo,
                'id_software', OLD.id_software,
                'tipo_licencia', OLD.tipo_licencia
            )
        );
    END IF;
END $$

-- Auditoría de Técnicos (Nuevos registros)
CREATE TRIGGER `tr_auditoria_tecnico_insert`
AFTER INSERT ON `tecnico`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'tecnico',
            'INSERT',
            JSON_OBJECT(
                'id_tecnico', NEW.id_tecnico,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'correo', NEW.correo,
                'rango', NEW.rango,
                'estado', NEW.estado
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Técnicos (Modificaciones de rol o estado)
CREATE TRIGGER `tr_auditoria_tecnico_update`
AFTER UPDATE ON `tecnico`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'tecnico',
            'UPDATE',
            JSON_OBJECT(
                'id_tecnico', NEW.id_tecnico,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'correo', NEW.correo,
                'rango', NEW.rango,
                'estado', NEW.estado
            ),
            JSON_OBJECT(
                'id_tecnico', OLD.id_tecnico,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'correo', OLD.correo,
                'rango', OLD.rango,
                'estado', OLD.estado
            )
        );
    END IF;
END $$

-- Auditoría de Usuarios (Nuevos registros)
CREATE TRIGGER `tr_auditoria_usuario_insert`
AFTER INSERT ON `usuario`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'usuario',
            'INSERT',
            JSON_OBJECT(
                'id_usuario', NEW.id_usuario,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'correo', NEW.correo,
                'cargo', NEW.cargo,
                'id_area', NEW.id_area
            ),
            NULL
        );
    END IF;
END $$

-- Auditoría de Usuarios (Modificaciones de datos o estado)
CREATE TRIGGER `tr_auditoria_usuario_update`
AFTER UPDATE ON `usuario`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'usuario',
            'UPDATE',
            JSON_OBJECT(
                'id_usuario', NEW.id_usuario,
                'nombres', NEW.nombres,
                'apellidos', NEW.apellidos,
                'correo', NEW.correo,
                'cargo', NEW.cargo,
                'id_area', NEW.id_area
            ),
            JSON_OBJECT(
                'id_usuario', OLD.id_usuario,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'correo', OLD.correo,
                'cargo', OLD.cargo,
                'id_area', OLD.id_area
            )
        );
    END IF;
END $$

-- Auditoría de Solicitudes (Aprobaciones / Rechazos)
CREATE TRIGGER `tr_auditoria_solicitud_update`
AFTER UPDATE ON `solicitud`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'solicitud',
            'UPDATE',
            JSON_OBJECT(
                'id_solicitud', NEW.id_solicitud,
                'estado', NEW.estado,
                'fecha_respuesta', NEW.fecha_respuesta
            ),
            JSON_OBJECT(
                'id_solicitud', OLD.id_solicitud,
                'estado', OLD.estado,
                'fecha_respuesta', OLD.fecha_respuesta
            )
        );
    END IF;
END $$

-- Auditoría de Ambientes (Inserción)
CREATE TRIGGER `tr_auditoria_ambiente_insert`
AFTER INSERT ON `ambiente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'ambiente',
            'INSERT',
            JSON_OBJECT(
                'id_ambiente', NEW.id_ambiente,
                'numero', NEW.numero,
                'pabellon', NEW.pabellon,
                'piso', NEW.piso
            ),
            NULL
        );
    END IF;
END $$

DELIMITER ;

-- =============================================================================
-- 2. TRIGGERS DE REGLAS DE NEGOCIO (Integridad y Automatización de Datos)
-- =============================================================================

DELIMITER $$

-- Regla 1: Mantenimiento automático de equipo si falla un componente crítico
CREATE TRIGGER `tr_equipo_cambio_estado_componente`
AFTER UPDATE ON `componente`
FOR EACH ROW
BEGIN
    IF NEW.id_equipo IS NOT NULL AND NEW.estado_componente IN ('mantenimiento', 'baja') AND OLD.estado_componente = 'operativo' THEN
        UPDATE equipo 
        SET estado = 'mantenimiento' 
        WHERE id_equipo = NEW.id_equipo;
    END IF;
END $$

-- Regla 2: Límite estricto de 4 incidencias activas asignadas a un practicante
CREATE TRIGGER `tr_limitar_incidencias_practicante`
BEFORE UPDATE ON `incidencia`
FOR EACH ROW
BEGIN
    DECLARE v_rango ENUM('practicante', 'tecnico', 'administrador_sistema');
    DECLARE v_count INT;
    
    IF NEW.id_tecnico_recibe IS NOT NULL AND (OLD.id_tecnico_recibe IS NULL OR OLD.id_tecnico_recibe <> NEW.id_tecnico_recibe) THEN
        SELECT rango INTO v_rango FROM tecnico WHERE id_tecnico = NEW.id_tecnico_recibe;
        
        IF v_rango = 'practicante' THEN
            SELECT COUNT(*) INTO v_count 
            FROM incidencia 
            WHERE id_tecnico_recibe = NEW.id_tecnico_recibe 
              AND estado IN ('pendiente', 'en_proceso');
                 
            IF v_count >= 4 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: El practicante ya posee 4 incidencias activas asignadas.';
            END IF;
        END IF;
    END IF;
END $$

-- Regla 3: Finalización automática de asignaciones históricas anteriores
CREATE TRIGGER `tr_cerrar_asignacion_anterior`
BEFORE INSERT ON `asignacion_historial`
FOR EACH ROW
BEGIN
    UPDATE asignacion_historial
    SET fecha_fin = NEW.fecha_inicio
    WHERE id_equipo = NEW.id_equipo AND fecha_fin IS NULL;
END $$

-- Regla 4: Liberación automática de licencias de software y desvinculación de componentes al dar de baja un equipo
CREATE TRIGGER `tr_desvincular_software_baja_equipo`
AFTER UPDATE ON `equipo`
FOR EACH ROW
BEGIN
    IF NEW.estado = 'baja' AND OLD.estado <> 'baja' THEN
        -- 1. Eliminar licencias de software instaladas en el equipo
        DELETE FROM `software_instalado` 
        WHERE `id_equipo` = NEW.id_equipo;

        -- 2. Desvincular componentes de hardware (poner id_equipo = NULL y marcarlos como almacenados en el mismo ambiente del equipo)
        UPDATE `componente`
        SET `id_equipo` = NULL,
            `id_ambiente` = NEW.id_ambiente,
            `estado_componente` = 'almacenado'
        WHERE `id_equipo` = NEW.id_equipo;
    END IF;
END $$

-- Auditoría de Equipos (Eliminación Física)
CREATE TRIGGER `tr_auditoria_equipo_delete`
BEFORE DELETE ON `equipo`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'equipo',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_equipo', OLD.id_equipo,
                'codigo_inventario', OLD.codigo_inventario,
                'tipo', OLD.tipo,
                'tipo_origen', OLD.tipo_origen,
                'marca', OLD.marca,
                'estado', OLD.estado
            )
        );
    END IF;
END $$

-- Auditoría de Componentes (Eliminación Física)
CREATE TRIGGER `tr_auditoria_componente_delete`
BEFORE DELETE ON `componente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'componente',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_componente', OLD.id_componente,
                'id_equipo', OLD.id_equipo,
                'id_ambiente', OLD.id_ambiente,
                'estado_componente', OLD.estado_componente
            )
        );
    END IF;
END $$

-- Auditoría de Incidencias (Eliminación Física)
CREATE TRIGGER `tr_auditoria_incidencia_delete`
BEFORE DELETE ON `incidencia`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'incidencia',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_incidencia', OLD.id_incidencia,
                'id_equipo', OLD.id_equipo,
                'id_usuario_reporta', OLD.id_usuario_reporta,
                'id_tecnico_recibe', OLD.id_tecnico_recibe,
                'estado', OLD.estado
            )
        );
    END IF;
END $$

-- Auditoría de Seguimiento de Incidencias (Eliminación Física)
CREATE TRIGGER `tr_auditoria_seguimiento_delete`
BEFORE DELETE ON `seguimiento_incidencia`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'seguimiento_incidencia',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_seguimiento', OLD.id_seguimiento,
                'id_incidencia', OLD.id_incidencia,
                'id_tecnico', OLD.id_tecnico,
                'diagnostico', OLD.diagnostico,
                'trabajo_realizado', OLD.trabajo_realizado
            )
        );
    END IF;
END $$

-- Auditoría de Técnicos (Eliminación Física)
CREATE TRIGGER `tr_auditoria_tecnico_delete`
BEFORE DELETE ON `tecnico`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'tecnico',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_tecnico', OLD.id_tecnico,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'correo', OLD.correo,
                'rango', OLD.rango
            )
        );
    END IF;
END $$

-- Auditoría de Usuarios (Eliminación Física)
CREATE TRIGGER `tr_auditoria_usuario_delete`
BEFORE DELETE ON `usuario`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'usuario',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_usuario', OLD.id_usuario,
                'nombres', OLD.nombres,
                'apellidos', OLD.apellidos,
                'correo', OLD.correo,
                'cargo', OLD.cargo
            )
        );
    END IF;
END $$

-- Auditoría de Solicitudes (Eliminación Física)
CREATE TRIGGER `tr_auditoria_solicitud_delete`
BEFORE DELETE ON `solicitud`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'solicitud',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_solicitud', OLD.id_solicitud,
                'id_usuario_solicita', OLD.id_usuario_solicita,
                'tipo', OLD.tipo,
                'estado', OLD.estado
            )
        );
    END IF;
END $$

-- Auditoría de Software Instalado (Modificación)
CREATE TRIGGER `tr_auditoria_software_update`
AFTER UPDATE ON `software_instalado`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'software_instalado',
            'UPDATE',
            JSON_OBJECT(
                'id_software_instalado', NEW.id_software_instalado,
                'id_equipo', NEW.id_equipo,
                'id_software', NEW.id_software,
                'tipo_licencia', NEW.tipo_licencia,
                'clave_licencia', NEW.clave_licencia,
                'fecha_instalacion', NEW.fecha_instalacion,
                'fecha_expiracion', NEW.fecha_expiracion
            ),
            JSON_OBJECT(
                'id_software_instalado', OLD.id_software_instalado,
                'id_equipo', OLD.id_equipo,
                'id_software', OLD.id_software,
                'tipo_licencia', OLD.tipo_licencia,
                'clave_licencia', OLD.clave_licencia,
                'fecha_instalacion', OLD.fecha_instalacion,
                'fecha_expiracion', OLD.fecha_expiracion
            )
        );
    END IF;
END $$

-- Auditoría de Seguimiento de Incidencias (Modificación)
CREATE TRIGGER `tr_auditoria_seguimiento_update`
AFTER UPDATE ON `seguimiento_incidencia`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'seguimiento_incidencia',
            'UPDATE',
            JSON_OBJECT(
                'id_seguimiento', NEW.id_seguimiento,
                'id_incidencia', NEW.id_incidencia,
                'id_tecnico', NEW.id_tecnico,
                'diagnostico', NEW.diagnostico,
                'trabajo_realizado', NEW.trabajo_realizado,
                'horas_invertidas', NEW.horas_invertidas
            ),
            JSON_OBJECT(
                'id_seguimiento', OLD.id_seguimiento,
                'id_incidencia', OLD.id_incidencia,
                'id_tecnico', OLD.id_tecnico,
                'diagnostico', OLD.diagnostico,
                'trabajo_realizado', OLD.trabajo_realizado,
                'horas_invertidas', OLD.horas_invertidas
            )
        );
    END IF;
END $$

-- Auditoría de Ambientes (Modificación)
CREATE TRIGGER `tr_auditoria_ambiente_update`
AFTER UPDATE ON `ambiente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'ambiente',
            'UPDATE',
            JSON_OBJECT(
                'id_ambiente', NEW.id_ambiente,
                'numero', NEW.numero,
                'nombre', NEW.nombre,
                'pabellon', NEW.pabellon,
                'piso', NEW.piso
            ),
            JSON_OBJECT(
                'id_ambiente', OLD.id_ambiente,
                'numero', OLD.numero,
                'nombre', OLD.nombre,
                'pabellon', OLD.pabellon,
                'piso', OLD.piso
            )
        );
    END IF;
END $$

-- Auditoría de Ambientes (Eliminación)
CREATE TRIGGER `tr_auditoria_ambiente_delete`
BEFORE DELETE ON `ambiente`
FOR EACH ROW
BEGIN
    IF @current_tecnico_id IS NOT NULL THEN
        INSERT INTO `auditoria_tecnico` (id_tecnico, tabla_afectada, permiso_realizado, valor_agregado, valor_anterior)
        VALUES (
            @current_tecnico_id,
            'ambiente',
            'DELETE',
            NULL,
            JSON_OBJECT(
                'id_ambiente', OLD.id_ambiente,
                'numero', OLD.numero,
                'nombre', OLD.nombre,
                'pabellon', OLD.pabellon,
                'piso', OLD.piso
            )
        );
    END IF;
END $$

-- Regla 5: Validar asignación de incidencias a técnicos activos e integridad de roles
CREATE TRIGGER `tr_incidencia_asignacion_valida`
BEFORE UPDATE ON `incidencia`
FOR EACH ROW
BEGIN
    DECLARE v_rango_asignado ENUM('practicante', 'tecnico', 'administrador_sistema');
    DECLARE v_rango_asignador ENUM('practicante', 'tecnico', 'administrador_sistema');

    -- A. Validar que el técnico a asignar exista y esté activo
    IF NEW.id_tecnico_recibe IS NOT NULL AND (OLD.id_tecnico_recibe IS NULL OR OLD.id_tecnico_recibe <> NEW.id_tecnico_recibe) THEN
        IF NOT EXISTS (SELECT 1 FROM `tecnico` WHERE `id_tecnico` = NEW.id_tecnico_recibe AND `estado` = TRUE) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El técnico asignado no existe o se encuentra inactivo.';
        END IF;
    END IF;

    -- B. Validar jerarquía de asignación de roles a nivel físico (cuando @current_tecnico_id esté configurado en la sesión)
    IF @current_tecnico_id IS NOT NULL AND NEW.id_tecnico_recibe IS NOT NULL AND (OLD.id_tecnico_recibe IS NULL OR OLD.id_tecnico_recibe <> NEW.id_tecnico_recibe) THEN
        SELECT `rango` INTO v_rango_asignador FROM `tecnico` WHERE `id_tecnico` = @current_tecnico_id;
        SELECT `rango` INTO v_rango_asignado FROM `tecnico` WHERE `id_tecnico` = NEW.id_tecnico_recibe;

        IF v_rango_asignador = 'practicante' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Permiso denegado. Un practicante no tiene privilegios para realizar asignaciones.';
        ELSEIF v_rango_asignador = 'tecnico' AND @current_tecnico_id <> NEW.id_tecnico_recibe AND v_rango_asignado <> 'practicante' THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Permiso denegado. Un técnico solo puede asignar incidencias a practicantes o a sí mismo.';
        END IF;
    END IF;
END $$

DELIMITER ;
