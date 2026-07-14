import os
import random
import re
from datetime import datetime, timedelta
import mysql.connector
from faker import Faker

# Inicializar Faker
fake = Faker('es_ES')  # Localización en español estándar

# Cargar variables de entorno desde .env manualmente
env_vars = {}
if os.path.exists('.env'):
    with open('.env', 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, val = line.split('=', 1)
                env_vars[key.strip()] = val.strip()

# Configuración de base de datos
db_config = {
    'host': env_vars.get('DB_HOST', 'localhost'),
    'user': env_vars.get('DB_USER', 'root'),
    'password': env_vars.get('DB_PASSWORD', 'root'),
    'database': env_vars.get('DB_NAME', 'soportefisi'),
    'port': int(env_vars.get('DB_PORT', 3306))
}

print(f"🔌 Conectando a MySQL en {db_config['host']}:{db_config['port']}...")
conn = mysql.connector.connect(**db_config)
cursor = conn.cursor(dictionary=True)
print("✅ Conexión establecida.")

# Deshabilitar checks de claves foráneas y triggers para agilizar la inserción masiva
cursor.execute("SET FOREIGN_KEY_CHECKS = 0;")
cursor.execute("SET @current_tecnico_id = 1;")  # Simular que los cambios son auditados al técnico 1

def truncate_tables():
    print("🧹 Limpiando base de datos antes de poblar...")
    tables = [
        'auditoria_tecnico', 'software_instalado', 'software', 'asignacion_historial',
        'solicitud', 'seguimiento_incidencia', 'incidencia', 'fuente_poder', 'placa_madre',
        'tarjeta_grafica', 'almacenamiento', 'memoria_ram', 'procesador', 'componente',
        'equipo', 'ambiente', 'tecnico', 'usuario'
    ]
    for table in tables:
        cursor.execute(f"TRUNCATE TABLE `{table}`;")
    conn.commit()
    print("✅ Tablas truncadas.")

truncate_tables()

# =============================================================================
# 1. AMBIENTES (20 registros)
# =============================================================================
print("📂 Insertando Ambientes...")
ambientes_data = []

# Mapear laboratorios (Lab-101 a Lab-320)
lab_num = 101
for _ in range(12):
    piso = int(str(lab_num)[0])
    ambientes_data.append({
        'numero': lab_num,
        'nombre': f'Laboratorio de Computo L{lab_num}',
        'pabellon': 'Nuevo' if piso > 1 else 'Antiguo',
        'piso': piso
    })
    lab_num += 9  # Incrementar números de laboratorio de manera irregular (101, 110, 119...)

# Aulas comunes, biblioteca y sala de servidores
infraestructuras = [
    (102, 'Aula Común 102', 'Antiguo', 1),
    (204, 'Aula Común 204', 'Nuevo', 2),
    (305, 'Aula de Investigación 305', 'Nuevo', 3),
    (115, 'Biblioteca Central FISI', 'Antiguo', 1),
    (200, 'Sala de Servidores TI', 'Nuevo', 2),
    (300, 'Oficina de Soporte Técnico', 'Nuevo', 3),
    (100, 'Oficina de Decanato', 'Antiguo', 1),
    (999, 'Almacen General TI', 'Antiguo', 0)
]

for numero, nombre, pabellon, piso in infraestructuras:
    ambientes_data.append({
        'numero': numero,
        'nombre': nombre,
        'pabellon': pabellon,
        'piso': piso
    })

ambiente_ids = []
for amb in ambientes_data:
    cursor.execute(
        "INSERT INTO `ambiente` (`numero`, `nombre`, `pabellon`, `piso`) VALUES (%s, %s, %s, %s)",
        (amb['numero'], amb['nombre'], amb['pabellon'], amb['piso'])
    )
    ambiente_ids.append(cursor.lastrowid)

conn.commit()
print(f"   ✅ {len(ambiente_ids)} ambientes insertados con éxito.")

# =============================================================================
# 2. USUARIOS Y TÉCNICOS (150 registros)
# =============================================================================
print("👥 Insertando Usuarios y Técnicos...")
emails_unicos = set()

# Helper para generar correos institucionales únicos
def generar_correo_fisi(nombres, apellidos):
    base = f"{nombres.split()[0].lower()}.{apellidos.split()[0].lower()}"
    base = re.sub(r'[^a-z.]', '', base.replace('ñ', 'n'))
    correo = f"{base}@fisi.edu.pe"
    counter = 1
    while correo in emails_unicos:
        correo = f"{base}{counter}@fisi.edu.pe"
        counter += 1
    emails_unicos.add(correo)
    return correo

# 120 Usuarios Comunes (90 empleados y 30 jefes)
usuario_ids = []
jefes_ids = []
for i in range(120):
    cargo = 'jefe' if i < 30 else 'empleado'
    nombres = fake.first_name() + " " + fake.first_name()
    apellidos = fake.last_name() + " " + fake.last_name()
    correo = generar_correo_fisi(nombres, apellidos)
    telefono = str(random.randint(900000000, 999999999))
    contrasena = '$2y$10$abcdefg12345678901234u'  # Contraseña hash fija de prueba
    id_area = random.choice(ambiente_ids)
    
    cursor.execute(
        "INSERT INTO `usuario` (`id_area`, `cargo`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
        (id_area, cargo, nombres, apellidos, correo, telefono, contrasena, True)
    )
    uid = cursor.lastrowid
    usuario_ids.append(uid)
    if cargo == 'jefe':
        jefes_ids.append(uid)

# 30 Técnicos (10 practicantes, 15 tecnicos, 5 administradores)
tecnico_ids = []
practicante_ids = []
for i in range(30):
    if i < 5:
        rango = 'administrador_sistema'
    elif i < 15:
        rango = 'practicante'
    else:
        rango = 'tecnico'
        
    nombres = fake.first_name() + " " + fake.first_name()
    apellidos = fake.last_name() + " " + fake.last_name()
    correo = generar_correo_fisi(nombres, apellidos)
    telefono = str(random.randint(900000000, 999999999))
    contrasena = '$2y$10$abcdefg12345678901234t'
    
    cursor.execute(
        "INSERT INTO `tecnico` (`rango`, `nombres`, `apellidos`, `correo`, `telefono`, `contrasena`, `estado`) VALUES (%s, %s, %s, %s, %s, %s, %s)",
        (rango, nombres, apellidos, correo, telefono, contrasena, True)
    )
    tid = cursor.lastrowid
    tecnico_ids.append(tid)
    if rango == 'practicante':
        practicante_ids.append(tid)

conn.commit()
print(f"   ✅ {len(usuario_ids)} usuarios (incluyendo {len(jefes_ids)} jefes) insertados.")
print(f"   ✅ {len(tecnico_ids)} personal de soporte técnico insertados.")

# =============================================================================
# 3. EQUIPOS PRINCIPALES (200 registros)
# =============================================================================
print("💻 Insertando Equipos...")
equipo_ids = []

tipos_equipo = ['pc_escritorio', 'proyector', 'teclado', 'mouse', 'monitor', 'otro']
origenes = ['ensamblado_facultad', 'comprado_ensamblado']
marcas = {
    'pc_escritorio': ['Lenovo', 'HP', 'Dell', 'Asus', 'Acer'],
    'proyector': ['Epson', 'BenQ', 'Sony', 'Optoma'],
    'teclado': ['Logitech', 'Genius', 'Microsoft', 'Razer'],
    'mouse': ['Logitech', 'Genius', 'Microsoft', 'Razer'],
    'monitor': ['LG', 'Samsung', 'ViewSonic', 'Dell', 'Asus'],
    'otro': ['Cisco', 'HP Enterprise', 'MikroTik', 'APC']
}

for i in range(1, 201):
    codigo = f"FISI-EQ-{i:04d}"
    tipo = random.choices(tipos_equipo, weights=[45, 10, 15, 15, 10, 5])[0]
    origen = random.choice(origenes)
    marca = random.choice(marcas[tipo])
    estado = random.choices(['operativo', 'mantenimiento', 'baja'], weights=[85, 10, 5])[0]
    
    # Restricción chk_equipo_destino: id_usuario u id_ambiente
    # 60% asignados a usuarios fijos, 40% a un ambiente común
    if random.random() < 0.6:
        id_usuario = random.choice(usuario_ids)
        id_ambiente = random.choice(ambiente_ids)
    else:
        id_usuario = None
        id_ambiente = random.choice(ambiente_ids)
        
    cursor.execute(
        "INSERT INTO `equipo` (`codigo_inventario`, `tipo`, `tipo_origen`, `marca`, `estado`, `id_usuario`, `id_ambiente`) VALUES (%s, %s, %s, %s, %s, %s, %s)",
        (codigo, tipo, origen, marca, estado, id_usuario, id_ambiente)
    )
    equipo_ids.append(cursor.lastrowid)

conn.commit()
print(f"   ✅ {len(equipo_ids)} equipos principales registrados en el inventario.")

# =============================================================================
# 4. COMPONENTES Y SUBTIPOS (800 registros)
# =============================================================================
print("🔌 Insertando Componentes de Hardware...")
componente_ids = []
almacen_id = ambiente_ids[-1]  # Usar el almacén como ambiente por defecto para stock

componentes_detalles = {
    'procesador': [
        ('Intel', 'Core i7-12700K'), ('Intel', 'Core i5-13400'), ('Intel', 'Core i9-12900K'),
        ('AMD', 'Ryzen 7 5700X'), ('AMD', 'Ryzen 5 7600X'), ('AMD', 'Ryzen 9 5900X')
    ],
    'memoria_ram': [
        ('Kingston', 8, 'DDR4'), ('Kingston', 16, 'DDR4'), ('Corsair', 16, 'DDR4'),
        ('Corsair', 32, 'DDR5'), ('Crucial', 8, 'DDR3'), ('Crucial', 16, 'DDR5')
    ],
    'almacenamiento': [
        ('Samsung', '980 Pro', 'ssd', 1000), ('Crucial', 'MX500', 'ssd', 500),
        ('Western Digital', 'Blue', 'hdd', 1000), ('Western Digital', 'Green', 'ssd', 480),
        ('Seagate', 'Barracuda', 'hdd', 2000)
    ],
    'tarjeta_grafica': [
        ('NVIDIA', 'RTX 3060', 12), ('NVIDIA', 'RTX 4070', 12), ('NVIDIA', 'GTX 1650', 4),
        ('AMD', 'Radeon RX 6600', 8), ('AMD', 'Radeon RX 7800 XT', 16)
    ],
    'placa_madre': [
        ('ASUS', 'ROG Strix B550-F', 'AM4', 'ATX'), ('Gigabyte', 'B760M DS3H', 'LGA1700', 'Micro-ATX'),
        ('MSI', 'PRO H610M-E', 'LGA1700', 'Micro-ATX'), ('ASRock', 'B450M Steel Legend', 'AM4', 'Micro-ATX')
    ],
    'fuente_poder': [
        ('Corsair', 'CV650', 650, '80 Plus Bronze'), ('EVGA', '600 W1', 600, '80 Plus White'),
        ('Seasonical', 'Focus GX-750', 750, '80 Plus Gold'), ('Thermaltake', 'Smart 500W', 500, '80 Plus White')
    ]
}

comp_types = list(componentes_detalles.keys())

for i in range(800):
    tipo = random.choice(comp_types)
    estado = random.choices(['operativo', 'almacenado', 'mantenimiento', 'baja'], weights=[70, 20, 5, 5])[0]
    
    # Restricción chk_componente_destino: id_equipo XOR id_ambiente
    if estado == 'almacenado':
        id_equipo = None
        id_ambiente = random.choice(ambiente_ids)
    else:
        # Asignado a un equipo
        id_equipo = random.choice(equipo_ids)
        id_ambiente = None
        
    cursor.execute(
        "INSERT INTO `componente` (`id_equipo`, `id_ambiente`, `estado_componente`) VALUES (%s, %s, %s)",
        (id_equipo, id_ambiente, estado)
    )
    cid = cursor.lastrowid
    componente_ids.append(cid)
    
    # Insertar el detalle específico según el subtipo
    if tipo == 'procesador':
        marca, modelo = random.choice(componentes_detalles['procesador'])
        cursor.execute(
            "INSERT INTO `procesador` (`id_componente`, `marca`, `modelo`) VALUES (%s, %s, %s)",
            (cid, marca, modelo)
        )
    elif tipo == 'memoria_ram':
        marca, capacidad, tipo_ddr = random.choice(componentes_detalles['memoria_ram'])
        cursor.execute(
            "INSERT INTO `memoria_ram` (`id_componente`, `marca`, `capacidad_gb`, `tipo_ddr`) VALUES (%s, %s, %s, %s)",
            (cid, marca, capacidad, tipo_ddr)
        )
    elif tipo == 'almacenamiento':
        marca, modelo, tipo_disco, capacidad = random.choice(componentes_detalles['almacenamiento'])
        cursor.execute(
            "INSERT INTO `almacenamiento` (`id_componente`, `marca`, `modelo`, `tipo`, `capacidad_gb`) VALUES (%s, %s, %s, %s, %s)",
            (cid, marca, modelo, tipo_disco, capacidad)
        )
    elif tipo == 'tarjeta_grafica':
        marca, modelo, vram = random.choice(componentes_detalles['tarjeta_grafica'])
        cursor.execute(
            "INSERT INTO `tarjeta_grafica` (`id_componente`, `marca`, `modelo`, `vram_gb`) VALUES (%s, %s, %s, %s)",
            (cid, marca, modelo, vram)
        )
    elif tipo == 'placa_madre':
        marca, modelo, socket, factor = random.choice(componentes_detalles['placa_madre'])
        cursor.execute(
            "INSERT INTO `placa_madre` (`id_componente`, `marca`, `modelo`, `socket`, `factor_forma`) VALUES (%s, %s, %s, %s, %s)",
            (cid, marca, modelo, socket, factor)
        )
    elif tipo == 'fuente_poder':
        marca, modelo, potencia, cert = random.choice(componentes_detalles['fuente_poder'])
        cursor.execute(
            "INSERT INTO `fuente_poder` (`id_componente`, `marca`, `modelo`, `potencia_watts`, `certificacion`) VALUES (%s, %s, %s, %s, %s)",
            (cid, marca, modelo, potencia, cert)
        )

conn.commit()
print(f"   ✅ {len(componente_ids)} componentes y sus subtipos insertados en cascada.")

# =============================================================================
# 5. INCIDENCIAS / SEGUIMIENTOS (350 registros)
# =============================================================================
print("🎫 Insertando Incidencias y Seguimientos...")

# Desplegar a lo largo de 2025 y 2026
start_date = datetime(2025, 1, 1)
end_date = datetime(2026, 12, 31)

problemas = [
    "Fallo en la fuente de alimentación, el equipo no enciende.",
    "Problema con la conexión de red local, desconexión intermitente.",
    "El monitor parpadea constantemente al encender el equipo.",
    "Error de sistema operativo: Pantallazo azul de error de memoria (BSOD).",
    "El proyector muestra colores distorsionados o amarillentos.",
    "Sobrecalentamiento excesivo y reinicios imprevistos de la CPU.",
    "El disco duro hace ruidos inusuales y la lectura de archivos es extremadamente lenta.",
    "El teclado y mouse no responden a pesar de estar conectados físicamente.",
    "Infección sospechosa por malware en el equipo de administración.",
    "El ventilador del procesador emite vibraciones ruidosas y molestas."
]

diagnosticos = [
    "Fuente de poder quemada debido a una sobrecarga de energía.",
    "Configuración IP manual duplicada en el segmento DHCP del ambiente.",
    "Fallo en el cable de video VGA/HDMI o soldaduras internas flojas en el conector.",
    "Un módulo de memoria RAM presenta sectores corruptos físicos.",
    "Lámpara del proyector agotada tras superar el límite de horas de vida útil.",
    "Pasta térmica del disipador de calor completamente reseca.",
    "Disco duro HDD con sectores dañados físicamente en la pista cero.",
    "Conectores USB internos de la placa madre desconectados o en cortocircuito.",
    "Presencia de troyanos activos realizando peticiones inusuales en red local.",
    "Ventilador del disipador desgastado y con acumulación de polvo denso."
]

trabajos = [
    "Se reemplazó la fuente de poder por una nueva de stock con certificación 80 Plus.",
    "Se reconfiguró la tarjeta de red a direccionamiento automático por DHCP.",
    "Se cambió el cable HDMI averiado por uno nuevo con apantallamiento magnético.",
    "Se extrajo el módulo RAM defectuoso y se colocó un módulo DDR4 de repuesto.",
    "Se realizó el cambio de lámpara de proyector y se limpió el filtro de aire.",
    "Se limpió la CPU con aire comprimido y se renovó la pasta térmica con Artic MX-4.",
    "Se clonó el disco hacia una unidad de estado sólido (SSD) de stock.",
    "Se reconectó el bus de la placa madre y se probaron los periféricos.",
    "Se corrió un análisis antivirus en modo seguro y se aislaron los archivos corruptos.",
    "Se lubricó el eje del ventilador y se fijaron los tornillos de soporte."
]

incidencia_ids = []
total_seguimientos = 0

for i in range(350):
    # Generar fecha de creación aleatoria distribuida cronológicamente
    random_days = random.randint(0, (end_date - start_date).days)
    random_hours = random.randint(0, 23)
    random_minutes = random.randint(0, 59)
    fecha_creacion = start_date + timedelta(days=random_days, hours=random_hours, minutes=random_minutes)
    
    id_equipo = random.choice(equipo_ids) if random.random() < 0.8 else None
    id_usuario_reporta = random.choice(usuario_ids)
    id_tecnico_recibe = random.choice(tecnico_ids)
    
    descripcion = random.choice(problemas)
    prioridad = random.choices(['baja', 'media', 'alta'], weights=[30, 50, 20])[0]
    estado = random.choices(['pendiente', 'en_proceso', 'resuelta', 'cerrada'], weights=[10, 20, 60, 10])[0]
    
    # Configurar fecha de resolución si aplica
    if estado in ['resuelta', 'cerrada']:
        # Se resuelve entre 2 horas y 5 días después de creada
        delay_hours = random.randint(2, 120)
        fecha_resolucion = fecha_creacion + timedelta(hours=delay_hours)
    else:
        fecha_resolucion = None
        
    cursor.execute(
        "INSERT INTO `incidencia` (`id_equipo`, `id_usuario_reporta`, `id_tecnico_recibe`, `descripcion`, `prioridad`, `estado`, `fecha_creacion`, `fecha_resolucion`) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
        (id_equipo, id_usuario_reporta, id_tecnico_recibe, descripcion, prioridad, estado, fecha_creacion, fecha_resolucion)
    )
    inc_id = cursor.lastrowid
    incidencia_ids.append(inc_id)
    
    # Crear seguimientos para tickets que han avanzado
    if estado in ['en_proceso', 'resuelta', 'cerrada']:
        # Determinar cuántos seguimientos tiene (entre 1 y 3)
        num_segs = random.randint(1, 3)
        for s in range(num_segs):
            # Fecha del seguimiento intermedia
            if fecha_resolucion:
                seg_date = fecha_creacion + (fecha_resolucion - fecha_creacion) * ((s + 1) / (num_segs + 1))
            else:
                seg_date = fecha_creacion + timedelta(hours=random.randint(1, 24))
                
            id_tecnico_seg = random.choice(tecnico_ids)
            diagnostico_seg = random.choice(diagnosticos)
            trabajo_seg = random.choice(trabajos)
            horas = round(random.uniform(0.5, 6.0), 2)
            
            # Opción de cambiar componente
            id_comp_cambiado = None
            if random.random() < 0.15:  # 15% de probabilidad de cambio físico de hardware
                id_comp_cambiado = random.choice(componente_ids)
                
            cursor.execute(
                "INSERT INTO `seguimiento_incidencia` (`id_incidencia`, `id_tecnico`, `diagnostico`, `trabajo_realizado`, `horas_invertidas`, `id_componente_cambiado`, `fecha`) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (inc_id, id_tecnico_seg, diagnostico_seg, trabajo_seg, horas, id_comp_cambiado, seg_date)
            )
            total_seguimientos += 1

conn.commit()
print(f"   ✅ {len(incidencia_ids)} incidencias insertadas.")
print(f"   ✅ {total_seguimientos} seguimientos técnicos asociados.")

# =============================================================================
# 6. SOLICITUDES Y SOFTWARE ADICIONAL
# =============================================================================
print("📝 Insertando Solicitudes y Software...")

# 50 Solicitudes de Jefes
for i in range(50):
    jefe_id = random.choice(jefes_ids)
    tipo = random.choice(['remodelacion', 'mejora', 'reemplazo'])
    descripcion = f"Solicitud de {tipo} para el correcto funcionamiento del área. Requerimiento urgente."
    estado = random.choices(['pendiente', 'aprobada', 'rechazada', 'completada'], weights=[30, 40, 20, 10])[0]
    
    # Fecha de solicitud
    random_days = random.randint(0, 365)
    fecha_sol = datetime(2025, 6, 1) + timedelta(days=random_days)
    
    if estado != 'pendiente':
        fecha_resp = fecha_sol + timedelta(days=random.randint(1, 15))
    else:
        fecha_resp = None
        
    cursor.execute(
        "INSERT INTO `solicitud` (`id_usuario_solicita`, `tipo`, `descripcion`, `estado`, `fecha_solicitud`, `fecha_respuesta`) VALUES (%s, %s, %s, %s, %s, %s)",
        (jefe_id, tipo, descripcion, estado, fecha_sol, fecha_resp)
    )

# 15 Programas de software en el catálogo
softwares = [
    'Windows 11 Pro', 'Windows 10 Pro', 'MS Office Pro 2021', 'MATLAB R2024a',
    'Autodesk AutoCAD 2024', 'Adobe Creative Cloud', 'Visual Studio Code',
    'Python 3.12', 'Docker Desktop', 'Git Version Control', 'MySQL Workbench',
    'Java JDK 21', 'Eclipse IDE', 'VirtualBox', 'Wireshark'
]
software_ids = []
for name in softwares:
    try:
        cursor.execute("INSERT INTO `software` (`nombre`) VALUES (%s)", (name,))
        software_ids.append(cursor.lastrowid)
    except mysql.connector.Error:
        pass

# 150 Instalaciones de software en los equipos de forma aleatoria
licencias = ['libre', 'propietaria', 'educativa', 'trial']
for _ in range(150):
    id_eq = random.choice(equipo_ids)
    id_sw = random.choice(software_ids)
    lic = random.choice(licencias)
    clave = fake.uuid4().upper() if lic == 'propietaria' else None
    
    random_days = random.randint(0, 365)
    fecha_ins = datetime(2025, 1, 1) + timedelta(days=random_days)
    fecha_exp = fecha_ins + timedelta(days=365) if lic in ['propietaria', 'trial'] else None
    
    try:
        cursor.execute(
            "INSERT INTO `software_instalado` (`id_equipo`, `id_software`, `tipo_licencia`, `clave_licencia`, `fecha_instalacion`, `fecha_expiracion`) VALUES (%s, %s, %s, %s, %s, %s)",
            (id_eq, id_sw, lic, clave, fecha_ins.date(), fecha_exp.date() if fecha_exp else None)
        )
    except mysql.connector.Error:
        pass

conn.commit()

# Reestablecer foreign keys
cursor.execute("SET FOREIGN_KEY_CHECKS = 1;")
cursor.close()
conn.close()

print("\n🎉 ¡Poblado de Base de Datos completado de manera exitosa!")
