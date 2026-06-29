import { buildRouteRows } from "../models/request.model.js";
import { formatCurrency } from "../utils/format.js";
import {
  pageHeading,
  renderActiveLoan,
  renderAdvisorDirectory,
  renderAdvisorFieldForm,
  renderClientDirectory,
  renderClientRequestForm,
  renderClientRequests,
  renderCompactRequestList,
  renderMetric,
  renderMetrics,
  renderMiniPanel,
  renderProfileCard,
  renderRequestWorkspace,
  renderRoleLayout,
  renderRouteCard,
  renderTracking,
} from "./components.view.js";

export function renderAdminPage({ page, rows, filtered, selected, filters, actionMessage }) {
  let content = "";
  if (page === "dashboard") {
    content = `
      ${pageHeading("Dashboard", "Indicadores generales y supervision del flujo completo.")}
      ${renderMetrics(rows)}
      <section class="info-grid">
        ${renderMiniPanel("Solicitudes por atender", rows.filter((row) => row.statusGroup === "pending").length, "Pendientes de evaluacion")}
        ${renderMiniPanel("Clientes visitados", rows.filter((row) => row.visitStatus === "Visitado").length, "Atencion registrada")}
        ${renderMiniPanel("Datos demo disponibles", rows.filter((row) => row.source === "demo").length, "Scoring y pruebas")}
      </section>
      ${renderRequestWorkspace({
        title: "Ultimas solicitudes",
        rows: rows.slice(0, 12),
        filtered: rows.slice(0, 12),
        selected,
        mode: "admin",
        filters,
        actionMessage,
      })}
    `;
  } else if (page === "solicitudes") {
    content = `
      ${pageHeading("Solicitudes", "Solicitudes generadas desde Cliente y Fuerza de Ventas.")}
      ${renderRequestWorkspace({
        title: "Solicitudes del sistema",
        rows,
        filtered,
        selected,
        mode: "admin",
        filters,
        actionMessage,
      })}
    `;
  } else if (page === "clientes") {
    content = `
      ${pageHeading("Clientes", "Listado general de clientes reales y demo sin alterar los moviles.")}
      ${renderClientDirectory(rows)}
    `;
  } else if (page === "asesores") {
    content = `
      ${pageHeading("Asesores", "Actividad derivada de solicitudes y atenciones registradas.")}
      ${renderAdvisorDirectory(rows)}
    `;
  } else {
    content = `
      ${pageHeading("Seguimiento", "Trazabilidad de cambios de estado y avance de solicitudes.")}
      ${renderTracking(rows)}
    `;
  }
  return renderRoleLayout("admin", page, content);
}

export function renderClientPage({ page, state, requests }) {
  const profile = state.clientProfile || {};
  const visibleLoan = state.activeLoan;
  let content = "";
  if (page === "inicio") {
    content = `
      ${pageHeading("Inicio", "Resumen de tus datos, solicitudes y productos activos.")}
      <section class="metrics-grid">
        ${renderMetric("Solicitudes", requests.length)}
        ${renderMetric("Pendientes", requests.filter((row) => row.statusGroup === "pending").length)}
        ${renderMetric("Aceptadas", requests.filter((row) => row.statusGroup === "accepted").length)}
        ${renderMetric("Creditos activos", visibleLoan ? 1 : 0)}
        ${renderMetric("Saldo total", formatCurrency(profile.totalBalance))}
        ${renderMetric("Ahorros", formatCurrency(profile.savingsBalance))}
      </section>
      <section class="client-grid">
        ${renderProfileCard(profile, state.user)}
        <article class="list-panel">
          <div class="panel-heading"><div><h2>Ultimas solicitudes</h2><p>Estados sincronizados con la app movil.</p></div></div>
          ${renderClientRequests(requests.slice(0, 5))}
        </article>
      </section>
    `;
  } else if (page === "solicitudes") {
    content = `
      ${pageHeading("Solicitudes", "Crea y consulta solicitudes usando el mismo flujo de la app movil.")}
      <section class="client-grid">
        <article class="list-panel">
          <div class="panel-heading"><div><h2>Nueva solicitud</h2><p>Se enviara al flujo de Fuerza de Ventas.</p></div></div>
          ${renderClientRequestForm(state.clientLocation, state.actionMessage)}
        </article>
        <article class="list-panel">
          <div class="panel-heading"><div><h2>Mis solicitudes</h2><p>${requests.length} registro${requests.length === 1 ? "" : "s"}</p></div></div>
          ${renderClientRequests(requests)}
        </article>
      </section>
    `;
  } else if (page === "creditos") {
    content = `
      ${pageHeading("Creditos", "Solo se muestra prestamo activo con aprobacion y desembolso real.")}
      <article class="list-panel">${renderActiveLoan(visibleLoan, state.installments)}</article>
    `;
  } else {
    content = `
      ${pageHeading("Perfil", "Datos personales registrados en la base compartida.")}
      ${renderProfileCard(profile, state.user)}
    `;
  }
  return renderRoleLayout("client", page, content);
}

export function renderAdvisorPage({ page, rows, filtered, selected, filters, actionMessage }) {
  let content = "";
  if (page === "cartera") {
    content = `
      ${pageHeading("Cartera", "Clientes asignados, solicitudes recibidas y filtros operativos.")}
      ${renderMetrics(rows)}
      ${renderRequestWorkspace({
        title: "Cartera y solicitudes asignadas",
        rows,
        filtered,
        selected,
        mode: "advisor-read",
        filters,
        actionMessage,
      })}
    `;
  } else if (page === "ruta") {
    const routeRows = buildRouteRows(rows);
    content = `
      ${pageHeading("Ruta", "Cuatro clientes demo asignados y nuevas solicitudes reales en ruta.")}
      <section class="route-panel">
        <div class="route-grid">
          ${routeRows.length
            ? routeRows.map(renderRouteCard).join("")
            : '<div class="empty-state">Sin clientes en ruta.</div>'}
        </div>
      </section>
      ${renderRequestWorkspace({
        title: "Detalle de ruta",
        rows: routeRows,
        filtered: routeRows,
        selected,
        mode: "advisor-read",
        filters,
        actionMessage,
      })}
    `;
  } else if (page === "solicitud") {
    content = `
      ${pageHeading("Solicitud", "Completa la informacion de campo y guarda en Firestore.")}
      <section class="client-grid">
        <article class="list-panel">
          <div class="panel-heading"><div><h2>Solicitudes asignadas</h2><p>Selecciona una ficha para completarla.</p></div></div>
          ${renderCompactRequestList(filtered, selected?.key)}
        </article>
        <article class="list-panel">
          <div class="panel-heading"><div><h2>Ficha de solicitud</h2><p>Actualiza el registro existente, sin duplicarlo.</p></div></div>
          ${selected ? renderAdvisorFieldForm(selected, actionMessage) : '<div class="empty-state">Selecciona una solicitud.</div>'}
        </article>
      </section>
    `;
  } else {
    content = `
      ${pageHeading("Cliente", "Ficha del cliente, estado de atencion y decision crediticia.")}
      ${renderRequestWorkspace({
        title: "Fichas disponibles",
        rows,
        filtered,
        selected,
        mode: "advisor",
        filters,
        actionMessage,
      })}
    `;
  }
  return renderRoleLayout("advisor", page, content);
}
