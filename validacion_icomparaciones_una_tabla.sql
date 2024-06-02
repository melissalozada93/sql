USE DWH_HISTORICO



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
'PERIODOSOLICITUDCONCESIONAL', 'NUMEROSOLICITUDCONCESIONAL', 'FechaControl','FECHA'
) AND DATA_TYPE NOT IN ('VARCHAR','text','char', 'DATE','datetime2')
AND TABLE_NAME NOT IN ('ICONFIG_MODELO_DOCUMENTO')--,'IAPORTEMAXHISTORICO');
;
 
CREATE CLUSTERED INDEX IX_#TablitasIntermedias_tableName_ORDINALPOSITION
ON #TablitasIntermedias (tableName, ORDINAL_POSITION);


-- Crear la tabla dinámicamente
DECLARE @createTableSQL NVARCHAR(MAX);

SET @createTableSQL = '
DROP TABLE IF EXISTS ICOMPARACIONES
    CREATE TABLE ICOMPARACIONES (
        TableName NVARCHAR(MAX),
        Fecha DATE,
        ' + STUFF((
            SELECT ', ' + COLUMN_NAME + ' VARCHAR(250)' 
            FROM (SELECT DISTINCT COLUMN_NAME FROM #TablitasIntermedias WHERE COLUMN_NAME <>'TableName')A
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') + '
    )';

-- Ejecutar la consulta para crear la tabla
EXEC (@createTableSQL);



DECLARE @tableName NVARCHAR(MAX);
DECLARE @columns NVARCHAR(MAX);
DECLARE @headers  NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);
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
    SET @col = (SELECT columnDate FROM IFECHAS WHERE tableName = @tableName);
    
    -- Inicializar la variable de columnas para la tabla actual
    SET @columns = '';
	SET @headers = '';

    -- Concatenar los nombres de las columnas y determinar el tipo de datos
    SELECT @columns = COALESCE(@columns + ', ', '') +
        CASE
            WHEN DATA_TYPE = 'int' THEN 'COUNT(' + COLUMN_NAME + ') AS ' + COLUMN_NAME
            WHEN DATA_TYPE = 'decimal' THEN 'SUM(' + COLUMN_NAME + ') AS ' + COLUMN_NAME
		ELSE
			'COUNT(' + COLUMN_NAME + ') AS ' + COLUMN_NAME
        END
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName;


	SELECT @headers = COALESCE(@headers + ', ', '') +COLUMN_NAME 
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName;

    -- Construir la consulta SQL
    SET @sql = '
        INSERT INTO ICOMPARACIONES (TableName, Fecha  ' + @headers + ')
        SELECT
            ''' + @tableName + ''' AS TableName,
            ' + @col + ' as Fecha ' + @columns + '
        FROM ' + @tableName + '
        GROUP BY ' + @col;

    -- Ejecutar la consulta
    EXEC (@sql);

    -- Obtener la siguiente tabla
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Cerrar y liberar el cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;