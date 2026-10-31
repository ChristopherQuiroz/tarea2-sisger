-- =============================================================
-- 03_consultas_validacion.sql
-- Chequeos de calidad despues de ejecutar pipeline_bronze y
-- pipeline_silver. Todo debe devolver 0 salvo los conteos.
-- =============================================================
SET NOCOUNT ON;

-- 1. Filas por capa
SELECT 'bronze.Rutas' AS Tabla, COUNT(*) AS Filas FROM bronze.Rutas
UNION ALL SELECT 'bronze.Paradas', COUNT(*) FROM bronze.Paradas
UNION ALL SELECT 'bronze.Vehiculos', COUNT(*) FROM bronze.Vehiculos
UNION ALL SELECT 'bronze.Viajes', COUNT(*) FROM bronze.Viajes
UNION ALL SELECT 'bronze.DemandaParadas', COUNT(*) FROM bronze.DemandaParadas
UNION ALL SELECT 'bronze.Incidentes', COUNT(*) FROM bronze.Incidentes
UNION ALL SELECT 'bronze.IncidenteRuta', COUNT(*) FROM bronze.IncidenteRuta
UNION ALL SELECT 'silver.Rutas', COUNT(*) FROM silver.Rutas
UNION ALL SELECT 'silver.Paradas', COUNT(*) FROM silver.Paradas
UNION ALL SELECT 'silver.Vehiculos', COUNT(*) FROM silver.Vehiculos
UNION ALL SELECT 'silver.Viajes', COUNT(*) FROM silver.Viajes
UNION ALL SELECT 'silver.DemandaParadas', COUNT(*) FROM silver.DemandaParadas
UNION ALL SELECT 'silver.Incidentes', COUNT(*) FROM silver.Incidentes
UNION ALL SELECT 'silver.IncidenteRuta', COUNT(*) FROM silver.IncidenteRuta;

-- 2. Nulos en silver (debe ser 0; solo Incidentes.VehiculoId admite NULL por diseno)
SELECT 'Viajes' AS Tabla, COUNT(*) AS Nulos FROM silver.Viajes
WHERE ViajeId IS NULL OR RutaHistoricaId IS NULL OR VehiculoId IS NULL OR FechaServicio IS NULL
   OR HoraProgramada IS NULL OR HoraSalida IS NULL OR HoraLlegada IS NULL
   OR ValidacionesTarjeta IS NULL OR KmRecorridos IS NULL OR EstadoViaje IS NULL
UNION ALL
SELECT 'DemandaParadas', COUNT(*) FROM silver.DemandaParadas
WHERE DemandaId IS NULL OR FechaServicio IS NULL OR RutaHistoricaId IS NULL OR ParadaHistoricaId IS NULL
   OR Franja IS NULL OR ValidacionesTarjeta IS NULL OR Descensos IS NULL OR DemandaNoAtendida IS NULL OR Metodo IS NULL
UNION ALL
SELECT 'Rutas', COUNT(*) FROM silver.Rutas
WHERE RutaHistoricaId IS NULL OR CodigoRuta IS NULL OR VigenciaDesde IS NULL OR VigenciaHasta IS NULL;

-- 3. Huerfanos contra catalogos silver (debe ser 0)
SELECT 'ViajesSinRuta' AS Chequeo, COUNT(*) AS Filas FROM silver.Viajes v
WHERE NOT EXISTS (SELECT 1 FROM silver.Rutas r WHERE r.RutaHistoricaId = v.RutaHistoricaId)
UNION ALL
SELECT 'ViajesSinVehiculo', COUNT(*) FROM silver.Viajes v
WHERE NOT EXISTS (SELECT 1 FROM silver.Vehiculos x WHERE x.VehiculoId = v.VehiculoId)
UNION ALL
SELECT 'DemandaSinParada', COUNT(*) FROM silver.DemandaParadas d
WHERE NOT EXISTS (SELECT 1 FROM silver.Paradas p WHERE p.ParadaHistoricaId = d.ParadaHistoricaId)
UNION ALL
SELECT 'IncidenteRutaSinIncidente', COUNT(*) FROM silver.IncidenteRuta ir
WHERE NOT EXISTS (SELECT 1 FROM silver.Incidentes i WHERE i.IncidenteId = ir.IncidenteId);

-- 4. Distribucion por anio embebido en el id
SELECT LEFT(ViajeId, 7) AS AnioId, COUNT(*) AS Viajes FROM silver.Viajes GROUP BY LEFT(ViajeId, 7) ORDER BY 1;
SELECT LEFT(DemandaId, 7) AS AnioId, COUNT(*) AS Registros FROM silver.DemandaParadas GROUP BY LEFT(DemandaId, 7) ORDER BY 1;

-- 5. Separacion de capas: bronze conserva codigos crudos, silver solo ids estandar
-- (bronze debe ser > 0: guarda el crudo; silver debe ser 0: todo normalizado)
SELECT 'bronze.Viajes_CodigosCrudos' AS Chequeo, COUNT(*) AS Filas FROM bronze.Viajes
WHERE RutaHistoricaId NOT LIKE 'RH-%' OR VehiculoId NOT LIKE 'V-___'
UNION ALL
SELECT 'silver.Viajes_SinEstandar (debe ser 0)', COUNT(*) FROM silver.Viajes
WHERE RutaHistoricaId NOT LIKE 'RH-%' OR VehiculoId NOT LIKE 'V-___'
UNION ALL
SELECT 'bronze.Rutas_CodigosCrudos', COUNT(*) FROM bronze.Rutas WHERE RutaHistoricaId NOT LIKE 'RH-%'
UNION ALL
SELECT 'silver.Rutas_SinEstandar (debe ser 0)', COUNT(*) FROM silver.Rutas WHERE RutaHistoricaId NOT LIKE 'RH-%'
UNION ALL
SELECT 'bronze.Demanda_SinId (crudo)', COUNT(*) FROM bronze.DemandaParadas WHERE DemandaId IS NULL
UNION ALL
SELECT 'silver.Demanda_IdNoEstandar (debe ser 0)', COUNT(*) FROM silver.DemandaParadas WHERE DemandaId NOT LIKE 'DM-____-_____';
