-- Utilizar la base de datos DWCOOPAC
USE [DWCOOPAC];

-- Declarar la fecha fin de la tabla FECHAMAESTRA
DECLARE @FECHAFIN DATE;
SET @FECHAFIN = (SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA);


-- Declarar la fecha inicio 
DECLARE @FECHAINI DATE;
SET @FECHAINI = (SELECT DATEFROMPARTS(YEAR(DATEADD(YEAR, -1, @FECHAFIN)), MONTH(DATEADD(YEAR, -1,@FECHAFIN)), 1));


	SELECT A.TABLE_NAME ,@FECHAFIN
	FROM [ST_ValidacionTablas] A
	WHERE  A.FRECUENCIA='DIA ACTUAL'


 --SELECT @FECHAINI , @FECHAFIN

------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
-------Armando Calendarios ---------------------------------------------------------------------------------------------------------------------

    -- calendario de fechas 
    DROP TABLE IF EXISTS #calendario
    SELECT DISTINCT Fecha 
    INTO #calendario
    FROM dimtiempo 
    WHERE FECHA BETWEEN @FECHAINI AND @FECHAFIN 

	
    -- calendario de cierre 
    DROP TABLE IF EXISTS #calendariocierres
    SELECT DISTINCT Fecha 
    INTO #calendariocierres
    FROM dimtiempo 
    WHERE  DiaNegativo=-1 AND  FECHA BETWEEN @FECHAINI AND @FECHAFIN 


	-- calendario de periodos 
    DROP TABLE IF EXISTS #calendarioperiodo
    SELECT DISTINCT FORMAT(CONVERT(date, fecha), 'yyyyMM') Fecha
    INTO #calendarioperiodo
    FROM dimtiempo 
    WHERE FECHA BETWEEN @FECHAINI AND @FECHAFIN 


	--SELECT * FROM #calendario
	--ORDER BY Fecha
	--SELECT * FROM #calendariocierres
	--ORDER BY Fecha
	--SELECT * FROM #calendarioperiodo
	--ORDER BY Fecha

------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
-------Armando tabla para la comparación -------------------------------------------------------------------------------------------------------


	DROP TABLE IF EXISTS #TABLAFECHA

	SELECT A.TABLE_NAME ,@FECHAFIN FECHA
	INTO #TABLAFECHA
	FROM [ST_ValidacionTablas] A
	WHERE  A.FRECUENCIA='DIA ACTUAL'


	-----Diario-----------------
	SELECT A.TABLE_NAME ,CONVERT(VARCHAR(20), B.Fecha)FECHA
	FROM [ST_ValidacionTablas] A
	CROSS JOIN #calendario B
	WHERE  A.FRECUENCIA='DIARIO'

	UNION
	-------Diario Mes Actual-----------------
	SELECT A.TABLE_NAME ,CONVERT(VARCHAR(20), B.Fecha)FECHA
	FROM [ST_ValidacionTablas] A
	CROSS JOIN #calendario B
	WHERE  A.FRECUENCIA IN ('MES ACTUAL','CIERRE / DIARIO') AND FORMAT(CONVERT(date, B.fecha), 'yyyyMM')=FORMAT(CONVERT(date, @FECHAFIN), 'yyyyMM')

	
	UNION
    -------Mensual-----------------
	SELECT A.TABLE_NAME ,CONVERT(VARCHAR(20), B.Fecha)FECHA
	FROM [ST_ValidacionTablas] A
	CROSS JOIN #calendariocierres B
	WHERE  A.FRECUENCIA IN ('CIERRE','CIERRE / DIARIO')

	UNION
	-------Periodo-----------------
	SELECT A.TABLE_NAME , B.Fecha
	FROM [ST_ValidacionTablas] A
	CROSS JOIN #calendarioperiodo B
	WHERE  A.FRECUENCIA='MENSUAL'


	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='WT_TRANSFERENCIASPACINET' AND FECHA<'2024-02-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_CAJASOLICITUDTRANSFERENCIA' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_DATOSCUENTACORRIENTE' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_GARANTEBIEN' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_INFORMACIONFINANCIERACLIENTE' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PADRONFECHA' AND FECHA IN (SELECT DISTINCT FECHA FROM DW_PADRONCONTROL WHERE ESTADO=0)
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PERSONAJURVINCULADA' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOANEXO' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOANEXO' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOANEXOINCREMENTO' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOCAMBIOSITUACION' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOCUOTASRESUMEN' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMODETALLE' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOHISTORIA' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOINCREMENTO' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_PRESTAMOSALDOS' AND FECHA<'2023-04-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_SBSANEXO6RESULTADO' AND FECHA IN (SELECT DISTINCT FECHA FROM DW_PADRONCONTROL WHERE ESTADO=0)
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='DW_SOLICITUDPRESTAMOCUOTASRESUMEN' AND FECHA<'2023-10-01'
	DELETE FROM #TABLAFECHA WHERE TABLE_NAME='WT_DPF_STOCK' AND YEAR(FECHA)<>YEAR(GETDATE())



-- Eliminar las tablas temporales
DROP TABLE #calendario
DROP TABLE #calendariocierres
DROP TABLE #calendarioperiodo


------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
-------Obteniendo conteo de registros de tablas por fecha --------------------------------------------------------------------------------------

-- Crear una tabla temporal para almacenar los resultados
DROP TABLE IF EXISTS ConteoRegistrosPorFecha;
CREATE TABLE ConteoRegistrosPorFecha (
    NombreTabla NVARCHAR(255),
    ColumnaFecha NVARCHAR(255),
    FechaFecha NVARCHAR(30),
    CantidadRegistros INT
);

-- Declarar variables
DECLARE @Tabla NVARCHAR(255);
DECLARE @ColumnaFecha NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Contador INT = 1;
DECLARE @TotalTablas INT;
DECLARE @FechaFecha  NVARCHAR(30);
DECLARE @CantidadRegistros INT;

-- Insertar las tablas de interés en una tabla temporal
DROP TABLE IF EXISTS #Tablas;
CREATE TABLE #Tablas (
    NombreTabla NVARCHAR(255),
    ColumnaFecha NVARCHAR(255),
    RowNumber INT
);

INSERT INTO #Tablas (NombreTabla, ColumnaFecha,RowNumber)
SELECT TABLE_NAME, COLUMNA_FECHA, ROW_NUMBER() OVER (ORDER BY TABLE_NAME) AS RowNumber 
FROM [dbo].[ST_ValidacionTablas];


-- Obtener la cantidad total de tablas
SELECT @TotalTablas = COUNT(*) FROM #Tablas;

-- Inicializar el bucle WHILE
WHILE @Contador <= @TotalTablas
BEGIN
    -- Obtener el nombre de la tabla y la columna de fecha actual
    SELECT @Tabla = NombreTabla, @ColumnaFecha = ColumnaFecha 
    FROM #Tablas 
    WHERE RowNumber = @Contador;
    
    -- Construir la consulta dinámica para contar todos los registros por fecha
    SET @SQL = 'INSERT INTO ConteoRegistrosPorFecha (NombreTabla, ColumnaFecha, FechaFecha, CantidadRegistros) ' +
               'SELECT ''' + @Tabla + ''', ''' + @ColumnaFecha + ''', CONVERT(NVARCHAR(30), ' + @ColumnaFecha + ', 23), COUNT(*) FROM ' + @Tabla +
               ' GROUP BY CONVERT(NVARCHAR(30), ' + @ColumnaFecha + ', 23)';

    --SELECT @SQL
    -- Ejecutar la consulta dinámica
    EXEC sp_executesql @SQL;
    
    -- Incrementar el contador
    SET @Contador = @Contador + 1;
END;

-- Eliminar las tablas temporales
DROP TABLE #Tablas;



------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------------
-------Haciendo Comparación

DROP TABLE IF EXISTS VT_DATETABLE
SELECT 
A.*,
B.CantidadRegistros,
Registros= IIF(B.CantidadRegistros IS NULL,'NO','SI')
INTO VT_DATETABLE
FROM 
#TABLAFECHA A
LEFT JOIN ConteoRegistrosPorFecha B ON  A.TABLE_NAME=B.NombreTabla AND A.Fecha=B.FechaFecha



--SELECT * FROM #TABLAFECHA

--SELECT * FROM [ST_ValidacionTablas]  WHERE FRECUENCIA='DIARIA'

--SELECT MAX(dw_fechaCarga) FROM DW_APORTEMAXHISTORICO

-- WHERE FECHAUSUARIO='2024-03-01'



-- Seleccionar los resultados finales
--SELECT * FROM C;

SELECT * FROM [ST_ValidacionTablas] WHERE TABLE_NAME='DW_XLIBRODIARIO (PERIODO LIBRO)'

SELECT * FROM ConteoRegistrosPorFecha
SELECT * FROM DW_PADRONCONTROL

UPDATE A
SET  TABLE_NAME='DW_XLIBRODIARIODETALLE'
FROM [ST_ValidacionTablas] A WHERE TABLE_NAME='DW_XLIBRODIARIODETALLE (Periodo Libro)'

----Tablas operativas ---Padron Control (Trigger para el cambio de estado del cierre)

----Tablas contables (1 año)


--DROP TABLE  [ST_ValidacionTablas] 