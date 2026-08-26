# Arquitectura Kimball — PoC RH

## 1. Capas

| Capa | Base | Rol |
|------|------|-----|
| Origen OLTP | `HR_Sintetico` | Sistema transaccional sintético (empleados, nómina lógica, ausencias, salidas, skills) |
| Staging | `HR_Staging` | Copia casi 1:1 del origen + metadatos de carga (`LoadBatchID`, `LoadType`, `SrcModifiedAt`) |
| Data Mart | `HR_DataMart` | Modelo dimensional en estrella (conformado a preguntas de RH) |
| Presentación | Power BI | Semántica, KPIs y tableros (ver `docs/Guia_PowerBI_Tableros.md`) |

## 2. Principios Kimball aplicados

- **Bus architecture / conformed dimensions:** `DimFecha`, `DimEmpleado`, `DimDepartamento`, `DimPuesto`, `DimUbicacion` se reutilizan en todos los hechos.
- **Grain declarado** por hecho (ver abajo).
- **SCD Tipo 2** en `DimEmpleado` (cambios de atributos relevantes en el tiempo).
- **Transactional facts** para eventos (salida, ausencia) y **periodic snapshot** para headcount/compensación mensual.

## 3. Grano de los hechos

### FactHabilidadEmpleado
- **Grano:** 1 fila = 1 empleado × 1 habilidad requerida por su puesto (evaluación vigente).
- **Medidas:** `NivelActual`, `NivelRequerido`, `TieneGap`, `DiferenciaNiveles`.
- **Pregunta:** ¿Tenemos las habilidades correctas?

### FactRotacion
- **Grano:** 1 fila = 1 salida de empleado.
- **Medidas:** `ContadorSalida`, `AntiguedadMeses`, `SalarioAlSalir`, `EsEvitable`.
- **Pregunta:** ¿Por qué se van y cuándo?

### FactAusentismo
- **Grano:** 1 fila = 1 evento de ausencia aprobada.
- **Medidas:** `DiasLaborales`, `ContadorEvento`, `AfectaProductividad`.
- **Pregunta:** ¿Hay patrones de falta que afecten productividad?

### FactHeadcountMensual
- **Grano:** 1 fila = 1 empleado activo (o estado) al cierre/inicio de mes.
- **Medidas:** `Salario`, `EsActivo`, `AntiguedadMeses`.
- **Uso:** denominador de tasas de rotación/ausentismo y análisis de compensación.

## 4. Mapeo origen → dimensión / hecho

| Origen (`hr.*`) | Destino |
|-----------------|---------|
| `Empleado` + `EmpleadoAsignacionHistorial` | `DimEmpleado` (SCD2), keys en hechos |
| `Departamento` | `DimDepartamento` |
| `Puesto` | `DimPuesto` |
| `Ubicacion` | `DimUbicacion` |
| `Habilidad` | `DimHabilidad` |
| `MotivoSalida` | `DimMotivoSalida` |
| `TipoAusencia` | `DimTipoAusencia` |
| `EscalaSalarial` | `DimEscalaSalarial` |
| calendario | `DimFecha` |
| `SalidaEmpleado` | `FactRotacion` |
| `Ausencia` | `FactAusentismo` |
| `EmpleadoHabilidad` + `PuestoHabilidadRequerida` | `FactHabilidadEmpleado` |
| snapshot mensual de `Empleado` | `FactHeadcountMensual` |
| `HistorialSalarial` | atributo/medida en snapshot o hecho satélite opcional |

## 5. Estrategia de carga

La separación detallada **Full vs Incremental** (dimensiones y hechos, Staging → Data Mart) está en [`Guia_SSIS_PowerBI.md`](./Guia_SSIS_PowerBI.md).

Resumen:

### Carga inicial (Full)
1. Truncar staging → extraer **todo** el OLTP (`LoadType='Full'`).
2. Cargar dimensiones (TRUNCATE/INSERT catálogos; `DimEmpleado`).
3. Truncar hechos → INSERT histórico.
4. Inicializar watermarks al `MAX(ModifiedAt)`.

### Carga incremental
1. Extraer `ModifiedAt > watermark` → staging (`LoadType='Incremental'`).
2. MERGE dimensiones (SCD1 catálogos / SCD2 empleado).
3. INSERT hechos nuevos con idempotencia (`NOT EXISTS` / MERGE). **No truncar** hechos.
4. Avanzar watermarks solo si la corrida fue exitosa.

Prototipo ejecutable: `04_DataMart/03_EtlLoadHelpers.sql` (`stg.usp_RunCargaInicial` / `stg.usp_RunCargaIncremental`).

## 6. Diagrama lógico

```text
                    ┌──────────────┐
                    │  DimFecha    │
                    └──────┬───────┘
                           │
 ┌────────────┐   ┌────────┴────────┐   ┌──────────────┐
 │DimEmpleado │───│ FactRotacion    │───│DimMotivoSalida│
 └─────┬──────┘   └─────────────────┘   └──────────────┘
       │
       ├────────── FactAusentismo ────── DimTipoAusencia
       │
       ├────────── FactHabilidadEmpleado ── DimHabilidad
       │
       └────────── FactHeadcountMensual ── DimEscalaSalarial
              │
              ├── DimDepartamento
              ├── DimPuesto
              └── DimUbicacion
```

## 7. Sesgos sintéticos (para storytelling del TFG)

Estos patrones están **intencionalmente** en el seed para que los tableros muestren hallazgos:

1. Gaps de skills críticos concentrados en Tecnología.
2. Motivos de salida distintos por departamento.
3. Ausentismo estacional + pico en Operaciones.
4. Diferencias salariales entre Comercial / Operaciones y gap leve de género en TI.

Documente en la memoria que los sesgos son de diseño (datos sintéticos), no conclusiones sobre una empresa real.

Los tableros que deben hacer visibles esos sesgos (páginas, KPIs y DAX mínimo) están en [`Guia_PowerBI_Tableros.md`](./Guia_PowerBI_Tableros.md).
