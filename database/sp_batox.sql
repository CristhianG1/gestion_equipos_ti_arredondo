USE `soportefisi`;

DELIMITER $$

-- =============================================================================
-- 1. PROCEDIMIENTO ALMACENADO: sp_listar_equipos_disponibles
-- =============================================================================

CREATE PROCEDURE `sp_listar_equipos_disponibles`(
    IN p_id_ambiente INT,
    IN p_tipo VARCHAR(50),
    IN p_estado VARCHAR(50)
)
BEGIN
    SELECT 
        e.`codigo_inventario`,
        e.`tipo`,
        e.`marca`,
        e.`estado`,
        CONCAT(u.`nombres`, ' ', u.`apellidos`) AS `usuario_nombre_completo`,
        CONCAT(a.`pabellon`, ' - ', a.`numero`) AS `nombre_ambiente`
    FROM `equipo` e
    INNER JOIN `ambiente` a ON e.`id_ambiente` = a.`id_ambiente`
    LEFT JOIN `usuario` u ON e.`id_usuario` = u.`id_usuario`
    WHERE e.`estado` != 'baja'
      AND (p_id_ambiente IS NULL OR e.`id_ambiente` = p_id_ambiente)
      AND (p_tipo IS NULL OR e.`tipo` = p_tipo)
      AND (p_estado IS NULL OR e.`estado` = p_estado);
END$$

-- =============================================================================
-- 2. PROCEDIMIENTO ALMACENADO: sp_listar_componentes
-- =============================================================================

CREATE PROCEDURE `sp_listar_componentes`(
    IN p_id_equipo INT,
    IN p_id_ambiente INT,
    IN p_estado_componente VARCHAR(50)
)
BEGIN
    SELECT 
        c.`id_componente`,
        CASE 
            WHEN p.`id_componente` IS NOT NULL THEN 'Procesador'
            WHEN ram.`id_componente` IS NOT NULL THEN 'Memoria RAM'
            WHEN alm.`id_componente` IS NOT NULL THEN 'Almacenamiento'
            WHEN gpu.`id_componente` IS NOT NULL THEN 'Tarjeta Gráfica'
            WHEN mb.`id_componente` IS NOT NULL THEN 'Placa Madre'
            WHEN fp.`id_componente` IS NOT NULL THEN 'Fuente de Poder'
            ELSE 'Otro'
        END AS `tipo_componente`,
        COALESCE(p.`marca`, ram.`marca`, alm.`marca`, gpu.`marca`, mb.`marca`, fp.`marca`) AS `marca`,
        CASE 
            WHEN p.`id_componente` IS NOT NULL THEN p.`modelo`
            WHEN ram.`id_componente` IS NOT NULL THEN CONCAT(ram.`capacidad_gb`, 'GB ', ram.`tipo_ddr`)
            WHEN alm.`id_componente` IS NOT NULL THEN CONCAT(alm.`modelo`, ' (', alm.`capacidad_gb`, 'GB ', alm.`tipo`, ')')
            WHEN gpu.`id_componente` IS NOT NULL THEN CONCAT(gpu.`modelo`, ' (', gpu.`vram_gb`, 'GB VRAM)')
            WHEN mb.`id_componente` IS NOT NULL THEN CONCAT(mb.`modelo`, ' Socket ', mb.`socket`, ' ', mb.`factor_forma`)
            WHEN fp.`id_componente` IS NOT NULL THEN CONCAT(fp.`modelo`, ' ', fp.`potencia_watts`, 'W')
            ELSE NULL
        END AS `especificaciones`,
        c.`estado_componente`,
        e.`codigo_inventario` AS `equipo_codigo`,
        CONCAT(a.`pabellon`, ' - ', a.`numero`) AS `nombre_ambiente`
    FROM `componente` c
    LEFT JOIN `equipo` e ON c.`id_equipo` = e.`id_equipo`
    LEFT JOIN `ambiente` a ON c.`id_ambiente` = a.`id_ambiente`
    LEFT JOIN `procesador` p ON c.`id_componente` = p.`id_componente`
    LEFT JOIN `memoria_ram` ram ON c.`id_componente` = ram.`id_componente`
    LEFT JOIN `almacenamiento` alm ON c.`id_componente` = alm.`id_componente`
    LEFT JOIN `tarjeta_grafica` gpu ON c.`id_componente` = gpu.`id_componente`
    LEFT JOIN `placa_madre` mb ON c.`id_componente` = mb.`id_componente`
    LEFT JOIN `fuente_poder` fp ON c.`id_componente` = fp.`id_componente`
    WHERE c.`estado_componente` != 'baja'
      AND (p_id_equipo IS NULL OR c.`id_equipo` = p_id_equipo)
      AND (p_id_ambiente IS NULL OR c.`id_ambiente` = p_id_ambiente)
      AND (p_estado_componente IS NULL OR c.`estado_componente` = p_estado_componente);
END$$

-- =============================================================================
-- 3. PROCEDIMIENTO ALMACENADO: sp_listar_software
-- =============================================================================

CREATE PROCEDURE `sp_listar_software`(
    IN p_nombre VARCHAR(255)
)
BEGIN
    SELECT 
        `id_software`,
        `nombre`
    FROM `software`
    WHERE (p_nombre IS NULL OR `nombre` LIKE CONCAT('%', p_nombre, '%'));
END$$

-- =============================================================================
-- 4. PROCEDIMIENTO ALMACENADO: sp_crear_software
-- =============================================================================

CREATE PROCEDURE `sp_crear_software`(
    IN p_nombre VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Ya existe un software registrado con ese nombre.';
    END;

    INSERT INTO `software` (`nombre`) VALUES (p_nombre);
END$$

-- =============================================================================
-- 5. PROCEDIMIENTO ALMACENADO: sp_actualizar_software
-- =============================================================================

CREATE PROCEDURE `sp_actualizar_software`(
    IN p_id_software INT,
    IN p_nombre VARCHAR(255)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Ya existe un software registrado con ese nombre.';
    END;

    -- Validar si el software existe
    SELECT COUNT(*) INTO v_exists FROM `software` WHERE `id_software` = p_id_software;

    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El software especificado no existe.';
    END IF;

    UPDATE `software` 
    SET `nombre` = p_nombre 
    WHERE `id_software` = p_id_software;
END$$

-- =============================================================================
-- 6. PROCEDIMIENTO ALMACENADO: sp_crear_software_instalado
-- =============================================================================
CREATE PROCEDURE `sp_crear_software_instalado`(
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

    -- Validar que la combinación equipo-software no esté duplicada
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
-- 7. PROCEDIMIENTO ALMACENADO: sp_actualizar_software_instalado
-- =============================================================================

CREATE PROCEDURE `sp_actualizar_software_instalado`(
    IN p_id_software_instalado INT,
    IN p_tipo_licencia VARCHAR(50),
    IN p_clave_licencia VARCHAR(255),
    IN p_fecha_instalacion DATE,
    IN p_fecha_expiracion DATE
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    -- Validar si el registro existe
    SELECT COUNT(*) INTO v_exists FROM `software_instalado` WHERE `id_software_instalado` = p_id_software_instalado;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El registro de instalación de software especificado no existe.';
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
    WHERE `id_software_instalado` = p_id_software_instalado;
END$$

-- =============================================================================
-- 8. PROCEDIMIENTO ALMACENADO: sp_eliminar_software_instalado
-- =============================================================================

CREATE PROCEDURE `sp_eliminar_software_instalado`(
    IN p_id_software_instalado INT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;

    -- Validar si el registro existe
    SELECT COUNT(*) INTO v_exists FROM `software_instalado` WHERE `id_software_instalado` = p_id_software_instalado;
    IF v_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El registro de instalación de software especificado no existe.';
    END IF;

    DELETE FROM `software_instalado` WHERE `id_software_instalado` = p_id_software_instalado;
END$$

DELIMITER ;