# Diccionario de datos — HR_Sintetico y HR_DataMart

Documento de referencia para entender el contenido, propósito y relaciones de las bases del PoC de RH.

| Base | Esquema | Rol |
|------|---------|-----|
| `HR_Sintetico` | `hr` | Origen OLTP transaccional (fuente de los ETL) |
| `HR_DataMart` | `dm` | Destino dimensional Kimball (consumo Power BI) |

Convenciones comunes:

- Sufijo `ID` = clave de negocio / surrogada en OLTP  
- Sufijo `Key` = clave subrogada del Data Mart  
- Sufijo `BK` = business key (ID del origen OLTP)  
- `CreatedAt` / `ModifiedAt` = auditoría UTC para carga incremental  
- `IsActive` = soft-delete / vigencia lógica  

---

# 1. HR_Sintetico (OLTP)

## 1.1 Inventario de tablas

| Grupo | Tabla | Propósito |
|-------|-------|-----------|
| Catálogo | `Ubicacion` | Sedes / ubicaciones laborales |
| Catálogo | `Departamento` | Áreas organizacionales |
| Catálogo | `Puesto` | Roles y nivel jerárquico |
| Catálogo | `EscalaSalarial` | Bandas salariales (grados) |
| Catálogo | `Habilidad` | Taxonomía de competencias |
| Catálogo | `NivelHabilidad` | Escala 1–5 de dominio |
| Catálogo | `TipoAusencia` | Clasificación de ausencias |
| Catálogo | `MotivoSalida` | Motivos de rotación |
| Catálogo | `EstadoEmpleado` | Activo, terminado, etc. |
| Catálogo | `Capacitacion` | Cursos / programas de formación |
| Relación | `PuestoHabilidadRequerida` | Perfil ideal del puesto (gap analysis) |
| Maestro | `Empleado` | Colaborador y estado actual |
| Histórico | `EmpleadoAsignacionHistorial` | Cambios de depto/puesto/ubicación |
| Histórico | `HistorialSalarial` | Evolución del salario |
| Transacción | `EmpleadoHabilidad` | Competencias evaluadas del empleado |
| Transacción | `EmpleadoCapacitacion` | Participación en cursos |
| Transacción | `Ausencia` | Eventos de ausencia |
| Transacción | `SalidaEmpleado` | Terminaciones / renuncias |
| Transacción | `EvaluacionDesempeno` | Evaluaciones de performance |
| Control ETL | `EtlWatermark` | Último `ModifiedAt` procesado por tabla |

### Relación con preguntas de negocio

| Pregunta | Tablas clave |
|----------|--------------|
| ¿Tenemos las habilidades correctas? | `PuestoHabilidadRequerida`, `EmpleadoHabilidad`, `Habilidad`, `Capacitacion` |
| ¿Por qué se van y cuándo? | `SalidaEmpleado`, `MotivoSalida`, `Empleado` |
| ¿Hay patrones de ausencia? | `Ausencia`, `TipoAusencia` |
| ¿Es justa la estructura salarial? | `EscalaSalarial`, `HistorialSalarial`, `Empleado.SalarioActual` |

---

## 1.2 Catálogos

### `hr.Ubicacion`

Sede o modalidad de trabajo del colaborador.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `UbicacionID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Código único (ej. `U-SJO`) |
| `Nombre` | NVARCHAR(100) | No | Nombre de la sede |
| `Provincia` | NVARCHAR(50) | No | Provincia |
| `Canton` | NVARCHAR(50) | Sí | Cantón |
| `Pais` | NVARCHAR(50) | No | Default `Costa Rica` |
| `IsActive` | BIT | No | 1 = vigente |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.Departamento`

Área organizacional (TI, Comercial, Operaciones, etc.).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `DepartamentoID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Código único (ej. `D-TI`) |
| `Nombre` | NVARCHAR(100) | No | Nombre del departamento |
| `Descripcion` | NVARCHAR(300) | Sí | Descripción |
| `CostoCentro` | VARCHAR(30) | Sí | Centro de costo contable |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.Puesto`

Rol laboral y jerarquía.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `PuestoID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Código único |
| `Nombre` | NVARCHAR(120) | No | Nombre del puesto |
| `NivelJerarquico` | TINYINT | No | 1=Operativo … 5=Dirección |
| `FamiliaPuesto` | NVARCHAR(60) | No | Técnico, Comercial, Gerencial, etc. |
| `RequiereSupervisa` | BIT | No | Si el puesto supervisa personal |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.EscalaSalarial`

Bandas salariales para análisis de equidad.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EscalaSalarialID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Ej. `G1`…`G5` |
| `Grado` | TINYINT | No | Número de grado |
| `Descripcion` | NVARCHAR(100) | No | Descripción del grado |
| `SalarioMinimo` | DECIMAL(12,2) | No | Límite inferior de banda |
| `SalarioMedio` | DECIMAL(12,2) | No | Punto medio |
| `SalarioMaximo` | DECIMAL(12,2) | No | Límite superior |
| `Moneda` | CHAR(3) | No | Default `CRC` |
| `VigenteDesde` / `VigenteHasta` | DATE | Sí/No | Vigencia de la escala |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.Habilidad`

Competencia o skill del catálogo de talento.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `HabilidadID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Ej. `H-SQL` |
| `Nombre` | NVARCHAR(100) | No | Nombre de la habilidad |
| `Categoria` | NVARCHAR(50) | No | Técnica, Blandas, Idioma, Herramienta… |
| `Descripcion` | NVARCHAR(300) | Sí | Detalle |
| `IsCritical` | BIT | No | 1 = crítica para el negocio |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.NivelHabilidad`

Escala de dominio (1–5).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `NivelHabilidadID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(10) | No | `N1`…`N5` |
| `Nombre` | NVARCHAR(40) | No | Básico … Maestro |
| `ValorNumerico` | TINYINT | No | 1 a 5 |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.TipoAusencia`

Clasificación de faltas / permisos.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `TipoAusenciaID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Ej. `A-VAC`, `A-ENF` |
| `Nombre` | NVARCHAR(80) | No | Nombre del tipo |
| `EsRemunerada` | BIT | No | Si se paga |
| `AfectaProductividad` | BIT | No | Si impacta operación |
| `RequiereAprobacion` | BIT | No | Flujo de aprobación |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.MotivoSalida`

Taxonomía de rotación.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `MotivoSalidaID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Ej. `S-MEJOR` |
| `Nombre` | NVARCHAR(100) | No | Motivo legible |
| `Categoria` | NVARCHAR(40) | No | `Voluntaria` / `Involuntaria` |
| `EsEvitable` | BIT | No | Si RH podría intervenir |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.EstadoEmpleado`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EstadoEmpleadoID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | `ACT`, `TER`, `LIC`… |
| `Nombre` | NVARCHAR(50) | No | Nombre del estado |
| `EsActivoLaboral` | BIT | No | 1 = cuenta en headcount activo |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.Capacitacion`

Catálogo de cursos.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `CapacitacionID` | INT IDENTITY | No | PK |
| `Codigo` | VARCHAR(20) | No | Código del curso |
| `Nombre` | NVARCHAR(150) | No | Nombre |
| `Proveedor` | NVARCHAR(100) | Sí | Institución / vendor |
| `Modalidad` | VARCHAR(30) | No | Presencial, Virtual, Híbrida |
| `HorasDuracion` | DECIMAL(6,1) | No | Horas |
| `HabilidadID` | INT | Sí | FK → habilidad principal que desarrolla |
| `CostoEstimado` | DECIMAL(12,2) | Sí | Costo estimado |
| `IsActive` | BIT | No | Vigencia |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.PuestoHabilidadRequerida`

Perfil de competencias mínimas por puesto (base del gap analysis).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `PuestoHabilidadID` | INT IDENTITY | No | PK |
| `PuestoID` | INT | No | FK → `Puesto` |
| `HabilidadID` | INT | No | FK → `Habilidad` |
| `NivelMinimoRequeridoID` | INT | No | FK → `NivelHabilidad` |
| `EsObligatoria` | BIT | No | 1 = requisito obligatorio |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

UQ: (`PuestoID`, `HabilidadID`).

---

## 1.3 Maestro y transacciones

### `hr.Empleado`

Estado actual del colaborador (foto vigente).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EmpleadoID` | INT IDENTITY | No | PK |
| `NumeroEmpleado` | VARCHAR(20) | No | Código HR único (ej. `E00001`) |
| `Cedula` | VARCHAR(20) | No | Identificación (única) |
| `Nombre` / `Apellido1` / `Apellido2` | NVARCHAR | Sí/No | Nombre legal |
| `FechaNacimiento` | DATE | No | Nacimiento |
| `Genero` | CHAR(1) | No | `M` / `F` / `O` |
| `EmailCorporativo` | NVARCHAR(150) | No | Correo único |
| `Telefono` | VARCHAR(30) | Sí | Contacto |
| `FechaContratacion` | DATE | No | Ingreso |
| `FechaTerminacion` | DATE | Sí | Baja (NULL si activo) |
| `EstadoEmpleadoID` | INT | No | FK → estado |
| `DepartamentoID` | INT | No | FK → depto actual |
| `PuestoID` | INT | No | FK → puesto actual |
| `UbicacionID` | INT | No | FK → ubicación actual |
| `ManagerEmpleadoID` | INT | Sí | FK → jefe (autoreferencia) |
| `EscalaSalarialID` | INT | No | FK → banda salarial |
| `SalarioActual` | DECIMAL(12,2) | No | Salario vigente |
| `TipoContrato` | VARCHAR(20) | No | Indefinido / Temporal / Servicios |
| `Jornada` | VARCHAR(20) | No | Default `Completa` |
| `IsActive` | BIT | No | 1 = activo laboralmente |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría / watermark |

### `hr.EmpleadoAsignacionHistorial`

Historial de asignaciones (fuente natural SCD2).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `AsignacionHistorialID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `DepartamentoID` / `PuestoID` / `UbicacionID` | INT | No | Asignación del tramo |
| `ManagerEmpleadoID` | INT | Sí | Jefe en ese tramo |
| `EscalaSalarialID` | INT | No | Escala en ese tramo |
| `Salario` | DECIMAL(12,2) | No | Salario del tramo |
| `MotivoCambio` | NVARCHAR(100) | No | Contratación, Ascenso, Transferencia… |
| `FechaInicio` / `FechaFin` | DATE | Sí/No | Vigencia del tramo |
| `EsActual` | BIT | No | 1 = tramo vigente |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.HistorialSalarial`

Cada cambio de salario.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `HistorialSalarialID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `EscalaSalarialID` | INT | No | FK → escala |
| `SalarioAnterior` | DECIMAL(12,2) | Sí | NULL en ingreso |
| `SalarioNuevo` | DECIMAL(12,2) | No | Nuevo monto |
| `PorcentajeCambio` | computed | Sí | % calculado persistido |
| `Motivo` | NVARCHAR(100) | No | Ingreso, mérito, inflación… |
| `FechaEfectiva` | DATE | No | Fecha del cambio |
| `AprobadoPor` | INT | Sí | FK → empleado aprobador |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.EmpleadoHabilidad`

Competencia actual del empleado.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EmpleadoHabilidadID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `HabilidadID` | INT | No | FK → habilidad |
| `NivelHabilidadID` | INT | No | FK → nivel actual |
| `FechaEvaluacion` | DATE | No | Fecha de evaluación |
| `FuenteEvaluacion` | NVARCHAR(40) | No | Autoevaluación, Manager, Certificación… |
| `Certificado` | BIT | No | Si hay certificación |
| `IsActive` | BIT | No | Vigencia del registro |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

UQ: (`EmpleadoID`, `HabilidadID`).

### `hr.EmpleadoCapacitacion`

Inscripción / resultado de un curso.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EmpleadoCapacitacionID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `CapacitacionID` | INT | No | FK → curso |
| `FechaInicio` / `FechaFin` | DATE | Sí/No | Periodo |
| `Estado` | VARCHAR(20) | No | Inscrito, EnCurso, Completado, Abandonado |
| `Calificacion` | DECIMAL(5,2) | Sí | Nota |
| `CostoReal` | DECIMAL(12,2) | Sí | Costo ejecutado |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.Ausencia`

Evento de ausencia.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `AusenciaID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `TipoAusenciaID` | INT | No | FK → tipo |
| `FechaInicio` / `FechaFin` | DATE | No | Periodo |
| `DiasLaborales` | DECIMAL(5,1) | No | Días impactados |
| `Estado` | VARCHAR(20) | No | Solicitada, Aprobada, Rechazada, Cancelada |
| `MotivoDetalle` | NVARCHAR(300) | Sí | Comentario |
| `AprobadoPor` | INT | Sí | FK → aprobador |
| `FechaSolicitud` | DATE | No | Fecha de solicitud |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

### `hr.SalidaEmpleado`

Registro de terminación (1 por empleado).

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `SalidaEmpleadoID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado (UQ) |
| `MotivoSalidaID` | INT | No | FK → motivo |
| `FechaSalida` | DATE | No | Fecha de baja |
| `TipoSalida` | VARCHAR(20) | No | Renuncia, Despido, MutuoAcuerdo, Jubilacion, FinContrato |
| `EntrevistaSalida` | BIT | No | Si hubo exit interview |
| `ComentarioSalida` | NVARCHAR(500) | Sí | Comentario |
| `Recontratable` | BIT | No | Elegible a rehire |
| `DepartamentoID` / `PuestoID` / `UbicacionID` | INT | No | Snapshot al salir |
| `ManagerEmpleadoID` | INT | Sí | Jefe al salir |
| `SalarioAlSalir` | DECIMAL(12,2) | No | Salario en la salida |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

> La antigüedad **no** se guarda aquí; se calcula en vistas (`AntiguedadMeses`) y en `FactRotacion`.

### `hr.EvaluacionDesempeno`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `EvaluacionID` | INT IDENTITY | No | PK |
| `EmpleadoID` | INT | No | FK → empleado |
| `PeriodoAnio` | SMALLINT | No | Año del ciclo |
| `PeriodoCiclo` | VARCHAR(20) | No | Semestral1, Semestral2, Anual |
| `FechaEvaluacion` | DATE | No | Fecha |
| `PuntajeGlobal` | DECIMAL(4,2) | No | 1.00–5.00 |
| `CalificacionTexto` | VARCHAR(30) | No | Bajo, Esperado, Destacado, Excepcional |
| `EvaluadorEmpleadoID` | INT | Sí | FK → evaluador |
| `Comentarios` | NVARCHAR(400) | Sí | Notas |
| `CreatedAt` / `ModifiedAt` | DATETIME2(0) | No | Auditoría |

UQ: (`EmpleadoID`, `PeriodoAnio`, `PeriodoCiclo`).

### `hr.EtlWatermark`

Control de cargas incrementales.

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `TablaFuente` | SYSNAME | No | PK — nombre calificado (ej. `hr.Ausencia`) |
| `UltimoModifiedAt` | DATETIME2(0) | No | Watermark de última carga exitosa |
| `UltimaEjecucion` | DATETIME2(0) | No | Timestamp de corrida |
| `FilasProcesadas` | INT | No | Filas del último batch |
| `Notas` | NVARCHAR(200) | Sí | Comentario operativo |

---

## 1.4 Vistas de análisis (OLTP)

| Vista | Pregunta que apoya |
|-------|--------------------|
| `hr.vw_GapHabilidades` | Talento — detalle empleado × habilidad |
| `hr.vw_ResumenGapPorDepartamento` | Talento — % gap por depto |
| `hr.vw_RotacionDetalle` | Rotación — motivo, antigüedad, depto |
| `hr.vw_TasaRotacionMensual` | Rotación — tasa mensual |
| `hr.vw_AusentismoDetalle` | Ausentismo — eventos |
| `hr.vw_AusentismoPorDeptoMes` | Ausentismo — agregación |
| `hr.vw_CompensacionActual` | Compensación — posición en banda |
| `hr.vw_EquidadSalarialPorDepto` | Compensación — equidad / gap género |

---

# 2. HR_DataMart (dimensional)

Modelo en estrella (Kimball). Esquema `dm`.

## 2.1 Inventario

| Tipo | Tabla | Grano / uso |
|------|-------|-------------|
| Dim | `DimFecha` | Un día calendario |
| Dim | `DimEmpleado` | Empleado (SCD2) |
| Dim | `DimDepartamento` | Departamento (SCD1) |
| Dim | `DimPuesto` | Puesto (SCD1) |
| Dim | `DimUbicacion` | Ubicación (SCD1) |
| Dim | `DimHabilidad` | Habilidad (SCD1) |
| Dim | `DimMotivoSalida` | Motivo de salida (SCD1) |
| Dim | `DimTipoAusencia` | Tipo de ausencia (SCD1) |
| Dim | `DimEscalaSalarial` | Banda salarial (SCD1) |
| Fact | `FactRotacion` | 1 fila = 1 salida |
| Fact | `FactAusentismo` | 1 fila = 1 ausencia aprobada |
| Fact | `FactHabilidadEmpleado` | 1 fila = empleado × habilidad requerida |
| Fact | `FactHeadcountMensual` | 1 fila = empleado × mes |

```text
                    DimFecha
                       │
     ┌─────────────────┼─────────────────┐
     │                 │                 │
FactRotacion   FactAusentismo   FactHabilidadEmpleado
     │                 │                 │
     └────────── FactHeadcountMensual ───┘
                       │
        DimEmpleado / DimDepartamento / DimPuesto / DimUbicacion
        (+ DimMotivoSalida, DimTipoAusencia, DimHabilidad, DimEscalaSalarial)
```

---

## 2.2 Dimensiones

### `dm.DimFecha`

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `FechaKey` | INT (PK) | Formato `yyyymmdd` |
| `Fecha` | DATE | Fecha calendario |
| `Anio` / `Mes` / `NombreMes` | | Atributos de mes |
| `Trimestre` / `NombreTrimestre` | | Q1–Q4 |
| `SemanaAnio` | TINYINT | Semana ISO |
| `DiaSemana` / `NombreDiaSemana` | | Día de semana |
| `EsFinDeSemana` | BIT | 1 = sábado/domingo |
| `AnioMes` | CHAR(7) | `yyyy-MM` |

Población: `dm.usp_GenerarDimFecha`.

### `dm.DimEmpleado` (SCD Tipo 2)

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `EmpleadoKey` | INT IDENTITY | PK subrogada |
| `EmpleadoBK` | INT | `EmpleadoID` del OLTP |
| `NumeroEmpleado` | VARCHAR(20) | Código HR |
| `NombreCompleto` | NVARCHAR(200) | Nombre para reportes |
| `Genero` | CHAR(1) | M/F/O |
| `FechaNacimiento` | DATE | Nacimiento |
| `FechaContratacion` | DATE | Ingreso |
| `TipoContrato` | VARCHAR(20) | Tipo de contrato |
| `FechaInicioValidez` | DATETIME2(0) | Inicio versión SCD2 |
| `FechaFinValidez` | DATETIME2(0) | Fin versión (NULL si actual) |
| `EsActual` | BIT | 1 = versión vigente |
| `HashDiff` | BINARY(32) | Opcional para detectar cambios |

### Dimensiones de catálogo (SCD1)

Patrón común: `XxxKey` (PK) + `XxxBK` (ID origen) + atributos descriptivos.

| Tabla | BK | Atributos principales |
|-------|-----|------------------------|
| `DimDepartamento` | `DepartamentoBK` | Codigo, Nombre, CostoCentro |
| `DimPuesto` | `PuestoBK` | Codigo, Nombre, NivelJerarquico, FamiliaPuesto |
| `DimUbicacion` | `UbicacionBK` | Codigo, Nombre, Provincia, Pais |
| `DimHabilidad` | `HabilidadBK` | Codigo, Nombre, Categoria, IsCritical |
| `DimMotivoSalida` | `MotivoSalidaBK` | Codigo, Nombre, Categoria, EsEvitable |
| `DimTipoAusencia` | `TipoAusenciaBK` | Codigo, Nombre, EsRemunerada, AfectaProductividad |
| `DimEscalaSalarial` | `EscalaSalarialBK` | Codigo, Grado, Descripcion, SalarioMin/Med/Max, Moneda |

---

## 2.3 Hechos

### `dm.FactRotacion`

**Grano:** 1 salida de empleado.  
**Pregunta:** ¿Por qué se van y cuándo?

| Columna | Tipo | Rol | Descripción |
|---------|------|-----|-------------|
| `FactRotacionID` | BIGINT | PK | Surrogate del hecho |
| `FechaSalidaKey` | INT | FK → DimFecha | Fecha de salida |
| `EmpleadoKey` | INT | FK → DimEmpleado | Empleado |
| `DepartamentoKey` | INT | FK | Depto al salir |
| `PuestoKey` | INT | FK | Puesto al salir |
| `UbicacionKey` | INT | FK | Ubicación al salir |
| `MotivoSalidaKey` | INT | FK → DimMotivoSalida | Motivo |
| `AntiguedadMeses` | INT | Medida | Meses desde contratación |
| `SalarioAlSalir` | DECIMAL(12,2) | Medida | Salario en la salida |
| `ContadorSalida` | INT | Medida | Siempre 1 (conteo) |
| `EsEvitable` | BIT | Semiaditivo / flag | Si el motivo es evitable |

**Origen OLTP:** `hr.SalidaEmpleado` (+ snapshot organizacional).

### `dm.FactAusentismo`

**Grano:** 1 evento de ausencia aprobada.  
**Pregunta:** ¿Hay patrones de falta?

| Columna | Tipo | Rol | Descripción |
|---------|------|-----|-------------|
| `FactAusentismoID` | BIGINT | PK | Surrogate |
| `FechaInicioKey` | INT | FK DimFecha | Inicio |
| `FechaFinKey` | INT | FK DimFecha | Fin |
| `EmpleadoKey` | INT | FK | Empleado |
| `DepartamentoKey` / `PuestoKey` | INT | FK | Contexto org. |
| `TipoAusenciaKey` | INT | FK | Tipo |
| `DiasLaborales` | DECIMAL(5,1) | Medida | Días de ausencia |
| `ContadorEvento` | INT | Medida | Siempre 1 |
| `AfectaProductividad` | BIT | Flag | Copiado del tipo |

**Origen OLTP:** `hr.Ausencia` (filtrar `Estado='Aprobada'`).

### `dm.FactHabilidadEmpleado`

**Grano:** empleado × habilidad requerida por su puesto.  
**Pregunta:** ¿Tenemos las habilidades correctas?

| Columna | Tipo | Rol | Descripción |
|---------|------|-----|-------------|
| `FactHabilidadID` | BIGINT | PK | Surrogate |
| `FechaEvaluacionKey` | INT | FK DimFecha | Fecha de evaluación |
| `EmpleadoKey` | INT | FK | Empleado |
| `DepartamentoKey` / `PuestoKey` | INT | FK | Contexto |
| `HabilidadKey` | INT | FK | Habilidad |
| `NivelActual` | TINYINT | Medida | 1–5 (NULL si no evaluado) |
| `NivelRequerido` | TINYINT | Medida | Mínimo del puesto |
| `TieneGap` | BIT | Medida | 1 si actual < requerido |
| `DiferenciaNiveles` | INT | Medida | requerido − actual |
| `EsCritica` | BIT | Flag | Habilidad crítica |
| `EsObligatoria` | BIT | Flag | Requisito obligatorio |

**Origen OLTP:** `PuestoHabilidadRequerida` ⟕ `EmpleadoHabilidad`.

### `dm.FactHeadcountMensual`

**Grano:** empleado vigente en un mes.  
**Uso:** denominador de tasas + compensación.

| Columna | Tipo | Rol | Descripción |
|---------|------|-----|-------------|
| `FactHeadcountID` | BIGINT | PK | Surrogate |
| `FechaKey` | INT | FK DimFecha | Primer día del mes (`yyyymm01`) |
| `EmpleadoKey` | INT | FK | Empleado |
| `DepartamentoKey` / `PuestoKey` / `UbicacionKey` | INT | FK | Contexto del mes |
| `EscalaSalarialKey` | INT | FK | Banda |
| `Salario` | DECIMAL(12,2) | Medida | Salario en el snapshot |
| `EsActivo` | BIT | Flag/medida | 1 = activo en el mes |
| `AntiguedadMeses` | INT | Medida | Antigüedad al mes |

**Origen OLTP:** snapshot periódico de `hr.Empleado` (+ historial de asignación si se historía).

---

## 2.4 Mapeo OLTP → Data Mart

| Origen (`HR_Sintetico`) | Destino (`HR_DataMart`) |
|-------------------------|-------------------------|
| calendario generado | `DimFecha` |
| `Empleado` (+ historial asignación) | `DimEmpleado` |
| `Departamento` | `DimDepartamento` |
| `Puesto` | `DimPuesto` |
| `Ubicacion` | `DimUbicacion` |
| `Habilidad` | `DimHabilidad` |
| `MotivoSalida` | `DimMotivoSalida` |
| `TipoAusencia` | `DimTipoAusencia` |
| `EscalaSalarial` | `DimEscalaSalarial` |
| `SalidaEmpleado` | `FactRotacion` |
| `Ausencia` | `FactAusentismo` |
| `EmpleadoHabilidad` + `PuestoHabilidadRequerida` | `FactHabilidadEmpleado` |
| snapshot mensual `Empleado` | `FactHeadcountMensual` |

El paso intermedio es `HR_Staging` (`stg.*`): copia casi 1:1 + `LoadBatchID`, `LoadType`, `SrcModifiedAt`. Ver `docs/Guia_SSIS_PowerBI.md`.

---

## 2.5 Glosario rápido

| Término | Significado en este proyecto |
|---------|------------------------------|
| **BK (Business Key)** | Identificador del sistema origen (`EmpleadoID`, etc.) |
| **Key** | Surrogate key del Data Mart |
| **SCD1** | Sobrescribe el atributo (catálogos) |
| **SCD2** | Versiona el historial (`DimEmpleado`) |
| **Grano** | Qué representa exactamente una fila del hecho |
| **Watermark** | Último `ModifiedAt` cargado en ETL incremental |
| **Gap de habilidad** | Nivel actual < nivel requerido del puesto |
| **Headcount** | Conteo de personal en un periodo |
| **Banda salarial** | Rango min–max de `EscalaSalarial` |

---

## 3. Cómo usar este diccionario en el TFG

1. Cite `HR_Sintetico` como **sistema origen / OLTP sintético**.  
2. Cite `HR_DataMart` como **data mart dimensional** alineado a las 4 preguntas.  
3. Para el flujo ETL, complemente con `Guia_SSIS_PowerBI.md` y `Arquitectura_Kimball.md`.  
4. Para validar datos cargados, use `03_ConsultasValidacion.sql` y las vistas `hr.vw_*`.
