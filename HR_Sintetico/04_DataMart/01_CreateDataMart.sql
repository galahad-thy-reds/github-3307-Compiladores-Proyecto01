/*
================================================================================
  HR_DataMart - Modelo dimensional sugerido (Ralph Kimball)
  Estrella orientada a las 4 preguntas de RH
  Nota: este script crea una BD separada para el data mart.
================================================================================
*/
USE master;
GO

IF DB_ID(N'HR_DataMart') IS NULL
BEGIN
    CREATE DATABASE HR_DataMart;
END
GO

USE HR_DataMart;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dm')
    EXEC(N'CREATE SCHEMA dm AUTHORIZATION dbo;');
GO

/* ---------- Dimensiones ---------- */
IF OBJECT_ID(N'dm.DimFecha', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimFecha
    (
        FechaKey        INT NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY, -- yyyymmdd
        Fecha           DATE NOT NULL,
        Anio            SMALLINT NOT NULL,
        Mes             TINYINT NOT NULL,
        NombreMes       NVARCHAR(20) NOT NULL,
        Trimestre       TINYINT NOT NULL,
        NombreTrimestre NVARCHAR(10) NOT NULL,
        SemanaAnio      TINYINT NOT NULL,
        DiaSemana       TINYINT NOT NULL,
        NombreDiaSemana NVARCHAR(20) NOT NULL,
        EsFinDeSemana   BIT NOT NULL,
        AnioMes         CHAR(7) NOT NULL -- yyyy-MM
    );
END
GO

IF OBJECT_ID(N'dm.DimEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimEmpleado
    (
        EmpleadoKey         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEmpleado PRIMARY KEY,
        EmpleadoBK          INT NOT NULL,          -- EmpleadoID origen
        NumeroEmpleado      VARCHAR(20) NOT NULL,
        NombreCompleto      NVARCHAR(200) NOT NULL,
        Genero              CHAR(1) NOT NULL,
        FechaNacimiento     DATE NOT NULL,
        FechaContratacion   DATE NOT NULL,
        TipoContrato        VARCHAR(20) NOT NULL,
        /* SCD Tipo 2 */
        FechaInicioValidez  DATETIME2(0) NOT NULL,
        FechaFinValidez     DATETIME2(0) NULL,
        EsActual            BIT NOT NULL,
        HashDiff            BINARY(32) NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimDepartamento', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimDepartamento
    (
        DepartamentoKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimDepto PRIMARY KEY,
        DepartamentoBK  INT NOT NULL,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        CostoCentro     VARCHAR(30) NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimPuesto', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimPuesto
    (
        PuestoKey       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPuesto PRIMARY KEY,
        PuestoBK        INT NOT NULL,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(120) NOT NULL,
        NivelJerarquico TINYINT NOT NULL,
        FamiliaPuesto   NVARCHAR(60) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimUbicacion', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimUbicacion
    (
        UbicacionKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimUbic PRIMARY KEY,
        UbicacionBK  INT NOT NULL,
        Codigo       VARCHAR(20) NOT NULL,
        Nombre       NVARCHAR(100) NOT NULL,
        Provincia    NVARCHAR(50) NOT NULL,
        Pais         NVARCHAR(50) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimHabilidad', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimHabilidad
    (
        HabilidadKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimHab PRIMARY KEY,
        HabilidadBK  INT NOT NULL,
        Codigo       VARCHAR(20) NOT NULL,
        Nombre       NVARCHAR(100) NOT NULL,
        Categoria    NVARCHAR(50) NOT NULL,
        IsCritical   BIT NOT NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimMotivoSalida', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimMotivoSalida
    (
        MotivoSalidaKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimMotivo PRIMARY KEY,
        MotivoSalidaBK  INT NOT NULL,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        Categoria       NVARCHAR(40) NOT NULL,
        EsEvitable      BIT NOT NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimTipoAusencia', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimTipoAusencia
    (
        TipoAusenciaKey     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimTipoAus PRIMARY KEY,
        TipoAusenciaBK      INT NOT NULL,
        Codigo              VARCHAR(20) NOT NULL,
        Nombre              NVARCHAR(80) NOT NULL,
        EsRemunerada        BIT NOT NULL,
        AfectaProductividad BIT NOT NULL
    );
END
GO

IF OBJECT_ID(N'dm.DimEscalaSalarial', N'U') IS NULL
BEGIN
    CREATE TABLE dm.DimEscalaSalarial
    (
        EscalaSalarialKey INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimEscala PRIMARY KEY,
        EscalaSalarialBK  INT NOT NULL,
        Codigo            VARCHAR(20) NOT NULL,
        Grado             TINYINT NOT NULL,
        Descripcion       NVARCHAR(100) NOT NULL,
        SalarioMinimo     DECIMAL(12,2) NOT NULL,
        SalarioMedio      DECIMAL(12,2) NOT NULL,
        SalarioMaximo     DECIMAL(12,2) NOT NULL,
        Moneda            CHAR(3) NOT NULL
    );
END
GO

/* ---------- Hechos ---------- */

/* Fact snapshot mensual de headcount / compensación */
IF OBJECT_ID(N'dm.FactHeadcountMensual', N'U') IS NULL
BEGIN
    CREATE TABLE dm.FactHeadcountMensual
    (
        FactHeadcountID     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactHC PRIMARY KEY,
        FechaKey            INT NOT NULL, -- primer día del mes
        EmpleadoKey         INT NOT NULL,
        DepartamentoKey     INT NOT NULL,
        PuestoKey           INT NOT NULL,
        UbicacionKey        INT NOT NULL,
        EscalaSalarialKey   INT NOT NULL,
        Salario             DECIMAL(12,2) NOT NULL,
        EsActivo            BIT NOT NULL,
        AntiguedadMeses     INT NOT NULL,
        CONSTRAINT FK_FactHC_Fecha FOREIGN KEY (FechaKey) REFERENCES dm.DimFecha(FechaKey),
        CONSTRAINT FK_FactHC_Emp FOREIGN KEY (EmpleadoKey) REFERENCES dm.DimEmpleado(EmpleadoKey),
        CONSTRAINT FK_FactHC_Depto FOREIGN KEY (DepartamentoKey) REFERENCES dm.DimDepartamento(DepartamentoKey),
        CONSTRAINT FK_FactHC_Puesto FOREIGN KEY (PuestoKey) REFERENCES dm.DimPuesto(PuestoKey),
        CONSTRAINT FK_FactHC_Ubic FOREIGN KEY (UbicacionKey) REFERENCES dm.DimUbicacion(UbicacionKey),
        CONSTRAINT FK_FactHC_Escala FOREIGN KEY (EscalaSalarialKey) REFERENCES dm.DimEscalaSalarial(EscalaSalarialKey)
    );
END
GO

/* Fact de salidas (rotación) - grano: 1 fila por salida */
IF OBJECT_ID(N'dm.FactRotacion', N'U') IS NULL
BEGIN
    CREATE TABLE dm.FactRotacion
    (
        FactRotacionID      BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactRot PRIMARY KEY,
        FechaSalidaKey      INT NOT NULL,
        EmpleadoKey         INT NOT NULL,
        DepartamentoKey     INT NOT NULL,
        PuestoKey           INT NOT NULL,
        UbicacionKey        INT NOT NULL,
        MotivoSalidaKey     INT NOT NULL,
        AntiguedadMeses     INT NOT NULL,
        SalarioAlSalir      DECIMAL(12,2) NOT NULL,
        ContadorSalida      INT NOT NULL CONSTRAINT DF_FactRot_Cnt DEFAULT (1),
        EsEvitable          BIT NOT NULL,
        CONSTRAINT FK_FactRot_Fecha FOREIGN KEY (FechaSalidaKey) REFERENCES dm.DimFecha(FechaKey),
        CONSTRAINT FK_FactRot_Emp FOREIGN KEY (EmpleadoKey) REFERENCES dm.DimEmpleado(EmpleadoKey),
        CONSTRAINT FK_FactRot_Depto FOREIGN KEY (DepartamentoKey) REFERENCES dm.DimDepartamento(DepartamentoKey),
        CONSTRAINT FK_FactRot_Puesto FOREIGN KEY (PuestoKey) REFERENCES dm.DimPuesto(PuestoKey),
        CONSTRAINT FK_FactRot_Ubic FOREIGN KEY (UbicacionKey) REFERENCES dm.DimUbicacion(UbicacionKey),
        CONSTRAINT FK_FactRot_Motivo FOREIGN KEY (MotivoSalidaKey) REFERENCES dm.DimMotivoSalida(MotivoSalidaKey)
    );
END
GO

/* Fact de ausentismo - grano: 1 fila por evento de ausencia */
IF OBJECT_ID(N'dm.FactAusentismo', N'U') IS NULL
BEGIN
    CREATE TABLE dm.FactAusentismo
    (
        FactAusentismoID    BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactAus PRIMARY KEY,
        FechaInicioKey      INT NOT NULL,
        FechaFinKey         INT NOT NULL,
        EmpleadoKey         INT NOT NULL,
        DepartamentoKey     INT NOT NULL,
        PuestoKey           INT NOT NULL,
        TipoAusenciaKey     INT NOT NULL,
        DiasLaborales       DECIMAL(5,1) NOT NULL,
        ContadorEvento      INT NOT NULL CONSTRAINT DF_FactAus_Cnt DEFAULT (1),
        AfectaProductividad BIT NOT NULL,
        CONSTRAINT FK_FactAus_Fi FOREIGN KEY (FechaInicioKey) REFERENCES dm.DimFecha(FechaKey),
        CONSTRAINT FK_FactAus_Ff FOREIGN KEY (FechaFinKey) REFERENCES dm.DimFecha(FechaKey),
        CONSTRAINT FK_FactAus_Emp FOREIGN KEY (EmpleadoKey) REFERENCES dm.DimEmpleado(EmpleadoKey),
        CONSTRAINT FK_FactAus_Depto FOREIGN KEY (DepartamentoKey) REFERENCES dm.DimDepartamento(DepartamentoKey),
        CONSTRAINT FK_FactAus_Puesto FOREIGN KEY (PuestoKey) REFERENCES dm.DimPuesto(PuestoKey),
        CONSTRAINT FK_FactAus_Tipo FOREIGN KEY (TipoAusenciaKey) REFERENCES dm.DimTipoAusencia(TipoAusenciaKey)
    );
END
GO

/* Fact de habilidades / gap - grano: empleado × habilidad requerida */
IF OBJECT_ID(N'dm.FactHabilidadEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE dm.FactHabilidadEmpleado
    (
        FactHabilidadID     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactHab PRIMARY KEY,
        FechaEvaluacionKey  INT NOT NULL,
        EmpleadoKey         INT NOT NULL,
        DepartamentoKey     INT NOT NULL,
        PuestoKey           INT NOT NULL,
        HabilidadKey        INT NOT NULL,
        NivelActual         TINYINT NULL,
        NivelRequerido      TINYINT NOT NULL,
        TieneGap            BIT NOT NULL,
        DiferenciaNiveles   INT NOT NULL,
        EsCritica           BIT NOT NULL,
        EsObligatoria       BIT NOT NULL,
        CONSTRAINT FK_FactHab_Fecha FOREIGN KEY (FechaEvaluacionKey) REFERENCES dm.DimFecha(FechaKey),
        CONSTRAINT FK_FactHab_Emp FOREIGN KEY (EmpleadoKey) REFERENCES dm.DimEmpleado(EmpleadoKey),
        CONSTRAINT FK_FactHab_Depto FOREIGN KEY (DepartamentoKey) REFERENCES dm.DimDepartamento(DepartamentoKey),
        CONSTRAINT FK_FactHab_Puesto FOREIGN KEY (PuestoKey) REFERENCES dm.DimPuesto(PuestoKey),
        CONSTRAINT FK_FactHab_Hab FOREIGN KEY (HabilidadKey) REFERENCES dm.DimHabilidad(HabilidadKey)
    );
END
GO

/* Utilidad: poblar DimFecha */
CREATE OR ALTER PROCEDURE dm.usp_GenerarDimFecha
    @FechaInicio DATE = '2019-01-01',
    @FechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FechaFin IS NULL SET @FechaFin = DATEADD(YEAR, 2, CAST(GETDATE() AS DATE));

    DECLARE @d DATE = @FechaInicio;
    WHILE @d <= @FechaFin
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dm.DimFecha WHERE FechaKey = CONVERT(INT, CONVERT(CHAR(8), @d, 112)))
        BEGIN
            INSERT INTO dm.DimFecha
            (FechaKey, Fecha, Anio, Mes, NombreMes, Trimestre, NombreTrimestre, SemanaAnio,
             DiaSemana, NombreDiaSemana, EsFinDeSemana, AnioMes)
            VALUES
            (
                CONVERT(INT, CONVERT(CHAR(8), @d, 112)),
                @d,
                YEAR(@d),
                MONTH(@d),
                DATENAME(MONTH, @d),
                DATEPART(QUARTER, @d),
                N'Q' + CAST(DATEPART(QUARTER, @d) AS NVARCHAR(1)),
                DATEPART(ISO_WEEK, @d),
                DATEPART(WEEKDAY, @d),
                DATENAME(WEEKDAY, @d),
                CASE WHEN DATEPART(WEEKDAY, @d) IN (1,7) THEN 1 ELSE 0 END,
                CONVERT(CHAR(7), @d, 126)
            );
        END
        SET @d = DATEADD(DAY, 1, @d);
    END
END
GO

PRINT N'Data Mart dimensional (Kimball) creado.';
GO
