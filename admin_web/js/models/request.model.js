import {
  asNumber,
  formatDate,
  joinName,
  pick,
  toMillis,
} from "../utils/format.js";

export function normalizeRequest(id, data) {
  const rawStatus =
    pick(data, ["estado_solicitud", "estado", "status"]) || "Pendiente";
  const clientName =
    pick(data, ["cliente", "clientName", "nombres", "fullName"]) ||
    joinName(data.nombres, data.apellidos);
  return {
    key: `real:${id}`,
    id,
    source: "real",
    clientId: pick(data, ["clientId", "id_cliente"]) || "",
    requestId: id,
    clientName,
    dni: String(pick(data, ["dni", "documentNumber", "documento"]) || ""),
    phone: pick(data, ["telefono", "phone"]) || "",
    email: pick(data, ["correo", "email"]) || "",
    advisor:
      pick(data, ["advisor", "asesor", "advisorEmail", "asesorEmail"]) || "",
    amount: asNumber(pick(data, ["amount", "monto_solicitado", "monto"])),
    termMonths: asNumber(pick(data, ["plazo_meses", "termMonths"])),
    purpose: pick(data, ["destino_credito", "purpose"]) || "",
    statusRaw: rawStatus,
    statusLabel: normalizeStatusLabel(rawStatus),
    statusGroup: normalizeStatusGroup(rawStatus),
    visitStatus:
      pick(data, ["estado_cliente", "clientStatus"]) === "Visitado"
        ? "Visitado"
        : "Visitar",
    score: asNumber(pick(data, ["score", "score_preliminar"])),
    riskLevel: pick(data, ["nivel_riesgo", "riskLevel"]) || "",
    recommendation:
      pick(data, ["recomendacion_scoring", "recommendation"]) || "",
    latitude: asNumber(pick(data, ["latitud", "latitude"])),
    longitude: asNumber(pick(data, ["longitud", "longitude"])),
    locationLabel: pick(data, ["ubicacion", "location", "direccion"]) || "",
    fieldVisitCompleted:
      data.fieldVisitCompleted === true || data.solicitud_completada === true,
    businessName: pick(data, ["businessName", "negocio"]) || "",
    businessType: pick(data, ["businessType", "rubro"]) || "",
    monthlyIncome: asNumber(
      pick(data, ["monthlyIncome", "ingresos_mensuales"]),
    ),
    monthlyExpenses: asNumber(
      pick(data, ["monthlyExpenses", "gastos_mensuales"]),
    ),
    debt: asNumber(pick(data, ["deuda_actual_scoring", "deuda_actual", "debt"])),
    createdAt: pick(data, ["createdAt", "fecha_creacion", "submittedAt"]),
    updatedAt: pick(data, ["updatedAt", "fecha_actualizacion"]),
    approvedAt: pick(data, ["approvedAt"]),
    disbursedAt: pick(data, ["disbursedAt"]),
  };
}

export function normalizeDemoClient(id, data) {
  const rawStatus =
    pick(data, ["estado_solicitud", "estado", "status"]) || "Pendiente";
  return {
    key: `demo:${id}`,
    id,
    source: "demo",
    clientId: pick(data, ["id_cliente"]) || id,
    requestId: pick(data, ["requestId", "id_solicitud"]) || id,
    clientName:
      joinName(data.nombres, data.apellidos) || pick(data, ["cliente"]) || "",
    dni: String(pick(data, ["dni"]) || ""),
    phone: pick(data, ["telefono"]) || "",
    advisor: pick(data, ["asesor", "advisor"]) || "",
    amount: asNumber(pick(data, ["monto_solicitado", "amount"])),
    termMonths: asNumber(pick(data, ["plazo_meses", "termMonths"])),
    purpose: pick(data, ["destino_credito", "purpose"]) || "",
    statusRaw: rawStatus,
    statusLabel: normalizeStatusLabel(rawStatus),
    statusGroup: normalizeStatusGroup(rawStatus),
    visitStatus:
      pick(data, ["estado_cliente", "clientStatus"]) === "Visitado"
        ? "Visitado"
        : "Visitar",
    score: asNumber(pick(data, ["score", "score_preliminar"])),
    riskLevel: pick(data, ["nivel_riesgo"]) || "",
    recommendation: pick(data, ["recomendacion_scoring"]) || "",
    latitude: asNumber(pick(data, ["latitud", "latitude"])),
    longitude: asNumber(pick(data, ["longitud", "longitude"])),
    locationLabel: pick(data, ["ubicacion", "location"]) || "",
    fieldVisitCompleted:
      data.fieldVisitCompleted === true || data.solicitud_completada === true,
    businessName: pick(data, ["negocio"]) || "",
    businessType: pick(data, ["rubro", "ocupacion"]) || "",
    monthlyIncome: asNumber(pick(data, ["ingresos_mensuales"])),
    monthlyExpenses: asNumber(pick(data, ["gastos_mensuales"])),
    debt: asNumber(pick(data, ["deuda_actual"])),
    createdAt: pick(data, ["createdAt"]),
    updatedAt: pick(data, ["updatedAt"]),
  };
}

export function mergeRow(row, extra) {
  if (!extra || Object.keys(extra).length === 0) return row;
  return {
    ...row,
    phone: row.phone || pick(extra, ["telefono", "phone"]) || "",
    locationLabel:
      row.locationLabel || pick(extra, ["ubicacion", "location"]) || "",
    businessName:
      row.businessName || pick(extra, ["negocio", "businessName"]) || "",
    businessType:
      row.businessType || pick(extra, ["rubro", "businessType"]) || "",
    score: row.score || asNumber(pick(extra, ["score_preliminar", "score"])),
    riskLevel: row.riskLevel || pick(extra, ["nivel_riesgo"]) || "",
    advisor:
      row.advisor || pick(extra, ["asesor", "advisor", "advisorEmail"]) || "",
    visitStatus:
      pick(extra, ["estado_cliente", "clientStatus"]) === "Visitado"
        ? "Visitado"
        : row.visitStatus,
    fieldVisitCompleted:
      row.fieldVisitCompleted ||
      extra.fieldVisitCompleted === true ||
      extra.solicitud_completada === true,
  };
}

export function buildRows({ requests, demoClients, salesClients }) {
  const byDni = new Map();
  for (const client of salesClients) {
    const dni = pick(client, ["dni", "documentNumber", "documento", "id"]);
    if (dni) byDni.set(String(dni), client);
  }

  const realRows = requests.map((request) =>
    mergeRow(request, byDni.get(request.dni) || {}),
  );
  const usedDnis = new Set(realRows.map((row) => row.dni).filter(Boolean));
  const demoRows = demoClients.filter((row) => !usedDnis.has(row.dni));

  return [...realRows, ...demoRows].sort((a, b) => {
    const dateDiff =
      toMillis(b.updatedAt || b.createdAt) -
      toMillis(a.updatedAt || a.createdAt);
    if (dateDiff !== 0) return dateDiff;
    return a.clientName.localeCompare(b.clientName);
  });
}

export function buildRouteRows(rows) {
  const demo = rows.filter((row) => row.source === "demo").slice(0, 4);
  const real = rows.filter((row) => row.source === "real");
  return [...demo, ...real];
}

export function normalizeStatusGroup(status) {
  const value = String(status || "").trim().toLowerCase();
  if (value === "aceptado") return "accepted";
  if (value === "negado" || value === "rechazado") return "rejected";
  if (value.includes("desembols")) return "disbursed";
  if (value.includes("aprob")) return "approved";
  return "pending";
}

export function normalizeStatusLabel(status) {
  const group = normalizeStatusGroup(status);
  if (group === "accepted") return "Aceptado";
  if (group === "rejected") return "Negado";
  if (group === "approved") return "Aprobado";
  if (group === "disbursed") return "Desembolsado";
  return "Pendiente";
}

export function buildHistory(row) {
  const events = [];
  addHistory(events, "Solicitud recibida", row.createdAt, "Registrada en el flujo compartido");
  if (row.visitStatus === "Visitado" || row.fieldVisitCompleted) {
    addHistory(events, "Ficha de campo completada", row.updatedAt, "Informacion guardada por asesor");
  }
  if (row.statusGroup === "accepted") {
    addHistory(events, "Solicitud aceptada", row.updatedAt, "Decision emitida por fuerza de ventas");
  }
  if (row.statusGroup === "rejected") {
    addHistory(events, "Solicitud rechazada", row.updatedAt, "Decision emitida por fuerza de ventas");
  }
  if (row.statusGroup === "approved") {
    addHistory(events, "Credito aprobado", row.approvedAt || row.updatedAt, "Listo para desembolso");
  }
  if (row.statusGroup === "disbursed") {
    addHistory(events, "Credito desembolsado", row.disbursedAt || row.updatedAt, "Visible para Cliente");
  }
  addHistory(events, `Estado actual: ${row.statusLabel}`, row.updatedAt, "Ultima sincronizacion conocida");

  return events
    .filter((event, index, all) => {
      const key = `${event.title}-${event.subtitle}`;
      return all.findIndex((item) => `${item.title}-${item.subtitle}` === key) === index;
    })
    .sort((a, b) => toMillis(a.date) - toMillis(b.date))
    .map((event) => ({
      title: event.title,
      subtitle: `${formatDate(event.date)} - ${event.subtitle}`,
    }));
}

export function isVisibleActiveLoan(loan) {
  if (!loan) return false;
  const status = String(loan.status || "").trim().toLowerCase();
  const disbursed = loan.isDisbursed === true;
  return (
    disbursed ||
    status.includes("aprob") ||
    status.includes("desembols") ||
    status.includes("al dia") ||
    status.includes("al d")
  );
}

function addHistory(events, title, date, subtitle) {
  events.push({ title, date, subtitle });
}
