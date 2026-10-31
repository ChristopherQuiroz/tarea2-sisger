-- =============================================================
-- 01_crear_esquema_bronze.sql
-- Capa BRONZE del DW (dw_transporte): zona cruda estructurada.
-- Todas las columnas son nvarchar: los valores llegan TAL CUAL
-- de CSV (2020-2021), Excel (2022-2023) y ERP SQL (2024-2025),
-- solo con los NOMBRES de columna del ERP y el metadato AnioFuente.
-- Bronze NO aplica reglas de negocio: sin trim/upper, sin parseo
-- de fechas, sin derivacion de ids historicos (RH-*/V-*), sin
-- generacion de claves (DM-*) y sin filtros. Conserva codigos
-- crudos ('05', 'Ruta 29', '015'), duplicados, nulos y formatos
-- originales; toda la estandarizacion vive en la capa silver.
-- Excepcion estructural: IncidenteRuta expande la lista cruda
-- rutas_afectadas a filas y EsPrincipal guarda la posicion cruda
-- en la lista ('1' = primer elemento); silver la convierte a bit.
-- =============================================================SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

IF OBJECT_ID('bronze.IncidenteRuta', 'U')   IS NOT NULL DROP TABLE bronze.IncidenteRuta;
IF OBJECT_ID('bronze.DemandaParadas', 'U')  IS NOT NULL DROP TABLE bronze.DemandaParadas;
IF OBJECT_ID('bronze.Viajes', 'U')          IS NOT NULL DROP TABLE bronze.Viajes;
IF OBJECT_ID('bronze.Incidentes', 'U')      IS NOT NULL DROP TABLE bronze.Incidentes;
IF OBJECT_ID('bronze.Vehiculos', 'U')       IS NOT NULL DROP TABLE bronze.Vehiculos;
IF OBJECT_ID('bronze.Paradas', 'U')         IS NOT NULL DROP TABLE bronze.Paradas;
IF OBJECT_ID('bronze.Rutas', 'U')           IS NOT NULL DROP TABLE bronze.Rutas;
GO

CREATE TABLE bronze.Rutas (
  AnioFuente nvarchar(10) NULL, RutaHistoricaId nvarchar(30) NULL, CodigoRuta nvarchar(30) NULL,
  NombreRuta nvarchar(120) NULL, Origen nvarchar(80) NULL, Destino nvarchar(80) NULL,
  VigenciaDesde nvarchar(30) NULL, VigenciaHasta nvarchar(30) NULL, Estado nvarchar(20) NULL
);

CREATE TABLE bronze.Paradas (
  AnioFuente nvarchar(10) NULL, ParadaHistoricaId nvarchar(30) NULL, CodigoPublicado nvarchar(30) NULL,
  NombreParada nvarchar(120) NULL, Zona nvarchar(40) NULL, Latitud nvarchar(30) NULL, Longitud nvarchar(30) NULL,
  VigenciaDesde nvarchar(30) NULL, VigenciaHasta nvarchar(30) NULL, Estado nvarchar(20) NULL
);

CREATE TABLE bronze.Vehiculos (
  AnioFuente nvarchar(10) NULL, VehiculoId nvarchar(20) NULL, Placa nvarchar(20) NULL,
  TipoVehiculo nvarchar(30) NULL, CapacidadEfectiva nvarchar(10) NULL,
  VigenciaDesde nvarchar(30) NULL, VigenciaHasta nvarchar(30) NULL, Estado nvarchar(20) NULL
);

CREATE TABLE bronze.Viajes (
  AnioFuente nvarchar(10) NULL, ViajeId nvarchar(30) NULL, RutaHistoricaId nvarchar(30) NULL,
  VehiculoId nvarchar(20) NULL, FechaServicio nvarchar(30) NULL, HoraProgramada nvarchar(30) NULL,
  HoraSalida nvarchar(30) NULL, HoraLlegada nvarchar(30) NULL, ValidacionesTarjeta nvarchar(15) NULL,
  KmRecorridos nvarchar(20) NULL, EstadoViaje nvarchar(20) NULL
);

CREATE TABLE bronze.DemandaParadas (
  AnioFuente nvarchar(10) NULL, DemandaId nvarchar(30) NULL, FechaServicio nvarchar(30) NULL,
  RutaHistoricaId nvarchar(30) NULL, ParadaHistoricaId nvarchar(30) NULL, Franja nvarchar(20) NULL,
  ValidacionesTarjeta nvarchar(15) NULL, Descensos nvarchar(15) NULL, DemandaNoAtendida nvarchar(15) NULL,
  Metodo nvarchar(30) NULL
);

CREATE TABLE bronze.Incidentes (
  AnioFuente nvarchar(10) NULL, IncidenteId nvarchar(30) NULL, TipoIncidente nvarchar(30) NULL,
  Severidad nvarchar(15) NULL, FechaHoraInicio nvarchar(30) NULL, FechaHoraFin nvarchar(30) NULL,
  FechaHoraRegistro nvarchar(30) NULL, VehiculoId nvarchar(20) NULL, Descripcion nvarchar(200) NULL
);

CREATE TABLE bronze.IncidenteRuta (
  AnioFuente nvarchar(10) NULL, IncidenteId nvarchar(30) NULL,
  RutaHistoricaId nvarchar(30) NULL, EsPrincipal nvarchar(5) NULL
);
GO
