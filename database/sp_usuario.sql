-- =============================================================================
-- USUARIO SIMPLE
-- =============================================================================

USE `soportefisi`;

-- Cambiamos el delimitador para poder definir los procedimientos
DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP 1: sp_registrar_incidencia
-- Parámetros de entrada:
--   p_id_equipo   : ID del equipo que presenta la falla
--   p_prioridad   : Prioridad de la incidencia ('baja', 'media', 'alta')
--   p_descripcion : Descripción detallada de la falla
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_registrar_incidencia_usuario` $$

CREATE PROCEDURE `sp_registrar_incidencia_usuario`(
    IN p_id_equipo INT,
    IN p_prioridad ENUM('baja', 'media', 'alta'),
    IN p_descripcion TEXT
)
BEGIN
    DECLARE v_id_usuario_reporta INT;

    -- Obtener el usuario asignado al equipo para colocarlo como reportante
    SELECT `id_usuario` INTO v_id_usuario_reporta
    FROM `equipo`
    WHERE `id_equipo` = p_id_equipo;

    -- Registrar la incidencia lista para que el técnico la revise
    INSERT INTO `incidencia` (
        `id_equipo`,
        `id_usuario_reporta`,
        `descripcion`,
        `prioridad`,
        `estado`,
        `fecha_creacion`
    ) VALUES (
        p_id_equipo,
        v_id_usuario_reporta,
        p_descripcion,
        p_prioridad,
        'pendiente',
        NOW()
    );
END $$

-- -----------------------------------------------------------------------------
-- SP 2: sp_revisar_incidencia_usuario
-- Parámetros de entrada:
--   p_id_incidencia : ID de la incidencia a revisar
-- Nota: Solo consulta desde la vista vw_revision_incidencias_is_usuario
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_revisar_incidencia_usuario` $$

CREATE PROCEDURE `sp_revisar_incidencia_usuario`(
    IN p_id_incidencia INT
)
BEGIN
    SELECT `id_equipo`, `descripcion`, `estado`
    FROM `vw_revision_incidencias_is_usuario`
    WHERE `id_incidencia` = p_id_incidencia;
END $$

-- -----------------------------------------------------------------------------
-- SP 3: sp_ver_seguimiento_incidencia
-- Parámetros de entrada:
--   p_id_incidencia : ID de la incidencia a revisar el seguimiento
-- Nota: Solo consulta desde la vista vw_seguimiento_incidencias_usuario
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_ver_seguimiento_incidencia` $$

CREATE PROCEDURE `sp_ver_seguimiento_incidencia`(
    IN p_id_incidencia INT
)
BEGIN
    SELECT `id_incidencia`, `id_tecnico`, `diagnostico`, `trabajo_realizado`, `horas_invertidas`, `fecha`
    FROM `vw_seguimiento_incidencias_usuario`
    WHERE `id_incidencia` = p_id_incidencia;
END $$

DELIMITER ;

-- =============================================================================
-- USUARIO JEFE
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP: sp_crear_solicitud_jefe
-- Parámetros de entrada:
--   p_id_usuario  : ID del usuario solicitante
--   p_rango       : Rango del usuario ('empleado', 'jefe')
--   p_tipo        : Tipo de solicitud ('remodelacion', 'mejora', 'reemplazo')
--   p_descripcion : Descripción detallada de la solicitud
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_crear_solicitud_jefe` $$

CREATE PROCEDURE `sp_crear_solicitud_jefe`(
    IN p_id_usuario INT,
    IN p_tipo ENUM('remodelacion', 'mejora', 'reemplazo'),
    IN p_descripcion TEXT
)
BEGIN
    DECLARE v_cargo ENUM('empleado', 'jefe');

    -- Obtener el cargo del usuario de la base de datos para validación cruzada
    SELECT `cargo` INTO v_cargo
    FROM `usuario`
    WHERE `id_usuario` = p_id_usuario;

    -- Validar que el cargo real en la BD sea 'jefe'
    IF v_cargo <> 'jefe' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Permiso denegado. Solo usuarios con rango/cargo de jefe pueden crear solicitudes.';
    ELSE
        -- Insertar la solicitud generando la fecha actual y estado 'pendiente' automáticamente
        INSERT INTO `solicitud` (
            `id_usuario_solicita`,
            `tipo`,
            `descripcion`,
            `estado`,
            `fecha_solicitud`
        ) VALUES (
            p_id_usuario,
            p_tipo,
            p_descripcion,
            'pendiente',
            NOW()
        );
    END IF;
END $$

-- -----------------------------------------------------------------------------
-- SP: sp_ver_estado_solicitud
-- Parámetros de entrada:
--   p_id_solicitud : ID de la solicitud a consultar
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_ver_estado_solicitud` $$

CREATE PROCEDURE `sp_ver_estado_solicitud`(
    IN p_id_solicitud INT
)
BEGIN
    SELECT 
        `id_solicitud`,
        `tipo`,
        `descripcion`,
        `estado`,
        `fecha_solicitud`,
        `fecha_respuesta`
    FROM `solicitud`
    WHERE `id_solicitud` = p_id_solicitud;
END $$

DELIMITER ;
