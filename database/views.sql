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
-- Columnas    : id_incidencia, id_tecnico, diagnostico, trabajo_realizado, horas_invertidas, fecha
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_seguimiento_incidencias_usuario` AS
SELECT 
    `id_incidencia`,
    `id_tecnico`,
    `diagnostico`,
    `trabajo_realizado`,
    `horas_invertidas`,
    `fecha`
FROM `seguimiento_incidencia`;
