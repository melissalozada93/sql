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
) AND DATA_TYPE NOT IN ('VARCHAR','text','char')
AND TABLE_NAME NOT IN (
'ICONFIG_MODELO_DOCUMENTO',
'ICOMPARACIONES',
'IFECHAS',
'TEMP_COMPARACION',
'PRE_INTERMEDIAS',
'BDSOCDATOS')--,'IAPORTEMAXHISTORICO');
;


SELECT * FROM #TablitasIntermedias
WHERE tableName='ICUENTACORRIENTE' AND COLUMN_NAME='NUMEROCUENTA'

SELECT * FROM  INFORMATION_SCHEMA.COLUMNS 
where TABLE_NAME='ICUENTACORRIENTE' AND COLUMN_NAME='NUMEROCUENTA'



CREATE CLUSTERED INDEX IX_#TablitasIntermedias_tableName_ORDINALPOSITION
ON #TablitasIntermedias (tableName, ORDINAL_POSITION);





DECLARE @tableName NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @columns2 NVARCHAR(MAX);
DECLARE @headers  NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);
DECLARE @sql2 NVARCHAR(MAX);
DECLARE @col NVARCHAR(255);



-- Crear un cursor para recorrer las tablas
DECLARE tableCursor CURSOR FOR
SELECT DISTINCT tableName
FROM #TablitasIntermedias;

-- Abrir el cursor
OPEN tableCursor;

-- Iterar sobre las tablas
FETCH NEXT FROM tableCursor INTO @tableName;

WHILE @@FETCH_STATUS = 0
BEGIN
	
		-- Crear la tabla dinámicamente
		DECLARE @createTableSQL NVARCHAR(MAX);

		SET @createTableSQL = '
		DROP TABLE IF EXISTS TEMP_COMPARACION
			CREATE TABLE TEMP_COMPARACION (
				TableName NVARCHAR(MAX),
				FechaComparacion DATE,
				Qty DECIMAL(36,2),
				' + STUFF((
					SELECT ', ' + COLUMN_NAME + '  DECIMAL(36,2)' 
					FROM (SELECT DISTINCT COLUMN_NAME FROM #TablitasIntermedias WHERE 
					TableName=@tableName and
					COLUMN_NAME <>'TableName')A
					FOR XML PATH(''), TYPE
				).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + '
			)';

		-- Ejecutar la consulta para crear la tabla
		EXEC (@createTableSQL);

  
    SET @col = (SELECT columnDate FROM IFECHAS WHERE tableName = @tableName);
    
    -- Inicializar la variable de columnas para la tabla actual
    SET @columns = '';
	SET @headers = '';

    -- Concatenar los nombres de las columnas y determinar el tipo de datos
    SELECT @columns = COALESCE(@columns + ', ', '') +
        CASE
            WHEN DATA_TYPE = 'int' THEN  'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
            WHEN DATA_TYPE = 'decimal' THEN  'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
			WHEN DATA_TYPE = 'date' THEN  'SUM(CAST(DATEDIFF(DAY, ''19000101'', convert(date,' + COLUMN_NAME + ',101)) AS float)) AS'  + COLUMN_NAME
			WHEN DATA_TYPE = 'datetime2' THEN  'SUM(CAST(DATEDIFF(DAY, ''19000101'', convert(date,' + COLUMN_NAME + ',101)) AS float)) AS'  + COLUMN_NAME
		ELSE
			 'SUM(CAST(' + COLUMN_NAME + ' AS DECIMAL (36,2))) AS ' + COLUMN_NAME
        END
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName;


	SET @columns2 = '';
	-- Concatenar los nombres de las columnas con corchetes
	SELECT @columns2 =  STUFF((SELECT ', ' + COLUMN_NAME  FROM #TablitasIntermedias WHERE TABLENAME = @tableName FOR XML PATH('')), 1, 2, '');



	SELECT @headers = COALESCE(@headers + ', ', '') +COLUMN_NAME 
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName;

    -- Construir la consulta SQL
    SET @sql = '
        INSERT INTO TEMP_COMPARACION (TableName, FechaComparacion ,Qty ' + @headers + ')
        SELECT
            ''' + @tableName + ''' AS TableName,
            ' + @col + ' as FechaComparacion, count(*)Qty ' + @columns + '
        FROM ' + @tableName + '
        GROUP BY ' + @col;

    -- Ejecutar la consulta
    EXEC (@sql);

	    -- Construir la consulta SQL
    SET @sql2 = '
		INSERT INTO ICOMPARACIONES
		SELECT TableName,FechaComparacion, ColumnsName, Valor
		FROM   
		   (SELECT TableName,FechaComparacion,'+@columns2+',Qty
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


--select * from TEMP_COMPARACION
--select * from ICOMPARACIONES





SELECT * FROM ICOMPARACIONES WHERE COLUMNSNAME IN('NUMEROCUENTA','TABLASERVICIO','FECHARENUNCIA')
AND TableName='ICUENTACORRIENTE'

