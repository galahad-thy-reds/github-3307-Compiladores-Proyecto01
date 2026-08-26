/*
================================================================================
  Helpers ETL (referencia T-SQL) — espejo de docs/Guia_SSIS_PowerBI.md
  Útiles como:
    - Lógica a portar a Data Flows SSIS
    - Prototipo ejecutable antes de armar paquetes
    - Defensa del TFG (mostrar Full vs Incremental)

  Prerrequisitos: HR_Sintetico + HR_Staging + HR_DataMart instalados.
================================================================================
*/
USE HR_Staging;
GO

/* -------------------------------------------------------------------------- */
/* FULL: OLTP → Staging                                                       */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_Full_ExtractOltpToStaging
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchID IS NULL SET @BatchID = NEWID();

    INSERT INTO stg.EtlBatchLog (BatchID, PackageName, LoadType, StartUTC, Status)
    VALUES (@BatchID, N'stg.usp_Full_ExtractOltpToStaging', 'Full', SYSUTCDATETIME(), 'Running');

    TRUNCATE TABLE stg.Departamento;
    TRUNCATE TABLE stg.Puesto;
    TRUNCATE TABLE stg.Ubicacion;
    TRUNCATE TABLE stg.Habilidad;
    TRUNCATE TABLE stg.NivelHabilidad;
    TRUNCATE TABLE stg.TipoAusencia;
    TRUNCATE TABLE stg.MotivoSalida;
    TRUNCATE TABLE stg.EscalaSalarial;
    TRUNCATE TABLE stg.PuestoHabilidadRequerida;
    TRUNCATE TABLE stg.Empleado;
    TRUNCATE TABLE stg.EmpleadoAsignacionHistorial;
    TRUNCATE TABLE stg.HistorialSalarial;
    TRUNCATE TABLE stg.EmpleadoHabilidad;
    TRUNCATE TABLE stg.Ausencia;
    TRUNCATE TABLE stg.SalidaEmpleado;

    INSERT INTO stg.Departamento (DepartamentoID, Codigo, Nombre, CostoCentro, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT DepartamentoID, Codigo, Nombre, CostoCentro, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.Departamento;

    INSERT INTO stg.Puesto (PuestoID, Codigo, Nombre, NivelJerarquico, FamiliaPuesto, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT PuestoID, Codigo, Nombre, NivelJerarquico, FamiliaPuesto, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.Puesto;

    INSERT INTO stg.Ubicacion (UbicacionID, Codigo, Nombre, Provincia, Pais, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT UbicacionID, Codigo, Nombre, Provincia, Pais, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.Ubicacion;

    INSERT INTO stg.Habilidad (HabilidadID, Codigo, Nombre, Categoria, IsCritical, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT HabilidadID, Codigo, Nombre, Categoria, IsCritical, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.Habilidad;

    INSERT INTO stg.NivelHabilidad (NivelHabilidadID, Codigo, Nombre, ValorNumerico, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT NivelHabilidadID, Codigo, Nombre, ValorNumerico, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.NivelHabilidad;

    INSERT INTO stg.TipoAusencia (TipoAusenciaID, Codigo, Nombre, EsRemunerada, AfectaProductividad, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT TipoAusenciaID, Codigo, Nombre, EsRemunerada, AfectaProductividad, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.TipoAusencia;

    INSERT INTO stg.MotivoSalida (MotivoSalidaID, Codigo, Nombre, Categoria, EsEvitable, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT MotivoSalidaID, Codigo, Nombre, Categoria, EsEvitable, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.MotivoSalida;

    INSERT INTO stg.EscalaSalarial (EscalaSalarialID, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EscalaSalarialID, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda, IsActive, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.EscalaSalarial;

    INSERT INTO stg.PuestoHabilidadRequerida (PuestoHabilidadID, PuestoID, HabilidadID, NivelMinimoRequeridoID, EsObligatoria, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT PuestoHabilidadID, PuestoID, HabilidadID, NivelMinimoRequeridoID, EsObligatoria, ModifiedAt, @BatchID, 'Full' FROM HR_Sintetico.hr.PuestoHabilidadRequerida;

    INSERT INTO stg.Empleado
    (EmpleadoID, NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero, EmailCorporativo,
     FechaContratacion, FechaTerminacion, EstadoEmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID,
     EscalaSalarialID, SalarioActual, TipoContrato, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EmpleadoID, NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero, EmailCorporativo,
           FechaContratacion, FechaTerminacion, EstadoEmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID,
           EscalaSalarialID, SalarioActual, TipoContrato, IsActive, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.Empleado;

    INSERT INTO stg.EmpleadoAsignacionHistorial
    (AsignacionHistorialID, EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
     Salario, MotivoCambio, FechaInicio, FechaFin, EsActual, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT AsignacionHistorialID, EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
           Salario, MotivoCambio, FechaInicio, FechaFin, EsActual, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.EmpleadoAsignacionHistorial;

    INSERT INTO stg.HistorialSalarial
    (HistorialSalarialID, EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT HistorialSalarialID, EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.HistorialSalarial;

    INSERT INTO stg.EmpleadoHabilidad
    (EmpleadoHabilidadID, EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EmpleadoHabilidadID, EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, IsActive, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.EmpleadoHabilidad;

    INSERT INTO stg.Ausencia
    (AusenciaID, EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT AusenciaID, EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.Ausencia;

    INSERT INTO stg.SalidaEmpleado
    (SalidaEmpleadoID, EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, DepartamentoID, PuestoID, UbicacionID,
     SalarioAlSalir, EntrevistaSalida, Recontratable, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT SalidaEmpleadoID, EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, DepartamentoID, PuestoID, UbicacionID,
           SalarioAlSalir, EntrevistaSalida, Recontratable, ModifiedAt, @BatchID, 'Full'
    FROM HR_Sintetico.hr.SalidaEmpleado;

    UPDATE stg.EtlBatchLog
    SET EndUTC = SYSUTCDATETIME(), Status = 'Success',
        RowsExtracted = (SELECT COUNT(*) FROM stg.Empleado WHERE LoadBatchID = @BatchID)
    WHERE BatchID = @BatchID;

    SELECT @BatchID AS BatchID, 'Full extract OK' AS Resultado;
END
GO

/* -------------------------------------------------------------------------- */
/* FULL: Staging → Data Mart (dims + hechos)                                  */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_Full_LoadStagingToDataMart
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    /* DimFecha */
    EXEC HR_DataMart.dm.usp_GenerarDimFecha @FechaInicio = '2019-01-01', @FechaFin = NULL;

    /* Dims catálogo — TRUNCATE + INSERT */
    TRUNCATE TABLE HR_DataMart.dm.FactHabilidadEmpleado;
    TRUNCATE TABLE HR_DataMart.dm.FactAusentismo;
    TRUNCATE TABLE HR_DataMart.dm.FactRotacion;
    TRUNCATE TABLE HR_DataMart.dm.FactHeadcountMensual;

    DELETE FROM HR_DataMart.dm.DimEmpleado;
    DELETE FROM HR_DataMart.dm.DimDepartamento;
    DELETE FROM HR_DataMart.dm.DimPuesto;
    DELETE FROM HR_DataMart.dm.DimUbicacion;
    DELETE FROM HR_DataMart.dm.DimHabilidad;
    DELETE FROM HR_DataMart.dm.DimTipoAusencia;
    DELETE FROM HR_DataMart.dm.DimMotivoSalida;
    DELETE FROM HR_DataMart.dm.DimEscalaSalarial;

    INSERT INTO HR_DataMart.dm.DimDepartamento (DepartamentoBK, Codigo, Nombre, CostoCentro)
    SELECT DepartamentoID, Codigo, Nombre, CostoCentro FROM stg.Departamento WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimPuesto (PuestoBK, Codigo, Nombre, NivelJerarquico, FamiliaPuesto)
    SELECT PuestoID, Codigo, Nombre, NivelJerarquico, FamiliaPuesto FROM stg.Puesto WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimUbicacion (UbicacionBK, Codigo, Nombre, Provincia, Pais)
    SELECT UbicacionID, Codigo, Nombre, Provincia, Pais FROM stg.Ubicacion WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimHabilidad (HabilidadBK, Codigo, Nombre, Categoria, IsCritical)
    SELECT HabilidadID, Codigo, Nombre, Categoria, IsCritical FROM stg.Habilidad WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimTipoAusencia (TipoAusenciaBK, Codigo, Nombre, EsRemunerada, AfectaProductividad)
    SELECT TipoAusenciaID, Codigo, Nombre, EsRemunerada, AfectaProductividad FROM stg.TipoAusencia WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimMotivoSalida (MotivoSalidaBK, Codigo, Nombre, Categoria, EsEvitable)
    SELECT MotivoSalidaID, Codigo, Nombre, Categoria, EsEvitable FROM stg.MotivoSalida WHERE LoadBatchID = @BatchID;

    INSERT INTO HR_DataMart.dm.DimEscalaSalarial
    (EscalaSalarialBK, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda)
    SELECT EscalaSalarialID, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda
    FROM stg.EscalaSalarial WHERE LoadBatchID = @BatchID;

    /* DimEmpleado (versión simplificada: 1 fila actual por empleado) */
    INSERT INTO HR_DataMart.dm.DimEmpleado
    (EmpleadoBK, NumeroEmpleado, NombreCompleto, Genero, FechaNacimiento, FechaContratacion, TipoContrato,
     FechaInicioValidez, FechaFinValidez, EsActual)
    SELECT
        EmpleadoID, NumeroEmpleado, CONCAT(Nombre, N' ', Apellido1), Genero, FechaNacimiento,
        FechaContratacion, TipoContrato, CAST(FechaContratacion AS DATETIME2(0)), NULL, 1
    FROM stg.Empleado WHERE LoadBatchID = @BatchID;

    /* FactRotacion */
    INSERT INTO HR_DataMart.dm.FactRotacion
    (FechaSalidaKey, EmpleadoKey, DepartamentoKey, PuestoKey, UbicacionKey, MotivoSalidaKey,
     AntiguedadMeses, SalarioAlSalir, ContadorSalida, EsEvitable)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), s.FechaSalida, 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, du.UbicacionKey, dm.MotivoSalidaKey,
        DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida),
        s.SalarioAlSalir, 1, dm.EsEvitable
    FROM stg.SalidaEmpleado s
    INNER JOIN stg.Empleado e ON e.EmpleadoID = s.EmpleadoID AND e.LoadBatchID = s.LoadBatchID
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = s.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = s.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = s.PuestoID
    INNER JOIN HR_DataMart.dm.DimUbicacion du ON du.UbicacionBK = s.UbicacionID
    INNER JOIN HR_DataMart.dm.DimMotivoSalida dm ON dm.MotivoSalidaBK = s.MotivoSalidaID
    WHERE s.LoadBatchID = @BatchID;

    /* FactAusentismo */
    INSERT INTO HR_DataMart.dm.FactAusentismo
    (FechaInicioKey, FechaFinKey, EmpleadoKey, DepartamentoKey, PuestoKey, TipoAusenciaKey,
     DiasLaborales, ContadorEvento, AfectaProductividad)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), a.FechaInicio, 112)),
        CONVERT(INT, CONVERT(CHAR(8), a.FechaFin, 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, dt.TipoAusenciaKey,
        a.DiasLaborales, 1, dt.AfectaProductividad
    FROM stg.Ausencia a
    INNER JOIN stg.Empleado e ON e.EmpleadoID = a.EmpleadoID AND e.LoadBatchID = a.LoadBatchID
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = a.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = e.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = e.PuestoID
    INNER JOIN HR_DataMart.dm.DimTipoAusencia dt ON dt.TipoAusenciaBK = a.TipoAusenciaID
    WHERE a.LoadBatchID = @BatchID AND a.Estado = 'Aprobada';

    /* FactHabilidadEmpleado (gap) */
    INSERT INTO HR_DataMart.dm.FactHabilidadEmpleado
    (FechaEvaluacionKey, EmpleadoKey, DepartamentoKey, PuestoKey, HabilidadKey,
     NivelActual, NivelRequerido, TieneGap, DiferenciaNiveles, EsCritica, EsObligatoria)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), ISNULL(eh.FechaEvaluacion, CAST(GETDATE() AS DATE)), 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, dh.HabilidadKey,
        nact.ValorNumerico,
        nreq.ValorNumerico,
        CASE WHEN ISNULL(nact.ValorNumerico, 0) >= nreq.ValorNumerico THEN 0 ELSE 1 END,
        nreq.ValorNumerico - ISNULL(nact.ValorNumerico, 0),
        dh.IsCritical,
        ph.EsObligatoria
    FROM stg.Empleado e
    INNER JOIN stg.PuestoHabilidadRequerida ph ON ph.PuestoID = e.PuestoID AND ph.LoadBatchID = e.LoadBatchID
    INNER JOIN stg.NivelHabilidad nreq ON nreq.NivelHabilidadID = ph.NivelMinimoRequeridoID AND nreq.LoadBatchID = e.LoadBatchID
    LEFT JOIN stg.EmpleadoHabilidad eh
        ON eh.EmpleadoID = e.EmpleadoID AND eh.HabilidadID = ph.HabilidadID
       AND eh.LoadBatchID = e.LoadBatchID AND eh.IsActive = 1
    LEFT JOIN stg.NivelHabilidad nact ON nact.NivelHabilidadID = eh.NivelHabilidadID AND nact.LoadBatchID = e.LoadBatchID
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = e.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = e.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = e.PuestoID
    INNER JOIN HR_DataMart.dm.DimHabilidad dh ON dh.HabilidadBK = ph.HabilidadID
    WHERE e.LoadBatchID = @BatchID AND e.IsActive = 1;

    /* FactHeadcountMensual — últimos 24 meses, empleados vigentes en cada mes */
    ;WITH Meses AS (
        SELECT DATEFROMPARTS(YEAR(DATEADD(MONTH, -v.n, GETDATE())), MONTH(DATEADD(MONTH, -v.n, GETDATE())), 1) AS Periodo
        FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),
                     (12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23)) v(n)
    )
    INSERT INTO HR_DataMart.dm.FactHeadcountMensual
    (FechaKey, EmpleadoKey, DepartamentoKey, PuestoKey, UbicacionKey, EscalaSalarialKey,
     Salario, EsActivo, AntiguedadMeses)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), m.Periodo, 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, du.UbicacionKey, ds.EscalaSalarialKey,
        e.SalarioActual,
        1,
        DATEDIFF(MONTH, e.FechaContratacion, m.Periodo)
    FROM Meses m
    INNER JOIN stg.Empleado e ON e.LoadBatchID = @BatchID
        AND e.FechaContratacion <= EOMONTH(m.Periodo)
        AND (e.FechaTerminacion IS NULL OR e.FechaTerminacion > m.Periodo)
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = e.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = e.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = e.PuestoID
    INNER JOIN HR_DataMart.dm.DimUbicacion du ON du.UbicacionBK = e.UbicacionID
    INNER JOIN HR_DataMart.dm.DimEscalaSalarial ds ON ds.EscalaSalarialBK = e.EscalaSalarialID;

    /* Inicializar watermarks al MAX del origen */
    UPDATE w SET
        UltimoModifiedAt = ISNULL(x.MaxMod, '1900-01-01'),
        UltimaEjecucion = SYSUTCDATETIME(),
        FilasProcesadas = ISNULL(x.Cnt, 0),
        Notas = N'Baseline post FULL'
    FROM HR_Sintetico.hr.EtlWatermark w
    OUTER APPLY (
        SELECT
            CASE w.TablaFuente
                WHEN N'hr.Empleado' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.Empleado)
                WHEN N'hr.Ausencia' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.Ausencia)
                WHEN N'hr.SalidaEmpleado' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.SalidaEmpleado)
                WHEN N'hr.EmpleadoHabilidad' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.EmpleadoHabilidad)
                WHEN N'hr.HistorialSalarial' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.HistorialSalarial)
                WHEN N'hr.EmpleadoAsignacionHistorial' THEN (SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.EmpleadoAsignacionHistorial)
            END AS MaxMod,
            CASE w.TablaFuente
                WHEN N'hr.Empleado' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.Empleado)
                WHEN N'hr.Ausencia' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.Ausencia)
                WHEN N'hr.SalidaEmpleado' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.SalidaEmpleado)
                WHEN N'hr.EmpleadoHabilidad' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.EmpleadoHabilidad)
                WHEN N'hr.HistorialSalarial' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.HistorialSalarial)
                WHEN N'hr.EmpleadoAsignacionHistorial' THEN (SELECT COUNT(*) FROM HR_Sintetico.hr.EmpleadoAsignacionHistorial)
            END AS Cnt
    ) x
    WHERE w.TablaFuente IN (
        N'hr.Empleado', N'hr.Ausencia', N'hr.SalidaEmpleado',
        N'hr.EmpleadoHabilidad', N'hr.HistorialSalarial', N'hr.EmpleadoAsignacionHistorial'
    );

    SELECT
        (SELECT COUNT(*) FROM HR_DataMart.dm.DimEmpleado) AS DimEmpleado,
        (SELECT COUNT(*) FROM HR_DataMart.dm.FactRotacion) AS FactRotacion,
        (SELECT COUNT(*) FROM HR_DataMart.dm.FactAusentismo) AS FactAusentismo,
        (SELECT COUNT(*) FROM HR_DataMart.dm.FactHabilidadEmpleado) AS FactHabilidad,
        (SELECT COUNT(*) FROM HR_DataMart.dm.FactHeadcountMensual) AS FactHeadcount;
END
GO

/* -------------------------------------------------------------------------- */
/* INCREMENTAL: OLTP → Staging                                                */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_Inc_ExtractOltpToStaging
    @BatchID UNIQUEIDENTIFIER = NULL,
    @TruncateLanding BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchID IS NULL SET @BatchID = NEWID();

    INSERT INTO stg.EtlBatchLog (BatchID, PackageName, LoadType, StartUTC, Status)
    VALUES (@BatchID, N'stg.usp_Inc_ExtractOltpToStaging', 'Incremental', SYSUTCDATETIME(), 'Running');

    IF @TruncateLanding = 1
    BEGIN
        TRUNCATE TABLE stg.Empleado;
        TRUNCATE TABLE stg.EmpleadoAsignacionHistorial;
        TRUNCATE TABLE stg.HistorialSalarial;
        TRUNCATE TABLE stg.EmpleadoHabilidad;
        TRUNCATE TABLE stg.Ausencia;
        TRUNCATE TABLE stg.SalidaEmpleado;
        TRUNCATE TABLE stg.Departamento;
        TRUNCATE TABLE stg.Puesto;
        TRUNCATE TABLE stg.Ubicacion;
        TRUNCATE TABLE stg.Habilidad;
        TRUNCATE TABLE stg.TipoAusencia;
        TRUNCATE TABLE stg.MotivoSalida;
        TRUNCATE TABLE stg.EscalaSalarial;
        TRUNCATE TABLE stg.NivelHabilidad;
        TRUNCATE TABLE stg.PuestoHabilidadRequerida;
    END

    DECLARE @wm DATETIME2(0);

    /* Catálogos: en incremental PoC se reextraen completos (volumen bajo) */
    INSERT INTO stg.Departamento (DepartamentoID, Codigo, Nombre, CostoCentro, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT DepartamentoID, Codigo, Nombre, CostoCentro, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.Departamento;
    INSERT INTO stg.Puesto (PuestoID, Codigo, Nombre, NivelJerarquico, FamiliaPuesto, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT PuestoID, Codigo, Nombre, NivelJerarquico, FamiliaPuesto, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.Puesto;
    INSERT INTO stg.Ubicacion (UbicacionID, Codigo, Nombre, Provincia, Pais, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT UbicacionID, Codigo, Nombre, Provincia, Pais, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.Ubicacion;
    INSERT INTO stg.Habilidad (HabilidadID, Codigo, Nombre, Categoria, IsCritical, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT HabilidadID, Codigo, Nombre, Categoria, IsCritical, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.Habilidad;
    INSERT INTO stg.NivelHabilidad (NivelHabilidadID, Codigo, Nombre, ValorNumerico, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT NivelHabilidadID, Codigo, Nombre, ValorNumerico, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.NivelHabilidad;
    INSERT INTO stg.TipoAusencia (TipoAusenciaID, Codigo, Nombre, EsRemunerada, AfectaProductividad, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT TipoAusenciaID, Codigo, Nombre, EsRemunerada, AfectaProductividad, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.TipoAusencia;
    INSERT INTO stg.MotivoSalida (MotivoSalidaID, Codigo, Nombre, Categoria, EsEvitable, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT MotivoSalidaID, Codigo, Nombre, Categoria, EsEvitable, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.MotivoSalida;
    INSERT INTO stg.EscalaSalarial (EscalaSalarialID, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EscalaSalarialID, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda, IsActive, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.EscalaSalarial;
    INSERT INTO stg.PuestoHabilidadRequerida (PuestoHabilidadID, PuestoID, HabilidadID, NivelMinimoRequeridoID, EsObligatoria, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT PuestoHabilidadID, PuestoID, HabilidadID, NivelMinimoRequeridoID, EsObligatoria, ModifiedAt, @BatchID, 'Incremental' FROM HR_Sintetico.hr.PuestoHabilidadRequerida;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.Empleado';
    INSERT INTO stg.Empleado
    (EmpleadoID, NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero, EmailCorporativo,
     FechaContratacion, FechaTerminacion, EstadoEmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID,
     EscalaSalarialID, SalarioActual, TipoContrato, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EmpleadoID, NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero, EmailCorporativo,
           FechaContratacion, FechaTerminacion, EstadoEmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID,
           EscalaSalarialID, SalarioActual, TipoContrato, IsActive, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.Empleado WHERE ModifiedAt > @wm;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.EmpleadoAsignacionHistorial';
    INSERT INTO stg.EmpleadoAsignacionHistorial
    (AsignacionHistorialID, EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
     Salario, MotivoCambio, FechaInicio, FechaFin, EsActual, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT AsignacionHistorialID, EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
           Salario, MotivoCambio, FechaInicio, FechaFin, EsActual, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.EmpleadoAsignacionHistorial WHERE ModifiedAt > @wm;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.HistorialSalarial';
    INSERT INTO stg.HistorialSalarial
    (HistorialSalarialID, EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT HistorialSalarialID, EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.HistorialSalarial WHERE ModifiedAt > @wm;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.EmpleadoHabilidad';
    INSERT INTO stg.EmpleadoHabilidad
    (EmpleadoHabilidadID, EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, IsActive, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT EmpleadoHabilidadID, EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, IsActive, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.EmpleadoHabilidad WHERE ModifiedAt > @wm;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.Ausencia';
    INSERT INTO stg.Ausencia
    (AusenciaID, EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT AusenciaID, EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.Ausencia WHERE ModifiedAt > @wm;

    SELECT @wm = UltimoModifiedAt FROM HR_Sintetico.hr.EtlWatermark WHERE TablaFuente = N'hr.SalidaEmpleado';
    INSERT INTO stg.SalidaEmpleado
    (SalidaEmpleadoID, EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, DepartamentoID, PuestoID, UbicacionID,
     SalarioAlSalir, EntrevistaSalida, Recontratable, SrcModifiedAt, LoadBatchID, LoadType)
    SELECT SalidaEmpleadoID, EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, DepartamentoID, PuestoID, UbicacionID,
           SalarioAlSalir, EntrevistaSalida, Recontratable, ModifiedAt, @BatchID, 'Incremental'
    FROM HR_Sintetico.hr.SalidaEmpleado WHERE ModifiedAt > @wm;

    UPDATE stg.EtlBatchLog
    SET EndUTC = SYSUTCDATETIME(), Status = 'Success',
        RowsExtracted = (SELECT COUNT(*) FROM stg.Ausencia WHERE LoadBatchID = @BatchID)
                      + (SELECT COUNT(*) FROM stg.Empleado WHERE LoadBatchID = @BatchID)
                      + (SELECT COUNT(*) FROM stg.SalidaEmpleado WHERE LoadBatchID = @BatchID)
    WHERE BatchID = @BatchID;

    SELECT @BatchID AS BatchID,
           (SELECT COUNT(*) FROM stg.Empleado WHERE LoadBatchID = @BatchID) AS EmpDelta,
           (SELECT COUNT(*) FROM stg.Ausencia WHERE LoadBatchID = @BatchID) AS AusDelta,
           (SELECT COUNT(*) FROM stg.SalidaEmpleado WHERE LoadBatchID = @BatchID) AS SalDelta;
END
GO

/* -------------------------------------------------------------------------- */
/* INCREMENTAL: Staging → Data Mart                                           */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_Inc_LoadStagingToDataMart
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

    /* Dims catálogo SCD1 */
    MERGE HR_DataMart.dm.DimDepartamento AS t
    USING (SELECT DepartamentoID AS DepartamentoBK, Codigo, Nombre, CostoCentro FROM stg.Departamento WHERE LoadBatchID = @BatchID) s
    ON t.DepartamentoBK = s.DepartamentoBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.CostoCentro=s.CostoCentro
    WHEN NOT MATCHED THEN INSERT (DepartamentoBK, Codigo, Nombre, CostoCentro)
         VALUES (s.DepartamentoBK, s.Codigo, s.Nombre, s.CostoCentro);

    MERGE HR_DataMart.dm.DimPuesto AS t
    USING (SELECT PuestoID AS PuestoBK, Codigo, Nombre, NivelJerarquico, FamiliaPuesto FROM stg.Puesto WHERE LoadBatchID = @BatchID) s
    ON t.PuestoBK = s.PuestoBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.NivelJerarquico=s.NivelJerarquico, t.FamiliaPuesto=s.FamiliaPuesto
    WHEN NOT MATCHED THEN INSERT (PuestoBK, Codigo, Nombre, NivelJerarquico, FamiliaPuesto)
         VALUES (s.PuestoBK, s.Codigo, s.Nombre, s.NivelJerarquico, s.FamiliaPuesto);

    MERGE HR_DataMart.dm.DimUbicacion AS t
    USING (SELECT UbicacionID AS UbicacionBK, Codigo, Nombre, Provincia, Pais FROM stg.Ubicacion WHERE LoadBatchID = @BatchID) s
    ON t.UbicacionBK = s.UbicacionBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.Provincia=s.Provincia, t.Pais=s.Pais
    WHEN NOT MATCHED THEN INSERT (UbicacionBK, Codigo, Nombre, Provincia, Pais)
         VALUES (s.UbicacionBK, s.Codigo, s.Nombre, s.Provincia, s.Pais);

    MERGE HR_DataMart.dm.DimHabilidad AS t
    USING (SELECT HabilidadID AS HabilidadBK, Codigo, Nombre, Categoria, IsCritical FROM stg.Habilidad WHERE LoadBatchID = @BatchID) s
    ON t.HabilidadBK = s.HabilidadBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.Categoria=s.Categoria, t.IsCritical=s.IsCritical
    WHEN NOT MATCHED THEN INSERT (HabilidadBK, Codigo, Nombre, Categoria, IsCritical)
         VALUES (s.HabilidadBK, s.Codigo, s.Nombre, s.Categoria, s.IsCritical);

    MERGE HR_DataMart.dm.DimTipoAusencia AS t
    USING (SELECT TipoAusenciaID AS TipoAusenciaBK, Codigo, Nombre, EsRemunerada, AfectaProductividad FROM stg.TipoAusencia WHERE LoadBatchID = @BatchID) s
    ON t.TipoAusenciaBK = s.TipoAusenciaBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.EsRemunerada=s.EsRemunerada, t.AfectaProductividad=s.AfectaProductividad
    WHEN NOT MATCHED THEN INSERT (TipoAusenciaBK, Codigo, Nombre, EsRemunerada, AfectaProductividad)
         VALUES (s.TipoAusenciaBK, s.Codigo, s.Nombre, s.EsRemunerada, s.AfectaProductividad);

    MERGE HR_DataMart.dm.DimMotivoSalida AS t
    USING (SELECT MotivoSalidaID AS MotivoSalidaBK, Codigo, Nombre, Categoria, EsEvitable FROM stg.MotivoSalida WHERE LoadBatchID = @BatchID) s
    ON t.MotivoSalidaBK = s.MotivoSalidaBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Nombre=s.Nombre, t.Categoria=s.Categoria, t.EsEvitable=s.EsEvitable
    WHEN NOT MATCHED THEN INSERT (MotivoSalidaBK, Codigo, Nombre, Categoria, EsEvitable)
         VALUES (s.MotivoSalidaBK, s.Codigo, s.Nombre, s.Categoria, s.EsEvitable);

    MERGE HR_DataMart.dm.DimEscalaSalarial AS t
    USING (SELECT EscalaSalarialID AS EscalaSalarialBK, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda
           FROM stg.EscalaSalarial WHERE LoadBatchID = @BatchID) s
    ON t.EscalaSalarialBK = s.EscalaSalarialBK
    WHEN MATCHED THEN UPDATE SET t.Codigo=s.Codigo, t.Grado=s.Grado, t.Descripcion=s.Descripcion,
         t.SalarioMinimo=s.SalarioMinimo, t.SalarioMedio=s.SalarioMedio, t.SalarioMaximo=s.SalarioMaximo, t.Moneda=s.Moneda
    WHEN NOT MATCHED THEN INSERT (EscalaSalarialBK, Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, Moneda)
         VALUES (s.EscalaSalarialBK, s.Codigo, s.Grado, s.Descripcion, s.SalarioMinimo, s.SalarioMedio, s.SalarioMaximo, s.Moneda);

    /* DimEmpleado: altas nuevas (SCD2 simplificado — insert si no existe BK) */
    INSERT INTO HR_DataMart.dm.DimEmpleado
    (EmpleadoBK, NumeroEmpleado, NombreCompleto, Genero, FechaNacimiento, FechaContratacion, TipoContrato,
     FechaInicioValidez, FechaFinValidez, EsActual)
    SELECT e.EmpleadoID, e.NumeroEmpleado, CONCAT(e.Nombre, N' ', e.Apellido1), e.Genero, e.FechaNacimiento,
           e.FechaContratacion, e.TipoContrato, SYSUTCDATETIME(), NULL, 1
    FROM stg.Empleado e
    WHERE e.LoadBatchID = @BatchID
      AND NOT EXISTS (SELECT 1 FROM HR_DataMart.dm.DimEmpleado d WHERE d.EmpleadoBK = e.EmpleadoID AND d.EsActual = 1);

    /* Actualización SCD1 de atributos no historiarles / simplificado */
    UPDATE d
    SET d.NombreCompleto = CONCAT(e.Nombre, N' ', e.Apellido1),
        d.TipoContrato = e.TipoContrato
    FROM HR_DataMart.dm.DimEmpleado d
    INNER JOIN stg.Empleado e ON e.EmpleadoID = d.EmpleadoBK AND e.LoadBatchID = @BatchID
    WHERE d.EsActual = 1;

    /* FactRotacion — solo nuevas */
    INSERT INTO HR_DataMart.dm.FactRotacion
    (FechaSalidaKey, EmpleadoKey, DepartamentoKey, PuestoKey, UbicacionKey, MotivoSalidaKey,
     AntiguedadMeses, SalarioAlSalir, ContadorSalida, EsEvitable)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), s.FechaSalida, 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, du.UbicacionKey, dm.MotivoSalidaKey,
        DATEDIFF(MONTH, ISNULL(oe.FechaContratacion, s.FechaSalida), s.FechaSalida),
        s.SalarioAlSalir, 1, dm.EsEvitable
    FROM stg.SalidaEmpleado s
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = s.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = s.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = s.PuestoID
    INNER JOIN HR_DataMart.dm.DimUbicacion du ON du.UbicacionBK = s.UbicacionID
    INNER JOIN HR_DataMart.dm.DimMotivoSalida dm ON dm.MotivoSalidaBK = s.MotivoSalidaID
    LEFT JOIN HR_Sintetico.hr.Empleado oe ON oe.EmpleadoID = s.EmpleadoID
    WHERE s.LoadBatchID = @BatchID
      AND NOT EXISTS (
            SELECT 1 FROM HR_DataMart.dm.FactRotacion f
            INNER JOIN HR_DataMart.dm.DimEmpleado dx ON dx.EmpleadoKey = f.EmpleadoKey
            WHERE dx.EmpleadoBK = s.EmpleadoID
      );

    /* FactAusentismo — solo nuevas por AusenciaID (vía fecha+empleado+tipo como proxy) */
    INSERT INTO HR_DataMart.dm.FactAusentismo
    (FechaInicioKey, FechaFinKey, EmpleadoKey, DepartamentoKey, PuestoKey, TipoAusenciaKey,
     DiasLaborales, ContadorEvento, AfectaProductividad)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), a.FechaInicio, 112)),
        CONVERT(INT, CONVERT(CHAR(8), a.FechaFin, 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, dt.TipoAusenciaKey,
        a.DiasLaborales, 1, dt.AfectaProductividad
    FROM stg.Ausencia a
    INNER JOIN HR_Sintetico.hr.Empleado e ON e.EmpleadoID = a.EmpleadoID
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = a.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = e.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = e.PuestoID
    INNER JOIN HR_DataMart.dm.DimTipoAusencia dt ON dt.TipoAusenciaBK = a.TipoAusenciaID
    WHERE a.LoadBatchID = @BatchID AND a.Estado = 'Aprobada'
      AND NOT EXISTS (
            SELECT 1 FROM HR_DataMart.dm.FactAusentismo f
            WHERE f.EmpleadoKey = de.EmpleadoKey
              AND f.FechaInicioKey = CONVERT(INT, CONVERT(CHAR(8), a.FechaInicio, 112))
              AND f.TipoAusenciaKey = dt.TipoAusenciaKey
              AND f.DiasLaborales = a.DiasLaborales
      );

    /* Recalcular gaps para empleados tocados en habilidades o altas */
    ;WITH Tocados AS (
        SELECT DISTINCT EmpleadoID FROM stg.EmpleadoHabilidad WHERE LoadBatchID = @BatchID
        UNION
        SELECT DISTINCT EmpleadoID FROM stg.Empleado WHERE LoadBatchID = @BatchID AND IsActive = 1
    )
    DELETE f
    FROM HR_DataMart.dm.FactHabilidadEmpleado f
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoKey = f.EmpleadoKey
    INNER JOIN Tocados t ON t.EmpleadoID = de.EmpleadoBK;

    INSERT INTO HR_DataMart.dm.FactHabilidadEmpleado
    (FechaEvaluacionKey, EmpleadoKey, DepartamentoKey, PuestoKey, HabilidadKey,
     NivelActual, NivelRequerido, TieneGap, DiferenciaNiveles, EsCritica, EsObligatoria)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), ISNULL(eh.FechaEvaluacion, CAST(GETDATE() AS DATE)), 112)),
        de.EmpleadoKey, dd.DepartamentoKey, dp.PuestoKey, dh.HabilidadKey,
        nact.ValorNumerico, nreq.ValorNumerico,
        CASE WHEN ISNULL(nact.ValorNumerico, 0) >= nreq.ValorNumerico THEN 0 ELSE 1 END,
        nreq.ValorNumerico - ISNULL(nact.ValorNumerico, 0),
        h.IsCritical, ph.EsObligatoria
    FROM (
        SELECT DISTINCT EmpleadoID FROM stg.EmpleadoHabilidad WHERE LoadBatchID = @BatchID
        UNION
        SELECT DISTINCT EmpleadoID FROM stg.Empleado WHERE LoadBatchID = @BatchID AND IsActive = 1
    ) t
    INNER JOIN HR_Sintetico.hr.Empleado e ON e.EmpleadoID = t.EmpleadoID AND e.IsActive = 1
    INNER JOIN HR_Sintetico.hr.PuestoHabilidadRequerida ph ON ph.PuestoID = e.PuestoID
    INNER JOIN HR_Sintetico.hr.NivelHabilidad nreq ON nreq.NivelHabilidadID = ph.NivelMinimoRequeridoID
    INNER JOIN HR_Sintetico.hr.Habilidad h ON h.HabilidadID = ph.HabilidadID
    LEFT JOIN HR_Sintetico.hr.EmpleadoHabilidad eh
        ON eh.EmpleadoID = e.EmpleadoID AND eh.HabilidadID = ph.HabilidadID AND eh.IsActive = 1
    LEFT JOIN HR_Sintetico.hr.NivelHabilidad nact ON nact.NivelHabilidadID = eh.NivelHabilidadID
    INNER JOIN HR_DataMart.dm.DimEmpleado de ON de.EmpleadoBK = e.EmpleadoID AND de.EsActual = 1
    INNER JOIN HR_DataMart.dm.DimDepartamento dd ON dd.DepartamentoBK = e.DepartamentoID
    INNER JOIN HR_DataMart.dm.DimPuesto dp ON dp.PuestoBK = e.PuestoID
    INNER JOIN HR_DataMart.dm.DimHabilidad dh ON dh.HabilidadBK = ph.HabilidadID;

    /* Avanzar watermarks solo si hubo extracción */
    UPDATE w SET
        UltimoModifiedAt = CASE WHEN x.MaxSrc IS NOT NULL THEN x.MaxSrc ELSE w.UltimoModifiedAt END,
        UltimaEjecucion = SYSUTCDATETIME(),
        FilasProcesadas = ISNULL(x.Cnt, 0),
        Notas = N'Incremental OK'
    FROM HR_Sintetico.hr.EtlWatermark w
    OUTER APPLY (
        SELECT MAX(SrcModifiedAt) AS MaxSrc, COUNT(*) AS Cnt
        FROM (
            SELECT SrcModifiedAt FROM stg.Empleado WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.Empleado'
            UNION ALL
            SELECT SrcModifiedAt FROM stg.Ausencia WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.Ausencia'
            UNION ALL
            SELECT SrcModifiedAt FROM stg.SalidaEmpleado WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.SalidaEmpleado'
            UNION ALL
            SELECT SrcModifiedAt FROM stg.EmpleadoHabilidad WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.EmpleadoHabilidad'
            UNION ALL
            SELECT SrcModifiedAt FROM stg.HistorialSalarial WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.HistorialSalarial'
            UNION ALL
            SELECT SrcModifiedAt FROM stg.EmpleadoAsignacionHistorial WHERE LoadBatchID = @BatchID AND w.TablaFuente = N'hr.EmpleadoAsignacionHistorial'
        ) z
    ) x
    WHERE w.TablaFuente IN (
        N'hr.Empleado', N'hr.Ausencia', N'hr.SalidaEmpleado',
        N'hr.EmpleadoHabilidad', N'hr.HistorialSalarial', N'hr.EmpleadoAsignacionHistorial'
    );

    SELECT 'Incremental load OK' AS Resultado, @BatchID AS BatchID;
END
GO

/* -------------------------------------------------------------------------- */
/* Orquestadores de demo                                                      */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE stg.usp_RunCargaInicial
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();

    EXEC stg.usp_Full_ExtractOltpToStaging @BatchID = @BatchID;
    EXEC stg.usp_Full_LoadStagingToDataMart @BatchID = @BatchID;

    SELECT @BatchID AS BatchID, N'Carga inicial completada' AS Mensaje;
END
GO

CREATE OR ALTER PROCEDURE stg.usp_RunCargaIncremental
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();

    EXEC stg.usp_Inc_ExtractOltpToStaging @BatchID = @BatchID, @TruncateLanding = 1;
    EXEC stg.usp_Inc_LoadStagingToDataMart @BatchID = @BatchID;

    SELECT @BatchID AS BatchID, N'Carga incremental completada' AS Mensaje;
END
GO

PRINT N'Helpers ETL Full/Incremental creados en HR_Staging.';
GO
