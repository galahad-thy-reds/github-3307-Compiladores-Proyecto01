/*
================================================================================
  HR_Sintetico - Carga inicial de empleados y transacciones
  Genera ~180 empleados (activos + terminados) con historiales, skills,
  ausencias, salidas, capacitaciones y evaluaciones.
  Ejecutar DESPUÉS de 01_SeedCatalogos.sql
================================================================================
*/
USE HR_Sintetico;
GO

CREATE OR ALTER PROCEDURE hr.usp_SeedEmpleadosInicial
    @TotalEmpleados INT = 180
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM hr.Empleado)
    BEGIN
        PRINT N'Ya existen empleados. Omitiendo carga inicial. Use usp_ResetDemoData si desea regenerar.';
        RETURN;
    END

    IF OBJECT_ID(N'tempdb..#Nombres') IS NOT NULL DROP TABLE #Nombres;
    IF OBJECT_ID(N'tempdb..#Apellidos') IS NOT NULL DROP TABLE #Apellidos;

    CREATE TABLE #Nombres (Id INT IDENTITY(1,1), Nombre NVARCHAR(40), Genero CHAR(1));
    CREATE TABLE #Apellidos (Id INT IDENTITY(1,1), Apellido NVARCHAR(40));

    INSERT INTO #Nombres (Nombre, Genero) VALUES
    (N'Andrés','M'),(N'Carlos','M'),(N'Diego','M'),(N'Eduardo','M'),(N'Felipe','M'),
    (N'Gabriel','M'),(N'Hernán','M'),(N'Iván','M'),(N'Jorge','M'),(N'Kevin','M'),
    (N'Luis','M'),(N'Marco','M'),(N'Nicolás','M'),(N'Oscar','M'),(N'Pablo','M'),
    (N'Ricardo','M'),(N'Sebastián','M'),(N'Tomás','M'),(N'Víctor','M'),(N'William','M'),
    (N'Ana','F'),(N'Beatriz','F'),(N'Carolina','F'),(N'Diana','F'),(N'Elena','F'),
    (N'Fernanda','F'),(N'Gabriela','F'),(N'Helena','F'),(N'Isabel','F'),(N'Jimena','F'),
    (N'Karla','F'),(N'Laura','F'),(N'María','F'),(N'Natalia','F'),(N'Olga','F'),
    (N'Patricia','F'),(N'Rebeca','F'),(N'Sofía','F'),(N'Tatiana','F'),(N'Valeria','F');

    INSERT INTO #Apellidos (Apellido) VALUES
    (N'Rojas'),(N'Jiménez'),(N'Vargas'),(N'Castro'),(N'Mora'),(N'Solano'),(N'Chaves'),
    (N'Alpízar'),(N'Quesada'),(N'Herrera'),(N'Araya'),(N'Calderón'),(N'Méndez'),(N'Ramírez'),
    (N'Sánchez'),(N'González'),(N'Rodríguez'),(N'Pérez'),(N'Fernández'),(N'López'),
    (N'Guillén'),(N'Ureña'),(N'Brenes'),(N'Aguilar'),(N'Murillo'),(N'Campos'),(N'Segura'),
    (N'Fallas'),(N'Monge'),(N'Zúñiga');

    DECLARE
        @i INT = 1,
        @Nombre NVARCHAR(40),
        @Ap1 NVARCHAR(40),
        @Ap2 NVARCHAR(40),
        @Genero CHAR(1),
        @DeptoID INT,
        @PuestoID INT,
        @UbicID INT,
        @EscalaID INT,
        @EstadoActivoID INT,
        @EstadoTermID INT,
        @Salario DECIMAL(12,2),
        @FechaContrato DATE,
        @FechaTerm DATE,
        @EsTerminado BIT,
        @EmpID INT,
        @NumEmp VARCHAR(20),
        @Cedula VARCHAR(20),
        @Email NVARCHAR(150),
        @Nacimiento DATE,
        @TipoContrato VARCHAR(20),
        @MinE DECIMAL(12,2),
        @MaxE DECIMAL(12,2),
        @NivelPuesto TINYINT,
        @DeptoCodigo VARCHAR(20),
        @Aumentos INT,
        @a INT,
        @SalPrev DECIMAL(12,2),
        @SalNew DECIMAL(12,2),
        @FechaAum DATE;

    SELECT @EstadoActivoID = EstadoEmpleadoID FROM hr.EstadoEmpleado WHERE Codigo = 'ACT';
    SELECT @EstadoTermID   = EstadoEmpleadoID FROM hr.EstadoEmpleado WHERE Codigo = 'TER';

    WHILE @i <= @TotalEmpleados
    BEGIN
        SELECT TOP (1) @Nombre = Nombre, @Genero = Genero FROM #Nombres ORDER BY NEWID();
        SELECT TOP (1) @Ap1 = Apellido FROM #Apellidos ORDER BY NEWID();
        SELECT TOP (1) @Ap2 = Apellido FROM #Apellidos ORDER BY NEWID();

        SELECT TOP (1) @DeptoID = DepartamentoID
        FROM hr.Departamento
        WHERE Codigo = CASE
            WHEN @i % 10 IN (0,1,2) THEN 'D-TI'
            WHEN @i % 10 IN (3,4)   THEN 'D-COM'
            WHEN @i % 10 = 5        THEN 'D-OPE'
            WHEN @i % 10 = 6        THEN 'D-FIN'
            WHEN @i % 10 = 7        THEN 'D-RH'
            WHEN @i % 10 = 8        THEN 'D-MKT'
            WHEN @i % 10 = 9        THEN 'D-INN'
            ELSE 'D-LEG'
        END;

        SELECT TOP (1) @PuestoID = p.PuestoID, @NivelPuesto = p.NivelJerarquico
        FROM hr.Puesto p
        WHERE
            (EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-TI'
                     AND p.Codigo IN ('P-DEV','P-DEV-SR','P-ARQ','P-DBA','P-SOP','P-ANA-SR','P-JEF','P-GER'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-COM'
                     AND p.Codigo IN ('P-EJE-COM','P-SUP-COM','P-ANA-JR','P-JEF','P-GER'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-OPE'
                     AND p.Codigo IN ('P-OPR','P-SUP-OP','P-ANA-JR','P-JEF'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-FIN'
                     AND p.Codigo IN ('P-CONT','P-FIN-AN','P-ANA-SR','P-JEF','P-GER'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-RH'
                     AND p.Codigo IN ('P-AN-RH','P-BP-RH','P-ANA-JR','P-JEF'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-MKT'
                     AND p.Codigo IN ('P-MKT','P-ANA-JR','P-JEF'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-LEG'
                     AND p.Codigo IN ('P-LEG','P-ANA-SR','P-JEF'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = @DeptoID AND d.Codigo = 'D-INN'
                     AND p.Codigo IN ('P-INN','P-DEV','P-ANA-SR','P-JEF')))
        ORDER BY NEWID();

        SELECT TOP (1) @UbicID = UbicacionID FROM hr.Ubicacion ORDER BY NEWID();

        SELECT @EscalaID = EscalaSalarialID, @MinE = SalarioMinimo, @MaxE = SalarioMaximo
        FROM hr.EscalaSalarial WHERE Grado = @NivelPuesto;

        SELECT @DeptoCodigo = Codigo FROM hr.Departamento WHERE DepartamentoID = @DeptoID;

        SET @Salario = @MinE + ((@MaxE - @MinE) * (ABS(CHECKSUM(NEWID())) % 100) / 100.0);
        IF @DeptoCodigo = 'D-COM' SET @Salario = @Salario * 1.08;
        IF @DeptoCodigo = 'D-OPE' SET @Salario = @Salario * 0.92;
        IF @DeptoCodigo = 'D-TI'  AND @Genero = 'F' SET @Salario = @Salario * 0.97;
        SET @Salario = ROUND(@Salario, -3);

        SET @FechaContrato = DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 2200), CAST(GETDATE() AS DATE));
        SET @EsTerminado = CASE WHEN @i % 5 = 0 THEN 1 ELSE 0 END;
        SET @FechaTerm = NULL;

        IF @EsTerminado = 1
        BEGIN
            SET @FechaTerm = DATEADD(DAY, 90 + (ABS(CHECKSUM(NEWID())) %
                CASE WHEN DATEDIFF(DAY, @FechaContrato, GETDATE()) > 90
                     THEN DATEDIFF(DAY, @FechaContrato, GETDATE()) ELSE 91 END), @FechaContrato);
            IF @FechaTerm > CAST(GETDATE() AS DATE)
                SET @FechaTerm = DATEADD(DAY, -((ABS(CHECKSUM(NEWID())) % 400) + 30), CAST(GETDATE() AS DATE));
            IF @FechaTerm < @FechaContrato SET @FechaTerm = DATEADD(MONTH, 6, @FechaContrato);
        END

        SET @Nacimiento = DATEADD(YEAR, -(22 + ABS(CHECKSUM(NEWID())) % 30), @FechaContrato);
        SET @NumEmp = 'E' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5);
        SET @Cedula = CAST(100000000 + @i * 37 + (ABS(CHECKSUM(NEWID())) % 50) AS VARCHAR(20));
        SET @Email = LOWER(REPLACE(REPLACE(@Nombre, N'í', 'i'), N'á', 'a')) + '.' +
                     LOWER(REPLACE(REPLACE(@Ap1, N'í', 'i'), N'á', 'a')) +
                     CAST(@i AS VARCHAR(10)) + '@hrsintetico.local';
        SET @TipoContrato = CASE WHEN @i % 11 = 0 THEN 'Temporal' WHEN @i % 17 = 0 THEN 'Servicios' ELSE 'Indefinido' END;

        INSERT INTO hr.Empleado
        (
            NumeroEmpleado, Cedula, Nombre, Apellido1, Apellido2, FechaNacimiento, Genero,
            EmailCorporativo, Telefono, FechaContratacion, FechaTerminacion, EstadoEmpleadoID,
            DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
            SalarioActual, TipoContrato, Jornada, IsActive, CreatedAt, ModifiedAt
        )
        VALUES
        (
            @NumEmp, @Cedula, @Nombre, @Ap1, @Ap2, @Nacimiento, @Genero,
            @Email, '8888' + RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4),
            @FechaContrato, @FechaTerm,
            CASE WHEN @EsTerminado = 1 THEN @EstadoTermID ELSE @EstadoActivoID END,
            @DeptoID, @PuestoID, @UbicID, NULL, @EscalaID,
            @Salario, @TipoContrato, 'Completa',
            CASE WHEN @EsTerminado = 1 THEN 0 ELSE 1 END,
            DATEADD(DAY, -10, SYSUTCDATETIME()), DATEADD(DAY, -10, SYSUTCDATETIME())
        );

        SET @EmpID = SCOPE_IDENTITY();

        INSERT INTO hr.EmpleadoAsignacionHistorial
        (EmpleadoID, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, EscalaSalarialID,
         Salario, MotivoCambio, FechaInicio, FechaFin, EsActual, CreatedAt, ModifiedAt)
        VALUES
        (@EmpID, @DeptoID, @PuestoID, @UbicID, NULL, @EscalaID,
         @Salario, N'Contratación', @FechaContrato,
         CASE WHEN @EsTerminado = 1 THEN @FechaTerm ELSE NULL END,
         CASE WHEN @EsTerminado = 1 THEN 0 ELSE 1 END,
         DATEADD(DAY, -10, SYSUTCDATETIME()), DATEADD(DAY, -10, SYSUTCDATETIME()));

        INSERT INTO hr.HistorialSalarial
        (EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, CreatedAt, ModifiedAt)
        VALUES
        (@EmpID, @EscalaID, NULL, @Salario, N'Ingreso', @FechaContrato,
         DATEADD(DAY, -10, SYSUTCDATETIME()), DATEADD(DAY, -10, SYSUTCDATETIME()));

        SET @Aumentos = ABS(CHECKSUM(NEWID())) % 3;
        SET @a = 1;
        SET @SalPrev = @Salario;

        WHILE @a <= @Aumentos AND @EsTerminado = 0
        BEGIN
            SET @FechaAum = DATEADD(MONTH, 12 * @a, @FechaContrato);
            IF @FechaAum < CAST(GETDATE() AS DATE)
            BEGIN
                SET @SalNew = ROUND(@SalPrev * (1.0 + (0.03 + (ABS(CHECKSUM(NEWID())) % 8) / 100.0)), -3);
                INSERT INTO hr.HistorialSalarial
                (EmpleadoID, EscalaSalarialID, SalarioAnterior, SalarioNuevo, Motivo, FechaEfectiva, CreatedAt, ModifiedAt)
                VALUES
                (@EmpID, @EscalaID, @SalPrev, @SalNew,
                 CASE WHEN @a = 1 THEN N'Aumento meritocrático' ELSE N'Ajuste por inflación' END,
                 @FechaAum, DATEADD(DAY, -5, SYSUTCDATETIME()), DATEADD(DAY, -5, SYSUTCDATETIME()));

                UPDATE hr.Empleado
                SET SalarioActual = @SalNew, ModifiedAt = DATEADD(DAY, -5, SYSUTCDATETIME())
                WHERE EmpleadoID = @EmpID;

                UPDATE hr.EmpleadoAsignacionHistorial
                SET Salario = @SalNew, ModifiedAt = DATEADD(DAY, -5, SYSUTCDATETIME())
                WHERE EmpleadoID = @EmpID AND EsActual = 1;

                SET @SalPrev = @SalNew;
            END
            SET @a += 1;
        END

        SET @i += 1;
    END

    /* Managers */
    ;WITH Managers AS (
        SELECT e.EmpleadoID, e.DepartamentoID,
               ROW_NUMBER() OVER (PARTITION BY e.DepartamentoID ORDER BY e.EmpleadoID) AS rn
        FROM hr.Empleado e
        INNER JOIN hr.Puesto p ON p.PuestoID = e.PuestoID
        WHERE e.IsActive = 1 AND p.NivelJerarquico >= 4
    ),
    Targets AS (
        SELECT e.EmpleadoID, e.DepartamentoID
        FROM hr.Empleado e
        INNER JOIN hr.Puesto p ON p.PuestoID = e.PuestoID
        WHERE e.IsActive = 1 AND p.NivelJerarquico < 4
    )
    UPDATE e
    SET e.ManagerEmpleadoID = m.EmpleadoID,
        e.ModifiedAt = SYSUTCDATETIME()
    FROM hr.Empleado e
    INNER JOIN Targets t ON t.EmpleadoID = e.EmpleadoID
    INNER JOIN Managers m ON m.DepartamentoID = e.DepartamentoID AND m.rn = 1;

    UPDATE h
    SET h.ManagerEmpleadoID = e.ManagerEmpleadoID,
        h.ModifiedAt = SYSUTCDATETIME()
    FROM hr.EmpleadoAsignacionHistorial h
    INNER JOIN hr.Empleado e ON e.EmpleadoID = h.EmpleadoID
    WHERE h.EsActual = 1;

    /* Habilidades con gaps intencionados en TI */
    INSERT INTO hr.EmpleadoHabilidad
    (EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, CreatedAt, ModifiedAt)
    SELECT
        e.EmpleadoID,
        ph.HabilidadID,
        CASE
            WHEN d.Codigo = 'D-TI' AND h.IsCritical = 1 AND (e.EmpleadoID % 3 = 0)
                THEN ISNULL((SELECT TOP 1 n2.NivelHabilidadID
                             FROM hr.NivelHabilidad n2
                             WHERE n2.ValorNumerico = CASE WHEN nreq.ValorNumerico > 1 THEN nreq.ValorNumerico - 1 ELSE 1 END),
                            ph.NivelMinimoRequeridoID)
            ELSE
                ISNULL((SELECT TOP 1 n3.NivelHabilidadID
                        FROM hr.NivelHabilidad n3
                        WHERE n3.ValorNumerico = CASE
                            WHEN (e.EmpleadoID + h.HabilidadID) % 4 = 0
                                THEN CASE WHEN nreq.ValorNumerico < 5 THEN nreq.ValorNumerico + 1 ELSE 5 END
                            ELSE nreq.ValorNumerico END),
                       ph.NivelMinimoRequeridoID)
        END,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID(), e.EmpleadoID)) % 365), CAST(GETDATE() AS DATE)),
        CASE WHEN e.EmpleadoID % 3 = 0 THEN N'Manager' WHEN e.EmpleadoID % 3 = 1 THEN N'Certificación' ELSE N'Autoevaluación' END,
        CASE WHEN e.EmpleadoID % 5 = 0 THEN 1 ELSE 0 END,
        DATEADD(DAY, -3, SYSUTCDATETIME()),
        DATEADD(DAY, -3, SYSUTCDATETIME())
    FROM hr.Empleado e
    INNER JOIN hr.Departamento d ON d.DepartamentoID = e.DepartamentoID
    INNER JOIN hr.PuestoHabilidadRequerida ph ON ph.PuestoID = e.PuestoID
    INNER JOIN hr.Habilidad h ON h.HabilidadID = ph.HabilidadID
    INNER JOIN hr.NivelHabilidad nreq ON nreq.NivelHabilidadID = ph.NivelMinimoRequeridoID
    WHERE e.IsActive = 1;

    INSERT INTO hr.EmpleadoHabilidad
    (EmpleadoID, HabilidadID, NivelHabilidadID, FechaEvaluacion, FuenteEvaluacion, Certificado, CreatedAt, ModifiedAt)
    SELECT e.EmpleadoID, h.HabilidadID, n.NivelHabilidadID,
           DATEADD(DAY, -60, CAST(GETDATE() AS DATE)), N'Autoevaluación', 0,
           DATEADD(DAY, -2, SYSUTCDATETIME()), DATEADD(DAY, -2, SYSUTCDATETIME())
    FROM hr.Empleado e
    INNER JOIN hr.Habilidad h ON h.Codigo IN ('H-COM','H-EXC')
    INNER JOIN hr.NivelHabilidad n ON n.ValorNumerico = 2 + (e.EmpleadoID % 3)
    WHERE e.IsActive = 1
      AND e.EmpleadoID % 2 = 0
      AND NOT EXISTS (
          SELECT 1 FROM hr.EmpleadoHabilidad eh
          WHERE eh.EmpleadoID = e.EmpleadoID AND eh.HabilidadID = h.HabilidadID
      );

    INSERT INTO hr.EmpleadoCapacitacion
    (EmpleadoID, CapacitacionID, FechaInicio, FechaFin, Estado, Calificacion, CostoReal, CreatedAt, ModifiedAt)
    SELECT TOP (120)
        e.EmpleadoID,
        c.CapacitacionID,
        DATEADD(DAY, -(ABS(CHECKSUM(NEWID(), e.EmpleadoID)) % 500), CAST(GETDATE() AS DATE)),
        CASE WHEN e.EmpleadoID % 4 = 0 THEN NULL
             ELSE DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 400), CAST(GETDATE() AS DATE)) END,
        CASE WHEN e.EmpleadoID % 4 = 0 THEN 'EnCurso'
             WHEN e.EmpleadoID % 11 = 0 THEN 'Abandonado'
             ELSE 'Completado' END,
        CASE WHEN e.EmpleadoID % 4 = 0 THEN NULL ELSE 70 + (ABS(CHECKSUM(NEWID())) % 30) END,
        c.CostoEstimado,
        DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, -1, SYSUTCDATETIME())
    FROM hr.Empleado e
    CROSS JOIN hr.Capacitacion c
    WHERE e.IsActive = 1
    ORDER BY NEWID();

    /* Ausencias */
    DECLARE @EmpAus INT, @TipoAus INT, @Fi DATE, @Ff DATE, @Dias DECIMAL(5,1), @Mes INT, @k INT, @MaxK INT;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT EmpleadoID FROM hr.Empleado WHERE IsActive = 1 OR FechaTerminacion >= DATEADD(YEAR, -2, GETDATE());

    OPEN cur;
    FETCH NEXT FROM cur INTO @EmpAus;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @k = 1;
        SET @MaxK = 3 + (ABS(CHECKSUM(NEWID(), @EmpAus)) % 6);

        WHILE @k <= @MaxK
        BEGIN
            SET @Mes = CASE
                WHEN @k % 3 = 0 THEN CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 12 ELSE 1 END
                WHEN @k % 3 = 1 THEN 7
                ELSE 1 + (ABS(CHECKSUM(NEWID())) % 12)
            END;

            SET @Fi = DATEFROMPARTS(
                YEAR(GETDATE()) - CASE WHEN @Mes > MONTH(GETDATE()) THEN 1 ELSE (ABS(CHECKSUM(NEWID())) % 2) END,
                @Mes,
                1 + (ABS(CHECKSUM(NEWID())) % 25)
            );
            IF @Fi > CAST(GETDATE() AS DATE) SET @Fi = DATEADD(MONTH, -1, @Fi);

            SELECT TOP (1) @TipoAus = TipoAusenciaID
            FROM hr.TipoAusencia
            WHERE Codigo = CASE
                WHEN @Mes IN (12,1) AND @k % 2 = 0 THEN 'A-ENF'
                WHEN @Mes IN (7,12) THEN 'A-VAC'
                WHEN @k % 7 = 0 THEN 'A-INA'
                WHEN @k % 5 = 0 THEN 'A-PER'
                ELSE 'A-VAC'
            END;

            SET @Dias = CASE
                WHEN EXISTS (SELECT 1 FROM hr.TipoAusencia WHERE TipoAusenciaID = @TipoAus AND Codigo = 'A-VAC') THEN 5 + (ABS(CHECKSUM(NEWID())) % 10)
                WHEN EXISTS (SELECT 1 FROM hr.TipoAusencia WHERE TipoAusenciaID = @TipoAus AND Codigo = 'A-ENF') THEN 1 + (ABS(CHECKSUM(NEWID())) % 5)
                WHEN EXISTS (SELECT 1 FROM hr.TipoAusencia WHERE TipoAusenciaID = @TipoAus AND Codigo = 'A-INA') THEN 1
                ELSE 1 + (ABS(CHECKSUM(NEWID())) % 3)
            END;
            SET @Ff = DATEADD(DAY, CAST(@Dias AS INT) - 1, @Fi);

            IF EXISTS (
                SELECT 1 FROM hr.Empleado e
                INNER JOIN hr.Departamento d ON d.DepartamentoID = e.DepartamentoID
                WHERE e.EmpleadoID = @EmpAus AND d.Codigo = 'D-OPE'
            ) AND @k = 1
            BEGIN
                INSERT INTO hr.Ausencia
                (EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, MotivoDetalle,
                 FechaSolicitud, CreatedAt, ModifiedAt)
                SELECT @EmpAus, ta.TipoAusenciaID,
                       DATEADD(DAY, -40 - (@EmpAus % 20), CAST(GETDATE() AS DATE)),
                       DATEADD(DAY, -38 - (@EmpAus % 20), CAST(GETDATE() AS DATE)),
                       3, 'Aprobada', N'Pico operacional / fatiga',
                       DATEADD(DAY, -41 - (@EmpAus % 20), CAST(GETDATE() AS DATE)),
                       DATEADD(HOUR, -12, SYSUTCDATETIME()), DATEADD(HOUR, -12, SYSUTCDATETIME())
                FROM hr.TipoAusencia ta WHERE ta.Codigo = 'A-ENF';
            END

            INSERT INTO hr.Ausencia
            (EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin, DiasLaborales, Estado, MotivoDetalle,
             FechaSolicitud, CreatedAt, ModifiedAt)
            VALUES
            (@EmpAus, @TipoAus, @Fi, @Ff, @Dias,
             CASE WHEN ABS(CHECKSUM(NEWID())) % 20 = 0 THEN 'Rechazada' ELSE 'Aprobada' END,
             NULL, DATEADD(DAY, -3, @Fi),
             DATEADD(HOUR, -6, SYSUTCDATETIME()), DATEADD(HOUR, -6, SYSUTCDATETIME()));

            SET @k += 1;
        END

        FETCH NEXT FROM cur INTO @EmpAus;
    END

    CLOSE cur;
    DEALLOCATE cur;

    /* Salidas */
    INSERT INTO hr.SalidaEmpleado
    (
        EmpleadoID, MotivoSalidaID, FechaSalida, TipoSalida, EntrevistaSalida, ComentarioSalida,
        Recontratable, DepartamentoID, PuestoID, UbicacionID, ManagerEmpleadoID, SalarioAlSalir,
        CreatedAt, ModifiedAt
    )
    SELECT
        e.EmpleadoID,
        m.MotivoSalidaID,
        e.FechaTerminacion,
        CASE
            WHEN m.Categoria = 'Involuntaria' AND m.Codigo = 'S-PERF' THEN 'Despido'
            WHEN m.Codigo = 'S-FINC' THEN 'FinContrato'
            WHEN m.Codigo = 'S-JUB'  THEN 'Jubilacion'
            WHEN m.Codigo = 'S-REST' THEN 'MutuoAcuerdo'
            ELSE 'Renuncia'
        END,
        CASE WHEN e.EmpleadoID % 3 = 0 THEN 1 ELSE 0 END,
        CASE m.Codigo
            WHEN 'S-MEJOR' THEN N'Recibió oferta ~20% superior en otra empresa.'
            WHEN 'S-CARR'  THEN N'No veía ruta de ascenso clara en 18 meses.'
            WHEN 'S-CLIMA' THEN N'Conflictos con liderazgo inmediato.'
            ELSE NULL
        END,
        CASE WHEN m.Codigo IN ('S-PERF','S-ABAN') THEN 0 ELSE 1 END,
        e.DepartamentoID, e.PuestoID, e.UbicacionID, e.ManagerEmpleadoID, e.SalarioActual,
        DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, -1, SYSUTCDATETIME())
    FROM hr.Empleado e
    CROSS APPLY (
        SELECT TOP (1) ms.*
        FROM hr.MotivoSalida ms
        WHERE
            (EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = e.DepartamentoID AND d.Codigo = 'D-TI'
                     AND ms.Codigo IN ('S-MEJOR','S-CARR','S-CLIMA','S-RELOC'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = e.DepartamentoID AND d.Codigo = 'D-OPE'
                     AND ms.Codigo IN ('S-CLIMA','S-PERF','S-PERS','S-ABAN'))
          OR EXISTS (SELECT 1 FROM hr.Departamento d WHERE d.DepartamentoID = e.DepartamentoID AND d.Codigo = 'D-COM'
                     AND ms.Codigo IN ('S-MEJOR','S-CARR','S-RELOC'))
          OR ms.Codigo IN ('S-PERS','S-FINC','S-REST','S-JUB','S-MEJOR'))
        ORDER BY NEWID()
    ) m
    WHERE e.FechaTerminacion IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM hr.SalidaEmpleado s WHERE s.EmpleadoID = e.EmpleadoID);

    /* Evaluaciones */
    INSERT INTO hr.EvaluacionDesempeno
    (EmpleadoID, PeriodoAnio, PeriodoCiclo, FechaEvaluacion, PuntajeGlobal, CalificacionTexto,
     EvaluadorEmpleadoID, CreatedAt, ModifiedAt)
    SELECT
        e.EmpleadoID,
        y.Anio,
        c.Ciclo,
        DATEFROMPARTS(y.Anio, CASE WHEN c.Ciclo = 'Semestral1' THEN 6 ELSE 12 END, 15),
        CAST(2.5 + (ABS(CHECKSUM(e.EmpleadoID, y.Anio, c.Ciclo)) % 26) / 10.0 AS DECIMAL(4,2)),
        CASE
            WHEN (2.5 + (ABS(CHECKSUM(e.EmpleadoID, y.Anio, c.Ciclo)) % 26) / 10.0) < 3.0 THEN 'Bajo'
            WHEN (2.5 + (ABS(CHECKSUM(e.EmpleadoID, y.Anio, c.Ciclo)) % 26) / 10.0) < 4.0 THEN 'Esperado'
            WHEN (2.5 + (ABS(CHECKSUM(e.EmpleadoID, y.Anio, c.Ciclo)) % 26) / 10.0) < 4.6 THEN 'Destacado'
            ELSE 'Excepcional'
        END,
        e.ManagerEmpleadoID,
        DATEADD(DAY, -20, SYSUTCDATETIME()),
        DATEADD(DAY, -20, SYSUTCDATETIME())
    FROM hr.Empleado e
    CROSS JOIN (VALUES (YEAR(GETDATE())-1), (YEAR(GETDATE()))) y(Anio)
    CROSS JOIN (VALUES ('Semestral1'), ('Semestral2')) c(Ciclo)
    WHERE e.FechaContratacion < DATEFROMPARTS(y.Anio, CASE WHEN c.Ciclo = 'Semestral1' THEN 6 ELSE 12 END, 15)
      AND (e.FechaTerminacion IS NULL OR e.FechaTerminacion >= DATEFROMPARTS(y.Anio, CASE WHEN c.Ciclo = 'Semestral1' THEN 6 ELSE 12 END, 1));

    SELECT 'Empleados' AS Entidad, COUNT(*) AS Filas FROM hr.Empleado
    UNION ALL SELECT 'Activos', COUNT(*) FROM hr.Empleado WHERE IsActive = 1
    UNION ALL SELECT 'Salidas', COUNT(*) FROM hr.SalidaEmpleado
    UNION ALL SELECT 'Ausencias', COUNT(*) FROM hr.Ausencia
    UNION ALL SELECT 'HabilidadesEmp', COUNT(*) FROM hr.EmpleadoHabilidad
    UNION ALL SELECT 'HistSalarial', COUNT(*) FROM hr.HistorialSalarial
    UNION ALL SELECT 'Capacitaciones', COUNT(*) FROM hr.EmpleadoCapacitacion
    UNION ALL SELECT 'Evaluaciones', COUNT(*) FROM hr.EvaluacionDesempeno;

    PRINT N'Carga inicial de empleados y transacciones completada.';
END
GO

/* Ejecutar seed automáticamente al instalar el script */
EXEC hr.usp_SeedEmpleadosInicial @TotalEmpleados = 180;
GO
