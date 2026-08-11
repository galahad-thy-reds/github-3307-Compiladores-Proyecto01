# HR_Sintetico — Fuente transaccional sintética para PoC de RH

Prueba de concepto de Business Intelligence / Data Warehousing para Recursos Humanos, orientada a un trabajo final de graduación (modalidad práctica empresarial).

Stack objetivo: **SQL Server 2025**, **SSIS**, **Power BI**, metodología **Ralph Kimball** (Staging → Data Mart dimensional).

---

## Qué incluye este repositorio

| Carpeta | Contenido |
|---------|-----------|
| `01_DDL/` | Creación de `HR_Sintetico` (OLTP) y tablas |
| `02_Seed/` | Catálogos + ~180 empleados con historial, ausencias, salidas, habilidades |
| `03_Procedures/` | SPs para generar cambios incrementales + vistas de negocio |
| `04_DataMart/` | `HR_Staging` + `HR_DataMart` (modelo estrella Kimball) |
| `docs/` | Arquitectura, mapeo a preguntas de negocio y guía SSIS/Power BI |

---

## Instalación rápida (SSMS)

Ejecute **en este orden**, conectado a su instancia SQL Server:

1. `01_DDL/00_CreateDatabase.sql`
2. `01_DDL/01_CreateTables.sql`
3. `02_Seed/01_SeedCatalogos.sql`
4. `02_Seed/02_SeedEmpleadosYTransacciones.sql` (crea y ejecuta `hr.usp_SeedEmpleadosInicial`)
5. `03_Procedures/01_ProcedimientosSimulacion.sql`
6. `03_Procedures/02_VistasAnalisisNegocio.sql`
7. `04_DataMart/02_CreateStaging.sql`
8. `04_DataMart/01_CreateDataMart.sql`
9. (Opcional) `EXEC dm.usp_GenerarDimFecha;` en `HR_DataMart`

Bases creadas:

- `HR_Sintetico` — fuente transaccional (origen)
- `HR_Staging` — landing / staging area
- `HR_DataMart` — data mart dimensional

---

## Generar más cambios (pruebas de ETL incremental)

```sql
USE HR_Sintetico;
GO

-- Simula un día completo de actividad
EXEC hr.usp_SimularDiaTransaccional;

-- O por tipo de evento
EXEC hr.usp_GenerarContrataciones @Cantidad = 5;
EXEC hr.usp_GenerarSalidas @Cantidad = 2;
EXEC hr.usp_GenerarAusencias @Cantidad = 15;
EXEC hr.usp_GenerarAjustesSalariales @Cantidad = 8;
EXEC hr.usp_GenerarActualizacionHabilidades @Cantidad = 10;
EXEC hr.usp_GenerarTransferencias @Cantidad = 3;
EXEC hr.usp_GenerarCapacitaciones @Cantidad = 6;

-- Extraer cambios desde un watermark (patrón SSIS)
EXEC hr.usp_ObtenerCambiosDesde
    @TablaFuente = N'hr.Ausencia',
    @DesdeModifiedAt = '2026-01-01';
```

Todas las tablas transaccionales tienen `CreatedAt` / `ModifiedAt` (UTC) e índices por `ModifiedAt` para cargas incrementales por watermark.

---

## Preguntas de negocio que esta fuente permite responder

### 1. Gestión de Talento — ¿Tenemos las habilidades correctas?

- Requisitos por puesto (`hr.PuestoHabilidadRequerida`)
- Competencias actuales (`hr.EmpleadoHabilidad`)
- Capacitaciones (`hr.EmpleadoCapacitacion`)
- Vista: `hr.vw_GapHabilidades` / `hr.vw_ResumenGapPorDepartamento`
- **Sesgo sintético:** ~1/3 de TI queda bajo el nivel requerido en habilidades críticas (SQL, ETL, Cloud, etc.)

### 2. Rotación y Retención — ¿Por qué se van y cuándo?

- `hr.SalidaEmpleado` + `hr.MotivoSalida`
- Historial de antigüedad vía `FechaContratacion` / `FechaTerminacion`
- Vistas: `hr.vw_RotacionDetalle`, `hr.vw_TasaRotacionMensual`
- **Sesgo sintético:** TI sale más por oferta/carrera; Operaciones por clima/desempeño

### 3. Ausentismo — ¿Hay patrones que afecten productividad?

- `hr.Ausencia` + `hr.TipoAusencia` (flag `AfectaProductividad`)
- Estacionalidad Dic/Ene (enfermedad) y Jul/Dic (vacaciones)
- Vista: `hr.vw_AusentismoDetalle` / `hr.vw_AusentismoPorDeptoMes`
- **Sesgo sintético:** Operaciones con pico adicional de enfermedad

### 4. Compensación — ¿Es justa la estructura salarial por departamento?

- `hr.EscalaSalarial` + `hr.HistorialSalarial` + `SalarioActual`
- Posición en banda salarial y gap por género/depto
- Vista: `hr.vw_CompensacionActual` / `hr.vw_EquidadSalarialPorDepto`
- **Sesgo sintético:** Comercial ~+8%, Operaciones ~-8%, gap leve de género en TI

---

## Flujo Kimball propuesto

```text
HR_Sintetico (OLTP)
        │  SSIS Full / Incremental (ModifiedAt)
        ▼
   HR_Staging (stg.*)
        │  Transformaciones / keys / SCD2
        ▼
   HR_DataMart (dm.*)
        │  Modelo estrella
        ▼
     Power BI
```

Hechos sugeridos:

| Hecho | Pregunta que atiende |
|-------|----------------------|
| `FactHabilidadEmpleado` | Talento / skills gap |
| `FactRotacion` | Rotación y retención |
| `FactAusentismo` | Ausentismo y productividad |
| `FactHeadcountMensual` | Compensación + denominadores de tasas |

Detalle en `docs/Arquitectura_Kimball.md` y `docs/Guia_SSIS_PowerBI.md`.

---

## Reiniciar datos demo

```sql
EXEC hr.usp_ResetDemoData @Confirmar = 1;
EXEC hr.usp_SeedEmpleadosInicial;  -- regenera ~180 empleados y transacciones
```

---

## Contexto académico sugerido (resumen)

Empresa ficticia costarricense con ~180 colaboradores en 8 departamentos. El departamento de RH necesita un data mart analítico para decidir sobre talento, retención, ausentismo y equidad salarial. La PoC demuestra:

1. Modelado de fuente transaccional
2. ETL inicial e incremental con SSIS
3. Staging Area
4. Data Mart dimensional (Kimball)
5. Visualización en Power BI respondiendo las 4 preguntas
