USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dashb_runoff]    Script Date: 9/11/2023 15:49:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_dashb_runoff_resumen]
-- Declarar fecha de tabla FECHAMAESTRA
AS
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA)

-- Insertar información del Funcionarios
/*
	INSERT INTO ST_FUNCIONARIO (CodFuncionario,Gerencia,CodJefatura,Estado,FechaAlta,Usuario) 
	VALUES ('0134374','RICARDO YI','0113954','1',GETDATE(),'MELISSA LOZADA')

*/
-- Dar de baja Funcionarios
/*
	UPDATE ST_FUNCIONARIO 
	SET Estado=0,FechaBaja=GETDATE(),UsuarioMod='MELISSA LOZADA'
	WHERE CodFuncionario='0124189'

*/
-- Generar Reporte
DROP TABLE IF EXISTS TEMP_REPORTE_RUNOFF_RESUMEN;
SELECT DISTINCT 
    RN.origen AS Origen,
    RN.codigosocio AS CodigoSocio,
    DBO.INITCAP(LTRIM(RTRIM(P1.NOMBRECOMPLETO))) AS NombreSocio,
    RN.codigoSolicitud,
    SP.CODIGOPERSONAANALISTA AS CodigoSectorista,
    DBO.INITCAP(LTRIM(RTRIM(P2.NOMBRECORTO))) AS Funcionario,
    DBO.INITCAP(LTRIM(RTRIM(p3.NOMBRECORTO))) AS Jefatura,
    FN.Gerencia,
	iif(([dbo].[UFN_TIPO](producto))='C. Cartera','S','N') AS CompraCartera,
    RN.NrocuotasAtrasadas,
    RN.Saldo_SBS, 
    RN.TotalCapitalVencido_SBS
INTO TEMP_REPORTE_RUNOFF_RESUMEN
FROM DWCOOPAC.dbo.WT_RUNOFF RN
LEFT JOIN DW_SOLICITUDPRESTAMO SP ON RN.CODIGOSOLICITUD = SP.CODIGOSOLICITUD AND SP.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN ST_FUNCIONARIO FN ON SP.CODIGOPERSONAANALISTA=FN.CodFuncionario AND FN.ESTADO=1
LEFT JOIN DW_DATOSSOCIO DS ON RN.CODIGOSOCIO=DS.CODIGOSOCIO AND DS.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P1 ON DS.CODIGOPERSONA = P1.CODIGOPERSONA AND P1.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P2 ON SP.CODIGOPERSONAANALISTA = P2.CODIGOPERSONA AND P2.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P3 ON FN.CodJefatura = P3.CODIGOPERSONA AND P3.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
WHERE RN.periodo <= '2023-12' 
AND SP.CODIGOPERSONAANALISTA IN (SELECT DISTINCT CODFUNCIONARIO FROM ST_FUNCIONARIO WHERE ESTADO=1)

-- Generar Reporte Por Período
DROP TABLE IF EXISTS WT_REPORTE_RUNOFF;
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
	iif(([dbo].[UFN_TIPO](producto))='C. Cartera','S','N') AS CompraCartera,
    RN.NrocuotasAtrasadas,
    RN.Amortizacion,
    RN.Saldo_SBS, 
    RN.TotalCapitalVencido_SBS,
    CONVERT(DATE, @FECHA) AS FechaActualizacion
INTO WT_REPORTE_RUNOFF
FROM DWCOOPAC.dbo.WT_RUNOFF RN
LEFT JOIN DW_SOLICITUDPRESTAMO SP ON RN.CODIGOSOLICITUD = SP.CODIGOSOLICITUD AND SP.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN ST_FUNCIONARIO FN ON SP.CODIGOPERSONAANALISTA=FN.CodFuncionario AND FN.ESTADO=1
LEFT JOIN DW_DATOSSOCIO DS ON RN.CODIGOSOCIO=DS.CODIGOSOCIO AND DS.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P1 ON DS.CODIGOPERSONA = P1.CODIGOPERSONA AND P1.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P2 ON SP.CODIGOPERSONAANALISTA = P2.CODIGOPERSONA AND P2.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
LEFT JOIN DW_PERSONA P3 ON FN.CodJefatura = P3.CODIGOPERSONA AND P3.DW_FECHACARGA = CAST(GETDATE()-1 AS DATE) 
WHERE RN.periodo >= '2023-10' AND RN.periodo <= '2025-01'
AND SP.CODIGOPERSONAANALISTA IN (SELECT DISTINCT CODFUNCIONARIO FROM ST_FUNCIONARIO WHERE ESTADO=1)

-- Generar datos de pivot Amortización
DECLARE @pivot_columns1 NVARCHAR(MAX);
DECLARE @query1 NVARCHAR(MAX);
DECLARE @table1 VARCHAR(50) = 'DWCOOPAC.dbo.WT_RUNOFF_pivotAmortizacion';

SET @pivot_columns1 = STUFF(
    (
        SELECT ', ' + QUOTENAME(FA) + ' '
        FROM (
            SELECT DISTINCT LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS FA
            FROM DWCOOPAC.dbo.WT_RUNOFF
            WHERE CAST(fecini AS DATE) > CAST(GETDATE() - 1 AS DATE)
            AND CAST(fecini AS DATE) <= EOMONTH(CAST(GETDATE() + 479 AS DATE))
        ) AS T
        ORDER BY FA
        FOR XML PATH('')
    ), 1, 1, ''
);

SET @query1 = '
    IF OBJECT_ID(''' + @table1 + ''') IS NOT NULL DROP TABLE ' + @table1 + '
    SELECT codigoSolicitud, ' + @pivot_columns1 + '  
    INTO ' + @table1 + ' FROM 
    (
        SELECT codigoSolicitud, amortizacion, LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS mes 
        FROM DWCOOPAC.dbo.WT_RUNOFF
    ) AS q1
    PIVOT (SUM(amortizacion) FOR mes IN (' + @pivot_columns1 + ')) AS pvt
';

EXEC sp_executesql @query1;

-- Generar datos de pivot Cierre
DECLARE @pivot_columns2 NVARCHAR(MAX);
DECLARE @query2 NVARCHAR(MAX);
DECLARE @table2 VARCHAR(50) = 'DWCOOPAC.dbo.WT_RUNOFF_pivotCierre';

SET @pivot_columns2 = STUFF(
    (
        SELECT ', ' + QUOTENAME(FA) + ' '
        FROM (
            SELECT DISTINCT LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS FA
            FROM DWCOOPAC.dbo.WT_RUNOFF
            WHERE CAST(fecini AS DATE) > CAST(GETDATE() - 1 AS DATE)
            AND CAST(fecini AS DATE) <= EOMONTH(CAST(GETDATE() + 479 AS DATE))
        ) AS T
        ORDER BY FA
        FOR XML PATH('')
    ), 1, 1, ''
);

SET @query2 = '
    IF OBJECT_ID(''' + @table2 + ''') IS NOT NULL DROP TABLE ' + @table2 + '
    SELECT codigoSolicitud, ' + @pivot_columns2 + '  
    INTO ' + @table2 + ' FROM 
    (
        SELECT codigoSolicitud, CierreMes, LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS mes 
        FROM DWCOOPAC.dbo.WT_RUNOFF
    ) AS q1
    PIVOT (SUM(CierreMes) FOR mes IN (' + @pivot_columns2 + ')) AS pvt
';

EXEC sp_executesql @query2;

-- Enumerar los meses que quieres
DROP TABLE IF EXISTS #numeracionmeses;
SELECT DISTINCT LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) AS mes, IDENTITY(INT, 1, 1) AS n
INTO #numeracionmeses
FROM DWCOOPAC.dbo.WT_RUNOFF
WHERE CAST(fecini AS DATE) <= DATEADD(MONTH, 14, GETDATE())
ORDER BY LEFT(CONVERT(VARCHAR, CAST(fecini AS DATE)), 7) ASC;



DECLARE @ColumnasPeriodo VARCHAR(MAX);
DECLARE @ColumnasPeriodo2 VARCHAR(MAX);
DECLARE @ConsultaDinamica NVARCHAR(MAX);

-- Establece los nombres de las tres primeras columnas de período que deseas seleccionar
-- Reemplaza con los nombres reales
SET @ColumnasPeriodo = 
    CONCAT(
        'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 1), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 1), '], ',
        'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 2), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 2), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 3), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 3), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 4), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 4), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 5), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 5), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 6), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 6), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 7), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 7), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 8), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 8), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 9), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 9), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 10), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 10), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 11), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 11), '], ',
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 12), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 12), '], ',
        'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 13), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 13), '], ',		
		'TC.[', (SELECT mes FROM #numeracionmeses WHERE n = 14), '] AS [Cierre_', (SELECT mes FROM #numeracionmeses WHERE n = 14), '] '
    );

SET @ColumnasPeriodo2 = 
    CONCAT(
        'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 1), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 1), '], ',
        'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 2), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 2), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 3), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 3), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 4), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 4), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 5), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 5), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 6), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 6), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 7), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 7), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 8), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 8), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 9), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 9), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 10), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 10), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 11), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 11), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 12), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 12), '], ',
		'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 13), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 13), '], ',
        'TP.[', (SELECT mes FROM #numeracionmeses WHERE n = 14), '] AS [Amortizacion_', (SELECT mes FROM #numeracionmeses WHERE n = 14), ']'
    );

-- Construye la consulta dinámica
SET @ConsultaDinamica = '
    DROP TABLE IF EXISTS WT_REPORTE_RUNOFF_RESUMIDO;
    SELECT TR.*, ' + @ColumnasPeriodo + ', ' + @ColumnasPeriodo2 + '
    INTO WT_REPORTE_RUNOFF_RESUMIDO 
    FROM TEMP_REPORTE_RUNOFF_RESUMEN AS TR
    LEFT JOIN WT_RUNOFF_pivotCierre AS TC
    ON TR.CODIGOSOLICITUD = TC.CODIGOSOLICITUD
    LEFT JOIN WT_RUNOFF_pivotAmortizacion TP
    ON TR.CODIGOSOLICITUD = TP.CODIGOSOLICITUD;
';

-- Ejecuta la consulta dinámica
EXEC sp_executesql @ConsultaDinamica;

---- Limpieza de tablas temporales
--DROP TABLE IF EXISTS TEMP_REPORTE_RUNOFF_RESUMEN;
--DROP TABLE IF EXISTS #FUNCIONARIO;
--DROP TABLE IF EXISTS #numeracionmeses;
--DROP TABLE IF EXISTS WT_RUNOFF_pivotAmortizacion;
--DROP TABLE IF EXISTS WT_RUNOFF_pivotCierre;


[TemporalesDW]
--10343


--select * from WT_REPORTE_RUNOFF_RESUMIDO