USE `soportefisi`;

DELIMITER $$

-- =============================================================================
-- 1. PROCEDIMIENTO ALMACENADO: sp_listar_equipos_disponibles
-- =============================================================================

CREATE PROCEDURE `sp_listar_equipos`(
    IN p_id_ambiente INT,
    IN p_tipo VARCHAR(50),
    IN p_estado VARCHAR(50)
)
BEGIN
    SELECT 
        e.`codigo_inventario`,
        e.`tipo`,
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




DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_ver_incidencias` $$

CREATE PROCEDURE `sp_ver_incidencias`(
    IN pi_id_sesion INT -- ID único de la sesión activa (usuario o técnico)
)
BEGIN
    DECLARE v_rol_detectado VARCHAR(50) DEFAULT NULL;

    -- 1. Buscar si el ID pertenece a un Técnico/Practicante/Administrador
    -- Ahora leemos el ENUM 'rango' directamente de la tabla tecnico
    SELECT `rango` INTO v_rol_detectado
    FROM `tecnico`
    WHERE `id_tecnico` = pi_id_sesion AND `estado` = TRUE;

    -- 2. Si no se encontró en 'tecnico', buscar en 'usuario' (empleado o jefe)
    IF v_rol_detectado IS NULL THEN
        SELECT `cargo` INTO v_rol_detectado 
        FROM `usuario` 
        WHERE `id_usuario` = pi_id_sesion AND `estado` = TRUE;
    END IF;

    -- 3. Si sigue siendo NULL, el usuario no existe o está inactivo
    IF v_rol_detectado IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Sesión no identificada o usuario inactivo.';
    ELSE
        -- 4. Mostrar incidencias aplicando las reglas del diagrama de casos de uso
        SELECT 
            inc.`id_incidencia`,
            eq.`codigo_inventario` AS `equipo_codigo`,
            CONCAT(u_rep.`nombres`, ' ', u_rep.`apellidos`) AS `usuario_reporta_nombre`,
            IFNULL(CONCAT(t_rec.`nombres`, ' ', t_rec.`apellidos`), 'Sin asignar') AS `tecnico_asignado`,
            inc.`descripcion`,
            inc.`prioridad`,
            inc.`estado`,
            inc.`fecha_creacion` AS `fecha`
        FROM `incidencia` inc
        LEFT JOIN `equipo` eq ON inc.`id_equipo` = eq.`id_equipo`
        INNER JOIN `usuario` u_rep ON inc.`id_usuario_reporta` = u_rep.`id_usuario`
        LEFT JOIN `tecnico` t_rec ON inc.`id_tecnico_recibe` = t_rec.`id_tecnico`
        WHERE 
            -- Regla: Personal de soporte (practicante, tecnico, administrador_sistema) ve TODO
            (v_rol_detectado IN ('practicante', 'tecnico', 'administrador_sistema'))
            
            -- Regla: Usuarios de oficina (empleado, jefe) solo ven lo que ellos reportaron
            OR (v_rol_detectado IN ('empleado', 'jefe') AND inc.`id_usuario_reporta` = pi_id_sesion)
        ORDER BY inc.`fecha_creacion` DESC;
    END IF;
END$$

DELIMITER ;





DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_ver_software_instalado` $$

CREATE PROCEDURE `sp_ver_software_instalado`(
    IN pi_id_sesion INT,               -- ID de sesión activa
    IN pi_codigo_inventario VARCHAR(255) -- Código de la PC a auditar
)
BEGIN
    DECLARE v_rango_soporte ENUM('practicante', 'tecnico', 'administrador_sistema') DEFAULT NULL;

    -- 1. Obtener el rango directamente del ENUM de la tabla tecnico
    SELECT `rango` INTO v_rango_soporte
    FROM `tecnico`
    WHERE `id_tecnico` = pi_id_sesion AND `estado` = TRUE;

    -- 2. Si no tiene rango de soporte, denegar el acceso (Usuarios de oficina no pueden ver software)
    IF v_rango_soporte IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acceso denegado: Su rol no tiene privilegios para visualizar el software instalado.';
    ELSE
        -- 3. Validar si el equipo de cómputo existe en el inventario de la FISI
        IF NOT EXISTS (SELECT 1 FROM `equipo` WHERE `codigo_inventario` = pi_codigo_inventario) THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El código de inventario del equipo no existe.';
        ELSE
            -- 4. Mostrar el listado detallado de software
            SELECT 
                eq.`codigo_inventario` AS `Codigo_Equipo`,
                eq.`tipo` AS `Tipo_Equipo`,
                sw.`nombre` AS `Nombre_Software`,
                sw_inst.`tipo_licencia` AS `Tipo_Licencia`,
                sw_inst.`clave_licencia` AS `Clave_Licencia`,
                sw_inst.`fecha_instalacion` AS `Fecha_Instalacion`,
                sw_inst.`fecha_expiracion` AS `Fecha_Expiracion`
            FROM `software_instalado` sw_inst
            INNER JOIN `equipo` eq ON sw_inst.`id_equipo` = eq.`id_equipo`
            INNER JOIN `software` sw ON sw_inst.`id_software` = sw.`id_software`
            WHERE eq.`codigo_inventario` = pi_codigo_inventario
            ORDER BY sw_inst.`fecha_instalacion` DESC;
        END IF;
    END IF;
END$$

-- =============================================================================
-- 9. PROCEDIMIENTO ALMACENADO: sp_ver_detalle_equipo
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_ver_detalle_equipo` $$

CREATE PROCEDURE `sp_ver_detalle_equipo`(
    IN p_id_equipo INT
)
BEGIN
    SELECT 
        `codigo_inventario` AS `codigo`,
        `tipo`,
        `tipo_origen` AS `origen`,
        `marca`,
        `estado`
    FROM `equipo`
    WHERE `id_equipo` = p_id_equipo;
END$$

-- =============================================================================
-- 10. PROCEDIMIENTO ALMACENADO: sp_ver_detalle_incidencia
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_ver_detalle_incidencia` $$

CREATE PROCEDURE `sp_ver_detalle_incidencia`(
    IN p_id_incidencia INT
)
BEGIN
    SELECT 
        eq.`codigo_inventario` AS `equipo`,
        CONCAT(u_rep.`nombres`, ' ', u_rep.`apellidos`) AS `reportado_por`,
        u_rep.`correo` AS `correo_reportante`,
        IFNULL(CONCAT(t_rec.`nombres`, ' ', t_rec.`apellidos`), 'Sin asignar') AS `tecnico_asignado`,
        inc.`prioridad`,
        inc.`estado`,
        inc.`descripcion`
    FROM `incidencia` inc
    LEFT JOIN `equipo` eq ON inc.`id_equipo` = eq.`id_equipo`
    INNER JOIN `usuario` u_rep ON inc.`id_usuario_reporta` = u_rep.`id_usuario`
    LEFT JOIN `tecnico` t_rec ON inc.`id_tecnico_recibe` = t_rec.`id_tecnico`
    WHERE inc.`id_incidencia` = p_id_incidencia;
END$$

-- =============================================================================
-- 11. PROCEDIMIENTO ALMACENADO: sp_registrar_seguimiento_incidencia
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_registrar_seguimiento_incidencia` $$

CREATE PROCEDURE `sp_registrar_seguimiento_incidencia`(
    IN p_id_incidencia INT,
    IN p_id_tecnico INT,
    IN p_diagnostico TEXT,
    IN p_trabajo_realizado TEXT,
    IN p_horas_invertidas DECIMAL(4,2),
    IN p_id_componente_cambiado INT,
    IN p_nuevo_estado VARCHAR(50)
)
BEGIN
    DECLARE v_incidencia_exists INT DEFAULT 0;
    DECLARE v_tecnico_exists INT DEFAULT 0;
    DECLARE v_componente_exists INT DEFAULT 0;

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

    -- Validar existencia del técnico
    SELECT COUNT(*) INTO v_tecnico_exists FROM `tecnico` WHERE `id_tecnico` = p_id_tecnico AND `estado` = TRUE;
    IF v_tecnico_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico especificado no existe o está inactivo.';
    END IF;

    -- Validar que las horas invertidas sean válidas
    IF p_horas_invertidas IS NULL OR p_horas_invertidas <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Las horas invertidas deben ser mayores a 0.';
    END IF;

    -- Validar si se especificó un componente cambiado
    IF p_id_componente_cambiado IS NOT NULL THEN
        SELECT COUNT(*) INTO v_componente_exists FROM `componente` WHERE `id_componente` = p_id_componente_cambiado;
        IF v_componente_exists = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Error: El componente especificado no existe.';
        END IF;
    END IF;

    -- Validar que el nuevo estado de la incidencia (si se envía) sea válido
    IF p_nuevo_estado IS NOT NULL AND p_nuevo_estado NOT IN ('pendiente', 'en_proceso', 'resuelta', 'cerrada') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El nuevo estado especificado no es válido (Debe ser: pendiente, en_proceso, resuelta o cerrada).';
    END IF;

    -- Registrar el seguimiento en una transacción
    START TRANSACTION;
        
        -- Insertar el seguimiento
        INSERT INTO `seguimiento_incidencia` (
            `id_incidencia`,
            `id_tecnico`,
            `diagnostico`,
            `trabajo_realizado`,
            `horas_invertidas`,
            `id_componente_cambiado`,
            `fecha`
        ) VALUES (
            p_id_incidencia,
            p_id_tecnico,
            p_diagnostico,
            p_trabajo_realizado,
            p_horas_invertidas,
            p_id_componente_cambiado,
            NOW()
        );

        -- Si se proporcionó un nuevo estado, actualizar el estado de la incidencia
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
-- 12. PROCEDIMIENTO ALMACENADO: sp_ver_seguimientos_incidencia
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_ver_seguimientos_incidencia` $$

CREATE PROCEDURE `sp_ver_seguimientos_incidencia`(
    IN p_id_incidencia INT
)
BEGIN
    -- Validar existencia de la incidencia
    IF NOT EXISTS (SELECT 1 FROM `incidencia` WHERE `id_incidencia` = p_id_incidencia) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La incidencia especificada no existe.';
    ELSE
        SELECT 
            s.`id_seguimiento`,
            s.`fecha`,
            CONCAT(t.`nombres`, ' ', t.`apellidos`) AS `tecnico`,
            s.`diagnostico`,
            s.`trabajo_realizado`,
            s.`horas_invertidas`,
            s.`id_componente_cambiado`
        FROM `seguimiento_incidencia` s
        INNER JOIN `tecnico` t ON s.`id_tecnico` = t.`id_tecnico`
        WHERE s.`id_incidencia` = p_id_incidencia
        ORDER BY s.`fecha` DESC;
    END IF;
END$$

-- =============================================================================
-- 13. PROCEDIMIENTO ALMACENADO: sp_registrar_incidencia_tecnico
-- =============================================================================

DROP PROCEDURE IF EXISTS `sp_registrar_incidencia_tecnico` $$

CREATE PROCEDURE `sp_registrar_incidencia_tecnico`(
    IN p_id_tecnico INT,
    IN p_id_equipo INT,
    IN p_prioridad ENUM('baja', 'media', 'alta'),
    IN p_descripcion TEXT
)
BEGIN
    DECLARE v_nombres VARCHAR(255) DEFAULT NULL;
    DECLARE v_apellidos VARCHAR(255) DEFAULT NULL;
    DECLARE v_correo VARCHAR(255) DEFAULT NULL;
    DECLARE v_telefono VARCHAR(255) DEFAULT NULL;
    DECLARE v_contrasena VARCHAR(255) DEFAULT NULL;
    DECLARE v_id_usuario INT DEFAULT NULL;
    DECLARE v_id_area INT DEFAULT NULL;
    DECLARE v_equipo_exists INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- 1. Validar existencia del técnico/practicante y obtener sus datos
    SELECT `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`
    INTO v_nombres, v_apellidos, v_correo, v_telefono, v_contrasena
    FROM `tecnico`
    WHERE `id_tecnico` = p_id_tecnico AND `estado` = TRUE;

    IF v_nombres IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico/practicante especificado no existe o está inactivo.';
    END IF;

    -- 2. Validar existencia del equipo
    SELECT COUNT(*) INTO v_equipo_exists FROM `equipo` WHERE `id_equipo` = p_id_equipo;
    IF v_equipo_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El equipo especificado no existe.';
    END IF;

    -- 3. Buscar si el técnico ya tiene una cuenta de usuario
    -- Primero por correo
    SELECT `id_usuario` INTO v_id_usuario
    FROM `usuario`
    WHERE `correo` = v_correo
    LIMIT 1;

    -- Si no se encuentra por correo, por nombres y apellidos
    IF v_id_usuario IS NULL THEN
        SELECT `id_usuario` INTO v_id_usuario
        FROM `usuario`
        WHERE `nombres` = v_nombres AND `apellidos` = v_apellidos
        LIMIT 1;
    END IF;

    -- Ejecutar inserciones/actualizaciones en una transacción
    START TRANSACTION;
        -- En caso de encontrar el usuario, nos aseguramos de que esté activo (estado = TRUE)
        -- Si no existe, creamos un nuevo usuario para este técnico
        IF v_id_usuario IS NOT NULL THEN
            UPDATE `usuario` SET `estado` = TRUE WHERE `id_usuario` = v_id_usuario;
        ELSE
            -- Obtener o crear un ambiente (área) por defecto para el usuario técnico
            SELECT `id_ambiente` INTO v_id_area 
            FROM `ambiente` 
            WHERE `nombre` IN ('Soporte', 'Sistemas', 'TI', 'Tecnología de la Información') 
            LIMIT 1;

            IF v_id_area IS NULL THEN
                SELECT `id_ambiente` INTO v_id_area 
                FROM `ambiente` 
                LIMIT 1;
            END IF;

            IF v_id_area IS NULL THEN
                INSERT INTO `ambiente` (`numero`, `nombre`, `pabellon`, `piso`) VALUES (999, 'Soporte TI', 'Antiguo', 1);
                SET v_id_area = LAST_INSERT_ID();
            END IF;

            -- Crear el usuario
            INSERT INTO `usuario` (
                `id_area`,
                `cargo`,
                `nombres`,
                `apellidos`,
                `correo`,
                `telefono`,
                `contrasena`,
                `estado`
            ) VALUES (
                v_id_area,
                'empleado',
                v_nombres,
                v_apellidos,
                v_correo,
                v_telefono,
                v_contrasena,
                TRUE
            );
            SET v_id_usuario = LAST_INSERT_ID();
        END IF;

        -- 4. Registrar la incidencia utilizando el usuario del técnico
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
            v_id_usuario,
            p_id_tecnico,
            p_descripcion,
            p_prioridad,
            'pendiente',
            NOW()
        );
    COMMIT;
END$$

DELIMITER ;

-- =============================================================================
-- FUNCIONES UDF (Disponibles para Practicante y Técnico)
-- =============================================================================

DROP FUNCTION IF EXISTS `fn_tickets_asignados`;
DROP FUNCTION IF EXISTS `fn_total_incidentes_pendientes`;
DROP FUNCTION IF EXISTS `fn_tickets_resueltos`;

DELIMITER $$

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
    SELECT `componente_id`, `tipo`, `especificaciones_tecnicas`, `estado_fisico`, `asignado_a`, `id_equipo`, `id_ambiente`
    FROM `vw_componentes_detallados`
    ORDER BY `componente_id` DESC;
END$$

DELIMITER ;




