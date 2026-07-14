-- =============================================================================
-- PROCEDIMIENTOS ALMACENADOS Y FUNCIONES - Rol Administrador del Sistema
-- Sistema de Soporte FISI (soportefisi)
-- =============================================================================

USE `soportefisi`;

-- -----------------------------------------------------------------------------
-- Eliminación de funciones y procedimientos previos
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `fn_total_equipos_activos`;
DROP FUNCTION IF EXISTS `fn_total_incidencias_activas`;
DROP FUNCTION IF EXISTS `fn_total_personal_tecnico`;
DROP FUNCTION IF EXISTS `fn_total_solicitudes`;

DROP PROCEDURE IF EXISTS `sp_admin_ultimos_5_incidentes_globales`;
DROP PROCEDURE IF EXISTS `sp_admin_procesar_solicitud`;
DROP PROCEDURE IF EXISTS `sp_admin_ver_usuarios`;
DROP PROCEDURE IF EXISTS `sp_admin_eliminar_usuario`;
DROP PROCEDURE IF EXISTS `sp_admin_editar_usuario`;
DROP PROCEDURE IF EXISTS `sp_admin_registrar_usuario`;
DROP PROCEDURE IF EXISTS `sp_admin_registrar_tecnico`;
DROP PROCEDURE IF EXISTS `sp_admin_ver_tecnicos`;
DROP PROCEDURE IF EXISTS `sp_admin_eliminar_tecnico`;
DROP PROCEDURE IF EXISTS `sp_admin_editar_tecnico`;
DROP PROCEDURE IF EXISTS `sp_admin_ver_areas`;
DROP PROCEDURE IF EXISTS `sp_admin_registrar_area`;
DROP PROCEDURE IF EXISTS `sp_admin_eliminar_area`;
DROP PROCEDURE IF EXISTS `sp_admin_registrar_componente`;
DROP PROCEDURE IF EXISTS `sp_admin_editar_componente`;
DROP PROCEDURE IF EXISTS `sp_admin_ver_auditoria`;
DROP PROCEDURE IF EXISTS `sp_admin_ver_metricas_tecnicos`;
DROP PROCEDURE IF EXISTS `sp_ver_todos_componentes`;

DELIMITER $$

-- =============================================================================
-- 1. FUNCIONES UDF
-- =============================================================================

-- Ver total de equipos activos
CREATE FUNCTION `fn_total_equipos_activos`() 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `equipo` 
    WHERE `estado` <> 'baja';
    RETURN v_count;
END$$

-- Ver total de incidencias activas (pendiente, en_proceso)
CREATE FUNCTION `fn_total_incidencias_activas`() 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `incidencia` 
    WHERE `estado` IN ('pendiente', 'en_proceso');
    RETURN v_count;
END$$

-- Ver total de personal técnico activo
CREATE FUNCTION `fn_total_personal_tecnico`() 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `tecnico` 
    WHERE `estado` = TRUE;
    RETURN v_count;
END$$

-- Ver total de solicitudes pendientes
CREATE FUNCTION `fn_total_solicitudes`() 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `solicitud` 
    WHERE `estado` = 'pendiente';
    RETURN v_count;
END$$

-- =============================================================================
-- 2. PROCEDIMIENTOS ALMACENADOS
-- =============================================================================

-- Ver últimos 5 incidentes globales
CREATE PROCEDURE `sp_admin_ultimos_5_incidentes_globales`()
BEGIN
    SELECT 
        CONCAT(u.`nombres`, ' ', u.`apellidos`) AS `usuario`,
        i.`prioridad`,
        i.`estado`,
        i.`fecha_creacion` AS `fecha`,
        COALESCE((SELECT s.`trabajo_realizado` FROM `seguimiento_incidencia` s WHERE s.`id_incidencia` = i.`id_incidencia` ORDER BY s.`fecha` DESC LIMIT 1), 'Sin seguimiento') AS `accion`
    FROM `incidencia` i
    INNER JOIN `usuario` u ON i.`id_usuario_reporta` = u.`id_usuario`
    ORDER BY i.`fecha_creacion` DESC
    LIMIT 5;
END$$

-- Aceptar o rechazar solicitudes
CREATE PROCEDURE `sp_admin_procesar_solicitud`(
    IN p_id_solicitud INT,
    IN p_nuevo_estado ENUM('aprobada', 'rechazada')
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `solicitud` WHERE `id_solicitud` = p_id_solicitud) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La solicitud especificada no existe.';
    END IF;

    UPDATE `solicitud`
    SET `estado` = p_nuevo_estado,
        `fecha_respuesta` = NOW()
    WHERE `id_solicitud` = p_id_solicitud;
END$$

-- Ver todos los usuarios (los inactivos se ordenan al final)
CREATE PROCEDURE `sp_admin_ver_usuarios`()
BEGIN
    SELECT 
        u.`id_usuario`,
        u.`nombres`,
        u.`apellidos`,
        u.`correo`,
        u.`telefono`,
        u.`id_area`,
        u.`cargo`,
        CONCAT(a.`pabellon`, ' - ', a.`numero`, ' (', a.`nombre`, ')') AS `ambiente_nombre`,
        u.`estado`
    FROM `usuario` u
    INNER JOIN `ambiente` a ON u.`id_area` = a.`id_ambiente`
    ORDER BY u.`estado` DESC, u.`apellidos` ASC, u.`nombres` ASC;
END$$

-- Eliminar usuario (cambiar a estado inactivo)
CREATE PROCEDURE `sp_admin_eliminar_usuario`(
    IN p_id_usuario INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `usuario` WHERE `id_usuario` = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El usuario especificado no existe.';
    END IF;

    UPDATE `usuario` SET `estado` = FALSE WHERE `id_usuario` = p_id_usuario;
END$$

-- Editar usuario
CREATE PROCEDURE `sp_admin_editar_usuario`(
    IN p_id_usuario INT,
    IN p_id_area INT,
    IN p_cargo ENUM('empleado', 'jefe'),
    IN p_nombres VARCHAR(255),
    IN p_apellidos VARCHAR(255),
    IN p_correo VARCHAR(255),
    IN p_telefono VARCHAR(255),
    IN p_estado BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `usuario` WHERE `id_usuario` = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El usuario especificado no existe.';
    END IF;

    -- Validar formato de correo
    IF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de correo electrónico inválido.';
    END IF;

    -- Validar teléfono (opcional)
    IF p_telefono IS NOT NULL AND p_telefono <> '' AND p_telefono NOT REGEXP '^[0-9]{7,15}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de teléfono inválido (debe tener entre 7 y 15 dígitos numéricos).';
    END IF;

    -- Validar ambiente/área
    IF NOT EXISTS (SELECT 1 FROM `ambiente` WHERE `id_ambiente` = p_id_area) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El ambiente especificado no existe.';
    END IF;

    UPDATE `usuario`
    SET `id_area` = p_id_area,
        `cargo` = p_cargo,
        `nombres` = p_nombres,
        `apellidos` = p_apellidos,
        `correo` = p_correo,
        `telefono` = NULLIF(p_telefono, ''),
        `estado` = p_estado
    WHERE `id_usuario` = p_id_usuario;
END$$

-- Registrar usuario
CREATE PROCEDURE `sp_admin_registrar_usuario`(
    IN p_id_area INT,
    IN p_cargo ENUM('empleado', 'jefe'),
    IN p_nombres VARCHAR(255),
    IN p_apellidos VARCHAR(255),
    IN p_correo VARCHAR(255),
    IN p_telefono VARCHAR(255),
    IN p_contrasena VARCHAR(255)
)
BEGIN
    -- Validar existencia de área/ambiente
    IF NOT EXISTS (SELECT 1 FROM `ambiente` WHERE `id_ambiente` = p_id_area) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El ambiente especificado no existe.';
    END IF;

    -- Validar correo único y formato
    IF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de correo electrónico inválido.';
    END IF;

    IF EXISTS (SELECT 1 FROM `usuario` WHERE `correo` = p_correo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El correo electrónico ya está registrado.';
    END IF;

    -- Validar teléfono (opcional)
    IF p_telefono IS NOT NULL AND p_telefono <> '' AND p_telefono NOT REGEXP '^[0-9]{7,15}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de teléfono inválido (debe tener entre 7 y 15 dígitos numéricos).';
    END IF;

    INSERT INTO `usuario` (
        `id_area`, `cargo`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`
    ) VALUES (
        p_id_area, p_cargo, p_nombres, p_apellidos, p_correo, NULLIF(p_telefono, ''), p_contrasena, TRUE
    );
END$$

-- Registrar técnico
CREATE PROCEDURE `sp_admin_registrar_tecnico`(
    IN p_rango ENUM('practicante', 'tecnico', 'administrador_sistema'),
    IN p_nombres VARCHAR(255),
    IN p_apellidos VARCHAR(255),
    IN p_correo VARCHAR(255),
    IN p_telefono VARCHAR(255),
    IN p_contrasena VARCHAR(255)
)
BEGIN
    -- Validar correo
    IF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de correo electrónico inválido.';
    END IF;

    IF EXISTS (SELECT 1 FROM `tecnico` WHERE `correo` = p_correo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El correo electrónico ya está registrado para un técnico.';
    END IF;

    -- Validar teléfono (opcional)
    IF p_telefono IS NOT NULL AND p_telefono <> '' AND p_telefono NOT REGEXP '^[0-9]{7,15}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de teléfono inválido.';
    END IF;

    INSERT INTO `tecnico` (
        `rango`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`
    ) VALUES (
        p_rango, p_nombres, p_apellidos, p_correo, NULLIF(p_telefono, ''), p_contrasena, TRUE
    );
END$$

-- Ver todos los técnicos (los inactivos se ordenan al final)
CREATE PROCEDURE `sp_admin_ver_tecnicos`()
BEGIN
    SELECT 
        t.`id_tecnico`,
        t.`nombres`,
        t.`apellidos`,
        t.`correo`,
        t.`telefono`,
        t.`rango`,
        t.`estado`
    FROM `tecnico` t
    ORDER BY t.`estado` DESC, t.`apellidos` ASC, t.`nombres` ASC;
END$$

-- Eliminar técnico (cambiar a estado inactivo)
CREATE PROCEDURE `sp_admin_eliminar_tecnico`(
    IN p_id_tecnico INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico especificado no existe.';
    END IF;

    UPDATE `tecnico` SET `estado` = FALSE WHERE `id_tecnico` = p_id_tecnico;
END$$

-- Editar técnico
CREATE PROCEDURE `sp_admin_editar_tecnico`(
    IN p_id_tecnico INT,
    IN p_rango ENUM('practicante', 'tecnico', 'administrador_sistema'),
    IN p_nombres VARCHAR(255),
    IN p_apellidos VARCHAR(255),
    IN p_correo VARCHAR(255),
    IN p_telefono VARCHAR(255),
    IN p_estado BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico especificado no existe.';
    END IF;

    -- Validar correo
    IF p_correo NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de correo electrónico inválido.';
    END IF;

    -- Validar teléfono (opcional)
    IF p_telefono IS NOT NULL AND p_telefono <> '' AND p_telefono NOT REGEXP '^[0-9]{7,15}$' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Formato de teléfono inválido.';
    END IF;

    UPDATE `tecnico`
    SET `rango` = p_rango,
        `nombres` = p_nombres,
        `apellidos` = p_apellidos,
        `correo` = p_correo,
        `telefono` = NULLIF(p_telefono, ''),
        `estado` = p_estado
    WHERE `id_tecnico` = p_id_tecnico;
END$$

-- Ver todas las áreas (unificado con ambientes)
CREATE PROCEDURE `sp_admin_ver_areas`()
BEGIN
    SELECT 
        `id_ambiente`,
        `numero`,
        `nombre`,
        `pabellon`,
        `piso`
    FROM `ambiente`
    ORDER BY `nombre` ASC, `numero` ASC;
END$$

-- Registrar área (ambiente)
CREATE PROCEDURE `sp_admin_registrar_area`(
    IN p_numero INT,
    IN p_nombre VARCHAR(50),
    IN p_pabellon ENUM('Antiguo','Nuevo'),
    IN p_piso INT
)
BEGIN
    IF p_numero <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El número de ambiente debe ser mayor a 0.';
    END IF;

    IF p_piso < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El piso debe ser mayor o igual a 0.';
    END IF;

    INSERT INTO `ambiente` (`numero`, `nombre`, `pabellon`, `piso`)
    VALUES (p_numero, p_nombre, p_pabellon, p_piso);
END$$

-- Eliminar área (ambiente). Si tiene dependencias de llaves foráneas activas, el motor SQL restringirá la operación.
CREATE PROCEDURE `sp_admin_eliminar_area`(
    IN p_id_ambiente INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM `ambiente` WHERE `id_ambiente` = p_id_ambiente) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El ambiente (área) especificado no existe.';
    END IF;

    DELETE FROM `ambiente` WHERE `id_ambiente` = p_id_ambiente;
END$$

-- Registrar componente general
CREATE PROCEDURE `sp_admin_registrar_componente`(
    IN p_id_equipo INT,
    IN p_id_ambiente INT,
    IN p_estado_componente ENUM ('operativo', 'almacenado', 'mantenimiento', 'baja'),
    IN p_tipo_componente VARCHAR(50), -- 'procesador', 'memoria_ram', 'almacenamiento', 'tarjeta_grafica', 'placa_madre', 'fuente_poder'
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(100),
    IN p_capacidad_o_vram INT, -- capacidad_gb o vram_gb o potencia_watts
    IN p_tipo_detalle VARCHAR(50) -- ddr_type (DDR3, DDR4, DDR5) o storage_type (ssd, hdd) o socket o certificacion
)
BEGIN
    DECLARE v_id_comp INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validar exclusión mutua de destino (o en equipo, o en almacén/ambiente)
    IF (p_id_equipo IS NOT NULL AND p_id_ambiente IS NOT NULL) OR (p_id_equipo IS NULL AND p_id_ambiente IS NULL) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Debe especificar id_equipo o id_ambiente, pero no ambos.';
    END IF;

    START TRANSACTION;
        -- Insertar componente base
        INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`)
        VALUES (p_id_equipo, p_id_ambiente, COALESCE(p_estado_componente, 'operativo'));
        
        SET v_id_comp = LAST_INSERT_ID();

        -- Insertar según tipo
        IF LOWER(p_tipo_componente) = 'procesador' THEN
            INSERT INTO `procesador` (`id_componente`, `marca`, `modelo`)
            VALUES (v_id_comp, p_marca, p_modelo);
        ELSEIF LOWER(p_tipo_componente) = 'memoria_ram' THEN
            INSERT INTO `memoria_ram` (`id_componente`, `marca`, `capacidad_gb`, `tipo_ddr`)
            VALUES (v_id_comp, p_marca, p_capacidad_o_vram, p_tipo_detalle);
        ELSEIF LOWER(p_tipo_componente) = 'almacenamiento' THEN
            INSERT INTO `almacenamiento` (`id_componente`, `marca`, `modelo`, `tipo`, `capacidad_gb`)
            VALUES (v_id_comp, p_marca, p_modelo, p_tipo_detalle, p_capacidad_o_vram);
        ELSEIF LOWER(p_tipo_componente) = 'tarjeta_grafica' THEN
            INSERT INTO `tarjeta_grafica` (`id_componente`, `marca`, `modelo`, `vram_gb`)
            VALUES (v_id_comp, p_marca, p_modelo, p_capacidad_o_vram);
        ELSEIF LOWER(p_tipo_componente) = 'placa_madre' THEN
            INSERT INTO `placa_madre` (`id_componente`, `marca`, `modelo`, `socket`, `factor_forma`)
            VALUES (v_id_comp, p_marca, p_modelo, p_tipo_detalle, 'ATX');
        ELSEIF LOWER(p_tipo_componente) = 'fuente_poder' THEN
            INSERT INTO `fuente_poder` (`id_componente`, `marca`, `modelo`, `potencia_watts`, `certificacion`)
            VALUES (v_id_comp, p_marca, p_modelo, p_capacidad_o_vram, p_tipo_detalle);
        ELSE
            ROLLBACK;
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: Tipo de componente no reconocido.';
        END IF;
    COMMIT;
END$$

-- Editar componente general
CREATE PROCEDURE `sp_admin_editar_componente`(
    IN p_id_componente INT,
    IN p_id_equipo INT,
    IN p_id_ambiente INT,
    IN p_estado_componente ENUM ('operativo', 'almacenado', 'mantenimiento', 'baja'),
    IN p_tipo_componente VARCHAR(50),
    IN p_marca VARCHAR(50),
    IN p_modelo VARCHAR(100),
    IN p_capacidad_o_vram INT,
    IN p_tipo_detalle VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM `componente` WHERE `id_componente` = p_id_componente) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El componente especificado no existe.';
    END IF;

    -- Validar exclusión mutua de destino
    IF (p_id_equipo IS NOT NULL AND p_id_ambiente IS NOT NULL) OR (p_id_equipo IS NULL AND p_id_ambiente IS NULL) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Debe especificar id_equipo o id_ambiente, pero no ambos.';
    END IF;

    START TRANSACTION;
        UPDATE `componente`
        SET `id_equipo` = p_id_equipo,
            `id_ambiente` = p_id_ambiente,
            `estado_componente` = p_estado_componente
        WHERE `id_componente` = p_id_componente;

        IF LOWER(p_tipo_componente) = 'procesador' THEN
            UPDATE `procesador` SET `marca` = p_marca, `modelo` = p_modelo WHERE `id_componente` = p_id_componente;
        ELSEIF LOWER(p_tipo_componente) = 'memoria_ram' THEN
            UPDATE `memoria_ram` SET `marca` = p_marca, `capacidad_gb` = p_capacidad_o_vram, `tipo_ddr` = p_tipo_detalle WHERE `id_componente` = p_id_componente;
        ELSEIF LOWER(p_tipo_componente) = 'almacenamiento' THEN
            UPDATE `almacenamiento` SET `marca` = p_marca, `modelo` = p_modelo, `tipo` = p_tipo_detalle, `capacidad_gb` = p_capacidad_o_vram WHERE `id_componente` = p_id_componente;
        ELSEIF LOWER(p_tipo_componente) = 'tarjeta_grafica' THEN
            UPDATE `tarjeta_grafica` SET `marca` = p_marca, `modelo` = p_modelo, `vram_gb` = p_capacidad_o_vram WHERE `id_componente` = p_id_componente;
        ELSEIF LOWER(p_tipo_componente) = 'placa_madre' THEN
            UPDATE `placa_madre` SET `marca` = p_marca, `modelo` = p_modelo, `socket` = p_tipo_detalle WHERE `id_componente` = p_id_componente;
        ELSEIF LOWER(p_tipo_componente) = 'fuente_poder' THEN
            UPDATE `fuente_poder` SET `marca` = p_marca, `modelo` = p_modelo, `potencia_watts` = p_capacidad_o_vram, `certificacion` = p_tipo_detalle WHERE `id_componente` = p_id_componente;
        END IF;
    COMMIT;
END$$

-- Ver auditoría en formato JSON
CREATE PROCEDURE `sp_admin_ver_auditoria`()
BEGIN
    SELECT 
        a.`id_auditoria_tecnico` AS `log_id`,
        CONCAT(t.`nombres`, ' ', t.`apellidos`) AS `tecnico_responsable`,
        a.`tabla_afectada` AS `tabla`,
        a.`permiso_realizado` AS `operacion`,
        a.`valor_agregado` AS `valor_nuevo`,
        a.`valor_anterior` AS `valor_antiguo`,
        a.`fecha_realizado` AS `fecha_hora`
    FROM `auditoria_tecnico` a
    INNER JOIN `tecnico` t ON a.`id_tecnico` = t.`id_tecnico`
    ORDER BY a.`fecha_realizado` DESC;
END$$

-- Ver métricas de rendimiento de técnicos
CREATE PROCEDURE `sp_admin_ver_metricas_tecnicos`()
BEGIN
    SELECT 
        CONCAT(t.`nombres`, ' ', t.`apellidos`) AS `nombre_tecnico`,
        t.`rango`,
        (SELECT COUNT(*) FROM `incidencia` i WHERE i.`id_tecnico_recibe` = t.`id_tecnico`) AS `incidencias_asignadas`,
        (SELECT COUNT(*) FROM `incidencia` i WHERE i.`id_tecnico_recibe` = t.`id_tecnico` AND i.`estado` = 'resuelta') AS `incidencias_resueltas`,
        (SELECT COUNT(*) FROM `incidencia` i WHERE i.`id_tecnico_recibe` = t.`id_tecnico` AND i.`estado` IN ('pendiente', 'en_proceso')) AS `incidencias_pendientes`,
        IFNULL((SELECT SUM(s.`horas_invertidas`) FROM `seguimiento_incidencia` s WHERE s.`id_tecnico` = t.`id_tecnico`), 0) AS `total_horas_invertidas`,
        IFNULL(
            (SELECT SUM(s.`horas_invertidas`) FROM `seguimiento_incidencia` s WHERE s.`id_tecnico` = t.`id_tecnico`) / 
            NULLIF((SELECT COUNT(*) FROM `incidencia` i WHERE i.`id_tecnico_recibe` = t.`id_tecnico` AND i.`estado` = 'resuelta'), 0),
            0
        ) AS `promedio_hora_incidencia`
    FROM `tecnico` t
    WHERE t.`estado` = TRUE
    ORDER BY `incidencias_resueltas` DESC;
END$$

-- Ver todos los componentes (común para practicante, técnico y administrador)
CREATE PROCEDURE `sp_ver_todos_componentes`()
BEGIN
    SELECT `componente_id`, `tipo`, `especificaciones_tecnicas`, `estado_fisico`, `asignado_a`, `id_equipo`, `id_ambiente`
    FROM `vw_componentes_detallados`
    ORDER BY `componente_id` DESC;
END$$

-- Ver tiempo de resolución de una incidencia en horas (SLA)
DROP FUNCTION IF EXISTS `fn_tiempo_resolucion`$$

CREATE FUNCTION `fn_tiempo_resolucion`(p_id_incidencia INT)
RETURNS DECIMAL(6,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_tiempo DECIMAL(6,2);
    SELECT TIMESTAMPDIFF(HOUR, `fecha_creacion`, `fecha_resolucion`) INTO v_tiempo
    FROM `incidencia`
    WHERE `id_incidencia` = p_id_incidencia;
    RETURN IFNULL(v_tiempo, 0.0);
END$$

DELIMITER ;
