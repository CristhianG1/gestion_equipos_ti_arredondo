// State management de la sesión simulada
let currentSession = {
    userId: null,
    userName: '',
    role: ''
};

// Elementos del DOM
const DOM = {
    viewRoleSelection: document.getElementById('view-role-selection'),
    viewLoginSimulation: document.getElementById('view-login-simulation'),
    viewEmpleadoDashboard: document.getElementById('view-empleado-dashboard'),
    userSessionInfo: document.getElementById('user-session-info'),
    sessionName: document.getElementById('session-name'),
    sessionBadge: document.getElementById('session-badge'),
    btnLogout: document.getElementById('btn-logout'),
    btnBackRoles: document.getElementById('btn-back-roles'),
    selectUserSimulation: document.getElementById('select-user-simulation'),
    btnConfirmLogin: document.getElementById('btn-confirm-login'),
    
    // Navegación Empleado
    btnNavRegistrar: document.getElementById('btn-nav-registrar'),
    btnNavRevisar: document.getElementById('btn-nav-revisar'),
    panelRegistrarIncidencia: document.getElementById('panel-registrar-incidencia'),
    panelRevisarIncidencias: document.getElementById('panel-revisar-incidencias'),
    
    // Formularios
    formRegistrarIncidencia: document.getElementById('form-registrar-incidencia'),
    regIdEquipo: document.getElementById('reg-id-equipo'),
    regPrioridad: document.getElementById('reg-prioridad'),
    regDescripcion: document.getElementById('reg-descripcion'),
    
    // Tablas y detalles
    tbodyIncidencias: document.getElementById('tbody-incidencias'),
    cardSeguimientoDetalle: document.getElementById('card-seguimiento-detalle'),
    btnCloseDetail: document.getElementById('btn-close-detail'),
    detailIdIncidencia: document.getElementById('detail-id-incidencia'),
    detailEquipo: document.getElementById('detail-equipo'),
    detailDescripcion: document.getElementById('detail-descripcion'),
    detailEstado: document.getElementById('detail-estado'),
    timelineSeguimiento: document.getElementById('timeline-seguimiento'),
    
    toastContainer: document.getElementById('toast-container')
};

// =============================================================================
// FUNCIONES AUXILIARES (TOASTS Y CARGAS DE API)
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

// Cargar equipos disponibles para el SELECT de incidencias
async function loadEquipos() {
    try {
        const res = await fetch('/api/equipos');
        const equipos = await res.json();
        
        DOM.regIdEquipo.innerHTML = '<option value="" disabled selected>Selecciona el equipo...</option>';
        equipos.forEach(eq => {
            const opt = document.createElement('option');
            opt.value = eq.id_equipo;
            opt.textContent = `${eq.codigo_inventario} - ${eq.tipo.toUpperCase()} (${eq.marca || 'Genérico'}) [${eq.estado}]`;
            DOM.regIdEquipo.appendChild(opt);
        });
    } catch (err) {
        showToast('Error al cargar la lista de equipos.', 'danger');
    }
}

// Cargar incidencias del usuario y pintar la tabla
async function loadIncidencias() {
    try {
        const res = await fetch(`/api/empleado/incidencias/${currentSession.userId}`);
        const incidencias = await res.json();
        
        DOM.tbodyIncidencias.innerHTML = '';
        
        if (incidencias.length === 0) {
            DOM.tbodyIncidencias.innerHTML = `
                <tr>
                    <td colspan="5" class="empty-state">No tienes incidencias registradas en el sistema.</td>
                </tr>
            `;
            return;
        }

        incidencias.forEach(inc => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>#${inc.id_incidencia}</td>
                <td>EQU-${inc.id_equipo}</td>
                <td>${inc.descripcion}</td>
                <td><span class="badge badge-${inc.estado}">${inc.estado}</span></td>
                <td>
                    <button class="btn btn-secondary btn-sm btn-ver-seg" data-id="${inc.id_incidencia}" data-equipo="EQU-${inc.id_equipo}" data-desc="${inc.descripcion}" data-estado="${inc.estado}">
                        Ver Seguimiento
                    </button>
                </td>
            `;
            DOM.tbodyIncidencias.appendChild(row);
        });

        // Registrar eventos click en los botones "Ver Seguimiento"
        document.querySelectorAll('.btn-ver-seg').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const target = e.target;
                const id = target.getAttribute('data-id');
                const equipo = target.getAttribute('data-equipo');
                const desc = target.getAttribute('data-desc');
                const estado = target.getAttribute('data-estado');
                showIncidenciaSeguimiento(id, equipo, desc, estado);
            });
        });
    } catch (err) {
        showToast('Error al cargar tus incidencias.', 'danger');
    }
}

// Mostrar el detalle y seguimiento de la incidencia seleccionada
async function showIncidenciaSeguimiento(id, equipo, descripcion, estado) {
    DOM.detailIdIncidencia.textContent = id;
    DOM.detailEquipo.textContent = equipo;
    DOM.detailDescripcion.textContent = descripcion;
    DOM.detailEstado.textContent = estado;
    DOM.detailEstado.className = `badge badge-${estado}`;
    
    DOM.timelineSeguimiento.innerHTML = '<p class="empty-state">Buscando seguimiento...</p>';
    DOM.cardSeguimientoDetalle.classList.remove('hidden');
    DOM.cardSeguimientoDetalle.scrollIntoView({ behavior: 'smooth' });

    try {
        const res = await fetch(`/api/empleado/incidencias/seguimiento/${id}`);
        const seguimientos = await res.json();
        
        DOM.timelineSeguimiento.innerHTML = '';

        if (seguimientos.length === 0) {
            DOM.timelineSeguimiento.innerHTML = `
                <div class="timeline-item">
                    <div class="timeline-dot"></div>
                    <div class="timeline-content">
                        <div class="timeline-header">
                            <span class="timeline-tech">Soporte Técnico</span>
                            <span>Ahora</span>
                        </div>
                        <div class="timeline-body">
                            <p>La incidencia ha sido registrada correctamente. Actualmente se encuentra en estado <strong>${estado}</strong> y está en la cola de revisión por parte de los técnicos.</p>
                        </div>
                    </div>
                </div>
            `;
            return;
        }

        seguimientos.forEach(seg => {
            const fechaStr = new Date(seg.fecha).toLocaleString('es-PE', {
                day: '2-digit', month: '2-digit', year: 'numeric',
                hour: '2-digit', minute: '2-digit'
            });
            const item = document.createElement('div');
            item.className = 'timeline-item';
            item.innerHTML = `
                <div class="timeline-dot"></div>
                <div class="timeline-content">
                    <div class="timeline-header">
                        <span class="timeline-tech">Técnico ID: ${seg.id_tecnico}</span>
                        <span>${fechaStr}</span>
                    </div>
                    <div class="timeline-body">
                        <p><strong>Diagnóstico:</strong> ${seg.diagnostico || 'Sin diagnóstico aún.'}</p>
                        <p><strong>Trabajo Realizado:</strong> ${seg.trabajo_realizado || 'En evaluación.'}</p>
                    </div>
                    <div class="timeline-meta">
                        <span>Horas invertidas: ${seg.horas_invertidas}h</span>
                        ${seg.id_componente_cambiado ? `<span>Componente cambiado: ID ${seg.id_componente_cambiado}</span>` : ''}
                    </div>
                </div>
            `;
            DOM.timelineSeguimiento.appendChild(item);
        });
    } catch (err) {
        showToast('Error al consultar el historial de seguimiento.', 'danger');
    }
}

// =============================================================================
// NAVEGACIÓN Y EVENTOS DE PANTALLA
// =============================================================================

// Inicializar selección de rol
document.querySelectorAll('.role-card:not(.disabled)').forEach(card => {
    card.addEventListener('click', async () => {
        const role = card.getAttribute('data-role');
        currentSession.role = role;
        
        // Simular flujo de inicio de sesión trayendo los usuarios de la base de datos
        DOM.viewRoleSelection.classList.add('hidden');
        DOM.viewLoginSimulation.classList.remove('hidden');
        
        try {
            const res = await fetch('/api/roles/usuarios');
            const usuarios = await res.json();
            
            // Filtrar usuarios del tipo empleado
            const empleados = usuarios.filter(u => u.cargo === 'empleado');
            
            DOM.selectUserSimulation.innerHTML = '';
            empleados.forEach(emp => {
                const opt = document.createElement('option');
                opt.value = emp.id_usuario;
                opt.textContent = `${emp.nombres} ${emp.apellidos} (ID: ${emp.id_usuario})`;
                DOM.selectUserSimulation.appendChild(opt);
            });
        } catch (err) {
            showToast('Error al simular la conexión de usuarios.', 'danger');
        }
    });
});

// Confirmar ingreso
DOM.btnConfirmLogin.addEventListener('click', () => {
    const selectedOpt = DOM.selectUserSimulation.options[DOM.selectUserSimulation.selectedIndex];
    if (!selectedOpt) {
        showToast('Por favor selecciona un usuario de prueba.', 'warning');
        return;
    }
    
    currentSession.userId = DOM.selectUserSimulation.value;
    currentSession.userName = selectedOpt.textContent.split(' (ID:')[0];
    
    // Mostrar sesión en el header
    DOM.sessionBadge.textContent = currentSession.role;
    DOM.sessionName.textContent = currentSession.userName;
    DOM.userSessionInfo.classList.remove('hidden');
    
    // Cargar dashboard de empleado
    DOM.viewLoginSimulation.classList.add('hidden');
    DOM.viewEmpleadoDashboard.classList.remove('hidden');
    
    // Carga inicial
    loadEquipos();
    loadIncidencias();
    
    showToast(`Sesión simulada como ${currentSession.userName}.`);
});

// Volver atrás en roles
DOM.btnBackRoles.addEventListener('click', () => {
    DOM.viewLoginSimulation.classList.add('hidden');
    DOM.viewRoleSelection.classList.remove('hidden');
});

// Cerrar sesión
DOM.btnLogout.addEventListener('click', () => {
    currentSession = { userId: null, userName: '', role: '' };
    DOM.userSessionInfo.classList.add('hidden');
    DOM.viewEmpleadoDashboard.classList.add('hidden');
    DOM.viewRoleSelection.classList.remove('hidden');
    DOM.cardSeguimientoDetalle.classList.add('hidden');
    DOM.formRegistrarIncidencia.reset();
});

// Navegación interna Empleado (Tabs)
DOM.btnNavRegistrar.addEventListener('click', () => {
    DOM.btnNavRegistrar.classList.add('active');
    DOM.btnNavRevisar.classList.remove('active');
    DOM.panelRegistrarIncidencia.classList.remove('hidden');
    DOM.panelRevisarIncidencias.classList.add('hidden');
});

DOM.btnNavRevisar.addEventListener('click', () => {
    DOM.btnNavRegistrar.classList.remove('active');
    DOM.btnNavRevisar.classList.add('active');
    DOM.panelRegistrarIncidencia.classList.add('hidden');
    DOM.panelRevisarIncidencias.classList.remove('hidden');
    loadIncidencias(); // Recargar incidencias cada vez que se revisa la lista
});

// Cerrar card de seguimiento detallado
DOM.btnCloseDetail.addEventListener('click', () => {
    DOM.cardSeguimientoDetalle.classList.add('hidden');
});

// =============================================================================
// SUBMIT DE FORMULARIO - REGISTRAR INCIDENCIA
// =============================================================================

DOM.formRegistrarIncidencia.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const data = {
        id_equipo: DOM.regIdEquipo.value,
        prioridad: DOM.regPrioridad.value,
        descripcion: DOM.regDescripcion.value.trim()
    };
    
    if (!data.id_equipo) {
        showToast('Debes seleccionar un equipo.', 'warning');
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
            showToast('¡Incidencia registrada correctamente en la Base de Datos!');
            DOM.formRegistrarIncidencia.reset();
            // Cargar y cambiar de pestaña automáticamente para ver la tabla
            loadIncidencias();
            DOM.btnNavRevisar.click();
        } else {
            showToast(`Error: ${result.error}`, 'danger');
        }
    } catch (err) {
        showToast('Error de red al intentar registrar la incidencia.', 'danger');
    }
});
