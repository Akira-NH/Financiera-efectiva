import { normalizeText } from "../utils/format.js";

export function isAdminRole(role) {
  return ["admin", "administrador", "supervisor", "super operador"].includes(
    normalizeText(role),
  );
}

export function isAdvisorRole(role) {
  return ["asesor", "fuerza de ventas", "operador", "super operador"].includes(
    normalizeText(role),
  );
}

export function roleLabel(role) {
  if (role === "admin") return "Administrador";
  if (role === "advisor") return "Asesor";
  return "Cliente";
}
