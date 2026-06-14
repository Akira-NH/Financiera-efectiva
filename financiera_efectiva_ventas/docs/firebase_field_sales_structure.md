# Estructura Firebase sugerida para Fuerza de Ventas

Colecciones principales:

- `sales_clients`: cartera comercial visible para asesores.
- `sales_daily_portfolio`: asignaciones diarias por asesor, prioridad, tipo de gestion y estado de visita.
- `sales_route_visits`: puntos de visita con latitud, longitud, objetivo y estado.
- `sales_credit_requests`: solicitudes originadas en campo y seguimiento de estados.
- `sales_application_drafts`: borradores offline-first pendientes de envio.
- `sales_request_documents`: metadatos de documentos capturados y URLs de Firebase Storage.
- `sales_bureau_checks`: resultados de consulta de buro simulada o real asociados a solicitud.
- `sales_submission_progress`: avance de transmision electronica para reintentos.
- `sales_scoring_features`: variables usadas para evaluacion y reportes.

Campos minimos recomendados:

- Todas las colecciones: `createdAt`, `updatedAt`, `advisorId`, `syncStatus`.
- Solicitudes: `clientId`, `amount`, `termMonths`, `purpose`, `status`, `expedientNumber`.
- Documentos: `requestId`, `documentType`, `required`, `status`, `storageUrl`.
- Buro: `requestId`, `dni`, `rating`, `debtEntities`, `totalDebt`, `result`, `recommendation`.

Estados recomendados:

- Solicitud: `borrador`, `pendiente_envio`, `enviado`, `en_comite`, `aprobado`, `rechazado`, `desembolsado`.
- Documento: `PENDIENTE`, `OBLIGATORIO`, `LISTO`.
- Sync: `local`, `pending`, `synced`, `error`.
