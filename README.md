# tarea2-sisger — Pipeline Bronze/Silver con separacion de capas corregida

Proyecto Azure Data Factory (ARM export) del DW de transporte con arquitectura
medallion:

```
datos_csv/*.csv ─────┐
datos_xls/*.xlsx ────┼──> bronze.* (crudo, todo string) ──> silver.* (estandar, tipada) ──> Tableau
ERP Azure SQL ───────┘
```

## El problema grave que tenia

El proyecto centralizaba TODA la logica en la capa bronze: los dataflows
`df_bronze_*` no solo normalizaban los datos a columnas legibles para la base
de datos, sino que aplicaban las reglas de estandarizacion de la compania
(derivacion de ids historicos, generacion de claves, composicion de fechas,
limpieza de texto). La capa silver quedaba reducida a un casteo de tipos,
cuando deberia ser la duena de esas reglas. Eso rompe el sistema de trabajo:
bronze deja de ser una zona cruda auditable y cualquier cambio de reglas
obliga a re-ingerir desde las fuentes.

## Como se corrigio

### Capa bronze (df_bronze_*) — solo normalizacion inicial a columnas

Cada dataflow bronze ahora hace UNICAMENTE:

1. Lee las 4 fuentes (CSV 2020-2021, XLS 2022, XLS 2023, ERP SQL 2024-2025).
2. Renombra las columnas crudas a los nombres del ERP (ej. `cod_ruta` ->
   `RutaHistoricaId`, `nro_bus` -> `VehiculoId`, `pasajeros_estimados` /
   `pasajeros_reportados` -> `ValidacionesTarjeta`).
3. Agrega el metadato `AnioFuente` (literal 2022/2023 en XLS; extraido del
   propio campo fecha o del id en CSV, sin modificar el dato).
4. Une las ramas y escribe en `bronze.*`, donde toda columna es nvarchar:
   entra cualquier valor, sucio o no.

Bronze YA NO: recorta/espacia (trim/upper), parsea fechas, deriva ids
historicos, genera claves, ni filtra filas. En `bronze.Viajes` se ven los
codigos crudos (`05`, `Ruta 29`, `015`), duplicados y la fila basura
`TOTAL_OPERACION`: es el system of record.

Unica excepcion estructural: `df_bronze_incidente_ruta` expande la lista cruda
`rutas_afectadas` (`RH-05|RH-04`) a filas (conversion a estructura legible) y
guarda en `EsPrincipal` la posicion cruda en la lista (`'1'` = primer
elemento). La decision de negocio (primera ruta = principal, tipo bit) la
materializa silver.

### Capa silver (df_silver_*) — estandar segun normas de la compania

Cada dataflow silver lee su tabla `bronze.*` y aplica TODAS las reglas:

1. **Ids historicos de ruta** (rutas, viajes, demanda, incidente_ruta):
   `05` / `R-05` / `Ruta 5` -> `RH-05`; `07` -> `RH-07-OLD`; `12` ->
   `RH-12-OLD`; `R12-N`/`R12-S` -> `RH-12-N`/`RH-12-S`. Ids ya `RH-*` (ERP)
   se respetan.
2. **Ids de vehiculo** (vehiculos, viajes, incidentes): `015` -> `V-015`;
   ids `V-###` (ERP) se respetan; vacio queda NULL (incidente sin vehiculo).
3. **Claves generadas**: `ViajeId = VJ-<anio>-<5 digitos>` solo si el id es
   crudo; `DemandaId = DM-<anio>-<correlativo>` con `keyGenerate` para las
   filas de CSV/XLS que no traen id (las del ERP se respetan).
4. **Fechas multi-formato**: serial Excel (`44771` -> `1899-12-30 + n`),
   `dd/MM/yyyy` si hay `/`, si no `yyyy-MM-dd`. En incidentes compone los
   timestamps desde el par crudo `fecha hora` que entrega bronze.
5. **Horas**: `HH:mm` -> `HH:mm:ss` (regex sirve para `HH:mm`, `HH:mm:ss` y
   celdas datetime de Excel).
6. **Tipado**: `date`, `time`, `int`, `decimal(9,6)`, `decimal(8,1)`, `bit`.
7. **Calidad**: filtra filas invalidas (incluye `TOTAL_OPERACION`, filas sin
   ruta/bus, franjas mal formadas) y deduplica catalogos por id.
8. Escribe en `silver.*` (tablas tipadas con PK + FK, NOT NULL).

### Orquestacion

`pipeline_bronze` ejecuta la ingesta cruda (BR_01..BR_07) y al terminar
dispara automaticamente `pipeline_silver` (actividad `EjecutarPipelineSilver`,
Execute Pipeline con espera). `pipeline_silver` audita bronze, vacia silver en
orden de dependencias y recarga rutas -> paradas -> vehiculos -> incidentes ->
viajes -> demanda -> incidente_ruta respetando las FK. Una sola ejecucion de
`pipeline_bronze` deja ambas capas cargadas.

## Estructura

```
dataflow/    7 df bronze (rename + AnioFuente) + 7 df silver (reglas + tipado)
dataset/     datasets de storage (raw), ERP y DW (bronze/silver)
pipeline/    pipeline_bronze (encadena silver), pipeline_silver
linkedService/
sql_dw/      01_crear_esquema_bronze.sql   (tablas nvarchar, zona cruda)
             02_crear_esquema_silver.sql   (tablas tipadas, PK + FK, NOT NULL)
             03_consultas_validacion.sql   (calidad + chequeo de separacion de capas)
```

## Puesta en marcha

1. Desplegar el entorno (storage `raw/`, ERP `erp_transporte_db`, factoria).
2. En `dw_transporte` ejecutar `sql_dw/01_crear_esquema_bronze.sql` y
   `sql_dw/02_crear_esquema_silver.sql`.
3. Publicar este repo en la factoria (rama `adf_publish`) o importar los JSON.
4. Ejecutar `pipeline_bronze` (al terminar lanza solo `pipeline_silver`).
5. Verificar con `sql_dw/03_consultas_validacion.sql`: la seccion 5 confirma
   que bronze conserva codigos crudos y que silver solo tiene ids estandar.
