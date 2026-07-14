// State management de la sesión simulada
let currentSession = {
    userId: null,
    userName: '',
    role: '' // jefe, empleado, tecnico, practicante, administrador_sistema
};

// Form editing states
let editingTecnicoId = null;
let editingUsuarioId = null;
let editingComponenteId = null;

// DOM Elements
const DOM = {
    viewRoleSelection: document.getElementById('view-role-selection'),
    viewLoginSimulation: document.getElementById('view-login-simulation'),
    viewEmpleadoDashboard: document.getElementById('view-empleado-dashboard'),
    viewPracticanteDashboard: document.getElementById('view-practicante-dashboard'),
    viewTecnicoDashboard: document.getElementById('view-tecnico-dashboard'),
    viewAdminDashboard: document.getElementById('view-admin-dashboard'),
    
    userSessionInfo: document.getElementById('user-session-info'),
    sessionName: document.getElementById('session-name'),
    sessionBadge: document.getElementById('session-badge'),
    btnLogout: document.getElementById('btn-logout'),
    btnBackRoles: document.getElementById('btn-back-roles'),
    selectUserSimulation: document.getElementById('select-user-simulation'),
    btnConfirmLogin: document.getElementById('btn-confirm-login'),
    toastContainer: document.getElementById('toast-container')
};

// =============================================================================
// FUNCIONES AUXILIARES (TOASTS)
// =============================================================================
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    DOM.toastContainer.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease reverse forwards';
        setTimeout(() => toast.remove(), 300);
    }, 4000);
}

// Format date strings nicely
function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString('es-PE', { timeZone: 'America/Lima' });
}

function formatDateShort(dateStr) {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleDateString('es-PE');
}

// =============================================================================
// 1. CODIGO DE EMPLEADO Y JEFE
// =============================================================================
const EmpDOM = {
    btnNavRegistrar: document.getElementById('btn-nav-registrar'),
    btnNavRevisar: document.getElementById('btn-nav-revisar'),
    btnNavCrearSolicitud: document.getElementById('btn-nav-crear-solicitud'),
    btnNavRevisarSolicitudes: document.getElementById('btn-nav-revisar-solicitudes'),
    panelRegistrarIncidencia: document.getElementById('panel-registrar-incidencia'),
    panelRevisarIncidencias: document.getElementById('panel-revisar-incidencias'),
    panelCrearSolicitud: document.getElementById('panel-crear-solicitud'),
    panelRevisarSolicitudes: document.getElementById('panel-revisar-solicitudes'),
    
    formRegistrarIncidencia: document.getElementById('form-registrar-incidencia'),
    regIdEquipo: document.getElementById('reg-id-equipo'),
    regPrioridad: document.getElementById('reg-prioridad'),
    regDescripcion: document.getElementById('reg-descripcion'),
    
    formCrearSolicitud: document.getElementById('form-crear-solicitud'),
    solTipo: document.getElementById('sol-tipo'),
    solDescripcion: document.getElementById('sol-descripcion'),
    
    tbodyIncidencias: document.getElementById('tbody-incidencias'),
    cardSeguimientoDetalle: document.getElementById('card-seguimiento-detalle'),
    btnCloseDetail: document.getElementById('btn-close-detail'),
    detailIdIncidencia: document.getElementById('detail-id-incidencia'),
    detailEquipo: document.getElementById('detail-equipo'),
    detailDescripcion: document.getElementById('detail-descripcion'),
    detailEstado: document.getElementById('detail-estado'),
    timelineSeguimiento: document.getElementById('timeline-seguimiento'),
    
    tbodySolicitudes: document.getElementById('tbody-solicitudes'),
    cardSolicitudDetalle: document.getElementById('card-solicitud-detalle'),
    btnCloseSolDetail: document.getElementById('btn-close-sol-detail'),
    solDetailId: document.getElementById('sol-detail-id'),
    solDetailTipo: document.getElementById('sol-detail-tipo'),
    solDetailEstado: document.getElementById('sol-detail-estado'),
    solDetailFecha: document.getElementById('sol-detail-fecha'),
    solDetailDescripcion: document.getElementById('sol-detail-descripcion'),
    solResponseContainer: document.getElementById('sol-response-container'),
    solDetailRespuestaFecha: document.getElementById('sol-detail-respuesta-fecha')
};

// Cargar equipos del área del empleado
async function loadEquiposEmpleado() {
    try {
        const res = await fetch(`/api/equipos/usuario/${currentSession.userId}`);
        const equipos = await res.json();
        EmpDOM.regIdEquipo.innerHTML = '<option value="" disabled selected>Selecciona el equipo...</option>';
        equipos.forEach(eq => {
            const opt = document.createElement('option');
            opt.value = eq.id_equipo;
            opt.textContent = `${eq.codigo_inventario} - ${eq.tipo.toUpperCase()} (${eq.marca || 'Genérico'}) [${eq.estado}]`;
            EmpDOM.regIdEquipo.appendChild(opt);
        });
    } catch (err) {
        showToast('Error al cargar equipos de oficina.', 'danger');
    }
}

// Cargar incidencias reportadas por el empleado
async function loadIncidenciasEmpleado() {
    try {
        const res = await fetch(`/api/empleado/incidencias/${currentSession.userId}`);
        const incidencias = await res.json();
        EmpDOM.tbodyIncidencias.innerHTML = '';
        if (incidencias.length === 0) {
            EmpDOM.tbodyIncidencias.innerHTML = `<tr><td colspan="5" class="empty-state">No tienes incidencias registradas.</td></tr>`;
            return;
        }
        incidencias.forEach(inc => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${inc.id_incidencia}</td>
                <td>EQUIP-${inc.id_equipo}</td>
                <td>${inc.descripcion}</td>
                <td><span class="badge badge-${inc.estado}">${inc.estado}</span></td>
                <td><button class="btn btn-secondary btn-sm btn-emp-ver" data-id="${inc.id_incidencia}" data-eq="EQUIP-${inc.id_equipo}" data-desc="${inc.descripcion}" data-est="${inc.estado}">Ver Seguimiento</button></td>
            `;
            EmpDOM.tbodyIncidencias.appendChild(row);
        });
        
        EmpDOM.tbodyIncidencias.querySelectorAll('.btn-emp-ver').forEach(btn => {
            btn.addEventListener('click', () => {
                showIncidenciaSeguimientoEmpleado(
                    btn.getAttribute('data-id'),
                    btn.getAttribute('data-eq'),
                    btn.getAttribute('data-desc'),
                    btn.getAttribute('data-est')
                );
            });
        });
    } catch (err) {
        showToast('Error al cargar incidencias.', 'danger');
    }
}

async function showIncidenciaSeguimientoEmpleado(id, equipo, desc, estado) {
    try {
        EmpDOM.detailIdIncidencia.textContent = id;
        EmpDOM.detailEquipo.textContent = equipo;
        EmpDOM.detailDescripcion.textContent = desc;
        EmpDOM.detailEstado.className = `badge badge-${estado}`;
        EmpDOM.detailEstado.textContent = estado;
        
        const res = await fetch(`/api/empleado/incidencias/seguimiento/${id}`);
        const seguimiento = await res.json();
        EmpDOM.timelineSeguimiento.innerHTML = '';
        
        if (seguimiento.length === 0) {
            EmpDOM.timelineSeguimiento.innerHTML = '<div class="empty-state">Aún no se registra avance técnico para esta incidencia.</div>';
        } else {
            seguimiento.forEach(seg => {
                const item = document.createElement('div');
                item.className = 'timeline-item';
                item.innerHTML = `
                    <div class="timeline-header">
                        <span class="timeline-title">${seg.tecnico_nombre} (Soporte)</span>
                        <span class="timeline-date">${formatDate(seg.fecha)}</span>
                    </div>
                    <div class="timeline-body">
                        <p><strong>Diagnóstico:</strong> ${seg.diagnostico}</p>
                        <p><strong>Trabajo:</strong> ${seg.trabajo_realizado}</p>
                    </div>
                    <div class="timeline-meta">
                        <span>Horas invertidas: ${seg.horas_invertidas} hrs</span>
                    </div>
                `;
                EmpDOM.timelineSeguimiento.appendChild(item);
            });
        }
        EmpDOM.cardSeguimientoDetalle.classList.remove('hidden');
    } catch (err) {
        showToast('Error al cargar el seguimiento de la incidencia.', 'danger');
    }
}

// Cargar solicitudes del jefe
async function loadSolicitudesJefe() {
    try {
        const res = await fetch(`/api/jefe/solicitudes/${currentSession.userId}`);
        const solicitudes = await res.json();
        EmpDOM.tbodySolicitudes.innerHTML = '';
        if (solicitudes.length === 0) {
            EmpDOM.tbodySolicitudes.innerHTML = `<tr><td colspan="6" class="empty-state">No posees solicitudes de área registradas.</td></tr>`;
            return;
        }
        solicitudes.forEach(sol => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${sol.id_solicitud}</td>
                <td>${sol.tipo.toUpperCase()}</td>
                <td>${sol.descripcion}</td>
                <td><span class="badge badge-${sol.estado}">${sol.estado}</span></td>
                <td>${formatDateShort(sol.fecha_solicitud)}</td>
                <td><button class="btn btn-secondary btn-sm btn-jefe-sol-ver" data-id="${sol.id_solicitud}">Ver Detalle</button></td>
            `;
            EmpDOM.tbodySolicitudes.appendChild(row);
        });
        
        EmpDOM.tbodySolicitudes.querySelectorAll('.btn-jefe-sol-ver').forEach(btn => {
            btn.addEventListener('click', () => {
                showSolicitudDetalleJefe(btn.getAttribute('data-id'));
            });
        });
    } catch (err) {
        showToast('Error al cargar solicitudes.', 'danger');
    }
}

async function showSolicitudDetalleJefe(id) {
    try {
        const res = await fetch(`/api/jefe/solicitudes/detalle/${id}`);
        const sol = await res.json();
        
        EmpDOM.solDetailId.textContent = sol.id_solicitud;
        EmpDOM.solDetailTipo.textContent = sol.tipo.toUpperCase();
        EmpDOM.solDetailEstado.className = `badge badge-${sol.estado}`;
        EmpDOM.solDetailEstado.textContent = sol.estado;
        EmpDOM.solDetailFecha.textContent = formatDate(sol.fecha_solicitud);
        EmpDOM.solDetailDescripcion.textContent = sol.descripcion;
        
        if (sol.fecha_respuesta) {
            EmpDOM.solDetailRespuestaFecha.textContent = `Atendida el: ${formatDate(sol.fecha_respuesta)}`;
            EmpDOM.solResponseContainer.classList.remove('hidden');
        } else {
            EmpDOM.solResponseContainer.classList.add('hidden');
        }
        EmpDOM.cardSolicitudDetalle.classList.remove('hidden');
    } catch (err) {
        showToast('Error al cargar el detalle de la solicitud.', 'danger');
    }
}

// Reset y desactivar pestañas de empleado
function deactivateEmpleadoTabs() {
    EmpDOM.btnNavRegistrar.classList.remove('active');
    EmpDOM.btnNavRevisar.classList.remove('active');
    EmpDOM.btnNavCrearSolicitud.classList.remove('active');
    EmpDOM.btnNavRevisarSolicitudes.classList.remove('active');
    
    EmpDOM.panelRegistrarIncidencia.classList.add('hidden');
    EmpDOM.panelRevisarIncidencias.classList.add('hidden');
    EmpDOM.panelCrearSolicitud.classList.add('hidden');
    EmpDOM.panelRevisarSolicitudes.classList.add('hidden');
    
    EmpDOM.cardSeguimientoDetalle.classList.add('hidden');
    EmpDOM.cardSolicitudDetalle.classList.add('hidden');
}

// Eventos de Navegación Empleado
EmpDOM.btnNavRegistrar.addEventListener('click', () => {
    deactivateEmpleadoTabs();
    EmpDOM.btnNavRegistrar.classList.add('active');
    EmpDOM.panelRegistrarIncidencia.classList.remove('hidden');
    loadEquiposEmpleado();
});

EmpDOM.btnNavRevisar.addEventListener('click', () => {
    deactivateEmpleadoTabs();
    EmpDOM.btnNavRevisar.classList.add('active');
    EmpDOM.panelRevisarIncidencias.classList.remove('hidden');
    loadIncidenciasEmpleado();
});

EmpDOM.btnNavCrearSolicitud.addEventListener('click', () => {
    deactivateEmpleadoTabs();
    EmpDOM.btnNavCrearSolicitud.classList.add('active');
    EmpDOM.panelCrearSolicitud.classList.remove('hidden');
});

EmpDOM.btnNavRevisarSolicitudes.addEventListener('click', () => {
    deactivateEmpleadoTabs();
    EmpDOM.btnNavRevisarSolicitudes.classList.add('active');
    EmpDOM.panelRevisarSolicitudes.classList.remove('hidden');
    loadSolicitudesJefe();
});

EmpDOM.btnCloseDetail.addEventListener('click', () => EmpDOM.cardSeguimientoDetalle.classList.add('hidden'));
EmpDOM.btnCloseSolDetail.addEventListener('click', () => EmpDOM.cardSolicitudDetalle.classList.add('hidden'));

// Registrar Incidencia (Empleado)
EmpDOM.formRegistrarIncidencia.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_usuario: currentSession.userId,
        id_equipo: EmpDOM.regIdEquipo.value,
        prioridad: EmpDOM.regPrioridad.value,
        descripcion: EmpDOM.regDescripcion.value.trim()
    };
    if (!data.id_equipo) {
        showToast('Selecciona el equipo afectado.', 'warning');
        return;
    }
    try {
        const res = await fetch('/api/empleado/incidencia', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Incidencia registrada correctamente!');
            EmpDOM.formRegistrarIncidencia.reset();
            EmpDOM.btnNavRevisar.click();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error de red al registrar incidencia.', 'danger');
    }
});

// Crear Solicitud (Jefe)
EmpDOM.formCrearSolicitud.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_usuario: currentSession.userId,
        tipo: EmpDOM.solTipo.value,
        descripcion: EmpDOM.solDescripcion.value.trim()
    };
    try {
        const res = await fetch('/api/jefe/solicitud', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Solicitud enviada a la oficina de TI!');
            EmpDOM.formCrearSolicitud.reset();
            EmpDOM.btnNavRevisarSolicitudes.click();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al enviar solicitud.', 'danger');
    }
});

// =============================================================================
// 2. CODIGO DE PRACTICANTE
// =============================================================================
const PracDOM = {
    btnNavIncidencias: document.getElementById('btn-prac-nav-incidencias'),
    btnNavComponentes: document.getElementById('btn-prac-nav-componentes'),
    btnNavSoftware: document.getElementById('btn-prac-nav-software'),
    panelIncidencias: document.getElementById('panel-prac-incidencias'),
    panelComponentes: document.getElementById('panel-prac-componentes'),
    panelSoftware: document.getElementById('panel-prac-software'),
    
    tbodyIncidencias: document.getElementById('tbody-prac-incidencias'),
    tbodyComponentes: document.getElementById('tbody-prac-componentes'),
    tbodySoftware: document.getElementById('tbody-prac-software'),
    
    cardAtencionDetalle: document.getElementById('card-prac-atencion-detalle'),
    btnCloseDetail: document.getElementById('btn-close-prac-detail'),
    detailId: document.getElementById('prac-detail-id'),
    detailEquipo: document.getElementById('prac-detail-equipo'),
    detailDescripcion: document.getElementById('prac-detail-descripcion'),
    detailEstado: document.getElementById('prac-detail-estado'),
    
    formSeguimiento: document.getElementById('form-prac-registrar-seguimiento'),
    segDiagnostico: document.getElementById('prac-seg-diagnostico'),
    segTrabajo: document.getElementById('prac-seg-trabajo'),
    segHoras: document.getElementById('prac-seg-horas'),
    segEstado: document.getElementById('prac-seg-nuevo-estado'),
    segComponente: document.getElementById('prac-seg-componente')
};

// Cargar métricas rápidas UDF del practicante
async function loadPracticanteMetrics() {
    try {
        const res = await fetch(`/api/tecnicos/metricas-individuales/${currentSession.userId}`);
        const data = await res.json();
        document.getElementById('prac-stat-asignados').textContent = data.asignados || 0;
        document.getElementById('prac-stat-pendientes').textContent = data.pendientes || 0;
        document.getElementById('prac-stat-resueltos').textContent = data.resueltos || 0;
    } catch (err) {
        console.error(err);
    }
}

// Cargar incidencias asignadas al practicante
async function loadIncidenciasPracticante() {
    try {
        const res = await fetch(`/api/soporte/incidencias/${currentSession.userId}`);
        const data = await res.json();
        PracDOM.tbodyIncidencias.innerHTML = '';
        
        if (data.length === 0) {
            PracDOM.tbodyIncidencias.innerHTML = `<tr><td colspan="7" class="empty-state">No posees incidencias asignadas.</td></tr>`;
            return;
        }
        
        data.forEach(inc => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${inc.id_incidencia}</td>
                <td>${inc.equipo_codigo || 'N/A'}</td>
                <td><span class="priority-badge priority-${inc.prioridad}">${inc.prioridad}</span></td>
                <td>${inc.usuario_reporta_nombre || 'N/A'}</td>
                <td>${inc.descripcion || ''}</td>
                <td><span class="badge badge-${inc.estado}">${inc.estado}</span></td>
                <td><button class="btn btn-primary btn-sm btn-prac-atender" data-id="${inc.id_incidencia}" data-eq="${inc.equipo_codigo || 'EQUIP-' + inc.id_equipo}" data-desc="${inc.descripcion}" data-est="${inc.estado}">Atender</button></td>
            `;
            PracDOM.tbodyIncidencias.appendChild(row);
        });

        PracDOM.tbodyIncidencias.querySelectorAll('.btn-prac-atender').forEach(btn => {
            btn.addEventListener('click', () => {
                showAtencionIncidenciaPracticante(
                    btn.getAttribute('data-id'),
                    btn.getAttribute('data-eq'),
                    btn.getAttribute('data-desc'),
                    btn.getAttribute('data-est')
                );
            });
        });
    } catch (err) {
        showToast('Error al cargar incidencias de practicante.', 'danger');
    }
}

async function showAtencionIncidenciaPracticante(id, equipo, desc, estado) {
    PracDOM.detailId.textContent = id;
    PracDOM.detailEquipo.textContent = equipo;
    PracDOM.detailDescripcion.textContent = desc;
    PracDOM.detailEstado.className = `badge badge-${estado}`;
    PracDOM.detailEstado.textContent = estado;
    
    // Cargar componentes disponibles en el stock para el cambio de hardware
    try {
        const res = await fetch('/api/componentes/todos');
        const componentes = await res.json();
        PracDOM.segComponente.innerHTML = '<option value="">-- Ninguno / No se requirió cambio --</option>';
        componentes.filter(c => c.estado_fisico === 'almacenado').forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.componente_id;
            opt.textContent = `${c.tipo} - ${c.especificaciones_tecnicas} (${c.asignado_a})`;
            PracDOM.segComponente.appendChild(opt);
        });
    } catch (err) {
        console.error(err);
    }
    
    PracDOM.cardAtencionDetalle.classList.remove('hidden');
    setTimeout(() => {
        PracDOM.cardAtencionDetalle.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 50);
}

// Cargar todos los componentes (Practicante)
async function loadComponentesPracticante() {
    try {
        const res = await fetch('/api/componentes/todos');
        const componentes = await res.json();
        PracDOM.tbodyComponentes.innerHTML = '';
        if (componentes.length === 0) {
            PracDOM.tbodyComponentes.innerHTML = `<tr><td colspan="5" class="empty-state">No hay componentes en la Base de Datos.</td></tr>`;
            return;
        }
        componentes.forEach(c => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${c.componente_id}</td>
                <td><strong>${c.tipo}</strong></td>
                <td>${c.especificaciones_tecnicas}</td>
                <td><span class="badge badge-${c.estado_fisico}">${c.estado_fisico}</span></td>
                <td>${c.asignado_a || 'Sin Asignación'}</td>
            `;
            PracDOM.tbodyComponentes.appendChild(row);
        });
    } catch (err) {
        showToast('Error al cargar inventario de componentes.', 'danger');
    }
}

// Cargar catálogo de software instalado
async function loadSoftwarePracticante() {
    try {
        const res = await fetch('/api/inventario/software/instalado');
        const software = await res.json();
        PracDOM.tbodySoftware.innerHTML = '';
        if (software.length === 0) {
            PracDOM.tbodySoftware.innerHTML = `<tr><td colspan="6" class="empty-state">No hay registros de instalaciones de software.</td></tr>`;
            return;
        }
        software.forEach(sw => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${sw.codigo_inventario}</td>
                <td><strong>${sw.nombre_software}</strong></td>
                <td>${sw.tipo_licencia.toUpperCase()}</td>
                <td><code>${sw.clave_licencia || 'Libre'}</code></td>
                <td>${formatDateShort(sw.fecha_instalacion)}</td>
                <td>${formatDateShort(sw.fecha_expiracion)}</td>
            `;
            PracDOM.tbodySoftware.appendChild(row);
        });
    } catch (err) {
        showToast('Error al cargar auditoría de software.', 'danger');
    }
}

// Reset y desactivar pestañas del practicante
function deactivatePracticanteTabs() {
    PracDOM.btnNavIncidencias.classList.remove('active');
    PracDOM.btnNavComponentes.classList.remove('active');
    PracDOM.btnNavSoftware.classList.remove('active');
    
    PracDOM.panelIncidencias.classList.add('hidden');
    PracDOM.panelComponentes.classList.add('hidden');
    PracDOM.panelSoftware.classList.add('hidden');
    PracDOM.cardAtencionDetalle.classList.add('hidden');
}

// Eventos Practicante Nav
PracDOM.btnNavIncidencias.addEventListener('click', () => {
    deactivatePracticanteTabs();
    PracDOM.btnNavIncidencias.classList.add('active');
    PracDOM.panelIncidencias.classList.remove('hidden');
    loadIncidenciasPracticante();
    loadPracticanteMetrics();
});

PracDOM.btnNavComponentes.addEventListener('click', () => {
    deactivatePracticanteTabs();
    PracDOM.btnNavComponentes.classList.add('active');
    PracDOM.panelComponentes.classList.remove('hidden');
    loadComponentesPracticante();
});

PracDOM.btnNavSoftware.addEventListener('click', () => {
    deactivatePracticanteTabs();
    PracDOM.btnNavSoftware.classList.add('active');
    PracDOM.panelSoftware.classList.remove('hidden');
    loadSoftwarePracticante();
});

PracDOM.btnCloseDetail.addEventListener('click', () => PracDOM.cardAtencionDetalle.classList.add('hidden'));

// Registrar Seguimiento (Practicante)
PracDOM.formSeguimiento.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_incidencia: PracDOM.detailId.textContent,
        id_tecnico: currentSession.userId,
        diagnostico: PracDOM.segDiagnostico.value.trim(),
        trabajo_realizado: PracDOM.segTrabajo.value.trim(),
        horas_invertidas: parseFloat(PracDOM.segHoras.value),
        id_componente_cambiado: PracDOM.segComponente.value || null,
        nuevo_estado: PracDOM.segEstado.value
    };
    
    try {
        const res = await fetch('/api/soporte/seguimiento/practicante', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Seguimiento registrado con éxito por Practicante!');
            PracDOM.formSeguimiento.reset();
            PracDOM.cardAtencionDetalle.classList.add('hidden');
            loadIncidenciasPracticante();
            loadPracticanteMetrics();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al enviar el seguimiento de soporte.', 'danger');
    }
});

// =============================================================================
// 3. CODIGO DE TECNICO
// =============================================================================
const TecDOM = {
    btnNavIncidencias: document.getElementById('btn-tec-nav-incidencias'),
    btnNavRegistrar: document.getElementById('btn-tec-nav-registrar'),
    btnNavSoftware: document.getElementById('btn-tec-nav-software'),
    btnNavSolicitudes: document.getElementById('btn-tec-nav-solicitudes'),
    btnNavComponentes: document.getElementById('btn-tec-nav-componentes'),
    
    panelIncidencias: document.getElementById('panel-tec-incidencias'),
    panelRegistrar: document.getElementById('panel-tec-registrar'),
    panelSoftware: document.getElementById('panel-tec-software'),
    panelSolicitudes: document.getElementById('panel-tec-solicitudes'),
    panelComponentes: document.getElementById('panel-tec-componentes'),
    
    tbodyIncidencias: document.getElementById('tbody-tec-incidencias'),
    
    filterEstado: document.getElementById('tec-filter-estado'),
    filterPrioridad: document.getElementById('tec-filter-prioridad'),
    filterUsuario: document.getElementById('tec-filter-usuario'),
    filterAsignacion: document.getElementById('tec-filter-asignacion'),
    sortOrden: document.getElementById('tec-sort-orden'),
    tbodySolicitudes: document.getElementById('tbody-tec-solicitudes'),
    tbodyComponentes: document.getElementById('tbody-tec-componentes'),
    
    cardAtencionDetalle: document.getElementById('card-tec-atencion-detalle'),
    btnCloseDetail: document.getElementById('btn-close-tec-detail'),
    detailId: document.getElementById('tec-detail-id'),
    
    formAsignar: document.getElementById('form-tec-asignar'),
    asignarPersonal: document.getElementById('tec-asignar-personal'),
    
    formSeguimiento: document.getElementById('form-tec-seguimiento'),
    segDiagnostico: document.getElementById('tec-seg-diagnostico'),
    segTrabajo: document.getElementById('tec-seg-trabajo'),
    segHoras: document.getElementById('tec-seg-horas'),
    segEstado: document.getElementById('tec-seg-estado'),
    
    formRegistrarIncidenciaDirecta: document.getElementById('form-tec-registrar-incidencia-directa'),
    incEquipo: document.getElementById('tec-inc-equipo'),
    incPrioridad: document.getElementById('tec-inc-prioridad'),
    incCreador: document.getElementById('tec-inc-creador'),
    incDescripcion: document.getElementById('tec-inc-descripcion'),
    
    // Equipos registro
    formRegistrarEquipo: document.getElementById('form-tec-registrar-equipo'),
    eqCodigo: document.getElementById('eq-codigo'),
    eqTipo: document.getElementById('eq-tipo'),
    eqOrigen: document.getElementById('eq-origen'),
    eqMarca: document.getElementById('eq-marca'),
    eqEstado: document.getElementById('eq-estado'),
    eqCantidad: document.getElementById('eq-cantidad'),
    eqAmbiente: document.getElementById('eq-ambiente'),
    eqUsuario: document.getElementById('eq-usuario'),
    
    subLaptop: document.getElementById('sub-panel-componentes-laptop'),
    subPC: document.getElementById('sub-panel-componentes-pc'),
    
    // Software
    formSoftwareCatalogo: document.getElementById('form-tec-software-catalogo'),
    softCatNombre: document.getElementById('soft-cat-nombre'),
    
    formSoftwareInstalar: document.getElementById('form-tec-software-instalar'),
    softInsEquipo: document.getElementById('soft-ins-equipo'),
    softInsSoftware: document.getElementById('soft-ins-software'),
    softInsLicencia: document.getElementById('soft-ins-licencia'),
    softInsClave: document.getElementById('soft-ins-clave'),
    softInsFecha: document.getElementById('soft-ins-fecha'),
    softInsExpiracion: document.getElementById('soft-ins-expiracion'),
    
    tbodySoftwareInstalado: document.getElementById('tbody-tec-software-instalado'),
    cardEditarSoftware: document.getElementById('card-tec-editar-software'),
    btnCloseSoftEdit: document.getElementById('btn-close-soft-edit'),
    formSoftwareEditar: document.getElementById('form-tec-software-editar'),
    softEditIdEquipo: document.getElementById('soft-edit-id-equipo'),
    softEditIdSoftware: document.getElementById('soft-edit-id-software'),
    softEditLicencia: document.getElementById('soft-edit-licencia'),
    softEditClave: document.getElementById('soft-edit-clave'),
    softEditFecha: document.getElementById('soft-edit-fecha'),
    softEditExpiracion: document.getElementById('soft-edit-expiracion')
};

// Cargar métricas UDF del técnico
async function loadTecnicoMetrics() {
    try {
        const res = await fetch(`/api/tecnicos/metricas-individuales/${currentSession.userId}`);
        const data = await res.json();
        document.getElementById('tec-stat-asignados').textContent = data.asignados || 0;
        document.getElementById('tec-stat-pendientes').textContent = data.pendientes || 0;
        document.getElementById('tec-stat-resueltos').textContent = data.resueltos || 0;
    } catch (err) {
        console.error(err);
    }
}

// Cargar incidencias globales en el panel del técnico
async function loadIncidenciasTecnico() {
    await fetchAndRenderIncidencias('tecnico');
}

async function showAtencionIncidenciaTecnico(id) {
    TecDOM.detailId.textContent = id;
    
    // Cargar técnicos y practicantes activos para el SELECT de asignación
    try {
        const res = await fetch('/api/roles/tecnicos');
        const personal = await res.json();
        TecDOM.asignarPersonal.innerHTML = '<option value="" disabled selected>Selecciona técnico...</option>';
        personal.forEach(p => {
            const opt = document.createElement('option');
            opt.value = p.id_tecnico;
            opt.textContent = `${p.nombres} ${p.apellidos} (${p.rango.toUpperCase()})`;
            TecDOM.asignarPersonal.appendChild(opt);
        });
    } catch (err) {
        console.error(err);
    }
    
    TecDOM.cardAtencionDetalle.classList.remove('hidden');
    setTimeout(() => {
        TecDOM.cardAtencionDetalle.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 50);
}

// Cargar datos de iniciación para el registro de equipos (ambiente, usuarios, equipos)
async function loadTecnicoRegistrarInit() {
    try {
        // Cargar ambientes
        const resA = await fetch('/api/admin/areas');
        const areas = await resA.json();
        TecDOM.eqAmbiente.innerHTML = '<option value="" disabled selected>Selecciona ambiente...</option>';
        areas.forEach(a => {
            const opt = document.createElement('option');
            opt.value = a.id_ambiente;
            opt.textContent = `${a.pabellon} - ${a.numero} (${a.nombre})`;
            TecDOM.eqAmbiente.appendChild(opt);
        });
        
        // Cargar usuarios
        const resU = await fetch('/api/roles/usuarios');
        const usuarios = await resU.json();
        
        const populateSelect = (selectElem, placeholder) => {
            selectElem.innerHTML = `<option value="">${placeholder}</option>`;
            usuarios.forEach(u => {
                const opt = document.createElement('option');
                opt.value = u.id_usuario;
                opt.textContent = `${u.nombres} ${u.apellidos} (${u.cargo.toUpperCase()})`;
                selectElem.appendChild(opt);
            });
        };

        populateSelect(TecDOM.eqUsuario, '-- No Asignar a un Usuario Fijo --');
        populateSelect(TecDOM.incCreador, '-- Seleccione Usuario Reportante --');

        // Cargar todos los equipos activos
        const resE = await fetch('/api/equipos');
        const equipos = await resE.json();
        TecDOM.incEquipo.innerHTML = '<option value="" disabled selected>Seleccione el equipo afectado...</option>';
        TecDOM.softInsEquipo.innerHTML = '<option value="" disabled selected>Seleccione equipo...</option>';
        
        equipos.forEach(eq => {
            const opt = document.createElement('option');
            opt.value = eq.id_equipo;
            opt.textContent = `${eq.codigo_inventario} - ${eq.tipo.toUpperCase()} [${eq.marca || 'N/A'}]`;
            
            TecDOM.incEquipo.appendChild(opt.cloneNode(true));
            TecDOM.softInsEquipo.appendChild(opt);
        });
    } catch (err) {
        console.error(err);
    }
}

// Cargar datos de software (catálogo de software y software instalado)
async function loadTecnicoSoftwareDashboard() {
    try {
        // Cargar catálogo de software para el dropdown de instalación
        const resCat = await fetch('/api/inventario/software/catalogo');
        const catalogo = await resCat.json();
        TecDOM.softInsSoftware.innerHTML = '<option value="" disabled selected>Selecciona software...</option>';
        catalogo.forEach(sw => {
            const opt = document.createElement('option');
            opt.value = sw.id_software;
            opt.textContent = sw.nombre;
            TecDOM.softInsSoftware.appendChild(opt);
        });

        // Cargar tabla de software instalado
        const resInst = await fetch('/api/inventario/software/instalado');
        const instalado = await resInst.json();
        TecDOM.tbodySoftwareInstalado.innerHTML = '';
        if (instalado.length === 0) {
            TecDOM.tbodySoftwareInstalado.innerHTML = `<tr><td colspan="7" class="empty-state">No hay software registrado en los equipos.</td></tr>`;
            return;
        }
        instalado.forEach(ins => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${ins.codigo_inventario}</td>
                <td><strong>${ins.nombre_software}</strong></td>
                <td>${ins.tipo_licencia.toUpperCase()}</td>
                <td><code>${ins.clave_licencia || 'N/A'}</code></td>
                <td>${formatDateShort(ins.fecha_instalacion)}</td>
                <td>${formatDateShort(ins.fecha_expiracion)}</td>
                <td><button class="btn btn-secondary btn-sm btn-tec-soft-edit" data-eq="${ins.id_equipo}" data-soft="${ins.id_software}" data-lic="${ins.tipo_licencia}" data-clave="${ins.clave_licencia || ''}" data-fecha="${ins.fecha_instalacion.split('T')[0]}" data-exp="${ins.fecha_expiracion ? ins.fecha_expiracion.split('T')[0] : ''}">Editar</button></td>
            `;
            TecDOM.tbodySoftwareInstalado.appendChild(row);
        });

        TecDOM.tbodySoftwareInstalado.querySelectorAll('.btn-tec-soft-edit').forEach(btn => {
            btn.addEventListener('click', () => {
                TecDOM.softEditIdEquipo.value = btn.getAttribute('data-eq');
                TecDOM.softEditIdSoftware.value = btn.getAttribute('data-soft');
                TecDOM.softEditLicencia.value = btn.getAttribute('data-lic');
                TecDOM.softEditClave.value = btn.getAttribute('data-clave');
                TecDOM.softEditFecha.value = btn.getAttribute('data-fecha');
                TecDOM.softEditExpiracion.value = btn.getAttribute('data-exp');
                
                TecDOM.cardEditarSoftware.classList.remove('hidden');
                TecDOM.cardEditarSoftware.scrollIntoView({ behavior: 'smooth' });
            });
        });
    } catch (err) {
        showToast('Error al cargar la información del software.', 'danger');
    }
}

// Cargar solicitudes en el dashboard del técnico
async function loadSolicitudesTecnico() {
    try {
        const res = await fetch('/api/soporte/solicitudes');
        const data = await res.json();
        TecDOM.tbodySolicitudes.innerHTML = '';
        if (data.length === 0) {
            TecDOM.tbodySolicitudes.innerHTML = `<tr><td colspan="6" class="empty-state">No hay requerimientos en el sistema.</td></tr>`;
            return;
        }
        data.forEach(sol => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${sol.id_solicitud}</td>
                <td>${sol.jefe_nombres || 'Usuario'}</td>
                <td><strong>${sol.tipo.toUpperCase()}</strong></td>
                <td>${sol.descripcion}</td>
                <td>${formatDateShort(sol.fecha_solicitud)}</td>
                <td><span class="badge badge-${sol.estado}">${sol.estado}</span></td>
            `;
            TecDOM.tbodySolicitudes.appendChild(row);
        });
    } catch (err) {
        showToast('Error al cargar solicitudes de Jefes.', 'danger');
    }
}

// Cargar componentes (Técnico)
async function loadComponentesTecnico() {
    try {
        const res = await fetch('/api/componentes/todos');
        const data = await res.json();
        TecDOM.tbodyComponentes.innerHTML = '';
        if (data.length === 0) {
            TecDOM.tbodyComponentes.innerHTML = `<tr><td colspan="6" class="empty-state">No hay componentes en almacén o equipos.</td></tr>`;
            return;
        }
        data.forEach(c => {
            const row = document.createElement('tr');
            let actionsHtml = '<em>N/A</em>';
            if (c.estado_fisico === 'almacenado') {
                actionsHtml = `<button class="btn btn-primary btn-sm btn-tec-comp-assign" data-id="${c.componente_id}" data-desc="${c.tipo} - ${c.especificaciones_tecnicas}">Asignar a PC</button>`;
            }
            row.innerHTML = `
                <td>#${c.componente_id}</td>
                <td><strong>${c.tipo}</strong></td>
                <td>${c.especificaciones_tecnicas}</td>
                <td><span class="badge badge-${c.estado_fisico}">${c.estado_fisico}</span></td>
                <td>${c.asignado_a}</td>
                <td>${actionsHtml}</td>
            `;
            TecDOM.tbodyComponentes.appendChild(row);
        });

        TecDOM.tbodyComponentes.querySelectorAll('.btn-tec-comp-assign').forEach(btn => {
            btn.addEventListener('click', () => {
                abrirModalAsignacion(btn.getAttribute('data-id'), btn.getAttribute('data-desc'));
            });
        });
    } catch (err) {
        showToast('Error al cargar componentes.', 'danger');
    }
}

// Reset y desactivar pestañas del técnico
function deactivateTecnicoTabs() {
    TecDOM.btnNavIncidencias.classList.remove('active');
    TecDOM.btnNavRegistrar.classList.remove('active');
    TecDOM.btnNavSoftware.classList.remove('active');
    TecDOM.btnNavSolicitudes.classList.remove('active');
    TecDOM.btnNavComponentes.classList.remove('active');
    
    TecDOM.panelIncidencias.classList.add('hidden');
    TecDOM.panelRegistrar.classList.add('hidden');
    TecDOM.panelSoftware.classList.add('hidden');
    TecDOM.panelSolicitudes.classList.add('hidden');
    TecDOM.panelComponentes.classList.add('hidden');
    
    TecDOM.cardAtencionDetalle.classList.add('hidden');
    TecDOM.cardEditarSoftware.classList.add('hidden');
}

// Eventos de Navegación Técnico
TecDOM.btnNavIncidencias.addEventListener('click', () => {
    deactivateTecnicoTabs();
    TecDOM.btnNavIncidencias.classList.add('active');
    TecDOM.panelIncidencias.classList.remove('hidden');
    loadIncidenciasTecnico();
    loadTecnicoMetrics();
    loadTecnicoRegistrarInit(); // Carga usuarios y equipos en los dropdowns
});

TecDOM.btnNavRegistrar.addEventListener('click', () => {
    deactivateTecnicoTabs();
    TecDOM.btnNavRegistrar.classList.add('active');
    TecDOM.panelRegistrar.classList.remove('hidden');
    loadTecnicoRegistrarInit();
});

TecDOM.btnNavSoftware.addEventListener('click', () => {
    deactivateTecnicoTabs();
    TecDOM.btnNavSoftware.classList.add('active');
    TecDOM.panelSoftware.classList.remove('hidden');
    loadTecnicoRegistrarInit();
    loadTecnicoSoftwareDashboard();
});

TecDOM.btnNavSolicitudes.addEventListener('click', () => {
    deactivateTecnicoTabs();
    TecDOM.btnNavSolicitudes.classList.add('active');
    TecDOM.panelSolicitudes.classList.remove('hidden');
    loadSolicitudesTecnico();
});

TecDOM.btnNavComponentes.addEventListener('click', () => {
    deactivateTecnicoTabs();
    TecDOM.btnNavComponentes.classList.add('active');
    TecDOM.panelComponentes.classList.remove('hidden');
    loadComponentesTecnico();
});

TecDOM.btnCloseDetail.addEventListener('click', () => TecDOM.cardAtencionDetalle.classList.add('hidden'));
TecDOM.btnCloseSoftEdit.addEventListener('click', () => TecDOM.cardEditarSoftware.classList.add('hidden'));

// Mostrar/Ocultar paneles de componentes específicos según tipo de equipo
TecDOM.eqTipo.addEventListener('change', () => {
    const val = TecDOM.eqTipo.value;
    if (val === 'laptop') {
        TecDOM.subLaptop.classList.remove('hidden');
        TecDOM.subPC.classList.add('hidden');
    } else if (val === 'pc_escritorio') {
        TecDOM.subPC.classList.remove('hidden');
        TecDOM.subLaptop.classList.add('hidden');
    } else {
        TecDOM.subLaptop.classList.add('hidden');
        TecDOM.subPC.classList.add('hidden');
    }
});

// Registrar asignación (Técnico)
TecDOM.formAsignar.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_incidencia: TecDOM.detailId.textContent,
        id_tecnico_asignador: currentSession.userId,
        id_tecnico_asignado: TecDOM.asignarPersonal.value
    };
    try {
        const res = await fetch('/api/soporte/incidencia/asignar', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Asignación guardada correctamente!');
            TecDOM.cardAtencionDetalle.classList.add('hidden');
            loadIncidenciasTecnico();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al asignar personal técnico.', 'danger');
    }
});

// Registrar seguimiento (Técnico)
TecDOM.formSeguimiento.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_incidencia: TecDOM.detailId.textContent,
        id_tecnico: currentSession.userId,
        diagnostico: TecDOM.segDiagnostico.value.trim(),
        trabajo_realizado: TecDOM.segTrabajo.value.trim(),
        horas_invertidas: parseFloat(TecDOM.segHoras.value),
        nuevo_estado: TecDOM.segEstado.value
    };
    try {
        const res = await fetch('/api/soporte/seguimiento/tecnico', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Seguimiento registrado con éxito!');
            TecDOM.formSeguimiento.reset();
            TecDOM.cardAtencionDetalle.classList.add('hidden');
            loadIncidenciasTecnico();
            loadTecnicoMetrics();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error de red al enviar avance de soporte.', 'danger');
    }
});

// Registrar incidencia directa por soporte
TecDOM.formRegistrarIncidenciaDirecta.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_tecnico: currentSession.userId,
        id_equipo: TecDOM.incEquipo.value,
        prioridad: TecDOM.incPrioridad.value,
        descripcion: TecDOM.incDescripcion.value.trim()
    };
    try {
        const res = await fetch('/api/soporte/incidencia/tecnico', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Incidencia registrada correctamente en la BD!');
            TecDOM.formRegistrarIncidenciaDirecta.reset();
            loadIncidenciasTecnico();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al registrar incidencia técnica.', 'danger');
    }
});

// Registrar Equipos + Componentes en lote
TecDOM.formRegistrarEquipo.addEventListener('submit', async (e) => {
    e.preventDefault();
    const eqData = {
        codigo_inventario: TecDOM.eqCodigo.value.trim(),
        tipo: TecDOM.eqTipo.value,
        tipo_origen: TecDOM.eqOrigen.value,
        marca: TecDOM.eqMarca.value.trim(),
        estado: TecDOM.eqEstado.value,
        cantidad: parseInt(TecDOM.eqCantidad.value),
        id_ambiente: parseInt(TecDOM.eqAmbiente.value),
        id_usuario: TecDOM.eqUsuario.value ? parseInt(TecDOM.eqUsuario.value) : null,
        id_tecnico_sesion: currentSession.userId
    };

    try {
        const resEq = await fetch('/api/inventario/equipo', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(eqData)
        });
        const resultEq = await resEq.json();
        if (!resEq.ok) {
            showToast(`Error al registrar equipo base: ${resultEq.error}`, 'danger');
            return;
        }

        const newEquipoId = resultEq.last_inserted_id;
        
        // Si es Laptop y se ingresó un ID válido, registrar componentes
        if (eqData.tipo === 'laptop' && newEquipoId) {
            const lapData = {
                id_equipo: newEquipoId,
                modelo_laptop: document.getElementById('lap-modelo').value.trim(),
                codigo_serie_base: document.getElementById('lap-serie').value.trim(),
                marca_procesador: document.getElementById('lap-cpu-marca').value.trim(),
                modelo_procesador: document.getElementById('lap-cpu-modelo').value.trim(),
                tipo_ram: document.getElementById('lap-ram-tipo').value,
                capacidad_ram: parseInt(document.getElementById('lap-ram-capacidad').value),
                tipo_almacenamiento: document.getElementById('lap-disco-tipo').value,
                capacidad_almacenamiento: parseInt(document.getElementById('lap-disco-capacidad').value),
                tipo_graficos: document.getElementById('lap-gpu-tipo').value.trim(),
                modelo_grafica: document.getElementById('lap-gpu-modelo').value.trim(),
                id_tecnico_sesion: currentSession.userId
            };

            const resComp = await fetch('/api/inventario/componentes/laptop', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(lapData)
            });
            const resultComp = await resComp.json();
            if (!resComp.ok) {
                showToast(`Equipo creado, pero falló el registro de componentes: ${resultComp.error}`, 'danger');
                return;
            }
        }
        
        // Si es PC y se ingresó un ID válido, registrar componentes
        if (eqData.tipo === 'pc_escritorio' && newEquipoId) {
            const pcData = {
                id_equipo: newEquipoId,
                marca_procesador: document.getElementById('pc-cpu-marca').value.trim(),
                modelo_procesador: document.getElementById('pc-cpu-modelo').value.trim(),
                marca_ram: document.getElementById('pc-ram-marca').value.trim(),
                capacidad_ram: parseInt(document.getElementById('pc-ram-capacidad').value),
                tipo_ram: document.getElementById('pc-ram-tipo').value,
                marca_almacenamiento: document.getElementById('pc-disco-marca').value.trim(),
                modelo_almacenamiento: document.getElementById('pc-disco-modelo').value.trim(),
                tipo_disco: document.getElementById('pc-disco-tipo').value,
                capacidad_almacenamiento: parseInt(document.getElementById('pc-disco-capacidad').value),
                marca_placa: document.getElementById('pc-placa-marca').value.trim(),
                modelo_placa: document.getElementById('pc-placa-modelo').value.trim(),
                socket_placa: document.getElementById('pc-placa-socket').value.trim(),
                tamano_placa: document.getElementById('pc-placa-tamano').value.trim(),
                marca_fuente: document.getElementById('pc-fuente-marca').value.trim(),
                modelo_fuente: document.getElementById('pc-fuente-modelo').value.trim(),
                potencia_fuente: parseInt(document.getElementById('pc-fuente-potencia').value),
                certificacion_fuente: document.getElementById('pc-fuente-certificacion').value.trim(),
                marca_grafica: document.getElementById('pc-gpu-marca').value.trim(),
                modelo_gpu: document.getElementById('pc-gpu-modelo').value.trim(),
                vram_gpu: parseInt(document.getElementById('pc-gpu-vram').value),
                id_tecnico_sesion: currentSession.userId
            };

            const resComp = await fetch('/api/inventario/componentes/pc', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(pcData)
            });
            const resultComp = await resComp.json();
            if (!resComp.ok) {
                showToast(`Equipo creado, pero falló el registro de componentes de PC: ${resultComp.error}`, 'danger');
                return;
            }
        }

        showToast('¡Registro exitoso del lote de equipos y componentes hardware!');
        TecDOM.formRegistrarEquipo.reset();
        TecDOM.subLaptop.classList.add('hidden');
        TecDOM.subPC.classList.add('hidden');
    } catch (err) {
        showToast('Error de red al registrar inventario.', 'danger');
    }
});

// Catálogo Software
TecDOM.formSoftwareCatalogo.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        nombre: TecDOM.softCatNombre.value.trim(),
        id_tecnico_sesion: currentSession.userId
    };
    try {
        const res = await fetch('/api/inventario/software', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Software agregado al catálogo de la facultad!');
            TecDOM.formSoftwareCatalogo.reset();
            loadTecnicoSoftwareDashboard();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al registrar software.', 'danger');
    }
});

// Instalar Software
TecDOM.formSoftwareInstalar.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_equipo: parseInt(TecDOM.softInsEquipo.value),
        id_software: parseInt(TecDOM.softInsSoftware.value),
        tipo_licencia: TecDOM.softInsLicencia.value,
        clave_licencia: TecDOM.softInsClave.value.trim() || null,
        fecha_instalacion: TecDOM.softInsFecha.value,
        fecha_expiracion: TecDOM.softInsExpiracion.value || null,
        id_tecnico_sesion: currentSession.userId
    };
    try {
        const res = await fetch('/api/inventario/software/instalar', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Instalación registrada con éxito en el equipo!');
            TecDOM.formSoftwareInstalar.reset();
            loadTecnicoSoftwareDashboard();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al registrar la instalación.', 'danger');
    }
});

// Editar software instalado submit
TecDOM.formSoftwareEditar.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_equipo: parseInt(TecDOM.softEditIdEquipo.value),
        id_software: parseInt(TecDOM.softEditIdSoftware.value),
        tipo_licencia: TecDOM.softEditLicencia.value,
        clave_licencia: TecDOM.softEditClave.value.trim() || null,
        fecha_instalacion: TecDOM.softEditFecha.value,
        fecha_expiracion: TecDOM.softEditExpiracion.value || null,
        id_tecnico_sesion: currentSession.userId
    };
    try {
        const res = await fetch('/api/inventario/software/instalado', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Registro de software actualizado!');
            TecDOM.cardEditarSoftware.classList.add('hidden');
            loadTecnicoSoftwareDashboard();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al guardar cambios de software.', 'danger');
    }
});

// =============================================================================
// 4. CODIGO DE ADMINISTRADOR
// =============================================================================
const AdmDOM = {
    btnNavInicio: document.getElementById('btn-adm-nav-inicio'),
    btnNavIncidencias: document.getElementById('btn-adm-nav-incidencias'),
    btnNavTecnicos: document.getElementById('btn-adm-nav-tecnicos'),
    btnNavUsuarios: document.getElementById('btn-adm-nav-usuarios'),
    btnNavAreas: document.getElementById('btn-adm-nav-areas'),
    btnNavComponentes: document.getElementById('btn-adm-nav-componentes'),
    btnNavAuditoria: document.getElementById('btn-adm-nav-auditoria'),
    
    panelInicio: document.getElementById('panel-adm-inicio'),
    panelIncidencias: document.getElementById('panel-adm-incidencias'),
    panelTecnicos: document.getElementById('panel-adm-tecnicos'),
    panelUsuarios: document.getElementById('panel-adm-usuarios'),
    panelAreas: document.getElementById('panel-adm-areas'),
    panelComponentes: document.getElementById('panel-adm-componentes'),
    panelAuditoria: document.getElementById('panel-adm-auditoria'),
    
    tbodyUltimosIncidentes: document.getElementById('tbody-adm-ultimos-incidentes'),
    tbodyProcesarSolicitudes: document.getElementById('tbody-adm-procesar-solicitudes'),
    
    tbodyIncidencias: document.getElementById('tbody-adm-incidencias'),
    tbodyTecnicos: document.getElementById('tbody-adm-tecnicos'),
    tbodyMetricasTecnicos: document.getElementById('tbody-adm-metricas-tecnicos'),
    tbodyUsuarios: document.getElementById('tbody-adm-usuarios'),
    tbodyAreas: document.getElementById('tbody-adm-areas'),
    tbodyComponentes: document.getElementById('tbody-adm-componentes'),
    tbodyAuditoria: document.getElementById('tbody-adm-auditoria'),

    cardAtencionDetalle: document.getElementById('card-adm-atencion-detalle'),
    btnCloseDetail: document.getElementById('btn-close-adm-detail'),
    detailId: document.getElementById('adm-detail-id'),
    
    formAsignar: document.getElementById('form-adm-asignar'),
    asignarPersonal: document.getElementById('adm-asignar-personal'),
    
    formSeguimiento: document.getElementById('form-adm-seguimiento'),
    segDiagnostico: document.getElementById('adm-seg-diagnostico'),
    segTrabajo: document.getElementById('adm-seg-trabajo'),
    segHoras: document.getElementById('adm-seg-horas'),
    segEstado: document.getElementById('adm-seg-estado'),
    
    filterEstado: document.getElementById('adm-filter-estado'),
    filterPrioridad: document.getElementById('adm-filter-prioridad'),
    filterUsuario: document.getElementById('adm-filter-usuario'),
    filterAsignacion: document.getElementById('adm-filter-asignacion'),
    sortOrden: document.getElementById('adm-sort-orden'),
    
    // CRUD Técnicos Form
    formTecnico: document.getElementById('form-adm-tecnico'),
    tecId: document.getElementById('adm-tec-id'),
    tecNombres: document.getElementById('adm-tec-nombres'),
    tecApellidos: document.getElementById('adm-tec-apellidos'),
    tecCorreo: document.getElementById('adm-tec-correo'),
    tecTelefono: document.getElementById('adm-tec-telefono'),
    tecRango: document.getElementById('adm-tec-rango'),
    tecPass: document.getElementById('adm-tec-pass'),
    tecEstado: document.getElementById('adm-tec-estado'),
    tecPassGroup: document.getElementById('adm-tec-pass-group'),
    tecStatusGroup: document.getElementById('adm-tec-status-group'),
    btnCancelTecEdit: document.getElementById('btn-adm-tec-cancel'),
    tecFormTitle: document.getElementById('adm-tec-form-title'),
    
    // CRUD Usuarios Form
    formUsuario: document.getElementById('form-adm-usuario'),
    userId: document.getElementById('adm-user-id'),
    userNombres: document.getElementById('adm-user-nombres'),
    userApellidos: document.getElementById('adm-user-apellidos'),
    userCorreo: document.getElementById('adm-user-correo'),
    userTelefono: document.getElementById('adm-user-telefono'),
    userCargo: document.getElementById('adm-user-cargo'),
    userArea: document.getElementById('adm-user-area'),
    userPass: document.getElementById('adm-user-pass'),
    userEstado: document.getElementById('adm-user-estado'),
    userPassGroup: document.getElementById('adm-user-pass-group'),
    userStatusGroup: document.getElementById('adm-user-status-group'),
    btnCancelUserEdit: document.getElementById('btn-adm-user-cancel'),
    userFormTitle: document.getElementById('adm-user-form-title'),
    
    // CRUD Áreas Form
    formArea: document.getElementById('form-adm-area'),
    areaNumero: document.getElementById('area-numero'),
    areaNombre: document.getElementById('area-nombre'),
    areaPabellon: document.getElementById('area-pabellon'),
    areaPiso: document.getElementById('area-piso'),
    
    // CRUD Componente Form
    formComponente: document.getElementById('form-adm-componente'),
    compId: document.getElementById('adm-comp-id'),
    compDestinoTipo: document.getElementById('comp-destino-tipo'),
    compIdEquipo: document.getElementById('comp-id-equipo'),
    compIdAmbiente: document.getElementById('comp-id-ambiente'),
    compEstado: document.getElementById('comp-estado'),
    compTipo: document.getElementById('comp-tipo'),
    compMarca: document.getElementById('comp-marca'),
    compModelo: document.getElementById('comp-modelo'),
    compCapacidad: document.getElementById('comp-capacidad'),
    compDetalle: document.getElementById('comp-detalle'),
    compFormTitle: document.getElementById('adm-comp-form-title'),
    btnCancelCompEdit: document.getElementById('btn-adm-comp-cancel')
};

// Cargar indicadores rápidos de administración
async function loadAdminKPIs() {
    try {
        const res = await fetch('/api/admin/kpis');
        const kpi = await res.json();
        document.getElementById('adm-stat-equipos').textContent = kpi.equipos_activos || 0;
        document.getElementById('adm-stat-incidencias').textContent = kpi.incidencias_activas || 0;
        document.getElementById('adm-stat-personal').textContent = kpi.personal_tecnico || 0;
        document.getElementById('adm-stat-solicitudes').textContent = kpi.solicitudes_pendientes || 0;
    } catch (err) {
        console.error(err);
    }
}

// Cargar últimos 5 incidentes globales y solicitudes pendientes a procesar
async function loadAdminMoniteroInicio() {
    try {
        // Incidentes
        const resInc = await fetch('/api/admin/ultimos-incidentes');
        const incidentes = await resInc.json();
        AdmDOM.tbodyUltimosIncidentes.innerHTML = '';
        if (incidentes.length === 0) {
            AdmDOM.tbodyUltimosIncidentes.innerHTML = `<tr><td colspan="4" class="empty-state">No hay incidencias registradas.</td></tr>`;
        } else {
            incidentes.forEach(inc => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td>${inc.usuario || 'N/A'}</td>
                    <td><span class="priority-badge priority-${inc.prioridad}">${inc.prioridad}</span></td>
                    <td><span class="badge badge-${inc.estado}">${inc.estado}</span></td>
                    <td>${inc.accion || 'Ninguna acción registrada'}</td>
                `;
                AdmDOM.tbodyUltimosIncidentes.appendChild(row);
            });
        }

        // Solicitudes
        const resSol = await fetch('/api/soporte/solicitudes');
        const solicitudes = await resSol.json();
        AdmDOM.tbodyProcesarSolicitudes.innerHTML = '';
        const pendientes = solicitudes.filter(s => s.estado === 'pendiente');
        if (pendientes.length === 0) {
            AdmDOM.tbodyProcesarSolicitudes.innerHTML = `<tr><td colspan="4" class="empty-state">No hay solicitudes pendientes de aprobación.</td></tr>`;
        } else {
            pendientes.forEach(s => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><strong>${s.jefe_nombres}</strong></td>
                    <td>${s.tipo.toUpperCase()}</td>
                    <td>${s.descripcion}</td>
                    <td>
                        <button class="btn btn-success btn-sm btn-adm-aprobar" data-id="${s.id_solicitud}">Aprobar</button>
                        <button class="btn btn-danger btn-sm btn-adm-rechazar" data-id="${s.id_solicitud}">Rechazar</button>
                    </td>
                `;
                AdmDOM.tbodyProcesarSolicitudes.appendChild(row);
            });

            AdmDOM.tbodyProcesarSolicitudes.querySelectorAll('.btn-adm-aprobar').forEach(btn => {
                btn.addEventListener('click', () => procesarSolicitudJefe(btn.getAttribute('data-id'), 'aprobada'));
            });
            AdmDOM.tbodyProcesarSolicitudes.querySelectorAll('.btn-adm-rechazar').forEach(btn => {
                btn.addEventListener('click', () => procesarSolicitudJefe(btn.getAttribute('data-id'), 'rechazada'));
            });
        }
    } catch (err) {
        showToast('Error al cargar monitoreo inicial.', 'danger');
    }
}

async function procesarSolicitudJefe(id, estado) {
    try {
        const res = await fetch('/api/admin/procesar-solicitud', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id_solicitud: parseInt(id),
                nuevo_estado: estado,
                id_tecnico_sesion: currentSession.userId
            })
        });
        const result = await res.json();
        if (res.ok) {
            showToast(result.message);
            loadAdminKPIs();
            loadAdminMoniteroInicio();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al procesar solicitud.', 'danger');
    }
}

// Cargar CRUD Técnicos y métricas de desempeño
async function loadAdminTecnicosPanel() {
    try {
        const resT = await fetch('/api/admin/tecnicos');
        const tecnicos = await resT.json();
        AdmDOM.tbodyTecnicos.innerHTML = '';
        tecnicos.forEach(t => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${t.nombres} ${t.apellidos}</strong></td>
                <td>${t.rango.toUpperCase()}</td>
                <td><span class="badge ${t.estado ? 'badge-operativo' : 'badge-baja'}">${t.estado ? 'Activo' : 'Inactivo'}</span></td>
                <td>
                    <button class="btn btn-secondary btn-sm btn-adm-tec-edit" data-id="${t.id_tecnico}" data-nom="${t.nombres}" data-ape="${t.apellidos}" data-cor="${t.correo}" data-tel="${t.telefono || ''}" data-ran="${t.rango}" data-est="${t.estado ? 1 : 0}">Editar</button>
                    ${t.estado ? `<button class="btn btn-danger btn-sm btn-adm-tec-del" data-id="${t.id_tecnico}">Dar Baja</button>` : ''}
                </td>
            `;
            AdmDOM.tbodyTecnicos.appendChild(row);
        });

        // Eventos Editar / Baja
        AdmDOM.tbodyTecnicos.querySelectorAll('.btn-adm-tec-edit').forEach(btn => {
            btn.addEventListener('click', () => {
                editingTecnicoId = btn.getAttribute('data-id');
                AdmDOM.tecNombres.value = btn.getAttribute('data-nom');
                AdmDOM.tecApellidos.value = btn.getAttribute('data-ape');
                AdmDOM.tecCorreo.value = btn.getAttribute('data-cor');
                AdmDOM.tecTelefono.value = btn.getAttribute('data-tel');
                AdmDOM.tecRango.value = btn.getAttribute('data-ran');
                AdmDOM.tecEstado.value = btn.getAttribute('data-est');
                
                AdmDOM.tecPassGroup.classList.add('hidden');
                AdmDOM.tecPass.required = false;
                AdmDOM.tecStatusGroup.classList.remove('hidden');
                AdmDOM.btnCancelTecEdit.classList.remove('hidden');
                AdmDOM.tecFormTitle.textContent = 'Editar Personal Técnico';
                AdmDOM.formTecnico.scrollIntoView({ behavior: 'smooth' });
            });
        });

        AdmDOM.tbodyTecnicos.querySelectorAll('.btn-adm-tec-del').forEach(btn => {
            btn.addEventListener('click', () => eliminarTecnico(btn.getAttribute('data-id')));
        });

        // Métricas de Técnicos
        const resM = await fetch('/api/admin/metricas-tecnicos');
        const metricas = await resM.json();
        AdmDOM.tbodyMetricasTecnicos.innerHTML = '';
        metricas.forEach(m => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${m.nombre_tecnico}</strong></td>
                <td>${m.rango.toUpperCase()}</td>
                <td>${m.incidencias_asignadas}</td>
                <td>${m.incidencias_resueltas}</td>
                <td>${m.incidencias_pendientes}</td>
                <td>${m.total_horas_invertidas} hrs</td>
                <td>${parseFloat(m.promedio_hora_incidencia).toFixed(2)} hrs/ticket</td>
            `;
            AdmDOM.tbodyMetricasTecnicos.appendChild(row);
        });
    } catch (err) {
        showToast('Error al cargar técnicos.', 'danger');
    }
}

async function eliminarTecnico(id) {
    if (!confirm('¿Estás seguro de dar de baja a este técnico? Esto colocará su estado como inactivo.')) return;
    try {
        const res = await fetch(`/api/admin/tecnicos/${id}`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_tecnico_sesion: currentSession.userId })
        });
        if (res.ok) {
            showToast('Técnico dado de baja con éxito (baja lógica).');
            loadAdminTecnicosPanel();
            loadAdminKPIs();
        } else {
            const r = await res.json();
            showToast(`Error: ${r.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al dar de baja técnico.', 'danger');
    }
}

// Cargar CRUD Usuarios
async function loadAdminUsuariosPanel() {
    try {
        // Cargar ambientes en el select
        const resA = await fetch('/api/admin/areas');
        const areas = await resA.json();
        AdmDOM.userArea.innerHTML = '<option value="" disabled selected>Selecciona el área...</option>';
        areas.forEach(a => {
            const opt = document.createElement('option');
            opt.value = a.id_ambiente;
            opt.textContent = `${a.pabellon} - ${a.numero} (${a.nombre})`;
            AdmDOM.userArea.appendChild(opt);
        });

        const resU = await fetch('/api/admin/usuarios');
        const usuarios = await resU.json();
        AdmDOM.tbodyUsuarios.innerHTML = '';
        usuarios.forEach(u => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${u.nombres} ${u.apellidos}</strong></td>
                <td>${u.ambiente_nombre || 'Sin asignación'}</td>
                <td>${u.cargo.toUpperCase()}</td>
                <td><span class="badge ${u.estado ? 'badge-operativo' : 'badge-baja'}">${u.estado ? 'Activo' : 'Inactivo'}</span></td>
                <td>
                    <button class="btn btn-secondary btn-sm btn-adm-user-edit" data-id="${u.id_usuario}" data-nom="${u.nombres}" data-ape="${u.apellidos}" data-cor="${u.correo}" data-tel="${u.telefono || ''}" data-car="${u.cargo}" data-are="${u.id_area}" data-est="${u.estado ? 1 : 0}">Editar</button>
                    ${u.estado ? `<button class="btn btn-danger btn-sm btn-adm-user-del" data-id="${u.id_usuario}">Dar Baja</button>` : ''}
                </td>
            `;
            AdmDOM.tbodyUsuarios.appendChild(row);
        });

        // Eventos Editar / Baja
        AdmDOM.tbodyUsuarios.querySelectorAll('.btn-adm-user-edit').forEach(btn => {
            btn.addEventListener('click', () => {
                editingUsuarioId = btn.getAttribute('data-id');
                AdmDOM.userNombres.value = btn.getAttribute('data-nom');
                AdmDOM.userApellidos.value = btn.getAttribute('data-ape');
                AdmDOM.userCorreo.value = btn.getAttribute('data-cor');
                AdmDOM.userTelefono.value = btn.getAttribute('data-tel');
                AdmDOM.userCargo.value = btn.getAttribute('data-car');
                AdmDOM.userArea.value = btn.getAttribute('data-are');
                AdmDOM.userEstado.value = btn.getAttribute('data-est');
                
                AdmDOM.userPassGroup.classList.add('hidden');
                AdmDOM.userPass.required = false;
                AdmDOM.userStatusGroup.classList.remove('hidden');
                AdmDOM.btnCancelUserEdit.classList.remove('hidden');
                AdmDOM.userFormTitle.textContent = 'Editar Datos de Usuario';
                AdmDOM.formUsuario.scrollIntoView({ behavior: 'smooth' });
            });
        });

        AdmDOM.tbodyUsuarios.querySelectorAll('.btn-adm-user-del').forEach(btn => {
            btn.addEventListener('click', () => eliminarUsuario(btn.getAttribute('data-id')));
        });
    } catch (err) {
        showToast('Error al cargar panel de usuarios.', 'danger');
    }
}

async function eliminarUsuario(id) {
    if (!confirm('¿Estás seguro de dar de baja a este usuario?')) return;
    try {
        const res = await fetch(`/api/admin/usuarios/${id}`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_tecnico_sesion: currentSession.userId })
        });
        if (res.ok) {
            showToast('Usuario inhabilitado con éxito.');
            loadAdminUsuariosPanel();
        } else {
            const r = await res.json();
            showToast(`Error: ${r.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al inhabilitar usuario.', 'danger');
    }
}

// Cargar CRUD Áreas
async function loadAdminAreasPanel() {
    try {
        const res = await fetch('/api/admin/areas');
        const areas = await res.json();
        AdmDOM.tbodyAreas.innerHTML = '';
        areas.forEach(a => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${a.numero}</strong></td>
                <td>${a.nombre}</td>
                <td>${a.pabellon}</td>
                <td>Piso ${a.piso}</td>
                <td><button class="btn btn-danger btn-sm btn-adm-area-del" data-id="${a.id_ambiente}">Eliminar</button></td>
            `;
            AdmDOM.tbodyAreas.appendChild(row);
        });

        AdmDOM.tbodyAreas.querySelectorAll('.btn-adm-area-del').forEach(btn => {
            btn.addEventListener('click', () => eliminarArea(btn.getAttribute('data-id')));
        });
    } catch (err) {
        showToast('Error al cargar áreas.', 'danger');
    }
}

async function eliminarArea(id) {
    if (!confirm('¿Seguro que deseas eliminar permanentemente esta área?')) return;
    try {
        const res = await fetch(`/api/admin/areas/${id}`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_tecnico_sesion: currentSession.userId })
        });
        const result = await res.json();
        if (res.ok) {
            showToast('Área eliminada con éxito de la BD.');
            loadAdminAreasPanel();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error de red al eliminar el área.', 'danger');
    }
}

// Cargar CRUD Componentes
async function loadAdminComponentesPanel() {
    try {
        // Cargar equipos en el SELECT
        const resE = await fetch('/api/equipos');
        const equipos = await resE.json();
        AdmDOM.compIdEquipo.innerHTML = '<option value="">-- No instalar en equipo --</option>';
        equipos.forEach(eq => {
            const opt = document.createElement('option');
            opt.value = eq.id_equipo;
            opt.textContent = `${eq.codigo_inventario} - ${eq.tipo.toUpperCase()} (${eq.marca})`;
            AdmDOM.compIdEquipo.appendChild(opt);
        });

        // Cargar ambientes en el SELECT
        const resA = await fetch('/api/admin/areas');
        const areas = await resA.json();
        AdmDOM.compIdAmbiente.innerHTML = '<option value="">-- No almacenar en área --</option>';
        areas.forEach(a => {
            const opt = document.createElement('option');
            opt.value = a.id_ambiente;
            opt.textContent = `${a.pabellon} - ${a.numero} (${a.nombre})`;
            AdmDOM.compIdAmbiente.appendChild(opt);
        });

        // Cargar lista general
        const resC = await fetch('/api/componentes/todos');
        const componentes = await resC.json();
        AdmDOM.tbodyComponentes.innerHTML = '';
        componentes.forEach(c => {
            const row = document.createElement('tr');
            let assignBtnHtml = '';
            if (c.estado_fisico === 'almacenado') {
                assignBtnHtml = `<button class="btn btn-primary btn-sm btn-adm-comp-assign" data-id="${c.componente_id}" data-desc="${c.tipo} - ${c.especificaciones_tecnicas}">Asignar a PC</button>`;
            }
            row.innerHTML = `
                <td>#${c.componente_id}</td>
                <td><strong>${c.tipo}</strong></td>
                <td>${c.especificaciones_tecnicas}</td>
                <td><span class="badge badge-${c.estado_fisico}">${c.estado_fisico}</span></td>
                <td>
                    <div style="display: flex; gap: 5px;">
                        <button class="btn btn-secondary btn-sm btn-adm-comp-edit" data-id="${c.componente_id}" data-eq="${c.id_equipo || ''}" data-amb="${c.id_ambiente || ''}" data-est="${c.estado_fisico}" data-tip="${c.tipo}" data-marca="${c.especificaciones_tecnicas.split(' ')[0]}" data-model="${c.especificaciones_tecnicas.split(' ').slice(1).join(' ')}">Editar</button>
                        ${assignBtnHtml}
                    </div>
                </td>
            `;
            AdmDOM.tbodyComponentes.appendChild(row);
        });

        AdmDOM.tbodyComponentes.querySelectorAll('.btn-adm-comp-edit').forEach(btn => {
            btn.addEventListener('click', () => {
                editingComponenteId = btn.getAttribute('data-id');
                const eqId = btn.getAttribute('data-eq');
                const ambId = btn.getAttribute('data-amb');
                
                if (eqId) {
                    AdmDOM.compDestinoTipo.value = 'equipo';
                    document.querySelector('.id-equipo-group').classList.remove('hidden');
                    document.querySelector('.id-ambiente-group').classList.add('hidden');
                    AdmDOM.compIdEquipo.value = eqId;
                } else {
                    AdmDOM.compDestinoTipo.value = 'ambiente';
                    document.querySelector('.id-ambiente-group').classList.remove('hidden');
                    document.querySelector('.id-equipo-group').classList.add('hidden');
                    AdmDOM.compIdAmbiente.value = ambId;
                }

                AdmDOM.compEstado.value = btn.getAttribute('data-est');
                
                // Tratar de predecir campos
                const compTipoTxt = btn.getAttribute('data-tip').toLowerCase().replace(' ', '_');
                AdmDOM.compTipo.value = compTipoTxt;
                AdmDOM.compMarca.value = btn.getAttribute('data-marca');
                AdmDOM.compModelo.value = btn.getAttribute('data-model');
                
                AdmDOM.btnCancelCompEdit.classList.remove('hidden');
                AdmDOM.compFormTitle.textContent = 'Editar Componente Físico';
                AdmDOM.formComponente.scrollIntoView({ behavior: 'smooth' });
            });
        });

        AdmDOM.tbodyComponentes.querySelectorAll('.btn-adm-comp-assign').forEach(btn => {
            btn.addEventListener('click', () => {
                abrirModalAsignacion(btn.getAttribute('data-id'), btn.getAttribute('data-desc'));
            });
        });

    } catch (err) {
        showToast('Error al cargar componentes.', 'danger');
    }
}

AdmDOM.compDestinoTipo.addEventListener('change', () => {
    if (AdmDOM.compDestinoTipo.value === 'equipo') {
        document.querySelector('.id-equipo-group').classList.remove('hidden');
        document.querySelector('.id-ambiente-group').classList.add('hidden');
        AdmDOM.compIdAmbiente.value = '';
    } else {
        document.querySelector('.id-ambiente-group').classList.remove('hidden');
        document.querySelector('.id-equipo-group').classList.add('hidden');
        AdmDOM.compIdEquipo.value = '';
    }
});

// Cargar logs de auditoría
async function loadAdminAuditorias() {
    try {
        const res = await fetch('/api/admin/auditoria');
        const logs = await res.json();
        AdmDOM.tbodyAuditoria.innerHTML = '';
        if (logs.length === 0) {
            AdmDOM.tbodyAuditoria.innerHTML = `<tr><td colspan="7" class="empty-state">No hay registros de auditoría en la Base de Datos.</td></tr>`;
            return;
        }
        logs.forEach(log => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${log.log_id}</td>
                <td><strong>${log.tecnico_responsable || 'Sistema'}</strong></td>
                <td><code style="background-color: rgba(255,255,255,0.05); padding: 2px 4px; border-radius: 4px;">${log.tabla_afectada}</code></td>
                <td><span class="badge badge-${log.operacion === 'INSERT' ? 'resuelta' : log.operacion === 'UPDATE' ? 'en_proceso' : 'baja'}">${log.operacion}</span></td>
                <td><pre style="max-width: 250px; overflow-x: auto; font-size: 0.75rem; color: #60a5fa;">${JSON.stringify(log.valor_nuevo, null, 2)}</pre></td>
                <td><pre style="max-width: 250px; overflow-x: auto; font-size: 0.75rem; color: #ef4444;">${log.valor_antiguo ? JSON.stringify(log.valor_antiguo, null, 2) : 'NULL'}</pre></td>
                <td>${formatDate(log.fecha)}</td>
            `;
            AdmDOM.tbodyAuditoria.appendChild(row);
        });
    } catch (err) {
        showToast('Error al cargar logs de auditoría.', 'danger');
    }
}

// Reset y desactivar pestañas de administrador
function deactivateAdminTabs() {
    AdmDOM.btnNavInicio.classList.remove('active');
    AdmDOM.btnNavIncidencias.classList.remove('active');
    AdmDOM.btnNavTecnicos.classList.remove('active');
    AdmDOM.btnNavUsuarios.classList.remove('active');
    AdmDOM.btnNavAreas.classList.remove('active');
    AdmDOM.btnNavComponentes.classList.remove('active');
    AdmDOM.btnNavAuditoria.classList.remove('active');
    
    AdmDOM.panelInicio.classList.add('hidden');
    AdmDOM.panelIncidencias.classList.add('hidden');
    AdmDOM.panelTecnicos.classList.add('hidden');
    AdmDOM.panelUsuarios.classList.add('hidden');
    AdmDOM.panelAreas.classList.add('hidden');
    AdmDOM.panelComponentes.classList.add('hidden');
    AdmDOM.panelAuditoria.classList.add('hidden');
    
    AdmDOM.cardAtencionDetalle.classList.add('hidden');
}

// Eventos Navegación Administrador
AdmDOM.btnNavInicio.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavInicio.classList.add('active');
    AdmDOM.panelInicio.classList.remove('hidden');
    loadAdminKPIs();
    loadAdminMoniteroInicio();
});

AdmDOM.btnNavIncidencias.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavIncidencias.classList.add('active');
    AdmDOM.panelIncidencias.classList.remove('hidden');
    fetchAndRenderIncidencias('admin');
});

AdmDOM.btnNavTecnicos.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavTecnicos.classList.add('active');
    AdmDOM.panelTecnicos.classList.remove('hidden');
    loadAdminTecnicosPanel();
});

AdmDOM.btnNavUsuarios.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavUsuarios.classList.add('active');
    AdmDOM.panelUsuarios.classList.remove('hidden');
    loadAdminUsuariosPanel();
});

AdmDOM.btnNavAreas.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavAreas.classList.add('active');
    AdmDOM.panelAreas.classList.remove('hidden');
    loadAdminAreasPanel();
});

AdmDOM.btnNavComponentes.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavComponentes.classList.add('active');
    AdmDOM.panelComponentes.classList.remove('hidden');
    loadAdminComponentesPanel();
});

AdmDOM.btnNavAuditoria.addEventListener('click', () => {
    deactivateAdminTabs();
    AdmDOM.btnNavAuditoria.classList.add('active');
    AdmDOM.panelAuditoria.classList.remove('hidden');
    loadAdminAuditorias();
});

// Guardar Técnico (Insert o Update)
AdmDOM.formTecnico.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        nombres: AdmDOM.tecNombres.value.trim(),
        apellidos: AdmDOM.tecApellidos.value.trim(),
        correo: AdmDOM.tecCorreo.value.trim(),
        telefono: AdmDOM.tecTelefono.value.trim() || null,
        rango: AdmDOM.tecRango.value,
        id_tecnico_sesion: currentSession.userId
    };

    if (editingTecnicoId) {
        data.estado = parseInt(AdmDOM.tecEstado.value);
        try {
            const res = await fetch(`/api/admin/tecnicos/${editingTecnicoId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('Personal técnico editado correctamente.');
                resetTecnicoForm();
                loadAdminTecnicosPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error de red al actualizar técnico.', 'danger');
        }
    } else {
        data.contrasena = AdmDOM.tecPass.value;
        try {
            const res = await fetch('/api/admin/tecnicos', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('¡Personal técnico registrado con éxito!');
                resetTecnicoForm();
                loadAdminTecnicosPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error al registrar técnico.', 'danger');
        }
    }
});

function resetTecnicoForm() {
    editingTecnicoId = null;
    AdmDOM.formTecnico.reset();
    AdmDOM.tecPassGroup.classList.remove('hidden');
    AdmDOM.tecPass.required = true;
    AdmDOM.tecStatusGroup.classList.add('hidden');
    AdmDOM.btnCancelTecEdit.classList.add('hidden');
    AdmDOM.tecFormTitle.textContent = 'Registrar Nuevo Personal Técnico / Practicante';
}

AdmDOM.btnCancelTecEdit.addEventListener('click', resetTecnicoForm);

// Guardar Usuario (Insert o Update)
AdmDOM.formUsuario.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        id_area: parseInt(AdmDOM.userArea.value),
        cargo: AdmDOM.userCargo.value,
        nombres: AdmDOM.userNombres.value.trim(),
        apellidos: AdmDOM.userApellidos.value.trim(),
        correo: AdmDOM.userCorreo.value.trim(),
        telefono: AdmDOM.userTelefono.value.trim() || null,
        id_tecnico_sesion: currentSession.userId
    };

    if (editingUsuarioId) {
        data.estado = parseInt(AdmDOM.userEstado.value);
        try {
            const res = await fetch(`/api/admin/usuarios/${editingUsuarioId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('Usuario editado con éxito.');
                resetUsuarioForm();
                loadAdminUsuariosPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error de red al actualizar usuario.', 'danger');
        }
    } else {
        data.contrasena = AdmDOM.userPass.value;
        try {
            const res = await fetch('/api/admin/usuarios', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('¡Usuario registrado con éxito!');
                resetUsuarioForm();
                loadAdminUsuariosPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error de red al crear usuario.', 'danger');
        }
    }
});

function resetUsuarioForm() {
    editingUsuarioId = null;
    AdmDOM.formUsuario.reset();
    AdmDOM.userPassGroup.classList.remove('hidden');
    AdmDOM.userPass.required = true;
    AdmDOM.userStatusGroup.classList.add('hidden');
    AdmDOM.btnCancelUserEdit.classList.add('hidden');
    AdmDOM.userFormTitle.textContent = 'Registrar Nuevo Usuario Común';
}
AdmDOM.btnCancelUserEdit.addEventListener('click', resetUsuarioForm);

// Guardar Área (Environment)
AdmDOM.formArea.addEventListener('submit', async (e) => {
    e.preventDefault();
    const data = {
        numero: parseInt(AdmDOM.areaNumero.value),
        nombre: AdmDOM.areaNombre.value.trim(),
        pabellon: AdmDOM.areaPabellon.value,
        piso: parseInt(AdmDOM.areaPiso.value),
        id_tecnico_sesion: currentSession.userId
    };
    try {
        const res = await fetch('/api/admin/areas', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        const result = await res.json();
        if (res.ok) {
            showToast('¡Área registrada correctamente!');
            AdmDOM.formArea.reset();
            loadAdminAreasPanel();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error de red al registrar área.', 'danger');
    }
});

// Guardar Componente (Insert o Update)
AdmDOM.formComponente.addEventListener('submit', async (e) => {
    e.preventDefault();
    const isEquipo = AdmDOM.compDestinoTipo.value === 'equipo';
    const data = {
        id_equipo: isEquipo && AdmDOM.compIdEquipo.value ? parseInt(AdmDOM.compIdEquipo.value) : null,
        id_ambiente: !isEquipo && AdmDOM.compIdAmbiente.value ? parseInt(AdmDOM.compIdAmbiente.value) : null,
        estado_componente: AdmDOM.compEstado.value,
        tipo_componente: AdmDOM.compTipo.value,
        marca: AdmDOM.compMarca.value.trim(),
        modelo: AdmDOM.compModelo.value.trim(),
        capacidad_o_vram: AdmDOM.compCapacidad.value ? parseInt(AdmDOM.compCapacidad.value) : null,
        tipo_detalle: AdmDOM.compDetalle.value.trim() || null,
        id_tecnico_sesion: currentSession.userId
    };

    if (!data.id_equipo && !data.id_ambiente) {
        showToast('Debes seleccionar un destino (Equipo o Ambiente).', 'warning');
        return;
    }

    try {
        if (editingComponenteId) {
            const res = await fetch(`/api/admin/componentes/${editingComponenteId}`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('Componente modificado con éxito.');
                resetComponenteForm();
                loadAdminComponentesPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        } else {
            const res = await fetch('/api/admin/componentes', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (res.ok) {
                showToast('Componente de hardware ingresado con éxito.');
                resetComponenteForm();
                loadAdminComponentesPanel();
            } else {
                const r = await res.json();
                showToast(`Error: ${r.error}`, 'danger');
            }
        }
    } catch (err) {
        showToast('Error de red al procesar componente.', 'danger');
    }
});

function resetComponenteForm() {
    editingComponenteId = null;
    AdmDOM.formComponente.reset();
    AdmDOM.btnCancelCompEdit.classList.add('hidden');
    AdmDOM.compFormTitle.textContent = 'Ingresar Componente Físico al Inventario';
    AdmDOM.compDestinoTipo.dispatchEvent(new Event('change'));
}
AdmDOM.btnCancelCompEdit.addEventListener('click', resetComponenteForm);

// =============================================================================
// LOGIN SIMULATION HANDLERS
// =============================================================================
document.querySelectorAll('.role-card').forEach(card => {
    card.addEventListener('click', async () => {
        const role = card.getAttribute('data-role');
        currentSession.role = role;
        
        DOM.viewRoleSelection.classList.add('hidden');
        DOM.viewLoginSimulation.classList.remove('hidden');
        
        try {
            const isUserRole = ['empleado', 'jefe'].includes(currentSession.role);
            const res = await fetch(isUserRole ? '/api/roles/usuarios' : '/api/roles/tecnicos');
            const users = await res.json();
            
            let filteredUsers = [];
            if (isUserRole) {
                filteredUsers = users.filter(u => u.cargo === currentSession.role);
            } else {
                filteredUsers = users.filter(u => u.rango === currentSession.role);
            }
            
            DOM.selectUserSimulation.innerHTML = '';
            if (filteredUsers.length === 0) {
                DOM.selectUserSimulation.innerHTML = '<option value="" disabled>No hay cuentas activas en la BD para este rol</option>';
            } else {
                filteredUsers.forEach(u => {
                    const opt = document.createElement('option');
                    opt.value = isUserRole ? u.id_usuario : u.id_tecnico;
                    opt.textContent = `${u.nombres} ${u.apellidos} (ID: ${isUserRole ? u.id_usuario : u.id_tecnico})`;
                    DOM.selectUserSimulation.appendChild(opt);
                });
            }
        } catch (err) {
            showToast('Error de conexión al cargar usuarios simulados.', 'danger');
        }
    });
});

DOM.btnConfirmLogin.addEventListener('click', () => {
    const selectedOpt = DOM.selectUserSimulation.options[DOM.selectUserSimulation.selectedIndex];
    if (!selectedOpt || selectedOpt.value === "") {
        showToast('Por favor selecciona un usuario simulado.', 'warning');
        return;
    }
    
    currentSession.userId = DOM.selectUserSimulation.value;
    currentSession.userName = selectedOpt.textContent.split(' (ID:')[0];
    
    DOM.sessionBadge.textContent = currentSession.role.replace('_', ' ');
    DOM.sessionName.textContent = currentSession.userName;
    DOM.userSessionInfo.classList.remove('hidden');
    DOM.viewLoginSimulation.classList.add('hidden');

    // Desviar a dashboard según rol
    if (currentSession.role === 'empleado' || currentSession.role === 'jefe') {
        DOM.viewEmpleadoDashboard.classList.remove('hidden');
        // Mostrar u ocultar opciones exclusivas del jefe
        if (currentSession.role === 'jefe') {
            EmpDOM.btnNavCrearSolicitud.classList.remove('hidden');
            EmpDOM.btnNavRevisarSolicitudes.classList.remove('hidden');
        } else {
            EmpDOM.btnNavCrearSolicitud.classList.add('hidden');
            EmpDOM.btnNavRevisarSolicitudes.classList.add('hidden');
        }
        EmpDOM.btnNavRegistrar.click(); // Pestaña por defecto
    } else if (currentSession.role === 'practicante') {
        DOM.viewPracticanteDashboard.classList.remove('hidden');
        PracDOM.btnNavIncidencias.click();
    } else if (currentSession.role === 'tecnico') {
        DOM.viewTecnicoDashboard.classList.remove('hidden');
        TecDOM.btnNavIncidencias.click();
    } else if (currentSession.role === 'administrador_sistema') {
        DOM.viewAdminDashboard.classList.remove('hidden');
        AdmDOM.btnNavInicio.click();
    }
    
    showToast(`Ingresaste exitosamente como: ${currentSession.userName}`);
});

DOM.btnBackRoles.addEventListener('click', () => {
    DOM.viewLoginSimulation.classList.add('hidden');
    DOM.viewRoleSelection.classList.remove('hidden');
});

DOM.btnLogout.addEventListener('click', () => {
    currentSession = { userId: null, userName: '', role: '' };
    DOM.userSessionInfo.classList.add('hidden');
    
    // Ocultar todos los dashboards
    DOM.viewEmpleadoDashboard.classList.add('hidden');
    DOM.viewPracticanteDashboard.classList.add('hidden');
    DOM.viewTecnicoDashboard.classList.add('hidden');
    DOM.viewAdminDashboard.classList.add('hidden');

    // Ocultar botones de jefe en la barra de navegación del empleado
    EmpDOM.btnNavCrearSolicitud.classList.add('hidden');
    EmpDOM.btnNavRevisarSolicitudes.classList.add('hidden');
    
    // Resetear formularios
    EmpDOM.formRegistrarIncidencia.reset();
    EmpDOM.formCrearSolicitud.reset();
    PracDOM.formSeguimiento.reset();
    TecDOM.formAsignar.reset();
    TecDOM.formSeguimiento.reset();
    TecDOM.formRegistrarIncidenciaDirecta.reset();
    TecDOM.formRegistrarEquipo.reset();
    TecDOM.formSoftwareCatalogo.reset();
    TecDOM.formSoftwareInstalar.reset();
    TecDOM.formSoftwareEditar.reset();
    AdmDOM.formTecnico.reset();
    AdmDOM.formUsuario.reset();
    AdmDOM.formArea.reset();
    AdmDOM.formComponente.reset();
    
    // Resetear nuevos formularios
    if (AdmDOM.formAsignar) AdmDOM.formAsignar.reset();
    if (AdmDOM.formSeguimiento) AdmDOM.formSeguimiento.reset();

    // Retornar al inicio
    DOM.viewRoleSelection.classList.remove('hidden');
    showToast('Sesión simulada finalizada.');
});

// =============================================================================
// 5. NUEVA LOGICA DE FILTROS, ORDENAMIENTO Y ASIGNACION DE COMPONENTES
// =============================================================================
let currentIncidencias = [];

async function fetchAndRenderIncidencias(role) {
    try {
        const res = await fetch(`/api/soporte/incidencias/${currentSession.userId}`);
        currentIncidencias = await res.json();
        renderIncidenciasTable(role);
    } catch (err) {
        showToast('Error al cargar incidencias.', 'danger');
    }
}

function renderIncidenciasTable(role) {
    const tbody = role === 'admin' ? AdmDOM.tbodyIncidencias : TecDOM.tbodyIncidencias;
    const filterEstado = role === 'admin' ? AdmDOM.filterEstado.value : TecDOM.filterEstado.value;
    const filterPrioridad = role === 'admin' ? AdmDOM.filterPrioridad.value : TecDOM.filterPrioridad.value;
    const filterUsuario = role === 'admin' ? AdmDOM.filterUsuario.value : TecDOM.filterUsuario.value;
    const filterAsignacion = role === 'admin' ? AdmDOM.filterAsignacion.value : TecDOM.filterAsignacion.value;
    const sortOrden = role === 'admin' ? AdmDOM.sortOrden.value : TecDOM.sortOrden.value;

    if (!tbody) return;
    tbody.innerHTML = '';

    // 1. Filtrar
    let filtered = currentIncidencias.filter(inc => {
        const matchEstado = filterEstado === 'todos' || inc.estado === filterEstado;
        const matchPrioridad = filterPrioridad === 'todas' || inc.prioridad === filterPrioridad;
        
        const reportaNombre = inc.usuario_reporta_nombre || '';
        const matchUsuario = !filterUsuario || reportaNombre.toLowerCase().includes(filterUsuario.toLowerCase().trim());
        
        const matchAsignacion = filterAsignacion === 'todas' || (inc.tecnico_asignado && inc.tecnico_asignado.trim().toLowerCase() === currentSession.userName.trim().toLowerCase());
        
        return matchEstado && matchPrioridad && matchUsuario && matchAsignacion;
    });

    // 2. Ordenar
    filtered.sort((a, b) => {
        if (sortOrden === 'recientes') {
            return new Date(b.fecha) - new Date(a.fecha);
        } else if (sortOrden === 'antiguas') {
            return new Date(a.fecha) - new Date(b.fecha);
        } else if (sortOrden === 'prioridad') {
            const priorityWeight = { alta: 3, media: 2, baja: 1 };
            const weightA = priorityWeight[a.prioridad] || 0;
            const weightB = priorityWeight[b.prioridad] || 0;
            if (weightA !== weightB) {
                return weightB - weightA;
            }
            return new Date(b.fecha) - new Date(a.fecha);
        }
        return 0;
    });

    if (filtered.length === 0) {
        tbody.innerHTML = `<tr><td colspan="9" class="empty-state">No se encontraron incidencias con los filtros aplicados.</td></tr>`;
        return;
    }

    filtered.forEach(inc => {
        const row = document.createElement('tr');
        const btnClass = role === 'admin' ? 'btn-adm-atender' : 'btn-tec-atender';
        row.innerHTML = `
            <td>#${inc.id_incidencia}</td>
            <td>${formatDate(inc.fecha)}</td>
            <td>${inc.equipo_codigo || 'N/A'}</td>
            <td><span class="priority-badge priority-${inc.prioridad}">${inc.prioridad}</span></td>
            <td>${inc.usuario_reporta_nombre || 'N/A'}</td>
            <td>${inc.tecnico_asignado || '<em style="color: var(--color-warning);">No Asignado</em>'}</td>
            <td>${inc.descripcion || ''}</td>
            <td><span class="badge badge-${inc.estado}">${inc.estado}</span></td>
            <td><button class="btn btn-primary btn-sm ${btnClass}" data-id="${inc.id_incidencia}">Atender / Asignar</button></td>
        `;
        tbody.appendChild(row);
    });

    tbody.querySelectorAll(`.${role === 'admin' ? 'btn-adm-atender' : 'btn-tec-atender'}`).forEach(btn => {
        btn.addEventListener('click', () => {
            if (role === 'admin') {
                showAtencionIncidenciaAdmin(btn.getAttribute('data-id'));
            } else {
                showAtencionIncidenciaTecnico(btn.getAttribute('data-id'));
            }
        });
    });
}

// Detalle atencion Admin
async function showAtencionIncidenciaAdmin(id) {
    AdmDOM.detailId.textContent = id;
    try {
        const res = await fetch('/api/roles/tecnicos');
        const tecnicos = await res.json();
        AdmDOM.asignarPersonal.innerHTML = '<option value="">-- Seleccionar --</option>';
        tecnicos.forEach(t => {
            const opt = document.createElement('option');
            opt.value = t.id_tecnico;
            opt.textContent = `${t.nombres} ${t.apellidos} (${t.rango.toUpperCase()})`;
            AdmDOM.asignarPersonal.appendChild(opt);
        });
    } catch (err) {
        showToast('Error al cargar personal de soporte.', 'danger');
    }
    AdmDOM.cardAtencionDetalle.classList.remove('hidden');
    setTimeout(() => {
        AdmDOM.cardAtencionDetalle.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 50);
}

// Boton cerrar detalle Admin
if (AdmDOM.btnCloseDetail) {
    AdmDOM.btnCloseDetail.addEventListener('click', () => {
        AdmDOM.cardAtencionDetalle.classList.add('hidden');
    });
}

// Formulario de asignación Admin
if (AdmDOM.formAsignar) {
    AdmDOM.formAsignar.addEventListener('submit', async (e) => {
        e.preventDefault();
        const idIncidencia = AdmDOM.detailId.textContent;
        const idTecnicoAsignado = AdmDOM.asignarPersonal.value;
        try {
            const res = await fetch('/api/soporte/incidencia/asignar', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id_incidencia: idIncidencia,
                    id_tecnico_asignador: currentSession.userId,
                    id_tecnico_asignado: idTecnicoAsignado
                })
            });
            const result = await res.json();
            if (res.ok) {
                showToast(result.message, 'success');
                AdmDOM.cardAtencionDetalle.classList.add('hidden');
                fetchAndRenderIncidencias('admin');
            } else {
                showToast(`Error: ${result.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error al asignar personal.', 'danger');
        }
    });
}

// Formulario de seguimiento Admin
if (AdmDOM.formSeguimiento) {
    AdmDOM.formSeguimiento.addEventListener('submit', async (e) => {
        e.preventDefault();
        const idIncidencia = AdmDOM.detailId.textContent;
        try {
            const res = await fetch('/api/soporte/incidencia/seguimiento/tec', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id_incidencia: idIncidencia,
                    id_tecnico: currentSession.userId,
                    diagnostico: AdmDOM.segDiagnostico.value,
                    trabajo_realizado: AdmDOM.segTrabajo.value,
                    horas_invertidas: parseFloat(AdmDOM.segHoras.value),
                    nuevo_estado: AdmDOM.segEstado.value
                })
            });
            const result = await res.json();
            if (res.ok) {
                showToast('Seguimiento registrado con éxito.', 'success');
                AdmDOM.formSeguimiento.reset();
                AdmDOM.cardAtencionDetalle.classList.add('hidden');
                fetchAndRenderIncidencias('admin');
            } else {
                showToast(`Error: ${result.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error al registrar seguimiento.', 'danger');
        }
    });
}

// Listeners de cambio de filtro para recargar en tiempo real
if (TecDOM.filterEstado) {
    TecDOM.filterEstado.addEventListener('change', () => renderIncidenciasTable('tecnico'));
    TecDOM.filterPrioridad.addEventListener('change', () => renderIncidenciasTable('tecnico'));
    TecDOM.filterUsuario.addEventListener('input', () => renderIncidenciasTable('tecnico'));
    TecDOM.filterAsignacion.addEventListener('change', () => renderIncidenciasTable('tecnico'));
    TecDOM.sortOrden.addEventListener('change', () => renderIncidenciasTable('tecnico'));
}
if (AdmDOM.filterEstado) {
    AdmDOM.filterEstado.addEventListener('change', () => renderIncidenciasTable('admin'));
    AdmDOM.filterPrioridad.addEventListener('change', () => renderIncidenciasTable('admin'));
    AdmDOM.filterUsuario.addEventListener('input', () => renderIncidenciasTable('admin'));
    AdmDOM.filterAsignacion.addEventListener('change', () => renderIncidenciasTable('admin'));
    AdmDOM.sortOrden.addEventListener('change', () => renderIncidenciasTable('admin'));
}

// MODAL DE ASIGNACIÓN DE COMPONENTES
const CompAsignarDOM = {
    modal: document.getElementById('modal-asignar-componente'),
    btnClose: document.getElementById('btn-close-asignar-modal'),
    form: document.getElementById('form-asignar-componente'),
    compId: document.getElementById('asignar-comp-id'),
    compInfo: document.getElementById('asignar-comp-info'),
    pcSelect: document.getElementById('asignar-pc-select')
};

async function abrirModalAsignacion(compId, compDesc) {
    CompAsignarDOM.compId.value = compId;
    CompAsignarDOM.compInfo.textContent = `[ID #${compId}] ${compDesc}`;
    
    try {
        const res = await fetch('/api/equipos');
        const equipos = await res.json();
        
        // Filtrar por pc_escritorio
        const pcs = equipos.filter(eq => eq.tipo === 'pc_escritorio');
        
        CompAsignarDOM.pcSelect.innerHTML = '';
        if (pcs.length === 0) {
            CompAsignarDOM.pcSelect.innerHTML = '<option value="">-- No hay PCs de Escritorio disponibles --</option>';
        } else {
            pcs.forEach(pc => {
                const opt = document.createElement('option');
                opt.value = pc.id_equipo;
                opt.textContent = `${pc.codigo_inventario} - ${pc.marca} (${pc.estado})`;
                CompAsignarDOM.pcSelect.appendChild(opt);
            });
        }
    } catch (err) {
        showToast('Error al cargar equipos de tipo PC Escritorio.', 'danger');
    }
    
    CompAsignarDOM.modal.classList.remove('hidden');
}

if (CompAsignarDOM.btnClose) {
    CompAsignarDOM.btnClose.addEventListener('click', () => {
        CompAsignarDOM.modal.classList.add('hidden');
    });
}

if (CompAsignarDOM.modal) {
    CompAsignarDOM.modal.addEventListener('click', (e) => {
        if (e.target === CompAsignarDOM.modal) {
            CompAsignarDOM.modal.classList.add('hidden');
        }
    });
}

if (CompAsignarDOM.form) {
    CompAsignarDOM.form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const compId = CompAsignarDOM.compId.value;
        const pcId = CompAsignarDOM.pcSelect.value;
        
        if (!pcId) {
            showToast('Por favor seleccione una PC de Escritorio.', 'warning');
            return;
        }
        
        try {
            const res = await fetch('/api/soporte/componentes/asignar-pc', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id_tecnico_sesion: currentSession.userId,
                    id_componente: compId,
                    id_equipo: pcId
                })
            });
            const result = await res.json();
            if (res.ok) {
                showToast(result.message, 'success');
                CompAsignarDOM.modal.classList.add('hidden');
                
                // Recargar el inventario correspondiente al panel activo
                if (currentSession.role === 'administrador_sistema') {
                    loadAdminComponentesPanel();
                } else if (currentSession.role === 'tecnico') {
                    loadComponentesTecnico();
                }
            } else {
                showToast(`Error: ${result.error}`, 'danger');
            }
        } catch (err) {
            showToast('Error al asignar componente.', 'danger');
        }
    });
}

// Lógica de auto-asignación ("Asignarme a mí mismo")
async function asignarIncidenciaSelf(idIncidencia, role) {
    try {
        const res = await fetch('/api/soporte/incidencia/asignar', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id_incidencia: idIncidencia,
                id_tecnico_asignador: currentSession.userId,
                id_tecnico_asignado: currentSession.userId
            })
        });
        const result = await res.json();
        if (res.ok) {
            showToast('Te has asignado la incidencia con éxito.', 'success');
            if (role === 'admin') {
                AdmDOM.cardAtencionDetalle.classList.add('hidden');
                fetchAndRenderIncidencias('admin');
            } else {
                TecDOM.cardAtencionDetalle.classList.add('hidden');
                fetchAndRenderIncidencias('tecnico');
            }
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error al asignarte la incidencia.', 'danger');
    }
}

const btnTecAsignarSelf = document.getElementById('btn-tec-asignar-self');
if (btnTecAsignarSelf) {
    btnTecAsignarSelf.addEventListener('click', () => {
        const idIncidencia = TecDOM.detailId.textContent;
        asignarIncidenciaSelf(idIncidencia, 'tecnico');
    });
}

const btnAdmAsignarSelf = document.getElementById('btn-adm-asignar-self');
if (btnAdmAsignarSelf) {
    btnAdmAsignarSelf.addEventListener('click', () => {
        const idIncidencia = AdmDOM.detailId.textContent;
        asignarIncidenciaSelf(idIncidencia, 'admin');
    });
}

