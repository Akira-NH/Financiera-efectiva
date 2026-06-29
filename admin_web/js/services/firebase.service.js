import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";
import {
  createUserWithEmailAndPassword,
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
  updateProfile,
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";
import {
  collection,
  doc,
  getDoc,
  getFirestore,
  onSnapshot,
  serverTimestamp,
  writeBatch,
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

import { firebaseConfig } from "../config/constants.js";
import { emailLooksAdmin, isAdminRole, isAdvisorRole } from "../models/role.model.js";
import { normalizeDemoClient, normalizeRequest } from "../models/request.model.js";
import { normalizeText } from "../utils/format.js";

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

export function listenAuth(callback) {
  return onAuthStateChanged(auth, callback);
}

export function login(email, password) {
  return signInWithEmailAndPassword(auth, email.trim().toLowerCase(), password);
}

export function logout() {
  return signOut(auth);
}

export async function registerClient({
  fullName,
  documentNumber,
  email,
  password,
}) {
  const credential = await createUserWithEmailAndPassword(
    auth,
    email.trim().toLowerCase(),
    password,
  );
  const user = credential.user;
  if (!user) return;

  await updateProfile(user, { displayName: fullName.trim() });
  const batch = writeBatch(db);
  batch.set(
    doc(db, "clients", user.uid),
    {
      fullName: fullName.trim(),
      documentType: "DNI",
      documentNumber: documentNumber.trim(),
      email: email.trim().toLowerCase(),
      totalBalance: 1000,
      savingsBalance: 1000,
      activeLoansBalance: 0,
      financialProfileSeeded: true,
      createdAt: serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();
}

export function sendClientPasswordReset(email) {
  auth.languageCode = "es";
  return sendPasswordResetEmail(auth, email.trim().toLowerCase());
}

export async function readDocument(collectionName, id) {
  try {
    const snapshot = await getDoc(doc(db, collectionName, id));
    return snapshot.exists() ? snapshot.data() : null;
  } catch (_) {
    return null;
  }
}

export async function detectRole(user) {
  const email = (user.email || "").toLowerCase();
  const salesProfile = await readDocument("sales_users", user.uid);
  const clientProfile = await readDocument("clients", user.uid);
  const rawRole = normalizeText(
    salesProfile?.role || salesProfile?.rol || clientProfile?.role || "",
  );
  const active = salesProfile?.active ?? salesProfile?.activo ?? true;

  if (isAdminRole(rawRole) || emailLooksAdmin(email)) {
    return { role: "admin", profile: salesProfile || clientProfile || {} };
  }
  if (isAdvisorRole(rawRole) && active) {
    return { role: "advisor", profile: salesProfile || {} };
  }
  if (rawRole === "cliente" || clientProfile || user.uid) {
    return { role: "client", profile: clientProfile || {} };
  }
  throw new Error("La cuenta no tiene un rol valido para la web.");
}

export function subscribeSalesData(handlers) {
  return [
    onSnapshot(
      collection(db, "sales_credit_requests"),
      (snapshot) => {
        handlers.onRequests(
          snapshot.docs.map((item) => normalizeRequest(item.id, item.data())),
        );
      },
      handlers.onError,
    ),
    onSnapshot(
      collection(db, "clientes_scoring_demo"),
      (snapshot) => {
        handlers.onDemoClients(
          snapshot.docs.map((item) => normalizeDemoClient(item.id, item.data())),
        );
      },
      handlers.onError,
    ),
    onSnapshot(
      collection(db, "sales_clients"),
      (snapshot) => {
        handlers.onSalesClients(
          snapshot.docs.map((item) => ({ id: item.id, ...item.data() })),
        );
      },
      handlers.onError,
    ),
  ];
}

export function subscribeClientData(uid, handlers) {
  return [
    onSnapshot(
      doc(db, "clients", uid),
      (snapshot) => handlers.onProfile(snapshot.exists() ? snapshot.data() : {}),
      handlers.onError,
    ),
    onSnapshot(
      collection(db, "clients", uid, "creditRequests"),
      (snapshot) => {
        handlers.onRequests(
          snapshot.docs.map((item) => normalizeRequest(item.id, item.data())),
        );
      },
      handlers.onError,
    ),
    onSnapshot(
      doc(db, "clients", uid, "credits", "activeLoan"),
      (snapshot) => handlers.onActiveLoan(snapshot.exists() ? snapshot.data() : null),
      () => handlers.onActiveLoan(null),
    ),
    onSnapshot(
      collection(db, "clients", uid, "installments"),
      (snapshot) => {
        handlers.onInstallments(
          snapshot.docs
            .map((item) => ({ id: item.id, ...item.data() }))
            .sort((a, b) => Number(a.number || 0) - Number(b.number || 0)),
        );
      },
      () => handlers.onInstallments([]),
    ),
  ];
}

export async function createClientCreditRequest({ user, profile, location, amount, termMonths, purpose }) {
  const uid = user.uid;
  const fullName = profile.fullName || profile.nombres || user.displayName || "Cliente";
  const documentNumber = profile.documentNumber || profile.dni || uid;
  const phone = profile.phone || profile.telefono || "";
  const email = profile.email || user.email || "";
  const requestRef = doc(collection(db, "clients", uid, "creditRequests"));
  const locationLabel = profile.location || profile.ubicacion || "";
  const amountLabel = `S/ ${amount.toFixed(2)}`;
  const batch = writeBatch(db);

  const common = {
    id: requestRef.id,
    clientId: uid,
    clientName: fullName,
    cliente: fullName,
    documentNumber,
    dni: documentNumber,
    email,
    correo: email,
    phone,
    telefono: phone,
    amount,
    amountLabel,
    monto: amountLabel,
    termMonths,
    plazo_meses: termMonths,
    purpose,
    destino_credito: purpose,
    latitud: location?.latitude ?? null,
    longitud: location?.longitude ?? null,
    ubicacion: locationLabel,
    status: "Preaprobado",
    estado: "Preaprobado",
    estado_solicitud: "Preaprobado",
    estado_cliente: "Visitar",
    clientStatus: "Visitar",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };

  batch.set(requestRef, common);
  batch.set(doc(db, "sales_credit_requests", requestRef.id), {
    ...common,
    segmento: "POR EVALUAR",
  });
  batch.set(
    doc(db, "sales_clients", String(documentNumber)),
    {
      dni: documentNumber,
      nombres: fullName,
      clientId: uid,
      requestId: requestRef.id,
      telefono: phone,
      phone,
      ubicacion: locationLabel,
      latitud: location?.latitude ?? null,
      longitud: location?.longitude ?? null,
      negocio: profile.businessName || "Por registrar",
      rubro: profile.businessType || "Por evaluar",
      calificacion_sbs: profile.sbsRating || "Por evaluar",
      score_preliminar: profile.preScore || 0,
      segmento: profile.segment || "POR EVALUAR",
      estado_cliente: "Visitar",
      estado_solicitud: "Preaprobado",
      updatedAt: serverTimestamp(),
    },
    { merge: true },
  );

  await batch.commit();
}

export async function updateClientStatus(row, status) {
  const normalized = status === "Visitado" ? "Visitado" : "Visitar";
  const payload = {
    estado_cliente: normalized,
    clientStatus: normalized,
    updatedAt: serverTimestamp(),
  };
  const batch = writeBatch(db);
  if (row.source === "demo") {
    batch.set(doc(db, "clientes_scoring_demo", row.clientId || row.id), payload, {
      merge: true,
    });
  } else {
    batch.set(doc(db, "sales_credit_requests", row.requestId), payload, {
      merge: true,
    });
    if (row.dni) batch.set(doc(db, "sales_clients", row.dni), payload, { merge: true });
  }
  await batch.commit();
}

export async function updateCreditDecision(row, decision) {
  if (row.statusGroup !== "pending") {
    throw new Error("Esta solicitud ya tiene una decision registrada.");
  }
  const normalized = decision === "Aceptado" ? "Aceptado" : "Negado";
  const payload = {
    estado_solicitud: normalized,
    estado: normalized,
    status: normalized,
    updatedAt: serverTimestamp(),
  };
  const batch = writeBatch(db);
  if (row.source === "demo") {
    batch.set(doc(db, "clientes_scoring_demo", row.clientId || row.id), payload, {
      merge: true,
    });
  } else {
    batch.set(doc(db, "sales_credit_requests", row.requestId), payload, {
      merge: true,
    });
    if (row.clientId && row.clientId !== row.requestId) {
      batch.set(
        doc(db, "clients", row.clientId, "creditRequests", row.requestId),
        payload,
        { merge: true },
      );
    }
    if (row.dni) batch.set(doc(db, "sales_clients", row.dni), payload, { merge: true });
  }
  await batch.commit();
}

export async function saveAdvisorFieldForm(row, payload) {
  const batch = writeBatch(db);
  const withMeta = {
    ...payload,
    estado_cliente: "Visitado",
    clientStatus: "Visitado",
    fieldVisitCompleted: true,
    solicitud_completada: true,
    updatedAt: serverTimestamp(),
  };

  if (row.source === "demo") {
    batch.set(doc(db, "clientes_scoring_demo", row.clientId || row.id), withMeta, {
      merge: true,
    });
  } else {
    batch.set(doc(db, "sales_credit_requests", row.requestId), withMeta, {
      merge: true,
    });
    if (row.clientId && row.clientId !== row.requestId) {
      batch.set(
        doc(db, "clients", row.clientId, "creditRequests", row.requestId),
        withMeta,
        { merge: true },
      );
    }
    batch.set(
      doc(db, "sales_clients", payload.dni),
      { ...withMeta, clientId: row.clientId, requestId: row.requestId },
      { merge: true },
    );
  }
  await batch.commit();
}
