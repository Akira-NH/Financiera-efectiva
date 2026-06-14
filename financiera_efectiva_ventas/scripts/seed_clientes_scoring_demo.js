#!/usr/bin/env node
/* eslint-disable no-console */

const https = require('https');
const { execFileSync } = require('child_process');
const { createSign } = require('crypto');
const { readFileSync } = require('fs');

const collection = 'clientes_scoring_demo';
const projectId = argValue('--project') || 'financiera-efectiva-movil';
const clearFirst = process.argv.includes('--clear');
const dryRun = process.argv.includes('--dry-run');
const database = '(default)';
const serviceAccountPath =
  argValue('--service-account') || process.env.GOOGLE_APPLICATION_CREDENTIALS;

const destinos = [
  'Capital de trabajo',
  'Compra de mercaderia',
  'Mejoramiento de vivienda',
  'Educacion',
  'Salud',
  'Pago de deudas',
  'Compra de activos o herramientas',
  'Negocio o emprendimiento',
  'Otros',
];
const nombres = ['Maria', 'Jose', 'Rosa', 'Luis', 'Carmen', 'Jorge', 'Ana', 'Miguel', 'Lucia', 'Carlos'];
const apellidos = [
  'Quispe Ramos',
  'Huaman Flores',
  'Medina Soto',
  'Torres Vega',
  'Castillo Rojas',
  'Paredes Nunez',
  'Salazar Cueva',
  'Mendoza Leon',
  'Vargas Silva',
  'Chavez Molina',
];
const ocupaciones = [
  'Comerciante',
  'Transportista',
  'Costurera',
  'Tecnico electricista',
  'Docente',
  'Vendedor mayorista',
  'Restaurante familiar',
  'Agricultor',
  'Ferretero',
  'Emprendedora digital',
];

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function scenario(index) {
  if (index <= 40) return 'bajo';
  if (index <= 75) return 'medio';
  if (index <= 95) return 'alto';
  return 'rechazo';
}

function buildClient(index) {
  const kind = scenario(index);
  const destino = destinos[(index - 1) % destinos.length];
  const baseIncome = kind === 'bajo' ? 5200 : kind === 'medio' ? 3800 : 1500;
  const ingresos = baseIncome + ((index * 137) % 1700);
  const gastos = Math.round(ingresos * (kind === 'bajo' ? 0.42 : kind === 'medio' ? 0.5 : 0.68));
  const cuotas = Math.round(ingresos * (kind === 'bajo' ? 0.06 : kind === 'medio' ? 0.1 : 0.26));
  const deuda = Math.round(ingresos * (kind === 'bajo' ? 0.16 : kind === 'medio' ? 0.22 : 0.55));
  const mora = kind === 'bajo' ? index % 3 : kind === 'medio' ? 1 + (index % 12) : kind === 'alto' ? 18 + (index % 55) : 92 + (index % 8);
  const listaNegra = kind === 'rechazo' && index % 2 === 0;
  const sbs = kind === 'rechazo' && index % 2 !== 0;
  const fraude = kind === 'rechazo' && index === 99;
  const puntualidad = kind === 'bajo' ? 96 + (index % 4) : kind === 'medio' ? 86 + (index % 8) : 42 + (index % 28);
  const client = {
    id_cliente: `CLI-DEMO-${String(index).padStart(3, '0')}`,
    dni: String(71000000 + index),
    nombres: nombres[(index - 1) % nombres.length],
    apellidos: apellidos[(index - 1) % apellidos.length],
    edad: 23 + (index % 38),
    ocupacion: ocupaciones[(index - 1) % ocupaciones.length],
    ingresos_mensuales: ingresos,
    gastos_mensuales: gastos,
    cuotas_mensuales_actuales: cuotas,
    deuda_actual: deuda,
    numero_creditos_activos: kind === 'bajo' ? index % 2 : kind === 'medio' ? 2 : 4 + (index % 3),
    historial_pagos: index % 11 === 0 ? 'sin historial' : kind === 'bajo' ? 'excelente' : kind === 'medio' ? 'regular' : 'deficiente',
    dias_mora: mora,
    puntualidad_pago: puntualidad,
    tiene_deuda_vencida: kind === 'alto' || kind === 'rechazo',
    reportado_sbs: sbs,
    en_lista_negra: listaNegra,
    evidencia_fraude: fraude,
    monto_solicitado: kind === 'bajo' ? 8000 + index * 120 : kind === 'medio' ? 10000 + index * 90 : 6000 + index * 70,
    plazo_meses: [6, 9, 12, 18, 24][index % 5],
    destino_credito: destino,
    destino_credito_otro: destino === 'Otros' ? 'Financiamiento especifico de temporada' : '',
    antiguedad_laboral_meses: kind === 'bajo' ? 62 + (index % 36) : kind === 'medio' ? 18 + (index % 34) : 3 + (index % 20),
  };
  return { ...client, ...evaluate(client) };
}

function evaluate(client) {
  const capacidad = client.ingresos_mensuales - client.gastos_mensuales - client.cuotas_mensuales_actuales;
  const ratio = ((client.cuotas_mensuales_actuales + client.deuda_actual) / Math.max(client.ingresos_mensuales, 1)) * 100;
  const detalle = {
    score_ingresos: monthlyIncomeScore(client.ingresos_mensuales),
    score_capacidad_pago: paymentCapacityScore(capacidad),
    score_dias_mora: lateDaysScore(client.dias_mora),
    score_puntualidad: punctualityScore(client.puntualidad_pago),
    score_ratio_endeudamiento: debtRatioScore(ratio),
    score_creditos_activos: activeCreditsScore(client.numero_creditos_activos),
    score_antiguedad_laboral: seniorityScore(client.antiguedad_laboral_meses),
    score_buro_sbs: bureauScore(client),
  };
  const score = Object.values(detalle).reduce((sum, value) => sum + value, 0);
  const rejection = automaticRejection(client, capacidad, ratio);
  const decision = rejection
    ? result(score, 'Rechazo automatico', 'Rechazado', `Rechazar: ${rejection}`, true, rejection)
    : score >= 80
      ? result(score, 'Bajo', 'Aprobado', 'Credito aprobado automaticamente.', false, '')
      : score >= 60
        ? result(score, 'Medio', 'Revision manual', 'Revision manual del asesor.', false, '')
        : result(score, 'Alto', 'Rechazado', 'Credito rechazado por riesgo alto.', false, '');
  return {
    ...decision,
    ...detalle,
    capacidad_pago_disponible: capacidad,
    ratio_endeudamiento: Number(ratio.toFixed(2)),
  };
}

function automaticRejection(client, capacidad, ratio) {
  if (client.en_lista_negra) return 'cliente en lista negra';
  if (client.reportado_sbs) return 'reporte SBS negativo activo';
  if (client.evidencia_fraude) return 'evidencia de fraude o suplantacion';
  if (capacidad <= 0) return 'capacidad de pago menor o igual a cero';
  if (ratio > 90) return 'ratio de endeudamiento superior al 90%';
  if (client.dias_mora > 90) return 'mas de 90 dias de mora acumulada';
  return '';
}

function result(score, nivel, estado, recommendation, autoReject, reason) {
  return {
    score,
    nivel_riesgo: nivel,
    estado_evaluacion: estado,
    semaforo_riesgo: nivel === 'Bajo' ? 'Verde' : nivel === 'Medio' ? 'Amarillo' : 'Rojo',
    recomendacion_scoring: recommendation,
    rechazo_automatico: autoReject,
    motivo_rechazo: reason,
  };
}

function monthlyIncomeScore(income) {
  if (income >= 5000) return 15;
  if (income >= 3500) return 12;
  if (income >= 2000) return 8;
  if (income >= 1200) return 4;
  return 0;
}

function paymentCapacityScore(capacity) {
  if (capacity >= 2000) return 10;
  if (capacity >= 1000) return 8;
  if (capacity >= 500) return 5;
  if (capacity >= 1) return 2;
  return 0;
}

function lateDaysScore(days) {
  if (days === 0) return 15;
  if (days <= 7) return 10;
  if (days <= 30) return 5;
  return 0;
}

function punctualityScore(punctuality) {
  if (punctuality >= 95) return 15;
  if (punctuality >= 85) return 12;
  if (punctuality >= 70) return 6;
  return 0;
}

function debtRatioScore(ratio) {
  if (ratio <= 30) return 15;
  if (ratio <= 50) return 10;
  if (ratio <= 70) return 5;
  return 0;
}

function activeCreditsScore(activeCredits) {
  if (activeCredits <= 1) return 5;
  if (activeCredits <= 3) return 3;
  if (activeCredits <= 5) return 1;
  return 0;
}

function seniorityScore(months) {
  if (months > 60) return 15;
  if (months >= 36) return 12;
  if (months >= 12) return 8;
  if (months >= 6) return 4;
  return 0;
}

function bureauScore(client) {
  if (client.en_lista_negra || client.evidencia_fraude || client.reportado_sbs) return 0;
  if (client.tiene_deuda_vencida) return 3;
  if (client.dias_mora > 0) return 7;
  return 10;
}

function firestoreValue(value) {
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  return { stringValue: String(value ?? '') };
}

function documentFields(client) {
  return Object.fromEntries(Object.entries(client).map(([key, value]) => [key, firestoreValue(value)]));
}

async function token() {
  if (process.env.FIRESTORE_TOKEN) return process.env.FIRESTORE_TOKEN;
  if (serviceAccountPath) return serviceAccountToken(serviceAccountPath);
  try {
    return execFileSync('gcloud', ['auth', 'application-default', 'print-access-token'], { encoding: 'utf8' }).trim();
  } catch (_) {
    return execFileSync('gcloud', ['auth', 'print-access-token'], { encoding: 'utf8' }).trim();
  }
}

async function serviceAccountToken(filePath) {
  const account = JSON.parse(readFileSync(filePath, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlUtf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64UrlUtf8(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsignedJwt = `${header}.${claim}`;
  const signature = createSign('RSA-SHA256')
    .update(unsignedJwt)
    .sign(account.private_key, 'base64');
  const assertion = `${unsignedJwt}.${base64UrlBase64(signature)}`;
  const response = await postForm('/token', {
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  return response.access_token;
}

function base64UrlUtf8(value) {
  return Buffer.from(value, 'utf8')
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function base64UrlBase64(value) {
  return Buffer.from(value, 'base64')
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

function postForm(path, form) {
  return new Promise((resolve, reject) => {
    const body = new URLSearchParams(form).toString();
    const req = https.request({
      method: 'POST',
      hostname: 'oauth2.googleapis.com',
      path,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`OAuth token error ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function request(method, path, accessToken, body) {
  return new Promise((resolve, reject) => {
    const req = https.request({
      method,
      hostname: 'firestore.googleapis.com',
      path,
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(data ? JSON.parse(data) : {});
        } else {
          reject(new Error(`${method} ${path} -> ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function clearCollection(accessToken) {
  const base = `/v1/projects/${projectId}/databases/${database}/documents/${collection}`;
  const listed = await request('GET', `${base}?pageSize=300`, accessToken);
  const documents = listed.documents || [];
  for (const doc of documents) {
    await request('DELETE', `/v1/${doc.name}`, accessToken);
  }
  console.log(`Eliminados ${documents.length} documentos de ${collection}.`);
}

async function seed() {
  const clients = Array.from({ length: 100 }, (_, index) => buildClient(index + 1));
  if (dryRun) {
    console.log(JSON.stringify(clients, null, 2));
    return;
  }
  const accessToken = await token();
  if (clearFirst) await clearCollection(accessToken);
  const writes = clients.map(client => ({
    update: {
      name: `projects/${projectId}/databases/${database}/documents/${collection}/${client.id_cliente}`,
      fields: documentFields(client),
    },
  }));
  await request('POST', `/v1/projects/${projectId}/databases/${database}/documents:commit`, accessToken, { writes });
  console.log(`Insertados/actualizados ${clients.length} clientes en ${collection}.`);
}

seed().catch(error => {
  console.error(error.message);
  process.exit(1);
});
