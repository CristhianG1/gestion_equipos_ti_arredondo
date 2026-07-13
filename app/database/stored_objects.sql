-- =============================================================================
-- PROCEDIMIENTOS ALMACENADOS Y FUNCIONES - SOPORTE FISI
-- =============================================================================

USE soportefisi;

-- 1. Eliminar objetos previos si existen para evitar conflictos
DROP PROCEDURE IF EXISTS sp_asignar_equipo;
DROP PROCEDURE IF EXISTS sp_registrar_seguimiento;
DROP PROCEDURE IF EXISTS sp_asignar_incidencia;
DROP PROCEDURE IF EXISTS sp_asignar_componente_equipo;
DROP FUNCTION IF EXISTS fn_incidencias_asignadas;
DROP FUNCTION IF EXISTS fn_incidencias_resueltas;
DROP FUNCTION IF EXISTS fn_horas_invertidas;

DELIMITER $$

-- 2. Procedimiento Almacenado: sp_asignar_equipo
-- Termina cualquier asignación activa del equipo y registra la nueva asignación de forma transaccional.
-- Sincroniza las columnas id_usuario e id_ambiente en la tabla equipo.
CREATE PROCEDURE sp_asignar_equipo(
    IN p_id_equipo INT,
    IN p_id_usuario INT,
    IN p_id_ambiente INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        -- Terminar asignación activa anterior
        UPDATE asignacion_historial 
        SET fecha_fin = NOW() 
        WHERE id_equipo = p_id_equipo AND fecha_fin IS NULL;

        -- Insertar la nueva asignación
        INSERT INTO asignacion_historial (id_equipo, id_usuario, id_ambiente, fecha_inicio)
        VALUES (p_id_equipo, p_id_usuario, p_id_ambiente, NOW());

        -- Sincronizar el estado actual en la tabla equipo
        UPDATE equipo
        SET id_usuario = p_id_usuario,
            id_ambiente = p_id_ambiente
        WHERE id_equipo = p_id_equipo;
    COMMIT;
END$$

-- 3. Procedimiento Almacenado: sp_registrar_seguimiento
-- Registra el seguimiento y actualiza el estado del ticket.
-- Si el técnico responsable es un practicante, el estado final se fuerza a 'por_confirmar' si se intenta resolver o cerrar.
CREATE PROCEDURE sp_registrar_seguimiento(
    IN p_id_incidencia INT,
    IN p_id_tecnico INT,
    IN p_diagnostico TEXT,
    IN p_trabajo_realizado TEXT,
    IN p_horas_invertidas DECIMAL(4,2),
    IN p_id_componente_cambiado INT,
    IN p_estado_incidencia VARCHAR(20)
)
BEGIN
    DECLARE v_rango VARCHAR(50);
    DECLARE v_final_estado VARCHAR(20);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Obtener el rol del técnico
    SELECT r.nombre INTO v_rango
    FROM tecnico t
    JOIN rango_tecnico r ON t.id_rango = r.id_rango
    WHERE t.id_tecnico = p_id_tecnico;

    -- Determinar estado final
    SET v_final_estado = p_estado_incidencia;
    IF v_rango = 'practicante' AND (p_estado_incidencia = 'resuelta' OR p_estado_incidencia = 'cerrada') THEN
        SET v_final_estado = 'por_confirmar';
    END IF;

    START TRANSACTION;
        -- Insertar seguimiento técnico
        INSERT INTO seguimiento_incidencia (id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, id_componente_cambiado, fecha)
        VALUES (p_id_incidencia, p_id_tecnico, p_diagnostico, p_trabajo_realizado, p_horas_invertidas, p_id_componente_cambiado, NOW());

        -- Actualizar incidencia
        UPDATE incidencia
        SET estado = v_final_estado,
            fecha_resolucion = IF(v_final_estado IN ('resuelta', 'cerrada'), NOW(), NULL)
        WHERE id_incidencia = p_id_incidencia;
    COMMIT;
END$$

-- 4. Procedimiento Almacenado: sp_asignar_incidencia
-- Realiza asignaciones de incidencias evaluando reglas de negocio:
-- - Si quien asigna es 'tecnico', solo puede asignarse a sí mismo o a un 'practicante'.
-- - Si el técnico asignado es un 'practicante', debe tener como máximo 4 incidencias activas.
CREATE PROCEDURE sp_asignar_incidencia(
    IN p_id_incidencia INT,
    IN p_id_tecnico_destino INT,
    IN p_id_tecnico_que_asigna INT
)
BEGIN
    DECLARE v_rango_destino VARCHAR(50);
    DECLARE v_rango_asigna VARCHAR(50);
    DECLARE v_count INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Obtener rango del técnico que recibe/destino
    SELECT r.nombre INTO v_rango_destino
    FROM tecnico t
    JOIN rango_tecnico r ON t.id_rango = r.id_rango
    WHERE t.id_tecnico = p_id_tecnico_destino;

    -- Obtener rango del técnico que está asignando
    SELECT r.nombre INTO v_rango_asigna
    FROM tecnico t
    JOIN rango_tecnico r ON t.id_rango = r.id_rango
    WHERE t.id_tecnico = p_id_tecnico_que_asigna;

    -- REGLA 1: Si quien asigna es de rango 'tecnico'
    IF v_rango_asigna = 'tecnico' THEN
        -- Solo puede asignarse a sí mismo o a un practicante
        IF p_id_tecnico_destino != p_id_tecnico_que_asigna AND v_rango_destino != 'practicante' THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'Los técnicos solo pueden asignarse tickets a sí mismos o a practicantes.';
        END IF;
    END IF;

    -- REGLA 2: Si el destino es 'practicante', validar límite de 4 incidencias activas
    IF v_rango_destino = 'practicante' THEN
        SELECT COUNT(*) INTO v_count 
        FROM incidencia 
        WHERE id_tecnico_recibe = p_id_tecnico_destino 
          AND estado IN ('pendiente', 'en_proceso', 'por_confirmar');
          
        IF v_count >= 4 THEN
            SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'El practicante seleccionado ya cuenta con el límite máximo de 4 incidencias activas.';
        END IF;
    END IF;

    START TRANSACTION;
        -- Actualizar la incidencia
        UPDATE incidencia
        SET id_tecnico_recibe = p_id_tecnico_destino,
            estado = IF(estado = 'pendiente', 'en_proceso', estado)
        WHERE id_incidencia = p_id_incidencia;
    COMMIT;
END$$

-- 5. Procedimiento Almacenado: sp_asignar_componente_equipo
-- Vincula un componente en almacén a un equipo, validando que no existan duplicados para tipos restringidos.
CREATE PROCEDURE sp_asignar_componente_equipo(
    IN p_id_componente INT,
    IN p_id_equipo INT
)
BEGIN
    DECLARE v_tipo VARCHAR(50);
    DECLARE v_count INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    -- Identificar el tipo de componente
    SET v_tipo = NULL;
    IF EXISTS(SELECT 1 FROM procesador WHERE id_componente = p_id_componente) THEN SET v_tipo = 'procesador';
    ELSEIF EXISTS(SELECT 1 FROM placa_madre WHERE id_componente = p_id_componente) THEN SET v_tipo = 'placa_madre';
    ELSEIF EXISTS(SELECT 1 FROM fuente_poder WHERE id_componente = p_id_componente) THEN SET v_tipo = 'fuente_poder';
    ELSEIF EXISTS(SELECT 1 FROM tarjeta_grafica WHERE id_componente = p_id_componente) THEN SET v_tipo = 'tarjeta_grafica';
    END IF;

    -- Validar restricción de unidad única por tipo (excepto RAM y almacenamiento)
    IF v_tipo IS NOT NULL THEN
        -- Contar cuántos componentes activos de ese tipo tiene el equipo
        SELECT COUNT(*) INTO v_count
        FROM componente c
        LEFT JOIN procesador p ON c.id_componente = p.id_componente
        LEFT JOIN placa_madre mb ON c.id_componente = mb.id_componente
        LEFT JOIN fuente_poder fp ON c.id_componente = fp.id_componente
        LEFT JOIN tarjeta_grafica gpu ON c.id_componente = gpu.id_componente
        WHERE c.id_equipo = p_id_equipo 
          AND c.estado_componente != 'baja'
          AND (
              (v_tipo = 'procesador' AND p.id_componente IS NOT NULL) OR
              (v_tipo = 'placa_madre' AND mb.id_componente IS NOT NULL) OR
              (v_tipo = 'fuente_poder' AND fp.id_componente IS NOT NULL) OR
              (v_tipo = 'tarjeta_grafica' AND gpu.id_componente IS NOT NULL)
          );

        IF v_count > 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El equipo ya posee un componente activo de este tipo. Solo se permite uno (excepto RAM y Almacenamiento).';
        END IF;
    END IF;

    START TRANSACTION;
        UPDATE componente
        SET id_equipo = p_id_equipo,
            estado_componente = 'operativo'
        WHERE id_componente = p_id_componente;
    COMMIT;
END$$

-- 6. Función Almacenada: fn_incidencias_asignadas
-- Retorna el total de incidencias asignadas a un técnico.
CREATE FUNCTION fn_incidencias_asignadas(p_id_tecnico INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM incidencia WHERE id_tecnico_recibe = p_id_tecnico;
    RETURN v_count;
END$$

-- 7. Función Almacenada: fn_incidencias_resueltas
-- Retorna el total de incidencias resueltas o cerradas por un técnico.
CREATE FUNCTION fn_incidencias_resueltas(p_id_tecnico INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count FROM incidencia WHERE id_tecnico_recibe = p_id_tecnico AND estado IN ('resuelta', 'cerrada');
    RETURN v_count;
END$$

-- 8. Función Almacenada: fn_horas_invertidas
-- Retorna la sumatoria de horas invertidas en seguimientos por un técnico.
CREATE FUNCTION fn_horas_invertidas(p_id_tecnico INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_hours DECIMAL(10,2);
    SELECT IFNULL(SUM(horas_invertidas), 0) INTO v_hours FROM seguimiento_incidencia WHERE id_tecnico = p_id_tecnico;
    RETURN v_hours;
END$$

DELIMITER ;

-- 9. Recreación de vista_metricas_personal usando las funciones almacenadas para optimizar cálculos
CREATE OR REPLACE VIEW vista_metricas_personal AS
SELECT 
    t.id_tecnico,
    t.nombres,
    t.apellidos,
    r.nombre AS rango,
    fn_incidencias_asignadas(t.id_tecnico) AS total_incidencias_asignadas,
    fn_incidencias_resueltas(t.id_tecnico) AS total_incidencias_resueltas,
    fn_horas_invertidas(t.id_tecnico) AS total_horas_invertidas,
    CASE 
        WHEN fn_incidencias_resueltas(t.id_tecnico) > 0 
        THEN ROUND(fn_horas_invertidas(t.id_tecnico) / fn_incidencias_resueltas(t.id_tecnico), 2)
        ELSE 0.00
    END AS promedio_horas_por_incidencia,
    (fn_incidencias_asignadas(t.id_tecnico) - fn_incidencias_resueltas(t.id_tecnico)) AS incidencias_pendientes
FROM tecnico t
JOIN rango_tecnico r ON t.id_rango = r.id_rango;
