import { creditPurposes, navConfig } from "../config/constants.js";
import { buildHistory, isVisibleActiveLoan } from "../models/request.model.js";
import { roleLabel } from "../models/role.model.js";
import {
  escapeAttr,
  escapeHtml,
  formatCurrency,
  formatDate,
} from "../utils/format.js";

export function renderRoleLayout(role, page, content) {
  const nav = navConfig[role] || [];
  return `
    <section class="role-layout">
      <nav class="side-nav" aria-label="Navegacion ${escapeAttr(roleLabel(role))}">
        <span>${escapeHtml(roleLabel(role))}</span>
        ${nav
          .map(
            (item) => `
              <a class="nav-link ${item.id === page ? "active" : ""}" href="#/${role}/${item.id}">
                ${escapeHtml(item.label)}
              </a>
            `,
          )
          .join("")}
      </nav>
      <section class="page-content">${content}</section>
    </section>
  `;
}

export function pageHeading(title, subtitle) {
  return `
    <div class="page-heading">
      <div>
        <h2>${escapeHtml(title)}</h2>
        ${subtitle ? `<p>${escapeHtml(subtitle)}</p>` : ""}
      </div>
    </div>
  `;
}

export function renderMetrics(rows) {
  const metrics = [
    ["Total solicitudes", rows.length],
    ["Pendientes", rows.filter((row) => row.statusGroup === "pending").length],
    ["Aceptadas", rows.filter((row) => row.statusGroup === "accepted").length],
    ["Rechazadas", rows.filter((row) => row.statusGroup === "rejected").length],
    ["Aprobadas", rows.filter((row) => row.statusGroup === "approved").length],
    ["Desembolsadas", rows.filter((row) => row.statusGroup === "disbursed").length],
  ];
  return `<section class="metrics-grid" aria-label="Indicadores">${metrics
    .map(([label, value]) => renderMetric(label, value))
    .join("")}</section>`;
}

export function renderMetric(label, value) {
  return `
    <article class="metric-card">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(String(value))}</strong>
    </article>
  `;
}

export function renderMiniPanel(title, value, caption) {
  return `
    <article class="mini-panel">
      <span>${escapeHtml(title)}</span>
      <strong>${escapeHtml(String(value))}</strong>
      <small>${escapeHtml(caption)}</small>
    </article>
  `;
}

export function renderRequestWorkspace({ title, rows, filtered, selected, mode, filters, actionMessage }) {
  return `
    <section class="workspace">
      <article class="list-panel">
        <div class="panel-heading">
          <div>
            <h2>${escapeHtml(title)}</h2>
            <p>${filtered.length} registro${filtered.length === 1 ? "" : "s"}</p>
          </div>
          <button type="button" class="ghost-button" data-refresh>Actualizar</button>
        </div>
        <div class="filters">${renderFilters(mode, filters)}</div>
        <div class="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Cliente</th>
                <th>DNI</th>
                <th>Monto</th>
                <th>Estado</th>
                <th>Atencion</th>
                <th>Asesor</th>
                <th>Score</th>
              </tr>
            </thead>
            <tbody>${filtered.map((row) => renderRequestRow(row, selected?.key)).join("")}</tbody>
          </table>
        </div>
        ${filtered.length ? "" : '<div class="empty-state">No hay registros para los filtros seleccionados.</div>'}
      </article>
      <aside class="detail-panel">
        ${selected ? renderDetail(selected, mode, actionMessage) : '<div class="detail-empty">Selecciona una solicitud para revisar su detalle.</div>'}
      </aside>
    </section>
  `;
}

export function renderFilters(mode, filters) {
  const advisorFilter =
    mode === "admin"
      ? `
        <label>
          Asesor
          <input data-filter="advisor" type="search" value="${escapeAttr(filters.advisor)}" placeholder="Correo o nombre" />
        </label>
        <label>
          Fecha
          <input data-filter="date" type="date" value="${escapeAttr(filters.date)}" />
        </label>
      `
      : "";
  return `
    <label>
      Buscar
      <input data-filter="search" type="search" value="${escapeAttr(filters.search)}" placeholder="DNI, nombre o telefono" />
    </label>
    <label>
      Estado solicitud
      <select data-filter="status">
        ${selectOption("all", "Todos", filters.status)}
        ${selectOption("pending", "Pendiente", filters.status)}
        ${selectOption("accepted", "Aceptado", filters.status)}
        ${selectOption("rejected", "Rechazado", filters.status)}
        ${selectOption("approved", "Aprobado", filters.status)}
        ${selectOption("disbursed", "Desembolsado", filters.status)}
      </select>
    </label>
    <label>
      Atencion
      <select data-filter="visit">
        ${selectOption("all", "Todos", filters.visit)}
        ${selectOption("Visitar", "Visitar", filters.visit)}
        ${selectOption("Visitado", "Visitado", filters.visit)}
      </select>
    </label>
    <label>
      Origen
      <select data-filter="source">
        ${selectOption("all", "Todos", filters.source)}
        ${selectOption("real", "Solicitudes reales", filters.source)}
        ${selectOption("demo", "Demo scoring", filters.source)}
      </select>
    </label>
    ${advisorFilter}
  `;
}

export function renderRequestRow(row, selectedKey) {
  return `
    <tr data-key="${escapeAttr(row.key)}" class="${row.key === selectedKey ? "selected" : ""}">
      <td class="client-cell">
        <strong>${escapeHtml(row.clientName || "Sin nombre")}</strong>
        <span>${escapeHtml(row.source === "demo" ? "Demo scoring" : "Solicitud movil")}</span>
      </td>
      <td>${escapeHtml(row.dni || "Sin DNI")}</td>
      <td>${formatCurrency(row.amount)}</td>
      <td><span class="pill ${row.statusGroup}">${escapeHtml(row.statusLabel)}</span></td>
      <td><span class="pill">${escapeHtml(row.visitStatus)}</span></td>
      <td>${escapeHtml(row.advisor || "-")}</td>
      <td>${row.score ? row.score : "-"}</td>
    </tr>
  `;
}

export function renderDetail(row, mode, actionMessage = "") {
  const history = buildHistory(row);
  const locationText =
    row.latitude && row.longitude
      ? `${row.locationLabel || "Ubicacion registrada"} (${row.latitude.toFixed(5)}, ${row.longitude.toFixed(5)})`
      : row.locationLabel || "Sin ubicacion registrada";
  return `
    <div class="detail-header">
      <span class="pill ${row.statusGroup}">${escapeHtml(row.statusLabel)}</span>
      ${row.source === "demo" ? '<span class="pill demo">Demo</span>' : ""}
      <h2>${escapeHtml(row.clientName || "Sin nombre")}</h2>
      <p>DNI ${escapeHtml(row.dni || "No registrado")}</p>
    </div>
    ${actionMessage ? `<div class="notice">${escapeHtml(actionMessage)}</div>` : ""}
    ${mode === "advisor" ? renderAdvisorActions(row) : ""}
    ${detailSection("Datos del cliente", [
      ["Telefono", row.phone || "No registrado"],
      ["Cliente ID", row.clientId || row.id || "No registrado"],
      ["Estado atencion", row.visitStatus],
      ["Asesor", row.advisor || "No asignado"],
    ])}
    ${detailSection("Solicitud de credito", [
      ["Monto solicitado", formatCurrency(row.amount)],
      ["Plazo", row.termMonths ? `${row.termMonths} meses` : "No registrado"],
      ["Destino", row.purpose || "No registrado"],
      ["Estado", row.statusLabel],
    ])}
    ${detailSection("Ruta y ficha", [
      ["Ubicacion", locationText],
      ["Ficha completada", row.fieldVisitCompleted ? "Si" : "No"],
      ["Negocio", row.businessName || "No registrado"],
      ["Rubro", row.businessType || "No registrado"],
    ])}
    ${detailSection("Evaluacion", [
      ["Score", row.score || "No registrado"],
      ["Nivel de riesgo", row.riskLevel || "No registrado"],
      ["Ingresos", formatCurrency(row.monthlyIncome)],
      ["Deuda", formatCurrency(row.debt)],
    ])}
    <section class="detail-section">
      <h3>Historial</h3>
      <ul class="timeline">${history
        .map(
          (item) => `<li><strong>${escapeHtml(item.title)}</strong><span>${escapeHtml(item.subtitle)}</span></li>`,
        )
        .join("")}</ul>
    </section>
  `;
}

export function renderAdvisorActions(row) {
  const canEvaluate = row.statusGroup === "pending" && row.fieldVisitCompleted;
  const decisionTaken = ["accepted", "rejected", "approved", "disbursed"].includes(
    row.statusGroup,
  );
  return `
    <section class="detail-section action-box">
      <h3>Acciones permitidas</h3>
      <div class="button-row">
        <button class="ghost-button" data-action="visit" ${row.visitStatus === "Visitado" ? "disabled" : ""}>Marcar visitado</button>
        <button class="primary-button" data-action="accept" ${!canEvaluate || decisionTaken ? "disabled" : ""}>Aceptar credito</button>
        <button class="danger-button" data-action="reject" ${!canEvaluate || decisionTaken ? "disabled" : ""}>Negar credito</button>
      </div>
      <p class="hint">La decision solo se habilita cuando la ficha de campo ya fue guardada.</p>
    </section>
  `;
}

export function renderRouteCard(row) {
  return `
    <article class="route-card">
      <strong>${escapeHtml(row.clientName || "Sin nombre")}</strong>
      <span>DNI ${escapeHtml(row.dni || "-")}</span>
      <span>${escapeHtml(row.locationLabel || "Ubicacion pendiente")}</span>
      <span class="pill ${row.statusGroup}">${escapeHtml(row.statusLabel)}</span>
    </article>
  `;
}

export function renderProfileCard(profile, user) {
  return `
    <article class="list-panel">
      <div class="panel-heading">
        <div>
          <h2>Datos personales</h2>
        </div>
      </div>
      <div class="detail-section">
        <div class="kv-grid">
          ${kv("Nombre", profile.fullName || profile.nombres || user.displayName || "No registrado")}
          ${kv("DNI", profile.documentNumber || profile.dni || "No registrado")}
          ${kv("Correo", profile.email || user.email || "No registrado")}
          ${kv("Telefono", profile.phone || profile.telefono || "No registrado")}
          ${kv("Saldo total", formatCurrency(profile.totalBalance))}
          ${kv("Saldo ahorros", formatCurrency(profile.savingsBalance))}
        </div>
      </div>
    </article>
  `;
}

export function renderClientRequestForm(location, actionMessage = "") {
  return `
    <form id="clientRequestForm" class="form-stack">
      <label>Monto solicitado<input name="amount" inputmode="decimal" placeholder="S/ 0.00" required /></label>
      <label>Plazo en meses<input name="term" inputmode="numeric" placeholder="12" required /></label>
      <label>
        Destino del credito
        <select name="purpose" required>
          <option value="">Selecciona una opcion</option>
          ${creditPurposes.map((item) => `<option value="${escapeAttr(item)}">${escapeHtml(item)}</option>`).join("")}
        </select>
      </label>
      <label class="hidden" data-other-purpose>Especifica destino<input name="otherPurpose" /></label>
      <div class="button-row">
        <button type="button" class="ghost-button" data-location>Usar ubicacion</button>
        <button type="submit" class="primary-button">Enviar solicitud</button>
      </div>
      <p class="hint" data-location-label>${
        location
          ? `Ubicacion lista: ${location.latitude.toFixed(5)}, ${location.longitude.toFixed(5)}`
          : "La ubicacion se adjuntara si el navegador lo permite."
      }</p>
      <p class="form-error" data-form-message>${escapeHtml(actionMessage)}</p>
    </form>
  `;
}

export function renderClientRequests(requests) {
  if (!requests.length) {
    return '<div class="empty-state">Aun no tienes solicitudes registradas.</div>';
  }
  return `
    <div class="table-wrap">
      <table>
        <thead><tr><th>Fecha</th><th>Monto</th><th>Destino</th><th>Estado</th></tr></thead>
        <tbody>${requests
          .map(
            (row) => `
              <tr>
                <td>${formatDate(row.updatedAt || row.createdAt)}</td>
                <td>${formatCurrency(row.amount)}</td>
                <td>${escapeHtml(row.purpose || "No registrado")}</td>
                <td><span class="pill ${row.statusGroup}">${escapeHtml(row.statusLabel)}</span></td>
              </tr>
            `,
          )
          .join("")}</tbody>
      </table>
    </div>
  `;
}

export function renderActiveLoan(loan, installments) {
  if (!isVisibleActiveLoan(loan)) {
    return '<div class="empty-state">No existe un prestamo aprobado y desembolsado para mostrar.</div>';
  }
  return `
    <div class="detail-section">
      <div class="kv-grid">
        ${kv("Credito", loan.id || "activeLoan")}
        ${kv("Monto", formatCurrency(loan.amount))}
        ${kv("Saldo pendiente", formatCurrency(loan.pendingBalance))}
        ${kv("Estado", loan.status || "Al dia")}
      </div>
    </div>
    <div class="detail-section">
      <h3>Cronograma</h3>
      ${installments.length
        ? `<ul class="timeline">${installments
            .map(
              (item) => `<li><strong>Cuota ${escapeHtml(item.number || item.id)}</strong><span>${escapeHtml(item.dueDate || "Sin fecha")} - ${formatCurrency(item.amount)} - ${item.isPaid ? "Pagada" : "Pendiente"}</span></li>`,
            )
            .join("")}</ul>`
        : '<div class="empty-state">Sin cronograma registrado.</div>'}
    </div>
  `;
}

export function renderClientDirectory(rows) {
  const clients = new Map();
  for (const row of rows) {
    const key = row.dni || row.clientId || row.key;
    if (!clients.has(key)) clients.set(key, row);
  }
  const list = [...clients.values()];
  if (!list.length) return '<div class="empty-state">No hay clientes para mostrar.</div>';
  return `
    <div class="table-wrap list-panel">
      <table>
        <thead><tr><th>Cliente</th><th>DNI</th><th>Telefono</th><th>Solicitud</th><th>Atencion</th><th>Score</th></tr></thead>
        <tbody>${list
          .map(
            (row) => `
              <tr>
                <td class="client-cell"><strong>${escapeHtml(row.clientName || "Sin nombre")}</strong><span>${escapeHtml(row.businessName || row.source)}</span></td>
                <td>${escapeHtml(row.dni || "-")}</td>
                <td>${escapeHtml(row.phone || "-")}</td>
                <td><span class="pill ${row.statusGroup}">${escapeHtml(row.statusLabel)}</span></td>
                <td><span class="pill">${escapeHtml(row.visitStatus)}</span></td>
                <td>${row.score || "-"}</td>
              </tr>
            `,
          )
          .join("")}</tbody>
      </table>
    </div>
  `;
}

export function renderAdvisorDirectory(rows) {
  const advisors = new Map();
  for (const row of rows) {
    const key = row.advisor || "Sin asesor asignado";
    const item = advisors.get(key) || { name: key, total: 0, pending: 0, visited: 0, accepted: 0, rejected: 0 };
    item.total += 1;
    if (row.statusGroup === "pending") item.pending += 1;
    if (row.visitStatus === "Visitado") item.visited += 1;
    if (row.statusGroup === "accepted") item.accepted += 1;
    if (row.statusGroup === "rejected") item.rejected += 1;
    advisors.set(key, item);
  }
  return `<section class="info-grid">${[...advisors.values()]
    .map(
      (item) => `
        <article class="mini-panel">
          <span>${escapeHtml(item.name)}</span>
          <strong>${item.total}</strong>
          <small>Pendientes: ${item.pending} - Visitados: ${item.visited} - Aceptados: ${item.accepted} - Rechazados: ${item.rejected}</small>
        </article>
      `,
    )
    .join("")}</section>`;
}

export function renderTracking(rows) {
  const events = rows
    .flatMap((row) =>
      buildHistory(row).map((item) => ({
        title: `${row.clientName || "Cliente"} - ${item.title}`,
        subtitle: item.subtitle,
      })),
    )
    .slice(0, 80);
  if (!events.length) return '<div class="empty-state">No hay eventos para mostrar.</div>';
  return `
    <article class="list-panel">
      <div class="detail-section">
        <ul class="timeline">${events
          .map((event) => `<li><strong>${escapeHtml(event.title)}</strong><span>${escapeHtml(event.subtitle)}</span></li>`)
          .join("")}</ul>
      </div>
    </article>
  `;
}

export function renderCompactRequestList(rows, selectedKey) {
  if (!rows.length) return '<div class="empty-state">No hay solicitudes asignadas.</div>';
  return `
    <div class="detail-section">
      <div class="route-grid">${rows
        .map(
          (row) => `
            <button type="button" class="route-card ${row.key === selectedKey ? "selected" : ""}" data-select-request="${escapeAttr(row.key)}">
              <strong>${escapeHtml(row.clientName || "Sin nombre")}</strong>
              <span>DNI ${escapeHtml(row.dni || "-")}</span>
              <span>${escapeHtml(row.statusLabel)} - ${escapeHtml(row.visitStatus)}</span>
            </button>
          `,
        )
        .join("")}</div>
    </div>
  `;
}

export function renderAdvisorFieldForm(row, actionMessage = "") {
  return `
    <form id="advisorFieldForm" class="form-stack">
      ${formInput("Nombre del cliente", "clientName", row.clientName, true)}
      ${formInput("DNI", "dni", row.dni, true)}
      ${formInput("Telefono", "phone", row.phone)}
      ${formInput("Negocio", "businessName", row.businessName)}
      ${formInput("Rubro", "businessType", row.businessType)}
      ${formInput("Direccion / ubicacion", "locationLabel", row.locationLabel)}
      ${formInput("Ingresos mensuales", "monthlyIncome", row.monthlyIncome)}
      ${formInput("Gastos mensuales", "monthlyExpenses", row.monthlyExpenses)}
      ${formInput("Monto solicitado", "amount", row.amount)}
      ${formInput("Plazo en meses", "termMonths", row.termMonths)}
      <label>
        Destino del credito
        <select name="purpose">${creditPurposes.map((item) => selectOption(item, item, row.purpose)).join("")}</select>
      </label>
      <button type="submit" class="primary-button">Guardar</button>
      <p class="hint">Actualiza la solicitud existente y marca la ficha como completada.</p>
      <p class="form-error">${escapeHtml(actionMessage)}</p>
    </form>
  `;
}

function detailSection(title, entries) {
  return `
    <section class="detail-section">
      <h3>${escapeHtml(title)}</h3>
      <div class="kv-grid">${entries.map(([label, value]) => kv(label, value)).join("")}</div>
    </section>
  `;
}

function kv(label, value) {
  return `
    <div class="kv">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(String(value || "No registrado"))}</strong>
    </div>
  `;
}

function formInput(label, name, value = "", required = false) {
  return `
    <label>
      ${escapeHtml(label)}
      <input name="${escapeAttr(name)}" value="${escapeAttr(value || "")}" ${required ? "required" : ""} />
    </label>
  `;
}

function selectOption(value, label, current) {
  return `<option value="${escapeAttr(value)}" ${value === current ? "selected" : ""}>${escapeHtml(label)}</option>`;
}
