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




DECLARE @tableName NVARCHAR(MAX);
DECLARE @headers  NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);


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

	SET @headers = '';
	SELECT @headers = COALESCE(@headers + ', ', '') +COLUMN_NAME 
    FROM #TablitasIntermedias
    WHERE TABLENAME = @tableName;

    -- Construir la consulta SQL
    SET @sql = '
        SELECT TableName, Fecha'+@headers+'
        FROM  ICOMPARACIONES 
        WHERE tableName= ''' + @tableName+'''';

    -- Ejecutar la consulta
    exec (@sql);

    -- Obtener la siguiente tabla
    FETCH NEXT FROM tableCursor INTO @tableName;
END

-- Cerrar y liberar el cursor
CLOSE tableCursor;
DEALLOCATE tableCursor;