-- =============================================================================
-- PROCEDIMIENTOS ALMACENADOS Y FUNCIONES - Rol Técnico / Administrador
-- Sistema de Soporte FISI (soportefisi)
-- =============================================================================

USE `soportefisi`;

-- -----------------------------------------------------------------------------
-- Eliminación de procedimientos previos para evitar duplicados
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_registrar_equipo`;
DROP PROCEDURE IF EXISTS `sp_registrar_componentes_laptop`;
DROP PROCEDURE IF EXISTS `sp_registrar_componentes_pc`;
DROP PROCEDURE IF EXISTS `sp_registrar_software`;
DROP PROCEDURE IF EXISTS `sp_registrar_instalacion_software`;
DROP PROCEDURE IF EXISTS `sp_ver_software_instalado_tecnico`;
DROP PROCEDURE IF EXISTS `sp_editar_software_instalado`;
DROP PROCEDURE IF EXISTS `sp_tecnico_registrar_incidencia`;
DROP PROCEDURE IF EXISTS `sp_registrar_seguimiento_tecnico`;
DROP PROCEDURE IF EXISTS `sp_asignar_personal_incidencia`;
DROP PROCEDURE IF EXISTS `sp_ver_solicitudes`;
DROP PROCEDURE IF EXISTS `sp_ver_detalle_solicitud`;

DROP FUNCTION IF EXISTS `fn_tickets_asignados`;
DROP FUNCTION IF EXISTS `fn_total_incidentes_pendientes`;
DROP FUNCTION IF EXISTS `fn_tickets_resueltos`;

DELIMITER $$

-- =============================================================================
-- 1. PROCEDIMIENTO ALMACENADO: sp_registrar_equipo
-- =============================================================================
CREATE PROCEDURE `sp_registrar_equipo`(
    IN p_codigo_inventario VARCHAR(255),
    IN p_tipo ENUM('pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor', 'otro'),
    IN p_tipo_origen ENUM('ensamblado_facultad', 'comprado_ensamblado'),
    IN p_marca VARCHAR(255),
    IN p_estado ENUM('operativo', 'mantenimiento', 'baja'),
    IN p_cantidad INT,
    IN p_id_ambiente INT,
    IN p_id_usuario INT
)
BEGIN
    DECLARE v_id_ambiente INT;
    DECLARE v_len INT;
    DECLARE v_pos INT;
    DECLARE v_prefix VARCHAR(255);
    DECLARE v_num_str VARCHAR(255);
    DECLARE v_num INT;
    DECLARE v_num_len INT;
    DECLARE v_current_code VARCHAR(255);
    DECLARE v_i INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validar cantidad
    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La cantidad a registrar debe ser mayor a 0.';
    END IF;

    -- Validar/buscar ambiente
    SET v_id_ambiente = p_id_ambiente;
    IF v_id_ambiente IS NULL THEN
        SELECT `id_ambiente` INTO v_id_ambiente FROM `ambiente` ORDER BY `id_ambiente` ASC LIMIT 1;
    END IF;
    IF v_id_ambiente IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se encontró ningún ambiente registrado en el sistema.';
    END IF;

    -- Si se especificó usuario, validar que exista
    IF p_id_usuario IS NOT NULL AND NOT EXISTS (SELECT 1 FROM `usuario` WHERE `id_usuario` = p_id_usuario) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El usuario especificado no existe.';
    END IF;

    -- Parsear código de inventario base para generación secuencial (ej. EQ-001 -> EQ-002, EQ-003)
    SET v_len = CHAR_LENGTH(p_codigo_inventario);
    SET v_pos = v_len;
    
    WHILE v_pos > 0 AND SUBSTRING(p_codigo_inventario, v_pos, 1) REGEXP '^[0-9]$' DO
        SET v_pos = v_pos - 1;
    END WHILE;

    SET v_prefix = SUBSTRING(p_codigo_inventario, 1, v_pos);
    SET v_num_str = SUBSTRING(p_codigo_inventario, v_pos + 1);

    IF v_num_str = '' OR v_num_str IS NULL THEN
        SET v_prefix = p_codigo_inventario;
        SET v_num = 1;
        SET v_num_len = 0;
    ELSE
        SET v_num = CAST(v_num_str AS UNSIGNED);
        SET v_num_len = CHAR_LENGTH(v_num_str);
    END IF;

    -- Iniciar transacción para asegurar atomicidad
    START TRANSACTION;
        WHILE v_i < p_cantidad DO
            IF v_i = 0 THEN
                SET v_current_code = p_codigo_inventario;
            ELSE
                IF v_num_len > 0 THEN
                    SET v_current_code = CONCAT(v_prefix, LPAD(CAST(v_num + v_i AS CHAR), v_num_len, '0'));
                ELSE
                    SET v_current_code = CONCAT(v_prefix, CAST(v_num + v_i AS CHAR));
                END IF;
            END IF;

            -- Validar duplicados durante el bucle
            IF EXISTS (SELECT 1 FROM `equipo` WHERE `codigo_inventario` = v_current_code) THEN
                ROLLBACK;
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Error: El código de inventario ya existe o se duplicaría en el registro secuencial.';
            END IF;

            INSERT INTO `equipo` (
                `codigo_inventario`, `tipo`, `tipo_origen`, `marca`, `estado`, `id_usuario`, `id_ambiente`
            ) VALUES (
                v_current_code, p_tipo, p_tipo_origen, p_marca, p_estado, p_id_usuario, v_id_ambiente
            );

            SET v_i = v_i + 1;
        END WHILE;
    COMMIT;
END$$

-- =============================================================================
-- 2. PROCEDIMIENTO ALMACENADO: sp_registrar_componentes_laptop
-- =============================================================================
CREATE PROCEDURE `sp_registrar_componentes_laptop`(
    IN p_id_equipo INT,
    IN p_modelo_laptop VARCHAR(100),
    IN p_codigo_serie_base VARCHAR(100), -- no almacenado directamente
    IN p_marca_procesador VARCHAR(50),
    IN p_modelo_procesador VARCHAR(100),
    IN p_tipo_ram ENUM('DDR3', 'DDR4', 'DDR5'),
    IN p_capacidad_ram INT,
    IN p_tipo_almacenamiento ENUM('ssd', 'hdd'),
    IN p_capacidad_almacenamiento INT,
    IN p_tipo_graficos VARCHAR(50),
    IN p_modelo_grafica VARCHAR(100)
)
BEGIN
    DECLARE v_id_comp INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validar existencia del equipo
    IF NOT EXISTS (SELECT 1 FROM `equipo` WHERE `id_equipo` = p_id_equipo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    START TRANSACTION;
        -- Actualizar marca/modelo en equipo
        IF p_modelo_laptop IS NOT NULL AND p_modelo_laptop <> '' THEN
            UPDATE `equipo` SET `marca` = p_modelo_laptop WHERE `id_equipo` = p_id_equipo;
        END IF;

        -- 1. Procesador
        IF p_marca_procesador IS NOT NULL OR p_modelo_procesador IS NOT NULL THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `procesador` (`id_componente`, `marca`, `modelo`) VALUES (v_id_comp, p_marca_procesador, p_modelo_procesador);
        END IF;

        -- 2. Memoria RAM
        IF p_capacidad_ram IS NOT NULL AND p_capacidad_ram > 0 THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `memoria_ram` (`id_componente`, `marca`, `capacidad_gb`, `tipo_ddr`) VALUES (v_id_comp, 'Genérica Laptop', p_capacidad_ram, p_tipo_ram);
        END IF;

        -- 3. Almacenamiento
        IF p_capacidad_almacenamiento IS NOT NULL AND p_capacidad_almacenamiento > 0 THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `almacenamiento` (`id_componente`, `marca`, `modelo`, `tipo`, `capacidad_gb`) VALUES (v_id_comp, 'Genérico Laptop', 'OEM SSD/HDD', p_tipo_almacenamiento, p_capacidad_almacenamiento);
        END IF;

        -- 4. Tarjeta Gráfica
        IF p_modelo_grafica IS NOT NULL AND p_modelo_grafica <> '' THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `tarjeta_grafica` (`id_componente`, `marca`, `modelo`, `vram_gb`) VALUES (v_id_comp, p_tipo_graficos, p_modelo_grafica, NULL);
        END IF;
    COMMIT;
END$$

-- =============================================================================
-- 3. PROCEDIMIENTO ALMACENADO: sp_registrar_componentes_pc
-- =============================================================================
CREATE PROCEDURE `sp_registrar_componentes_pc`(
    IN p_id_equipo INT,
    IN p_marca_procesador VARCHAR(50),
    IN p_modelo_procesador VARCHAR(100),
    IN p_marca_ram VARCHAR(50),
    IN p_capacidad_ram INT,
    IN p_tipo_ram ENUM('DDR3', 'DDR4', 'DDR5'),
    IN p_marca_almacenamiento VARCHAR(50),
    IN p_modelo_almacenamiento VARCHAR(100),
    IN p_tipo_disco ENUM('ssd', 'hdd'),
    IN p_capacidad_almacenamiento INT,
    IN p_marca_placa VARCHAR(50),
    IN p_modelo_placa VARCHAR(100),
    IN p_socket_placa VARCHAR(50),
    IN p_tamano_placa VARCHAR(50), -- factor_forma
    IN p_marca_fuente VARCHAR(50),
    IN p_modelo_fuente VARCHAR(100),
    IN p_potencia_fuente INT,
    IN p_certificacion_fuente VARCHAR(50),
    IN p_marca_grafica VARCHAR(50),
    IN p_modelo_gpu VARCHAR(100),
    IN p_vram_gpu INT
)
BEGIN
    DECLARE v_id_comp INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validar existencia del equipo
    IF NOT EXISTS (SELECT 1 FROM `equipo` WHERE `id_equipo` = p_id_equipo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    START TRANSACTION;
        -- 1. Procesador
        IF p_marca_procesador IS NOT NULL OR p_modelo_procesador IS NOT NULL THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `procesador` (`id_componente`, `marca`, `modelo`) VALUES (v_id_comp, p_marca_procesador, p_modelo_procesador);
        END IF;

        -- 2. Memoria RAM
        IF p_capacidad_ram IS NOT NULL AND p_capacidad_ram > 0 THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `memoria_ram` (`id_componente`, `marca`, `capacidad_gb`, `tipo_ddr`) VALUES (v_id_comp, p_marca_ram, p_capacidad_ram, p_tipo_ram);
        END IF;

        -- 3. Almacenamiento
        IF p_capacidad_almacenamiento IS NOT NULL AND p_capacidad_almacenamiento > 0 THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `almacenamiento` (`id_componente`, `marca`, `modelo`, `tipo`, `capacidad_gb`) VALUES (v_id_comp, p_marca_almacenamiento, p_modelo_almacenamiento, p_tipo_disco, p_capacidad_almacenamiento);
        END IF;

        -- 4. Placa Madre
        IF p_marca_placa IS NOT NULL OR p_modelo_placa IS NOT NULL THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `placa_madre` (`id_componente`, `marca`, `modelo`, `socket`, `factor_forma`) VALUES (v_id_comp, p_marca_placa, p_modelo_placa, p_socket_placa, p_tamano_placa);
        END IF;

        -- 5. Fuente de Poder
        IF p_potencia_fuente IS NOT NULL AND p_potencia_fuente > 0 THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `fuente_poder` (`id_componente`, `marca`, `modelo`, `potencia_watts`, `certificacion`) VALUES (v_id_comp, p_marca_fuente, p_modelo_fuente, p_potencia_fuente, p_certificacion_fuente);
        END IF;

        -- 6. Tarjeta Gráfica
        IF p_modelo_gpu IS NOT NULL AND p_modelo_gpu <> '' THEN
            INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (p_id_equipo, NULL, 'operativo');
            SET v_id_comp = LAST_INSERT_ID();
            INSERT INTO `tarjeta_grafica` (`id_componente`, `marca`, `modelo`, `vram_gb`) VALUES (v_id_comp, p_marca_grafica, p_modelo_gpu, p_vram_gpu);
        END IF;
    COMMIT;
END$$

-- =============================================================================
-- 4. PROCEDIMIENTO ALMACENADO: sp_registrar_software
-- =============================================================================
CREATE PROCEDURE `sp_registrar_software`(
    IN p_nombre VARCHAR(255)
)
BEGIN
    IF EXISTS (SELECT 1 FROM `software` WHERE `nombre` = p_nombre) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El software ya se encuentra registrado.';
    ELSE
        INSERT INTO `software` (`nombre`) VALUES (p_nombre);
    END IF;
END$$

-- =============================================================================
-- 5. PROCEDIMIENTO ALMACENADO: sp_registrar_instalacion_software
-- =============================================================================
CREATE PROCEDURE `sp_registrar_instalacion_software`(
    IN p_id_equipo INT,
    IN p_id_software INT,
    IN p_tipo_licencia VARCHAR(50),
    IN p_clave_licencia VARCHAR(255),
    IN p_fecha_instalacion DATE,
    IN p_fecha_expiracion DATE
)
BEGIN
    DECLARE v_equipo_exists INT DEFAULT 0;
    DECLARE v_software_exists INT DEFAULT 0;
    DECLARE v_dup_exists INT DEFAULT 0;

    -- Validar existencia del equipo
    SELECT COUNT(*) INTO v_equipo_exists FROM `equipo` WHERE `id_equipo` = p_id_equipo;
    IF v_equipo_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    -- Validar existencia del software
    SELECT COUNT(*) INTO v_software_exists FROM `software` WHERE `id_software` = p_id_software;
    IF v_software_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El software especificado no existe.';
    END IF;

    -- Validar duplicado
    SELECT COUNT(*) INTO v_dup_exists 
    FROM `software_instalado` 
    WHERE `id_equipo` = p_id_equipo AND `id_software` = p_id_software;
    
    IF v_dup_exists > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Este software ya se encuentra instalado en el equipo seleccionado.';
    END IF;

    -- Validar consistencia de fechas
    IF p_fecha_expiracion IS NOT NULL AND p_fecha_expiracion < p_fecha_instalacion THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La fecha de expiración no puede ser anterior a la fecha de instalación.';
    END IF;

    INSERT INTO `software_instalado` (
        `id_equipo`, `id_software`, `tipo_licencia`, `clave_licencia`, `fecha_instalacion`, `fecha_expiracion`
    ) VALUES (
        p_id_equipo, p_id_software, p_tipo_licencia, p_clave_licencia, p_fecha_instalacion, p_fecha_expiracion
    );
END$$

-- =============================================================================
-- 6. PROCEDIMIENTO ALMACENADO: sp_ver_software_instalado_tecnico
-- =============================================================================
CREATE PROCEDURE `sp_ver_software_instalado_tecnico`(
    IN p_codigo_inventario VARCHAR(255),
    IN p_nombre_software VARCHAR(255)
)
BEGIN
    SELECT 
        eq.`codigo_inventario` AS `equipo`,
        sw.`nombre` AS `software`,
        sw_inst.`tipo_licencia` AS `tipo_licencia`,
        sw_inst.`clave_licencia` AS `clave_licencia`,
        sw_inst.`fecha_instalacion` AS `instalacion`,
        sw_inst.`fecha_expiracion` AS `expiracion`
    FROM `software_instalado` sw_inst
    INNER JOIN `equipo` eq ON sw_inst.`id_equipo` = eq.`id_equipo`
    INNER JOIN `software` sw ON sw_inst.`id_software` = sw.`id_software`
    WHERE (p_codigo_inventario IS NULL OR eq.`codigo_inventario` = p_codigo_inventario)
      AND (p_nombre_software IS NULL OR sw.`nombre` LIKE CONCAT('%', p_nombre_software, '%'))
    ORDER BY sw_inst.`fecha_instalacion` DESC;
END$$

-- =============================================================================
-- 7. PROCEDIMIENTO ALMACENADO: sp_editar_software_instalado
-- =============================================================================
CREATE PROCEDURE `sp_editar_software_instalado`(
    IN p_id_equipo INT,
    IN p_id_software INT,
    IN p_tipo_licencia VARCHAR(50),
    IN p_clave_licencia VARCHAR(255),
    IN p_fecha_instalacion DATE,
    IN p_fecha_expiracion DATE
)
BEGIN
    -- Validar si el registro existe
    IF NOT EXISTS (SELECT 1 FROM `software_instalado` WHERE `id_equipo` = p_id_equipo AND `id_software` = p_id_software) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No existe un registro de instalación para el equipo y software especificados.';
    END IF;

    -- Validar consistencia de fechas
    IF p_fecha_expiracion IS NOT NULL AND p_fecha_expiracion < p_fecha_instalacion THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La fecha de expiración no puede ser anterior a la fecha de instalación.';
    END IF;

    UPDATE `software_instalado`
    SET `tipo_licencia` = p_tipo_licencia,
        `clave_licencia` = p_clave_licencia,
        `fecha_instalacion` = p_fecha_instalacion,
        `fecha_expiracion` = p_fecha_expiracion
    WHERE `id_equipo` = p_id_equipo AND `id_software` = p_id_software;
END$$

-- =============================================================================
-- 8. PROCEDIMIENTO ALMACENADO: sp_tecnico_registrar_incidencia
-- =============================================================================
CREATE PROCEDURE `sp_tecnico_registrar_incidencia`(
    IN p_id_equipo INT,
    IN p_id_usuario_reporta INT,
    IN p_id_tecnico_recibe INT,
    IN p_descripcion TEXT,
    IN p_prioridad ENUM('baja', 'media', 'alta')
)
BEGIN
    -- Validar equipo
    IF NOT EXISTS (SELECT 1 FROM `equipo` WHERE `id_equipo` = p_id_equipo) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;
    
    -- Validar usuario reporta
    IF NOT EXISTS (SELECT 1 FROM `usuario` WHERE `id_usuario` = p_id_usuario_reporta) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El usuario reportante no existe.';
    END IF;

    -- Validar técnico recibe (opcional)
    IF p_id_tecnico_recibe IS NOT NULL AND NOT EXISTS (SELECT 1 FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico_recibe AND `estado` = TRUE) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico asignado no existe o está inactivo.';
    END IF;

    INSERT INTO `incidencia` (
        `id_equipo`,
        `id_usuario_reporta`,
        `id_tecnico_recibe`,
        `descripcion`,
        `prioridad`,
        `estado`,
        `fecha_creacion`
    ) VALUES (
        p_id_equipo,
        p_id_usuario_reporta,
        p_id_tecnico_recibe,
        p_descripcion,
        p_prioridad,
        'pendiente',
        NOW()
    );
END$$

-- =============================================================================
-- 9. PROCEDIMIENTO ALMACENADO: sp_registrar_seguimiento_tecnico
-- =============================================================================
CREATE PROCEDURE `sp_registrar_seguimiento_tecnico`(
    IN p_id_incidencia INT,
    IN p_id_tecnico INT,
    IN p_diagnostico TEXT,
    IN p_trabajo_realizado TEXT,
    IN p_horas_invertidas DECIMAL(4,2),
    IN p_nuevo_estado ENUM('pendiente', 'en_proceso', 'resuelta', 'cerrada')
)
BEGIN
    DECLARE v_incidencia_exists INT DEFAULT 0;
    DECLARE v_tecnico_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Validar existencia de la incidencia
    SELECT COUNT(*) INTO v_incidencia_exists FROM `incidencia` WHERE `id_incidencia` = p_id_incidencia;
    IF v_incidencia_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La incidencia especificada no existe.';
    END IF;

    -- Validar técnico
    SELECT COUNT(*) INTO v_tecnico_exists FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico AND `estado` = TRUE;
    IF v_tecnico_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico especificado no existe o está inactivo.';
    END IF;

    -- Validar horas invertidas
    IF p_horas_invertidas IS NULL OR p_horas_invertidas <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Las horas invertidas deben ser mayores a 0.';
    END IF;

    START TRANSACTION;
        -- Insertar el seguimiento
        INSERT INTO `seguimiento_incidencia` (
            `id_incidencia`,
            `id_tecnico`,
            `diagnostico`,
            `trabajo_realizado`,
            `horas_invertidas`,
            `fecha`
        ) VALUES (
            p_id_incidencia,
            p_id_tecnico,
            p_diagnostico,
            p_trabajo_realizado,
            p_horas_invertidas,
            NOW()
        );

        -- Actualizar el estado de la incidencia
        IF p_nuevo_estado IS NOT NULL THEN
            IF p_nuevo_estado = 'resuelta' THEN
                UPDATE `incidencia`
                SET `estado` = p_nuevo_estado,
                    `fecha_resolucion` = NOW(),
                    `id_tecnico_recibe` = p_id_tecnico
                WHERE `id_incidencia` = p_id_incidencia;
            ELSE
                UPDATE `incidencia`
                SET `estado` = p_nuevo_estado,
                    `id_tecnico_recibe` = p_id_tecnico
                WHERE `id_incidencia` = p_id_incidencia;
            END IF;
        END IF;
    COMMIT;
END$$

-- =============================================================================
-- 10. PROCEDIMIENTO ALMACENADO: sp_asignar_personal_incidencia
-- =============================================================================
CREATE PROCEDURE `sp_asignar_personal_incidencia`(
    IN p_id_incidencia INT,
    IN p_id_tecnico_asignador INT,
    IN p_id_tecnico_asignado INT
)
BEGIN
    DECLARE v_rango_asignador ENUM('practicante', 'tecnico', 'administrador_sistema');
    DECLARE v_rango_asignado ENUM('practicante', 'tecnico', 'administrador_sistema');

    -- Validar incidencia
    IF NOT EXISTS (SELECT 1 FROM `incidencia` WHERE `id_incidencia` = p_id_incidencia) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La incidencia especificada no existe.';
    END IF;

    -- Obtener rango del asignador
    SELECT `rango` INTO v_rango_asignador FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico_asignador AND `estado` = TRUE;
    IF v_rango_asignador IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico asignador no existe o está inactivo.';
    END IF;

    -- Obtener rango del asignado
    SELECT `rango` INTO v_rango_asignado FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico_asignado AND `estado` = TRUE;
    IF v_rango_asignado IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico a asignar no existe o está inactivo.';
    END IF;

    -- Validar reglas de negocio según el rango del asignador:
    -- 1. Un practicante no puede asignar tickets.
    -- 2. Un técnico solo puede asignar a practicantes o a sí mismo.
    -- 3. Un administrador puede asignar a cualquier técnico/practicante activo.
    IF v_rango_asignador = 'practicante' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Permiso denegado. Los practicantes no pueden realizar asignaciones.';
    ELSEIF v_rango_asignador = 'tecnico' AND p_id_tecnico_asignador <> p_id_tecnico_asignado AND v_rango_asignado <> 'practicante' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Permiso denegado. Un técnico solo puede asignar incidencias a practicantes o a sí mismo.';
    END IF;

    -- Actualizar asignación
    UPDATE `incidencia`
    SET `id_tecnico_recibe` = p_id_tecnico_asignado,
        `estado` = IF(`estado` = 'pendiente', 'en_proceso', `estado`)
    WHERE `id_incidencia` = p_id_incidencia;
END$$

-- =============================================================================
-- 11. PROCEDIMIENTO ALMACENADO: sp_ver_solicitudes
-- =============================================================================
CREATE PROCEDURE `sp_ver_solicitudes`()
BEGIN
    SELECT 
        s.`id_solicitud` AS `Id_Solicitud`,
        CONCAT(u.`nombres`, ' ', u.`apellidos`) AS `Usuario_Solicita`,
        CONCAT(a.`pabellon`, ' - ', a.`numero`) AS `Ambiente`,
        s.`tipo` AS `Tipo`,
        s.`descripcion` AS `Descripcion`,
        s.`estado` AS `Estado`,
        s.`fecha_solicitud` AS `Fecha_Registro`
    FROM `solicitud` s
    INNER JOIN `usuario` u ON s.`id_usuario_solicita` = u.`id_usuario`
    INNER JOIN `ambiente` a ON u.`id_area` = a.`id_ambiente`
    ORDER BY s.`fecha_solicitud` DESC;
END$$

-- =============================================================================
-- 12. PROCEDIMIENTO ALMACENADO: sp_ver_detalle_solicitud
-- =============================================================================
CREATE PROCEDURE `sp_ver_detalle_solicitud`(
    IN p_id_solicitud INT
)
BEGIN
    SELECT 
        CONCAT(u.`nombres`, ' ', u.`apellidos`) AS `Usuario_Solicitante`,
        u.`correo` AS `Correo_Usuario`,
        CONCAT(a.`pabellon`, ' - ', a.`numero`) AS `Ambiente`,
        s.`tipo` AS `Tipo_Solicitud`,
        s.`descripcion` AS `Descripcion`,
        s.`fecha_solicitud` AS `Fecha_Registro`,
        s.`fecha_respuesta` AS `Fecha_Respuesta`,
        s.`estado` AS `Estado_Actual`
    FROM `solicitud` s
    INNER JOIN `usuario` u ON s.`id_usuario_solicita` = u.`id_usuario`
    INNER JOIN `ambiente` a ON u.`id_area` = a.`id_ambiente`
    WHERE s.`id_solicitud` = p_id_solicitud;
END$$

-- =============================================================================
-- 13. FUNCIONES UDF (Disponibles para Practicante y Técnico)
-- =============================================================================

CREATE FUNCTION `fn_tickets_asignados`(p_id_tecnico INT) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `incidencia` 
    WHERE `id_tecnico_recibe` = p_id_tecnico;
    RETURN v_count;
END$$

CREATE FUNCTION `fn_total_incidentes_pendientes`(p_id_tecnico INT) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    IF p_id_tecnico IS NULL THEN
        SELECT COUNT(*) INTO v_count 
        FROM `incidencia` 
        WHERE `estado` = 'pendiente';
    ELSE
        SELECT COUNT(*) INTO v_count 
        FROM `incidencia` 
        WHERE `id_tecnico_recibe` = p_id_tecnico AND `estado` = 'pendiente';
    END IF;
    RETURN v_count;
END$$

CREATE FUNCTION `fn_tickets_resueltos`(p_id_tecnico INT) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM `incidencia` 
    WHERE `id_tecnico_recibe` = p_id_tecnico AND `estado` = 'resuelta';
    RETURN v_count;
END$$

DELIMITER ;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_ver_todos_componentes` $$

CREATE PROCEDURE `sp_ver_todos_componentes`()
BEGIN
    SELECT `componente_id`, `tipo`, `especificaciones_tecnicas`, `estado_fisico`, `asignado_a`
    FROM `vw_componentes_detallados`
    ORDER BY `componente_id` DESC;
END$$

DELIMITER ;
