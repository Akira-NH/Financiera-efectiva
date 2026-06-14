# Clientes scoring demo

La coleccion de pruebas se llama `clientes_scoring_demo` y contiene 100 clientes
ficticios con identificadores reproducibles:

- `CLI-DEMO-001` a `CLI-DEMO-100`.
- Distribucion aproximada: 40 riesgo bajo, 35 riesgo medio, 20 riesgo alto y
  5 rechazos automaticos.
- Cada documento incluye datos financieros, cuotas mensuales actuales, destino
  del credito, score, nivel de riesgo, estado de evaluacion, semaforo,
  recomendacion, capacidad de pago disponible, ratio de endeudamiento y desglose
  de puntos por variable.

## Ejecutar seed

El script no requiere paquetes de npm. Usa la API REST de Firestore y un token
de `gcloud`.

```powershell
cd financiera_efectiva_ventas
node scripts/seed_clientes_scoring_demo.js --clear
```

Opciones:

- `--clear`: elimina la coleccion antes de volver a crear los 100 registros.
- `--dry-run`: imprime los 100 documentos en JSON sin escribir en Firestore.
- `--project <id>`: permite usar otro proyecto Firebase.

Si no tienes `gcloud`, puedes pasar un token OAuth con:

```powershell
$env:FIRESTORE_TOKEN = "<token>"
node scripts/seed_clientes_scoring_demo.js --clear
```

## Scoring

El scoring vive como logica interna en
`lib/data/services/credit_scoring_service.dart`. La app de ventas solo muestra
el resultado: score, nivel de riesgo, semaforo y recomendacion. No hay pantalla
visible para modificar el scoring manualmente.

El modelo suma 100 puntos:

- Ingresos y capacidad de pago: 25 puntos.
- Historial de pago: 30 puntos.
- Endeudamiento y creditos activos: 20 puntos.
- Antiguedad laboral: 15 puntos.
- Buro/SBS: 10 puntos.

Rechaza automaticamente cuando detecta lista negra, SBS negativo activo,
fraude/suplantacion, capacidad de pago menor o igual a cero, ratio mayor a 90%
o mas de 90 dias de mora acumulada.
