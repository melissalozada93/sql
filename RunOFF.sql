USE[DWCOOPAC]
-- Declarar fecha de tabla FECHAMAESTRA
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA from [DWCOOPAC].dbo.ST_FECHAMAESTRA)



-----Insertar información del Funcionarios
	DROP TABLE IF EXISTS #FUNCIONARIO
	CREATE TABLE #FUNCIONARIO (
	 CodFuncionario VARCHAR(7),
	 Gerencia VARCHAR(10),
	 CodJefatura VARCHAR(7),
	 Estado BIGINT);


	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0124189','RICARDO YI','0113954','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0068193','RICARDO YI','0113954','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0114904','RICARDO YI','0114904','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0126098','RICARDO YI','0114904','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0031171','RICARDO YI','0013866','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0043827','RICARDO YI','0013866','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0122631','RICARDO YI','0121859','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0041353','RICARDO YI','0121859','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0121859','RICARDO YI','0121859','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0127832','RICARDO YI','0121859','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0123362','RICARDO YI','0121859','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0113954','RICARDO YI','0113954','1')
	INSERT INTO #FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado) VALUES ('0134374','RICARDO YI','0113954','1')

------Generar Reporte--------------------
	DROP TABLE IF EXISTS TEMP_REPORTE_RUNOFF_RESUMEN
	SELECT DISTINCT 
	RN.origen AS Origen,
	RN.codigosocio AS CodigoSocio,
	DBO.INITCAP(LTRIM(RTRIM(P1.NOMBRECOMPLETO))) AS NombreSocio,
	RN.codigoSolicitud,
	SP.CODIGOPERSONAANALISTA AS CodigoSectorista,
	DBO.INITCAP(LTRIM(RTRIM(P2.NOMBRECORTO))) AS Funcionario,
	DBO.INITCAP(LTRIM(RTRIM(p3.NOMBRECORTO))) AS Jefatura,
	FN.Gerencia,
	RN.NrocuotasAtrasadas,
	RN.Saldo_SBS, RN.TotalCapitalVencido_SBS
	INTO TEMP_REPORTE_RUNOFF_RESUMEN
	from  DWCOOPAC.dbo.WT_RUNOFF RN
	LEFT JOIN DW_SOLICITUDPRESTAMO SP ON RN.CODIGOSOLICITUD = SP.CODIGOSOLICITUD AND SP.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN #FUNCIONARIO FN ON SP.CODIGOPERSONAANALISTA=FN.CodFuncionario AND FN.ESTADO=1
	LEFT JOIN DW_DATOSSOCIO DS ON RN.CODIGOSOCIO=DS.CODIGOSOCIO AND DS.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P1 ON DS.CODIGOPERSONA = P1.CODIGOPERSONA AND P1.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P2 ON SP.CODIGOPERSONAANALISTA = P2.CODIGOPERSONA AND P2.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P3 ON fn.CodJefatura= P3.CODIGOPERSONA AND P3.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	--266356
	WHERE  RN.periodo <= '2023-12' 
	AND SP.CODIGOPERSONAANALISTA  IN(SELECT distinct CODFUNCIONARIO FROM #FUNCIONARIO WHERE ESTADO=1) 
	---20688

	------Generar Reporte Por Período--------------------
	DROP TABLE IF EXISTS WT_REPORTE_RUNOFF
	SELECT DISTINCT 
	RN.origen AS Origen,
	RN.codigosocio AS CodigoSocio,
	RN.periodo,
	RN.Fecini,
	DBO.INITCAP(LTRIM(RTRIM(P1.NOMBRECOMPLETO))) AS NombreSocio,
	RN.codigoSolicitud,
	SP.CODIGOPERSONAANALISTA AS CodigoSectorista,
	DBO.INITCAP(LTRIM(RTRIM(P2.NOMBRECORTO))) AS Funcionario,
	DBO.INITCAP(LTRIM(RTRIM(p3.NOMBRECORTO))) AS Jefatura,
	FN.Gerencia,
	RN.NrocuotasAtrasadas,RN.Amortizacion,
	RN.Saldo_SBS, RN.TotalCapitalVencido_SBS,@FECHA FechaActualizacion
	INTO WT_REPORTE_RUNOFF
	from  DWCOOPAC.dbo.WT_RUNOFF RN
	LEFT JOIN DW_SOLICITUDPRESTAMO SP ON RN.CODIGOSOLICITUD = SP.CODIGOSOLICITUD AND SP.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN #FUNCIONARIO FN ON SP.CODIGOPERSONAANALISTA=FN.CodFuncionario AND FN.ESTADO=1
	LEFT JOIN DW_DATOSSOCIO DS ON RN.CODIGOSOCIO=DS.CODIGOSOCIO AND DS.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P1 ON DS.CODIGOPERSONA = P1.CODIGOPERSONA AND P1.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P2 ON SP.CODIGOPERSONAANALISTA = P2.CODIGOPERSONA AND P2.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	LEFT JOIN DW_PERSONA P3 ON fn.CodJefatura= P3.CODIGOPERSONA AND P3.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
	--266356
	WHERE  RN.periodo >= '2023-10'  AND RN.periodo<='2024-11'
	AND SP.CODIGOPERSONAANALISTA  IN(SELECT distinct CODFUNCIONARIO FROM #FUNCIONARIO WHERE ESTADO=1) 
	---20688


------Generar datos de pivot Amortización
DECLARE @pivot_columns1 NVARCHAR(MAX);
DECLARE @query1 NVARCHAR(MAX);
DECLARE @table1 varchar(50) = 'DWCOOPAC.dbo.WT_RUNOFF_pivotAmortizacion'
			         SET @pivot_columns1 =  STUFF(
        ( 
         SELECT
            + ',',' ' +QUOTENAME( FA)  + ' ' 
         FROM
           (SELECT DISTINCT left(convert(varchar,cast( fecini as date)),7) AS FA
            FROM DWCOOPAC.dbo.WT_RUNOFF
               WHERE  CAST( fecini AS DATE) >  CAST(GETDATE()-1 AS DATE)
                     AND  CAST( fecini AS DATE) <= eomonth(CAST(GETDATE()+479 AS DATE))-- eomonth(CAST(GETDATE()+365 AS DATE)) --- cambio solicitado por gloria
                     --AND year( fecini) <=2023
           ) AS T
        ORDER BY FA
        FOR XML PATH('')
        ), 1, 1, '');


        SET @query1 = '
        IF OBJECT_ID('''+@table1+''') IS NOT NULL drop table '+@table1+'
        select codigoSolicitud,' +@pivot_columns1 + '  
        into '+@table1+' from 
        (
               select codigoSolicitud,amortizacion, left(convert(varchar,cast( fecini as date)),7) AS  mes 
                from DWCOOPAC.dbo.WT_RUNOFF
        ) as q1
        pivot (sum(amortizacion) for mes in (' +@pivot_columns1+ ')) as pvt

        '

        EXEC sp_executesql @query1;

------Generar datos de pivot Cierre
DECLARE @pivot_columns2 NVARCHAR(MAX);
DECLARE @query2 NVARCHAR(MAX);
DECLARE @table2 varchar(50) = 'DWCOOPAC.dbo.WT_RUNOFF_pivotCierre'
			         SET @pivot_columns2 =  STUFF(
        ( 
         SELECT
            + ',',' ' +QUOTENAME( FA)  + ' ' 
         FROM
           (SELECT DISTINCT left(convert(varchar,cast( fecini as date)),7) AS FA
            FROM DWCOOPAC.dbo.WT_RUNOFF
               WHERE  CAST( fecini AS DATE) >  CAST(GETDATE()-1 AS DATE)
                     AND  CAST( fecini AS DATE) <= eomonth(CAST(GETDATE()+479 AS DATE))-- eomonth(CAST(GETDATE()+365 AS DATE)) --- cambio solicitado por gloria
                     --AND year( fecini) <=2023
           ) AS T
        ORDER BY FA
        FOR XML PATH('')
        ), 1, 1, '');


        SET @query2 = '
        IF OBJECT_ID('''+@table2+''') IS NOT NULL drop table '+@table2+'
        select codigoSolicitud,' +@pivot_columns2 + '  
        into '+@table2+' from 
        (
               select codigoSolicitud,CierreMes, left(convert(varchar,cast( fecini as date)),7) AS  mes 
                from DWCOOPAC.dbo.WT_RUNOFF
        ) as q1
        pivot (sum(CierreMes) for mes in (' +@pivot_columns2+ ')) as pvt

        '

        EXEC sp_executesql @query2;

		--drop table WT_RUNOFF_pivot





-- enumero los meses que quiero
Drop table if exists #numeracionmeses
SELECT DISTINCT LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS mes, identity(int,1,1) as n
into #numeracionmeses
FROM DWCOOPAC.dbo.WT_RUNOFF
WHERE CAST(fecini AS DATE) <= DATEADD(MONTH,3, GETDATE())
order by LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) asc;-- importante el order para que se enumere del mes menor al mes mayor
 

 
DECLARE @ColumnasPeriodo VARCHAR(MAX);
DECLARE @ColumnasPeriodo2 VARCHAR(MAX);
DECLARE @ConsultaDinamica NVARCHAR(MAX);
-- Establece los nombres de las tres primeras columnas de período que deseas seleccionar
--SET @ColumnasPeriodo = N'[2023-11] AS [Cierre_2023-11],[2023-12] as [Cierre_2023-12],[2024-01] as [Cierre_2024-01]'; -- Reemplaza con los nombres reales
SET @ColumnasPeriodo =  concat(   'TC.[',(select mes from #numeracionmeses where n = 1),'] as [Cierre_',(select mes from #numeracionmeses where n = 1),'],'-- mes 1
                                 ,'TC.[',(select mes from #numeracionmeses where n = 2),'] as [Cierre_',(select mes from #numeracionmeses where n = 2),'],'-- mes 2
                                 ,'TC.[',(select mes from #numeracionmeses where n = 3),'] as [Cierre_',(select mes from #numeracionmeses where n = 3),']'-- mes 3
                              )-- solo le doy la forma

SET @ColumnasPeriodo2 =  concat(   'TP.[',(select mes from #numeracionmeses where n = 1),'] as [Amortizacion_',(select mes from #numeracionmeses where n = 1),'],'-- mes 1
                                 ,'TP.[',(select mes from #numeracionmeses where n = 2),'] as [Amortizacion_',(select mes from #numeracionmeses where n = 2),'],'-- mes 2
                                 ,'TP.[',(select mes from #numeracionmeses where n = 3),'] as [Amortizacion_',(select mes from #numeracionmeses where n = 3),']'-- mes 3
                              )-- solo le doy la forma
  

-- Construye la consulta dinámica
SET @ConsultaDinamica = N'
DROP TABLE IF EXISTS WT_REPORTE_RUNOFF_RESUMIDO
SELECT TR.*, ' + @ColumnasPeriodo + ','+@ColumnasPeriodo2+'
INTO WT_REPORTE_RUNOFF_RESUMIDO 
FROM TEMP_REPORTE_RUNOFF_RESUMEN AS TR
LEFT JOIN WT_RUNOFF_pivotCierre AS TC
ON TR.CODIGOSOLICITUD = TC.CODIGOSOLICITUD
LEFT JOIN WT_RUNOFF_pivotAmortizacion TP
ON TR.CODIGOSOLICITUD = TP.CODIGOSOLICITUD;
';
-- Ejecuta la consulta dinámica
EXEC sp_executesql @ConsultaDinamica;


DROP TABLE IF EXISTS TEMP_REPORTE_RUNOFF_RESUMEN
DROP TABLE IF EXISTS #FUNCIONARIO
DROP TABLE IF EXISTS #numeracionmeses
DROP TABLE IF EXISTS WT_RUNOFF_pivotAmortizacion
DROP TABLE IF EXISTS WT_RUNOFF_pivotCierre

