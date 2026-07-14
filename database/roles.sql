-- =============================================================================
-- CONFIGURACIÓN DE ROLES Y PRIVILEGIOS DE BASE DE DATOS (RBAC)
-- Sistema de Soporte FISI (soportefisi)
-- =============================================================================

USE `soportefisi`;

-- -----------------------------------------------------------------------------
-- 1. CREACIÓN DE ROLES
-- -----------------------------------------------------------------------------
DROP ROLE IF EXISTS 'rol_empleado';
DROP ROLE IF EXISTS 'rol_jefe';
DROP ROLE IF EXISTS 'rol_practicante';
DROP ROLE IF EXISTS 'rol_tecnico';
DROP ROLE IF EXISTS 'rol_administrador';

CREATE ROLE 'rol_empleado';
CREATE ROLE 'rol_jefe';
CREATE ROLE 'rol_practicante';
CREATE ROLE 'rol_tecnico';
CREATE ROLE 'rol_administrador';

-- -----------------------------------------------------------------------------
-- 2. ASIGNACIÓN DE PRIVILEGIOS A 'rol_empleado'
-- -----------------------------------------------------------------------------
-- Permisos de lectura en vistas
GRANT SELECT ON `soportefisi`.`vw_revision_incidencias_is_usuario` TO 'rol_empleado';
GRANT SELECT ON `soportefisi`.`vw_seguimiento_incidencias_usuario` TO 'rol_empleado';

-- Permisos de ejecución de stored procedures
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_incidencia_usuario` TO 'rol_empleado';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_revisar_incidencia_usuario` TO 'rol_empleado';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_seguimiento_incidencia` TO 'rol_empleado';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_revisar_equipos_por_area_usuario` TO 'rol_empleado';

-- -----------------------------------------------------------------------------
-- 3. ASIGNACIÓN DE PRIVILEGIOS A 'rol_jefe'
-- -----------------------------------------------------------------------------
-- El rol Jefe hereda los permisos del empleado
GRANT 'rol_empleado' TO 'rol_jefe';

-- Permisos adicionales específicos para el Jefe
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_crear_solicitud_jefe` TO 'rol_jefe';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_estado_solicitud` TO 'rol_jefe';

-- -----------------------------------------------------------------------------
-- 4. ASIGNACIÓN DE PRIVILEGIOS A 'rol_practicante'
-- -----------------------------------------------------------------------------
-- Lectura básica en tablas operativas requerida por procedimientos
GRANT SELECT ON `soportefisi`.`tecnico` TO 'rol_practicante';
GRANT SELECT ON `soportefisi`.`usuario` TO 'rol_practicante';
GRANT SELECT ON `soportefisi`.`ambiente` TO 'rol_practicante';
GRANT SELECT ON `soportefisi`.`equipo` TO 'rol_practicante';

-- Permisos sobre procedimientos de consulta y gestión básica
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_listar_equipos` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_listar_componentes` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_listar_software` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_crear_software_instalado` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_actualizar_software_instalado` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_eliminar_software_instalado` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_incidencias` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_software_instalado` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_detalle_equipo` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_detalle_incidencia` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_seguimiento_incidencia` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_seguimientos_incidencia` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_incidencia_tecnico` TO 'rol_practicante';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_todos_componentes` TO 'rol_practicante';

-- Permisos en funciones métricas UDF
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_tickets_asignados` TO 'rol_practicante';
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_total_incidentes_pendientes` TO 'rol_practicante';
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_tickets_resueltos` TO 'rol_practicante';

-- -----------------------------------------------------------------------------
-- 5. ASIGNACIÓN DE PRIVILEGIOS A 'rol_tecnico'
-- -----------------------------------------------------------------------------
-- El técnico hereda los permisos del practicante
GRANT 'rol_practicante' TO 'rol_tecnico';

-- Permisos adicionales específicos para el Técnico
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_equipo` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_componentes_laptop` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_componentes_pc` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_software` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_instalacion_software` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_software_instalado_tecnico` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_editar_software_instalado` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_tecnico_registrar_incidencia` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_registrar_seguimiento_tecnico` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_asignar_personal_incidencia` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_solicitudes` TO 'rol_tecnico';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_ver_detalle_solicitud` TO 'rol_tecnico';

-- -----------------------------------------------------------------------------
-- 6. ASIGNACIÓN DE PRIVILEGIOS A 'rol_administrador'
-- -----------------------------------------------------------------------------
-- El Administrador del sistema hereda todos los privilegios del técnico
GRANT 'rol_tecnico' TO 'rol_administrador';

-- Permisos de ejecución de procedimientos administrativos
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ultimos_5_incidentes_globales` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_procesar_solicitud` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ver_usuarios` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_eliminar_usuario` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_editar_usuario` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_registrar_usuario` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_registrar_tecnico` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ver_tecnicos` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_eliminar_tecnico` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_editar_tecnico` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ver_areas` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_registrar_area` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_eliminar_area` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_registrar_componente` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_editar_componente` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ver_auditoria` TO 'rol_administrador';
GRANT EXECUTE ON PROCEDURE `soportefisi`.`sp_admin_ver_metricas_tecnicos` TO 'rol_administrador';

-- Permisos sobre las funciones métricas globales del administrador
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_total_equipos_activos` TO 'rol_administrador';
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_total_incidencias_activas` TO 'rol_administrador';
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_total_personal_tecnico` TO 'rol_administrador';
GRANT EXECUTE ON FUNCTION `soportefisi`.`fn_total_solicitudes` TO 'rol_administrador';
