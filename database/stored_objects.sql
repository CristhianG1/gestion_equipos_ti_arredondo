-- =============================================================================
-- STORED OBJECTS - Sistema de Soporte FISI (soportefisi)
-- Archivo de Stored Procedures
-- =============================================================================

USE `soportefisi`;

DROP PROCEDURE IF EXISTS `sp_registrar_incidencia`;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP: sp_registrar_incidencia
-- Parámetros de entrada:
--   p_id_equipo   : ID del equipo que presenta la falla
--   p_prioridad   : Prioridad de la incidencia ('baja', 'media', 'alta')
--   p_descripcion : Descripción detallada de la falla
-- -----------------------------------------------------------------------------
CREATE PROCEDURE `sp_registrar_incidencia`(
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

    -- Si el equipo no está asignado a un usuario (está en un ambiente/laboratorio),
    -- tomamos el primer usuario activo de la base de datos para no violar la integridad referencial (NOT NULL)
    IF v_id_usuario_reporta IS NULL THEN
        SELECT `id_usuario` INTO v_id_usuario_reporta
        FROM `usuario`
        WHERE `estado` = TRUE
        LIMIT 1;
    END IF;

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

DELIMITER ;
