/*
================================================================================
  HR_Sintetico - DDL completo (modelo transaccional / OLTP)
  Convenciones:
    - PK surrogadas IDENTITY
    - CreatedAt / ModifiedAt en todas las tablas (ETL incremental por watermark)
    - IsActive para soft-delete / SCD Type 1 en origen
================================================================================
*/
USE HR_Sintetico;
GO

SET NOCOUNT ON;
GO

/* -------------------------------------------------------------------------- */
/* 1. CATÁLOGOS                                                               */
/* -------------------------------------------------------------------------- */

IF OBJECT_ID(N'hr.Ubicacion', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Ubicacion
    (
        UbicacionID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ubicacion PRIMARY KEY,
        Codigo          VARCHAR(20)  NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        Provincia       NVARCHAR(50)  NOT NULL,
        Canton          NVARCHAR(50)  NULL,
        Pais            NVARCHAR(50)  NOT NULL CONSTRAINT DF_Ubicacion_Pais DEFAULT (N'Costa Rica'),
        IsActive        BIT NOT NULL CONSTRAINT DF_Ubicacion_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Ubicacion_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Ubicacion_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Ubicacion_Codigo UNIQUE (Codigo)
    );
END
GO

IF OBJECT_ID(N'hr.Departamento', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Departamento
    (
        DepartamentoID  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Departamento PRIMARY KEY,
        Codigo          VARCHAR(20)  NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        Descripcion     NVARCHAR(300) NULL,
        CostoCentro     VARCHAR(30) NULL,
        IsActive        BIT NOT NULL CONSTRAINT DF_Departamento_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Departamento_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Departamento_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Departamento_Codigo UNIQUE (Codigo)
    );
END
GO

IF OBJECT_ID(N'hr.Puesto', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Puesto
    (
        PuestoID            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Puesto PRIMARY KEY,
        Codigo              VARCHAR(20)  NOT NULL,
        Nombre              NVARCHAR(120) NOT NULL,
        NivelJerarquico     TINYINT NOT NULL,  -- 1=Operativo ... 5=Dirección
        FamiliaPuesto       NVARCHAR(60) NOT NULL, -- Técnico, Administrativo, Comercial, etc.
        RequiereSupervisa   BIT NOT NULL CONSTRAINT DF_Puesto_ReqSup DEFAULT (0),
        IsActive            BIT NOT NULL CONSTRAINT DF_Puesto_IsActive DEFAULT (1),
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Puesto_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Puesto_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Puesto_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_Puesto_Nivel CHECK (NivelJerarquico BETWEEN 1 AND 5)
    );
END
GO

IF OBJECT_ID(N'hr.EscalaSalarial', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EscalaSalarial
    (
        EscalaSalarialID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EscalaSalarial PRIMARY KEY,
        Codigo              VARCHAR(20) NOT NULL,
        Grado               TINYINT NOT NULL,
        Descripcion         NVARCHAR(100) NOT NULL,
        SalarioMinimo       DECIMAL(12,2) NOT NULL,
        SalarioMedio        DECIMAL(12,2) NOT NULL,
        SalarioMaximo       DECIMAL(12,2) NOT NULL,
        Moneda              CHAR(3) NOT NULL CONSTRAINT DF_Escala_Moneda DEFAULT ('CRC'),
        VigenteDesde        DATE NOT NULL,
        VigenteHasta        DATE NULL,
        IsActive            BIT NOT NULL CONSTRAINT DF_Escala_IsActive DEFAULT (1),
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Escala_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Escala_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Escala_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_Escala_Rango CHECK (SalarioMinimo <= SalarioMedio AND SalarioMedio <= SalarioMaximo)
    );
END
GO

IF OBJECT_ID(N'hr.Habilidad', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Habilidad
    (
        HabilidadID     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Habilidad PRIMARY KEY,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        Categoria       NVARCHAR(50) NOT NULL, -- Técnica, Blandas, Idioma, Herramienta
        Descripcion     NVARCHAR(300) NULL,
        IsCritical      BIT NOT NULL CONSTRAINT DF_Habilidad_IsCritical DEFAULT (0),
        IsActive        BIT NOT NULL CONSTRAINT DF_Habilidad_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Habilidad_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Habilidad_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Habilidad_Codigo UNIQUE (Codigo)
    );
END
GO

IF OBJECT_ID(N'hr.NivelHabilidad', N'U') IS NULL
BEGIN
    CREATE TABLE hr.NivelHabilidad
    (
        NivelHabilidadID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_NivelHabilidad PRIMARY KEY,
        Codigo           VARCHAR(10) NOT NULL,
        Nombre           NVARCHAR(40) NOT NULL,
        ValorNumerico    TINYINT NOT NULL, -- 1..5
        CreatedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_NivelHab_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_NivelHab_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_NivelHab_Codigo UNIQUE (Codigo),
        CONSTRAINT CK_NivelHab_Valor CHECK (ValorNumerico BETWEEN 1 AND 5)
    );
END
GO

IF OBJECT_ID(N'hr.TipoAusencia', N'U') IS NULL
BEGIN
    CREATE TABLE hr.TipoAusencia
    (
        TipoAusenciaID  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TipoAusencia PRIMARY KEY,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(80) NOT NULL,
        EsRemunerada    BIT NOT NULL,
        AfectaProductividad BIT NOT NULL CONSTRAINT DF_TipoAus_Afecta DEFAULT (1),
        RequiereAprobacion  BIT NOT NULL CONSTRAINT DF_TipoAus_ReqAprob DEFAULT (1),
        IsActive        BIT NOT NULL CONSTRAINT DF_TipoAus_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_TipoAus_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_TipoAus_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_TipoAusencia_Codigo UNIQUE (Codigo)
    );
END
GO

IF OBJECT_ID(N'hr.MotivoSalida', N'U') IS NULL
BEGIN
    CREATE TABLE hr.MotivoSalida
    (
        MotivoSalidaID  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MotivoSalida PRIMARY KEY,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(100) NOT NULL,
        Categoria       NVARCHAR(40) NOT NULL, -- Voluntaria / Involuntaria
        EsEvitable      BIT NOT NULL CONSTRAINT DF_Motivo_EsEvitable DEFAULT (0),
        IsActive        BIT NOT NULL CONSTRAINT DF_Motivo_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Motivo_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Motivo_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_MotivoSalida_Codigo UNIQUE (Codigo)
    );
END
GO

IF OBJECT_ID(N'hr.EstadoEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EstadoEmpleado
    (
        EstadoEmpleadoID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EstadoEmpleado PRIMARY KEY,
        Codigo           VARCHAR(20) NOT NULL,
        Nombre           NVARCHAR(50) NOT NULL,
        EsActivoLaboral  BIT NOT NULL,
        CreatedAt        DATETIME2(0) NOT NULL CONSTRAINT DF_EstadoEmp_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_EstadoEmp_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_EstadoEmpleado_Codigo UNIQUE (Codigo)
    );
END
GO

/* Habilidades requeridas por puesto (gap analysis de talento) */
IF OBJECT_ID(N'hr.PuestoHabilidadRequerida', N'U') IS NULL
BEGIN
    CREATE TABLE hr.PuestoHabilidadRequerida
    (
        PuestoHabilidadID       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PuestoHabReq PRIMARY KEY,
        PuestoID                INT NOT NULL,
        HabilidadID             INT NOT NULL,
        NivelMinimoRequeridoID  INT NOT NULL,
        EsObligatoria           BIT NOT NULL CONSTRAINT DF_PuestoHab_Oblig DEFAULT (1),
        CreatedAt               DATETIME2(0) NOT NULL CONSTRAINT DF_PuestoHab_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt              DATETIME2(0) NOT NULL CONSTRAINT DF_PuestoHab_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_PuestoHab UNIQUE (PuestoID, HabilidadID),
        CONSTRAINT FK_PuestoHab_Puesto FOREIGN KEY (PuestoID) REFERENCES hr.Puesto(PuestoID),
        CONSTRAINT FK_PuestoHab_Habilidad FOREIGN KEY (HabilidadID) REFERENCES hr.Habilidad(HabilidadID),
        CONSTRAINT FK_PuestoHab_Nivel FOREIGN KEY (NivelMinimoRequeridoID) REFERENCES hr.NivelHabilidad(NivelHabilidadID)
    );
END
GO

/* -------------------------------------------------------------------------- */
/* 2. EMPLEADOS Y TRANSACCIONES                                               */
/* -------------------------------------------------------------------------- */

IF OBJECT_ID(N'hr.Empleado', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Empleado
    (
        EmpleadoID          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Empleado PRIMARY KEY,
        NumeroEmpleado      VARCHAR(20) NOT NULL,
        Cedula              VARCHAR(20) NOT NULL,
        Nombre              NVARCHAR(80) NOT NULL,
        Apellido1           NVARCHAR(80) NOT NULL,
        Apellido2           NVARCHAR(80) NULL,
        FechaNacimiento     DATE NOT NULL,
        Genero              CHAR(1) NOT NULL, -- M/F/O
        EmailCorporativo    NVARCHAR(150) NOT NULL,
        Telefono            VARCHAR(30) NULL,
        FechaContratacion   DATE NOT NULL,
        FechaTerminacion    DATE NULL,
        EstadoEmpleadoID    INT NOT NULL,
        DepartamentoID      INT NOT NULL,
        PuestoID            INT NOT NULL,
        UbicacionID         INT NOT NULL,
        ManagerEmpleadoID   INT NULL,
        EscalaSalarialID    INT NOT NULL,
        SalarioActual       DECIMAL(12,2) NOT NULL,
        TipoContrato        VARCHAR(20) NOT NULL, -- Indefinido, Temporal, Servicios
        Jornada             VARCHAR(20) NOT NULL CONSTRAINT DF_Emp_Jornada DEFAULT ('Completa'),
        IsActive            BIT NOT NULL CONSTRAINT DF_Emp_IsActive DEFAULT (1),
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Emp_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Emp_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Empleado_Numero UNIQUE (NumeroEmpleado),
        CONSTRAINT UQ_Empleado_Cedula UNIQUE (Cedula),
        CONSTRAINT UQ_Empleado_Email UNIQUE (EmailCorporativo),
        CONSTRAINT CK_Empleado_Genero CHECK (Genero IN ('M','F','O')),
        CONSTRAINT CK_Empleado_Fechas CHECK (FechaTerminacion IS NULL OR FechaTerminacion >= FechaContratacion),
        CONSTRAINT FK_Emp_Estado FOREIGN KEY (EstadoEmpleadoID) REFERENCES hr.EstadoEmpleado(EstadoEmpleadoID),
        CONSTRAINT FK_Emp_Depto FOREIGN KEY (DepartamentoID) REFERENCES hr.Departamento(DepartamentoID),
        CONSTRAINT FK_Emp_Puesto FOREIGN KEY (PuestoID) REFERENCES hr.Puesto(PuestoID),
        CONSTRAINT FK_Emp_Ubicacion FOREIGN KEY (UbicacionID) REFERENCES hr.Ubicacion(UbicacionID),
        CONSTRAINT FK_Emp_Manager FOREIGN KEY (ManagerEmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Emp_Escala FOREIGN KEY (EscalaSalarialID) REFERENCES hr.EscalaSalarial(EscalaSalarialID)
    );
END
GO

/* Historial de asignaciones (fuente natural SCD2 para DimEmpleado / DimAsignacion) */
IF OBJECT_ID(N'hr.EmpleadoAsignacionHistorial', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EmpleadoAsignacionHistorial
    (
        AsignacionHistorialID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmpAsigHist PRIMARY KEY,
        EmpleadoID            INT NOT NULL,
        DepartamentoID        INT NOT NULL,
        PuestoID              INT NOT NULL,
        UbicacionID           INT NOT NULL,
        ManagerEmpleadoID     INT NULL,
        EscalaSalarialID      INT NOT NULL,
        Salario               DECIMAL(12,2) NOT NULL,
        MotivoCambio          NVARCHAR(100) NOT NULL, -- Contratación, Ascenso, Transferencia, Ajuste, etc.
        FechaInicio           DATE NOT NULL,
        FechaFin              DATE NULL,
        EsActual              BIT NOT NULL CONSTRAINT DF_Asig_EsActual DEFAULT (1),
        CreatedAt             DATETIME2(0) NOT NULL CONSTRAINT DF_Asig_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt            DATETIME2(0) NOT NULL CONSTRAINT DF_Asig_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_Asig_Fechas CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio),
        CONSTRAINT FK_Asig_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Asig_Depto FOREIGN KEY (DepartamentoID) REFERENCES hr.Departamento(DepartamentoID),
        CONSTRAINT FK_Asig_Puesto FOREIGN KEY (PuestoID) REFERENCES hr.Puesto(PuestoID),
        CONSTRAINT FK_Asig_Ubic FOREIGN KEY (UbicacionID) REFERENCES hr.Ubicacion(UbicacionID),
        CONSTRAINT FK_Asig_Mgr FOREIGN KEY (ManagerEmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Asig_Escala FOREIGN KEY (EscalaSalarialID) REFERENCES hr.EscalaSalarial(EscalaSalarialID)
    );
END
GO

IF OBJECT_ID(N'hr.HistorialSalarial', N'U') IS NULL
BEGIN
    CREATE TABLE hr.HistorialSalarial
    (
        HistorialSalarialID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_HistSal PRIMARY KEY,
        EmpleadoID          INT NOT NULL,
        EscalaSalarialID    INT NOT NULL,
        SalarioAnterior     DECIMAL(12,2) NULL,
        SalarioNuevo        DECIMAL(12,2) NOT NULL,
        PorcentajeCambio    AS (CASE WHEN SalarioAnterior IS NULL OR SalarioAnterior = 0 THEN NULL
                                     ELSE ROUND(((SalarioNuevo - SalarioAnterior) / SalarioAnterior) * 100.0, 2) END) PERSISTED,
        Motivo              NVARCHAR(100) NOT NULL, -- Ingreso, Aumento meritocrático, Inflación, Ascenso, Corrección
        FechaEfectiva       DATE NOT NULL,
        AprobadoPor         INT NULL,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_HistSal_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_HistSal_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_HistSal_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_HistSal_Escala FOREIGN KEY (EscalaSalarialID) REFERENCES hr.EscalaSalarial(EscalaSalarialID),
        CONSTRAINT FK_HistSal_Aprob FOREIGN KEY (AprobadoPor) REFERENCES hr.Empleado(EmpleadoID)
    );
END
GO

IF OBJECT_ID(N'hr.EmpleadoHabilidad', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EmpleadoHabilidad
    (
        EmpleadoHabilidadID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmpHab PRIMARY KEY,
        EmpleadoID          INT NOT NULL,
        HabilidadID         INT NOT NULL,
        NivelHabilidadID    INT NOT NULL,
        FechaEvaluacion     DATE NOT NULL,
        FuenteEvaluacion    NVARCHAR(40) NOT NULL, -- Autoevaluación, Manager, Certificación, RH
        Certificado         BIT NOT NULL CONSTRAINT DF_EmpHab_Cert DEFAULT (0),
        IsActive            BIT NOT NULL CONSTRAINT DF_EmpHab_IsActive DEFAULT (1),
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_EmpHab_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_EmpHab_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_EmpHab UNIQUE (EmpleadoID, HabilidadID),
        CONSTRAINT FK_EmpHab_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_EmpHab_Hab FOREIGN KEY (HabilidadID) REFERENCES hr.Habilidad(HabilidadID),
        CONSTRAINT FK_EmpHab_Nivel FOREIGN KEY (NivelHabilidadID) REFERENCES hr.NivelHabilidad(NivelHabilidadID)
    );
END
GO

IF OBJECT_ID(N'hr.Capacitacion', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Capacitacion
    (
        CapacitacionID  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Capacitacion PRIMARY KEY,
        Codigo          VARCHAR(20) NOT NULL,
        Nombre          NVARCHAR(150) NOT NULL,
        Proveedor       NVARCHAR(100) NULL,
        Modalidad       VARCHAR(30) NOT NULL, -- Presencial, Virtual, Híbrida
        HorasDuracion   DECIMAL(6,1) NOT NULL,
        HabilidadID     INT NULL, -- habilidad principal que desarrolla
        CostoEstimado   DECIMAL(12,2) NULL,
        IsActive        BIT NOT NULL CONSTRAINT DF_Cap_IsActive DEFAULT (1),
        CreatedAt       DATETIME2(0) NOT NULL CONSTRAINT DF_Cap_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Cap_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Capacitacion_Codigo UNIQUE (Codigo),
        CONSTRAINT FK_Cap_Habilidad FOREIGN KEY (HabilidadID) REFERENCES hr.Habilidad(HabilidadID)
    );
END
GO

IF OBJECT_ID(N'hr.EmpleadoCapacitacion', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EmpleadoCapacitacion
    (
        EmpleadoCapacitacionID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmpCap PRIMARY KEY,
        EmpleadoID             INT NOT NULL,
        CapacitacionID         INT NOT NULL,
        FechaInicio            DATE NOT NULL,
        FechaFin               DATE NULL,
        Estado                 VARCHAR(20) NOT NULL, -- Inscrito, EnCurso, Completado, Abandonado
        Calificacion           DECIMAL(5,2) NULL,
        CostoReal              DECIMAL(12,2) NULL,
        CreatedAt              DATETIME2(0) NOT NULL CONSTRAINT DF_EmpCap_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt             DATETIME2(0) NOT NULL CONSTRAINT DF_EmpCap_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_EmpCap_Estado CHECK (Estado IN ('Inscrito','EnCurso','Completado','Abandonado')),
        CONSTRAINT FK_EmpCap_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_EmpCap_Cap FOREIGN KEY (CapacitacionID) REFERENCES hr.Capacitacion(CapacitacionID)
    );
END
GO

IF OBJECT_ID(N'hr.Ausencia', N'U') IS NULL
BEGIN
    CREATE TABLE hr.Ausencia
    (
        AusenciaID          INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Ausencia PRIMARY KEY,
        EmpleadoID          INT NOT NULL,
        TipoAusenciaID      INT NOT NULL,
        FechaInicio         DATE NOT NULL,
        FechaFin            DATE NOT NULL,
        DiasLaborales       DECIMAL(5,1) NOT NULL,
        Estado              VARCHAR(20) NOT NULL, -- Solicitada, Aprobada, Rechazada, Cancelada
        MotivoDetalle       NVARCHAR(300) NULL,
        AprobadoPor         INT NULL,
        FechaSolicitud      DATE NOT NULL,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Aus_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Aus_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_Aus_Fechas CHECK (FechaFin >= FechaInicio),
        CONSTRAINT CK_Aus_Estado CHECK (Estado IN ('Solicitada','Aprobada','Rechazada','Cancelada')),
        CONSTRAINT FK_Aus_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Aus_Tipo FOREIGN KEY (TipoAusenciaID) REFERENCES hr.TipoAusencia(TipoAusenciaID),
        CONSTRAINT FK_Aus_Aprob FOREIGN KEY (AprobadoPor) REFERENCES hr.Empleado(EmpleadoID)
    );
END
GO

IF OBJECT_ID(N'hr.SalidaEmpleado', N'U') IS NULL
BEGIN
    CREATE TABLE hr.SalidaEmpleado
    (
        SalidaEmpleadoID    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Salida PRIMARY KEY,
        EmpleadoID          INT NOT NULL,
        MotivoSalidaID      INT NOT NULL,
        FechaSalida         DATE NOT NULL,
        TipoSalida          VARCHAR(20) NOT NULL, -- Renuncia, Despido, MutuoAcuerdo, Jubilacion, FinContrato
        AntiguedadAnios     AS (NULL), -- calculado en ETL / vistas
        EntrevistaSalida    BIT NOT NULL CONSTRAINT DF_Salida_Entrevista DEFAULT (0),
        ComentarioSalida    NVARCHAR(500) NULL,
        Recontratable       BIT NOT NULL CONSTRAINT DF_Salida_Recontratable DEFAULT (1),
        DepartamentoID      INT NOT NULL, -- snapshot al momento de salida
        PuestoID            INT NOT NULL,
        UbicacionID         INT NOT NULL,
        ManagerEmpleadoID   INT NULL,
        SalarioAlSalir      DECIMAL(12,2) NOT NULL,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Salida_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Salida_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT UQ_Salida_Empleado UNIQUE (EmpleadoID),
        CONSTRAINT CK_Salida_Tipo CHECK (TipoSalida IN ('Renuncia','Despido','MutuoAcuerdo','Jubilacion','FinContrato')),
        CONSTRAINT FK_Salida_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Salida_Motivo FOREIGN KEY (MotivoSalidaID) REFERENCES hr.MotivoSalida(MotivoSalidaID),
        CONSTRAINT FK_Salida_Depto FOREIGN KEY (DepartamentoID) REFERENCES hr.Departamento(DepartamentoID),
        CONSTRAINT FK_Salida_Puesto FOREIGN KEY (PuestoID) REFERENCES hr.Puesto(PuestoID),
        CONSTRAINT FK_Salida_Ubic FOREIGN KEY (UbicacionID) REFERENCES hr.Ubicacion(UbicacionID),
        CONSTRAINT FK_Salida_Mgr FOREIGN KEY (ManagerEmpleadoID) REFERENCES hr.Empleado(EmpleadoID)
    );
END
GO

IF OBJECT_ID(N'hr.EvaluacionDesempeno', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EvaluacionDesempeno
    (
        EvaluacionID        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Eval PRIMARY KEY,
        EmpleadoID          INT NOT NULL,
        PeriodoAnio         SMALLINT NOT NULL,
        PeriodoCiclo        VARCHAR(20) NOT NULL, -- Semestral1, Semestral2, Anual
        FechaEvaluacion     DATE NOT NULL,
        PuntajeGlobal       DECIMAL(4,2) NOT NULL, -- 1.00 a 5.00
        CalificacionTexto   VARCHAR(30) NOT NULL, -- Bajo, Esperado, Destacado, Excepcional
        EvaluadorEmpleadoID INT NULL,
        Comentarios         NVARCHAR(400) NULL,
        CreatedAt           DATETIME2(0) NOT NULL CONSTRAINT DF_Eval_CreatedAt DEFAULT (SYSUTCDATETIME()),
        ModifiedAt          DATETIME2(0) NOT NULL CONSTRAINT DF_Eval_ModifiedAt DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_Eval_Puntaje CHECK (PuntajeGlobal BETWEEN 1 AND 5),
        CONSTRAINT UQ_Eval_Periodo UNIQUE (EmpleadoID, PeriodoAnio, PeriodoCiclo),
        CONSTRAINT FK_Eval_Emp FOREIGN KEY (EmpleadoID) REFERENCES hr.Empleado(EmpleadoID),
        CONSTRAINT FK_Eval_Evaldr FOREIGN KEY (EvaluadorEmpleadoID) REFERENCES hr.Empleado(EmpleadoID)
    );
END
GO

/* Tabla de control ETL / watermark (útil para cargas incrementales desde SSIS) */
IF OBJECT_ID(N'hr.EtlWatermark', N'U') IS NULL
BEGIN
    CREATE TABLE hr.EtlWatermark
    (
        TablaFuente     SYSNAME NOT NULL CONSTRAINT PK_EtlWatermark PRIMARY KEY,
        UltimoModifiedAt DATETIME2(0) NOT NULL,
        UltimaEjecucion  DATETIME2(0) NOT NULL CONSTRAINT DF_EtlWm_Ejec DEFAULT (SYSUTCDATETIME()),
        FilasProcesadas  INT NOT NULL CONSTRAINT DF_EtlWm_Filas DEFAULT (0),
        Notas            NVARCHAR(200) NULL
    );
END
GO

/* -------------------------------------------------------------------------- */
/* 3. ÍNDICES PARA ETL Y CONSULTAS TRANSACCIONALES                            */
/* -------------------------------------------------------------------------- */

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Empleado_ModifiedAt' AND object_id = OBJECT_ID(N'hr.Empleado'))
    CREATE INDEX IX_Empleado_ModifiedAt ON hr.Empleado(ModifiedAt) INCLUDE (EmpleadoID, DepartamentoID, EstadoEmpleadoID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Ausencia_ModifiedAt' AND object_id = OBJECT_ID(N'hr.Ausencia'))
    CREATE INDEX IX_Ausencia_ModifiedAt ON hr.Ausencia(ModifiedAt) INCLUDE (EmpleadoID, TipoAusenciaID, FechaInicio);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Ausencia_Fechas' AND object_id = OBJECT_ID(N'hr.Ausencia'))
    CREATE INDEX IX_Ausencia_Fechas ON hr.Ausencia(FechaInicio, FechaFin) INCLUDE (EmpleadoID, DiasLaborales, Estado);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_HistSal_ModifiedAt' AND object_id = OBJECT_ID(N'hr.HistorialSalarial'))
    CREATE INDEX IX_HistSal_ModifiedAt ON hr.HistorialSalarial(ModifiedAt) INCLUDE (EmpleadoID, FechaEfectiva);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Salida_ModifiedAt' AND object_id = OBJECT_ID(N'hr.SalidaEmpleado'))
    CREATE INDEX IX_Salida_ModifiedAt ON hr.SalidaEmpleado(ModifiedAt) INCLUDE (FechaSalida, MotivoSalidaID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_EmpHab_ModifiedAt' AND object_id = OBJECT_ID(N'hr.EmpleadoHabilidad'))
    CREATE INDEX IX_EmpHab_ModifiedAt ON hr.EmpleadoHabilidad(ModifiedAt) INCLUDE (EmpleadoID, HabilidadID, NivelHabilidadID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_AsigHist_EmpActual' AND object_id = OBJECT_ID(N'hr.EmpleadoAsignacionHistorial'))
    CREATE INDEX IX_AsigHist_EmpActual ON hr.EmpleadoAsignacionHistorial(EmpleadoID, EsActual) INCLUDE (FechaInicio, DepartamentoID, PuestoID);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Emp_DeptoEstado' AND object_id = OBJECT_ID(N'hr.Empleado'))
    CREATE INDEX IX_Emp_DeptoEstado ON hr.Empleado(DepartamentoID, EstadoEmpleadoID) INCLUDE (SalarioActual, PuestoID, FechaContratacion);
GO

PRINT N'DDL HR_Sintetico creado correctamente.';
GO
