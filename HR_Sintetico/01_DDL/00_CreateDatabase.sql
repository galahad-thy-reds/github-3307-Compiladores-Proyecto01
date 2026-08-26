/*
================================================================================
  HR_Sintetico - Creación de base de datos OLTP (fuente transaccional)
  Motor: Microsoft SQL Server 2019+ / 2022 / 2025
  Propósito: Prueba de concepto RH → Staging → Data Mart (Kimball)
================================================================================
*/
USE master;
GO

IF DB_ID(N'HR_Sintetico') IS NULL
BEGIN
    CREATE DATABASE HR_Sintetico;
END
GO

ALTER DATABASE HR_Sintetico SET RECOVERY SIMPLE;
GO

USE HR_Sintetico;
GO

/* Esquema de aplicación (separado de dbo para claridad) */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'hr')
    EXEC(N'CREATE SCHEMA hr AUTHORIZATION dbo;');
GO

PRINT N'Base de datos HR_Sintetico lista.';
GO
