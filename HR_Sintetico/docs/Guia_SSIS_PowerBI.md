# Guía práctica SSIS + Power BI

## 1. Paquetes SSIS sugeridos

### `PKG_HR_Dim_Catalogos`
- Origen: `hr.Departamento`, `Puesto`, `Ubicacion`, `Habilidad`, `NivelHabilidad`, `TipoAusencia`, `MotivoSalida`, `EscalaSalarial`, `EstadoEmpleado`
- Destino staging → MERGE a dimensiones en `HR_DataMart`
- Frecuencia: diaria (cambios raros; full pequeño también es válido)

### `PKG_HR_Fact_Inicial`
- Full load histórico de hechos
- Truncate+load staging → transform → insert hechos
- Ejecutar una vez (o tras `usp_ResetDemoData`)

### `PKG_HR_Incremental_Diario`
Flujo recomendado:

1. **Execute SQL** — crear `@BatchID = NEWID()`, insertar fila en `stg.EtlBatchLog` (`Status='Running'`).
2. **Execute SQL** — leer watermarks de `hr.EtlWatermark`.
3. **Data Flow** por entidad (`Empleado`, `Ausencia`, `SalidaEmpleado`, `EmpleadoHabilidad`, `HistorialSalarial`, `EmpleadoAsignacionHistorial`):
   - Source: `EXEC hr.usp_ObtenerCambiosDesde ...` **o** `SELECT ... WHERE ModifiedAt > ?`
   - Destino: `stg.*` con `LoadBatchID`, `LoadType='Incremental'`, `SrcModifiedAt`.
4. **Data Flow / Execute SQL** — transformar staging → dimensiones/hechos.
5. **Execute SQL** — actualizar watermarks y cerrar batch (`Success`).

### Connection Managers
- `CM_OLTP` → `HR_Sintetico`
- `CM_STG` → `HR_Staging`
- `CM_DM` → `HR_DataMart`

## 2. Patrón de watermark (ejemplo T-SQL en SSIS)

```sql
DECLARE @wm DATETIME2(0);

SELECT @wm = UltimoModifiedAt
FROM HR_Sintetico.hr.EtlWatermark
WHERE TablaFuente = N'hr.Ausencia';

SELECT *
FROM HR_Sintetico.hr.Ausencia
WHERE ModifiedAt > @wm;

-- Tras carga exitosa:
UPDATE HR_Sintetico.hr.EtlWatermark
SET UltimoModifiedAt = (SELECT MAX(SrcModifiedAt) FROM HR_Staging.stg.Ausencia WHERE LoadBatchID = @BatchID),
    UltimaEjecucion = SYSUTCDATETIME(),
    FilasProcesadas = @RowCount
WHERE TablaFuente = N'hr.Ausencia';
```

## 3. Secuencia de prueba end-to-end

```text
1. Instalar scripts SQL
2. Ejecutar PKG_HR_Fact_Inicial (baseline)
3. Validar conteos en Data Mart vs vistas OLTP
4. EXEC hr.usp_SimularDiaTransaccional
5. Ejecutar PKG_HR_Incremental_Diario
6. Verificar que hechos nuevos aparecen sin duplicar históricos
7. Refrescar Power BI
```

Repita los pasos 4–7 para demostrar **carga incremental** en la defensa del TFG.

## 4. Modelo Power BI (star schema)

Conecte a `HR_DataMart` (Import mode recomendado para PoC).

Relaciones:

- `DimFecha[FechaKey]` 1→* cada hecho (role-playing: use vistas/tablas calculadas `FechaSalida`, `FechaInicioAusencia` si necesita varias relaciones activas).
- `DimEmpleado`, `DimDepartamento`, `DimPuesto`, `DimUbicacion` → todos los hechos.
- `DimMotivoSalida` → `FactRotacion`
- `DimTipoAusencia` → `FactAusentismo`
- `DimHabilidad` → `FactHabilidadEmpleado`
- `DimEscalaSalarial` → `FactHeadcountMensual`

### Medidas DAX sugeridas

```dax
Salidas = SUM(FactRotacion[ContadorSalida])

Headcount = CALCULATE(SUM(FactHeadcountMensual[EsActivo]), FactHeadcountMensual[EsActivo]=TRUE())

Tasa Rotación % =
DIVIDE([Salidas], [Headcount])

Días Ausencia = SUM(FactAusentismo[DiasLaborales])

Días Impacto Productividad =
CALCULATE([Días Ausencia], DimTipoAusencia[AfectaProductividad]=TRUE())

% Gaps Habilidad =
DIVIDE(SUM(FactHabilidadEmpleado[TieneGap]), COUNTROWS(FactHabilidadEmpleado))

Gaps Críticos =
CALCULATE(SUM(FactHabilidadEmpleado[TieneGap]), DimHabilidad[IsCritical]=TRUE())

Salario Promedio = AVERAGE(FactHeadcountMensual[Salario])
```

## 5. Páginas de informe sugeridas

1. **Talento / Skills** — % gap por depto, matriz puesto×habilidad, críticos vs no críticos, capacitaciones.
2. **Rotación** — tendencia mensual, motivos (treemap), antigüedad al salir, evitables vs no evitables.
3. **Ausentismo** — heatmap mes×depto, tipos que afectan productividad, día de semana.
4. **Compensación** — salario promedio por depto/nivel, posición en banda, gap de género, outliers fuera de banda.

## 6. Validación rápida sin Data Mart (opcional)

Si aún no tiene ETLs, puede prototipar Power BI directo contra las vistas:

- `hr.vw_ResumenGapPorDepartamento`
- `hr.vw_RotacionDetalle`
- `hr.vw_AusentismoPorDeptoMes`
- `hr.vw_EquidadSalarialPorDepto`

Use esto solo para exploración; la arquitectura formal del TFG debe pasar por Staging + Data Mart.

## 7. Seguridad y ética (importante en TFG)

Aunque los datos son sintéticos:

- Trate cédulas/emails como PII de demostración.
- En Power BI, evite exponer identificadores sensibles en visuals ejecutivos.
- Declare en la memoria: datos ficticios generados para la PoC.
