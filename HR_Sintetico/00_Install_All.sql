/*
================================================================================
  HR_Sintetico - Script maestro de instalación
  Ejecutar en SQL Server Management Studio (modo SQLCMD) o sección por sección.

  Orden:
    1) Fuente OLTP + seed + procedimientos + vistas
    2) Staging
    3) Data Mart dimensional
================================================================================
*/
:ON ERROR EXIT

PRINT N'==== 1/6 Base OLTP ====';
:r $(ProjectRoot)\01_DDL\00_CreateDatabase.sql
:r $(ProjectRoot)\01_DDL\01_CreateTables.sql

PRINT N'==== 2/6 Catálogos ====';
:r $(ProjectRoot)\02_Seed\01_SeedCatalogos.sql

PRINT N'==== 3/6 Empleados y transacciones ====';
:r $(ProjectRoot)\02_Seed\02_SeedEmpleadosYTransacciones.sql

PRINT N'==== 4/6 Procedimientos y vistas ====';
:r $(ProjectRoot)\03_Procedures\01_ProcedimientosSimulacion.sql
:r $(ProjectRoot)\03_Procedures\02_VistasAnalisisNegocio.sql

PRINT N'==== 5/6 Staging ====';
:r $(ProjectRoot)\04_DataMart\02_CreateStaging.sql

PRINT N'==== 6/6 Data Mart ====';
:r $(ProjectRoot)\04_DataMart\01_CreateDataMart.sql

PRINT N'==== Instalación completa ====';
GO

/*
  Si no usa SQLCMD, ejecute manualmente los scripts en el orden indicado.

  Ejemplo post-instalación (simular cambios incrementales):

    USE HR_Sintetico;
    EXEC hr.usp_SimularDiaTransaccional;
    EXEC hr.usp_ObtenerCambiosDesde @TablaFuente = N'hr.Empleado', @DesdeModifiedAt = '2020-01-01';

  Validar preguntas de negocio:

    SELECT * FROM hr.vw_ResumenGapPorDepartamento;
    SELECT * FROM hr.vw_RotacionDetalle;
    SELECT * FROM hr.vw_AusentismoPorDeptoMes;
    SELECT * FROM hr.vw_EquidadSalarialPorDepto;
*/
