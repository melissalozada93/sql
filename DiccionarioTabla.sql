-- Cambiar a la base de datos TemporalesDW
USE [TemporalesDW]

/****** Object:  StoredProcedure [dbo].[usp_exec_graba_log_extract]    Script Date: 30/10/2023 10:12:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter  procedure [dbo].[usp_auditoria_tablas]

AS

-- Crear tabla temporal #TempDW para datos DW
DROP TABLE IF EXISTS #TempDW
CREATE TABLE #TempDW (
    [DESCRIPCION] [varchar](MAX) NULL,
    [CAMPO] [varchar](255) NULL,
    [FILE] [varchar](255) NULL,
    [ARCHIVO] [varchar](255) NULL
) ON [PRIMARY]


-- Importar datos de archivo CSV a #TempDW
BULK INSERT #TempDW
FROM 'D:\FilesSharePoint\Reportería\DiccionarioTablas\Diccionario_tablas_DW.csv'
WITH (
    FIRSTROW = 2,  -- Omitir encabezado si es necesario
    FIELDTERMINATOR = '|',  -- Delimitador de campo (palote)
    ROWTERMINATOR = '\n'   -- Delimitador de fila (salto de línea)
);

-- Eliminar filas nulas o con FILE que no comienza con 'DW'
DELETE FROM #TempDW WHERE campo IS NULL
DELETE FROM #TempDW WHERE LEFT([FILE], 2) <> 'DW'

-- Crear tabla temporal #TempI para datos Intermedias
DROP TABLE IF EXISTS #TempI
CREATE TABLE #TempI (
    [DESCRIPCION] [varchar](MAX) NULL,
    [CAMPO] [varchar](255) NULL,
    [FILE] [varchar](255) NULL,
    [ARCHIVO] [varchar](255) NULL
) ON [PRIMARY]


-- Importar datos de archivo CSV a #TempI
BULK INSERT #TempI
FROM 'D:\FilesSharePoint\Reportería\DiccionarioTablas\Diccionario_tablas_I.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '|',
    ROWTERMINATOR = '\n'
);

-- Eliminar filas nulas o con FILE que no comienza con 'I'
DELETE FROM #TempI WHERE campo IS NULL
DELETE FROM #TempI WHERE LEFT([FILE], 1) <> 'I'

-- Consolidar información en [temp].[OrigenDiccionarioTablas]
DROP TABLE IF EXISTS [temp].[OrigenDiccionarioTablas]
SELECT *, 'DW' [TIPO]
INTO [temp].[OrigenDiccionarioTablas]
FROM #TempDW
UNION
SELECT *, 'I' [TIPO] 
FROM #TempI

-- Crear tabla R_DETALLE_TABLAS
DROP TABLE IF EXISTS R_DETALLE_TABLAS
SELECT A.tableName, A.columnName, B.DESCRIPCION,
    CUMPLE = IIF(CONCAT(A.tableName, A.columnName) = CONCAT(B.[FILE], B.CAMPO), 'SI', 'NO'),
	ACTUALIZADO= GETDATE()
INTO R_DETALLE_TABLAS
FROM DWCOOPAC.DBO.WT_REPORTETABLAS A
LEFT JOIN [temp].[OrigenDiccionarioTablas] B
ON CONCAT(A.tableName, A.columnName) = CONCAT(B.[FILE], B.CAMPO)
WHERE LEFT(tableName, 1) IN ('I', 'D')

-- Crear tabla #DiccionarioTablasArchivo para agrupación
DROP TABLE IF EXISTS #DiccionarioTablasArchivo
SELECT TIPO, [FILE] [tabla], COUNT(*) [QColumnasArchivo] 
INTO #DiccionarioTablasArchivo
FROM [temp].[OrigenDiccionarioTablas]
GROUP BY TIPO, [FILE]

-- Crear tabla #ReporteTablasResumen para agrupación
DROP TABLE IF EXISTS #ReporteTablasResumen
SELECT tipo = IIF(LEFT(tableName, 1) = 'I', 'I', 'DW'), tableName, COUNT(*) [QColumnas]
INTO #ReporteTablasResumen
FROM DWCOOPAC.DBO.WT_REPORTETABLAS
WHERE LEFT(tableName, 1) IN ('I', 'D')
GROUP BY tableName

-- Crear tabla R_RESUMEN_TABLAS para resumen
DROP TABLE IF EXISTS R_RESUMEN_TABLAS
SELECT a.*, isnull(b.QColumnasArchivo,0)QColumnasArchivo,
    Completo = IIF(A.QColumnas = B.QColumnasArchivo, 'SI', 'NO'),
	Actualizado= GETDATE()
INTO R_RESUMEN_TABLAS
FROM #ReporteTablasResumen A
LEFT JOIN #DiccionarioTablasArchivo B
ON A.tableName = B.[tabla]


DROP TABLE IF EXISTS #DiccionarioTablasArchivo
DROP TABLE IF EXISTS #ReporteTablasResumen
DROP TABLE IF EXISTS #TempDW
DROP TABLE IF EXISTS #TempI

