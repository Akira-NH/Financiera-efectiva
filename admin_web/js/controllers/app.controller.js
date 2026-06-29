import { defaultPage, navConfig } from "../config/constants.js";
import { buildRows } from "../models/request.model.js";
import { roleLabel } from "../models/role.model.js";
import {
  createClientCreditRequest,
  detectRole,
  listenAuth,
  login,
  logout,
  registerClient,
  saveAdvisorFieldForm,
  sendClientPasswordReset,
  subscribeClientData,
  subscribeSalesData,
  updateClientStatus,
  updateCreditDecision,
} from "../services/firebase.service.js";
import { cleanupListeners, clearSessionData, state } from "../state/store.js";
import { asNumber, formatInputDate, toMillis } from "../utils/format.js";
import {
  renderAdminPage,
  renderAdvisorPage,
  renderClientPage,
} from "../views/page.view.js";

export function initApp() {
  bindAuthEvents();
  window.addEventListener("hashchange", render);
  listenAuth(handleAuthChanged);
  renderAuthRoute();
}

function elements() {
  return {
    loginView: document.querySelector("#loginView"),
    shellView: document.querySelector("#shellView"),
    loginForm: document.querySelector("#loginForm"),
    registerForm: document.querySelector("#registerForm"),
    resetForm: document.querySelector("#resetForm"),
    loginError: document.querySelector("#loginError"),
    registerError: document.querySelector("#registerError"),
    resetMessage: document.querySelector("#resetMessage"),
    emailInput: document.querySelector("#emailInput"),
    passwordInput: document.querySelector("#passwordInput"),
    registerNameInput: document.querySelector("#registerNameInput"),
    registerDocumentInput: document.querySelector("#registerDocumentInput"),
    registerEmailInput: document.querySelector("#registerEmailInput"),
    registerPasswordInput: document.querySelector("#registerPasswordInput"),
    resetEmailInput: document.querySelector("#resetEmailInput"),
    roleEyebrow: document.querySelector("#roleEyebrow"),
    pageTitle: document.querySelector("#pageTitle"),
    userLabel: document.querySelector("#userLabel"),
    logoutButton: document.querySelector("#logoutButton"),
    loadingState: document.querySelector("#loadingState"),
    errorState: document.querySelector("#errorState"),
    viewRoot: document.querySelector("#viewRoot"),
  };
}

function bindAuthEvents() {
  const els = elements();
  document.querySelectorAll("[data-auth-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      const mode = button.dataset.authMode || "login";
      if (window.location.hash !== `#/auth/${mode}`) {
        window.location.hash = `#/auth/${mode}`;
      } else {
        setAuthMode(mode);
      }
    });
  });
  els.loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    els.loginError.textContent = "";
    try {
      await login(els.emailInput.value, els.passwordInput.value);
    } catch (error) {
      els.loginError.textContent = authMessage(error);
    }
  });
  els.registerForm.addEventListener("submit", submitRegisterForm);
  els.resetForm.addEventListener("submit", submitResetForm);
  els.logoutButton.addEventListener("click", () => logout());
}

function setAuthMode(mode) {
  const els = elements();
  const target = ["login", "register", "reset"].includes(mode) ? mode : "login";
  els.loginForm.classList.toggle("hidden", target !== "login");
  els.registerForm.classList.toggle("hidden", target !== "register");
  els.resetForm.classList.toggle("hidden", target !== "reset");
  els.loginError.textContent = "";
  els.registerError.textContent = "";
  els.resetMessage.textContent = "";
}

async function submitRegisterForm(event) {
  event.preventDefault();
  const els = elements();
  els.registerError.textContent = "";
  const fullName = els.registerNameInput.value.trim();
  const documentNumber = els.registerDocumentInput.value.trim();
  const email = els.registerEmailInput.value.trim().toLowerCase();
  const password = els.registerPasswordInput.value;

  if (!fullName) {
    els.registerError.textContent = "Ingresa tu nombre completo.";
    return;
  }
  if (!/^\d{8}$/.test(documentNumber)) {
    els.registerError.textContent = "El DNI debe tener exactamente 8 digitos.";
    return;
  }
  if (!email.includes("@")) {
    els.registerError.textContent = "Ingresa un correo valido.";
    return;
  }
  if (password.length < 6) {
    els.registerError.textContent = "La contraseña debe tener al menos 6 caracteres.";
    return;
  }

  try {
    await registerClient({ fullName, documentNumber, email, password });
  } catch (error) {
    els.registerError.textContent = authMessage(error);
  }
}

async function submitResetForm(event) {
  event.preventDefault();
  const els = elements();
  els.resetMessage.textContent = "";
  const email = els.resetEmailInput.value.trim().toLowerCase();
  if (!email.includes("@")) {
    els.resetMessage.textContent = "Ingresa un correo valido.";
    return;
  }

  try {
    await sendClientPasswordReset(email);
    els.resetMessage.textContent =
      "Si el correo esta registrado, Firebase enviara el enlace. Revisa Spam o Promociones.";
  } catch (error) {
    els.resetMessage.textContent = authMessage(error);
  }
}

async function handleAuthChanged(user) {
  cleanupListeners();
  state.user = user;
  state.role = "";
  state.roleProfile = null;
  clearSessionData();

  if (!user) {
    showLogin();
    renderAuthRoute();
    return;
  }

  showShell();
  setLoading(true);
  try {
    const access = await detectRole(user);
    state.role = access.role;
    state.roleProfile = access.profile;
    routeToRole();
    startRoleListeners();
  } catch (error) {
    state.error = error?.message || "No se pudo validar el acceso.";
    setLoading(false);
    render();
  }
}

function startRoleListeners() {
  setLoading(true);
  if (state.role === "client") {
    state.unsubscribers = subscribeClientData(state.user.uid, {
      onProfile: (profile) => {
        state.clientProfile = profile;
        setLoading(false);
        render();
      },
      onRequests: (requests) => {
        state.clientRequests = requests;
        render();
      },
      onActiveLoan: (loan) => {
        state.activeLoan = loan;
        render();
      },
      onInstallments: (installments) => {
        state.installments = installments;
        render();
      },
      onError: handleSnapshotError,
    });
    return;
  }

  state.unsubscribers = subscribeSalesData({
    onRequests: (requests) => {
      state.requests = requests;
      setLoading(false);
      render();
    },
    onDemoClients: (clients) => {
      state.demoClients = clients;
      render();
    },
    onSalesClients: (clients) => {
      state.salesClients = clients;
      render();
    },
    onError: handleSnapshotError,
  });
}

function handleSnapshotError(error) {
  state.error =
    error?.code === "permission-denied"
      ? "Firestore denego la operacion. Revisa que la cuenta tenga permisos para su rol."
      : error?.message || "No se pudieron cargar los datos.";
  setLoading(false);
  render();
}

function render() {
  if (!state.user) {
    showLogin();
    renderAuthRoute();
    return;
  }
  const route = routeFromHash();
  if (state.role && route.role !== state.role) {
    routeToRole();
    return;
  }
  if (window.location.hash !== `#/${state.role}/${route.page}`) {
    routeToRole(route.page);
    return;
  }

  showShell();
  renderHeader(route.page);
  const els = elements();
  els.loadingState.classList.toggle("hidden", !state.loading);
  els.errorState.classList.toggle("hidden", !state.error);
  els.errorState.textContent = state.error;
  els.viewRoot.classList.toggle("hidden", state.loading || !!state.error);
  if (state.loading || state.error) return;

  const rows = buildRows({
    requests: state.requests,
    demoClients: state.demoClients,
    salesClients: state.salesClients,
  });
  const filtered = filterRows(rows);
  ensureSelection(filtered);
  const selected = rows.find((row) => row.key === state.selectedKey) || null;

  if (state.role === "admin") {
    els.viewRoot.innerHTML = renderAdminPage({
      page: route.page,
      rows,
      filtered,
      selected,
      filters: state.filters,
      actionMessage: state.actionMessage,
    });
  }
  if (state.role === "client") {
    els.viewRoot.innerHTML = renderClientPage({
      page: route.page,
      state,
      requests: sortedClientRequests(),
    });
  }
  if (state.role === "advisor") {
    els.viewRoot.innerHTML = renderAdvisorPage({
      page: route.page,
      rows,
      filtered,
      selected,
      filters: state.filters,
      actionMessage: state.actionMessage,
    });
  }
  bindPageEvents(route.page, rows);
}

function bindPageEvents(page, rows) {
  document.querySelectorAll("[data-filter]").forEach((input) => {
    input.addEventListener("input", updateFilter);
    input.addEventListener("change", updateFilter);
  });
  document.querySelectorAll("[data-key]").forEach((row) => {
    row.addEventListener("click", () => {
      state.selectedKey = row.dataset.key;
      render();
    });
  });
  document.querySelectorAll("[data-refresh]").forEach((button) => {
    button.addEventListener("click", render);
  });
  document.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", () => handleAdvisorAction(button));
  });
  document.querySelectorAll("[data-select-request]").forEach((button) => {
    button.addEventListener("click", () => {
      state.selectedKey = button.dataset.selectRequest;
      render();
    });
  });
  bindClientRequestForm();
  bindAdvisorFieldForm(rows);
}

function bindClientRequestForm() {
  const form = document.querySelector("#clientRequestForm");
  if (!form) return;
  const purpose = form.elements.purpose;
  const otherBox = form.querySelector("[data-other-purpose]");
  purpose.addEventListener("change", () => {
    otherBox.classList.toggle("hidden", purpose.value !== "Otros");
  });
  form.querySelector("[data-location]").addEventListener("click", requestLocation);
  form.addEventListener("submit", submitClientRequest);
}

function bindAdvisorFieldForm(rows) {
  const form = document.querySelector("#advisorFieldForm");
  if (!form) return;
  const row = rows.find((item) => item.key === state.selectedKey);
  if (!row) return;
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    try {
      await saveAdvisorFieldForm(row, buildAdvisorPayload(new FormData(form)));
      state.actionMessage = "Ficha guardada y sincronizada.";
    } catch (error) {
      state.actionMessage = error?.message || "No se pudo guardar la ficha.";
    }
    render();
  });
}

async function handleAdvisorAction(button) {
  const rows = buildRows({
    requests: state.requests,
    demoClients: state.demoClients,
    salesClients: state.salesClients,
  });
  const row = rows.find((item) => item.key === state.selectedKey);
  if (!row) return;
  const action = button.dataset.action;
  state.actionMessage = "Guardando cambio...";
  render();
  try {
    if (action === "visit") {
      await updateClientStatus(row, "Visitado");
      state.actionMessage = "Cliente marcado como visitado.";
    }
    if (action === "accept") {
      await updateCreditDecision(row, "Aceptado");
      state.actionMessage = "Solicitud aceptada correctamente.";
    }
    if (action === "reject") {
      await updateCreditDecision(row, "Negado");
      state.actionMessage = "Solicitud negada correctamente.";
    }
  } catch (error) {
    state.actionMessage = error?.message || "No se pudo guardar el cambio.";
  }
  render();
}

function updateFilter(event) {
  const key = event.currentTarget.dataset.filter;
  const value = event.currentTarget.value.trim();
  state.filters[key] =
    key === "search" || key === "advisor" ? value.toLowerCase() : value;
  render();
}

function requestLocation() {
  if (!navigator.geolocation) {
    state.actionMessage = "El navegador no permite obtener ubicacion.";
    render();
    return;
  }
  navigator.geolocation.getCurrentPosition(
    (position) => {
      state.clientLocation = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      };
      state.actionMessage = "Ubicacion registrada para la solicitud.";
      render();
    },
    () => {
      state.actionMessage = "No se pudo obtener la ubicacion.";
      render();
    },
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 },
  );
}

async function submitClientRequest(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const amount = asNumber(form.elements.amount.value);
  const termMonths = Math.round(asNumber(form.elements.term.value));
  const purposeValue = form.elements.purpose.value;
  const cleanPurpose =
    purposeValue === "Otros"
      ? form.elements.otherPurpose.value.trim()
      : purposeValue.trim();

  if (amount <= 0) {
    state.actionMessage = "El monto debe ser mayor a cero.";
    render();
    return;
  }
  if (termMonths <= 0) {
    state.actionMessage = "El plazo debe ser mayor a cero.";
    render();
    return;
  }
  if (!cleanPurpose) {
    state.actionMessage = "Selecciona o especifica el destino del credito.";
    render();
    return;
  }

  try {
    await createClientCreditRequest({
      user: state.user,
      profile: state.clientProfile || {},
      location: state.clientLocation,
      amount,
      termMonths,
      purpose: cleanPurpose,
    });
    state.actionMessage = "Solicitud enviada al flujo de fuerza de ventas.";
    state.clientLocation = null;
  } catch (error) {
    state.actionMessage = error?.message || "No se pudo enviar la solicitud.";
  }
  render();
}

function buildAdvisorPayload(formData) {
  const clientName = String(formData.get("clientName") || "").trim();
  const dni = String(formData.get("dni") || "").trim();
  if (!clientName || !dni) throw new Error("Nombre y DNI son obligatorios.");
  const amount = asNumber(formData.get("amount"));
  const termMonths = Math.round(asNumber(formData.get("termMonths")));
  const purpose = String(formData.get("purpose") || "").trim();
  return {
    cliente: clientName,
    clientName,
    dni,
    documentNumber: dni,
    telefono: String(formData.get("phone") || "").trim(),
    phone: String(formData.get("phone") || "").trim(),
    negocio: String(formData.get("businessName") || "").trim(),
    businessName: String(formData.get("businessName") || "").trim(),
    rubro: String(formData.get("businessType") || "").trim(),
    businessType: String(formData.get("businessType") || "").trim(),
    ubicacion: String(formData.get("locationLabel") || "").trim(),
    businessAddress: String(formData.get("locationLabel") || "").trim(),
    monthlyIncome: asNumber(formData.get("monthlyIncome")),
    monthlyExpenses: asNumber(formData.get("monthlyExpenses")),
    ingresos_mensuales: asNumber(formData.get("monthlyIncome")),
    gastos_mensuales: asNumber(formData.get("monthlyExpenses")),
    amount,
    monto: amount > 0 ? `S/ ${amount.toFixed(2)}` : "",
    termMonths,
    plazo_meses: termMonths,
    purpose,
    destino_credito: purpose,
  };
}

function filterRows(rows) {
  return rows.filter((row) => {
    const haystack = [
      row.clientName,
      row.dni,
      row.phone,
      row.purpose,
      row.locationLabel,
    ]
      .join(" ")
      .toLowerCase();
    const dateText = formatInputDate(row.updatedAt || row.createdAt);
    const textMatch = !state.filters.search || haystack.includes(state.filters.search);
    const statusMatch =
      state.filters.status === "all" || row.statusGroup === state.filters.status;
    const visitMatch =
      state.filters.visit === "all" || row.visitStatus === state.filters.visit;
    const sourceMatch =
      state.filters.source === "all" || row.source === state.filters.source;
    const advisorMatch =
      !state.filters.advisor ||
      row.advisor.toLowerCase().includes(state.filters.advisor);
    const dateMatch = !state.filters.date || dateText === state.filters.date;
    return textMatch && statusMatch && visitMatch && sourceMatch && advisorMatch && dateMatch;
  });
}

function ensureSelection(rows) {
  if (!state.selectedKey && rows.length > 0) state.selectedKey = rows[0].key;
  if (!rows.some((row) => row.key === state.selectedKey)) {
    state.selectedKey = rows[0]?.key || null;
  }
}

function sortedClientRequests() {
  return [...state.clientRequests].sort(
    (a, b) =>
      toMillis(b.updatedAt || b.createdAt) - toMillis(a.updatedAt || a.createdAt),
  );
}

function routeToRole(page = defaultPage[state.role]) {
  const expected = `#/${state.role}/${page}`;
  if (window.location.hash !== expected) window.location.hash = expected;
}

function routeFromHash() {
  const [role, page] = window.location.hash.replace("#/", "").split("/");
  if (!navConfig[role]) return { role: state.role, page: defaultPage[state.role] };
  const validPage = navConfig[role].some((item) => item.id === page)
    ? page
    : defaultPage[role];
  return { role, page: validPage };
}

function authModeFromHash() {
  const [section, mode] = window.location.hash.replace("#/", "").split("/");
  if (section !== "auth") return "login";
  return ["login", "register", "reset"].includes(mode) ? mode : "login";
}

function renderAuthRoute() {
  setAuthMode(authModeFromHash());
}

function renderHeader(page) {
  const labels = {
    admin: ["Panel administrador", "Supervision general del sistema"],
    client: ["Portal cliente", "Mis productos financieros"],
    advisor: ["Fuerza de ventas", "Gestion de cartera y solicitudes"],
  };
  const els = elements();
  const [eyebrow, title] = labels[state.role] || labels.client;
  const pageTitle = navConfig[state.role]?.find((item) => item.id === page)?.title;
  els.roleEyebrow.textContent = eyebrow;
  els.pageTitle.textContent = pageTitle || title;
  els.userLabel.textContent = `${state.user.email || "Sesion activa"} - ${roleLabel(state.role)}`;
}

function showLogin() {
  const els = elements();
  els.loginView.classList.remove("hidden");
  els.shellView.classList.add("hidden");
  els.viewRoot.innerHTML = "";
  if (!window.location.hash || !window.location.hash.startsWith("#/auth/")) {
    window.location.hash = "#/auth/login";
  }
}

function showShell() {
  const els = elements();
  els.loginView.classList.add("hidden");
  els.shellView.classList.remove("hidden");
}

function setLoading(value) {
  state.loading = value;
  elements().loadingState.classList.toggle("hidden", !value);
}

function authMessage(error) {
  if (error?.code === "auth/email-already-in-use") {
    return "Ya existe una cuenta con ese correo.";
  }
  if (error?.code === "auth/invalid-email") {
    return "El correo no tiene un formato valido.";
  }
  if (error?.code === "auth/weak-password") {
    return "La contraseña es demasiado debil.";
  }
  if (error?.code === "auth/invalid-credential") {
    return "Correo o contraseña incorrectos.";
  }
  if (error?.code === "auth/too-many-requests") {
    return "Demasiados intentos. Espera un momento y vuelve a probar.";
  }
  if (error?.code === "auth/network-request-failed") {
    return "Revisa tu conexion a internet.";
  }
  return error?.message || "No se pudo iniciar sesion.";
}
