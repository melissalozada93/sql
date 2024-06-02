USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dasha_colaboradores]    Script Date: 14/03/2024 11:23:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_dwt_ReporteCadaHora]
 @HORA INT
as


 DECLARE @TC DECIMAL(15,3) = (select promedio from DW_XTIPOCAMBIO where fecha = (select fecha from st_fechamaestra where estado = 1) and codigoTipoCambio = 3)


--DECLARE @HORA INT
--SET @HORA = 14

--DROP TABLE IF EXISTS #HORAS;
--WITH Numeros AS (
--    SELECT 0 AS Numero
--    UNION ALL
--    SELECT Numero + 1
--    FROM Numeros
--    WHERE Numero < 23 -- Generar números del 0 al 23 (representando las 24 horas del día)
--)
--SELECT Numero AS HORA
--INTO #HORAS
--FROM Numeros
--WHERE Numero <= @HORA;

---------Listar las formas de pago-----------------------------------------------------
DROP TABLE IF EXISTS #FORMAPAGO;
SELECT 'Cheque' AS FORMAPAGO 
INTO #FORMAPAGO
UNION ALL
SELECT 'Efectivo'
UNION ALL
SELECT 'Transf. Bancaria';


-------Traer los datos necesarios del reporte 6 con los filtros necesarios-------------
DROP TABLE IF EXISTS #REPORTE6;
SELECT 
    FORMAPAGO,
    S = SUM(CASE WHEN MONEDA = 'S' THEN IMPORTE ELSE 0 END),
    D = SUM(CASE WHEN MONEDA = 'D' THEN IMPORTE ELSE 0 END),
	HORA= MAX(CONVERT(INT,RANGO_HORA))
INTO #REPORTE6
FROM 
    WT_REPORTE6
WHERE 
    CONVERT(DATE, FECHAUSUARIO) = CONVERT(DATE, GETDATE())
    AND RANGO_HORA <= @HORA 
    AND TIPOPERSONADESCRI = 'Persona Natural'
    AND TIPOMOVIMIENTO = 'SALIDA'
    AND FORMAPAGO IN ('Efectivo', 'Cheque')
    AND PRODUCTO IN (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE
						WHERE  Comentario='SBS Reporte Hora' AND Estado=1)
GROUP BY 
    FORMAPAGO




-------Traer los datos necesarios del reporte 66 con los filtros necesarios-------------
DROP TABLE IF EXISTS #REPORTE66;
SELECT 
    FORMAPAGO='Transf. Bancaria',
    S = SUM(CASE WHEN MONEDA = 1 THEN IMPORTESOLICITUD ELSE 0 END),
    D = SUM(CASE WHEN MONEDA = 2 THEN IMPORTESOLICITUD ELSE 0 END),
	HORA= MAX(CONVERT(INT,FILTRO_HORA))
INTO #REPORTE66
FROM 
    WT_REPORTE66
WHERE
	CONVERT(DATE, FECHASOLICITUDTRUNCADA) = CONVERT(DATE, GETDATE())
	AND FILTRO_HORA  <= @HORA  --IN (SELECT * FROM #HORAS)
	AND DESCESTADO = 'Liquidado'
	AND PERSONERIA = 'Natural'




	
-------Generar el reporte previo-------------
DROP TABLE IF EXISTS #WT_REPORTECADAHORA
SELECT 
A.*,
HORA=@HORA,
D=IIF(C.FORMAPAGO='Transf. Bancaria', ISNULL(C.D,0),ISNULL(B.D,0)),
S=IIF(C.FORMAPAGO='Transf. Bancaria', ISNULL(C.S,0),ISNULL(B.S,0))

INTO #WT_REPORTECADAHORA
FROM #FORMAPAGO A
LEFT JOIN #REPORTE6 B
	ON A.FORMAPAGO=B.FORMAPAGO
LEFT JOIN #REPORTE66 C
    ON A.FORMAPAGO=C.FORMAPAGO
ORDER BY A.FORMAPAGO ASC



-------Crear el reporte final con el consolidado-------------

-----Creando la tabla WT_REPORTECADAHORA-------------------
DROP TABLE IF EXISTS WT_REPORTECADAHORA
CREATE TABLE [dbo].[WT_REPORTECADAHORA](
    [ID] INT IDENTITY(1,1) PRIMARY KEY,
    [FORMAPAGO] [varchar](16) NOT NULL,
	[HORA] [int] NULL,
	[D] [decimal](38, 2) NOT NULL,
	[S] [decimal](38, 2) NOT NULL,
	[CONSOLIDADO] [decimal](38, 2) NULL
) ON [PRIMARY]


INSERT INTO [dbo].[WT_REPORTECADAHORA] ([FORMAPAGO], [HORA], [D], [S], [CONSOLIDADO])
SELECT FORMAPAGO, HORA, D, S, CONSOLIDADO = D*@TC +S
FROM #WT_REPORTECADAHORA

INSERT INTO [dbo].[WT_REPORTECADAHORA] ([FORMAPAGO], [HORA], [D], [S], [CONSOLIDADO])
SELECT 
FORMAPAGO = 'Total',
HORA,
D = SUM(D),
S = SUM(S),
CONSOLIDADO = SUM( D*@TC +S)
FROM #WT_REPORTECADAHORA
GROUP BY HORA


--DECLARE @HORA INT
--SET @HORA =( SELECT  DATENAME(HOUR, GETDATE()) )-1


--EXEC [usp_dwt_ReporteCadaHora]11



