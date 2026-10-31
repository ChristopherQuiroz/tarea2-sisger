-- =============================================================
-- 02_crear_esquema_silver.sql
-- Capa SILVER del DW (dw_transporte): datos limpios y tipados.
-- Misma logica del ERP pero consolidada por id historico
-- (el anio ya va embebido en los ids: VJ-2022-00001, etc.).
-- Toda columna es NOT NULL salvo Incidentes.VehiculoId, que el
-- esquema del docente declara NULL (incidente sin vehiculo).
-- =============================================================
SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

IF OBJECT_ID('silver.IncidenteRuta', 'U')   IS NOT NULL DROP TABLE silver.IncidenteRuta;
IF OBJECT_ID('silver.DemandaParadas', 'U')  IS NOT NULL DROP TABLE silver.DemandaParadas;
IF OBJECT_ID('silver.Viajes', 'U')          IS NOT NULL DROP TABLE silver.Viajes;
IF OBJECT_ID('silver.Incidentes', 'U')      IS NOT NULL DROP TABLE silver.Incidentes;
IF OBJECT_ID('silver.Vehiculos', 'U')       IS NOT NULL DROP TABLE silver.Vehiculos;
IF OBJECT_ID('silver.Paradas', 'U')         IS NOT NULL DROP TABLE silver.Paradas;
IF OBJECT_ID('silver.Rutas', 'U')           IS NOT NULL DROP TABLE silver.Rutas;
GO

CREATE TABLE silver.Rutas (
  RutaHistoricaId nvarchar(30) NOT NULL, CodigoRuta nvarchar(20) NOT NULL,
  NombreRuta nvarchar(120) NOT NULL, Origen nvarchar(80) NOT NULL, Destino nvarchar(80) NOT NULL,
  VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL, Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_silver_Rutas PRIMARY KEY (RutaHistoricaId)
);

CREATE TABLE silver.Paradas (
  ParadaHistoricaId nvarchar(30) NOT NULL, CodigoPublicado nvarchar(20) NOT NULL,
  NombreParada nvarchar(120) NOT NULL, Zona nvarchar(40) NOT NULL,
  Latitud decimal(9,6) NOT NULL, Longitud decimal(9,6) NOT NULL,
  VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL, Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_silver_Paradas PRIMARY KEY (ParadaHistoricaId)
);

CREATE TABLE silver.Vehiculos (
  VehiculoId nvarchar(20) NOT NULL, Placa nvarchar(20) NOT NULL, TipoVehiculo nvarchar(30) NOT NULL,
  CapacidadEfectiva int NOT NULL, VigenciaDesde date NOT NULL, VigenciaHasta date NOT NULL,
  Estado nvarchar(20) NOT NULL,
  CONSTRAINT PK_silver_Vehiculos PRIMARY KEY (VehiculoId)
);

CREATE TABLE silver.Viajes (
  ViajeId nvarchar(30) NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL, VehiculoId nvarchar(20) NOT NULL,
  FechaServicio date NOT NULL, HoraProgramada time NOT NULL, HoraSalida time NOT NULL, HoraLlegada time NOT NULL,
  ValidacionesTarjeta int NOT NULL, KmRecorridos decimal(8,1) NOT NULL, EstadoViaje nvarchar(20) NOT NULL,
  CONSTRAINT PK_silver_Viajes PRIMARY KEY (ViajeId),
  CONSTRAINT FK_silver_Viajes_Rutas FOREIGN KEY (RutaHistoricaId) REFERENCES silver.Rutas (RutaHistoricaId),
  CONSTRAINT FK_silver_Viajes_Vehiculos FOREIGN KEY (VehiculoId) REFERENCES silver.Vehiculos (VehiculoId)
);

CREATE TABLE silver.DemandaParadas (
  DemandaId nvarchar(30) NOT NULL, FechaServicio date NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL,
  ParadaHistoricaId nvarchar(30) NOT NULL, Franja nvarchar(20) NOT NULL, ValidacionesTarjeta int NOT NULL,
  Descensos int NOT NULL, DemandaNoAtendida int NOT NULL, Metodo nvarchar(30) NOT NULL,
  CONSTRAINT PK_silver_DemandaParadas PRIMARY KEY (DemandaId),
  CONSTRAINT FK_silver_Demanda_Rutas FOREIGN KEY (RutaHistoricaId) REFERENCES silver.Rutas (RutaHistoricaId),
  CONSTRAINT FK_silver_Demanda_Paradas FOREIGN KEY (ParadaHistoricaId) REFERENCES silver.Paradas (ParadaHistoricaId)
);

CREATE TABLE silver.Incidentes (
  IncidenteId nvarchar(30) NOT NULL, TipoIncidente nvarchar(30) NOT NULL, Severidad nvarchar(15) NOT NULL,
  FechaHoraInicio datetime2(0) NOT NULL, FechaHoraFin datetime2(0) NOT NULL, FechaHoraRegistro datetime2(0) NOT NULL,
  VehiculoId nvarchar(20) NULL, Descripcion nvarchar(200) NOT NULL,
  CONSTRAINT PK_silver_Incidentes PRIMARY KEY (IncidenteId),
  CONSTRAINT FK_silver_Incidentes_Vehiculos FOREIGN KEY (VehiculoId) REFERENCES silver.Vehiculos (VehiculoId)
);

CREATE TABLE silver.IncidenteRuta (
  IncidenteId nvarchar(30) NOT NULL, RutaHistoricaId nvarchar(30) NOT NULL, EsPrincipal bit NOT NULL,
  CONSTRAINT PK_silver_IncidenteRuta PRIMARY KEY (IncidenteId, RutaHistoricaId),
  CONSTRAINT FK_silver_IR_Incidentes FOREIGN KEY (IncidenteId) REFERENCES silver.Incidentes (IncidenteId),
  CONSTRAINT FK_silver_IR_Rutas FOREIGN KEY (RutaHistoricaId) REFERENCES silver.Rutas (RutaHistoricaId)
);
GO

CREATE INDEX IX_silver_Viajes_FechaRuta ON silver.Viajes (FechaServicio, RutaHistoricaId);
CREATE INDEX IX_silver_Demanda_FechaFranja ON silver.DemandaParadas (FechaServicio, Franja);
GO
