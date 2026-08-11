/*
================================================================================
  HR_Sintetico - Procedimientos de simulación de cambios (para ETL incremental)
================================================================================
*/
USE HR_Sintetico;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarContrataciones                                                  */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarContrataciones
    @Cantidad INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    IF @Cantidad < 1 RETURN;

    DECLARE @i INT = 1;
    DECLARE @MaxNum INT = ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(NumeroEmpleado, 2, 10) AS INT)) FROM hr.Empleado), 0);
    DECLARE @EstadoActivoID INT = (SELECT EstadoEmpleadoID FROM hr.EstadoEmpleado WHERE Codigo = 'ACT');

    WHILE @i <= @Cantidad
    BEGIN
        DECLARE
            @Num INT = @MaxNum + @i,
            @DeptoID INT,
            @PuestoID INT,
            @UbicID INT,
            @EscalaID INT,
            @Nivel TINYINT,
            @Salario DECIMAL(12,2),
            @MinE DECIMAL(12,2),
            @MaxE DECIMAL(12,2),
            @Nombre NVARCHAR(40),
            @Ap1 NVARCHAR(40),
            @Ap2 NVARCHAR(40),
            @Genero CHAR(1) = CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'F' ELSE 'M' END,
            @Fecha DATE = CAST(GETDATE() AS DATE),
            @EmpID INT;

        SELECT TOP (1) @DeptoID = DepartamentoID FROM hr.Departamento WHERE IsActive = 1 ORDER BY NEWID();
        SELECT TOP (1) @PuestoID = PuestoID, @Nivel = NivelJerarquico FROM hr.Puesto WHERE IsActive = 1 ORDER BY NEWID();
        SELECT TOP (1) @UbicID = UbicacionID FROM hr.Ubicacion WHERE IsActive = 1 ORDER BY NEWID();
        SELECT @EscalaID = EscalaSalarialID, @MinE = SalarioMinimo, @MaxE = SalarioMaximo
        FROM hr.EscalaSalarial WHERE Grado = @Nivel AND IsActive = 1;

        SET @Salario = ROUND(@MinE + ((@MaxE - @MinE) * (ABS(CHECKSUM(NEWID())) % 100) / 100.0), -3);
        SET @Nombre = N'Nuevo' + CAST(@Num AS NVARCHAR(10));
        SET @Ap1 = N'Ingreso';
        SET @Ap2 = N'Simulado';

        INSERT INTO hr.Empleado
        (NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero,
         EmailCorporativo, Telefono, FechaContratacion, EstadoEmpleadoID, DepartamentoID,
         PuestoID, UbicacionID, EscalaSalarialID, SalarioActual, TipoContrato, Jornada, IsActive)
        VALUES
        ('E' + RIGHT('00000' + CAST(@Num AS VARCHAR(5)), 5),
         CAST(200000000 + @Num AS VARCHAR(20)),
         @Nombre, @Ap1, @Ap2, DATEADD(YEAR, -28, @Fecha), @Genero,
         'nuevo.ingreso' + CAST(@Num AS VARCHAR(10)) + '@hrsintetico.local',
         '8777' + RIGHT('0000' + CAST(@Num AS VARCHAR(4)), 4),
         @Fecha, @EstadoActivoID, @DeptoID, @PuestoID, @UbicID, @EscalaID,
         @Salario, 'Indefinido', 'Completa', 1);

        SET @EmpID = SCOPE_IDENTITY();

        INSERT INTO hr.EmpleadoAsignacionHistorial
        (EmpleadoID, DepartamentoID, PuestoID, UbicacionID, EscalaSalarialID, Salario,
         MotivoCambio, FechaInicio, EsActual)
        VALUES (@EmpID, @DeptoID, @PuestoID, @UbicID, @EscalaID, @Salario, N'Contratación', @Fecha, 1);

        INSERT INTO hr.HistorialSalarial
        (EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva)
        VALUES (@EmpID, @EscalaID, NULL, @Salario, N'Ingreso', @Fecha);

        /* habilidades requeridas del puesto, nivel = requerido o -1 */
        INSERT INTO hr.EmpleadoHabilidad
        (EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado)
        SELECT
            @EmpID, ph.HabilidadID,
            ISNULL((
                SELECT TOP 1 n2.NivelHabilidadID
                FROM hr.NivelHabilidad n2
                WHERE n2.ValorNumerico = CASE WHEN @EmpID % 2 = 0 THEN n.ValorNumerico
                                              WHEN n.ValorNumerico > 1 THEN n.ValorNumerico - 1 ELSE 1 END
            ), ph.NivelMinimoRequeridoID),
            @Fecha, N'Autoevaluación', 0
        FROM hr.PuestoHabilidadRequerida ph
        INNER JOIN hr.NivelHabilidad n ON n.NivelHabilidadID = ph.NivelMinimoRequeridoID
        WHERE ph.PuestoID = @PuestoID;

        SET @i += 1;
    END

    SELECT @Cantidad AS ContratacionesGeneradas, SYSUTCDATETIME() AS GeneradoEnUTC;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarSalidas                                                         */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarSalidas
    @Cantidad INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoTermID INT = (SELECT EstadoEmpleadoID FROM hr.EstadoEmpleado WHERE Codigo = 'TER');
    DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);

    ;WITH Candidatos AS (
        SELECT TOP (@Cantidad) e.EmpleadoID
        FROM hr.Empleado e
        WHERE e.IsActive = 1
          AND e.FechaContratacion < DATEADD(MONTH, -3, @Hoy)
          AND NOT EXISTS (SELECT 1 FROM hr.SalidaEmpleado s WHERE s.EmpleadoID = e.EmpleadoID)
        ORDER BY NEWID()
    )
    SELECT EmpleadoID INTO #Salir FROM Candidatos;

    DECLARE @EmpID INT, @MotivoID INT, @Tipo VARCHAR(20), @CodigoMotivo VARCHAR(20);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT EmpleadoID FROM #Salir;
    OPEN c;
    FETCH NEXT FROM c INTO @EmpID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT TOP (1) @MotivoID = MotivoSalidaID, @CodigoMotivo = Codigo
        FROM hr.MotivoSalida WHERE IsActive = 1 ORDER BY NEWID();

        SET @Tipo = CASE
            WHEN @CodigoMotivo = 'S-PERF' THEN 'Despido'
            WHEN @CodigoMotivo = 'S-FINC' THEN 'FinContrato'
            WHEN @CodigoMotivo = 'S-JUB'  THEN 'Jubilacion'
            WHEN @CodigoMotivo = 'S-REST' THEN 'MutuoAcuerdo'
            ELSE 'Renuncia'
        END;

        INSERT INTO hr.SalidaEmpleado
        (EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, EntrevistaSalida, ComentarioSalida,
         Recontratable, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, SalarioAlSalir)
        SELECT
            e.EmpleadoID, @MotivoID, @Hoy, @Tipo, 1,
            N'Salida simulada para prueba ETL incremental',
            CASE WHEN @CodigoMotivo IN ('S-PERF','S-ABAN') THEN 0 ELSE 1 END,
            e.DepartamentoID, e.PuestoID, e.UbicacionID, e.ManagerEmpleadoID, e.SalarioActual
        FROM hr.Empleado e WHERE e.EmpleadoID = @EmpID;

        UPDATE hr.Empleado
        SET IsActive = 0,
            EstadoEmpleadoID = @EstadoTermID,
            FechaTerminacion = @Hoy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID;

        UPDATE hr.EmpleadoAsignacionHistorial
        SET EsActual = 0, FechaFin = @Hoy, ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID AND EsActual = 1;

        FETCH NEXT FROM c INTO @EmpID;
    END

    CLOSE c; DEALLOCATE c;

    SELECT COUNT(*) AS SalidasGeneradas, SYSUTCDATETIME() AS GeneradoEnUTC FROM #Salir;
    DROP TABLE #Salir;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarAusencias                                                       */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarAusencias
    @Cantidad INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @i INT = 1;
    DECLARE @EmpID INT, @TipoID INT, @Fi DATE, @Ff DATE, @Dias DECIMAL(5,1), @Codigo VARCHAR(20);

    WHILE @i <= @Cantidad
    BEGIN
        SELECT TOP (1) @EmpID = EmpleadoID FROM hr.Empleado WHERE IsActive = 1 ORDER BY NEWID();
        SELECT TOP (1) @TipoID = TipoAusenciaID, @Codigo = Codigo
        FROM hr.TipoAusencia WHERE IsActive = 1 AND Codigo <> 'A-MAT' ORDER BY NEWID();

        SET @Dias = CASE
            WHEN @Codigo = 'A-VAC' THEN 3 + (ABS(CHECKSUM(NEWID())) % 8)
            WHEN @Codigo = 'A-ENF' THEN 1 + (ABS(CHECKSUM(NEWID())) % 4)
            ELSE 1
        END;

        SET @Fi = DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 14), CAST(GETDATE() AS DATE));
        SET @Ff = DATEADD(DAY, CAST(@Dias AS INT) - 1, @Fi);

        INSERT INTO hr.Ausencia
        (EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, MotivoDetalle, FechaSolicitud)
        VALUES
        (@EmpID, @TipoID, @Fi, @Ff, @Dias, 'Aprobada', N'Ausencia simulada ETL', DATEADD(DAY, -1, @Fi));

        SET @i += 1;
    END

    SELECT @Cantidad AS AusenciasGeneradas, SYSUTCDATETIME() AS GeneradoEnUTC;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarAjustesSalariales                                               */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarAjustesSalariales
    @Cantidad INT = 5,
    @PorcentajeMin DECIMAL(5,2) = 3.00,
    @PorcentajeMax DECIMAL(5,2) = 10.00
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Candidatos AS (
        SELECT TOP (@Cantidad) e.EmpleadoID, e.SalarioActual, e.EscalaSalarialID
        FROM hr.Empleado e
        WHERE e.IsActive = 1
        ORDER BY NEWID()
    )
    SELECT * INTO #Adj FROM Candidatos;

    DECLARE @EmpID INT, @Sal DECIMAL(12,2), @EscalaID INT, @Nuevo DECIMAL(12,2), @Pct DECIMAL(5,2);

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT EmpleadoID, SalarioActual, EscalaSalarialID FROM #Adj;
    OPEN c;
    FETCH NEXT FROM c INTO @EmpID, @Sal, @EscalaID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Pct = @PorcentajeMin + ((ABS(CHECKSUM(NEWID())) % CAST(((@PorcentajeMax - @PorcentajeMin) * 100) AS INT)) / 100.0);
        SET @Nuevo = ROUND(@Sal * (1 + (@Pct / 100.0)), -3);

        INSERT INTO hr.HistorialSalarial
        (EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva)
        VALUES (@EmpID, @EscalaID, @Sal, @Nuevo, N'Aumento meritocrático (simulado)', CAST(GETDATE() AS DATE));

        UPDATE hr.Empleado
        SET SalarioActual = @Nuevo, ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID;

        UPDATE hr.EmpleadoAsignacionHistorial
        SET Salario = @Nuevo, ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID AND EsActual = 1;

        FETCH NEXT FROM c INTO @EmpID, @Sal, @EscalaID;
    END

    CLOSE c; DEALLOCATE c;

    SELECT COUNT(*) AS AjustesGenerados, SYSUTCDATETIME() AS GeneradoEnUTC FROM #Adj;
    DROP TABLE #Adj;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarActualizacionHabilidades                                        */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarActualizacionHabilidades
    @Cantidad INT = 8
AS
BEGIN
    SET NOCOUNT ON;

    /* Mejora nivel de habilidades existentes */
    ;WITH Pick AS (
        SELECT TOP (@Cantidad) eh.EmpleadoHabilidadID, eh.NivelHabilidadID, n.ValorNumerico
        FROM hr.EmpleadoHabilidad eh
        INNER JOIN hr.Empleado e ON e.EmpleadoID = eh.EmpleadoID AND e.IsActive = 1
        INNER JOIN hr.NivelHabilidad n ON n.NivelHabilidadID = eh.NivelHabilidadID
        WHERE eh.IsActive = 1 AND n.ValorNumerico < 5
        ORDER BY NEWID()
    )
    UPDATE eh
    SET eh.NivelHabilidadID = n2.NivelHabilidadID,
        eh.FechaEvaluacion = CAST(GETDATE() AS DATE),
        eh.FuenteEvaluacion = N'Manager',
        eh.ModifiedAt = SYSUTCDATETIME()
    FROM hr.EmpleadoHabilidad eh
    INNER JOIN Pick p ON p.EmpleadoHabilidadID = eh.EmpleadoHabilidadID
    INNER JOIN hr.NivelHabilidad n2 ON n2.ValorNumerico = p.ValorNumerico + 1;

    SELECT @@ROWCOUNT AS HabilidadesActualizadas, SYSUTCDATETIME() AS GeneradoEnUTC;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarTransferencias                                                  */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarTransferencias
    @Cantidad INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Hoy DATE = CAST(GETDATE() AS DATE);

    ;WITH Candidatos AS (
        SELECT TOP (@Cantidad) e.EmpleadoID
        FROM hr.Empleado e
        WHERE e.IsActive = 1
        ORDER BY NEWID()
    )
    SELECT EmpleadoID INTO #Tr FROM Candidatos;

    DECLARE @EmpID INT, @NuevoDepto INT, @NuevoPuesto INT, @NuevoUbic INT;

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT EmpleadoID FROM #Tr;
    OPEN c;
    FETCH NEXT FROM c INTO @EmpID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT TOP (1) @NuevoDepto = DepartamentoID FROM hr.Departamento WHERE IsActive = 1 ORDER BY NEWID();
        SELECT TOP (1) @NuevoPuesto = PuestoID FROM hr.Puesto WHERE IsActive = 1 ORDER BY NEWID();
        SELECT TOP (1) @NuevoUbic = UbicacionID FROM hr.Ubicacion WHERE IsActive = 1 ORDER BY NEWID();

        UPDATE hr.EmpleadoAsignacionHistorial
        SET EsActual = 0, FechaFin = DATEADD(DAY, -1, @Hoy), ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID AND EsActual = 1;

        INSERT INTO hr.EmpleadoAsignacionHistorial
        (EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
         Salario, MotivoCambio, FechaInicio, EsActual)
        SELECT
            e.EmpleadoID, @NuevoDepto, @NuevoPuesto, @NuevoUbic, e.ManagerEmpleadoID,
            e.EscalaSalarialID, e.SalarioActual, N'Transferencia', @Hoy, 1
        FROM hr.Empleado e WHERE e.EmpleadoID = @EmpID;

        UPDATE hr.Empleado
        SET DepartamentoID = @NuevoDepto,
            PuestoID = @NuevoPuesto,
            UbicacionID = @NuevoUbic,
            ModifiedAt = SYSUTCDATETIME()
        WHERE EmpleadoID = @EmpID;

        FETCH NEXT FROM c INTO @EmpID;
    END

    CLOSE c; DEALLOCATE c;

    SELECT COUNT(*) AS TransferenciasGeneradas, SYSUTCDATETIME() AS GeneradoEnUTC FROM #Tr;
    DROP TABLE #Tr;
END
GO

/* -------------------------------------------------------------------------- */
/* usp_GenerarCapacitaciones                                                  */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_GenerarCapacitaciones
    @Cantidad INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO hr.EmpleadoCapacitacion
    (EmpleadoID, CapacitacionID, FechaInicio, FechaFin, Estado, Calificacion, CostoReal)
    SELECT TOP (@Cantidad)
        e.EmpleadoID,
        c.CapacitacionID,
        CAST(GETDATE() AS DATE),
        CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN NULL ELSE DATEADD(DAY, 14, CAST(GETDATE() AS DATE)) END,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'EnCurso' ELSE 'Completado' END,
        CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN NULL ELSE 75 + (ABS(CHECKSUM(NEWID())) % 25) END,
        c.CostoEstimado
    FROM hr.Empleado e
    CROSS JOIN hr.Capacitacion c
    WHERE e.IsActive = 1 AND c.IsActive = 1
    ORDER BY NEWID();

    SELECT @@ROWCOUNT AS CapacitacionesGeneradas, SYSUTCDATETIME() AS GeneradoEnUTC;
END
GO

/* -------------------------------------------------------------------------- */
/* Orquestador: simula un "día" de actividad transaccional                    */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_SimularDiaTransaccional
    @Contrataciones INT = 2,
    @Salidas INT = 1,
    @Ausencias INT = 8,
    @AjustesSalariales INT = 3,
    @Habilidades INT = 5,
    @Transferencias INT = 1,
    @Capacitaciones INT = 3
AS
BEGIN
    SET NOCOUNT ON;

    PRINT N'=== Inicio simulación día transaccional ===';

    EXEC hr.usp_GenerarContrataciones @Cantidad = @Contrataciones;
    EXEC hr.usp_GenerarSalidas @Cantidad = @Salidas;
    EXEC hr.usp_GenerarAusencias @Cantidad = @Ausencias;
    EXEC hr.usp_GenerarAjustesSalariales @Cantidad = @AjustesSalariales;
    EXEC hr.usp_GenerarActualizacionHabilidades @Cantidad = @Habilidades;
    EXEC hr.usp_GenerarTransferencias @Cantidad = @Transferencias;
    EXEC hr.usp_GenerarCapacitaciones @Cantidad = @Capacitaciones;

    PRINT N'=== Fin simulación día transaccional ===';

    SELECT
        (SELECT COUNT(*) FROM hr.Empleado WHERE ModifiedAt >= DATEADD(MINUTE, -5, SYSUTCDATETIME())) AS EmpleadosTocados5min,
        (SELECT COUNT(*) FROM hr.Ausencia WHERE CreatedAt >= DATEADD(MINUTE, -5, SYSUTCDATETIME())) AS AusenciasNuevas5min,
        (SELECT COUNT(*) FROM hr.HistorialSalarial WHERE CreatedAt >= DATEADD(MINUTE, -5, SYSUTCDATETIME())) AS HistSalNuevos5min,
        (SELECT COUNT(*) FROM hr.SalidaEmpleado WHERE CreatedAt >= DATEADD(MINUTE, -5, SYSUTCDATETIME())) AS SalidasNuevas5min,
        SYSUTCDATETIME() AS EjecutadoEnUTC;
END
GO

/* -------------------------------------------------------------------------- */
/* Consulta de cambios desde un watermark (patrón ETL incremental)            */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_ObtenerCambiosDesde
    @TablaFuente SYSNAME,
    @DesdeModifiedAt DATETIME2(0)
AS
BEGIN
    SET NOCOUNT ON;

    IF @TablaFuente = N'hr.Empleado'
        SELECT * FROM hr.Empleado WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, EmpleadoID;
    ELSE IF @TablaFuente = N'hr.Ausencia'
        SELECT * FROM hr.Ausencia WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, AusenciaID;
    ELSE IF @TablaFuente = N'hr.HistorialSalarial'
        SELECT * FROM hr.HistorialSalarial WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, HistorialSalarialID;
    ELSE IF @TablaFuente = N'hr.SalidaEmpleado'
        SELECT * FROM hr.SalidaEmpleado WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, SalidaEmpleadoID;
    ELSE IF @TablaFuente = N'hr.EmpleadoHabilidad'
        SELECT * FROM hr.EmpleadoHabilidad WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, EmpleadoHabilidadID;
    ELSE IF @TablaFuente = N'hr.EmpleadoAsignacionHistorial'
        SELECT * FROM hr.EmpleadoAsignacionHistorial WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, AsignacionHistorialID;
    ELSE IF @TablaFuente = N'hr.EmpleadoCapacitacion'
        SELECT * FROM hr.EmpleadoCapacitacion WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, EmpleadoCapacitacionID;
    ELSE IF @TablaFuente = N'hr.EvaluacionDesempeno'
        SELECT * FROM hr.EvaluacionDesempeno WHERE ModifiedAt > @DesdeModifiedAt ORDER BY ModifiedAt, EvaluacionID;
    ELSE
        RAISERROR(N'Tabla no soportada para extracción incremental.', 16, 1);
END
GO

/* -------------------------------------------------------------------------- */
/* Reset controlado de datos transaccionales (mantiene catálogos)             */
/* -------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE hr.usp_ResetDemoData
    @Confirmar BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Confirmar <> 1
    BEGIN
        RAISERROR(N'Ejecute EXEC hr.usp_ResetDemoData @Confirmar = 1 para borrar datos transaccionales.', 16, 1);
        RETURN;
    END

    DELETE FROM hr.EvaluacionDesempeno;
    DELETE FROM hr.EmpleadoCapacitacion;
    DELETE FROM hr.EmpleadoHabilidad;
    DELETE FROM hr.Ausencia;
    DELETE FROM hr.SalidaEmpleado;
    DELETE FROM hr.HistorialSalarial;
    DELETE FROM hr.EmpleadoAsignacionHistorial;
    DELETE FROM hr.Empleado;

    UPDATE hr.EtlWatermark
    SET UltimoModifiedAt = '1900-01-01', FilasProcesadas = 0, UltimaEjecucion = SYSUTCDATETIME(),
        Notas = N'Reset demo';

    PRINT N'Datos transaccionales eliminados. Ejecute: EXEC hr.usp_SeedEmpleadosInicial;';
END
GO

PRINT N'Procedimientos de simulación creados.';
GO
