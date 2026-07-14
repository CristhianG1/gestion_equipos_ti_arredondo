

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
            inc.`id_incidencia` AS `ID`,
            eq.`codigo_inventario` AS `Codigo_Equipo`,
            CONCAT(u_rep.`nombres`, ' ', u_rep.`apellidos`) AS `Usuario_Reporta`,
            IFNULL(CONCAT(t_rec.`nombres`, ' ', t_rec.`apellidos`), 'Sin asignar') AS `Tecnico_Asignado`,
            inc.`descripcion` AS `Descripcion`,
            inc.`prioridad` AS `Prioridad`,
            inc.`estado` AS `Estado`,
            inc.`fecha_creacion` AS `Fecha`
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

DELIMITER ;


DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_asignar_tecnico_incidencia` $$

CREATE PROCEDURE `sp_asignar_tecnico_incidencia`(
    IN pi_id_sesion INT,          -- ID de quien realiza la asignación (Debe ser admin o técnico)
    IN pi_id_incidencia INT,      -- ID de la incidencia a asignar
    IN pi_id_tecnico_asignado INT -- ID del técnico que resolverá el problema
)
BEGIN
    DECLARE v_rango_sesion ENUM('practicante', 'tecnico', 'administrador_sistema') DEFAULT NULL;
    DECLARE v_rango_asignado ENUM('practicante', 'tecnico', 'administrador_sistema') DEFAULT NULL;

    -- 1. Validar que el usuario en sesión sea Administrador o Técnico (un Practicante no debería reasignar a otros)
    SELECT `rango` INTO v_rango_sesion 
    FROM `tecnico` 
    WHERE `id_tecnico` = pi_id_sesion AND `estado` = TRUE;

    IF v_rango_sesion IS NULL OR v_rango_sesion = 'practicante' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acceso denegado: Solo administradores o técnicos pueden asignar tareas.';
    END IF;

    -- 2. Validar que el técnico asignado exista y esté activo
    SELECT `rango` INTO v_rango_asignado 
    FROM `tecnico` 
    WHERE `id_tecnico` = pi_id_tecnico_asignado AND `estado` = TRUE;

    IF v_rango_asignado IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: El técnico al que deseas asignar no existe o está inactivo.';
    END IF;

    -- 3. Validar que la incidencia exista y no esté resuelta/cerrada ya
    IF NOT EXISTS (SELECT 1 FROM `incidencia` WHERE `id_incidencia` = pi_id_incidencia AND `estado` IN ('pendiente', 'en_proceso')) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La incidencia no existe o ya ha sido resuelta/cerrada.';
    END IF;

    -- 4. Asignar y cambiar estado
    UPDATE `incidencia`
    SET `id_tecnico_recibe` = pi_id_tecnico_asignado,
        `estado` = 'en_proceso'
    WHERE `id_incidencia` = pi_id_incidencia;

    SELECT CONCAT('Incidencia asignada correctamente al técnico con ID: ', pi_id_tecnico_asignado) AS `Resultado`;
END$$

DELIMITER ;


DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_cerrar_incidencia_usuario` $$

CREATE PROCEDURE `sp_cerrar_incidencia_usuario`(
    IN pi_id_sesion INT,       -- ID del usuario logueado
    IN pi_id_incidencia INT    -- ID de la incidencia a cerrar
)
BEGIN
    -- 1. Validar que la incidencia pertenezca al usuario en sesión y esté en estado 'resuelta'
    IF NOT EXISTS (
        SELECT 1 FROM `incidencia` 
        WHERE `id_incidencia` = pi_id_incidencia 
          AND `id_usuario_reporta` = pi_id_sesion
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acceso denegado: Solo puedes dar conformidad a incidencias reportadas por ti.';
    END IF;

    -- 2. Validar que la incidencia esté efectivamente resuelta antes de cerrarse
    IF NOT EXISTS (
        SELECT 1 FROM `incidencia` 
        WHERE `id_incidencia` = pi_id_incidencia AND `estado` = 'resuelta'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: No se puede cerrar una incidencia que no ha sido marcada como resuelta por el técnico.';
    END IF;

    -- 3. Cerrar incidencia oficialmente
    UPDATE `incidencia`
    SET `estado` = 'cerrada'
    WHERE `id_incidencia` = pi_id_incidencia;

    SELECT 'La incidencia ha sido cerrada con la conformidad del usuario.' AS `Resultado`;
END$$

DELIMITER ;

DELIMITER $$

DROP PROCEDURE IF EXISTS `sp_crear_software_catalogo` $$

CREATE PROCEDURE `sp_crear_software_catalogo`(
    IN pi_id_sesion INT,       -- ID del Técnico/Admin logueado
    IN pi_nombre_software VARCHAR(255)
)
BEGIN
    DECLARE v_rango_sesion ENUM('practicante', 'tecnico', 'administrador_sistema') DEFAULT NULL;

    -- 1. Validar privilegios: Practicante no tiene caso de uso para insertar software base en el catálogo, solo técnico/admin
    SELECT `rango` INTO v_rango_sesion 
    FROM `tecnico` 
    WHERE `id_tecnico` = pi_id_sesion AND `estado` = TRUE;

    IF v_rango_sesion IS NULL OR v_rango_sesion = 'practicante' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Acceso denegado: Su rol no tiene permisos para añadir software al catálogo general.';
    END IF;

    -- 2. Validar que el software no esté duplicado
    IF EXISTS (SELECT 1 FROM `software` WHERE LOWER(`nombre`) = LOWER(TRIM(pi_nombre_software))) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: Este software ya está registrado en el catálogo maestro.';
    END IF;

    -- 3. Insertar nuevo software
    INSERT INTO `software` (`nombre`) VALUES (TRIM(pi_nombre_software));
    
    SELECT LAST_INSERT_ID() AS `id_software_creado`, 'Software añadido con éxito al catálogo.' AS `Mensaje`;
END$$

DELIMITER ;


