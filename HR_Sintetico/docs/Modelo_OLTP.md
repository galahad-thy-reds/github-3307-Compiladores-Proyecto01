# Modelo de datos OLTP — HR_Sintetico

## Diagrama entidad-relación (lógico)

```text
Departamento ─┐
Puesto ───────┼── Empleado ──┬── EmpleadoAsignacionHistorial
Ubicacion ────┤              ├── HistorialSalarial
EscalaSalarial┤              ├── EmpleadoHabilidad ── Habilidad
EstadoEmpleado┘              ├── EmpleadoCapacitacion ── Capacitacion
                             ├── Ausencia ── TipoAusencia
                             ├── SalidaEmpleado ── MotivoSalida
                             └── EvaluacionDesempeno

Puesto ── PuestoHabilidadRequerida ── Habilidad
                              └── NivelHabilidad
```

## Tablas y propósito

### Catálogos
| Tabla | Propósito |
|-------|-----------|
| `Ubicacion` | Sedes / remoto |
| `Departamento` | Estructura organizacional |
| `Puesto` | Roles y nivel jerárquico |
| `EscalaSalarial` | Bandas salariales (equidad) |
| `Habilidad` / `NivelHabilidad` | Taxonomía de competencias |
| `PuestoHabilidadRequerida` | Perfil ideal del puesto (gap analysis) |
| `TipoAusencia` | Clasificación de faltas |
| `MotivoSalida` | Taxonomía de rotación |
| `EstadoEmpleado` | Activo, terminado, etc. |
| `Capacitacion` | Catálogo de cursos |

### Transaccionales / histórico
| Tabla | Propósito | Incremental |
|-------|-----------|-------------|
| `Empleado` | Maestro actual | `ModifiedAt` |
| `EmpleadoAsignacionHistorial` | Cambios de depto/puesto (SCD2 natural) | `ModifiedAt` |
| `HistorialSalarial` | Evolución salarial | `ModifiedAt` |
| `EmpleadoHabilidad` | Competencias evaluadas | `ModifiedAt` |
| `EmpleadoCapacitacion` | Participación en cursos | `ModifiedAt` |
| `Ausencia` | Eventos de ausencia | `ModifiedAt` |
| `SalidaEmpleado` | Terminaciones | `ModifiedAt` |
| `EvaluacionDesempeno` | Performance | `ModifiedAt` |
| `EtlWatermark` | Control de cargas | n/a |

## Procedimientos de simulación

| Procedimiento | Efecto |
|---------------|--------|
| `usp_GenerarContrataciones` | Altas + asignación + salario + skills |
| `usp_GenerarSalidas` | Baja + registro de salida + cierra historial |
| `usp_GenerarAusencias` | Nuevos eventos de ausencia |
| `usp_GenerarAjustesSalariales` | Aumentos + update maestro |
| `usp_GenerarActualizacionHabilidades` | Sube niveles de skill |
| `usp_GenerarTransferencias` | Cierra/abre historial de asignación |
| `usp_GenerarCapacitaciones` | Inscripciones/compleciones |
| `usp_SimularDiaTransaccional` | Orquesta todo lo anterior |
| `usp_ObtenerCambiosDesde` | Extracción incremental por tabla |
| `usp_ResetDemoData` | Limpia hechos/transacciones |

## Volumetría aproximada (seed)

| Entidad | Orden de magnitud |
|---------|-------------------|
| Empleados | ~180 (~80% activos) |
| Ausencias | cientos / 24 meses |
| Historial salarial | 1–3 filas por activo |
| Habilidades empleado | según requisitos de puesto |
| Salidas | ~20% de la población |
| Evaluaciones | ~2 ciclos × 2 años |

La volumetría es deliberadamente manejable para una PoC académica, pero suficiente para ETLs, SCD y tableros.
