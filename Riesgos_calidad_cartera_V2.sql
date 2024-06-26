USE [DWCOOPAC]
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA)
DECLARE @tipocambio DECIMAL(12, 3) = (
    SELECT PROMEDIO 
    FROM DW_XTIPOCAMBIO WITH (NOLOCK) 
    WHERE codigoTipoCambio = 3 AND fecha = @fecha
)

-- Crear tabla temporal para SALDOPRESTAMO
DROP TABLE IF EXISTS #PRESTAMOCUOTA
SELECT A.* 
INTO #PRESTAMOCUOTA
FROM (
    SELECT CODIGOSOLICITUD, SALDOPRESTAMO,FECHAVENCIMIENTO,
           N = ROW_NUMBER() OVER (PARTITION BY CODIGOSOLICITUD ORDER BY FECHAVENCIMIENTO DESC),
           ESTADO
    FROM DW_PRESTAMOCUOTAS 
    WHERE ESTADO = 1
) A
WHERE A.N = 1



-- Crear tabla temporal para INGRESOSECTORISTAS
DROP TABLE IF EXISTS #INGRESOSECTORISTAS;
SELECT 
    p.CODIGOSECTORISTA, 
    p2.NOMBRECOMPLETO AS nomsectorista, 
    convert(date,p2.FECHAINGRESOCOOP) AS fechaingresororiginador, 
    p.CIP
INTO #INGRESOSECTORISTAS
FROM DW_PERSONA p
LEFT JOIN DW_PERSONA p2 WITH (NOLOCK) ON p2.CODIGOPERSONA = p.CODIGOSECTORISTA AND p2.DW_FECHACARGA = @fecha
WHERE 
    p.DW_FECHACARGA = @fecha
    AND p.CODIGOSECTORISTA IS NOT NULL 
    AND p.CIP IS NOT NULL;


-- Consulta principal
DROP TABLE IF EXISTS #TEMP_REPORTE
SELECT 
    P.DW_CODIGOSOCIO AS codigoSocio,
    [dbo].[InitCap](per.NOMBRECOMPLETO) AS NombreSocio,
    pr.CODIGOSOLICITUD AS NroCredito,
    P.FechaDesembolso,
	pc.FechaVencimiento,
    pr.DiasAtraso,
    RangoDiasAtraso = 
        CASE 
			WHEN DiasAtraso  < 0   THEN 'Cuota Adelantada'
			WHEN DiasAtraso  = 0   THEN '0'
            WHEN pr.DIASATRASO >= 1 AND pr.DIASATRASO <= 8 THEN '1-8'
            WHEN pr.DIASATRASO >= 9 AND pr.DIASATRASO <= 15 THEN '9-15'
            WHEN pr.DIASATRASO >= 16 AND pr.DIASATRASO <= 30 THEN '16-30'  else 'M�s de 30'
        END,
    OrdenRangoDiasAtraso = 
        CASE 
			WHEN DiasAtraso  < 0   THEN 1
			WHEN DiasAtraso  = 0   THEN 2
            WHEN pr.DIASATRASO >= 1 AND pr.DIASATRASO <= 8 THEN 3
            WHEN pr.DIASATRASO >= 9 AND pr.DIASATRASO <= 15 THEN 4
            WHEN pr.DIASATRASO >= 16 AND pr.DIASATRASO <= 30 THEN 5 else 6
        END,
    p.DW_PRODUCTO AS Producto,
    sp.MODALIDADSOLICITUDDESCRIBE AS GrupoCredito,
    perf.FECHAINGRESOCOOP AS FechaIngresoFuncionario,
    [dbo].[InitCap](perf.NOMBRECORTO) AS FuncionarioOriginador,
    ISNULL(pc.SaldoPrestamo,0)SaldoPrestamo,
    SaldoPrestamoSoles = ISNULL(IIF(p.MONEDA = 2, pc.SALDOPRESTAMO * @tipocambio, pc.SALDOPRESTAMO),0),
    i.DW_TIPO AS JefaturaComercial,
    AlertaTemprana = IIF(p.FECHADESEMBOLSO BETWEEN  DATEADD(MONTH, -3,@FECHA) AND @FECHA, 'Fallidos', 
						IIF(p.FECHADESEMBOLSO BETWEEN  DATEADD(MONTH, -12,@FECHA) AND DATEADD(MONTH, -3,@FECHA ),'Originaci�n','')),
	p.DW_MONEDADESCRI AS Moneda
	INTO #TEMP_REPORTE
FROM DW_PRESTAMOCUOTASRESUMEN pr WITH (NOLOCK)
LEFT JOIN DW_PRESTAMO p WITH (NOLOCK) ON pr.CODIGOSOLICITUD = p.CODIGOSOLICITUD
LEFT JOIN #PRESTAMOCUOTA pc WITH (NOLOCK) ON pr.CODIGOSOLICITUD = pc.CODIGOSOLICITUD
LEFT JOIN DW_PRESTAMOANEXOHISTORICO pa WITH (NOLOCK) ON pr.CODIGOSOLICITUD = pa.CODIGOSOLICITUD
LEFT JOIN DW_PERSONA per WITH (NOLOCK) ON p.CODIGOPERSONA = per.CODIGOPERSONA
LEFT JOIN DW_syst901 i WITH (NOLOCK) ON pa.TIPOSOLICITUD = i.TBLCODARG
LEFT JOIN #INGRESOSECTORISTAS se WITH (NOLOCK) ON se.CIP = p.DW_CODIGOSOCIO
LEFT JOIN DW_SOLICITUDPRESTAMO sp WITH (NOLOCK) ON p.CODIGOSOLICITUD = sp.CODIGOSOLICITUD
LEFT JOIN DW_PERSONA perf WITH (NOLOCK) ON sp.CODIGOPERSONAANALISTA = perf.CODIGOPERSONA
WHERE 
    p.DW_PRODUCTO NOT IN ('TAN', 'PCC', 'PCH', 'PCY', 'PFI', 'PCM', 'PDD', 'PLC', 'PCL', 'DSC', 'CUO')
    --AND pr.NROCUOTASATRASADAS > 0
    --AND pr.DIASATRASO <= 30
    AND pr.dw_fechacarga = @FECHA
    AND p.DW_FECHACARGA = @FECHA
    AND pa.DW_FECHACARGA = @FECHA
    AND per.DW_FECHACARGA = @FECHA
	AND perf.DW_FECHACARGA = @FECHA
	AND SP.DW_FECHACARGA = @FECHA
    AND i.TBLCODTAB = 10
	AND YEAR(P.FECHADESEMBOLSO)>=2023

	--select * from #TEMP_REPORTE where NroCredito='2023-1031640'

	--select * from DW_PRESTAMOCUOTASRESUMEN where CODIGOSOLICITUD='2023-1031640'


--3311


DROP TABLE IF EXISTS #PVOPERACION
SELECT NroCredito,
       ISNULL([Cuota Adelantada], '0') AS [Cuota Adelantada],
	   ISNULL([0], '0') AS [0],
       ISNULL([1-8], '0') AS [1-8],
       ISNULL([9-15], '0') AS [9-15],
       ISNULL([16-30], '0') AS [16-30],
       ISNULL([M�s de 30], '0') AS [M�s de 30]
	   into #PVOPERACION
FROM (
    SELECT NroCredito, RangoDiasAtraso,1 as Operacion
    FROM #TEMP_REPORTE
) AS SourceTable
PIVOT (
    sum(Operacion)
    FOR RangoDiasAtraso IN ([Cuota Adelantada],[0],[1-8],[9-15],[16-30],[M�s de 30])
) AS PivotTable;



DROP TABLE IF EXISTS #PVSALDO
SELECT NroCredito,
       ISNULL([Cuota Adelantada], '0') AS [Cuota Adelantada],
	   ISNULL([0], '0') AS [0],
       ISNULL([1-8], '0') AS [1-8],
       ISNULL([9-15], '0') AS [9-15],
       ISNULL([16-30], '0') AS [16-30],
       ISNULL([M�s de 30], '0') AS [M�s de 30]
	  into #PVSALDO
FROM (
    SELECT NroCredito, RangoDiasAtraso, SALDOPRESTAMOSOLES as Saldo
    FROM #TEMP_REPORTE 
) AS SourceTable
PIVOT (
    SUM(Saldo)
    FOR RangoDiasAtraso IN ([Cuota Adelantada],[0],[1-8],[9-15],[16-30],[M�s de 30])
) AS PivotTable;



DROP TABLE IF EXISTS #FECHA_CANCELACION
SELECT A.CodigoSolicitud,A.Estado,A.N,A.FechaVencimiento,
FechaCancelacion= IIF(A.ESTADO=1,B.FECHACANCELACION,NULL)
,FechaPagoParcial= IIF(A.ESTADO=2,B.FECHACANCELACION,NULL)
,isnull(DATEDIFF(DAY, A.FechaVencimiento, IIF(A.ESTADO=1,B.FECHACANCELACION,NULL)),0) AS DiasAtraso,
A.SaldoPrestamo,
SaldoPrestamoSoles= IIF(A.MONEDA = 2, A.SALDOPRESTAMO * @tipocambio, A.SALDOPRESTAMO)
INTO #FECHA_CANCELACION
FROM DW_PRESTAMOCUOTAS  A
LEFT JOIN 
(SELECT PERIODOSOLICITUD,
DBO.UFN_CODIGOSOLICITUD(PERIODOSOLICITUD,NUMEROSOLICITUD)CODIGOSOLICITUD,
NUMEROCUOTA,max(FECHACANCELACION)FECHACANCELACION 
FROM dw_prestamopagoscuota 
GROUP BY PERIODOSOLICITUD,NUMEROSOLICITUD,NUMEROCUOTA)B
ON A.CODIGOSOLICITUD=B.CODIGOSOLICITUD
AND A.N=B.NUMEROCUOTA

WHERE  A.CODIGOSOLICITUD IN(SELECT DISTINCT NROCREDITO FROM TEMP_REPORTE)
ORDER BY CODIGOSOLICITUD,N ASC



DROP TABLE IF EXISTS #HISTORICO_DIAS_ATRASO
SELECT *
,RangoDiasAtraso = 
        CASE
		    WHEN DiasAtraso  < 0   THEN 'Cuota Adelantada'
			WHEN DiasAtraso  = 0   THEN '0'
            WHEN DiasAtraso >= 1 AND DiasAtraso <= 8 THEN '1-8'
            WHEN DiasAtraso >= 9 AND DiasAtraso <= 15 THEN '9-15'
            WHEN DiasAtraso >= 16 AND DiasAtraso <= 30 THEN '16-30' else 'M�s de 30'
        END
INTO #HISTORICO_DIAS_ATRASO
FROM #FECHA_CANCELACION



DROP TABLE IF EXISTS #HISTORICO
Select CodigoSolicitud,
RangoDiasAtraso, Count(distinct N)[Operaciones],
SUM(SaldoPrestamoSoles)[Saldo]
into #HISTORICO
from #HISTORICO_DIAS_ATRASO 
group by CodigoSolicitud,
RangoDiasAtraso


DROP TABLE IF EXISTS #HISTORICO_PVOPERACION
SELECT CodigoSolicitud,
       ISNULL([Cuota Adelantada], '0') AS [Cuota Adelantada],
	   ISNULL([0], '0') AS [0],
       ISNULL([1-8], '0') AS [1-8],
       ISNULL([9-15], '0') AS [9-15],
       ISNULL([16-30], '0') AS [16-30],
       ISNULL([M�s de 30], '0') AS [M�s de 30]
	   into #HISTORICO_PVOPERACION
FROM (
    SELECT CodigoSolicitud, RangoDiasAtraso, Operaciones
    FROM #HISTORICO
) AS SourceTable
PIVOT (
    SUM(Operaciones)
    FOR RangoDiasAtraso IN ([Cuota Adelantada],[0],[1-8],[9-15],[16-30],[M�s de 30])
) AS PivotTable;



DROP TABLE IF EXISTS #HISTORICO_PVSALDO
SELECT CodigoSolicitud,
       ISNULL([Cuota Adelantada], '0') AS [Cuota Adelantada],
	   ISNULL([0], '0') AS [0],
       ISNULL([1-8], '0') AS [1-8],
       ISNULL([9-15], '0') AS [9-15],
       ISNULL([16-30], '0') AS [16-30],
       ISNULL([M�s de 30], '0') AS [M�s de 30]
	  into #HISTORICO_PVSALDO
FROM (
    SELECT CodigoSolicitud, RangoDiasAtraso, saldo
    FROM #HISTORICO 
) AS SourceTable
PIVOT (
    SUM(Saldo)
    FOR RangoDiasAtraso IN ([Cuota Adelantada],[0],[1-8],[9-15],[16-30],[M�s de 30])
) AS PivotTable;




DROP TABLE IF EXISTS WT_RIESGOS_CALIDAD_CARTERA
SELECT T.*,
O.[0][#OpeRango 0],
O.[1-8][#OpeRango 1-8],
O.[9-15][#OpeRango 9-15],
O.[16-30][#OpeRango 16-30],
O.[M�s de 30][#OpeRango M�s de 30],
S.[0][SaldoRango 0],
S.[1-8][SaldoRango 1-8],
S.[9-15][SaldoRango 9-15],
S.[16-30][SaldoRango 16-30],
S.[M�s de 30][SaldoRango M�s de 30],
OH.[0][#OpeHRango 0],
OH.[1-8][#OpeHRango 1-8],
OH.[9-15][#OpeHRango 9-15],
OH.[16-30][#OpeHRango 16-30],
OH.[M�s de 30][#OpeHRango M�s de 30],
SH.[0][SaldoHRango 0],
SH.[1-8][SaldoHRango 1-8],
SH.[9-15][SaldoHRango 9-15],
SH.[16-30][SaldoHRango 16-30],
SH.[M�s de 30][SaldoHRango M�s de 30],
convert(date,@FECHA) FechaActualizacion
INTO WT_RIESGOS_CALIDAD_CARTERA
FROM #TEMP_REPORTE T 
LEFT JOIN #PVOPERACION O
ON T.NROCREDITO=O.NROCREDITO
LEFT JOIN #PVSALDO S
ON T.NROCREDITO=S.NROCREDITO
LEFT JOIN #HISTORICO_PVOPERACION OH
ON T.NROCREDITO=OH.CODIGOSOLICITUD
LEFT JOIN #HISTORICO_PVSALDO SH
ON T.NROCREDITO=SH.CODIGOSOLICITUD

SELECT * FROM WT_RIESGOS_CALIDAD_CARTERA
--select * from #HISTORICO_DIAS_ATRASO
--where CODIGOSOLICITUD='2023-1830150'
--order by CODIGOSOLICITUD, n asc


--SELECT * FROM #HISTORICO
--where CODIGOSOLICITUD='2023-1830150'

--SELECT * FROM #HISTORICO_PV
--where CODIGOSOLICITUD='2023-1830150'


--select * from TEMP_REPORTE where NROCREDITO='2023-1830150'

--SELECT * FROM dw_prestamopagoscuota WHERE 
--PERIODOSOLICITUD='2022' AND NUMEROSOLICITUD='0186350'
--ORDER BY NUMEROCUOTA ASC


--select * from DW_PRESTAMOCUOTASRESUMEN
--where  CODIGOSOLICITUD='2022-0186350' and dw_fechacarga='2023-11-12'

