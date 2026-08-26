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

No relacione hechos entre sí. Si un visual necesita tasa, el DAX usa dos medidas (numerador del evento + denominador de headcount), no un join.

### 2.2 Lo que se oculta

Oculte en el panel de datos: `*Key`, `*BK`, `*ID` de hechos, `HashDiff`, `FechaInicioValidez`, `FechaFinValidez`. El usuario de negocio no debe construir gráficos arrastrando claves.

**No** ponga `DimEmpleado[EsActual] = 1` como filtro de informe. Los hechos históricos apuntan a la versión SCD2 vigente *en el evento*; filtrar “solo actual” borra salidas y ausencias de empleados que ya no están.

### 2.3 Columnas de apoyo (sí) vs medidas (solo tasas y filtros)

El mart ya trae medidas aditivas (`ContadorSalida`, `DiasLaborales`, `TieneGap`, `EsEvitable`, `AfectaProductividad`). **No las reescriba en DAX.**

Use **columna calculada** (o Power Query, preferible) cuando el valor se usa como *eje, leyenda o slicer*. Use **medida** cuando el valor es un agregado o un ratio.

| Columna | Tabla | Para qué |
|---------|-------|----------|
| `GeneroDesc` | `DimEmpleado` | `M`/`F`/`O` → Femenino / Masculino / Otro |
| `RangoAntiguedad` | `FactRotacion` y `FactHeadcountMensual` | Eje: 0–6 m, 6–12 m, 1–2 a, 2–4 a, 4+ a (misma lógica que `hr.vw_RotacionDetalle`) |
| `EstadoBanda` | `FactHeadcountMensual` | Bajo / Dentro / Sobre banda (`RELATED` a `DimEscalaSalarial`) |
| `PosicionEnBandaPct` | `FactHeadcountMensual` | Columna para histograma; la medida de promedio es aparte |
| `CriticaDesc` | `DimHabilidad` | Crítica / No crítica (evita filtrar bits en la UI) |
| `EvitableDesc` | `DimMotivoSalida` | Evitable / No evitable |
| `ImpactoProdDesc` | `DimTipoAusencia` | Afecta productividad / No afecta |

```dax
-- Columna en DimEmpleado
GeneroDesc =
SWITCH(
    DimEmpleado[Genero],
    "F", "Femenino",
    "M", "Masculino",
    "Otro"
)

-- Columna en FactRotacion (igual en FactHeadcountMensual con [AntiguedadMeses])
RangoAntiguedad =
VAR m = FactRotacion[AntiguedadMeses]
RETURN
    SWITCH(
        TRUE(),
        m < 6, "0-6 meses",
        m < 12, "6-12 meses",
        m < 24, "1-2 años",
        m < 48, "2-4 años",
        "4+ años"
    )

-- Columnas en FactHeadcountMensual
PosicionEnBandaPct =
DIVIDE(
    FactHeadcountMensual[Salario] - RELATED(DimEscalaSalarial[SalarioMinimo]),
    RELATED(DimEscalaSalarial[SalarioMaximo]) - RELATED(DimEscalaSalarial[SalarioMinimo])
)

EstadoBanda =
VAR s = FactHeadcountMensual[Salario]
VAR mn = RELATED(DimEscalaSalarial[SalarioMinimo])
VAR mx = RELATED(DimEscalaSalarial[SalarioMaximo])
RETURN
    SWITCH(
        TRUE(),
        s < mn, "Bajo banda",
        s > mx, "Sobre banda",
        "Dentro de banda"
    )
```

Ordene `RangoAntiguedad` y `NombreMes` con una columna numérica oculta (`Mes`, o un `RangoAntiguedadOrden` 1–5).

### 2.4 Filtros sincronizados

Slicers del informe (sincronizar en Ejecutivo, Rotación, Ausentismo, Compensación):

- `DimFecha[Anio]` y `DimFecha[NombreMes]` (no el día: el headcount vive en el día 1).
- `DimDepartamento[Nombre]`
- `DimPuesto[FamiliaPuesto]` y `NivelJerarquico`

**No sincronice fecha en Talento.** `FactHabilidadEmpleado` es el perfil vigente (empleado × habilidad requerida), no una serie mensual. Un slicer de año puede vaciar la página si la evaluación cayó en otro periodo. En esa página use `REMOVEFILTERS(DimFecha)` en las medidas de gap, o desactive la sincronización.

`DimUbicacion` solo recorta Headcount y Rotación. Si el usuario filtra “Alajuela”, Ausentismo y Talento **no** se reducen. Déjelo como slicer local de Rotación/Compensación, no global.

### 2.5 Lo que el Data Mart no tiene

No diseñe KPIs de **capacitaciones**, **evaluaciones de desempeño** ni **historial salarial evento a evento**: existen en el OLTP y no se cargaron a `dm`. Posición en banda y salario del snapshot mensual cubren la pregunta de equidad. Si el TFG pide formación, es una ampliación del mart, no un visual sobre `hr.EmpleadoCapacitacion`.

---

## 3. Medidas DAX (núcleo corto)

Ponga todas las medidas en una tabla de medidas (`_Medidas`) para no mezclarlas con columnas de hechos.

### 3.1 Aditivos (casi sin DAX)

```dax
Salidas = SUM ( FactRotacion[ContadorSalida] )

Eventos ausencia = SUM ( FactAusentismo[ContadorEvento] )

Días ausencia = SUM ( FactAusentismo[DiasLaborales] )

Requisitos skill = COUNTROWS ( FactHabilidadEmpleado )

Gaps = SUM ( FactHabilidadEmpleado[TieneGap] )

Salario promedio = AVERAGE ( FactHeadcountMensual[Salario] )
```

`Días impacto productividad` y `Salidas evitables` sí usan `CALCULATE` porque el filtro es de negocio, no un recálculo:

```dax
Días impacto productividad =
CALCULATE (
    [Días ausencia],
    DimTipoAusencia[AfectaProductividad] = TRUE ()
)

Salidas evitables =
CALCULATE (
    [Salidas],
    DimMotivoSalida[EsEvitable] = TRUE ()
)

Gaps críticos =
CALCULATE (
    [Gaps],
    DimHabilidad[IsCritical] = TRUE ()
)
```

### 3.2 Headcount — no sume meses como si fueran personas

`FactHeadcountMensual` tiene grano **empleado × mes**. `SUM(EsActivo)` en un año cuenta ~12 veces a cada persona. Sirve como *masa salarial mensual acumulada*, no como plantilla.

```dax
Headcount mes =
CALCULATE (
    SUM ( FactHeadcountMensual[EsActivo] ),
    FactHeadcountMensual[EsActivo] = TRUE ()
)

Headcount promedio =
AVERAGEX (
    VALUES ( DimFecha[AnioMes] ),
    [Headcount mes]
)
```

En un visual a grano mes, `[Headcount mes]` y `[Headcount promedio]` coinciden. En año o en “todo el historial”, use **promedio**. Esa es la medida que va en tarjetas ejecutivas y como denominador de tasas.

Masa salarial del periodo (promedio de la masa mensual, no la suma de 12 meses):

```dax
Masa salarial promedio =
AVERAGEX (
    VALUES ( DimFecha[AnioMes] ),
    CALCULATE ( SUM ( FactHeadcountMensual[Salario] ), FactHeadcountMensual[EsActivo] = TRUE () )
)
```

### 3.3 Tasas (aquí sí hace falta DAX)

```dax
Tasa rotación % =
DIVIDE ( [Salidas], [Headcount promedio] )

% salidas evitables =
DIVIDE ( [Salidas evitables], [Salidas] )

Antigüedad media al salir =
AVERAGE ( FactRotacion[AntiguedadMeses] )

% gaps =
DIVIDE ( [Gaps], [Requisitos skill] )

% gaps críticos =
DIVIDE (
    [Gaps críticos],
    CALCULATE ( [Requisitos skill], DimHabilidad[IsCritical] = TRUE () )
)

-- 22 = aproximación de días laborales/mes (documentar en el glosario)
Tasa ausentismo % =
DIVIDE ( [Días ausencia], [Headcount promedio] * 22 )

% días con impacto productividad =
DIVIDE ( [Días impacto productividad], [Días ausencia] )

Gap género % =
VAR PromM =
    CALCULATE ( [Salario promedio], DimEmpleado[Genero] = "M" )
VAR PromF =
    CALCULATE ( [Salario promedio], DimEmpleado[Genero] = "F" )
RETURN
    DIVIDE ( PromM - PromF, PromM )

% bajo banda =
DIVIDE (
    CALCULATE ( [Headcount mes], FactHeadcountMensual[EstadoBanda] = "Bajo banda" ),
    [Headcount mes]
)
```

`DIVIDE` evita errores por denominador 0. No use inteligencia de tiempo (`SAMEPERIODLASTYEAR`, etc.) en el PoC: la serie es corta y el seed no está diseñado para YoY estable. Un “vs periodo anterior” se defiende peor que una tendencia mensual simple.

Formato: tasas en porcentaje con 1 decimal; CRC en `#,0`; antigüedad en `0.0`.

---

## 4. Páginas y visualizaciones

Filtros de página comunes (salvo Talento): `EsActivo = 1` **solo** en visuals que lean `FactHeadcountMensual`. No lo aplique al informe entero.

En páginas ejecutivas **no** ponga `NumeroEmpleado` ni `NombreCompleto`. El detalle nominativo va, si acaso, a *drill-through* con el aviso de PII sintético.

### 4.1 Página Ejecutivo

Tesis de la página: “¿Dónde está el riesgo de gente?”. Cuatro tarjetas + cuatro gráficos que invitan a entrar a la página temática.

| Visual | Campos | Lectura esperada |
|--------|--------|------------------|
| Tarjeta | `[Headcount promedio]` | Plantilla del periodo |
| Tarjeta | `[Tasa rotación %]` | Comparar contra 1–1,5 % mensual como orden de magnitud (no hay meta en el mart) |
| Tarjeta | `[Tasa ausentismo %]` | Días perdidos / capacidad |
| Tarjeta | `[% gaps críticos]` | Talento en riesgo |
| Línea | Eje `DimFecha[AnioMes]`; `[Tasa rotación %]` y `[Tasa ausentismo %]` (eje combinado o dos líneas) | Co-movimiento en el tiempo |
| Barras agrupadas | Eje `DimDepartamento[Nombre]`; `[% gaps]`, `[Tasa rotación %]` | Tecnología alta en gaps; Operaciones alta en rotación/ausencia |
| Anillo (uno solo) | `[Salidas]` por `DimMotivoSalida[Categoria]` | Voluntaria vs involuntaria |
| Barras | `[Salario promedio]` por departamento | Comercial arriba, Operaciones abajo |

No llene el ejecutivo de matrices. Cada gráfico debe *hacer clic* hacia su página (botón o bookmark).

### 4.2 Página Talento — ¿Tenemos las habilidades correctas?

Hecho: `FactHabilidadEmpleado`. Grano: empleado × habilidad **requerida por el puesto**. Un gap es `NivelActual < NivelRequerido` (o sin evaluación: `NivelActual` nulo).

| KPI | Medida | Visual |
|-----|--------|--------|
| Cobertura con gap | `[% gaps]` | Tarjeta |
| Gaps en skills críticos | `[Gaps críticos]` y `[% gaps críticos]` | Tarjeta + KPI |
| Requisitos evaluados | `[Requisitos skill]` | Tarjeta de contexto (no es un KPI de negocio) |

| Visual | Configuración | Por qué |
|--------|----------------|---------|
| Barras horizontales | `DimDepartamento[Nombre]` vs `[% gaps]`; color por `[% gaps críticos]` o segundo eje `[Gaps críticos]` | El seed concentra el problema en Tecnología |
| Matriz | Filas `DimPuesto[Nombre]`; columnas `DimHabilidad[Nombre]`; valores `AVERAGE(NivelActual)` y `AVERAGE(NivelRequerido)` **o** `[% gaps]` | Perfil del puesto vs realidad. Formato condicional rojo si `% gaps` alto |
| Gráfico de columnas apiladas | Eje `DimHabilidad[Nombre]`; leyenda `CriticaDesc`; valor `[Gaps]` | SQL / ETL / Cloud / Ciberseguridad deben destacar |
| Dispersión | X `AVERAGE(NivelRequerido)`; Y `AVERAGE(NivelActual)`; tamaño `[Requisitos skill]`; detalle `DimHabilidad[Nombre]` | Puntos bajo la diagonal = déficit |
| Segmentación | `DimHabilidad[Categoria]`, `CriticaDesc`, `FactHabilidadEmpleado[EsObligatoria]` | Obligatorio vs deseable |
| Tabla *drill-through* (página aparte) | Puesto, habilidad, `NivelActual`, `NivelRequerido`, `DiferenciaNiveles` | Solo si la defensa pide el ejemplo; **sin** cédula |

No use un mapa de calor empleado × habilidad en el tablero de mando (~180 × N habilidades es ilegible). Eso es operacional, no ejecutivo.

Medida extra si el slicer de fecha queda activo por error:

```dax
% gaps (perfil actual) =
CALCULATE ( [% gaps], REMOVEFILTERS ( DimFecha ) )
```

### 4.3 Página Rotación — ¿Por qué se van y cuándo?

Hecho: `FactRotacion`. Grano: **una fila = una salida**.

| KPI | Medida |
|-----|--------|
| Salidas | `[Salidas]` |
| Tasa | `[Tasa rotación %]` |
| % evitables | `[% salidas evitables]` |
| Antigüedad media al salir | `[Antigüedad media al salir]` |

| Visual | Configuración | Hallazgo de diseño |
|--------|----------------|---------------------|
| Línea + columnas | Columnas `[Salidas]`; línea `[Tasa rotación %]`; eje `AnioMes` | Volumen vs tasa (la tasa usa headcount promedio del mes) |
| Barras apiladas | Eje `DimDepartamento[Nombre]`; leyenda `DimMotivoSalida[Nombre]` o `Categoria` | TI: `Mejor oferta salarial` / `Falta de crecimiento`. Operaciones: `Clima laboral` / `Bajo desempeño` |
| Anillo o barras | `[Salidas]` por `EvitableDesc` | Cuánto podría intervenir RH |
| Histograma (columnas) | Eje `RangoAntiguedad`; valor `[Salidas]` | ¿Se van en el primer año? |
| Cajas o columnas | `[Antigüedad media al salir]` y `AVERAGE(SalarioAlSalir)` por motivo | Precio de perder a alguien por oferta vs por desempeño |
| Tabla | Motivo, categoría, evitabilidad, salidas, % del total (`% of grand total` del visual, sin DAX nuevo) | |

No grafique `ContadorSalida` en un mapa si hay pocas sedes: cinco barras de `DimUbicacion[Nombre]` bastan.

### 4.4 Página Ausentismo — ¿Hay patrones que afecten productividad?

Hecho: `FactAusentismo` (solo ausencias **aprobadas**, grano evento). Relacione el análisis a `FechaInicio`.

| KPI | Medida |
|-----|--------|
| Días de ausencia | `[Días ausencia]` |
| Eventos | `[Eventos ausencia]` |
| Tasa | `[Tasa ausentismo %]` |
| % con impacto | `[% días con impacto productividad]` |

| Visual | Configuración | Hallazgo de diseño |
|--------|----------------|---------------------|
| Matriz tipo heatmap | Filas `DimDepartamento[Nombre]`; columnas `DimFecha[NombreMes]` (ordenar por `Mes`); valor `[Días ausencia]`; formato condicional de escala de color | Estacionalidad (enfermedad Dic/Ene; vacaciones Jul/Dic) y pico de Operaciones |
| Columnas apiladas | Eje `NombreMes`; leyenda `DimTipoAusencia[Nombre]`; `[Días ausencia]` | Composición del patrón |
| Barras | `DimTipoAusencia[Nombre]` vs `[Días ausencia]`; color por `ImpactoProdDesc` | Vacaciones y enfermedad pesan; `Capacitación externa` y `Teletrabajo excepcional` no marcan productividad |
| Línea | `[Tasa ausentismo %]` por `AnioMes` | Independiente del tamaño de plantilla |
| Columnas | `[Días ausencia]` por `DimFecha[NombreDiaSemana]` (ordenar por `DiaSemana`) | Patrones de lunes/viernes si el seed los produce |
| Tarjeta de desglose | `CALCULATE([Días ausencia], DimTipoAusencia[Nombre] = "Incapacidad por enfermedad")` — o un visual filtrado, **sin** una medida por cada tipo | El catálogo ya distingue tipos; un slicer de tipo > 8 medidas clonadas |

`FactAusentismo` no tiene `UbicacionKey`. No prometa un mapa de ausentismo por sede.

### 4.5 Página Compensación — ¿Es justa la estructura salarial?

Hecho: `FactHeadcountMensual` + `DimEscalaSalarial`. Trabaje con el **último mes del filtro** o con el promedio del periodo; no mezcle salarios de 24 meses en un “promedio” sin decirlo. Patrón limpio para “foto actual”:

```dax
Ultimo AnioMes =
CALCULATE ( MAX ( DimFecha[AnioMes] ), FactHeadcountMensual[EsActivo] = TRUE () )

Salario promedio actual =
VAR Periodo = [Ultimo AnioMes]
RETURN
    CALCULATE (
        [Salario promedio],
        FILTER ( ALL ( DimFecha[AnioMes] ), DimFecha[AnioMes] = Periodo )
    )
```

Úsela en esta página; en tendencia mensual use `[Salario promedio]` sin ese recorte.

| KPI | Medida |
|-----|--------|
| Salario promedio | `[Salario promedio actual]` o `[Salario promedio]` |
| Masa salarial | `[Masa salarial promedio]` |
| Gap de género | `[Gap género %]` |
| % bajo banda | `[% bajo banda]` |

| Visual | Configuración | Hallazgo de diseño |
|--------|----------------|---------------------|
| Barras | `[Salario promedio]` por `DimDepartamento[Nombre]` | Comercial por encima, Operaciones por debajo |
| Matriz | Filas departamento; columnas `DimEmpleado[GeneroDesc]`; `[Salario promedio]` | Gap leve en Tecnología |
| Columnas apiladas al 100 % | Eje `DimDepartamento[Nombre]`; leyenda `EstadoBanda`; `[Headcount mes]` | Gente fuera de banda |
| Dispersión | X `NivelJerarquico`; Y `Salario`; detalle empleado **solo en drill-through**; color departamento | Dispersión dentro del grado |
| Box-and-whisker o columnas | `DimEscalaSalarial[Codigo]` (G1–G5) vs min/promedio/max de `Salario` **y** líneas de `SalarioMinimo` / `SalarioMedio` / `SalarioMaximo` (esas tres son atributos de dimensión: `MIN`/`MAX` iguales por grado) | ¿La práctica respeta la política de bandas? |
| Histograma | Eje `PosicionEnBandaPct` (agrupar en buckets 0–20, 20–40… con columna o con el eje del visual) | Concentración bajo el medio de banda |

Para equidad, compare **mismo `NivelJerarquico` o mismo `Grado`**, no el promedio crudo del departamento (mezcla operarios y gerentes). La matriz Depto × Nivel es la que se defiende.

---

## 5. Qué no hacer

- Un visual por cada columna del diccionario. El catálogo alimenta *slicers y leyendas*, no 40 tarjetas.
- Medidas `CALCULATE` por cada departamento (`[Rotación TI]`, `[Rotación RH]`…). El eje `DimDepartamento` ya lo resuelve.
- `COUNTROWS(DimEmpleado)` como headcount: la dimensión es SCD2 y tiene inactivos.
- Tasa de rotación = `Salidas / SUM(EsActivo)` a nivel año (denominador inflado ~×12).
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

1. Import de las 9 dimensiones y 4 hechos; renombre quitar esquema `dm`.
2. Relaciones de la tabla §2.1; marcar `DimFecha`.
3. Ocultar claves; columnas de apoyo de §2.3; ordenar mes y rangos.
4. Tabla `_Medidas` con §3 (no más de ~20 medidas en el PoC).
5. Cinco páginas; slicers sincronizados salvo fecha en Talento y ubicación global.
6. Formato CRC / % ; tooltips con grano (“una barra = una salida”, “una celda = días de ausencia en el mes”).
7. Panel de formato: título que **afirma** el hallazgo (“Tecnología concentra el déficit de skills críticos”), no el nombre de la tabla.
8. En la memoria: un `.pbix`, modelo Import sobre `HR_DataMart`, tasas con `DIVIDE` y headcount promedio mensual.
