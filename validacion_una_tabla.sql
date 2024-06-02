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
        'PERIODOSOLICITUDCONCESIONAL', 'NUMEROSOLICITUDCONCESIONAL', 'FechaControl'
        ) AND DATA_TYPE not in ('VARCHAR','text','char', 'DATE')--,'datetime2')
        --AND TABLE_NAME IN ('IAPORTE')--,'IAPORTEMAXHISTORICO');
;



CREATE CLUSTERED INDEX IX_#TablitasIntermedias_tableName_ORDINALPOSITION
ON #TablitasIntermedias (tableName, ORDINAL_POSITION);





DECLARE @columns NVARCHAR(MAX);
DECLARE @sql NVARCHAR(MAX);
DECLARE @col NVARCHAR(255) = 'FECHAUSUARIO';
DECLARE @tableName NVARCHAR(MAX) = 'IAPORTE';

-- Concatenar los nombres de las columnas y determinar el tipo de datos
SELECT @columns = COALESCE(@columns + ', ', '') +
    CASE
        WHEN DATA_TYPE = 'int' THEN 'COUNT(' + COLUMN_NAME + ') AS COUNT_' + COLUMN_NAME
        WHEN DATA_TYPE = 'decimal' THEN 'SUM(' + COLUMN_NAME + ') AS ' + COLUMN_NAME
    END
FROM #TablitasIntermedias
WHERE TABLENAME = @tableName;



-- Construir la consulta SQL
SET @sql = '
    SELECT
        ''' + @tableName + ''' AS TableName,
        ' + @col + ', ' + @columns + '
    FROM ' + @tableName + '
    GROUP BY ' + @col+
	' ORDER BY '+ @col;

-- Ejecutar la consulta
EXEC sp_executesql @sql;


