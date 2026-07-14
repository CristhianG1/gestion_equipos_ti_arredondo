-- =============================================================================
-- USUARIO SIMPLE
-- =============================================================================

USE `soportefisi`;

-- Cambiamos el delimitador para poder definir los procedimientos
DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP 1: sp_registrar_incidencia_usuario
-- Parámetros de entrada:
--   p_id_usuario  : ID del usuario que reporta
--   p_id_equipo   : ID del equipo que presenta la falla
--   p_prioridad   : Prioridad de la incidencia ('baja', 'media', 'alta')
--   p_descripcion : Descripción detallada de la falla
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_registrar_incidencia_usuario` $$

CREATE PROCEDURE `sp_registrar_incidencia_usuario`(
    IN p_id_usuario INT,
    IN p_id_equipo INT,
    IN p_prioridad ENUM('baja', 'media', 'alta'),
    IN p_descripcion TEXT
)
BEGIN
    -- Registrar la incidencia lista con el usuario que la reportó
    INSERT INTO `incidencia` (
        `id_equipo`,
        `id_usuario_reporta`,
        `descripcion`,
        `prioridad`,
        `estado`,
        `fecha_creacion`
    ) VALUES (
        p_id_equipo,
        p_id_usuario,
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
    SELECT `id_incidencia`, `id_tecnico`, `tecnico_nombre`, `diagnostico`, `trabajo_realizado`, `horas_invertidas`, `fecha`
    FROM `vw_seguimiento_incidencias_usuario`
    WHERE `id_incidencia` = p_id_incidencia;
END $$

DELIMITER ;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP: sp_revisar_equipos_por_area_usuario
-- Parámetros de entrada:
--   p_id_usuario : ID del usuario a consultar
-- Descripción: Retorna los equipos que pertenecen al área/ambiente del usuario.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_revisar_equipos_por_area_usuario` $$

CREATE PROCEDURE `sp_revisar_equipos_por_area_usuario`(
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_id_area INT;

    -- Obtener el área del usuario (que en el schema apunta al id_ambiente)
    SELECT `id_area` INTO v_id_area
    FROM `usuario`
    WHERE `id_usuario` = p_id_usuario;

    -- Retornar todos los equipos de ese ambiente/área que estén activos
    SELECT `id_equipo`, `codigo_inventario`, `tipo`, `marca`, `estado`
    FROM `equipo`
    WHERE `id_ambiente` = v_id_area AND `estado` != 'baja';
END $$

DELIMITER ;
