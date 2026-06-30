export const firebaseConfig = {
  apiKey: "AIzaSyB-vz6POYQ1s1NcrgJZ01A8xucEu8vG56w",
  authDomain: "financiera-efectiva-movil.firebaseapp.com",
  projectId: "financiera-efectiva-movil",
  storageBucket: "financiera-efectiva-movil.firebasestorage.app",
  messagingSenderId: "333875197359",
  appId: "1:333875197359:web:2654582460492b37e32b5a",
};

export const creditPurposes = [
  "Capital de trabajo",
  "Compra de mercaderia",
  "Mejoramiento de vivienda",
  "Educacion",
  "Salud",
  "Pago de deudas",
  "Compra de activos o herramientas",
  "Negocio o emprendimiento",
  "Otros",
];

export const navConfig = {
  admin: [
    { id: "dashboard", label: "Dashboard", title: "Dashboard administrativo" },
    { id: "solicitudes", label: "Solicitudes", title: "Solicitudes del sistema" },
    { id: "clientes", label: "Clientes", title: "Clientes" },
    { id: "asesores", label: "Asesores", title: "Asesores" },
    { id: "seguimiento", label: "Seguimiento", title: "Seguimiento" },
  ],
  client: [
    { id: "inicio", label: "Inicio", title: "Resumen del cliente" },
    { id: "solicitudes", label: "Solicitudes", title: "Solicitudes de credito" },
    { id: "creditos", label: "Creditos", title: "Creditos" },
    { id: "perfil", label: "Perfil", title: "Perfil" },
  ],
  advisor: [
    { id: "cartera", label: "Cartera", title: "Cartera" },
    { id: "ruta", label: "Ruta", title: "Ruta" },
    { id: "solicitud", label: "Solicitud", title: "Solicitud" },
    { id: "cliente", label: "Cliente", title: "Ficha del cliente" },
  ],
};

export const defaultPage = {
  admin: "dashboard",
  client: "inicio",
  advisor: "cartera",
};
