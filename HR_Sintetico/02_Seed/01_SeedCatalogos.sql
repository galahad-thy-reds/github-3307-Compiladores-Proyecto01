/*
================================================================================
  HR_Sintetico - Catálogos semilla
================================================================================
*/
USE HR_Sintetico;
GO

SET NOCOUNT ON;

/* Limpieza segura de catálogos (solo si no hay empleados) */
IF NOT EXISTS (SELECT 1 FROM hr.Empleado)
BEGIN
    DELETE FROM hr.PuestoHabilidadRequerida;
    DELETE FROM hr.Capacitacion;
    DELETE FROM hr.Habilidad;
    DELETE FROM hr.NivelHabilidad;
    DELETE FROM hr.TipoAusencia;
    DELETE FROM hr.MotivoSalida;
    DELETE FROM hr.EstadoEmpleado;
    DELETE FROM hr.EscalaSalarial;
    DELETE FROM hr.Puesto;
    DELETE FROM hr.Departamento;
    DELETE FROM hr.Ubicacion;
END
GO

/* ---------- Ubicaciones ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.Ubicacion)
BEGIN
    INSERT INTO hr.Ubicacion (Codigo, Nombre, Provincia, Canton) VALUES
    ('U-SJO', N'Oficina Central San José', N'San José', N'San José'),
    ('U-ALA', N'Centro Operativo Alajuela', N'Alajuela', N'Alajuela'),
    ('U-HER', N'Centro Heredia', N'Heredia', N'Heredia'),
    ('U-CAR', N'Sucursal Cartago', N'Cartago', N'Cartago'),
    ('U-REM', N'Trabajo Remoto', N'San José', N'Escazú');
END
GO

/* ---------- Departamentos ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.Departamento)
BEGIN
    INSERT INTO hr.Departamento (Codigo, Nombre, Descripcion, CostoCentro) VALUES
    ('D-TI',   N'Tecnología',           N'Desarrollo, infraestructura y soporte', 'CC-100'),
    ('D-RH',   N'Recursos Humanos',     N'Gestión de talento y nómina',           'CC-200'),
    ('D-FIN',  N'Finanzas',             N'Contabilidad, tesorería y control',     'CC-300'),
    ('D-COM',  N'Comercial',            N'Ventas y atención a clientes',          'CC-400'),
    ('D-OPE',  N'Operaciones',          N'Producción y logística',                'CC-500'),
    ('D-MKT',  N'Marketing',            N'Comunicación y marca',                  'CC-600'),
    ('D-LEG',  N'Legal y Cumplimiento', N'Asesoría jurídica y compliance',        'CC-700'),
    ('D-INN',  N'Innovación',           N'I+D y mejora continua',                 'CC-800');
END
GO

/* ---------- Puestos ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.Puesto)
BEGIN
    INSERT INTO hr.Puesto (Codigo, Nombre, NivelJerarquico, FamiliaPuesto, RequiereSupervisa) VALUES
    ('P-ANA-JR',  N'Analista Junior',              1, N'Analítico',      0),
    ('P-ANA-SR',  N'Analista Senior',              2, N'Analítico',      0),
    ('P-DEV',     N'Desarrollador de Software',    2, N'Técnico',        0),
    ('P-DEV-SR',  N'Desarrollador Senior',         3, N'Técnico',        0),
    ('P-ARQ',     N'Arquitecto de Soluciones',     4, N'Técnico',        0),
    ('P-SOP',     N'Especialista de Soporte',      1, N'Técnico',        0),
    ('P-DBA',     N'Administrador de Base Datos',  3, N'Técnico',        0),
    ('P-AN-RH',   N'Analista de Recursos Humanos', 2, N'Administrativo', 0),
    ('P-BP-RH',   N'Business Partner RH',          3, N'Administrativo', 0),
    ('P-CONT',    N'Contador',                     2, N'Administrativo', 0),
    ('P-FIN-AN',  N'Analista Financiero',          2, N'Analítico',      0),
    ('P-EJE-COM', N'Ejecutivo Comercial',          2, N'Comercial',      0),
    ('P-SUP-COM', N'Supervisor Comercial',         3, N'Comercial',      1),
    ('P-OPR',     N'Operario',                     1, N'Operativo',      0),
    ('P-SUP-OP',  N'Supervisor de Operaciones',    3, N'Operativo',      1),
    ('P-MKT',     N'Especialista Marketing',       2, N'Creativo',       0),
    ('P-LEG',     N'Asesor Legal',                 3, N'Profesional',    0),
    ('P-INN',     N'Especialista Innovación',      2, N'Técnico',        0),
    ('P-JEF',     N'Jefe de Área',                 4, N'Gerencial',      1),
    ('P-GER',     N'Gerente de Departamento',      5, N'Gerencial',      1);
END
GO

/* ---------- Escalas salariales (CRC mensuales aproximados) ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.EscalaSalarial)
BEGIN
    INSERT INTO hr.EscalaSalarial (Codigo, Grado, Descripcion, SalarioMinimo, SalarioMedio, SalarioMaximo, VigenteDesde) VALUES
    ('G1', 1, N'Grado 1 - Operativo / Entry',     450000,  550000,  650000,  '2023-01-01'),
    ('G2', 2, N'Grado 2 - Analista / Especialista',650000,  800000,  950000,  '2023-01-01'),
    ('G3', 3, N'Grado 3 - Senior / Supervisor',    950000, 1200000, 1450000,  '2023-01-01'),
    ('G4', 4, N'Grado 4 - Jefatura / Arquitecto', 1450000, 1800000, 2200000,  '2023-01-01'),
    ('G5', 5, N'Grado 5 - Gerencia',              2200000, 2800000, 3500000,  '2023-01-01');
END
GO

/* ---------- Niveles de habilidad ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.NivelHabilidad)
BEGIN
    INSERT INTO hr.NivelHabilidad (Codigo, Nombre, ValorNumerico) VALUES
    ('N1', N'Básico',       1),
    ('N2', N'Intermedio',   2),
    ('N3', N'Avanzado',     3),
    ('N4', N'Experto',      4),
    ('N5', N'Maestro',      5);
END
GO

/* ---------- Habilidades (incluye críticas para gap analysis) ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.Habilidad)
BEGIN
    INSERT INTO hr.Habilidad (Codigo, Nombre, Categoria, IsCritical, Descripcion) VALUES
    ('H-SQL',   N'SQL / Bases de datos',     N'Técnica',     1, N'Modelado y consultas SQL'),
    ('H-ETL',   N'Integración de datos/ETL', N'Técnica',     1, N'SSIS, pipelines, calidad de datos'),
    ('H-PBI',   N'Power BI',                 N'Herramienta', 1, N'Visualización y modelos semánticos'),
    ('H-PY',    N'Python',                   N'Técnica',     1, N'Automatización y análisis'),
    ('H-CSH',   N'C# / .NET',                N'Técnica',     0, N'Desarrollo de aplicaciones'),
    ('H-CLD',   N'Cloud (Azure/AWS)',        N'Técnica',     1, N'Infraestructura y servicios cloud'),
    ('H-SCR',   N'Scrum / Ágil',             N'Blandas',     0, N'Metodologías ágiles'),
    ('H-LID',   N'Liderazgo',                N'Blandas',     1, N'Gestión de equipos'),
    ('H-COM',   N'Comunicación',             N'Blandas',     0, N'Comunicación efectiva'),
    ('H-ING',   N'Inglés',                   N'Idioma',      1, N'Inglés profesional'),
    ('H-EXC',   N'Excel Avanzado',           N'Herramienta', 0, N'Análisis tabular y macros'),
    ('H-FIN',   N'Análisis financiero',      N'Técnica',     0, N'Estados financieros y KPIs'),
    ('H-VEN',   N'Técnicas de venta',        N'Comercial',   0, N'Ciclo comercial y cierre'),
    ('H-LEG',   N'Normativa laboral',        N'Profesional', 0, N'Legislación laboral CR'),
    ('H-CYB',   N'Ciberseguridad',           N'Técnica',     1, N'Seguridad de la información');
END
GO

/* ---------- Tipos de ausencia ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.TipoAusencia)
BEGIN
    INSERT INTO hr.TipoAusencia (Codigo, Nombre, EsRemunerada, AfectaProductividad, RequiereAprobacion) VALUES
    ('A-VAC',  N'Vacaciones',              1, 1, 1),
    ('A-ENF',  N'Incapacidad por enfermedad', 1, 1, 0),
    ('A-PER',  N'Permiso personal',        0, 1, 1),
    ('A-MAT',  N'Licencia maternidad/paternidad', 1, 1, 0),
    ('A-LUT',  N'Licencia por duelo',      1, 1, 0),
    ('A-CAP',  N'Capacitación externa',    1, 0, 1),
    ('A-INA',  N'Inasistencia injustificada', 0, 1, 0),
    ('A-REM',  N'Teletrabajo excepcional', 1, 0, 1);
END
GO

/* ---------- Motivos de salida ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.MotivoSalida)
BEGIN
    INSERT INTO hr.MotivoSalida (Codigo, Nombre, Categoria, EsEvitable) VALUES
    ('S-MEJOR', N'Mejor oferta salarial',           N'Voluntaria',   1),
    ('S-CARR',  N'Falta de crecimiento profesional', N'Voluntaria',   1),
    ('S-CLIMA', N'Clima laboral / liderazgo',        N'Voluntaria',   1),
    ('S-RELOC', N'Reubicación geográfica',           N'Voluntaria',   0),
    ('S-PERS',  N'Motivos personales / familia',     N'Voluntaria',   0),
    ('S-PERF',  N'Bajo desempeño',                   N'Involuntaria', 1),
    ('S-REST',  N'Reestructuración',                 N'Involuntaria', 0),
    ('S-FINC',  N'Fin de contrato temporal',         N'Involuntaria', 0),
    ('S-JUB',   N'Jubilación',                       N'Voluntaria',   0),
    ('S-ABAN',  N'Abandono de puesto',               N'Voluntaria',   1);
END
GO

/* ---------- Estados empleado ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.EstadoEmpleado)
BEGIN
    INSERT INTO hr.EstadoEmpleado (Codigo, Nombre, EsActivoLaboral) VALUES
    ('ACT', N'Activo',              1),
    ('LIC', N'Licencia',            1),
    ('SUS', N'Suspendido',          0),
    ('TER', N'Terminado',           0),
    ('PRE', N'Pre-ingreso',         0);
END
GO

/* ---------- Capacitaciones ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.Capacitacion)
BEGIN
    INSERT INTO hr.Capacitacion (Codigo, Nombre, Proveedor, Modalidad, HorasDuracion, HabilidadID, CostoEstimado)
    SELECT v.Codigo, v.Nombre, v.Proveedor, v.Modalidad, v.Horas, h.HabilidadID, v.Costo
    FROM (VALUES
        ('C-SQL01', N'SQL Server Avanzado',        N'Microsoft Learn', 'Virtual',   24.0, 'H-SQL', 150000.00),
        ('C-SSIS1', N'SSIS para Integración',      N'Microsoft Learn', 'Virtual',   16.0, 'H-ETL', 120000.00),
        ('C-PBI01', N'Power BI Data Analyst',      N'Microsoft Learn', 'Virtual',   20.0, 'H-PBI', 140000.00),
        ('C-PY01',  N'Python para Datos',          N'DataCamp',        'Virtual',   30.0, 'H-PY',  180000.00),
        ('C-LID01', N'Liderazgo Situacional',      N'INCAE',           'Presencial',12.0, 'H-LID', 250000.00),
        ('C-ING01', N'Inglés de Negocios B2',      N'Centro Cultural', 'Híbrida',   40.0, 'H-ING', 200000.00),
        ('C-SCR01', N'Scrum Master Foundations',   N'Scrum.org',       'Virtual',   16.0, 'H-SCR', 160000.00),
        ('C-CYB01', N'Seguridad de la Información',N'CISCO',           'Virtual',   18.0, 'H-CYB', 170000.00)
    ) v(Codigo, Nombre, Proveedor, Modalidad, Horas, HabCodigo, Costo)
    INNER JOIN hr.Habilidad h ON h.Codigo = v.HabCodigo;
END
GO

/* ---------- Requisitos de habilidad por puesto (muestra representativa) ---------- */
IF NOT EXISTS (SELECT 1 FROM hr.PuestoHabilidadRequerida)
BEGIN
    ;WITH Req AS (
        SELECT p.PuestoID, h.HabilidadID, n.NivelHabilidadID, r.EsObligatoria
        FROM (VALUES
            ('P-DEV',    'H-SQL', 3, 1),
            ('P-DEV',    'H-CSH', 3, 1),
            ('P-DEV',    'H-ING', 2, 1),
            ('P-DEV-SR', 'H-SQL', 4, 1),
            ('P-DEV-SR', 'H-CSH', 4, 1),
            ('P-DEV-SR', 'H-CLD', 3, 1),
            ('P-DEV-SR', 'H-ING', 3, 1),
            ('P-ARQ',    'H-CLD', 4, 1),
            ('P-ARQ',    'H-SQL', 4, 1),
            ('P-ARQ',    'H-LID', 3, 1),
            ('P-DBA',    'H-SQL', 5, 1),
            ('P-DBA',    'H-CYB', 3, 1),
            ('P-DBA',    'H-ETL', 3, 1),
            ('P-ANA-SR', 'H-SQL', 3, 1),
            ('P-ANA-SR', 'H-PBI', 3, 1),
            ('P-ANA-SR', 'H-EXC', 3, 1),
            ('P-ANA-JR', 'H-EXC', 2, 1),
            ('P-ANA-JR', 'H-SQL', 2, 0),
            ('P-JEF',    'H-LID', 4, 1),
            ('P-JEF',    'H-COM', 3, 1),
            ('P-GER',    'H-LID', 5, 1),
            ('P-GER',    'H-ING', 4, 1),
            ('P-EJE-COM','H-VEN', 3, 1),
            ('P-EJE-COM','H-COM', 3, 1),
            ('P-FIN-AN', 'H-FIN', 3, 1),
            ('P-FIN-AN', 'H-EXC', 4, 1),
            ('P-BP-RH',  'H-LEG', 3, 1),
            ('P-BP-RH',  'H-COM', 3, 1),
            ('P-INN',    'H-PY',  3, 1),
            ('P-INN',    'H-CLD', 2, 0)
        ) r(PuestoCodigo, HabCodigo, NivelValor, EsObligatoria)
        INNER JOIN hr.Puesto p ON p.Codigo = r.PuestoCodigo
        INNER JOIN hr.Habilidad h ON h.Codigo = r.HabCodigo
        INNER JOIN hr.NivelHabilidad n ON n.ValorNumerico = r.NivelValor
    )
    INSERT INTO hr.PuestoHabilidadRequerida (PuestoID, HabilidadID, NivelMinimoRequeridoID, EsObligatoria)
    SELECT PuestoID, HabilidadID, NivelHabilidadID, EsObligatoria FROM Req;
END
GO

/* Watermarks iniciales */
MERGE hr.EtlWatermark AS t
USING (VALUES
    (N'hr.Empleado',                '1900-01-01'),
    (N'hr.EmpleadoAsignacionHistorial', '1900-01-01'),
    (N'hr.HistorialSalarial',       '1900-01-01'),
    (N'hr.EmpleadoHabilidad',       '1900-01-01'),
    (N'hr.EmpleadoCapacitacion',    '1900-01-01'),
    (N'hr.Ausencia',                '1900-01-01'),
    (N'hr.SalidaEmpleado',          '1900-01-01'),
    (N'hr.EvaluacionDesempeno',     '1900-01-01')
) AS s(TablaFuente, UltimoModifiedAt)
ON t.TablaFuente = s.TablaFuente
WHEN NOT MATCHED THEN
    INSERT (TablaFuente, UltimoModifiedAt, FilasProcesadas, Notas)
    VALUES (s.TablaFuente, s.UltimoModifiedAt, 0, N'Inicial');
GO

PRINT N'Catálogos semilla cargados.';
GO
