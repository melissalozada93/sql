USE DWH_HISTORICO
----Crear la tabla de resumen ICOMPARACIONES
DROP TABLE IF EXISTS ICOMPARACIONES
CREATE TABLE [dbo].[ICOMPARACIONES](
	[TableName] [varchar](50) NOT NULL,
	[Fecha] [date] NULL,
	[ColumnsName] [nvarchar](128) NULL,
	[Valor] [decimal](38, 2) NULL
) ON [PRIMARY]
GO

-- problema es la tablas que cambian de nombre cuando pasan de i a dw -- aportes/captacionanexo
DROP TABLE IF EXISTS #TablitasIntermedias;

SELECT distinct 
    realTableName = substring(table_name,2,len(table_name))--5
,ntable=ROW_NUMBER()OVER(PARTITION BY table_name ORDER BY table_name)
, tableName = table_name
, COLUMN_NAME = UPPER(COLUMN_NAME)
, DATA_TYPE
, ORDINAL_POSITION
INTO #TablitasIntermedias
FROM INFORMATION_SCHEMA.COLUMNS 
where COLUMN_NAME NOT IN (
'DW_FECHAPROCESO', 'dw_fechaCarga', 'CODIGOSOCIO', 'CIP', 
'CODIGOPERSONA', 'PERIODOSOLICITUD', 'NUMEROSOLICITUD', 
'PERIODOSOLICITUDCONCESIONAL', 'NUMEROSOLICITUDCONCESIONAL', 'FechaControl'
) AND DATA_TYPE NOT IN ('VARCHAR','text','char', 'DATE','datetime2')
AND TABLE_NAME  NOT IN (
'ICONFIG_MODELO_DOCUMENTO',
'ICOMPARACIONES',
'IFECHAS',
'TEMP_COMPARACION',
'PRE_INTERMEDIAS')--,'IAPORTEMAXHISTORICO');
;




CREATE CLUSTERED INDEX IX_#TablitasIntermedias_tableName_ORDINALPOSITION
ON #TablitasIntermedias (tableName, ORDINAL_POSITION);



DECLARE @tableName NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @columns2 NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);
DECLARE @sql2 NVARCHAR(MAX);
DECLARE @col NVARCHAR(255)

-- Crear un cursor para recorrer las tablas
DECLARE tableCursor CURSOR FOR
SELECT DISTINCT tableName
FROM #TablitasIntermedias;

-- Abrir el cursor
OPEN tableCursor;

-- Inicializar variables
FETCH NEXT FROM tableCursor INTO @tableName;

-- Iterar sobre las tablas
WHILE @@FETCH_STATUS = 0
BEGIN
	
	SET @col=(SELECT columnDate FROM IFECHAS WHERE tableName=@tableName)
    -- Inicializar la variable de columnas para la tabla actual

    SET @columns = '';

    -- Concatenar los nombres de las columnas y determinar el tipo de datos
    SELECT @columns = STUFF((SELECT ', ' + 
        CASE
            WHEN DATA_TYPE = 'int' THEN 'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
            WHEN DATA_TYPE = 'decimal' THEN 'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
            ELSE 'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
        END
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName FOR XML PATH('')), 1, 2, '');


	SET @columns2 = '';
	-- Concatenar los nombres de las columnas con corchetes
	SELECT @columns2 =  STUFF((SELECT ', ' + COLUMN_NAME  FROM #TablitasIntermedias WHERE TABLENAME = @tableName FOR XML PATH('')), 1, 2, '');

	

    -- Construir la consulta SQL
    SET @sql = '
		DROP TABLE IF EXISTS TEMP_COMPARACION
        SELECT
            ''' + @tableName + ''' AS TableName,
            FechaControl, ' + @columns + ',COUNT(*)Qty
		INTO TEMP_COMPARACION
        FROM ' + @tableName + '
        GROUP BY FechaControl ';


    -- Ejecutar la consulta
    EXEC ( @sql);



	    -- Construir la consulta SQL
    SET @sql2 = '
		INSERT INTO ICOMPARACIONES
		SELECT TableName,FechaControl, ColumnsName, Valor
		FROM   
		   (SELECT TableName,FechaControl,'+@columns2+',Qty
		   FROM TEMP_COMPARACION ) p  
		UNPIVOT  
		   (VALOR FOR ColumnsName IN   
			  ('+@columns2+',Qty)  
		)AS unpvt;  
		
		'

		

    -- Ejecutar la consulta
    EXEC ( @sql2);


    -- Obtener la siguiente tabla
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Cerrar y liberar el cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;



--select * from ICOMPARACIONES

--SELECT * FROM TEMP_COMPARACION

