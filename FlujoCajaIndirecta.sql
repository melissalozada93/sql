USE [DWCOOPAC]
GO
--/****** Object:  StoredProcedure [dbo].[usp_dasha_colaboradores]    Script Date: 30/05/2024 10:57:16 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER procedure [dbo].[usp_dashf_indicadores_indirectos]
--@FECHA DATE

--as
--set nocount on --
--set xact_abort on
--	begin transaction
--	begin try


--DECLARE @FECHA DATE = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE estado = 1)
DECLARE @FECHAREPORTE DATE =(SELECT DATEFROMPARTS(YEAR(DATEADD(YEAR, -1, @FECHA)), 1, 1))
DECLARE @TC DECIMAL(15,3) = '3.697'

--SELECT @FECHAREPORTE

-- Creación y llenado de #DW_PERSONA
DROP TABLE IF EXISTS #DW_PERSONA
SELECT DISTINCT 
       P.CODIGOPERSONA, 
       P.CIP, 
       P.NOMBRECOMPLETO, 
       P.TIPOPERSONADESCRI, 
       P.TIPODOCUMENTOID, 
       P.NUMERODOCUMENTOID, 
       P.NUMERORUC
INTO #DW_PERSONA
FROM DW_PERSONA P WITH (NOLOCK)
WHERE P.DW_FECHACARGA = @FECHA


-- Creación y llenado de #DW_DATOSSOCIO
DROP TABLE IF EXISTS #DW_DATOSSOCIO
SELECT DISTINCT
       CODIGOPERSONA, 
       CODIGOSOCIO, 
       CODIGOAGENCIA, 
       FECHAINGRESOCOOP
INTO #DW_DATOSSOCIO
FROM DW_DATOSSOCIO WITH (NOLOCK)
WHERE DW_FECHACARGA = @FECHA


-- Creación y llenado de #DW_CUENTACORRIENTE
DROP TABLE IF EXISTS #DW_CUENTACORRIENTE
SELECT * 
INTO #DW_CUENTACORRIENTE 
FROM DW_CUENTACORRIENTE WITH (NOLOCK)
WHERE dw_fechaCarga=@FECHA


-- Creación y llenado de #DW_DATOSCUENTACORRIENTE
DROP TABLE IF EXISTS #DW_DATOSCUENTACORRIENTE
SELECT * 
INTO #DW_DATOSCUENTACORRIENTE
FROM DW_DATOSCUENTACORRIENTE WITH (NOLOCK)
WHERE dw_fechaCarga=@FECHA


-- Creación y llenado de #DW_CUENTAMOVIMIENTO
DROP TABLE IF EXISTS #DW_CUENTAMOVIMIENTO
SELECT * 
INTO #DW_CUENTAMOVIMIENTO
FROM DW_CUENTAMOVIMIENTO WITH (NOLOCK)
WHERE  FECHAUSUARIO >= @FECHAREPORTE 

-- Creación y llenado de #DW_PRESTAMO
DROP TABLE IF EXISTS #DW_PRESTAMO
SELECT * 
INTO #DW_PRESTAMO
FROM DW_PRESTAMO WITH (NOLOCK)
WHERE dw_fechaCarga=@FECHA 




-- Creación y llenado de #TEMP_DW_PRESTAMOINCREMENTO
DROP TABLE IF EXISTS #TEMP_DW_PRESTAMOINCREMENTO
SELECT * 
INTO #TEMP_DW_PRESTAMOINCREMENTO 
FROM DW_PRESTAMOINCREMENTO  WITH (NOLOCK)
WHERE dw_fechaCarga=@FECHA 


-- Agregar codigocosocio y crear la tabla #DW_PRESTAMOINCREMENTO
DROP TABLE IF EXISTS #DW_PRESTAMOINCREMENTO
SELECT P.*,PER.CIP[CODIGOSOCIO]
INTO #DW_PRESTAMOINCREMENTO
FROM #TEMP_DW_PRESTAMOINCREMENTO P
LEFT JOIN #DW_PERSONA PER ON P.CODIGOPERSONA=PER.CODIGOPERSONA


-- Creación y llenado de #DW_PRESTAMO_PAGOS
DROP TABLE IF EXISTS #DW_PRESTAMO_PAGOS
SELECT * 
INTO #DW_PRESTAMO_PAGOS
FROM DW_PRESTAMO_PAGOS WITH (NOLOCK)
WHERE FECHACANCELACION >= @FECHAREPORTE



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE 9--------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------

-- Creación y llenado de #TEMP_DEF_APERTURA
DROP TABLE IF EXISTS #REPORTE9
SELECT 
       p.CIP AS CODIGOSOCIO, 
       cc.NUMEROCUENTA, 
       dc.MONTOINICIAL AS [MONTO], 
       cc.FECHAAPERTURA AS [FECHA],
	   CC.MONEDA,
	   ISNULL(tc.PROMEDIO,@TC) AS [TIPOCAMBIO],
	   MONTO_S=IIF(cc.MONEDA=2,dc.MONTOINICIAL*ISNULL(tc.PROMEDIO,@TC),dc.MONTOINICIAL)
INTO #REPORTE9
FROM #DW_CUENTACORRIENTE cc WITH (NOLOCK)
INNER JOIN #DW_PERSONA p
    ON cc.CODIGOPERSONA = p.CODIGOPERSONA
INNER JOIN #DW_DATOSCUENTACORRIENTE dc WITH (NOLOCK)
    ON dc.NUMEROCUENTA = cc.NUMEROCUENTA 
    AND dc.FECHAINICIO = CAST(cc.FECHAAPERTURA AS DATE)
INNER JOIN #DW_DATOSSOCIO dsoc 
    ON dsoc.CODIGOPERSONA = cc.CODIGOPERSONA 
LEFT JOIN DW_TIPOCAMBIOAJUSTE tc
ON FORMAT(cc.FECHAAPERTURA, 'yyyy-MM')=FORMAT(tc.FECHACAMBIO, 'yyyy-MM')
WHERE cc.FECHAAPERTURA>=@FECHAREPORTE
AND cc.TABLASERVICIO=102  




---5 S
--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE 259--------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #REPORTE259;

SELECT 
    cc.CODIGOPERSONA AS CODIGOSOCIO, 
    cc.NUMEROCUENTA, 
    a.IMPORTE1 AS [MONTO], 
    a.FECHAUSUARIO AS [FECHA],
    cc.MONEDA,
    ISNULL(tc.PROMEDIO, @TC) AS [TIPOCAMBIO],
    IIF(cc.MONEDA = 2, a.IMPORTE1 * ISNULL(tc.PROMEDIO, @TC), a.IMPORTE1) AS MONTO_S,
    ST.Det_producto_D,
	a.tipomovimiento,
	TIPOMOVIMIENTODESCRI
INTO #REPORTE259
FROM 
    #DW_CUENTAMOVIMIENTO a
INNER JOIN 
    #DW_CUENTACORRIENTE cc ON a.numerocuenta = cc.numerocuenta
INNER JOIN 
    #DW_DATOSSOCIO ds ON cc.codigopersona = ds.codigopersona 
LEFT JOIN 
    ST_MATRIZ_FLUJOCAJA st ON cc.PRODUCTO = st.NOMB_PRODUCTO
LEFT JOIN 
    DW_TIPOCAMBIOAJUSTE tc ON FORMAT(a.fechausuario, 'yyyy-MM') = FORMAT(tc.FECHACAMBIO, 'yyyy-MM')
WHERE 
    a.estado = 1
    --AND a.tipomovimiento IN (1, 3, 5, 7)  -----Se agregó filtro
    --AND TIPOMOVIMIENTODESCRI <> 'Abono Interes';  -----Se agregó filtro


---28 S

--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE 133--------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #REPORTE133;

SELECT  
    p.DW_CODIGOSOCIO AS CODIGOSOCIO, 
    RIGHT(pp.CODIGOSOLICITUD, 7) AS NUMEROSOLICITUD,
    pp.CODIGOSOLICITUD,
    pp.FECHACANCELACION AS FECHA,
    p.MONEDA,
    ISNULL(tc.PROMEDIO, @TC) AS TIPOCAMBIO,
    pp.AMORTIZACION AS CAPITAL, 
    IIF(p.MONEDA = 2, pp.AMORTIZACION * ISNULL(tc.PROMEDIO, @TC), pp.AMORTIZACION) AS CAPITAL_S,
    pp.INTERES AS INTERES, 
    IIF(p.MONEDA = 2, pp.INTERES * ISNULL(tc.PROMEDIO, @TC), pp.INTERES) AS INTERES_S,
    pp.INTERESMORATORIO AS INTERESMORATORIO, 
    IIF(p.MONEDA = 2, pp.INTERESMORATORIO * ISNULL(tc.PROMEDIO, @TC), pp.INTERESMORATORIO) AS INTERESMORATORIO_S,
    p.DW_SITUACIONPRESTAMODESCRI,
    pp.CONDICION_DESCRI,
    pp.TIPOMOVIEMIENTO_DESCRI,
    CASE 
        WHEN pp.ESTADO = 1 THEN 'ACTIVO' 
        ELSE 'EXTORNADO' 
    END AS ESTADO_PAGO,
    CONCAT(pp.observaciones, '-', caja.glosa) AS GLOSA

INTO #REPORTE133

FROM #DW_PRESTAMO_PAGOS pp

INNER JOIN #DW_PRESTAMO p 
    ON p.CODIGOSOLICITUD = pp.CODIGOSOLICITUD 

LEFT JOIN #DW_PERSONA PER
    ON PER.CODIGOPERSONA = P.CODIGOPERSONA

INNER JOIN dwt_solicitudprestamo sp 
    ON p.codigosolicitud = sp.codigosolicitud 

LEFT JOIN #DW_PERSONA PER2
    ON PER2.CODIGOPERSONA = sp.codigopromotor

LEFT JOIN dwt_caja caja
    ON caja.PERIODOcaja = pp.periodocaja 
    AND caja.NUMEROcaja = pp.numerocaja 
    AND caja.codigoagenciacaja = pp.codigoagenciacaja

LEFT JOIN DW_TIPOCAMBIOAJUSTE tc 
    ON FORMAT(pp.FECHACANCELACION, 'yyyy-MM') = FORMAT(tc.FECHACAMBIO, 'yyyy-MM')
   
WHERE 
    LEFT(p.CODIGOSOLICITUD, 4) NOT IN ('0001') 
    AND p.CODIGOSOLICITUD NOT IN (
        SELECT CODIGOSOLICITUD
        FROM DW_SOLICITUDPRESTAMO
        WHERE periodosolicitudconcesional IS NOT NULL 
        AND numerosolicitudconcesional IS NOT NULL 
    ) 


    
--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE 101----------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #REPORTE101;
WITH MAXFECHA AS (
    SELECT 
        A.NUMEROCUENTA,
        A.IMPORTE1,
        A.SALDOIMPORTE1,
        FECHAUSUARIO,
        ROW_NUMBER() OVER (PARTITION BY A.NUMEROCUENTA ORDER BY FECHAUSUARIO DESC) AS rn
    FROM 
        #DW_CUENTAMOVIMIENTO A
    WHERE 
        estado = 1 
        AND tipomovimiento IN (1, 3, 5, 7)
)

SELECT 
    NUMEROCUENTA,
    IMPORTE1,
    SALDOIMPORTE1
INTO #REPORTE101
FROM 
    MAXFECHA
WHERE 
    rn = 1
ORDER BY 
    FECHAUSUARIO DESC;


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE 254----------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #REPORTE254
SELECT 
    CC.NUMEROCUENTA,
	DCC.MONTOINICIAL AS CAPITALAPERTURAINICIAL,
	CC.ULTIMOMOVIMIENTO,
	CC.MONEDA,
	R101.SALDOIMPORTE1,
	IIF(R101.SALDOIMPORTE1<DCC.MONTOINICIAL,R101.SALDOIMPORTE1,DCC.MONTOINICIAL)K,
	IIF(R101.SALDOIMPORTE1<DCC.MONTOINICIAL,0,R101.SALDOIMPORTE1-DCC.MONTOINICIAL)I
INTO #REPORTE254
   FROM 
    #DW_CUENTACORRIENTE cc
LEFT JOIN 
   (SELECT NUMEROCUENTA, MIN(FECHAINICIO)FECHAINICIO FROM #DW_DATOSCUENTACORRIENTE
   GROUP BY NUMEROCUENTA) fi
   ON cc.NUMEROCUENTA=fi.NUMEROCUENTA
LEFT JOIN 
	#DW_DATOSCUENTACORRIENTE dcc ON fi.NUMEROCUENTA=dcc.NUMEROCUENTA AND fi.FECHAINICIO=dcc.FECHAINICIO
LEFT JOIN 
	#REPORTE101 R101 ON cc.NUMEROCUENTA=R101.NUMEROCUENTA 
WHERE 
    CC.TABLASERVICIO = 102 
    AND CC.ESTADO = 3
    AND EXISTS (
        SELECT 
            1 
        FROM 
            DW_SYST902 S 
        WHERE 
            --S.TBLESTADO = 1   AND 
			S.TBLCODTAB = CC.TABLASERVICIO
    )
	AND CC.ULTIMOMOVIMIENTO>=@FECHAREPORTE
	AND R101.SALDOIMPORTE1 IS NOT NULL



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----REPORTE COLOCACIONES----------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #TEMP_REPORTECOLOCACIONES
SELECT 
	DW_CODIGOSOCIO,
	CODIGOSOLICITUD,
	FECHADESEMBOLSO,
	MONEDA,
	MONTODESEMBOLSO 
INTO #TEMP_REPORTECOLOCACIONES
FROM #DW_PRESTAMO 
WHERE 
	FECHADESEMBOLSO>=@FECHAREPORTE
UNION
SELECT 
	CODIGOSOCIO,
	CODIGOSOLICITUD,
	FECHAPROGRAMACION,
	MONEDA,
	MONTOPRESTAMO
FROM #DW_PRESTAMOINCREMENTO 
WHERE 
	FECHAPROGRAMACION>=@FECHAREPORTE AND PAGAREANTERIOR='I' 


DROP TABLE IF EXISTS #REPORTECOLOCACIONES
SELECT 
       rc.DW_CODIGOSOCIO AS CODIGOSOCIO, 
       rc.CODIGOSOLICITUD, 
       rc.MONTODESEMBOLSO AS [MONTO], 
       rc.FECHADESEMBOLSO AS [FECHA],
	   rc.MONEDA,
	   ISNULL(tc.PROMEDIO,@TC) AS [TIPOCAMBIO],
	   MONTO_S=IIF(rc.MONEDA=2,rc.MONTODESEMBOLSO*ISNULL(tc.PROMEDIO,@TC),rc.MONTODESEMBOLSO)
INTO #REPORTECOLOCACIONES
FROM #TEMP_REPORTECOLOCACIONES rc WITH (NOLOCK)
LEFT JOIN DW_TIPOCAMBIOAJUSTE tc
ON FORMAT(rc.FECHADESEMBOLSO, 'yyyy-MM')=FORMAT(tc.FECHACAMBIO, 'yyyy-MM')




----***************************************************************************************************************************************************-
-----Flujo de Ingresos----------------------------------------------------------------------------------------------------------------------------------
----***************************************************************************************************************************************************-
----***************************************************************************************************************************************************-


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Productos Pasivos----------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


--------Resumiendo la tabla de Def apertura
DROP TABLE IF EXISTS #DPF_Apertura
SELECT
	ID=2,
	NOMBRE='DPF Apertura',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #DPF_Apertura
FROM #REPORTE9 
GROUP BY FORMAT(FECHA, 'yyyy-MM')



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----CTS---------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #CTS
SELECT
	ID=3,
	NOMBRE='CTS',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #CTS
FROM #REPORTE259 WHERE Det_producto_D='CTS' AND tipomovimiento IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Tanomoshi---------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Tanomoshi
SELECT
	ID=4,
	NOMBRE='Tanomoshi',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #Tanomoshi
FROM #REPORTE259 WHERE Det_producto_D='Tanomoshi'  AND tipomovimiento IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Aportes--------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Cobranza de aportaciones---------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #Aportaciones
SELECT
	ID=5,
	NOMBRE='Cobranza de aportaciones',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #Aportaciones
FROM #REPORTE259 WHERE Det_producto_D='Aportes'  AND tipomovimiento IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Movimientos de cuentas-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Movimientos DPF------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MovimientosDPF
SELECT
	ID=6,
	NOMBRE='Movimientos DPF',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #MovimientosDPF
FROM #REPORTE259 WHERE Det_producto_D in ('Certificados Perú','Certificados Japón')
GROUP BY FORMAT(FECHA, 'yyyy-MM')



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Movimientos DPF------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MovimientosAhorro
SELECT
	ID=7,
	NOMBRE='Movimientos Ahorro',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #MovimientosAhorro
FROM #REPORTE259 WHERE Det_producto_D='Ahorros a la Vista'
GROUP BY FORMAT(FECHA, 'yyyy-MM')




--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Recaudación de Cartera-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------


DROP TABLE IF EXISTS #RecaudacionCartera

SELECT FECHA,
CAPITAL=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',CAPITAL,0)),
REVERSA_CAP=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',CAPITAL,0)),

CAPITAL_S = SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',CAPITAL_S,0)),
REVERSA_CAP_S=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',CAPITAL_S,0)),

INTERES=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',INTERES,0)),
REVERSA_INT=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',INTERES,0)),

INTERES_S = SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',INTERES_S,0)) ,
REVERSA_INT_S=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',INTERES_S,0)),


INTERESMORATORIO=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',INTERESMORATORIO,0)),
REVERSA_INTM=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',INTERESMORATORIO,0)),

INTERESMORATORIO_S = SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI IN ('Amortizacion','Nota Abono')
AND ESTADO_PAGO='Activo',INTERESMORATORIO_S,0)) ,
REVERSA_INTM_S=SUM(IIF(DW_SITUACIONPRESTAMODESCRI<>'Vigente' AND CONDICION_DESCRI<>'Disp. Efectivo' AND LEFT(GLOSA,9)<>'pago pres' AND TIPOMOVIEMIENTO_DESCRI ='Nota Cargo'
AND ESTADO_PAGO='Activo',INTERESMORATORIO_S,0))
INTO #RecaudacionCartera
FROM #REPORTE133
GROUP BY FECHA




--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Principal------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #Principal
SELECT
	ID=10,
	NOMBRE='Principal',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(CAPITAL)-SUM(REVERSA_CAP)MONTO,
	SUM(CAPITAL_S)-SUM(REVERSA_CAP_s)MONTO_S
	INTO #Principal
FROM #RecaudacionCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Intereses------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #Intereses
SELECT
	ID=11,
	NOMBRE='Intereses',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(INTERES)-SUM(REVERSA_INT)MONTO,
	SUM(INTERES_S)-SUM(REVERSA_INT_S)MONTO_S
	INTO #Intereses
FROM #RecaudacionCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Mora------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #Mora
SELECT
	ID=12,
	NOMBRE='Mora',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(INTERESMORATORIO)-SUM(REVERSA_INTM)MONTO,
	SUM(INTERESMORATORIO_S)-SUM(REVERSA_INTM_S)MONTO_S
	INTO #Mora
FROM #RecaudacionCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Otros Ingresos-------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Venta de cartera-----------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #VentaCartera

SELECT FECHA,
SUM(CAPITAL)CAPITAL,
SUM(CAPITAL_S)CAPITAL_S,
SUM(INTERES)INTERES,
SUM(INTERES)INTERES_S,
SUM(INTERESMORATORIO)INTERESMORATORIO,
SUM(INTERESMORATORIO_S)INTERESMORATORIO_S
INTO #VentaCartera
FROM #REPORTE133  WHERE TIPOMOVIEMIENTO_DESCRI='Venta de Cartera - Nota abono' AND ESTADO_PAGO='ACTIVO'
GROUP BY FECHA


--------------------------------------------------------------------------------------------------------------------------------------------------------
----- Capital Venta Cartera-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #CapitalVC
SELECT
	ID=14,
	NOMBRE='Capital Venta Cartera',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(CAPITAL)MONTO,
	SUM(CAPITAL_S)MONTO_S
	INTO #CapitalVC
FROM #VentaCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
----- Interes Venta Cartera-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #InteresVC
SELECT
	ID=15,
	NOMBRE='Interes Venta Cartera',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(INTERES)MONTO,
	SUM(INTERES_S)MONTO_S
	INTO #InteresVC
FROM #VentaCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')




--------------------------------------------------------------------------------------------------------------------------------------------------------
----- Interes Moratorios Venta Cartera------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #MoraVC
SELECT
	ID=16,
	NOMBRE='Interes Moratorios Venta Cartera',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(INTERES)MONTO,
	SUM(INTERES_S)MONTO_S
	INTO #MoraVC
FROM #VentaCartera 
GROUP BY FORMAT(FECHA, 'yyyy-MM')




----***************************************************************************************************************************************************-
-----Flujo de Salidas----------------------------------------------------------------------------------------------------------------------------------
----***************************************************************************************************************************************************-
----***************************************************************************************************************************************************-


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Productos Pasivos----------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #SalidasPasivos
SELECT r254.*,
	   ISNULL(tc.PROMEDIO,@TC) AS [TIPOCAMBIO],
	   K_S=IIF(r254.MONEDA=2,r254.K*ISNULL(tc.PROMEDIO,@TC),r254.K),
	   I_S=IIF(r254.MONEDA=2,r254.I*ISNULL(tc.PROMEDIO,@TC),r254.I)	
INTO #SalidasPasivos
FROM #REPORTE254 r254
LEFT JOIN DW_TIPOCAMBIOAJUSTE tc
ON FORMAT(r254.ULTIMOMOVIMIENTO, 'yyyy-MM')=FORMAT(tc.FECHACAMBIO, 'yyyy-MM')





--------------------------------------------------------------------------------------------------------------------------------------------------------
-----DPF Retiro - K-------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #DPF_RetiroK
SELECT
	ID=23,
	NOMBRE='DPF Retiro - K',
	FORMAT(ULTIMOMOVIMIENTO, 'yyyy-MM')PERIODO,
	SUM(K)MONTO,
	SUM(K_S)MONTO_S
	INTO #DPF_RetiroK
FROM #SalidasPasivos 
GROUP BY FORMAT(ULTIMOMOVIMIENTO, 'yyyy-MM')



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----DPF Retiro - I-------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #DPF_RetiroI
SELECT
	ID=24,
	NOMBRE='DPF Retiro - I',
	FORMAT(ULTIMOMOVIMIENTO, 'yyyy-MM')PERIODO,
	SUM(I)MONTO,
	SUM(I_S)MONTO_S
	INTO #DPF_RetiroI
FROM #SalidasPasivos 
GROUP BY FORMAT(ULTIMOMOVIMIENTO, 'yyyy-MM')



--------------------------------------------------------------------------------------------------------------------------------------------------------
-----CTS---------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #CTSS
SELECT
	ID=25,
	NOMBRE='CTS',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #CTSS
FROM #REPORTE259 WHERE Det_producto_D='CTS' AND tipomovimiento NOT IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Tanomoshi---------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #TanomoshiS
SELECT
	ID=26,
	NOMBRE='Tanomoshi',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #TanomoshiS
FROM #REPORTE259 WHERE Det_producto_D='Tanomoshi'  AND tipomovimiento NOT IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Retiro de Aportaciones-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #RetiroAportaciones
SELECT
	ID=27,
	NOMBRE='Retiro de Aportaciones',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #RetiroAportaciones
FROM #REPORTE259 WHERE Det_producto_D='Aportes'  AND tipomovimiento NOT IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Movimientos DPF-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MovimientosDPFS
SELECT
	ID=28,
	NOMBRE='Movimientos DPF',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #MovimientosDPFS
FROM #REPORTE259 WHERE Det_producto_D='Movimientos DPF'  AND tipomovimiento NOT IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')


--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Movimientos DPF-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #MovimientosAhorroS
SELECT
	ID=29,
	NOMBRE='Movimientos Ahorro',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #MovimientosAhorroS
FROM #REPORTE259 WHERE Det_producto_D='Movimientos Ahorro'  AND tipomovimiento NOT IN (1, 3, 5, 7) AND TIPOMOVIMIENTODESCRI <> 'Abono Interes'
GROUP BY FORMAT(FECHA, 'yyyy-MM')




--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Créditos desembolsados-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------

-- Creación y llenado de #Temp_Creditos_desembolsados
DROP TABLE IF EXISTS #Creditos_desembolsados
SELECT
	ID=35,
	NOMBRE='Créditos desembolsados',
	FORMAT(FECHA, 'yyyy-MM')PERIODO,
	MONEDA,
	SUM(MONTO)MONTO,
	SUM(MONTO_S)MONTO_S
	INTO #Creditos_desembolsados
FROM #REPORTECOLOCACIONES 
GROUP BY FORMAT(FECHA, 'yyyy-MM'),MONEDA


--SELECT CODIGOSOLICITUD FROM  #REPORTECOLOCACIONES WHERE  FORMAT(FECHA, 'yyyy-MM')='2023-12' AND MONEDA=2

--------------------------------------------------------------------------------------------------------------------------------------------------------
-----Bases Externas-----------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #TEMP_BASES_EXTERNAS
SELECT 
	be.ID,
	NOMBRE=be.Indicador2,
	be.MONEDA,
	be.MONTO,
	MONTO_S=IIF(be.MONEDA='DOLARES',be.MONTO*ISNULL(tc.PROMEDIO,@TC),be.MONTO),
	FORMAT(Fecha, 'yyyy-MM')PERIODO 
INTO #TEMP_BASES_EXTERNAS
FROM ST_FCI_BASESEXTERNAS be
LEFT JOIN DW_TIPOCAMBIOAJUSTE tc
ON FORMAT(be.Fecha, 'yyyy-MM')=FORMAT(tc.FECHACAMBIO, 'yyyy-MM')
WHERE be.Monto>0


DROP TABLE IF EXISTS #BASES_EXTERNAS
SELECT ID, NOMBRE,PERIODO,SUM(MONTO)MONTO,SUM(MONTO_S)MONTO_S 
INTO #BASES_EXTERNAS
FROM #TEMP_BASES_EXTERNAS
GROUP BY  ID, NOMBRE,PERIODO

DROP TABLE IF EXISTS #WT_FLUJO_CAJA_DIRECTA
SELECT * 
INTO #WT_FLUJO_CAJA_DIRECTA
FROM #DPF_Apertura
UNION
SELECT * FROM #CTS
UNION 
SELECT * FROM #Tanomoshi
UNION 
SELECT * FROM #Aportaciones
UNION 
SELECT * FROM #MovimientosDPF
UNION 
SELECT * FROM #MovimientosAhorro
UNION
SELECT * FROM #Principal
UNION
SELECT * FROM #Intereses
UNION
SELECT * FROM #Mora
UNION
SELECT * FROM #CapitalVC
UNION
SELECT * FROM #InteresVC
UNION
SELECT * FROM #MoraVC
UNION
SELECT * FROM #DPF_RetiroK
UNION
SELECT * FROM #DPF_RetiroI
UNION
SELECT * FROM #CTSS
UNION
SELECT * FROM #TanomoshiS
UNION
SELECT * FROM #RetiroAportaciones
UNION
SELECT * FROM #MovimientosDPFS
UNION
SELECT * FROM #MovimientosAhorroS
UNION 
SELECT * FROM #BASES_EXTERNAS


DROP TABLE IF EXISTS WT_FLUJO_CAJA_DIRECTA
SELECT *,@FECHA FECHAACTUALIZACION
INTO WT_FLUJO_CAJA_DIRECTA
FROM #WT_FLUJO_CAJA_DIRECTA



--	--===================================================================================================================================================================
--	insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--    select getdate(),'Ejecucion Exitosa del Dashboard Flujo de Caja Indirecta',null, 'OK'


--	end try
--	begin catch
--		rollback transaction

--		declare @error_message varchar(4000), @error_severity int, @error_state int
--		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
--		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'ERROR en la ejecucion del Dashboard Flujo de Caja Indirecta', @error_message, 'ERROR'

--	end catch 
--	if @@trancount > 0
--		commit transaction		
--return 0



--select  FORMAT(FECHA, 'yyyy-MM')PERIODO, count(*)CANTIDAD,
--sum(capital)CAPITAL, SUM(INTERES) INTERES, SUM(INTERESMORATORIO)INTERESMORATORIO

--from #REPORTE133
--group by FORMAT(FECHA, 'yyyy-MM')
--order by FORMAT(FECHA, 'yyyy-MM') asc


--select top 10 * from #REPORTE133