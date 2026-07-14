-- =============================================================================
-- TECNICO STORED PROCEDURES - Sistema de Soporte FISI (soportefisi)
-- Archivo de Stored Procedures para Técnicos
-- =============================================================================

USE `soportefisi`;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- SP: sp_dar_baja_equipo
-- Parámetros de entrada:
--   p_id_tecnico : ID del técnico que ejecuta la acción
--   p_id_equipo  : ID del equipo a dar de baja
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_dar_baja_equipo` $$

CREATE PROCEDURE `sp_dar_baja_equipo`(
    IN p_id_tecnico INT,
    IN p_id_equipo INT
)
BEGIN
    DECLARE v_rango ENUM('practicante', 'tecnico', 'administrador_sistema');
    DECLARE v_tipo_equipo ENUM('pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor', 'otro');
    DECLARE v_id_almacen INT;

    -- 1. Validar existencia del técnico y obtener su rango
    SELECT `rango` INTO v_rango
    FROM `tecnico`
    WHERE `id_tecnico` = p_id_tecnico;

    -- Validar que el técnico tenga rango 'tecnico' o 'administrador_sistema'
    IF v_rango IS NULL OR v_rango NOT IN ('tecnico', 'administrador_sistema') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Permiso denegado. Solo los técnicos de rango "tecnico" o "administrador_sistema" pueden dar de baja a los equipos.';
    END IF;

    -- 2. Validar existencia del equipo y obtener su tipo
    SELECT `tipo` INTO v_tipo_equipo
    FROM `equipo`
    WHERE `id_equipo` = p_id_equipo;

    IF v_tipo_equipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    -- 3. Iniciar el proceso de baja
    START TRANSACTION;

        -- Cambiar el estado del equipo a 'baja'
        UPDATE `equipo`
        SET `estado` = 'baja'
        WHERE `id_equipo` = p_id_equipo;

        -- 4. Si el equipo es pc_escritorio, desasociar y mover sus componentes a almacén
        IF v_tipo_equipo = 'pc_escritorio' THEN
            
            -- Buscar o crear el ambiente de almacén (buscando por su columna 'nombre')
            SELECT `id_ambiente` INTO v_id_almacen 
            FROM `ambiente` 
            WHERE `nombre` = 'almacen' 
            LIMIT 1;

            -- Si no existe un ambiente para almacén, lo registramos automáticamente
            IF v_id_almacen IS NULL THEN
                INSERT INTO `ambiente` (`numero`, `nombre`, `pabellon`, `piso`) 
                VALUES (1, 'almacen', 'Antiguo', 0);
                SET v_id_almacen = LAST_INSERT_ID();
            END IF;

            -- Actualizar los componentes asociados al equipo:
            -- Se cambia id_ambiente a 'almacen', id_equipo a NULL y el estado_componente a 'almacenado'
            UPDATE `componente`
            SET `id_ambiente` = v_id_almacen,
                `id_equipo` = NULL,
                `estado_componente` = 'almacenado'
            WHERE `id_equipo` = p_id_equipo;

        END IF;

    COMMIT;

END $$

-- -----------------------------------------------------------------------------
-- SP: sp_asignar_componente_pc_escritorio
-- Parámetros de entrada:
--   p_id_tecnico    : ID del técnico/administrador que realiza la asignación
--   p_id_componente : ID del componente a asignar
--   p_id_equipo     : ID del equipo al que se asignará el componente (debe ser PC_escritorio)
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_asignar_componente_pc_escritorio` $$

CREATE PROCEDURE `sp_asignar_componente_pc_escritorio`(
    IN p_id_tecnico INT,
    IN p_id_componente INT,
    IN p_id_equipo INT
)
BEGIN
    DECLARE v_rango ENUM('practicante', 'tecnico', 'administrador_sistema');
    DECLARE v_tipo_equipo ENUM('pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor', 'otro');

    -- 1. Validar existencia del técnico y obtener su rango
    SELECT `rango` INTO v_rango
    FROM `tecnico`
    WHERE `id_tecnico` = p_id_tecnico AND `estado` = TRUE;

    -- Validar que el técnico tenga rango 'tecnico' o 'administrador_sistema'
    IF v_rango IS NULL OR v_rango NOT IN ('tecnico', 'administrador_sistema') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Permiso denegado. Solo los técnicos de rango "tecnico" o "administrador_sistema" pueden asignar componentes a equipos.';
    END IF;

    -- 2. Validar existencia del equipo y obtener su tipo
    SELECT `tipo` INTO v_tipo_equipo
    FROM `equipo`
    WHERE `id_equipo` = p_id_equipo;

    IF v_tipo_equipo IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    -- Validar que sea de tipo 'pc_escritorio'
    IF v_tipo_equipo <> 'pc_escritorio' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Solo se pueden asignar componentes a equipos de la categoría PC_escritorio.';
    END IF;

    -- 3. Validar existencia del componente
    IF NOT EXISTS (SELECT 1 FROM `componente` WHERE `id_componente` = p_id_componente) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El componente especificado no existe.';
    END IF;

    -- 4. Realizar la asignación
    START TRANSACTION;
        UPDATE `componente`
        SET `id_equipo` = p_id_equipo,
            `id_ambiente` = NULL,
            `estado_componente` = 'operativo'
        WHERE `id_componente` = p_id_componente;
    COMMIT;
END $$

DELIMITER ;
