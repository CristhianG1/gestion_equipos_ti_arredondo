-- =============================================================================
-- VIEWS - Sistema de Soporte FISI (soportefisi)
-- Archivo de Vistas
-- =============================================================================

USE `soportefisi`;

-- -----------------------------------------------------------------------------
-- VISTA 1: vw_revision_incidencias_is_usuario
-- Descripción : Permite a los usuarios revisar las incidencias de sus equipos.
-- Columnas    : id_incidencia, id_usuario_reporta, id_equipo, descripcion, estado
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_revision_incidencias_is_usuario` AS
SELECT 
    `id_incidencia`,
    `id_usuario_reporta`,
    `id_equipo`,
    `descripcion`,
    `estado`
FROM `incidencia`;

-- -----------------------------------------------------------------------------
-- VISTA 2: vw_seguimiento_incidencias_usuario
-- Descripción : Muestra el seguimiento y avance de cada incidencia para el usuario.
-- Columnas    : id_incidencia, id_tecnico, tecnico_nombre, diagnostico, trabajo_realizado, horas_invertidas, fecha
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_seguimiento_incidencias_usuario` AS
SELECT 
    si.`id_incidencia`,
    si.`id_tecnico`,
    CONCAT(t.`nombres`, ' ', t.`apellidos`) AS `tecnico_nombre`,
    si.`diagnostico`,
    si.`trabajo_realizado`,
    si.`horas_invertidas`,
    si.`fecha`
FROM `seguimiento_incidencia` si
INNER JOIN `tecnico` t ON si.`id_tecnico` = t.`id_tecnico`;

-- -----------------------------------------------------------------------------
-- VISTA 3: vw_componentes_detallados
-- Descripción : Unifica todos los tipos de componentes y genera especificaciones técnicas formateadas.
-- Columnas    : componente_id, tipo, especificaciones_tecnicas, estado_fisico, asignado_a, id_equipo, id_ambiente
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_componentes_detallados` AS
SELECT 
    c.`id_componente` AS `componente_id`,
    CASE 
        WHEN p.`id_componente` IS NOT NULL THEN 'Procesador'
        WHEN ram.`id_componente` IS NOT NULL THEN 'Memoria RAM'
        WHEN alm.`id_componente` IS NOT NULL THEN 'Almacenamiento'
        WHEN gpu.`id_componente` IS NOT NULL THEN 'Tarjeta Gráfica'
        WHEN mb.`id_componente` IS NOT NULL THEN 'Placa Madre'
        WHEN fp.`id_componente` IS NOT NULL THEN 'Fuente de Poder'
        ELSE 'Otro'
    END AS `tipo`,
    CASE 
        WHEN p.`id_componente` IS NOT NULL THEN CONCAT(p.`marca`, ' ', p.`modelo`)
        WHEN ram.`id_componente` IS NOT NULL THEN CONCAT(ram.`marca`, ' ', ram.`capacidad_gb`, 'GB ', ram.`tipo_ddr`)
        WHEN alm.`id_componente` IS NOT NULL THEN CONCAT(alm.`marca`, ' ', alm.`modelo`, ' (', alm.`capacidad_gb`, 'GB ', alm.`tipo`, ')')
        WHEN gpu.`id_componente` IS NOT NULL THEN CONCAT(gpu.`marca`, ' ', gpu.`modelo`, ' (', gpu.`vram_gb`, 'GB VRAM)')
        WHEN mb.`id_componente` IS NOT NULL THEN CONCAT(mb.`marca`, ' ', mb.`modelo`, ' Socket ', mb.`socket`, ' ', mb.`factor_forma`)
        WHEN fp.`id_componente` IS NOT NULL THEN CONCAT(fp.`marca`, ' ', fp.`modelo`, ' ', fp.`potencia_watts`, 'W')
        ELSE 'N/A'
    END AS `especificaciones_tecnicas`,
    c.`estado_componente` AS `estado_fisico`,
    CASE 
        WHEN c.`id_equipo` IS NOT NULL THEN CONCAT('Equipo: ', e.`codigo_inventario`)
        WHEN c.`id_ambiente` IS NOT NULL THEN CONCAT('Ambiente: ', a.`pabellon`, ' - ', a.`numero`)
        ELSE 'No asignado'
    END AS `asignado_a`,
    c.`id_equipo`,
    c.`id_ambiente`
FROM `componente` c
LEFT JOIN `equipo` e ON c.`id_equipo` = e.`id_equipo`
LEFT JOIN `ambiente` a ON c.`id_ambiente` = a.`id_ambiente`
LEFT JOIN `procesador` p ON c.`id_componente` = p.`id_componente`
LEFT JOIN `memoria_ram` ram ON c.`id_componente` = ram.`id_componente`
LEFT JOIN `almacenamiento` alm ON c.`id_componente` = alm.`id_componente`
LEFT JOIN `tarjeta_grafica` gpu ON c.`id_componente` = gpu.`id_componente`
LEFT JOIN `placa_madre` mb ON c.`id_componente` = mb.`id_componente`
LEFT JOIN `fuente_poder` fp ON c.`id_componente` = fp.`id_componente`;
