-- =============================================================================
-- DATA DE PRUEBA - Sistema de Soporte FISI (soportefisi)
-- Archivo para poblar la base de datos con datos simulados y realistas
-- =============================================================================

USE `soportefisi`;

-- Desactivar temporalmente restricciones de clave foránea para evitar problemas de orden en la inserción
SET FOREIGN_KEY_CHECKS = 0;

-- Limpiar datos existentes para garantizar idempotencia
TRUNCATE TABLE `auditoria_tecnico`;
TRUNCATE TABLE `software_instalado`;
TRUNCATE TABLE `software`;
TRUNCATE TABLE `asignacion_historial`;
TRUNCATE TABLE `solicitud`;
TRUNCATE TABLE `seguimiento_incidencia`;
TRUNCATE TABLE `incidencia`;
TRUNCATE TABLE `fuente_poder`;
TRUNCATE TABLE `placa_madre`;
TRUNCATE TABLE `tarjeta_grafica`;
TRUNCATE TABLE `almacenamiento`;
TRUNCATE TABLE `memoria_ram`;
TRUNCATE TABLE `procesador`;
TRUNCATE TABLE `componente`;
TRUNCATE TABLE `equipo`;
TRUNCATE TABLE `ambiente`;
TRUNCATE TABLE `tecnico`;
TRUNCATE TABLE `usuario`;

-- 2. INSERTAR USUARIOS (Jefes y Empleados)
-- contraseñas encriptadas ficticias
INSERT INTO `usuario` (`id_usuario`, `id_area`, `cargo`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`) VALUES
(1, 1, 'jefe', 'Carlos', 'Mendoza Prado', 'carlos.mendoza@fisi.edu.pe', '987654321', '$2y$10$abcdefg12345678901234u', true),
(2, 3, 'jefe', 'Ana', 'Torres Valdivia', 'ana.torres@fisi.edu.pe', '912345678', '$2y$10$abcdefg12345678901234u', true),
(3, 2, 'empleado', 'Luis', 'Gómez Herrera', 'luis.gomez@fisi.edu.pe', '998877665', '$2y$10$abcdefg12345678901234u', true),
(4, 5, 'empleado', 'María', 'Rojas Quispe', 'maria.rojas@fisi.edu.pe', '944556677', '$2y$10$abcdefg12345678901234u', true),
(5, 4, 'empleado', 'Pedro', 'Díaz Alva', 'pedro.diaz@fisi.edu.pe', '922334455', '$2y$10$abcdefg12345678901234u', false); -- Usuario Inactivo

-- 3. INSERTAR TÉCNICOS (Con diferentes rangos ENUM)
INSERT INTO `tecnico` (`id_tecnico`, `rango`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`) VALUES
(1, 'administrador_sistema', 'Jorge', 'Ramírez Vega', 'jorge.ramirez@fisi.edu.pe', '955667788', '$2y$10$abcdefg12345678901234t', true),
(2, 'tecnico', 'Sofía', 'Castro Peña', 'sofia.castro@fisi.edu.pe', '966778899', '$2y$10$abcdefg12345678901234t', true),
(3, 'tecnico', 'Ricardo', 'Ruiz Ortiz', 'ricardo.ruiz@fisi.edu.pe', '977889900', '$2y$10$abcdefg12345678901234t', true),
(4, 'practicante', 'Alex', 'Marín Soto', 'alex.marin@fisi.edu.pe', '911223344', '$2y$10$abcdefg12345678901234t', true),
(5, 'practicante', 'Lucía', 'Pinedo Solís', 'lucia.pinedo@fisi.edu.pe', '933445566', '$2y$10$abcdefg12345678901234t', true);

-- 4. INSERTAR AMBIENTES
INSERT INTO `ambiente` (`id_ambiente`, `numero`, `nombre`, `pabellon`, `piso`) VALUES
(1, 101, 'Oficina de Decanato', 'Nuevo', 1),
(2, 102, 'Laboratorio de Cómputo L1', 'Antiguo', 1),
(3, 201, 'Aula de Innovación Tecnológica', 'Nuevo', 2),
(4, 202, 'Laboratorio de Redes L2', 'Nuevo', 2),
(5, 301, 'Gabinete de Investigación', 'Antiguo', 3),
(6, 999, 'almacen', 'Antiguo', 0); -- Ambiente de almacén para bajas de componentes

-- 5. INSERTAR EQUIPOS
-- Según chk_equipo_destino: id_usuario y id_ambiente no pueden ser nulos al mismo tiempo
INSERT INTO `equipo` (`id_equipo`, `codigo_inventario`, `tipo`, `tipo_origen`, `marca`, `estado`, `id_usuario`, `id_ambiente`) VALUES
(1, 'EQU-001', 'pc_escritorio', 'comprado_ensamblado', 'Lenovo', 'operativo', 1, 1),      -- Asignado a Carlos Mendoza en Decanato
(2, 'EQU-002', 'pc_escritorio', 'ensamblado_facultad', 'ASUS', 'operativo', NULL, 2), -- PC en Lab L1
(3, 'EQU-003', 'proyector', 'comprado_ensamblado', 'Epson', 'mantenimiento', NULL, 3),-- Proyector en Aula Innovación
(4, 'EQU-004', 'pc_escritorio', 'comprado_ensamblado', 'HP', 'operativo', 4, 5),          -- Laptop de María Rojas en Investigación
(5, 'EQU-005', 'pc_escritorio', 'ensamblado_facultad', 'Gigabyte', 'operativo', NULL, 4), -- PC en Lab L2
(6, 'EQU-006', 'pc_escritorio', 'ensamblado_facultad', 'Dell', 'baja', NULL, 6);       -- PC dada de baja en almacén



-- 7. COMPONENTES (Para equipos ensamblados o componentes sueltos)
INSERT INTO `componente` (`id_componente`, `id_equipo`, `id_ambiente`, `estado_componente`) VALUES
(1, 2, NULL, 'operativo'),     -- Procesador PC Lab L1
(2, 2, NULL, 'operativo'),     -- RAM PC Lab L1
(3, 2, NULL, 'operativo'),     -- SSD PC Lab L1
(4, 2, NULL, 'operativo'),     -- Placa Madre PC Lab L1
(5, 5, NULL, 'operativo'),     -- Procesador PC Lab L2
(6, 5, NULL, 'operativo'),     -- RAM PC Lab L2
(7, 5, NULL, 'operativo'),     -- GPU PC Lab L2
(8, 6, NULL, 'baja'),          -- Componente de PC dada de baja
(9, NULL, 6, 'almacenado'),    -- RAM suelta en almacén
(10, NULL, 6, 'mantenimiento'); -- Tarjeta gráfica en reparación en almacén

-- Detalle de Procesadores
INSERT INTO `procesador` (`id_componente`, `marca`, `modelo`) VALUES
(1, 'Intel', 'Core i5-10400'),
(5, 'AMD', 'Ryzen 5 5600X');

-- Detalle de Memorias RAM
INSERT INTO `memoria_ram` (`id_componente`, `marca`, `capacidad_gb`, `tipo_ddr`) VALUES
(2, 'Kingston Fury', 8, 'DDR4'),
(6, 'Crucial Ballistix', 16, 'DDR4'),
(9, 'Corsair Vengeance', 8, 'DDR4');

-- Detalle de Almacenamiento
INSERT INTO `almacenamiento` (`id_componente`, `marca`, `modelo`, `tipo`, `capacidad_gb`) VALUES
(3, 'Crucial', 'BX500', 'ssd', 480);

-- Detalle de Tarjetas Gráficas
INSERT INTO `tarjeta_grafica` (`id_componente`, `marca`, `modelo`, `vram_gb`) VALUES
(7, 'Gigabyte', 'NVIDIA GTX 1660 Super', 6),
(10, 'ASUS', 'AMD Radeon RX 580', 8);

-- Detalle de Placas Madre
INSERT INTO `placa_madre` (`id_componente`, `marca`, `modelo`, `socket`, `factor_forma`) VALUES
(4, 'ASUS', 'PRIME H410M-E', 'LGA1200', 'Micro-ATX');

-- Detalle de Fuentes de Poder
INSERT INTO `fuente_poder` (`id_componente`, `marca`, `modelo`, `potencia_watts`, `certificacion`) VALUES
(8, 'EVGA', '600 W1', 600, '80 Plus White');

-- 8. REGISTRO DE INCIDENCIAS
-- Falla de equipos o problemas generales (id_equipo opcional)
INSERT INTO `incidencia` (`id_incidencia`, `id_equipo`, `id_usuario_reporta`, `id_tecnico_recibe`, `descripcion`, `prioridad`, `estado`, `fecha_creacion`, `fecha_resolucion`) VALUES
(1, 1, 1, 3, 'La laptop Lenovo ThinkPad presenta problemas para conectarse a la red WiFi del Decanato.', 'media', 'resuelta', '2026-07-10 09:30:00', '2026-07-10 11:15:00'),
(2, 4, 4, 2, 'Pantalla azul recurrente (BSOD) con código CRITICAL_PROCESS_DIED al abrir MATLAB.', 'alta', 'en_proceso', '2026-07-12 14:00:00', NULL),
(3, 2, 3, NULL, 'El equipo de escritorio de Lab L1 no da video y emite 3 pitidos cortos al encender.', 'alta', 'pendiente', '2026-07-13 16:45:00', NULL),
(4, NULL, 2, 1, 'Corte de fluido eléctrico generalizado en el Pabellón Nuevo afectando Laboratorio L2.', 'alta', 'resuelta', '2026-07-11 08:00:00', '2026-07-11 09:20:00');

-- 9. SEGUIMIENTO DE INCIDENCIAS
INSERT INTO `seguimiento_incidencia` (`id_seguimiento`, `id_incidencia`, `id_tecnico`, `diagnostico`, `trabajo_realizado`, `horas_invertidas`, `id_componente_cambiado`, `fecha`) VALUES
(1, 1, 3, 'Conflicto con la IP estática configurada anteriormente y el nuevo router de la facultad.', 'Se configuró DHCP estático en el router y se limpió la caché DNS en la máquina.', 1.75, NULL, '2026-07-10 11:00:00'),
(2, 2, 2, 'Los volcados de memoria sugieren un fallo físico en un sector de la memoria RAM.', 'Se ejecutó memtest86 detectando múltiples errores en el sector alto de la RAM de 8GB.', 2.50, NULL, '2026-07-13 10:00:00'),
(3, 4, 1, 'Sobrecarga en la llave termomagnética del tablero secundario del pabellón.', 'Se rearmó el interruptor diferencial y se redistribuyeron las cargas en el tablero del piso.', 1.30, NULL, '2026-07-11 09:15:00');

-- 10. SOLICITUDES DE JEFES
INSERT INTO `solicitud` (`id_solicitud`, `id_usuario_solicita`, `tipo`, `descripcion`, `estado`, `fecha_solicitud`, `fecha_respuesta`) VALUES
(1, 2, 'reemplazo', 'Solicito el reemplazo de 5 mouses ópticos desgastados en el Laboratorio L1.', 'aprobada', '2026-07-08 10:00:00', '2026-07-09 15:30:00'),
(2, 1, 'mejora', 'Solicito la adquisición de un módulo de 8GB RAM adicional para la laptop asignada a Investigación.', 'pendiente', '2026-07-13 11:20:00', NULL);

-- 11. HISTORIAL DE ASIGNACIONES
INSERT INTO `asignacion_historial` (`id_asignacion`, `id_equipo`, `id_usuario`, `id_ambiente`, `fecha_inicio`, `fecha_fin`) VALUES
(1, 1, 1, NULL, '2026-01-15 08:30:00', NULL), -- Asignación activa
(2, 2, NULL, 2, '2026-02-10 09:00:00', NULL), -- Asignación activa
(3, 4, 4, NULL, '2026-03-01 10:15:00', NULL), -- Asignación activa
(4, 6, NULL, 2, '2025-05-10 08:00:00', '2026-07-13 17:00:00'); -- Historial cerrado al darse de baja

-- 12. SOFTWARE
INSERT INTO `software` (`id_software`, `nombre`) VALUES
(1, 'Windows 11 Pro 64-bit'),
(2, 'Microsoft Office Professional Plus 2021'),
(3, 'MATLAB R2023b Academic License'),
(4, 'Visual Studio Code 1.85');

-- 13. SOFTWARE INSTALADO
INSERT INTO `software_instalado` (`id_software_instalado`, `id_equipo`, `id_software`, `tipo_licencia`, `clave_licencia`, `fecha_instalacion`, `fecha_expiracion`) VALUES
(1, 1, 1, 'propietaria', 'W269N-WFGWX-YVC9B-4J6C9-T83GX', '2026-01-16', NULL),
(2, 1, 2, 'propietaria', 'OFFIC-E2021-KEYXX-YYYYY-ZZZZZ', '2026-01-16', '2027-01-16'),
(3, 4, 1, 'propietaria', 'W269N-WFGWX-YVC9B-4J6C9-T83GX', '2026-03-02', NULL),
(4, 4, 3, 'educativa', 'MATLA-ACADE-R2023-BBBBB-CCCCC', '2026-03-05', '2027-03-05'),
(5, 2, 4, 'libre', NULL, '2026-02-12', NULL);

-- Reactivar restricciones de clave foránea
SET FOREIGN_KEY_CHECKS = 1;
