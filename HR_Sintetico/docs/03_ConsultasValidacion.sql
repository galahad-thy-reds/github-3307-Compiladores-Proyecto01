/*
================================================================================
  Consultas de validación rápida — 4 preguntas de negocio
================================================================================
*/
USE HR_Sintetico;
GO

PRINT N'=== 1) Talento: gaps de habilidades ===';
SELECT * FROM hr.vw_ResumenGapPorDepartamento ORDER BY PctConGap DESC;

PRINT N'=== 1b) Gaps críticos (top 20) ===';
SELECT TOP (20) Empleado, Departamento, Puesto, Habilidad, NivelRequeridoNombre, NivelActualNombre, DiferenciaNiveles
FROM hr.vw_GapHabilidades
WHERE TieneGap = 1 AND IsCritical = 1
ORDER BY DiferenciaNiveles DESC, Departamento;

PRINT N'=== 2) Rotación: motivos ===';
SELECT MotivoSalida, CategoriaMotivo, COUNT(*) AS Salidas, AVG(AntiguedadMeses * 1.0) AS AntiguedadPromedioMeses
FROM hr.vw_RotacionDetalle
GROUP BY MotivoSalida, CategoriaMotivo
ORDER BY Salidas DESC;

PRINT N'=== 2b) Rotación por rango de antigüedad ===';
SELECT RangoAntiguedad, COUNT(*) AS Salidas
FROM hr.vw_RotacionDetalle
GROUP BY RangoAntiguedad
ORDER BY MIN(AntiguedadMeses);

PRINT N'=== 3) Ausentismo por depto (últimos periodos) ===';
SELECT TOP (30) *
FROM hr.vw_AusentismoPorDeptoMes
ORDER BY Anio DESC, Mes DESC, DiasImpactoProductividad DESC;

PRINT N'=== 4) Equidad salarial ===';
SELECT Departamento, NivelJerarquico, Empleados, SalarioPromedio, GapGeneroPct, CantBajoBanda, CantSobreBanda
FROM hr.vw_EquidadSalarialPorDepto
ORDER BY Departamento, NivelJerarquico;
GO
