-- =============================================================================
-- SETUP COMPLETO - Sistema de Soporte FISI (soportefisi)
-- Archivo de configuración completa de base de datos
-- =============================================================================

DROP DATABASE IF EXISTS `soportefisi`;
CREATE DATABASE `soportefisi` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `soportefisi`;

-- =============================================================================
-- 2. TABLAS Y RESTRICCIONES (CON CLAVES FORÁNEAS E INTEGRIDAD INLINE)
-- =============================================================================

-- Tabla de ambientes
CREATE TABLE `ambiente` (
  `id_ambiente` int PRIMARY KEY AUTO_INCREMENT,
  `numero` int NOT NULL,
  `nombre` varchar(50) NOT NULL,
  `pabellon` ENUM('Antiguo','Nuevo') NOT NULL,
  `piso` int NOT NULL,
  CONSTRAINT `chk_ambiente_numero` CHECK (`numero` > 0),
  CONSTRAINT `chk_ambiente_piso` CHECK (`piso` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de usuarios
CREATE TABLE `usuario` (
  `id_usuario` int PRIMARY KEY AUTO_INCREMENT,
  `id_area` int NOT NULL,
  `cargo` ENUM ('empleado', 'jefe') NOT NULL,
  `nombres` varchar(255) NOT NULL,
  `apellidos` varchar(255) NOT NULL,
  `correo` varchar(255) UNIQUE NOT NULL,
  `telefono` varchar(255),
  `contrasena` varchar(255) NOT NULL,
  `estado` boolean DEFAULT true,
  CONSTRAINT `chk_usuario_correo` CHECK (`correo` REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
  CONSTRAINT `chk_usuario_telefono` CHECK (`telefono` IS NULL OR `telefono` REGEXP '^[0-9]{7,15}$'),
  CONSTRAINT `fk_usuario_area` FOREIGN KEY (`id_area`) REFERENCES `ambiente` (`id_ambiente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de técnicos
CREATE TABLE `tecnico` (
  `id_tecnico` int PRIMARY KEY AUTO_INCREMENT,
  `rango` ENUM('practicante', 'tecnico', 'administrador_sistema') NOT NULL,
  `nombres` varchar(255) NOT NULL,
  `apellidos` varchar(255) NOT NULL,
  `correo` varchar(255) UNIQUE NOT NULL,
  `telefono` varchar(255),
  `contrasena` varchar(255) NOT NULL,
  `estado` boolean DEFAULT true,
  CONSTRAINT `chk_tecnico_correo` CHECK (`correo` REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
  CONSTRAINT `chk_tecnico_telefono` CHECK (`telefono` IS NULL OR `telefono` REGEXP '^[0-9]{7,15}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de equipos
CREATE TABLE `equipo` (
  `id_equipo` int PRIMARY KEY AUTO_INCREMENT,
  `codigo_inventario` varchar(255) UNIQUE NOT NULL,
  `tipo` ENUM ('pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor', 'otro') NOT NULL,
  `tipo_origen` ENUM ('ensamblado_facultad', 'comprado_ensamblado') NOT NULL,
  `marca` varchar(255),
  `estado` ENUM ('operativo', 'mantenimiento', 'baja') NOT NULL DEFAULT 'operativo',
  `id_usuario` int NULL,
  `id_ambiente` int NOT NULL,
  CONSTRAINT `chk_equipo_destino` CHECK (
    (`id_usuario` IS NOT NULL OR `id_ambiente` IS NOT NULL)),
  CONSTRAINT `fk_equipo_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT,
  CONSTRAINT `fk_equipo_ambiente` FOREIGN KEY (`id_ambiente`) REFERENCES `ambiente` (`id_ambiente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de componentes
CREATE TABLE `componente` (
  `id_componente` int PRIMARY KEY AUTO_INCREMENT,
  `id_equipo` int NULL,
  `id_ambiente` int NULL,
  `estado_componente` ENUM ('operativo', 'almacenado', 'mantenimiento', 'baja') NOT NULL DEFAULT 'operativo',
  CONSTRAINT `chk_componente_destino` CHECK (
    (`id_equipo` IS NOT NULL AND `id_ambiente` IS NULL) OR 
    (`id_equipo` IS NULL AND `id_ambiente` IS NOT NULL)
  ),
  CONSTRAINT `fk_componente_equipo` FOREIGN KEY (`id_equipo`) REFERENCES `equipo` (`id_equipo`) ON DELETE RESTRICT,
  CONSTRAINT `fk_componente_ambiente` FOREIGN KEY (`id_ambiente`) REFERENCES `ambiente` (`id_ambiente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de procesadores
CREATE TABLE `procesador` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `modelo` varchar(100),
  CONSTRAINT `fk_procesador_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de memorias RAM
CREATE TABLE `memoria_ram` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `capacidad_gb` int,
  `tipo_ddr` ENUM ('DDR3', 'DDR4', 'DDR5'),
  CONSTRAINT `chk_ram_capacidad` CHECK (`capacidad_gb` IS NULL OR `capacidad_gb` > 0),
  CONSTRAINT `fk_ram_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de almacenamiento
CREATE TABLE `almacenamiento` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `modelo` varchar(100),
  `tipo` ENUM ('ssd', 'hdd'),
  `capacidad_gb` int,
  CONSTRAINT `chk_almacenamiento_capacidad` CHECK (`capacidad_gb` IS NULL OR `capacidad_gb` > 0),
  CONSTRAINT `fk_almacenamiento_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de tarjetas gráficas
CREATE TABLE `tarjeta_grafica` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `modelo` varchar(100),
  `vram_gb` int,
  CONSTRAINT `chk_grafica_vram` CHECK (`vram_gb` IS NULL OR `vram_gb` > 0),
  CONSTRAINT `fk_tarjeta_grafica_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de placas madre
CREATE TABLE `placa_madre` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `modelo` varchar(100),
  `socket` varchar(50),
  `factor_forma` varchar(50),
  CONSTRAINT `fk_placa_madre_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de fuentes de poder
CREATE TABLE `fuente_poder` (
  `id_componente` int PRIMARY KEY,
  `marca` varchar(50),
  `modelo` varchar(100),
  `potencia_watts` int,
  `certificacion` varchar(50),
  CONSTRAINT `chk_fuente_potencia` CHECK (`potencia_watts` IS NULL OR `potencia_watts` > 0),
  CONSTRAINT `fk_fuente_poder_componente` FOREIGN KEY (`id_componente`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de incidencias
CREATE TABLE `incidencia` (
  `id_incidencia` int PRIMARY KEY AUTO_INCREMENT,
  `id_equipo` int,
  `id_usuario_reporta` int NOT NULL,
  `id_tecnico_recibe` int,
  `descripcion` text NOT NULL,
  `prioridad` ENUM ('baja', 'media', 'alta') NOT NULL DEFAULT 'media',
  `estado` ENUM ('pendiente', 'en_proceso', 'resuelta', 'cerrada') NOT NULL DEFAULT 'pendiente',
  `fecha_creacion` datetime NOT NULL,
  `fecha_resolucion` datetime,
  CONSTRAINT `chk_incidencia_fechas` CHECK (`fecha_resolucion` IS NULL OR `fecha_resolucion` >= `fecha_creacion`),
  CONSTRAINT `fk_incidencia_equipo` FOREIGN KEY (`id_equipo`) REFERENCES `equipo` (`id_equipo`) ON DELETE RESTRICT,
  CONSTRAINT `fk_incidencia_usuario` FOREIGN KEY (`id_usuario_reporta`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT,
  CONSTRAINT `fk_incidencia_tecnico` FOREIGN KEY (`id_tecnico_recibe`) REFERENCES `tecnico` (`id_tecnico`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de seguimientos de incidencia
CREATE TABLE `seguimiento_incidencia` (
  `id_seguimiento` int PRIMARY KEY AUTO_INCREMENT,
  `id_incidencia` int NOT NULL,
  `id_tecnico` int NOT NULL,
  `diagnostico` text,
  `trabajo_realizado` text,
  `horas_invertidas` decimal(4,2) NOT NULL,
  `id_componente_cambiado` int,
  `fecha` datetime NOT NULL,
  CONSTRAINT `chk_seguimiento_horas` CHECK (`horas_invertidas` > 0),
  CONSTRAINT `fk_seguimiento_incidencia` FOREIGN KEY (`id_incidencia`) REFERENCES `incidencia` (`id_incidencia`) ON DELETE RESTRICT,
  CONSTRAINT `fk_seguimiento_tecnico` FOREIGN KEY (`id_tecnico`) REFERENCES `tecnico` (`id_tecnico`) ON DELETE RESTRICT,
  CONSTRAINT `fk_seguimiento_componente` FOREIGN KEY (`id_componente_cambiado`) REFERENCES `componente` (`id_componente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de solicitudes
CREATE TABLE `solicitud` (
  `id_solicitud` int PRIMARY KEY AUTO_INCREMENT,
  `id_usuario_solicita` int NOT NULL,
  `tipo` ENUM ('remodelacion', 'mejora', 'reemplazo') NOT NULL,
  `descripcion` text NOT NULL,
  `estado` ENUM ('pendiente', 'aprobada', 'rechazada', 'completada') NOT NULL DEFAULT 'pendiente',
  `fecha_solicitud` datetime NOT NULL,
  `fecha_respuesta` datetime,
  CONSTRAINT `chk_solicitud_fechas` CHECK (`fecha_respuesta` IS NULL OR `fecha_respuesta` >= `fecha_solicitud`),
  CONSTRAINT `fk_solicitud_usuario` FOREIGN KEY (`id_usuario_solicita`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de asignación historial
CREATE TABLE `asignacion_historial` (
  `id_asignacion` int PRIMARY KEY AUTO_INCREMENT,
  `id_equipo` int NOT NULL,
  `id_usuario` int,
  `id_ambiente` int,
  `fecha_inicio` datetime NOT NULL,
  `fecha_fin` datetime,
  CONSTRAINT `chk_asignacion_fechas` CHECK (`fecha_fin` IS NULL OR `fecha_fin` >= `fecha_inicio`),
  CONSTRAINT `chk_asignacion_destino` CHECK (
    (`id_usuario` IS NOT NULL AND `id_ambiente` IS NULL) OR 
    (`id_usuario` IS NULL AND `id_ambiente` IS NOT NULL)
  ),
  CONSTRAINT `fk_asignacion_equipo` FOREIGN KEY (`id_equipo`) REFERENCES `equipo` (`id_equipo`) ON DELETE RESTRICT,
  CONSTRAINT `fk_asignacion_usuario` FOREIGN KEY (`id_usuario`) REFERENCES `usuario` (`id_usuario`) ON DELETE RESTRICT,
  CONSTRAINT `fk_asignacion_ambiente` FOREIGN KEY (`id_ambiente`) REFERENCES `ambiente` (`id_ambiente`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de software
CREATE TABLE `software` (
  `id_software` int PRIMARY KEY AUTO_INCREMENT,
  `nombre` varchar(255) UNIQUE NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de software instalado
CREATE TABLE `software_instalado` (
  `id_software_instalado` int PRIMARY KEY AUTO_INCREMENT,
  `id_equipo` int NOT NULL,
  `id_software` int NOT NULL,
  `tipo_licencia` ENUM ('libre', 'propietaria', 'educativa', 'trial') NOT NULL,
  `clave_licencia` varchar(255),
  `fecha_instalacion` date NOT NULL,
  `fecha_expiracion` date,
  CONSTRAINT `chk_software_fechas` CHECK (`fecha_expiracion` IS NULL OR `fecha_expiracion` >= `fecha_instalacion`),
  CONSTRAINT `fk_software_equipo` FOREIGN KEY (`id_equipo`) REFERENCES `equipo` (`id_equipo`) ON DELETE RESTRICT,
  CONSTRAINT `fk_software_list` FOREIGN KEY (`id_software`) REFERENCES `software` (`id_software`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tabla de auditoría
CREATE TABLE `auditoria_tecnico` (
  `id_auditoria_tecnico` int PRIMARY KEY AUTO_INCREMENT,
  `id_tecnico` int NOT NULL,
  `tabla_afectada` varchar(255) NOT NULL,
  `permiso_realizado` ENUM ('INSERT', 'UPDATE', 'DELETE') NOT NULL,
  `valor_agregado` json,
  `valor_anterior` json,
  `fecha_realizado` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_auditoria_tecnico` FOREIGN KEY (`id_tecnico`) REFERENCES `tecnico` (`id_tecnico`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
