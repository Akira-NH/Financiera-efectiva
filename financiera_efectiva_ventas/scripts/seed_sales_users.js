#!/usr/bin/env node
/* eslint-disable no-console */

const https = require('https');
const { execFileSync } = require('child_process');
const { createSign } = require('crypto');
const { readFileSync } = require('fs');

const projectId = argValue('--project') || 'financiera-efectiva-movil';
const database = '(default)';
const serviceAccountPath =
  argValue('--service-account') || process.env.GOOGLE_APPLICATION_CREDENTIALS;

const advisor = {
  uid: 'IQcYbtTbfvVjvVCG59qEPd5xURu1',
  email: 'asesor.demo@efectiva.pe',
  name: 'Asesor Demo',
  role: 'asesor',
  active: true,
};

function argValue(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

function firestoreValue(value) {
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Number.isInteger(value)) return { integerValue: String(value) };
  if (typeof value === 'number') return { doubleValue: value };
  return { stringValue: String(value ?? '') };
}

function documentFields(data) {
  return Object.fromEntries(
    Object.entries(data)
      .filter(([key]) => key !== 'uid')
      .map(([key, value]) => [key, firestoreValue(value)]),
  );
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

async function seed() {
  const accessToken = await token();
  const documentName =
    `projects/${projectId}/databases/${database}/documents/sales_users/${advisor.uid}`;
  await request(
    'POST',
    `/v1/projects/${projectId}/databases/${database}/documents:commit`,
    accessToken,
    {
      writes: [
        {
          update: {
            name: documentName,
            fields: documentFields(advisor),
          },
        },
      ],
    },
  );
  console.log(`Asesor creado/actualizado en sales_users/${advisor.uid}`);
}

seed().catch(error => {
  console.error(error.message);
  process.exit(1);
});
