/*
================================================================================
  HR_Sintetico - Vistas de validación orientadas a las 4 preguntas de negocio
  Útiles también como fuente intermedia / especificación para el Data Mart
================================================================================
*/
USE HR_Sintetico;
GO

/* 1) Gestión de Talento: ¿Tenemos las habilidades correctas? */
CREATE OR ALTER VIEW hr.vw_GapHabilidades
AS
SELECT
    e.EmpleadoID,
    e.NumeroEmpleado,
    e.Nombre + N' ' + e.Apellido1 AS Empleado,
    d.Nombre AS Departamento,
    p.Nombre AS Puesto,
    h.Nombre AS Habilidad,
    h.Categoria,
    h.IsCritical,
    nreq.ValorNumerico AS NivelRequerido,
    nreq.Nombre AS NivelRequeridoNombre,
    nact.ValorNumerico AS NivelActual,
    nact.Nombre AS NivelActualNombre,
    CASE WHEN nact.ValorNumerico >= nreq.ValorNumerico THEN 0 ELSE 1 END AS TieneGap,
    nreq.ValorNumerico - ISNULL(nact.ValorNumerico, 0) AS DiferenciaNiveles,
    ph.EsObligatoria
FROM hr.Empleado e
INNER JOIN hr.Departamento d ON d.DepartamentoID = e.DepartamentoID
INNER JOIN hr.Puesto p ON p.PuestoID = e.PuestoID
INNER JOIN hr.PuestoHabilidadRequerida ph ON ph.PuestoID = e.PuestoID
INNER JOIN hr.Habilidad h ON h.HabilidadID = ph.HabilidadID
INNER JOIN hr.NivelHabilidad nreq ON nreq.NivelHabilidadID = ph.NivelMinimoRequeridoID
LEFT JOIN hr.EmpleadoHabilidad eh
    ON eh.EmpleadoID = e.EmpleadoID AND eh.HabilidadID = h.HabilidadID AND eh.IsActive = 1
LEFT JOIN hr.NivelHabilidad nact ON nact.NivelHabilidadID = eh.NivelHabilidadID
WHERE e.IsActive = 1;
GO

CREATE OR ALTER VIEW hr.vw_ResumenGapPorDepartamento
AS
SELECT
    Departamento,
    COUNT(*) AS RequisitosEvaluados,
    SUM(TieneGap) AS GapsDetectados,
    CAST(100.0 * SUM(TieneGap) / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS PctConGap,
    SUM(CASE WHEN IsCritical = 1 THEN TieneGap ELSE 0 END) AS GapsCriticos
FROM hr.vw_GapHabilidades
GROUP BY Departamento;
GO

/* 2) Rotación y Retención: ¿Por qué se van y cuándo? */
CREATE OR ALTER VIEW hr.vw_RotacionDetalle
AS
SELECT
    s.SalidaEmpleadoID,
    e.NumeroEmpleado,
    e.Nombre + N' ' + e.Apellido1 AS Empleado,
    d.Nombre AS Departamento,
    p.Nombre AS Puesto,
    u.Nombre AS Ubicacion,
    s.FechaSalida,
    DATEPART(YEAR, s.FechaSalida) AS AnioSalida,
    DATEPART(MONTH, s.FechaSalida) AS MesSalida,
    DATENAME(MONTH, s.FechaSalida) AS NombreMes,
    s.TipoSalida,
    m.Nombre AS MotivoSalida,
    m.Categoria AS CategoriaMotivo,
    m.EsEvitable,
    DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida) AS AntiguedadMeses,
    CASE
        WHEN DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida) < 6 THEN N'0-6 meses'
        WHEN DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida) < 12 THEN N'6-12 meses'
        WHEN DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida) < 24 THEN N'1-2 años'
        WHEN DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida) < 48 THEN N'2-4 años'
        ELSE N'4+ años'
    END AS RangoAntiguedad,
    s.SalarioAlSalir,
    s.EntrevistaSalida,
    s.Recontratable
FROM hr.SalidaEmpleado s
INNER JOIN hr.Empleado e ON e.EmpleadoID = s.EmpleadoID
INNER JOIN hr.Departamento d ON d.DepartamentoID = s.DepartamentoID
INNER JOIN hr.Puesto p ON p.PuestoID = s.PuestoID
INNER JOIN hr.Ubicacion u ON u.UbicacionID = s.UbicacionID
INNER JOIN hr.MotivoSalida m ON m.MotivoSalidaID = s.MotivoSalidaID;
GO

CREATE OR ALTER VIEW hr.vw_TasaRotacionMensual
AS
WITH Meses AS (
    SELECT DISTINCT
        DATEFROMPARTS(DATEPART(YEAR, FechaSalida), DATEPART(MONTH, FechaSalida), 1) AS Periodo
    FROM hr.SalidaEmpleado
),
Headcount AS (
    SELECT
        m.Periodo,
        (
            SELECT COUNT(*)
            FROM hr.Empleado e
            WHERE e.FechaContratacion <= EOMONTH(m.Periodo)
              AND (e.FechaTerminacion IS NULL OR e.FechaTerminacion > m.Periodo)
        ) AS HeadcountInicio
    FROM Meses m
),
Salidas AS (
    SELECT
        DATEFROMPARTS(DATEPART(YEAR, FechaSalida), DATEPART(MONTH, FechaSalida), 1) AS Periodo,
        COUNT(*) AS CantSalidas
    FROM hr.SalidaEmpleado
    GROUP BY DATEFROMPARTS(DATEPART(YEAR, FechaSalida), DATEPART(MONTH, FechaSalida), 1)
)
SELECT
    h.Periodo,
    h.HeadcountInicio,
    ISNULL(s.CantSalidas, 0) AS CantSalidas,
    CAST(100.0 * ISNULL(s.CantSalidas, 0) / NULLIF(h.HeadcountInicio, 0) AS DECIMAL(5,2)) AS TasaRotacionPct
FROM Headcount h
LEFT JOIN Salidas s ON s.Periodo = h.Periodo;
GO

/* 3) Ausentismo: ¿Hay patrones de falta que afecten la productividad? */
CREATE OR ALTER VIEW hr.vw_AusentismoDetalle
AS
SELECT
    a.AusenciaID,
    e.NumeroEmpleado,
    e.Nombre + N' ' + e.Apellido1 AS Empleado,
    d.Nombre AS Departamento,
    p.Nombre AS Puesto,
    ta.Nombre AS TipoAusencia,
    ta.EsRemunerada,
    ta.AfectaProductividad,
    a.FechaInicio,
    a.FechaFin,
    a.DiasLaborales,
    a.Estado,
    DATEPART(YEAR, a.FechaInicio) AS Anio,
    DATEPART(MONTH, a.FechaInicio) AS Mes,
    DATENAME(MONTH, a.FechaInicio) AS NombreMes,
    DATEPART(WEEKDAY, a.FechaInicio) AS DiaSemanaNum,
    DATENAME(WEEKDAY, a.FechaInicio) AS DiaSemana
FROM hr.Ausencia a
INNER JOIN hr.Empleado e ON e.EmpleadoID = a.EmpleadoID
INNER JOIN hr.Departamento d ON d.DepartamentoID = e.DepartamentoID
INNER JOIN hr.Puesto p ON p.PuestoID = e.PuestoID
INNER JOIN hr.TipoAusencia ta ON ta.TipoAusenciaID = a.TipoAusenciaID
WHERE a.Estado = 'Aprobada';
GO

CREATE OR ALTER VIEW hr.vw_AusentismoPorDeptoMes
AS
SELECT
    Departamento,
    Anio,
    Mes,
    NombreMes,
    SUM(DiasLaborales) AS DiasAusencia,
    SUM(CASE WHEN AfectaProductividad = 1 THEN DiasLaborales ELSE 0 END) AS DiasImpactoProductividad,
    COUNT(*) AS EventosAusencia,
    COUNT(DISTINCT NumeroEmpleado) AS EmpleadosConAusencia
FROM hr.vw_AusentismoDetalle
GROUP BY Departamento, Anio, Mes, NombreMes;
GO

/* 4) Compensación: ¿Es justa la estructura salarial por departamento? */
CREATE OR ALTER VIEW hr.vw_CompensacionActual
AS
SELECT
    e.EmpleadoID,
    e.NumeroEmpleado,
    e.Nombre + N' ' + e.Apellido1 AS Empleado,
    e.Genero,
    d.Nombre AS Departamento,
    p.Nombre AS Puesto,
    p.NivelJerarquico,
    p.FamiliaPuesto,
    es.Codigo AS GradoSalarial,
    es.SalarioMinimo,
    es.SalarioMedio,
    es.SalarioMaximo,
    e.SalarioActual,
    CAST((e.SalarioActual - es.SalarioMinimo) * 100.0
         / NULLIF(es.SalarioMaximo - es.SalarioMinimo, 0) AS DECIMAL(5,2)) AS PosicionEnBandaPct,
    CASE
        WHEN e.SalarioActual < es.SalarioMinimo THEN N'Bajo banda'
        WHEN e.SalarioActual > es.SalarioMaximo THEN N'Sobre banda'
        ELSE N'Dentro de banda'
    END AS EstadoBanda,
    DATEDIFF(MONTH, e.FechaContratacion, GETDATE()) AS AntiguedadMeses
FROM hr.Empleado e
INNER JOIN hr.Departamento d ON d.DepartamentoID = e.DepartamentoID
INNER JOIN hr.Puesto p ON p.PuestoID = e.PuestoID
INNER JOIN hr.EscalaSalarial es ON es.EscalaSalarialID = e.EscalaSalarialID
WHERE e.IsActive = 1;
GO

CREATE OR ALTER VIEW hr.vw_EquidadSalarialPorDepto
AS
SELECT
    Departamento,
    NivelJerarquico,
    COUNT(*) AS Empleados,
    MIN(SalarioActual) AS SalarioMin,
    MAX(SalarioActual) AS SalarioMax,
    AVG(SalarioActual) AS SalarioPromedio,
    STDEV(SalarioActual) AS DesviacionEstándar,
    AVG(CASE WHEN Genero = 'F' THEN SalarioActual END) AS PromedioFemenino,
    AVG(CASE WHEN Genero = 'M' THEN SalarioActual END) AS PromedioMasculino,
    CAST(
        (AVG(CASE WHEN Genero = 'M' THEN SalarioActual END)
       - AVG(CASE WHEN Genero = 'F' THEN SalarioActual END))
        * 100.0 / NULLIF(AVG(CASE WHEN Genero = 'M' THEN SalarioActual END), 0)
    AS DECIMAL(5,2)) AS GapGeneroPct,
    SUM(CASE WHEN EstadoBanda = N'Bajo banda' THEN 1 ELSE 0 END) AS CantBajoBanda,
    SUM(CASE WHEN EstadoBanda = N'Sobre banda' THEN 1 ELSE 0 END) AS CantSobreBanda
FROM hr.vw_CompensacionActual
GROUP BY Departamento, NivelJerarquico;
GO

PRINT N'Vistas de análisis de negocio creadas.';
GO
