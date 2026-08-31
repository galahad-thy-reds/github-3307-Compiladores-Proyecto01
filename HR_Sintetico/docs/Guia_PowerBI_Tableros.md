# Tableros Power BI sobre HR_DataMart

Guía de diseño para el informe de mando de RH. Complementa el diccionario (`Diccionario_Datos.md`) y la Parte V de `Guia_SSIS_PowerBI.md`.

El Data Mart ya está **alineado a cuatro preguntas**. El informe no debe inventar un quinto dominio: debe hacer visibles esas preguntas, con `FactHeadcountMensual` como denominador común.

| Pregunta | Hecho | Dimensiones propias | Sesgo sintético a evidenciar |
|----------|-------|---------------------|------------------------------|
| ¿Tenemos las habilidades correctas? | `FactHabilidadEmpleado` | `DimHabilidad` | Gaps críticos concentrados en Tecnología (SQL, ETL, Cloud, etc.) |
| ¿Por qué se van y cuándo? | `FactRotacion` | `DimMotivoSalida` | TI: oferta/carrera. Operaciones: clima/desempeño |
| ¿Hay patrones de ausencia? | `FactAusentismo` | `DimTipoAusencia` | Estacionalidad Dic/Ene y Jul/Dic; pico de enfermedad en Operaciones |
| ¿Es justa la estructura salarial? | `FactHeadcountMensual` | `DimEscalaSalarial` | Comercial ~+8 %, Operaciones ~−8 %, gap leve de género en TI |

Los sesgos son de **diseño del seed**, no hallazgos de una empresa real. Declárelo en la memoria del TFG.

---

## 1. Un archivo o varios

**Recomendación: un solo `.pbix`** (`HR_TableroMando.pbix`) con un modelo semántico y **cinco páginas**.

| Alternativa | Cuándo tiene sentido | Por qué no aplica aquí |
|-------------|----------------------|------------------------|
| Varios `.pbix` cada uno con su copia del modelo | Equipos distintos, RLS distinta, refrescos independientes | Duplica dimensiones conformadas; rompe el tablero ejecutivo; ~180 empleados no justifican el costo |
| Un *dataset* publicado + informes delgados (thin reports) | Power BI Service, varios consumidores, un modelo gobernado | Correcto en empresa; excesivo para la PoC del TFG |
| Un `.pbix` / un dominio (Talento, Rotación…) | Informes muy grandes o audiencias que no deben verse entre sí | Las 4 preguntas comparten `DimFecha`, org. y el denominador de headcount |

Un archivo único es coherente con Kimball (*bus* de dimensiones conformadas): gerencia ve el resumen; analistas de RH entran a la página temática. Si más adelante publica en el servicio, el siguiente paso natural es **extraer el modelo** y dejar informes delgados, no partir el Data Mart.

Estructura del `.pbix`:

1. **Ejecutivo** — las 4 preguntas en una pantalla (audiencia: dirección).
2. **Talento** — gaps de habilidad.
3. **Rotación** — salidas, motivos, antigüedad.
4. **Ausentismo** — patrones y productividad.
5. **Compensación** — bandas, equidad, masa salarial.

Opcional (no la cuente como tablero de mando): página **Glosario / metodología** con grano de cada hecho y fórmulas de tasas. Sirve para la defensa.

---

## 2. Modelo semántico (antes de dibujar)

Conecte **solo** a `HR_DataMart` (esquema `dm`), modo **Import**. No mezcle vistas `hr.vw_*` del OLTP: son prototipo de exploración, no la capa de presentación del TFG.

### 2.1 Relaciones

Estrella clásica. Todas las relaciones **1 → \*** desde dimensión hacia hecho, filtro en un sentido (dimensión filtra hecho).

| Desde | Hacia | Activa | Notas |
|-------|-------|--------|-------|
| `DimFecha[FechaKey]` | `FactHeadcountMensual[FechaKey]` | Sí | Snapshot al **día 1** del mes |
| `DimFecha[FechaKey]` | `FactRotacion[FechaSalidaKey]` | Sí | |
| `DimFecha[FechaKey]` | `FactAusentismo[FechaInicioKey]` | Sí | La fecha de análisis de ausencia es el inicio |
| `DimFecha[FechaKey]` | `FactAusentismo[FechaFinKey]` | **No** | Role-playing; active con `USERELATIONSHIP` solo si un visual lo pide |
| `DimFecha[FechaKey]` | `FactHabilidadEmpleado[FechaEvaluacionKey]` | Sí | Ver §2.4: en Talento conviene *no* sincronizar el slicer de fecha |
| `DimEmpleado[EmpleadoKey]` | los 4 hechos | Sí | |
| `DimDepartamento[DepartamentoKey]` | los 4 hechos | Sí | |
| `DimPuesto[PuestoKey]` | los 4 hechos | Sí | |
| `DimUbicacion[UbicacionKey]` | `FactHeadcountMensual`, `FactRotacion` | Sí | **No** existe en Ausentismo ni Habilidades |
| `DimMotivoSalida` | `FactRotacion` | Sí | |
| `DimTipoAusencia` | `FactAusentismo` | Sí | |
| `DimHabilidad` | `FactHabilidadEmpleado` | Sí | |
| `DimEscalaSalarial` | `FactHeadcountMensual` | Sí | |

Marque `DimFecha[Fecha]` como **tabla de fechas**. No cree una tabla calendario en DAX: ya está en el mart.

Relacione **siempre** `DimFecha[FechaKey]` (entero `yyyymmdd`) con las `*Key` de los hechos. No una `Fecha` (tipo fecha) con un `FechaKey` (entero): Power BI deja crear la relación, **ninguna fila coincide** y todos los visuals con slicer de año/mes salen en blanco.

Desactive **Archivo → Opciones → Vista de modelo → Autodetectar nuevas relaciones**. Cree solo las de esta tabla. Borre cualquier relación extra, sobre todo si involucra `_Medidas`.

No relacione hechos entre sí. Si un visual necesita tasa, el DAX usa dos medidas (numerador del evento + denominador de headcount), no un join.

### 2.2 Lo que se oculta

Oculte en el panel de datos: `*Key`, `*BK`, `*ID` de hechos, `HashDiff`, `FechaInicioValidez`, `FechaFinValidez`. El usuario de negocio no debe construir gráficos arrastrando claves.

**No** ponga `DimEmpleado[EsActual]` como filtro de informe (ni `= 1` ni `= TRUE`). Los hechos históricos apuntan a la versión SCD2 vigente *en el evento*; filtrar “solo actual” borra salidas y ausencias de empleados que ya no están. Si el filtro no coincide con el tipo Boolean, **todas** las tablas de hechos quedan vacías y las medidas salen en blanco.

### 2.3 Columnas que usan los tableros

Dos capas:

1. **Nativas del mart** — se usan tal cual (eje, slicer, tooltip o filtro). El agregado vive en `_Medidas` (§3). Un `BIT` llega como Boolean: no lo ponga en `SUM`.
2. **Calculadas** — solo cuando el valor es una *etiqueta o bucket* (eje, leyenda, slicer u orden). Bit y códigos (`M`/`F`, `IsCritical`) no se arrastran a un visual de negocio.

Cree las calculadas en DAX (vista Informe → Nueva columna) o en Power Query; DAX es más fácil de citar en la memoria. Después de crearlas, configure **Ordenar por columna** (§2.3.3) y oculte las columnas de orden y las claves (§2.2).

Los agregados y tasas **no** van aquí: van a `_Medidas` (§3).

#### 2.3.1 Columnas nativas (sin expresión)

| Tabla | Columna | Rol en el informe | Páginas |
|-------|---------|-------------------|---------|
| `DimFecha` | `Anio` | Slicer global (no el día) | Ejecutivo, Rotación, Ausentismo, Compensación |
| `DimFecha` | `Mes` | Orden de `NombreMes` (ocultar) | Ausentismo, todas las que muestren mes |
| `DimFecha` | `NombreMes` | Eje / columnas del heatmap | Ausentismo |
| `DimFecha` | `AnioMes` | Eje de series (`yyyy-MM`, ya ordena bien) | Ejecutivo, Rotación, Ausentismo |
| `DimFecha` | `DiaSemana` | Orden de `NombreDiaSemana` (ocultar) | Ausentismo |
| `DimFecha` | `NombreDiaSemana` | Eje de patrón semanal | Ausentismo |
| `DimDepartamento` | `Nombre` | Eje y slicer de área | Todas |
| `DimPuesto` | `Nombre` | Filas de matriz de skills; drill-through | Talento |
| `DimPuesto` | `FamiliaPuesto` | Slicer global | Todas salvo Talento (opcional ahí) |
| `DimPuesto` | `NivelJerarquico` | Eje X de dispersión salarial; orden de la desc. | Compensación; slicer global |
| `DimUbicacion` | `Nombre` | Slicer **local** (no hay FK en Ausentismo ni Talento) | Rotación, Compensación |
| `DimHabilidad` | `Nombre` | Eje / columnas de matriz | Talento |
| `DimHabilidad` | `Categoria` | Slicer (Técnica, Blandas, Idioma…) | Talento |
| `DimHabilidad` | `IsCritical` | Solo filtro interno de medidas; no slicer | — |
| `DimMotivoSalida` | `Nombre` | Leyenda / filas de tabla | Rotación |
| `DimMotivoSalida` | `Categoria` | Anillo Voluntaria / Involuntaria | Ejecutivo, Rotación |
| `DimMotivoSalida` | `EsEvitable` | Solo filtro interno de medidas | — |
| `DimTipoAusencia` | `Nombre` | Leyenda y eje de tipos | Ausentismo |
| `DimTipoAusencia` | `AfectaProductividad` | Solo filtro interno de medidas | — |
| `DimEscalaSalarial` | `Codigo` | Eje G1–G5 | Compensación |
| `DimEscalaSalarial` | `Grado` | Orden de `Codigo` (ocultar si no se usa) | Compensación |
| `DimEscalaSalarial` | `SalarioMinimo`, `SalarioMedio`, `SalarioMaximo` | Líneas de política de banda (vía medidas §3) | Compensación |
| `DimEmpleado` | `Genero` | Solo filtro interno de `[Gap género %]` | — |
| `DimEmpleado` | `NombreCompleto`, `NumeroEmpleado` | Drill-through nominativo; **nunca** en Ejecutivo | Talento / Rotación (página detalle) |
| `FactRotacion` | `ContadorSalida` | Fuente de `[Salidas]`; no arrastrar al visual | — |
| `FactRotacion` | `AntiguedadMeses` | Fuente de `[Antigüedad media al salir]` | — |
| `FactRotacion` | `SalarioAlSalir` | Fuente de `[Salario al salir promedio]` | — |
| `FactAusentismo` | `DiasLaborales` | Fuente de `[Días ausencia]` | — |
| `FactAusentismo` | `ContadorEvento` | Fuente de `[Eventos ausencia]` | — |
| `FactHabilidadEmpleado` | `NivelActual`, `NivelRequerido` | Fuente de promedios; tooltip del drill-through | Talento |
| `FactHabilidadEmpleado` | `DiferenciaNiveles` | Fuente de `[Diferencia de niveles promedio]` | Talento (detalle) |
| `FactHabilidadEmpleado` | `TieneGap` | Boolean en PBI; fuente de `[Gaps]` vía `COUNTROWS`, no `SUM`; slicer = `GapDesc` | — |
| `FactHeadcountMensual` | `EsActivo` | Boolean en PBI; filtro `= TRUE ()` de plantilla/salario, no `SUM`; no filtro de informe | Compensación, denominadores |
| `FactHeadcountMensual` | `Salario` | Fuente de medidas salariales; eje Y de la **dispersión** (grano fila) | Compensación |

No cree columnas calculadas que solo copien un nativo (`DepartamentoNombre = RELATED(...)`). El modelo en estrella ya resuelve eso.

#### 2.3.2 Columnas calculadas (expresiones)

Cree **en este orden**: primero las de dimensión (no dependen de hechos), luego `PosicionEnBandaPct` y `EstadoBanda` (usan `RELATED`), luego buckets y órdenes. Cada columna de orden debe calcularse de las mismas entradas que el texto, **sin** leer el texto.

**`DimEmpleado[GeneroDesc]`** — matriz de equidad y slicer de Compensación.

```dax
GeneroDesc =
SWITCH (
    DimEmpleado[Genero],
    "F", "Femenino",
    "M", "Masculino",
    "Otro"
)
```

**`DimPuesto[NivelJerarquicoDesc]`** — slicer global y eje de equidad (el número 1–5 no se lee solo). Ordenar por `NivelJerarquico`.

```dax
NivelJerarquicoDesc =
SWITCH (
    DimPuesto[NivelJerarquico],
    1, "1 · Operativo",
    2, "2 · Analista / especialista",
    3, "3 · Senior / supervisor",
    4, "4 · Jefatura",
    5, "5 · Dirección",
    "Sin nivel"
)
```

**`DimHabilidad[CriticaDesc]`** — leyenda y slicer de Talento.

```dax
CriticaDesc =
IF ( DimHabilidad[IsCritical], "Crítica", "No crítica" )
```

**`DimMotivoSalida[EvitableDesc]`** — anillo/barras de Rotación.

```dax
EvitableDesc =
IF ( DimMotivoSalida[EsEvitable], "Evitable", "No evitable" )
```

**`DimTipoAusencia[ImpactoProdDesc]`** — color de barras de Ausentismo.

```dax
ImpactoProdDesc =
IF ( DimTipoAusencia[AfectaProductividad], "Afecta productividad", "No afecta productividad" )
```

**`DimTipoAusencia[EsRemuneradaDesc]`** — slicer opcional de Ausentismo (el catálogo lo trae; no requiere DAX de medida).

```dax
EsRemuneradaDesc =
IF ( DimTipoAusencia[EsRemunerada], "Remunerada", "No remunerada" )
```

**`FactHabilidadEmpleado[EsObligatoriaDesc]`** y **`GapDesc`** — slicers de Talento.

```dax
EsObligatoriaDesc =
IF ( FactHabilidadEmpleado[EsObligatoria], "Obligatoria", "Deseable" )

GapDesc =
IF ( FactHabilidadEmpleado[TieneGap], "Con gap", "Sin gap" )
```

**`FactHabilidadEmpleado[NivelActualDesc]`** y **`NivelRequeridoDesc`** — tabla de drill-through (N1–N5 del seed). `NivelActual` nulo = no evaluado.

```dax
NivelActualDesc =
SWITCH (
    FactHabilidadEmpleado[NivelActual],
    1, "1 · Básico",
    2, "2 · Intermedio",
    3, "3 · Avanzado",
    4, "4 · Experto",
    5, "5 · Maestro",
    "Sin evaluación"
)

NivelRequeridoDesc =
SWITCH (
    FactHabilidadEmpleado[NivelRequerido],
    1, "1 · Básico",
    2, "2 · Intermedio",
    3, "3 · Avanzado",
    4, "4 · Experto",
    5, "5 · Maestro"
)
```

**`RangoAntiguedad` + `RangoAntiguedadOrden`** — misma lógica que `hr.vw_RotacionDetalle`. Créelas en **las dos** tablas de hechos que tienen `AntiguedadMeses` (el histograma de Rotación usa la de `FactRotacion`; un slicer de plantilla usaría la de `FactHeadcountMensual`).

```dax
-- En FactRotacion
RangoAntiguedad =
VAR Meses = FactRotacion[AntiguedadMeses]
RETURN
    SWITCH (
        TRUE (),
        Meses < 6, "0-6 meses",
        Meses < 12, "6-12 meses",
        Meses < 24, "1-2 años",
        Meses < 48, "2-4 años",
        "4+ años"
    )

RangoAntiguedadOrden =
VAR Meses = FactRotacion[AntiguedadMeses]
RETURN
    SWITCH (
        TRUE (),
        Meses < 6, 1,
        Meses < 12, 2,
        Meses < 24, 3,
        Meses < 48, 4,
        5
    )
```

```dax
-- En FactHeadcountMensual (idéntico, cambiando la tabla)
RangoAntiguedad =
VAR Meses = FactHeadcountMensual[AntiguedadMeses]
RETURN
    SWITCH (
        TRUE (),
        Meses < 6, "0-6 meses",
        Meses < 12, "6-12 meses",
        Meses < 24, "1-2 años",
        Meses < 48, "2-4 años",
        "4+ años"
    )

RangoAntiguedadOrden =
VAR Meses = FactHeadcountMensual[AntiguedadMeses]
RETURN
    SWITCH (
        TRUE (),
        Meses < 6, 1,
        Meses < 12, 2,
        Meses < 24, 3,
        Meses < 48, 4,
        5
    )
```

Oculte `RangoAntiguedadOrden`. En cada tabla: `RangoAntiguedad` → Ordenar por → `RangoAntiguedadOrden`.

**`EsActivoN` y `TieneGapN`** — enteros 0/1. `INT` acepta Boolean y 1/0; las medidas filtran `= 1` y no vuelven a usar `SUM` ni `TRUE ()` sobre el `BIT`. Oculte estas columnas: no van a un slicer.

```dax
-- FactHeadcountMensual
EsActivoN = INT ( FactHeadcountMensual[EsActivo] )

-- FactHabilidadEmpleado
TieneGapN = INT ( FactHabilidadEmpleado[TieneGap] )
```

**`FactHeadcountMensual[PosicionEnBandaPct]`** — decimal 0–1 (formatear como %). Base del histograma y de `[Posición en banda promedio]`.

```dax
PosicionEnBandaPct =
DIVIDE (
    FactHeadcountMensual[Salario] - RELATED ( DimEscalaSalarial[SalarioMinimo] ),
    RELATED ( DimEscalaSalarial[SalarioMaximo] ) - RELATED ( DimEscalaSalarial[SalarioMinimo] )
)
```

**`FactHeadcountMensual[EstadoBanda]`** + **`EstadoBandaOrden`** — leyenda 100 % apilada y filtro de `[% bajo banda]`.

`EstadoBandaOrden` **no** puede leer `EstadoBanda`. Si lo hace, al aplicar Ordenar por columna Power BI cierra el ciclo (`EstadoBanda` → `EstadoBandaOrden` → `EstadoBanda`) y muestra *A circular dependency was detected*. Calcule el entero con las mismas entradas (salario vs min/máx).

```dax
EstadoBanda =
VAR Salario = FactHeadcountMensual[Salario]
VAR Minimo = RELATED ( DimEscalaSalarial[SalarioMinimo] )
VAR Maximo = RELATED ( DimEscalaSalarial[SalarioMaximo] )
RETURN
    SWITCH (
        TRUE (),
        Salario < Minimo, "Bajo banda",
        Salario > Maximo, "Sobre banda",
        "Dentro de banda"
    )

EstadoBandaOrden =
VAR Salario = FactHeadcountMensual[Salario]
VAR Minimo = RELATED ( DimEscalaSalarial[SalarioMinimo] )
VAR Maximo = RELATED ( DimEscalaSalarial[SalarioMaximo] )
RETURN
    SWITCH (
        TRUE (),
        Salario < Minimo, 1,
        Salario > Maximo, 3,
        2
    )
```

Si ya creó `EstadoBandaOrden` como `SWITCH ( FactHeadcountMensual[EstadoBanda], ... )`, edite esa expresión **antes** de volver a Ordenar por columna. No hace falta borrar la columna.

**`FactHeadcountMensual[PosicionEnBandaBucket]`** + **`PosicionEnBandaBucketOrden`** — eje del histograma (el visual de columnas no agrupa bien un % continuo).

```dax
PosicionEnBandaBucket =
VAR Pct = FactHeadcountMensual[PosicionEnBandaPct]
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( Pct ), "Sin banda",
        Pct < 0, "< 0% (bajo banda)",
        Pct < 0.20, "0-20%",
        Pct < 0.40, "20-40%",
        Pct < 0.60, "40-60%",
        Pct < 0.80, "60-80%",
        Pct <= 1, "80-100%",
        "> 100% (sobre banda)"
    )

PosicionEnBandaBucketOrden =
VAR Pct = FactHeadcountMensual[PosicionEnBandaPct]
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( Pct ), 0,
        Pct < 0, 1,
        Pct < 0.20, 2,
        Pct < 0.40, 3,
        Pct < 0.60, 4,
        Pct < 0.80, 5,
        Pct <= 1, 6,
        7
    )
```

#### 2.3.3 Ordenar por columna

| Columna visible | Tabla | Ordenar por | Ocultar la de orden |
|-----------------|-------|-------------|---------------------|
| `NombreMes` | `DimFecha` | `Mes` | `Mes` sí (si no se usa de otro modo) |
| `NombreDiaSemana` | `DimFecha` | `DiaSemana` | `DiaSemana` sí |
| `NombreTrimestre` | `DimFecha` | `Trimestre` | solo si la usa |
| `NivelJerarquicoDesc` | `DimPuesto` | `NivelJerarquico` | no |
| `Codigo` (G1–G5) | `DimEscalaSalarial` | `Grado` | no |
| `RangoAntiguedad` | `FactRotacion` y `FactHeadcountMensual` | `RangoAntiguedadOrden` | sí |
| `EstadoBanda` | `FactHeadcountMensual` | `EstadoBandaOrden` | sí |
| `PosicionEnBandaBucket` | `FactHeadcountMensual` | `PosicionEnBandaBucketOrden` | sí |
| `NivelActualDesc` / `NivelRequeridoDesc` | `FactHabilidadEmpleado` | `NivelActual` / `NivelRequerido` | no |

`AnioMes` (`yyyy-MM`) no necesita columna de orden.

La columna de orden **no debe referenciar** a la columna que ordena. *Ordenar por columna* añade una dependencia en el motor; si la fórmula ya iba en el otro sentido, Power BI reporta dependencia circular. `RangoAntiguedadOrden` y `PosicionEnBandaBucketOrden` ya salen de `AntiguedadMeses` / `PosicionEnBandaPct`, no del texto visible. No las reescriba como `SWITCH ( [RangoAntiguedad], ... )` ni `SWITCH ( [PosicionEnBandaBucket], ... )`.

#### 2.3.4 Dónde se usa cada calculada

| Columna | Visual / slicer | Página |
|---------|-----------------|--------|
| `GeneroDesc` | Columnas de la matriz depto × género | Compensación |
| `NivelJerarquicoDesc` | Slicer global; filas de matriz de equidad | Todas (slicer); Compensación |
| `CriticaDesc` | Leyenda de columnas de gaps; slicer | Talento |
| `EvitableDesc` | Anillo o barras evitables | Rotación |
| `ImpactoProdDesc` | Color de barras por tipo | Ausentismo |
| `EsRemuneradaDesc` | Slicer opcional | Ausentismo |
| `EsObligatoriaDesc`, `GapDesc` | Slicers | Talento |
| `NivelActualDesc`, `NivelRequeridoDesc` | Tabla drill-through | Talento (detalle) |
| `FactRotacion[RangoAntiguedad]` | Histograma de salidas | Rotación |
| `EstadoBanda` | Leyenda 100 % apilada | Compensación |
| `PosicionEnBandaPct` | No va al eje (es continuo); alimenta el bucket y la medida | Compensación |
| `PosicionEnBandaBucket` | Eje del histograma | Compensación |
| `EsActivoN`, `TieneGapN` | Solo las medidas §3.2 (ocultas) | — |

### 2.4 Filtros sincronizados

En Power BI un *slicer* (segmentación) recorta **solo la página donde está**, salvo que se indique lo contrario. **Filtros sincronizados** es esa excepción: la misma selección se replica en otras páginas del `.pbix`.

No es un filtro del panel (informe / página / visual) ni una relación bidireccional del modelo. Es una opción de la vista **Vista → Sincronizar segmentaciones** (*Sync slicers*). Por cada slicer y cada página hay dos casillas:

| Casilla | Qué hace |
|---------|----------|
| Filtro (el icono de sincronizar) | La selección de esa página **aplica** también aquí. El usuario elige “Tecnología” en Ejecutivo y, al ir a Rotación, los gráficos ya están recortados a Tecnología. |
| Visible (el ojo) | El slicer **se dibuja** en esa página. Puede sincronizar el filtro sin mostrar el control (la página hereda el recorte, pero no ocupa espacio). |

Flujo típico de este informe: ponga los slicers en **Ejecutivo**, márquelos como filtro en Rotación, Ausentismo y Compensación, y deje el ojo activo en esas páginas si quiere que el usuario cambie el recorte sin volver al ejecutivo. Si solo marca el filtro y no el ojo, esas páginas quedan “gobernadas” por Ejecutivo.

Sincronice estos slicers en Ejecutivo, Rotación, Ausentismo y Compensación:

- `DimFecha[Anio]` y `DimFecha[NombreMes]` (no el día: el headcount vive en el día 1).
- `DimDepartamento[Nombre]`
- `DimPuesto[FamiliaPuesto]` y `NivelJerarquicoDesc`

**No sincronice fecha en Talento.** `FactHabilidadEmpleado` es el perfil vigente (empleado × habilidad requerida), no una serie mensual. Un slicer de año puede vaciar la página si la evaluación cayó en otro periodo. En Vista → Sincronizar segmentaciones, desmarque el filtro de `Anio` / `NombreMes` para la página Talento. Como red de seguridad, `[% gaps (perfil actual)]` usa `REMOVEFILTERS ( DimFecha )` (§3). Departamento y familia de puesto sí pueden sincronizarse con Talento: el gap *sí* se recorta por área.

`DimUbicacion` solo recorta Headcount y Rotación. Si el usuario filtra “Alajuela”, Ausentismo y Talento **no** se reducen (no hay `UbicacionKey` en esos hechos). Déjelo como slicer **local** de Rotación y Compensación: no marque su casilla de filtro en las demás páginas.

Slicers temáticos (`CriticaDesc`, `EvitableDesc`, `ImpactoProdDesc`, `EstadoBanda`, etc.) también son locales: no tiene sentido llevar “skill crítica” a la página de ausentismo.

### 2.5 Lo que el Data Mart no tiene

No diseñe KPIs de **capacitaciones**, **evaluaciones de desempeño** ni **historial salarial evento a evento**: existen en el OLTP y no se cargaron a `dm`. Posición en banda y salario del snapshot mensual cubren la pregunta de equidad. Si el TFG pide formación, es una ampliación del mart, no un visual sobre `hr.EmpleadoCapacitacion`.

---

## 3. Tabla `_Medidas`

Todas las medidas del `.pbix` viven en **una sola tabla** `_Medidas`. Los hechos no deben mostrar medidas sueltas en el panel: el estudiante (y el jurado) ven un único catálogo.

Cree primero la tabla, luego las medidas **en el orden del catálogo §3.2** (cada ficha trae carpeta, formato y expresión). El §3.3 dice en qué visual se usa; el §4 no introduce DAX nuevo.

### 3.1 Cómo crear la tabla

1. Inicio → **Especificar datos** (Enter data).
2. Nombre de tabla: `_Medidas`. Una columna `_` con el valor `0`. Cargar.
3. En Vista de modelo: clic derecho en `_` → **Ocultar**.
4. Clic derecho en `_Medidas` → **Nueva medida** (no “nueva columna”).
5. Tras crear cada medida: Vista de modelo → panel Propiedades → **Carpeta para mostrar** (`00 Auxiliar`, `01 Headcount`, `02 Rotación`, `03 Ausentismo`, `04 Talento`, `05 Compensación`) → **Formato** de la ficha §3.2.
6. No oculte la tabla `_Medidas`: es el punto de entrada del modelo.
7. **No cree relaciones** desde `_Medidas` hacia ninguna tabla. Autodetectar a veces une `_` (el `0`) con una clave: el modelo se recorta a nada y todas las medidas quedan en blanco.
8. Las medidas **no tienen filas**. En Vista de datos/tabla `_Medidas` solo verá `_` = 0. Los valores salen en la **Vista de informe** (tarjeta, gráfico). Eso no es un error.

No cree una medida por departamento, por tipo de ausencia ni por mes. El eje o el slicer de la dimensión ya recorta el contexto.

### 3.2 Catálogo

Cree las 42 medidas **en este orden** (#1…#42): las tasas llaman a las aditivas. En Vista de modelo, carpeta y formato son los de cada ficha. CRC = `₡#,0`; % = `0.0%`; enteros = `#,0`; un decimal = `#,0.0`.

Las #1–#5, #17–#18 y #31 son de apoyo (tooltip u otras medidas). No clone variantes por departamento: el slicer recorta el contexto.

Índice: **00** #1–#2 · **01** #3–#5 · **02** #6–#11 · **03** #12–#16 · **04** #17–#26 · **05** #27–#42. Uso por visual en §3.3.

#### 00 Auxiliar

**1. `Días laborables mes`** — Entero. Constante 22: días laborales/mes supuestos en la tasa de ausentismo. Documente la hipótesis en el glosario; no la arrastre a un visual.

```dax
Días laborables mes = 22
```

**2. `Ultimo AnioMes`** — Texto. Último `yyyy-MM` con headcount activo en el filtro. Pie de Compensación y base de las variantes `* actual`.

```dax
Ultimo AnioMes =
CALCULATE (
    MAX ( DimFecha[AnioMes] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

#### 01 Headcount

`FactHeadcountMensual` es empleado × mes. Contar filas del snapshot en un año cuenta ~12 veces a cada persona. A grano mes, #3 y #4 coinciden. En tarjetas ejecutivas y denominadores de tasa use **#4**.

En Power BI un `BIT` de SQL llega como Boolean. Por eso existen `EsActivoN` y `TieneGapN` (§2.3.2): las medidas filtran `= 1`.

**3. `Headcount mes`** — Entero. Activos del contexto (a grano año es la suma de snapshots).

```dax
Headcount mes =
CALCULATE (
    COUNTROWS ( FactHeadcountMensual ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**4. `Headcount promedio`** — Entero (1 decimal opcional). Promedio de #3 **solo en meses que tienen snapshot**. No itere `VALUES ( DimFecha[AnioMes] )` sobre todo el calendario (2019–2028): la mayoría de meses no tienen hecho y, según el contexto, la media queda en blanco o diluida.

```dax
Headcount promedio =
AVERAGEX (
    SUMMARIZE ( FactHeadcountMensual, DimFecha[AnioMes] ),
    [Headcount mes]
)
```

**5. `Headcount actual`** — Entero. #3 recortado al #2.

```dax
Headcount actual =
VAR Periodo = [Ultimo AnioMes]
RETURN
    CALCULATE (
        [Headcount mes],
        FILTER ( ALL ( DimFecha[AnioMes] ), DimFecha[AnioMes] = Periodo )
    )
```

#### 02 Rotación

**6. `Salidas`** — Entero. Una fila del hecho = una salida.

```dax
Salidas = SUM ( FactRotacion[ContadorSalida] )
```

**7. `Salidas evitables`** — Entero. Subconjunto con `EsEvitable`. Tooltip de #9; no hace falta tarjeta propia.

```dax
Salidas evitables =
CALCULATE ( [Salidas], DimMotivoSalida[EsEvitable] = TRUE () )
```

**8. `Tasa rotación %`** — % 1 dec. Denominador = plantilla promedio, no la suma anual de snapshots.

```dax
Tasa rotación % =
DIVIDE ( [Salidas], [Headcount promedio] )
```

**9. `% salidas evitables`** — % 1 dec.

```dax
% salidas evitables =
DIVIDE ( [Salidas evitables], [Salidas] )
```

**10. `Antigüedad media al salir`** — Decimal 1. Meses desde contratación hasta la baja.

```dax
Antigüedad media al salir =
AVERAGE ( FactRotacion[AntiguedadMeses] )
```

**11. `Salario al salir promedio`** — CRC.

```dax
Salario al salir promedio =
AVERAGE ( FactRotacion[SalarioAlSalir] )
```

#### 03 Ausentismo

**12. `Eventos ausencia`** — Entero.

```dax
Eventos ausencia = SUM ( FactAusentismo[ContadorEvento] )
```

**13. `Días ausencia`** — Decimal 1.

```dax
Días ausencia = SUM ( FactAusentismo[DiasLaborales] )
```

**14. `Días impacto productividad`** — Decimal 1. Tipos con `AfectaProductividad` (enfermedad, vacaciones, etc.; no capacitación externa ni teletrabajo excepcional).

```dax
Días impacto productividad =
CALCULATE ( [Días ausencia], DimTipoAusencia[AfectaProductividad] = TRUE () )
```

**15. `Tasa ausentismo %`** — % 1 dec. Capacidad ≈ plantilla promedio × #1.

```dax
Tasa ausentismo % =
DIVIDE ( [Días ausencia], [Headcount promedio] * [Días laborables mes] )
```

**16. `% días con impacto productividad`** — % 1 dec.

```dax
% días con impacto productividad =
DIVIDE ( [Días impacto productividad], [Días ausencia] )
```

#### 04 Talento

**17. `Requisitos skill`** — Entero. Filas empleado × habilidad requerida por el puesto.

```dax
Requisitos skill = COUNTROWS ( FactHabilidadEmpleado )
```

**18. `Requisitos críticos`** — Entero. Denominador de #22.

```dax
Requisitos críticos =
CALCULATE ( [Requisitos skill], DimHabilidad[IsCritical] = TRUE () )
```

**19. `Gaps`** — Entero. Filtra `TieneGapN = 1` (§2.3.2).

```dax
Gaps =
CALCULATE (
    COUNTROWS ( FactHabilidadEmpleado ),
    FactHabilidadEmpleado[TieneGapN] = 1
)
```

**20. `Gaps críticos`** — Entero.

```dax
Gaps críticos =
CALCULATE ( [Gaps], DimHabilidad[IsCritical] = TRUE () )
```

**21. `% gaps`** — % 1 dec.

```dax
% gaps =
DIVIDE ( [Gaps], [Requisitos skill] )
```

**22. `% gaps críticos`** — % 1 dec.

```dax
% gaps críticos =
DIVIDE ( [Gaps críticos], [Requisitos críticos] )
```

**23. `% gaps (perfil actual)`** — % 1 dec. Tarjetas de Talento si el slicer de fecha del informe siguiera activo (§2.4).

```dax
% gaps (perfil actual) =
CALCULATE ( [% gaps], REMOVEFILTERS ( DimFecha ) )
```

**24. `Nivel actual promedio`** — Decimal 1. `AVERAGE` ignora `NivelActual` nulo (no evaluado).

```dax
Nivel actual promedio =
AVERAGE ( FactHabilidadEmpleado[NivelActual] )
```

**25. `Nivel requerido promedio`** — Decimal 1.

```dax
Nivel requerido promedio =
AVERAGE ( FactHabilidadEmpleado[NivelRequerido] )
```

**26. `Diferencia de niveles promedio`** — Decimal 1. Requerido − actual. Drill-through.

```dax
Diferencia de niveles promedio =
AVERAGE ( FactHabilidadEmpleado[DiferenciaNiveles] )
```

#### 05 Compensación

**27. `Salario promedio`** — CRC. Respeta el slicer de mes (si el mes es “todo el año”, mezcla snapshots).

```dax
Salario promedio =
CALCULATE (
    AVERAGE ( FactHeadcountMensual[Salario] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**28. `Salario promedio actual`** — CRC. Foto del #2. Tarjetas de Compensación.

```dax
Salario promedio actual =
VAR Periodo = [Ultimo AnioMes]
RETURN
    CALCULATE (
        [Salario promedio],
        FILTER ( ALL ( DimFecha[AnioMes] ), DimFecha[AnioMes] = Periodo )
    )
```

**29. `Salario mín`** — CRC. Mínimo de la *práctica* (hecho), no de la política.

```dax
Salario mín =
CALCULATE (
    MIN ( FactHeadcountMensual[Salario] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**30. `Salario máx`** — CRC. Máximo de la práctica.

```dax
Salario máx =
CALCULATE (
    MAX ( FactHeadcountMensual[Salario] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**31. `Masa salarial mes`** — CRC. Suma de salarios activos del contexto. Apoyo de #32 y #33.

```dax
Masa salarial mes =
CALCULATE (
    SUM ( FactHeadcountMensual[Salario] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**32. `Masa salarial promedio`** — CRC. Promedio de masas mensuales (no sume 12 meses).

```dax
Masa salarial promedio =
AVERAGEX (
    SUMMARIZE ( FactHeadcountMensual, DimFecha[AnioMes] ),
    [Masa salarial mes]
)
```

**33. `Masa salarial actual`** — CRC. Masa del #2.

```dax
Masa salarial actual =
VAR Periodo = [Ultimo AnioMes]
RETURN
    CALCULATE (
        [Masa salarial mes],
        FILTER ( ALL ( DimFecha[AnioMes] ), DimFecha[AnioMes] = Periodo )
    )
```

**34. `Gap género %`** — % 1 dec. (Promedio M − promedio F) / promedio M, en el filtro vigente.

```dax
Gap género % =
VAR PromM = CALCULATE ( [Salario promedio], DimEmpleado[Genero] = "M" )
VAR PromF = CALCULATE ( [Salario promedio], DimEmpleado[Genero] = "F" )
RETURN
    DIVIDE ( PromM - PromF, PromM )
```

**35. `Gap género % actual`** — % 1 dec. Igual, sobre #28.

```dax
Gap género % actual =
VAR PromM = CALCULATE ( [Salario promedio actual], DimEmpleado[Genero] = "M" )
VAR PromF = CALCULATE ( [Salario promedio actual], DimEmpleado[Genero] = "F" )
RETURN
    DIVIDE ( PromM - PromF, PromM )
```

**36. `Posición en banda promedio`** — % 1 dec. Media de la columna calculada `PosicionEnBandaPct` (§2.3.2). Formatee esa columna como %.

```dax
Posición en banda promedio =
CALCULATE (
    AVERAGE ( FactHeadcountMensual[PosicionEnBandaPct] ),
    FactHeadcountMensual[EsActivoN] = 1
)
```

**37. `% bajo banda`** — % 1 dec. Usa `EstadoBanda` (§2.3.2).

```dax
% bajo banda =
DIVIDE (
    CALCULATE ( [Headcount mes], FactHeadcountMensual[EstadoBanda] = "Bajo banda" ),
    [Headcount mes]
)
```

**38. `% sobre banda`** — % 1 dec.

```dax
% sobre banda =
DIVIDE (
    CALCULATE ( [Headcount mes], FactHeadcountMensual[EstadoBanda] = "Sobre banda" ),
    [Headcount mes]
)
```

**39. `% bajo banda actual`** — % 1 dec. #37 en el #2.

```dax
% bajo banda actual =
VAR Periodo = [Ultimo AnioMes]
RETURN
    CALCULATE (
        [% bajo banda],
        FILTER ( ALL ( DimFecha[AnioMes] ), DimFecha[AnioMes] = Periodo )
    )
```

**40. `Banda mínima`** — CRC. Política (`DimEscalaSalarial`), no la práctica. `MIN` es correcto: por grado el importe es constante (G3 = 950 000 CRC).

```dax
Banda mínima = MIN ( DimEscalaSalarial[SalarioMinimo] )
```

**41. `Banda media`** — CRC. Política. G3 = 1 200 000 CRC.

```dax
Banda media = MIN ( DimEscalaSalarial[SalarioMedio] )
```

**42. `Banda máxima`** — CRC. Política. G3 = 1 450 000 CRC.

```dax
Banda máxima = MIN ( DimEscalaSalarial[SalarioMaximo] )
```

### 3.3 Dónde se usa cada medida

Leyenda: T = tarjeta / KPI, V = visual (eje de valor), N = tooltip o título, — = no se arrastra (solo la consumen otras medidas).

#### Ejecutivo (§4.1)

| Visual | Medidas de `_Medidas` | Columnas (§2.3) |
|--------|----------------------|-----------------|
| Tarjeta plantilla | `[Headcount promedio]` | — |
| Tarjeta rotación | `[Tasa rotación %]` | — |
| Tarjeta ausentismo | `[Tasa ausentismo %]` | — |
| Tarjeta talento | `[% gaps críticos]` | — |
| Línea de tasas | `[Tasa rotación %]`, `[Tasa ausentismo %]` | `DimFecha[AnioMes]` |
| Barras agrupadas depto | `[% gaps]`, `[Tasa rotación %]` | `DimDepartamento[Nombre]` |
| Anillo categoría de salida | `[Salidas]` | `DimMotivoSalida[Categoria]` |
| Barras salario | `[Salario promedio]` | `DimDepartamento[Nombre]` |

Slicers de página: `DimFecha[Anio]`, `DimFecha[NombreMes]`, `DimDepartamento[Nombre]`, `DimPuesto[FamiliaPuesto]`, `DimPuesto[NivelJerarquicoDesc]`.

#### Talento (§4.2)

| Visual | Medidas de `_Medidas` | Columnas (§2.3) |
|--------|----------------------|-----------------|
| Tarjeta cobertura | `[% gaps]` o `[% gaps (perfil actual)]` | — |
| Tarjeta + KPI críticos | `[Gaps críticos]`, `[% gaps críticos]` | — |
| Tarjeta contexto | `[Requisitos skill]` | — |
| Barras horizontales | `[% gaps]`, `[% gaps críticos]` o `[Gaps críticos]` | `DimDepartamento[Nombre]` |
| Matriz puesto × skill | `[% gaps]`, `[Nivel actual promedio]`, `[Nivel requerido promedio]` | `DimPuesto[Nombre]`, `DimHabilidad[Nombre]` |
| Columnas apiladas | `[Gaps]` | `DimHabilidad[Nombre]`, `CriticaDesc` |
| Dispersión | `[Nivel requerido promedio]` (X), `[Nivel actual promedio]` (Y), `[Requisitos skill]` (tamaño) | `DimHabilidad[Nombre]` (detalle) |
| Slicers | — | `DimHabilidad[Categoria]`, `CriticaDesc`, `EsObligatoriaDesc`, `GapDesc` |
| Drill-through | `[Diferencia de niveles promedio]` | `DimPuesto[Nombre]`, `DimHabilidad[Nombre]`, `NivelActualDesc`, `NivelRequeridoDesc` |

En esta página use `[% gaps (perfil actual)]` en las **tarjetas** si el slicer de fecha del informe está sincronizado. En matrices y barras, `[% gaps]` basta si desactivó la sincronización de fecha (§2.4).

#### Rotación (§4.3)

| Visual | Medidas de `_Medidas` | Columnas (§2.3) |
|--------|----------------------|-----------------|
| Tarjetas | `[Salidas]`, `[Tasa rotación %]`, `[% salidas evitables]`, `[Antigüedad media al salir]` | — |
| Columnas + línea | `[Salidas]`, `[Tasa rotación %]` | `DimFecha[AnioMes]` |
| Barras apiladas | `[Salidas]` | `DimDepartamento[Nombre]`, `DimMotivoSalida[Nombre]` (o `Categoria`) |
| Anillo / barras | `[Salidas]` | `EvitableDesc` |
| Histograma | `[Salidas]` | `FactRotacion[RangoAntiguedad]` |
| Columnas por motivo | `[Antigüedad media al salir]`, `[Salario al salir promedio]` | `DimMotivoSalida[Nombre]` |
| Tabla | `[Salidas]` (+ % del total **del visual**) | `Nombre`, `Categoria`, `EvitableDesc` |
| Barras de sede (opcional) | `[Salidas]` | `DimUbicacion[Nombre]` |

`[Salidas evitables]` no hace falta en un visual: ya está en `[% salidas evitables]`. Puede dejarla en tooltip de la tarjeta.

#### Ausentismo (§4.4)

| Visual | Medidas de `_Medidas` | Columnas (§2.3) |
|--------|----------------------|-----------------|
| Tarjetas | `[Días ausencia]`, `[Eventos ausencia]`, `[Tasa ausentismo %]`, `[% días con impacto productividad]` | — |
| Heatmap | `[Días ausencia]` | `DimDepartamento[Nombre]` × `DimFecha[NombreMes]` |
| Columnas apiladas | `[Días ausencia]` | `DimFecha[NombreMes]`, `DimTipoAusencia[Nombre]` |
| Barras por tipo | `[Días ausencia]` | `DimTipoAusencia[Nombre]`, color `ImpactoProdDesc` |
| Línea | `[Tasa ausentismo %]` | `DimFecha[AnioMes]` |
| Columnas weekday | `[Días ausencia]` | `DimFecha[NombreDiaSemana]` |
| Slicer opcional | — | `EsRemuneradaDesc` |

Para “solo enfermedad”: filtre el visual con `DimTipoAusencia[Nombre] = "Incapacidad por enfermedad"`. No cree `[Días enfermedad]`. `[Días impacto productividad]` puede ir de tooltip en la tarjeta de `% días con impacto`. `[Días laborables mes]` no se arrastra: solo documenta el 22.

#### Compensación (§4.5)

| Visual | Medidas de `_Medidas` | Columnas (§2.3) |
|--------|----------------------|-----------------|
| Tarjetas (foto) | `[Salario promedio actual]`, `[Masa salarial actual]`, `[Gap género % actual]`, `[% bajo banda actual]` | — |
| Título / pie | `[Ultimo AnioMes]` | — |
| Barras por depto | `[Salario promedio]` | `DimDepartamento[Nombre]` |
| Matriz equidad | `[Salario promedio]` | `DimDepartamento[Nombre]` × `GeneroDesc` (añada `NivelJerarquicoDesc` en filas para defender) |
| 100 % apiladas | `[Headcount mes]` | `DimDepartamento[Nombre]`, `EstadoBanda` |
| Dispersión | **ninguna medida en Y** | X `NivelJerarquico` (o `NivelJerarquicoDesc`); Y `FactHeadcountMensual[Salario]`; color `DimDepartamento[Nombre]`. Grano = fila del snapshot |
| Política vs práctica | `[Salario mín]`, `[Salario promedio]`, `[Salario máx]`, `[Banda mínima]`, `[Banda media]`, `[Banda máxima]` | `DimEscalaSalarial[Codigo]` |
| Histograma | `[Headcount mes]` | `PosicionEnBandaBucket` |
| Tooltip | `[Posición en banda promedio]`, `[% sobre banda]` | — |

En barras/matriz/histograma de esta página, si el slicer de mes está en “todo el año”, `[Salario promedio]` mezcla snapshots. Las **tarjetas** usan las variantes `* actual`. Alternativa: filtre la página al `[Ultimo AnioMes]` y entonces `[Salario promedio]` = `[Salario promedio actual]`.

### 3.4 Orden de creación

Las expresiones están en el catálogo §3.2. Cree primero las columnas `EsActivoN` y `TieneGapN` (§2.3.2). Luego las medidas de #1 a #42: `#8 Tasa rotación %` necesita `#6` y `#4`; las variantes `* actual` necesitan `#2 Ultimo AnioMes`; `#37` necesita `EstadoBanda`.

### 3.5 Convenciones

- `DIVIDE` en todas las tasas (denominador 0 → en blanco, no error).
- Un `BIT` de SQL llega como Boolean. **No** use `SUM` sobre esas columnas. Use `EsActivoN` / `TieneGapN` (`INT`) y filtre `= 1`. Flags de dimensión (`EsEvitable`, `IsCritical`, `AfectaProductividad`) en `CALCULATE` sí pueden ir `= TRUE ()` si el tipo sigue siendo Boolean.
- No `SAMEPERIODLASTYEAR` ni equivalentes: el seed no está diseñado para YoY.
- No `COUNTROWS ( DimEmpleado )` como plantilla (SCD2 + bajas).
- `ContadorSalida`, `ContadorEvento` y `DiasLaborales` sí son numéricos: `SUM` es correcto.
- Formato: tasas `0.0%`; CRC `₡#,0`; antigüedad y niveles `#,0.0`; conteos `#,0`.
- Si **todas** las medidas salen en blanco, no siga pintando visuals: vaya a §3.6.

### 3.6 Medidas en blanco (diagnóstico)

Los hechos se ven en Vista de datos y las medidas no. Eso es normal **en parte**: las medidas no tienen filas. El resto suele ser filtro o relación, no “el DAX está mal copiado”.

Haga las pruebas **en este orden**, en una página nueva sin slicers ni filtros de página/informe.

| # | Prueba | Si muestra número | Si sigue en blanco |
|---|--------|-------------------|--------------------|
| 1 | Tarjeta con `Días laborables mes` (constante 22) | El motor evalúa medidas | La medida no es medida (es columna) o el visual está roto |
| 2 | Tarjeta `COUNTROWS ( FactRotacion )` (medida temporal) | El hecho no está filtrado a vacío | Relación o filtro de informe recorta el modelo; ver 3–5 |
| 3 | Tarjeta `[Salidas]` | `SUM` numérico funciona | Filtro de informe / slicer sincronizado / `EsActual` |
| 4 | Tarjeta `[Headcount mes]` | `EsActivoN` está bien | Falta la columna `EsActivoN`, o no hay filas con `= 1` |
| 5 | Misma tarjeta **con** slicer de año | El `FechaKey` une bien | Relacionó `DimFecha[Fecha]` con un `*Key` entero, o el año del slicer no tiene hechos (el snapshot son ~24 meses) |

Causas que vacían **todas** las medidas a la vez:

1. **Está mirando Vista de datos de `_Medidas`.** Solo existe `_` = 0. Pase a Vista de informe y ponga una **tarjeta**.
2. **`_Medidas` tiene una relación.** Bórrela. Autodetectar no debe estar activo.
3. **Filtro de informe** en `DimEmpleado[EsActual]` o `EsActivo = 1` (el `BIT` es Boolean: `1` no coincide → cero filas en la dimensión → los 4 hechos quedan vacíos).
4. **Slicers sincronizados** en un año/mes sin hechos. `FactHeadcountMensual` cubre los últimos ~24 meses, no todo `DimFecha` (desde 2019). Desmarque el slicer o elija un mes reciente.
5. **Relación de fecha mal tipada** (`Fecha` date vs `FechaKey` int). Debe ser `DimFecha[FechaKey]` → `Fact*[Fecha*Key]`, activa, 1 a muchos, filtro en un sentido.
6. **`[Headcount promedio]` iterando todo el calendario.** Use `SUMMARIZE ( FactHeadcountMensual, DimFecha[AnioMes] )` como en #4. Las tasas del ejecutivo dependen de esa medida: si ella está en blanco, `[Tasa rotación %]` y `[Tasa ausentismo %]` también.

Medidas temporales de diagnóstico (bórrrelas después):

```dax
_Diag filas rotación = COUNTROWS ( FactRotacion )
_Diag filas headcount = COUNTROWS ( FactHeadcountMensual )
_Diag filas skill = COUNTROWS ( FactHabilidadEmpleado )
_Diag activo = CALCULATE ( COUNTROWS ( FactHeadcountMensual ), FactHeadcountMensual[EsActivoN] = 1 )
```

Si `_Diag filas rotación` tiene número y `[Salidas]` no, la expresión de `#6` no es la del catálogo (columna calculada, nombre de tabla distinto, o `SUM` sobre otra columna). Si `_Diag filas headcount` tiene número y `_Diag activo` no, cree `EsActivoN` y revise que `INT ( EsActivo )` dé 1.

---

## 4. Páginas y visualizaciones

Las medidas se toman **solo** de `_Medidas` (expresión en §3.2; mapa visual en §3.3). Las columnas, de §2.3. Este apartado describe la tesis de cada página, no vuelve a definir DAX.

Filtros de página comunes (salvo Talento): `EsActivoN = 1` **solo** en visuals que lean `FactHeadcountMensual`. No lo aplique al informe entero (vaciaría fechas/depto para los otros hechos si el filtro se malinterpreta). No use `EsActivo = 1` sobre el Boolean original.

En páginas ejecutivas **no** ponga `NumeroEmpleado` ni `NombreCompleto`. El detalle nominativo va, si acaso, a *drill-through* con el aviso de PII sintético.

### 4.1 Página Ejecutivo

Tesis: “¿Dónde está el riesgo de gente?”. Cuatro tarjetas + cuatro gráficos que invitan a entrar a la página temática. Campos: §3.3 → Ejecutivo.

Lectura esperada: `[Tasa rotación %]` en el orden de 1–1,5 % mensual (no hay meta en el mart); Tecnología alta en `[% gaps]`; Operaciones alta en rotación; Comercial arriba en `[Salario promedio]`.

No llene el ejecutivo de matrices. Cada gráfico debe *hacer clic* hacia su página (botón o bookmark).

### 4.2 Página Talento — ¿Tenemos las habilidades correctas?

Hecho: `FactHabilidadEmpleado`. Grano: empleado × habilidad **requerida por el puesto**. Un gap es `NivelActual < NivelRequerido` (o sin evaluación: `NivelActual` nulo). Campos: §3.3 → Talento.

El seed concentra el problema en Tecnología. En la matriz, formato condicional rojo si `[% gaps]` es alto. En la dispersión, puntos bajo la diagonal = déficit (SQL / ETL / Cloud / Ciberseguridad). Slicers: `Categoria`, `CriticaDesc`, `EsObligatoriaDesc` (no el bit `EsObligatoria`).

No use un mapa de calor empleado × habilidad (~180 × N es ilegible). El drill-through va **sin** cédula.

### 4.3 Página Rotación — ¿Por qué se van y cuándo?

Hecho: `FactRotacion`. Grano: **una fila = una salida**. Campos: §3.3 → Rotación.

Hallazgos de diseño: TI → `Mejor oferta salarial` / `Falta de crecimiento`; Operaciones → `Clima laboral` / `Bajo desempeño`. El histograma de `RangoAntiguedad` responde si se van en el primer año. El % del total de la tabla es la opción del visual, no una medida nueva.

No grafique `ContadorSalida` en un mapa: cinco barras de `DimUbicacion[Nombre]` con `[Salidas]` bastan.

### 4.4 Página Ausentismo — ¿Hay patrones que afecten productividad?

Hecho: `FactAusentismo` (solo ausencias **aprobadas**, grano evento). Relacione el análisis a `FechaInicio`. Campos: §3.3 → Ausentismo.

Hallazgos: heatmap con estacionalidad (enfermedad Dic/Ene; vacaciones Jul/Dic) y pico de Operaciones. Vacaciones y enfermedad pesan; `Capacitación externa` y `Teletrabajo excepcional` no marcan productividad (`ImpactoProdDesc`). Un visual filtrado a “Incapacidad por enfermedad” sustituye a una medida por tipo.

`FactAusentismo` no tiene `UbicacionKey`. No prometa un mapa de ausentismo por sede.

### 4.5 Página Compensación — ¿Es justa la estructura salarial?

Hecho: `FactHeadcountMensual` + `DimEscalaSalarial`. Campos: §3.3 → Compensación.

Tarjetas = variantes `* actual` (foto de `[Ultimo AnioMes]`). Barras y matriz de tendencia = `[Salario promedio]` (respeta el slicer de mes). La dispersión es la excepción: eje Y = columna `Salario`, no una medida (grano fila). El histograma usa `PosicionEnBandaBucket`, no el % continuo.

Hallazgos: Comercial por encima, Operaciones por debajo; gap leve de género en Tecnología; gente fuera de `EstadoBanda`. Compare equidad a **mismo `NivelJerarquicoDesc` o mismo `Codigo` de escala**, no el promedio crudo del departamento.

---

## 5. Qué no hacer

- Un visual por cada columna del diccionario. El catálogo alimenta *slicers y leyendas*, no 40 tarjetas.
- Medidas `CALCULATE` por cada departamento (`[Rotación TI]`, `[Rotación RH]`…). El eje `DimDepartamento` ya lo resuelve.
- `COUNTROWS(DimEmpleado)` como headcount: la dimensión es SCD2 y tiene inactivos.
- Tasa de rotación = `Salidas / COUNTROWS` del snapshot a nivel año (denominador inflado ~×12). Use `[Headcount promedio]`.
- Mapa de Costa Rica como visual estrella: Bing suele resolver mal cantones; barras por `Provincia` / `Nombre` de sede son más honestas.
- Donuts encadenados. Uno en ejecutivo (voluntaria/involuntaria) es suficiente.
- Mezclar `hr.vw_EquidadSalarialPorDepto` con el mart en el mismo modelo “para validar”: valide en SQL (`03_ConsultasValidacion.sql`) y publique solo `dm`.

---

## 6. Narración para la defensa

Recorra el ejecutivo y baje a la página donde el sesgo es obvio:

1. Talento: Tecnología con `% gaps críticos` alto en SQL, ETL, Cloud.
2. Rotación: mismos departamentos, motivos distintos (oferta vs clima).
3. Ausentismo: heatmap con temporada y Operaciones.
4. Compensación: Comercial vs Operaciones y la columna de género en TI.

Cierre con el límite del modelo: capacitaciones y desempeño siguen en el OLTP; el mart responde las cuatro preguntas con hechos de grano declarado.

---

## 7. Checklist de implementación

1. Import de las 9 dimensiones y 4 hechos; renombre quitar esquema `dm`. Desactive autodetectar relaciones.
2. Relaciones de la tabla §2.1 (`FechaKey` entero con `FechaKey`); marcar `DimFecha[Fecha]`. Ninguna relación a `_Medidas`.
3. Ocultar claves; columnas nativas + calculadas de §2.3 (incluya `EsActivoN` y `TieneGapN`); Ordenar por columna (§2.3.3).
4. Tabla `_Medidas` (§3.1–3.2): 42 medidas con su DAX; no cree medidas extra por depto o tipo. Si salen en blanco, §3.6.
5. Cinco páginas según el mapa §3.3; Vista → Sincronizar segmentaciones (§2.4): fecha/depto/familia en Ejecutivo + Rotación + Ausentismo + Compensación; no sincronice fecha en Talento ni ubicación en todo el informe.
6. Formato CRC / % ; tooltips con grano (“una barra = una salida”, “una celda = días de ausencia en el mes”).
7. Panel de formato: título que **afirma** el hallazgo (“Tecnología concentra el déficit de skills críticos”), no el nombre de la tabla.
8. En la memoria: un `.pbix`, modelo Import sobre `HR_DataMart`, tasas con `DIVIDE` y headcount promedio mensual.
