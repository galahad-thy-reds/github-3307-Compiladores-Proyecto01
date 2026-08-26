# Guía práctica SSIS + Power BI

Guía operativa para mover datos desde `HR_Sintetico` (OLTP) hacia `HR_Staging` y luego hacia `HR_DataMart`, con **separación explícita** entre:

1. **Carga inicial (Full / histórica)**
2. **Carga incremental (diaria / por watermark)**

En ambos casos el camino es el mismo:

```text
HR_Sintetico (OLTP)
        │
        ▼  FASE A — Extracción
   HR_Staging (stg.*)
        │
        ▼  FASE B — Transformación / carga dimensional
   HR_DataMart (dm.*)
        │
        ▼
     Power BI
```

**Regla de oro:** nunca cargue dimensiones/hechos del Data Mart leyendo directo del OLTP en el mismo Data Flow “de producción”. Pase siempre por Staging (facilita auditoría, reproceso y defensa del TFG).

---

## 0. Preparación

### Connection Managers (SSIS)

| Nombre | Base | Uso |
|--------|------|-----|
| `CM_OLTP` | `HR_Sintetico` | Lectura origen |
| `CM_STG` | `HR_Staging` | Landing / control de batch |
| `CM_DM` | `HR_DataMart` | Dimensiones y hechos |

### Variables de paquete sugeridas

| Variable | Tipo | Ejemplo | Uso |
|----------|------|---------|-----|
| `User::BatchID` | GUID | `NEWID()` | Correlaciona toda la corrida |
| `User::LoadType` | String | `Full` / `Incremental` | Metadato en staging |
| `User::Watermark_*` | DateTime | valor de `hr.EtlWatermark` | Solo incremental |

### Paquetes SSIS (organización recomendada)

| Paquete | Cuándo | Responsabilidad |
|---------|--------|-----------------|
| `PKG_00_InitBatch` | Siempre | Abre/cierra `stg.EtlBatchLog`, asigna `BatchID` |
| `PKG_10_Full_OLTP_to_Staging` | **Solo carga inicial** | Extrae TODO el origen → staging (`LoadType='Full'`) |
| `PKG_20_Full_Staging_to_DataMart` | **Solo carga inicial** | Dimensiones + hechos históricos |
| `PKG_30_Inc_OLTP_to_Staging` | **Solo incremental** | Extrae cambios por `ModifiedAt` → staging |
| `PKG_40_Inc_Staging_to_DataMart` | **Solo incremental** | MERGE dims + INSERT hechos nuevos |
| `PKG_99_UpdateWatermarks` | Incremental (al final) | Actualiza `hr.EtlWatermark` si todo OK |

Orquestadores (Project Deployment / Master packages):

- `MST_CargaInicial` → `00` → `10` → `20`
- `MST_CargaIncremental` → `00` → `30` → `40` → `99`

### Prototipo T-SQL equivalente (sin SSIS aún)

Si quiere validar Full vs Incremental antes de armar paquetes, ejecute:

```sql
-- Tras instalar 04_DataMart/02_CreateStaging.sql y 03_EtlLoadHelpers.sql

EXEC HR_Staging.stg.usp_RunCargaInicial;       -- FULL: OLTP→Staging→DataMart + init watermarks

EXEC HR_Sintetico.hr.usp_SimularDiaTransaccional;
EXEC HR_Staging.stg.usp_RunCargaIncremental;   -- DELTA: watermark → Staging → MERGE/INSERT
```

| Procedimiento | Equivale a paquete |
|---------------|--------------------|
| `stg.usp_Full_ExtractOltpToStaging` | `PKG_10_Full_OLTP_to_Staging` |
| `stg.usp_Full_LoadStagingToDataMart` | `PKG_20_Full_Staging_to_DataMart` |
| `stg.usp_Inc_ExtractOltpToStaging` | `PKG_30_Inc_OLTP_to_Staging` |
| `stg.usp_Inc_LoadStagingToDataMart` | `PKG_40` + `PKG_99` |
| `stg.usp_RunCargaInicial` | `MST_CargaInicial` |
| `stg.usp_RunCargaIncremental` | `MST_CargaIncremental` |

La lógica de estos procedimientos es la **especificación ejecutable** de lo que SSIS debe implementar en Data Flows / Execute SQL Tasks.

---

# PARTE I — CARGA INICIAL (FULL)

Ejecutar **una vez** al montar el PoC, o después de:

```sql
EXEC hr.usp_ResetDemoData @Confirmar = 1;
EXEC hr.usp_SeedEmpleadosInicial;
```

## I.A — FASE A: OLTP → Staging (Full)

### Objetivo

Volcar una fotografía completa del origen en staging, sin transformaciones de negocio.

### Pasos del paquete `PKG_10_Full_OLTP_to_Staging`

1. **Execute SQL (STG):** registrar batch
   ```sql
   INSERT INTO stg.EtlBatchLog (BatchID, PackageName, LoadType, StartUTC, Status)
   VALUES (?, 'PKG_10_Full_OLTP_to_Staging', 'Full', SYSUTCDATETIME(), 'Running');
   ```
2. **Execute SQL (STG):** truncar tablas staging de trabajo
   ```sql
   TRUNCATE TABLE stg.Empleado;
   TRUNCATE TABLE stg.Ausencia;
   TRUNCATE TABLE stg.SalidaEmpleado;
   TRUNCATE TABLE stg.EmpleadoHabilidad;
   TRUNCATE TABLE stg.HistorialSalarial;
   -- (agregar stg de catálogos si las crea)
   ```
3. **Data Flows (uno por entidad)** — Source OLTP → Destination Staging

### Mapa de extracción FULL (dimensiones / catálogos)

| # | Origen OLTP | Destino Staging | Notas |
|---|-------------|-----------------|-------|
| 1 | `hr.Departamento` | `stg.Departamento` * | Crear tabla stg espejo si aún no existe |
| 2 | `hr.Puesto` | `stg.Puesto` * | |
| 3 | `hr.Ubicacion` | `stg.Ubicacion` * | |
| 4 | `hr.Habilidad` | `stg.Habilidad` * | |
| 5 | `hr.NivelHabilidad` | `stg.NivelHabilidad` * | |
| 6 | `hr.TipoAusencia` | `stg.TipoAusencia` * | |
| 7 | `hr.MotivoSalida` | `stg.MotivoSalida` * | |
| 8 | `hr.EscalaSalarial` | `stg.EscalaSalarial` * | |
| 9 | `hr.EstadoEmpleado` | `stg.EstadoEmpleado` * | |
| 10 | `hr.PuestoHabilidadRequerida` | `stg.PuestoHabilidadRequerida` * | Necesaria para FactHabilidad |

> Las tablas marcadas con `*` están modeladas conceptualmente; en el script base ya existen `stg.Empleado`, `stg.Ausencia`, `stg.SalidaEmpleado`, `stg.EmpleadoHabilidad`, `stg.HistorialSalarial`. Puede crear el resto como espejo 1:1 + columnas de control (`LoadBatchID`, `LoadDateUTC`, `LoadType`, `SrcModifiedAt`).

### Mapa de extracción FULL (hechos / transacciones)

| # | Origen OLTP | Destino Staging | Filtro FULL |
|---|-------------|-----------------|-------------|
| 11 | `hr.Empleado` | `stg.Empleado` | Sin filtro (todas las filas) |
| 12 | `hr.EmpleadoAsignacionHistorial` | `stg.EmpleadoAsignacionHistorial` * | Sin filtro |
| 13 | `hr.HistorialSalarial` | `stg.HistorialSalarial` | Sin filtro |
| 14 | `hr.EmpleadoHabilidad` | `stg.EmpleadoHabilidad` | Sin filtro |
| 15 | `hr.Ausencia` | `stg.Ausencia` | Sin filtro (o solo `Estado='Aprobada'` si prefiere filtrar temprano) |
| 16 | `hr.SalidaEmpleado` | `stg.SalidaEmpleado` | Sin filtro |
| 17 | `hr.EmpleadoCapacitacion` | `stg.EmpleadoCapacitacion` * | Opcional PoC |
| 18 | `hr.EvaluacionDesempeno` | `stg.EvaluacionDesempeno` * | Opcional PoC |

### Columnas de control a poblar en cada Data Flow FULL

| Columna staging | Valor |
|-----------------|-------|
| `LoadBatchID` | `@BatchID` |
| `LoadType` | `'Full'` |
| `LoadDateUTC` | `SYSUTCDATETIME()` (default en tabla) |
| `SrcModifiedAt` | `ModifiedAt` del origen |

### Criterio de éxito FASE A (Full)

```sql
-- Conteos origen vs staging (ejemplo)
SELECT 'OLTP Empleado' AS Src, COUNT(*) AS N FROM HR_Sintetico.hr.Empleado
UNION ALL
SELECT 'STG Empleado', COUNT(*) FROM HR_Staging.stg.Empleado WHERE LoadBatchID = @BatchID;
```

Los conteos deben coincidir (salvo filtros explícitos).

---

## I.B — FASE B: Staging → Data Mart (Full)

### Objetivo

Construir el modelo dimensional histórico desde staging.  
**Orden obligatorio:** primero dimensiones, después hechos.

```text
DimFecha
   → Dimensiones de catálogo (SCD1)
      → DimEmpleado (SCD2)
         → Hechos históricos
```

### B.1 Dimensiones — carga inicial

#### 1) `DimFecha`

```sql
USE HR_DataMart;
EXEC dm.usp_GenerarDimFecha
    @FechaInicio = '2019-01-01',
    @FechaFin    = NULL;  -- hoy + 2 años
```

No depende de staging. Ejecutar una sola vez (o ampliar rango si hace falta).

#### 2) Dimensiones de catálogo (SCD Tipo 1)

Patrón: **TRUNCATE + INSERT** en carga inicial (más simple y válido para PoC), o MERGE si prefiere idempotencia.

| Orden | Staging | Data Mart | Business Key |
|------:|---------|-----------|--------------|
| 1 | `stg.Departamento` | `dm.DimDepartamento` | `DepartamentoID` → `DepartamentoBK` |
| 2 | `stg.Puesto` | `dm.DimPuesto` | `PuestoID` |
| 3 | `stg.Ubicacion` | `dm.DimUbicacion` | `UbicacionID` |
| 4 | `stg.Habilidad` | `dm.DimHabilidad` | `HabilidadID` |
| 5 | `stg.TipoAusencia` | `dm.DimTipoAusencia` | `TipoAusenciaID` |
| 6 | `stg.MotivoSalida` | `dm.DimMotivoSalida` | `MotivoSalidaID` |
| 7 | `stg.EscalaSalarial` | `dm.DimEscalaSalarial` | `EscalaSalarialID` |

Ejemplo FULL (Departamento):

```sql
USE HR_DataMart;
TRUNCATE TABLE dm.DimDepartamento;

INSERT INTO dm.DimDepartamento (DepartamentoBK, Codigo, Nombre, CostoCentro)
SELECT DepartamentoID, Codigo, Nombre, CostoCentro
FROM HR_Staging.stg.Departamento
WHERE LoadBatchID = @BatchID;
```

#### 3) `DimEmpleado` (SCD Tipo 2) — carga inicial

En FULL, puede cargar **una versión actual por empleado** (simplificado) o **historizar** desde `EmpleadoAsignacionHistorial`.

**Opción recomendada para TFG (más Kimball):** una fila SCD2 por tramo de asignación.

```text
stg.EmpleadoAsignacionHistorial (+ stg.Empleado para nombre/género/fechas)
        →
dm.DimEmpleado
   FechaInicioValidez = FechaInicio
   FechaFinValidez    = FechaFin
   EsActual           = EsActual
```

Si prefiere simplificar la PoC:

```sql
TRUNCATE TABLE dm.DimEmpleado;

INSERT INTO dm.DimEmpleado
(EmpleadoBK, NumeroEmpleado, NombreCompleto, Genero, FechaNacimiento,
 FechaContratacion, TipoContrato, FechaInicioValidez, FechaFinValidez, EsActual)
SELECT
    e.EmpleadoID,
    e.NumeroEmpleado,
    CONCAT(e.Nombre, N' ', e.Apellido1),
    e.Genero,
    e.FechaNacimiento,
    e.FechaContratacion,
    e.TipoContrato,
    CAST(e.FechaContratacion AS DATETIME2(0)),
    NULL,
    1
FROM HR_Staging.stg.Empleado e
WHERE e.LoadBatchID = @BatchID;
```

### B.2 Hechos — carga inicial

**Antes de insertar hechos:** truncar tablas de hechos (solo en FULL).

```sql
TRUNCATE TABLE dm.FactRotacion;
TRUNCATE TABLE dm.FactAusentismo;
TRUNCATE TABLE dm.FactHabilidadEmpleado;
TRUNCATE TABLE dm.FactHeadcountMensual;
```

#### Orden de hechos FULL

| Orden | Hecho | Origen staging principal | Lookups (surrogate keys) |
|------:|-------|--------------------------|--------------------------|
| 1 | `FactRotacion` | `stg.SalidaEmpleado` | Fecha, Empleado, Depto, Puesto, Ubicación, Motivo |
| 2 | `FactAusentismo` | `stg.Ausencia` | Fecha inicio/fin, Empleado, Depto, Puesto, TipoAusencia |
| 3 | `FactHabilidadEmpleado` | `stg.Empleado` + skills + requisitos puesto | Fecha evaluación, Empleado, Depto, Puesto, Habilidad |
| 4 | `FactHeadcountMensual` | snapshot derivado de `stg.Empleado` (+ historial) | Fecha (1° del mes), Empleado, Depto, Puesto, Ubicación, Escala |

#### Ejemplo FULL — `FactRotacion`

```sql
INSERT INTO dm.FactRotacion
(
    FechaSalidaKey, EmpleadoKey, DepartamentoKey, PuestoKey, UbicacionKey,
    MotivoSalidaKey, AntiguedadMeses, SalarioAlSalir, ContadorSalida, EsEvitable
)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), s.FechaSalida, 112)),
    de.EmpleadoKey,
    dd.DepartamentoKey,
    dp.PuestoKey,
    du.UbicacionKey,
    dm.MotivoSalidaKey,
    DATEDIFF(MONTH, e.FechaContratacion, s.FechaSalida),
    s.SalarioAlSalir,
    1,
    ms.EsEvitable
FROM HR_Staging.stg.SalidaEmpleado s
INNER JOIN HR_Staging.stg.Empleado e
    ON e.EmpleadoID = s.EmpleadoID AND e.LoadBatchID = s.LoadBatchID
INNER JOIN dm.DimEmpleado de
    ON de.EmpleadoBK = s.EmpleadoID AND de.EsActual = 1
INNER JOIN dm.DimDepartamento dd ON dd.DepartamentoBK = s.DepartamentoID
INNER JOIN dm.DimPuesto dp ON dp.PuestoBK = s.PuestoID
INNER JOIN dm.DimUbicacion du ON du.UbicacionBK = s.UbicacionID
INNER JOIN dm.DimMotivoSalida dm ON dm.MotivoSalidaBK = s.MotivoSalidaID
INNER JOIN HR_Sintetico.hr.MotivoSalida ms ON ms.MotivoSalidaID = s.MotivoSalidaID
WHERE s.LoadBatchID = @BatchID;
```

> En SSIS puede implementar lo mismo con Lookup Transformations en lugar de JOINs T-SQL.

#### Ejemplo FULL — `FactAusentismo`

- Filtrar `Estado = 'Aprobada'`
- `FechaInicioKey` / `FechaFinKey` = `yyyymmdd`
- Lookup de `EmpleadoKey` (versión vigente a `FechaInicio`, o `EsActual=1` en PoC simplificada)
- Lookup `DepartamentoKey` / `PuestoKey` desde el empleado (o snapshot en staging)
- Lookup `TipoAusenciaKey`
- Medidas: `DiasLaborales`, `ContadorEvento=1`, `AfectaProductividad`

#### Ejemplo FULL — `FactHabilidadEmpleado`

Construir desde:

1. Empleados activos en staging  
2. Requisitos `PuestoHabilidadRequerida`  
3. Nivel actual en `EmpleadoHabilidad` (LEFT JOIN)  

Calcular:

- `TieneGap = 1` si nivel actual < requerido o NULL  
- `DiferenciaNiveles = requerido - ISNULL(actual,0)`  
- `EsCritica` / `EsObligatoria` desde catálogos  

Referencia de lógica ya disponible en OLTP: `hr.vw_GapHabilidades` (útil para validar, no como atajo de arquitectura).

#### Ejemplo FULL — `FactHeadcountMensual`

Para cada mes entre `MIN(FechaContratacion)` y hoy:

1. Empleados con `FechaContratacion <= fin_de_mes`  
2. Y (`FechaTerminacion IS NULL` OR `FechaTerminacion > inicio_de_mes`)  
3. Insertar una fila con `FechaKey = yyyymm01`, salario y keys dimensionales  

En PoC puede limitarse a los últimos 24 meses para acotar volumen.

### Criterio de éxito FASE B (Full)

| Validación | Cómo |
|------------|------|
| Dims pobladas | `SELECT COUNT(*) FROM dm.Dim*` > 0 |
| Salidas | `COUNT(FactRotacion) ≈ COUNT(hr.SalidaEmpleado)` |
| Ausencias | `COUNT(FactAusentismo)` ≈ ausencias aprobadas |
| Gaps | Totales cercanos a `hr.vw_ResumenGapPorDepartamento` |
| Orphans | Hechos sin dimensión = 0 (integrity lookups) |

Al terminar FULL, **inicialice watermarks** al máximo `ModifiedAt` visto:

```sql
UPDATE HR_Sintetico.hr.EtlWatermark
SET UltimoModifiedAt = ISNULL((SELECT MAX(ModifiedAt) FROM HR_Sintetico.hr.Empleado), '1900-01-01'),
    UltimaEjecucion = SYSUTCDATETIME(),
    FilasProcesadas = (SELECT COUNT(*) FROM HR_Sintetico.hr.Empleado),
    Notas = N'Baseline post carga inicial'
WHERE TablaFuente = N'hr.Empleado';

-- Repetir para: Ausencia, SalidaEmpleado, EmpleadoHabilidad,
-- HistorialSalarial, EmpleadoAsignacionHistorial, etc.
```

Sin este paso, la primera incremental re-extraería todo el histórico.

---

# PARTE II — CARGA INCREMENTAL

Ejecutar **después** de la carga inicial, típicamente una vez al día (o bajo demanda en la demo):

```sql
EXEC hr.usp_SimularDiaTransaccional;  -- genera cambios en OLTP
-- luego correr MST_CargaIncremental
```

## II.A — FASE A: OLTP → Staging (Incremental)

### Objetivo

Traer **solo filas nuevas o modificadas** desde el último watermark.

### Pasos del paquete `PKG_30_Inc_OLTP_to_Staging`

1. Abrir batch (`LoadType='Incremental'`).
2. **No truncar** toda la staging de golpe si quiere conservar historial de batches; alternativas:
   - **A (recomendada PoC):** truncar staging al inicio de cada incremental (staging = landing del día).
   - **B:** dejar acumular por `LoadBatchID` y procesar solo el batch actual en FASE B.
3. Por cada tabla fuente:
   - Leer watermark
   - Extraer `ModifiedAt > @wm`
   - Insertar en `stg.*` con `LoadType='Incremental'`

### Extracción incremental por entidad

| Entidad OLTP | ¿Va a Staging? | Impacto típico en Data Mart |
|--------------|----------------|-----------------------------|
| Catálogos (`Departamento`, `Puesto`, …) | Opcional diario / full pequeño | UPDATE SCD1 dims |
| `hr.Empleado` | Sí | SCD2 `DimEmpleado` + puede afectar hechos snapshot |
| `hr.EmpleadoAsignacionHistorial` | Sí | Cierre/alta versión SCD2 |
| `hr.HistorialSalarial` | Sí | Snapshot compensación / auditoría |
| `hr.EmpleadoHabilidad` | Sí | Recalcular/insertar gaps del empleado |
| `hr.Ausencia` | Sí | `FactAusentismo` (INSERT) |
| `hr.SalidaEmpleado` | Sí | `FactRotacion` (INSERT) + update empleado |

### Patrón Source (SSIS OLE DB Source / SQL Command)

```sql
DECLARE @wm DATETIME2(0) =
(
    SELECT UltimoModifiedAt
    FROM HR_Sintetico.hr.EtlWatermark
    WHERE TablaFuente = N'hr.Ausencia'
);

SELECT
    AusenciaID, EmpleadoID, TipoAusenciaID, FechaInicio, FechaFin,
    DiasLaborales, Estado, ModifiedAt AS SrcModifiedAt
FROM HR_Sintetico.hr.Ausencia
WHERE ModifiedAt > @wm;
```

Equivalente:

```sql
EXEC hr.usp_ObtenerCambiosDesde
    @TablaFuente = N'hr.Ausencia',
    @DesdeModifiedAt = ?;  -- parámetro desde variable SSIS
```

### Qué NO hacer en incremental hacia staging

- No re-extraer tablas completas “por si acaso” (rompe la demostración de incremental).
- No mezclar en la misma staging filas `Full` y `Incremental` del mismo batch sin discriminar por `LoadType`/`LoadBatchID`.

### Criterio de éxito FASE A (Incremental)

```sql
SELECT LoadType, COUNT(*) AS Filas
FROM HR_Staging.stg.Ausencia
WHERE LoadBatchID = @BatchID
GROUP BY LoadType;
-- Esperado: LoadType = Incremental, Filas > 0 tras usp_SimularDiaTransaccional
```

---

## II.B — FASE B: Staging → Data Mart (Incremental)

### Objetivo

Aplicar **solo el delta** del batch actual sobre el Data Mart, sin truncar hechos históricos.

### Orden incremental (igual que FULL, pero con MERGE/INSERT selectivo)

```text
1. Dimensiones catálogo (SCD1 MERGE)
2. DimEmpleado (SCD2)
3. Hechos transaccionales (INSERT si no existe)
4. Hechos de estado (gap skills / headcount del periodo)
5. Watermarks
```

### B.1 Dimensiones — incremental

#### Catálogos (SCD1)

```sql
MERGE dm.DimDepartamento AS t
USING (
    SELECT DepartamentoID AS DepartamentoBK, Codigo, Nombre, CostoCentro
    FROM HR_Staging.stg.Departamento
    WHERE LoadBatchID = @BatchID
) AS s
ON t.DepartamentoBK = s.DepartamentoBK
WHEN MATCHED AND (t.Nombre <> s.Nombre OR ISNULL(t.CostoCentro,'') <> ISNULL(s.CostoCentro,'')) THEN
    UPDATE SET t.Codigo = s.Codigo, t.Nombre = s.Nombre, t.CostoCentro = s.CostoCentro
WHEN NOT MATCHED THEN
    INSERT (DepartamentoBK, Codigo, Nombre, CostoCentro)
    VALUES (s.DepartamentoBK, s.Codigo, s.Nombre, s.CostoCentro);
```

Repita el patrón para Puesto, Ubicación, Habilidad, TipoAusencia, MotivoSalida, EscalaSalarial.

#### `DimEmpleado` (SCD2) — lógica incremental

Cuando llega un cambio de empleado/asignación:

1. Si cambió un atributo historiable (nombre, depto, puesto, etc. según diseño):
   - Cerrar versión actual: `EsActual=0`, `FechaFinValidez = hoy-1`
   - Insertar nueva versión: `EsActual=1`, `FechaInicioValidez = hoy`
2. Si solo cambió un atributo no historiable (según su matriz SCD), UPDATE in-place (SCD1).

Para la PoC, historiar al menos: departamento, puesto, ubicación (vía asignación) y datos personales básicos.

### B.2 Hechos — incremental

| Hecho | Operación incremental | Clave de idempotencia (evitar duplicados) |
|-------|------------------------|-------------------------------------------|
| `FactRotacion` | **INSERT** filas nuevas | `EmpleadoBK` (1 salida por empleado) o `SalidaEmpleadoID` si lo agrega como degenerate |
| `FactAusentismo` | **INSERT** eventos nuevos | `AusenciaID` (degenerate dimension / columna BK) |
| `FactHabilidadEmpleado` | **DELETE+INSERT** del empleado tocado, o MERGE por (`EmpleadoBK`,`HabilidadBK`) | Empleado + Habilidad |
| `FactHeadcountMensual` | **MERGE** del mes en curso (y meses afectados por altas/bajas) | (`FechaKey`,`EmpleadoBK`) |

#### Ejemplo incremental — `FactRotacion` (solo nuevas salidas)

```sql
INSERT INTO dm.FactRotacion (...)
SELECT ...
FROM HR_Staging.stg.SalidaEmpleado s
...
WHERE s.LoadBatchID = @BatchID
  AND NOT EXISTS (
        SELECT 1
        FROM dm.FactRotacion f
        INNER JOIN dm.DimEmpleado de ON de.EmpleadoKey = f.EmpleadoKey
        WHERE de.EmpleadoBK = s.EmpleadoID
  );
```

#### Ejemplo incremental — `FactAusentismo`

Igual patrón `NOT EXISTS` por `AusenciaID` (recomendado agregar `AusenciaBK INT NULL` al hecho si aún no está, o usar combinación Empleado+FechaInicio+Tipo).

#### Ejemplo incremental — gaps de habilidades

Para empleados presentes en `stg.EmpleadoHabilidad` del batch:

1. Borrar de `FactHabilidadEmpleado` las filas de esos `EmpleadoKey`
2. Recalcular e insertar el set completo de requisitos/gaps de esos empleados  

(Esto es más simple y correcto que intentar parchear celda por celda.)

#### Ejemplo incremental — headcount del mes

```sql
-- Pseudológica
-- 1) Identificar empleados tocados (altas, bajas, cambios salariales) en el batch
-- 2) MERGE FactHeadcountMensual para FechaKey = primer día del mes actual
```

### B.3 Actualizar watermarks — `PKG_99_UpdateWatermarks`

**Solo si FASE B terminó en Success.**

```sql
UPDATE w
SET
    w.UltimoModifiedAt = x.MaxSrc,
    w.UltimaEjecucion  = SYSUTCDATETIME(),
    w.FilasProcesadas  = x.Cnt,
    w.Notas            = N'Incremental OK'
FROM HR_Sintetico.hr.EtlWatermark w
INNER JOIN (
    SELECT MAX(SrcModifiedAt) AS MaxSrc, COUNT(*) AS Cnt
    FROM HR_Staging.stg.Ausencia
    WHERE LoadBatchID = @BatchID
) x ON 1 = 1
WHERE w.TablaFuente = N'hr.Ausencia';
```

Repetir por cada entidad extraída.  
Si el Data Flow de una entidad trae 0 filas, **no baje** el watermark; déjelo igual.

Cerrar batch:

```sql
UPDATE stg.EtlBatchLog
SET EndUTC = SYSUTCDATETIME(), Status = 'Success'
WHERE BatchID = @BatchID;
```

---

# PARTE III — Comparación lado a lado

| Aspecto | Carga inicial | Carga incremental |
|---------|---------------|-------------------|
| Disparador | Instalación / reset demo | Diario o post-`usp_SimularDiaTransaccional` |
| Staging | `TRUNCATE` + carga completa | Landing del delta (`ModifiedAt > watermark`) |
| `LoadType` | `Full` | `Incremental` |
| Dim catálogo | TRUNCATE+INSERT (o MERGE masivo) | MERGE SCD1 solo cambios |
| `DimEmpleado` | Carga histórica / versión base | SCD2 (cerrar + insertar) |
| Hechos | TRUNCATE + INSERT histórico | INSERT/MERGE delta; **no truncate** |
| Watermark | Se **inicializa** al final | Se **avanza** al final |
| Idempotencia | Recrear mart desde cero | `NOT EXISTS` / MERGE por BK |
| Volumen | Alto | Bajo |

```text
┌──────────────────────────────┐     ┌──────────────────────────────┐
│     MST_CargaInicial         │     │   MST_CargaIncremental       │
├──────────────────────────────┤     ├──────────────────────────────┤
│ 00 InitBatch (Full)          │     │ 00 InitBatch (Incremental)   │
│ 10 OLTP → Staging  (TODO)    │     │ 30 OLTP → Staging  (DELTA)   │
│ 20 Staging → DM              │     │ 40 Staging → DM (MERGE/INS)  │
│    - Dims TRUNCATE/INSERT    │     │    - Dims MERGE/SCD2         │
│    - Facts TRUNCATE/INSERT   │     │    - Facts INSERT idempotente│
│ Init watermarks = MAX(src)   │     │ 99 Advance watermarks        │
└──────────────────────────────┘     └──────────────────────────────┘
```

---

# PARTE IV — Secuencia de demostración (TFG)

```text
1. Instalar scripts SQL (OLTP + Staging + DataMart)
2. Ejecutar MST_CargaInicial
3. Validar conteos Data Mart vs vistas OLTP
4. Publicar/refrescar Power BI (baseline)
5. EXEC hr.usp_SimularDiaTransaccional
6. Ejecutar MST_CargaIncremental
7. Verificar:
     - nuevas filas en FactRotacion / FactAusentismo
     - sin duplicar el histórico de la carga inicial
     - watermarks avanzaron
8. Refrescar Power BI y mostrar el cambio
```

Repita 5–8 para evidenciar el ciclo incremental.

### Consultas de control rápidas

```sql
-- Batches
SELECT TOP 20 * FROM HR_Staging.stg.EtlBatchLog ORDER BY StartUTC DESC;

-- Watermarks
SELECT * FROM HR_Sintetico.hr.EtlWatermark ORDER BY TablaFuente;

-- Hechos
SELECT 'Rotacion' AS F, COUNT(*) AS N FROM HR_DataMart.dm.FactRotacion
UNION ALL SELECT 'Ausentismo', COUNT(*) FROM HR_DataMart.dm.FactAusentismo
UNION ALL SELECT 'Habilidades', COUNT(*) FROM HR_DataMart.dm.FactHabilidadEmpleado
UNION ALL SELECT 'Headcount', COUNT(*) FROM HR_DataMart.dm.FactHeadcountMensual;
```

---

# PARTE V — Power BI

Conecte a `HR_DataMart` (Import mode recomendado para PoC).

El diseño de tableros, KPIs, DAX y la decisión de **un solo `.pbix`** están en [`Guia_PowerBI_Tableros.md`](./Guia_PowerBI_Tableros.md). Aquí solo el contrato de modelo.

### Relaciones

- `DimFecha[FechaKey]` 1→\* cada hecho. Role-playing: `FactAusentismo[FechaFinKey]` queda **inactiva** (la activa es `FechaInicioKey`).
- `DimEmpleado`, `DimDepartamento`, `DimPuesto` → los 4 hechos.
- `DimUbicacion` → solo `FactHeadcountMensual` y `FactRotacion` (el mart no lleva ubicación en ausentismo ni skills).
- `DimMotivoSalida` → `FactRotacion`
- `DimTipoAusencia` → `FactAusentismo`
- `DimHabilidad` → `FactHabilidadEmpleado`
- `DimEscalaSalarial` → `FactHeadcountMensual`

`FactHeadcountMensual` es grano empleado×mes: **no** use `SUM(EsActivo)` como denominador anual de rotación. Use el promedio de headcount mensual (`AVERAGEX` sobre `AnioMes`). Detalle y medidas en la guía de tableros.

### Páginas de informe

Un archivo `HR_TableroMando.pbix`: Ejecutivo + Talento + Rotación + Ausentismo + Compensación.

### Prototipo temporal (solo exploración)

Si aún no tiene ETLs, puede mirar:

- `hr.vw_ResumenGapPorDepartamento`
- `hr.vw_RotacionDetalle`
- `hr.vw_AusentismoPorDeptoMes`
- `hr.vw_EquidadSalarialPorDepto`

La arquitectura formal del TFG debe pasar por **Staging + Data Mart**.

---

# PARTE VI — Seguridad y ética

Aunque los datos son sintéticos:

- Trate cédulas/emails como PII de demostración.
- En Power BI, evite exponer identificadores sensibles en visuals ejecutivos.
- Declare en la memoria: datos ficticios generados para la PoC.
