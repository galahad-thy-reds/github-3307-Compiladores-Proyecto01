/*
================================================================================
  HR_Staging - Área de staging (landing) para ETLs SSIS
  Patrón: 1 tabla staging por entidad fuente + columnas de control ETL
================================================================================
*/
USE master;
GO

IF DB_ID(N'HR_Staging') IS NULL
BEGIN
    CREATE DATABASE HR_Staging;
END
GO

USE HR_Staging;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg')
    EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'stg.Empleado', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Empleado
    (
        StagingID           BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EmpleadoID          INT NULL,
        NumeroEmpleado      VARCHAR(20) NULL,
        Cedula              VARCHAR(20) NULL,
        Nombre              NVARCHAR(80) NULL,
        Apellido1           NVARCHAR(80) NULL,
        Apellido2           NVARCHAR(80) NULL,
        FechaNacimiento     DATE NULL,
        Genero              CHAR(1) NULL,
        EmailCorporativo    NVARCHAR(150) NULL,
        FechaContratacion   DATE NULL,
        FechaTerminacion    DATE NULL,
        EstadoEmpleadoID    INT NULL,
        DepartamentoID      INT NULL,
        PuestoID            INT NULL,
        UbicacionID         INT NULL,
        ManagerEmpleadoID   INT NULL,
        EscalaSalarialID    INT NULL,
        SalarioActual       DECIMAL(12,2) NULL,
        TipoContrato        VARCHAR(20) NULL,
        IsActive            BIT NULL,
        SrcModifiedAt       DATETIME2(0) NULL,
        LoadBatchID         UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC         DATETIME2(0) NOT NULL CONSTRAINT DF_StgEmp_Load DEFAULT (SYSUTCDATETIME()),
        LoadType            VARCHAR(20) NOT NULL -- Full / Incremental
    );
END
GO

IF OBJECT_ID(N'stg.Ausencia', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Ausencia
    (
        StagingID       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AusenciaID      INT NULL,
        EmpleadoID      INT NULL,
        TipoAusenciaID  INT NULL,
        FechaInicio     DATE NULL,
        FechaFin        DATE NULL,
        DiasLaborales   DECIMAL(5,1) NULL,
        Estado          VARCHAR(20) NULL,
        SrcModifiedAt   DATETIME2(0) NULL,
        LoadBatchID     UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC     DATETIME2(0) NOT NULL CONSTRAINT DF_StgAus_Load DEFAULT (SYSUTCDATETIME()),
        LoadType        VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.SalidaEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE stg.SalidaEmpleado
    (
        StagingID           BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        SalidaEmpleadoID    INT NULL,
        EmpleadoID          INT NULL,
        MotivoSalidaID      INT NULL,
        FechaSalida         DATE NULL,
        TipoSalida          VARCHAR(20) NULL,
        DepartamentoID      INT NULL,
        PuestoID            INT NULL,
        UbicacionID         INT NULL,
        SalarioAlSalir      DECIMAL(12,2) NULL,
        EntrevistaSalida    BIT NULL,
        Recontratable       BIT NULL,
        SrcModifiedAt       DATETIME2(0) NULL,
        LoadBatchID         UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC         DATETIME2(0) NOT NULL CONSTRAINT DF_StgSal_Load DEFAULT (SYSUTCDATETIME()),
        LoadType            VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.EmpleadoHabilidad', N'U') IS NULL
BEGIN
    CREATE TABLE stg.EmpleadoHabilidad
    (
        StagingID           BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EmpleadoHabilidadID INT NULL,
        EmpleadoID          INT NULL,
        HabilidadID         INT NULL,
        NivelHabilidadID    INT NULL,
        FechaEvaluacion     DATE NULL,
        FuenteEvaluacion    NVARCHAR(40) NULL,
        Certificado         BIT NULL,
        IsActive            BIT NULL,
        SrcModifiedAt       DATETIME2(0) NULL,
        LoadBatchID         UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC         DATETIME2(0) NOT NULL CONSTRAINT DF_StgHab_Load DEFAULT (SYSUTCDATETIME()),
        LoadType            VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.HistorialSalarial', N'U') IS NULL
BEGIN
    CREATE TABLE stg.HistorialSalarial
    (
        StagingID           BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        HistorialSalarialID INT NULL,
        EmpleadoID          INT NULL,
        EscalaSalarialID    INT NULL,
        SalarioAnterior     DECIMAL(12,2) NULL,
        SalarioNuevo        DECIMAL(12,2) NULL,
        Motivo              NVARCHAR(100) NULL,
        FechaEfectiva       DATE NULL,
        SrcModifiedAt       DATETIME2(0) NULL,
        LoadBatchID         UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC         DATETIME2(0) NOT NULL CONSTRAINT DF_StgHist_Load DEFAULT (SYSUTCDATETIME()),
        LoadType            VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.EmpleadoAsignacionHistorial', N'U') IS NULL
BEGIN
    CREATE TABLE stg.EmpleadoAsignacionHistorial
    (
        StagingID               BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        AsignacionHistorialID   INT NULL,
        EmpleadoID              INT NULL,
        DepartamentoID          INT NULL,
        PuestoID                INT NULL,
        UbicacionID             INT NULL,
        ManagerEmpleadoID       INT NULL,
        EscalaSalarialID        INT NULL,
        Salario                 DECIMAL(12,2) NULL,
        MotivoCambio            NVARCHAR(100) NULL,
        FechaInicio             DATE NULL,
        FechaFin                DATE NULL,
        EsActual                BIT NULL,
        SrcModifiedAt           DATETIME2(0) NULL,
        LoadBatchID             UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC             DATETIME2(0) NOT NULL CONSTRAINT DF_StgAsig_Load DEFAULT (SYSUTCDATETIME()),
        LoadType                VARCHAR(20) NOT NULL
    );
END
GO

/* Catálogos espejo (necesarios para dims en carga Full/Incremental) */
IF OBJECT_ID(N'stg.Departamento', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Departamento
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        DepartamentoID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(100) NULL, CostoCentro VARCHAR(30) NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgDepto_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.Puesto', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Puesto
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PuestoID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(120) NULL,
        NivelJerarquico TINYINT NULL, FamiliaPuesto NVARCHAR(60) NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgPuesto_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.Ubicacion', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Ubicacion
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        UbicacionID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(100) NULL,
        Provincia NVARCHAR(50) NULL, Pais NVARCHAR(50) NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgUbic_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.Habilidad', N'U') IS NULL
BEGIN
    CREATE TABLE stg.Habilidad
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        HabilidadID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(100) NULL,
        Categoria NVARCHAR(50) NULL, IsCritical BIT NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgHabCat_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.TipoAusencia', N'U') IS NULL
BEGIN
    CREATE TABLE stg.TipoAusencia
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        TipoAusenciaID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(80) NULL,
        EsRemunerada BIT NULL, AfectaProductividad BIT NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgTipoAus_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.MotivoSalida', N'U') IS NULL
BEGIN
    CREATE TABLE stg.MotivoSalida
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        MotivoSalidaID INT NULL, Codigo VARCHAR(20) NULL, Nombre NVARCHAR(100) NULL,
        Categoria NVARCHAR(40) NULL, EsEvitable BIT NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgMotivo_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.EscalaSalarial', N'U') IS NULL
BEGIN
    CREATE TABLE stg.EscalaSalarial
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EscalaSalarialID INT NULL, Codigo VARCHAR(20) NULL, Grado TINYINT NULL,
        Descripcion NVARCHAR(100) NULL,
        SalarioMinimo DECIMAL(12,2) NULL, SalarioMedio DECIMAL(12,2) NULL, SalarioMaximo DECIMAL(12,2) NULL,
        Moneda CHAR(3) NULL,
        IsActive BIT NULL, SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgEscala_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.NivelHabilidad', N'U') IS NULL
BEGIN
    CREATE TABLE stg.NivelHabilidad
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        NivelHabilidadID INT NULL, Codigo VARCHAR(10) NULL, Nombre NVARCHAR(40) NULL, ValorNumerico TINYINT NULL,
        SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgNivel_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.PuestoHabilidadRequerida', N'U') IS NULL
BEGIN
    CREATE TABLE stg.PuestoHabilidadRequerida
    (
        StagingID BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PuestoHabilidadID INT NULL, PuestoID INT NULL, HabilidadID INT NULL,
        NivelMinimoRequeridoID INT NULL, EsObligatoria BIT NULL,
        SrcModifiedAt DATETIME2(0) NULL,
        LoadBatchID UNIQUEIDENTIFIER NOT NULL,
        LoadDateUTC DATETIME2(0) NOT NULL CONSTRAINT DF_StgPuestoHab_Load DEFAULT (SYSUTCDATETIME()),
        LoadType VARCHAR(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'stg.EtlBatchLog', N'U') IS NULL
BEGIN
    CREATE TABLE stg.EtlBatchLog
    (
        BatchID         UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_EtlBatch PRIMARY KEY,
        PackageName     NVARCHAR(200) NOT NULL,
        LoadType        VARCHAR(20) NOT NULL,
        StartUTC        DATETIME2(0) NOT NULL,
        EndUTC          DATETIME2(0) NULL,
        Status          VARCHAR(20) NOT NULL, -- Running, Success, Failed
        RowsExtracted   INT NULL,
        RowsLoaded      INT NULL,
        ErrorMessage    NVARCHAR(MAX) NULL
    );
END
GO

PRINT N'Staging Area creada.';
GO
