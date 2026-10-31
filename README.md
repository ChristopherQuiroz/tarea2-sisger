# tarea2-sisger — Pipeline Bronze/Silver corregido

Proyecto Azure Data Factory (ARM export) + Terraform del entorno, para el DW de
transporte con arquitectura medallion:

```
datos_csv/*.csv ─────┐
datos_xls/*.xlsx ────┼──> bronze.* (raw estructurado) ──> silver.* (limpia y tipada) ──> Tableau
ERP Azure SQL ───────┘
```

## Qué estaba roto y cómo se corrigió

### Capa bronze (df_bronze_*)
1. **Faltaba `AnioFuente`**: las ramas CSV/XLS no la generaban, llegaba NULL al
   bronze y silver no podía reconstruir los ids. Ahora:
   - CSV → año extraído de la propia fecha (los CSV mezclan **2020 y 2021**).
   - XLS → literal `2022` / `2023`. SQL → el que ya trae.
2. **`RutaHistoricaId`/`VehiculoId` sin normalizar**: viajes y demanda guardaban
   el código crudo (`05`, `R-18`, `Ruta 29`) como si fuera el id histórico.
   Ahora bronze deriva los ids con las reglas del ERP:
   - `05` / `R-05` / `Ruta 5` → `RH-05`
   - `R-07` (2020-2021) → `RH-07-OLD`; el ERP usa `RH-07-NEW` desde 2024.
   - `12`/`R-12`/`Ruta 12` (2020-2022) → `RH-12-OLD`; `R12-N`/`R12-S` → `RH-12-N`/`RH-12-S`.
   - `015` / `V-029` → `V-029`; paradas `P036`/`MC-01` se conservan.
3. **`ValidacionesTarjeta` vacía**: la rama XLS de viajes no mapeaba
   `pasajeros_estimados`; la rama CSV mapeaba `pasajeros_reportados` a un nombre
   que el sink no usaba. Ambas ramas quedan unificadas en `ValidacionesTarjeta`.
4. **Demanda sin `DemandaId`**: se genera `DM-<anio>-<correlativo>` con
   `keyGenerate` por rama (antes todo salía con año 2024 o NULL).
5. **Incidentes con fecha y hora en columnas separadas**: bronze compone
   `FechaHoraInicio/Fin/Registro` en formato ISO, manejando seriales de Excel
   (`44771`) y horas tipo `HH:mm` o celdas de tiempo.
6. **IncidenteRuta no se cargaba**: el campo `rutas_afectadas` (`RH-05|RH-04`)
   se ignoraba. Nuevo `df_bronze_incidente_ruta` que hace `flatten` de la lista,
   marca `EsPrincipal=1` en la primera ruta y une con `IncidenteRutaAzure` del ERP.

### Capa silver (df_silver_*)
1. **Fechas multi-formato**: un solo parseo `dd/MM/yyyy` rompía las fechas ISO y
   los seriales de Excel. Ahora se parsea: serial Excel (5 dígitos →
   `1899-12-30 + n`), `dd/MM/yyyy` si hay `/`, si no `yyyy-MM-dd`.
2. **Horas**: se extrae `HH:mm` con regex (sirve para `HH:mm`, `HH:mm:ss` y
   celdas datetime de Excel) y se escribe como `HH:mm:ss` en columnas `time`.
3. **Ids de viaje**: `ViajeId = VJ-<anio>-<id 5 dígitos>` solo cuando el id es
   crudo; los ids del ERP (`VJ-2024-00001`) se respetan (antes se duplicaba el
   prefijo: `VJ-2024-VJ-2024-00001`).
4. **Sin nulos**: cada dataflow filtra las filas inválidas después de limpiar
   (incluye la fila basura `TOTAL_OPERACION` de los Excel y las filas con
   `cod_ruta`/`nro_bus` vacíos). Los catálogos se deduplican por id
   (el CSV trae ~50% de filas repetidas).
5. **Orden con FK**: `pipeline_silver` carga rutas → paradas → vehículos →
   incidentes → viajes → demanda → incidente_ruta, y un Script inicial audita
   bronze y vacía silver en orden de dependencias (recarga idempotente).
   `Incidentes.VehiculoId` queda NULL solo cuando el incidente no tiene
   vehículo (así lo define el esquema del ERP).

## Estructura

```
dataflow/    7 df bronze + 7 df silver (Mapping Data Flow)
dataset/     datasets de storage (raw), ERP y DW (bronze/silver)
pipeline/    pipeline_bronze, pipeline_silver (encadenados, con scripts de limpieza)
linkedService/
sql_dw/      01_crear_esquema_bronze.sql   (tablas nvarchar, zona cruda)
             02_crear_esquema_silver.sql   (tablas tipadas, PK + FK, NOT NULL)
             03_consultas_validacion.sql   (chequeos de calidad para la demo)
```

## Puesta en marcha

1. Desplegar el entorno con Terraform (chris-terraform): storage `raw/`,
   ERP `erp_transporte_db` cargado y la factoría.
2. En `dw_transporte` ejecutar `sql_dw/01_crear_esquema_bronze.sql` y
   `sql_dw/02_crear_esquema_silver.sql`.
3. Publicar este repo en la factoría (rama `adf_publish`) o importar los JSON.
4. Ejecutar `pipeline_bronze` y después `pipeline_silver`.
5. Verificar con `sql_dw/03_consultas_validacion.sql`.

## Resultado verificado (simulación sobre los datos reales)

| Tabla silver      | Filas | Regla aplicada |
|-------------------|------:|----------------|
| Rutas             |    51 | 48 + RH-07-OLD/NEW + RH-12-OLD/N/S, deduplicadas |
| Paradas           |   220 | dedup por ParadaHistoricaId (incl. MC-01) |
| Vehiculos         |   120 | dedup por VehiculoId |
| Viajes            | 25112 | 5 filas inválidas descartadas (TOTAL_OPERACION, sin ruta/bus) |
| DemandaParadas    | 55200 | ids generados, fechas serial convertidas |
| Incidentes        |  1320 | fechas-hora compuestas |
| IncidenteRuta     |  1108 | split de rutas_afectadas |

Todas las PK son únicas, todas las FK se satisfacen y no hay nulos en ninguna
columna NOT NULL.
