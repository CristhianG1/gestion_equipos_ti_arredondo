DELIMITER $$
CREATE PROCEDURE `sp_registrar_solicitud` (
    IN p_id_usuario INT,
    IN p_tipo_solicitud ENUM('remodelacion', 'mejora', 'reemplazo'),
    IN p_descripcion VARCHAR(250)
)
BEGIN
    INSERT INTO solicitud (id_usuario_solicita, tipo, descripcion, fecha_solicitud)
    VALUES (p_id_usuario, p_tipo_solicitud, p_descripcion, NOW());
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE `sp_obtener_solicitudes_por_usuario` (
    IN p_id_usuario INT
)
BEGIN
    SELECT * FROM solicitud WHERE id_usuario_solicita = p_id_usuario;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE `sp_actualizar_estado_solicitud` (
    IN p_id_solicitud INT,
    IN p_nuevo_estado ENUM('pendiente', 'aprobada', 'rechazada')
)
BEGIN
    UPDATE solicitud SET estado = p_nuevo_estado WHERE id_solicitud = p_id_solicitud;
END $$
DELIMITER ;

CREATE OR REPLACE VIEW `vw_revisar_incidentes_tecnico` AS
SELECT 
    `id_incidencia`,
    `id_equipo`,
    `descripcion`,
    `estado`
FROM `incidencia`;


DELIMITER $$                                                                             
CREATE PROCEDURE `sp_ver_incidencias_practicantes` ()                                    
    BEGIN                                                                                    
        SELECT                                                                               
            i.id_incidencia,                                                                 
            e.codigo_inventario,                                                             
            e.tipo AS equipo_tipo,                                                           
            CONCAT(p.nombres, ' ', p.apellidos) AS practicante_nombre,                       
            i.descripcion,                                                                   
            i.prioridad,                                                                     
            i.estado,                                                                        
            i.fecha_creacion                                                                 
        FROM incidencia i                                                                    
        JOIN equipo e ON i.id_equipo = e.id_equipo                                           
        JOIN tecnico p ON i.id_tecnico_recibe = p.id_tecnico                                 
        JOIN rango_tecnico r ON p.id_rango = r.id_rango                                      
        WHERE r.nombre = 'practicante'                                                       
        ORDER BY i.fecha_creacion DESC;                                                      
    END $$                                                                                   
    DELIMITER ;

    DELIMITER $$                                                                             
    CREATE PROCEDURE `sp_ver_historial_tecnico` (                                            
        IN p_id_tecnico INT                                                                  
    )                                                                                        
    BEGIN                                                                                    
        SELECT                                                                               
            i.id_incidencia,                                                                 
            e.codigo_inventario,                                                             
            e.tipo AS equipo_tipo,                                                           
            i.descripcion,                                                                   
            i.prioridad,                                                                     
            i.estado,                                                                        
            i.fecha_creacion,                                                                
            i.fecha_resolucion                                                               
        FROM incidencia i                                                                    
        JOIN equipo e ON i.id_equipo = e.id_equipo                                           
        WHERE i.id_tecnico_recibe = p_id_tecnico                                             
          AND i.estado IN ('resuelta', 'cerrada')                                            
        ORDER BY i.fecha_resolucion DESC;                                                    
    END $$                                                                                   
    DELIMITER ;

    DELIMITER $$                                                                             
    CREATE PROCEDURE `sp_ver_incidencias_por_estado` (                                       
        IN p_grupo_estado ENUM('pendientes', 'realizadas')                                   
    )                                                                                        
    BEGIN                                                                                    
        SELECT                                                                               
            i.id_incidencia,                                                                 
            e.codigo_inventario,                                                             
            e.tipo AS equipo_tipo,                                                           
            COALESCE(CONCAT(t.nombres, ' ', t.apellidos), 'Sin asignar') AS tecnico_asignado,
            i.descripcion,                                                                   
            i.prioridad,                                                                     
            i.estado,                                                                        
            i.fecha_creacion                                                                 
        FROM incidencia i                                                                    
        JOIN equipo e ON i.id_equipo = e.id_equipo                                           
        LEFT JOIN tecnico t ON i.id_tecnico_recibe = t.id_tecnico                            
        WHERE                                                                                
            (p_grupo_estado = 'pendientes' AND i.estado IN ('pendiente', 'en_proceso',       
  'por_confirmar')) OR                                                                       
            (p_grupo_estado = 'realizadas' AND i.estado IN ('resuelta', 'cerrada'))          
        ORDER BY i.fecha_creacion DESC;                                                      
    END $$                                                                                   
    DELIMITER ;

-- Asignar laptops a usuarios o ambientes. Valida que el equipo a asignar sea  
--   obligatoriamente de tipo  'laptop' , cierra la asignación anterior en el historial y       
--   actualiza tanto el estado del equipo como el historial en una transacción.  
    DELIMITER $$                                                                             
    CREATE PROCEDURE `sp_asignar_laptop`(                                                    
        IN p_id_equipo INT,                                                                  
        IN p_id_usuario INT,                                                                 
        IN p_id_ambiente INT                                                                 
    )                                                                                        
    BEGIN                                                                                    
        DECLARE v_tipo VARCHAR(50);                                                          
        DECLARE EXIT HANDLER FOR SQLEXCEPTION                                                
        BEGIN                                                                                
            ROLLBACK;                                                                        
            RESIGNAL;                                                                        
        END;                                                                                 
                                                                                             
        -- Validar que el equipo exista y sea una laptop                                     
        SELECT tipo INTO v_tipo FROM equipo WHERE id_equipo = p_id_equipo;                   
                                                                                             
        IF v_tipo IS NULL THEN                                                               
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El equipo no existe.';        
        ELSEIF v_tipo <> 'laptop' THEN                                                       
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Los técnicos solo pueden      
  asignar laptops.';                                                                         
        END IF;                                                                              
                                                                                             
        START TRANSACTION;                                                                   
            -- 1. Cerrar asignación anterior en historial (fecha_fin = NOW())                
            UPDATE asignacion_historial                                                      
            SET fecha_fin = NOW()                                                            
            WHERE id_equipo = p_id_equipo AND fecha_fin IS NULL;                             
                                                                                             
            -- 2. Insertar nueva asignación en historial                                     
            INSERT INTO asignacion_historial (id_equipo, id_usuario, id_ambiente,            
  fecha_inicio)                                                                              
            VALUES (p_id_equipo, p_id_usuario, p_id_ambiente, NOW());                        
                                                                                             
            -- 3. Actualizar la tabla equipo con su asignación actual                        
            UPDATE equipo                                                                    
            SET id_usuario = p_id_usuario,                                                   
                id_ambiente = p_id_ambiente                                                  
            WHERE id_equipo = p_id_equipo;                                                   
        COMMIT;                                                                              
    END $$                                                                                   
    DELIMITER ;

DELIMITER $$                                                                             
                                                                                             
CREATE PROCEDURE `sp_insertar_equipo`(                                                   
    IN p_codigo_inventario VARCHAR(255),                                                 
    IN p_tipo ENUM('laptop', 'pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor',
'otro'),                                                                                   
    IN p_tipo_origen ENUM('ensamblado_facultad', 'comprado_ensamblado'),                 
    IN p_marca VARCHAR(255),                                                             
    IN p_estado ENUM('operativo', 'mantenimiento', 'baja'),                              
    IN p_id_usuario INT,                                                                 
    IN p_id_ambiente INT                                                                 
)                                                                                        
BEGIN                                                                                    
    DECLARE v_id_equipo INT;                                                             
    DECLARE EXIT HANDLER FOR SQLEXCEPTION                                                
    BEGIN                                                                                
        ROLLBACK;                                                                        
        RESIGNAL;                                                                        
    END;                                                                                 
                                                                                            
    -- Validar que el código no esté duplicado                                           
    IF EXISTS(SELECT 1 FROM equipo WHERE codigo_inventario = p_codigo_inventario) THEN   
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El código de inventario ya    
está registrado.';                                                                         
    END IF;                                                                              
                                                                                            
    START TRANSACTION;                                                                   
        -- 1. Registrar equipo                                                           
        INSERT INTO equipo (codigo_inventario, tipo, tipo_origen, marca, estado,         
id_usuario, id_ambiente)                                                                   
        VALUES (p_codigo_inventario, p_tipo, p_tipo_origen, p_marca, COALESCE(p_estado,  
'operativo'), p_id_usuario, p_id_ambiente);                                                
                                                                                            
        SET v_id_equipo = LAST_INSERT_ID();                                              
                                                                                            
        -- 2. Crear la asignación inicial en el historial                                
        INSERT INTO asignacion_historial (id_equipo, id_usuario, id_ambiente,            
fecha_inicio)                                                                              
        VALUES (v_id_equipo, p_id_usuario, p_id_ambiente, NOW());                        
    COMMIT;                                                                              
END$$                                                                                    
                                                                                             
DELIMITER ;



DELIMITER $$                                                                             
                                                                                             
CREATE PROCEDURE `sp_actualizar_equipo`(                                                 
    IN p_id_equipo INT,                                                                  
    IN p_codigo_inventario VARCHAR(255),                                                 
    IN p_tipo ENUM('laptop', 'pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor',
'otro'),                                                                                   
    IN p_tipo_origen ENUM('ensamblado_facultad', 'comprado_ensamblado'),                 
    IN p_marca VARCHAR(255),                                                             
    IN p_estado ENUM('operativo', 'mantenimiento', 'baja'),                              
    IN p_id_usuario INT,                                                                 
    IN p_id_ambiente INT                                                                 
)                                                                                        
BEGIN                                                                                    
    DECLARE v_old_usuario INT;                                                           
    DECLARE v_old_ambiente INT;                                                          
    DECLARE EXIT HANDLER FOR SQLEXCEPTION                                                
    BEGIN                                                                                
        ROLLBACK;                                                                        
        RESIGNAL;                                                                        
    END;                                                                                 
                                                                                            
    -- Validar que el equipo exista                                                      
    IF NOT EXISTS(SELECT 1 FROM equipo WHERE id_equipo = p_id_equipo) THEN               
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El equipo no existe.';        
    END IF;                                                                              
                                                                                            
    -- Validar código único de inventario                                                
    IF EXISTS(SELECT 1 FROM equipo WHERE codigo_inventario = p_codigo_inventario AND     
id_equipo <> p_id_equipo) THEN                                                             
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: El nuevo código de inventario 
ya pertenece a otra máquina.';                                                             
    END IF;                                                                              
                                                                                            
    -- Obtener asignación actual para evaluar si cambia                                  
    SELECT id_usuario, id_ambiente INTO v_old_usuario, v_old_ambiente                    
    FROM equipo                                                                          
    WHERE id_equipo = p_id_equipo;                                                       
                                                                                            
    START TRANSACTION;                                                                   
        -- Si cambió el destino de asignación física o lógica                            
        IF (COALESCE(p_id_usuario, 0) <> COALESCE(v_old_usuario, 0)) OR (p_id_ambiente <>
v_old_ambiente) THEN                                                                       
            -- Cerrar asignación activa anterior                                         
            UPDATE asignacion_historial                                                  
            SET fecha_fin = NOW()                                                        
            WHERE id_equipo = p_id_equipo AND fecha_fin IS NULL;                         
                                                                                            
            -- Crear nueva asignación activa                                             
            INSERT INTO asignacion_historial (id_equipo, id_usuario, id_ambiente,        
fecha_inicio)                                                                              
            VALUES (p_id_equipo, p_id_usuario, p_id_ambiente, NOW());                    
        END IF;                                                                          
                                                                                            
        -- Actualizar los datos del equipo                                               
        UPDATE equipo                                                                    
        SET codigo_inventario = p_codigo_inventario,                                     
            tipo = p_tipo,                                                               
            tipo_origen = p_tipo_origen,                                                 
            marca = p_marca,                                                             
            estado = p_estado,                                                           
            id_usuario = p_id_usuario,                                                   
            id_ambiente = p_id_ambiente                                                  
        WHERE id_equipo = p_id_equipo;                                                   
    COMMIT;                                                                              
END$$                                                                                    
                                                                                            
DELIMITER ;