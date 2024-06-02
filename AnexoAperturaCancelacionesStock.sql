USE [DWCOOPAC]

DECLARE @FECHA DATE = (SELECT fecha FROM ST_FECHAMAESTRA WHERE estado = 1)


---- Calendario de cierres y mes actual completo - se usa para el tipo de cambio mensual
DROP TABLE IF EXISTS #CALENDARIO
SELECT DISTINCT Fecha 
INTO #CALENDARIO
FROM dimtiempo 
WHERE (DiaNegativo = -1 and fecha <= @fecha) 
   OR (fecha BETWEEN DATEADD(dd,1,EOMONTH(CAST(@fecha AS DATE),-1)) and @fecha)

---- Calendario este año - se usa para la tabla final, limita el tiempo que figurara, a solicitud de gloria solo 2023 en adelante
DROP TABLE IF EXISTS #CALENDARIOHISYEAR
SELECT DISTINCT fecha 
INTO #CALENDARIOHISYEAR
FROM dimtiempo 
WHERE fecha BETWEEN DATEFROMPARTS(YEAR(GETDATE()-1), 1, 1) AND CAST(GETDATE()-1 AS DATE)

--=================================================================================================================================================================================================

-- todas las cuentas DPF activas y liquidadas para reducir el numero de cuentas
DROP TABLE IF EXISTS #cuentas
select 
      FECHACANCELACION = case when FECHACANCELACION = '-' then null else FECHACANCELACION end 
    , NROCUENTA
    , MONEDA
    , PRODUCTO
    , ESTADO
    , CANCELACIONANTICIPADA
    , AGENCIA = AGENCIAAPERTURA
    , PLAZODIAS
    , CANAL = CASE WHEN USUARIO = 'AGVIRTUAL' THEN 'DIGITAL' ELSE 'PRESENCIAL' END
into #cuentas
FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS
where fecha = @fecha
and TIPOPRODUCTO = 'Plazo Fijo' and estado in ('Activa','Liquidada')
and PRODUCTO != 'AHV' -- ESTO ES DE AHORROS


--=================================================================================================================================================================================================

-- de captacion anexo sacamos todas las cuentas con sus respectivos saldos
DROP TABLE IF EXISTS #DW_CUENTASALDOS
select 
      cs.dw_fechacarga
    , cs.numerocuenta
	, c.Producto
	, c.Moneda
	, c.Agencia
	, c.PlazoDias
	, c.Canal
    , cs.saldoimporte1
into #DW_CUENTASALDOS
from DW_CUENTASALDOS  cs
inner join #cuentas c on cs.NUMEROCUENTA = c.NROCUENTA

--================================================================================================================================================================================================

-- extraemos los datos de las renovaciones, para luego determinar las aperturas y las cancelaciones, al mismo tiempo se limita la data con
-- #cuentas
DROP TABLE IF EXISTS #datoscuentacorriente
select 
      dc.dw_fechaCarga
    , dc.FECHAINICIO
    , dc.FECHAVENCIMIENTO
    , dc.NUMEROCUENTA 
    , dc.MONTOINICIAL
    , c.moneda
    , c.FECHACANCELACION
    , c.PRODUCTO
    , c.ESTADO
    , c.CANCELACIONANTICIPADA
    , c.AGENCIA
    , c.PLAZODIAS
    , C.CANAL
into #datoscuentacorriente
from DW_DATOSCUENTACORRIENTE dc
inner join #cuentas c on dc.NUMEROCUENTA = c.NROCUENTA
where dc.dw_fechaCarga = @fecha--(select fecha from st_fechamaestra where estado = 1)--@fecha
-- and dc.NUMEROCUENTA = '001236923004'
 -- and dc.FECHAVENCIMIENTO >= '2023-01-01'


-- extraer aperturas
DROP TABLE IF EXISTS #aperturas
; with cte_aperturas as (
    select * 
    , n = ROW_NUMBER() over(partition by numerocuenta order by fechainicio asc) -- Diferencia para determina si es apertura o cancelacion
    from #datoscuentacorriente --WHERE FECHACANCELACION IS NOT NULL
) select obs = 'APERTURA', fecha = FECHAINICIO, FECHAINICIO, FECHAVENCIMIENTO, NUMEROCUENTA, MONTOINICIAL, moneda, FECHACANCELACION, PRODUCTO,
         ESTADO, CANCELACIONANTICIPADA, AGENCIA, PLAZODIAS, CANAL
into #aperturas
from cte_aperturas where n = 1 --and numerocuenta = '050071323001'




-- extraer cancelaciones
DROP TABLE IF EXISTS #cancelaciones
; with cte_cancelaciones as (
    select * 
    , n = ROW_NUMBER() over(partition by numerocuenta order by fechainicio desc) -- Diferencia para determina si es apertura o cancelacion
    from #datoscuentacorriente --where NUMEROCUENTA = '050071323001'
) select obs = 'CANCELACION', fecha = FECHACANCELACION, FECHAINICIO, FECHAVENCIMIENTO, NUMEROCUENTA, MONTOINICIAL, moneda, FECHACANCELACION, PRODUCTO,
         ESTADO, CANCELACIONANTICIPADA, AGENCIA, PLAZODIAS, CANAL
into #cancelaciones
from cte_cancelaciones where n = 1 and FECHACANCELACION IS NOT NULL --AND numerocuenta = '050071323001'-- Diferencia para determina si es apertura o cancelacion
--where numerocuenta = '000001423001'



DROP TABLE IF EXISTS #FILTROS
select distinct  Producto,Moneda,--Estado,CancelacionAnticipada,
Agencia,PlazoDias,Canal 
INTO #FILTROS
from #aperturas
union
select distinct  Producto,Moneda,---Estado,CancelacionAnticipada,
Agencia,PlazoDias,Canal  
from #cancelaciones

--347


DROP TABLE IF EXISTS #MATRIZ
SELECT *
INTO #MATRIZ
FROM #CALENDARIOHISYEAR C
CROSS JOIN #FILTROS F;



drop table if exists #consolidado;
WITH DatosCombinados AS (
    SELECT fecha,
	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal,
	SUM(montoinicial) AS apertura, 0 AS cancelacion,
	count(*) AS qApertura , 0 AS qCancelacion
    FROM #Aperturas
    GROUP BY fecha,	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal
    UNION ALL
    SELECT fecha,
	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal,
	0 AS apertura, SUM(montoinicial) AS cancelacion,
	0 AS qApertura , count(*) AS qCancelacion
    FROM #Cancelaciones
    GROUP BY fecha,	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal
)

SELECT 
    fecha,
	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal,
    SUM(apertura) AS apertura,
    SUM(cancelacion) AS cancelacion,
	SUM(qApertura) AS qApertura,
	SUM(qCancelacion) AS qCancelacion
	into #consolidado
FROM DatosCombinados
GROUP BY fecha,	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal
ORDER BY fecha asc;



DROP TABLE IF EXISTS #CONSOLIDADO2
select M.* ,
isnull(iif(M.Moneda='Dólares',(Apertura*TCD.promedio),Apertura),0) AS AperturaTCD,
isnull(iif(M.Moneda='Dólares',(Apertura*TCM.promedio),Apertura),0) AS AperturaTCM,
isnull(iif(M.Moneda='Dólares',(Apertura*TCA.promedio),Apertura),0) AS AperturaTCA,
isnull(qApertura,0)qApertura,
isnull(iif(M.Moneda='Dólares',(Cancelacion*TCD.promedio),Cancelacion),0) AS CancelacionTCD,
isnull(iif(M.Moneda='Dólares',(Cancelacion*TCM.promedio),Cancelacion),0) AS CancelacionTCM,
isnull(iif(M.Moneda='Dólares',(Cancelacion*TCA.promedio),Cancelacion),0) AS CancelacionTCA,
isnull(qCancelacion,0)qCancelacion
INTO #CONSOLIDADO2
from 
#MATRIZ M 
LEFT JOIN #CONSOLIDADO D 
ON M.fecha=D.Fecha AND M.Producto=D.Producto AND M.Moneda=D.Moneda --Estado,CancelacionAnticipada,
AND M.Agencia=D.Agencia AND M.PlazoDias=D.PlazoDias AND M.Canal=D.Canal 

LEFT JOIN DW_XTIPOCAMBIO TCD on tcd.fecha = D.fecha and tcd.codigoTipoCambio = 3 -- tipo cambio diario

LEFT JOIN (-- tipo cambio mensual
        SELECT 
		periodo = left(FECHA,7), 
		Fecha, 
		N = ROW_NUMBER() over(partition by left(FECHA,7) order by fecha desc), 
		Promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3 AND FECHA IN ( SELECT DISTINCT FECHA FROM #calendario )
    ) TCM ON TCM.periodo = LEFT(D.fecha,7) and TCM.N = 1

LEFT JOIN (-- tipo cambio anual
        SELECT 
		Periodo1 = left(FECHA,4), 
		Periodo2 = YEAR(FECHA)+1, 
		Fecha, 
		N = ROW_NUMBER() over(partition by left(FECHA,4) order by fecha desc), 
		Promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3
    ) TCA ON TCA.periodo2 = LEFT(D.fecha,4) and TCA.n = 1
where M.fecha>='2023-01-01'
order by fecha asc


----SCTOCK 2022
DROP TABLE  IF EXISTS #stockinicial
;with cte as(
SELECT cs.* ,
		isnull(iif(CS.Moneda='Dólares',(SaldoImporte1*TCD.promedio),SaldoImporte1),0) AS SaldoTCD,
		isnull(iif(CS.Moneda='Dólares',(SaldoImporte1*TCM.promedio),SaldoImporte1),0) AS SaldoTCM,
		isnull(iif(CS.Moneda='Dólares',(SaldoImporte1*TCA.promedio),SaldoImporte1),0) AS SaldoTCA,
		1 AS Q
FROM  #DW_CUENTASALDOS  CS
LEFT JOIN DW_XTIPOCAMBIO TCD on tcd.fecha = CS.dw_fechacarga and tcd.codigoTipoCambio = 3 -- tipo cambio diario

LEFT JOIN (-- tipo cambio mensual
        SELECT 
		periodo = left(FECHA,7), 
		Fecha, 
		N = ROW_NUMBER() over(partition by left(FECHA,7) order by fecha desc), 
		Promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3 AND FECHA IN ( SELECT DISTINCT FECHA FROM #calendario )
    ) TCM ON TCM.periodo = LEFT(CS.dw_fechacarga,7) and TCM.N = 1

LEFT JOIN (-- tipo cambio anual
        SELECT 
		Periodo1 = left(FECHA,4), 
		Periodo2 = YEAR(FECHA)+1, 
		Fecha, 
		N = ROW_NUMBER() over(partition by left(FECHA,4) order by fecha desc), 
		Promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3
    ) TCA ON TCA.periodo2 = LEFT(CS.dw_fechacarga,4) and TCA.n = 1
where CS.dw_fechacarga='2022-12-31'
)select dw_fechacarga AS Fecha,
	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal, AperturaTCD = sum(SaldoTCD), AperturaTCM = sum(SaldoTCM), AperturaTCA = sum(SaldoTCA) ,qApertura=sum(Q)
into #stockinicial
from cte
group by dw_fechacarga,Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal



INSERT INTO #CONSOLIDADO2
SELECT 
Fecha,Producto,Moneda,Agencia,PlazoDias,Canal,AperturaTCD,AperturaTCM,AperturaTCA,qApertura,
0 AS CancelacionTCD,
0 AS CancelacionTCM,
0 AS CancelacionTCA,
0 AS qCancelacion
FROM #stockinicial




;
WITH DatosOrdenados AS (
    SELECT 
        fecha,
		Producto,Moneda,--Estado,CancelacionAnticipada,
		Agencia,PlazoDias,Canal,
        AperturaTCD,
        CancelacionTCD,
        LAG(StockTCD, 1, 0) OVER (PARTITION BY 
		Producto,Moneda,--Estado,CancelacionAnticipada,
		Agencia,PlazoDias,Canal ORDER BY fecha) AS stock_anteriorTCD,
		AperturaTCM,
        CancelacionTCM,
        LAG(StockTCM, 1, 0) OVER (PARTITION BY 
		Producto,Moneda,--Estado,CancelacionAnticipada,
		Agencia,PlazoDias,Canal ORDER BY fecha) AS stock_anteriorTCM,
		AperturaTCA,
        CancelacionTCA,
        LAG(StockTCM, 1, 0) OVER (PARTITION BY 
		Producto,Moneda,--Estado,CancelacionAnticipada,
		Agencia,PlazoDias,Canal ORDER BY fecha) AS stock_anteriorTCA
    FROM (
        SELECT 
			fecha,
			Producto,Moneda,--Estado,CancelacionAnticipada,
			Agencia,PlazoDias,Canal,
            AperturaTCD,
            CancelacionTCD,
            0 + SUM(AperturaTCD - CancelacionTCD) OVER (PARTITION BY  
			Producto,Moneda,--Estado,CancelacionAnticipada,
			Agencia,PlazoDias,Canal ORDER BY fecha) AS StockTCD,
		    AperturaTCM,
            CancelacionTCM,
            0 + SUM(AperturaTCM - CancelacionTCM) OVER (PARTITION BY  
			Producto,Moneda,--Estado,CancelacionAnticipada,
			Agencia,PlazoDias,Canal ORDER BY fecha) AS StockTCM,
			AperturaTCA,
            CancelacionTCA,
            0 + SUM(AperturaTCA - CancelacionTCA) OVER (PARTITION BY  
			Producto,Moneda,--Estado,CancelacionAnticipada,
			Agencia,PlazoDias,Canal ORDER BY fecha) AS StockTCA
        FROM #CONSOLIDADO2
    ) AS DatosCalculados
)

SELECT 
    fecha,
	Producto,Moneda,--Estado,CancelacionAnticipada,
	Agencia,PlazoDias,Canal,
    AperturaTCD,
    CancelacionTCD,
    stock_anteriorTCD + AperturaTCD - CancelacionTCD AS StockTCD,
	AperturaTCM,
    CancelacionTCM,
    stock_anteriorTCM + AperturaTCM - CancelacionTCM AS StockTCM,
	AperturaTCA,
    CancelacionTCA,
    stock_anteriorTCA + AperturaTCA - CancelacionTCA AS StockTCA
FROM DatosOrdenados
ORDER BY Fecha, Producto, Moneda, Agencia, PlazoDias, Canal;










--Select  
--    Fecha,
--	Producto,Moneda,--Estado,CancelacionAnticipada,
--	Agencia,PlazoDias,Canal,
--    AperturaTCD, CancelacionTCD,
--    SUM(AperturaTCD - CancelacionTCD) OVER (
--                                                PARTITION BY 
--                                                            Producto
--														   , Moneda
--														   , Agencia
--														   , PlazoDias
--														   , Canal
--                                                ORDER BY Fecha 
--                                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--                                              ) AS StockCD
----    , APERTURA_TCM_MONTO, CANCELACION_TCM_MONTO
----    , SUM(APERTURA_TCM_MONTO - CANCELACION_TCM_MONTO) OVER (
----                                                --PARTITION BY moneda
----                                                --           , PRODUCTO
----                                                --           --, ESTADO
----                                                --           , CANCELACIONANTICIPADA
----                                                --           , AGENCIA
----                                                --           , PLAZODIAS
----                                                --           , CANAL 
----                                                ORDER BY Fecha 
----                                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
----                                              ) AS STOCK_TCM
----    , APERTURA_TCA_MONTO, CANCELACION_TCA_MONTO
----    , SUM(APERTURA_TCA_MONTO - CANCELACION_TCA_MONTO) OVER (
----                                                --PARTITION BY moneda
----                                                --           , PRODUCTO
----                                                --           --, ESTADO
----                                                --           , CANCELACIONANTICIPADA
----                                                --           , AGENCIA
----                                                --           , PLAZODIAS
----                                                --           , CANAL 
----                                                ORDER BY Fecha 
----                                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
----                                              ) AS STOCK_TCA
----    , QAPERTURAS, Qcancelaciones
----    , SUM(QAPERTURAS - Qcancelaciones) OVER (
----                                                --PARTITION BY moneda
----                                                --           , PRODUCTO
----                                                --           --, ESTADO
----                                                --           , CANCELACIONANTICIPADA
----                                                --           , AGENCIA
----                                                --           , PLAZODIAS
----                                                --           , CANAL 
----                                                ORDER BY Fecha 
----                                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
----                                              ) AS STOCK_Q
----    --, Amonto_mensual
----    --, Cmonto_mensual
----    --, Amonto_anual
----    --, Cmonto_anual
----    --, Qaperturas
----    --, Qcancelaciones
----INTO DWCOOPAC.DBO.WT_STOCK_DPF_GENERAL
--from #CONSOLIDADO2
--order by 
--    --  moneda
--    --, PRODUCTO
--    --, ESTADO
--    --, CANCELACIONANTICIPADA
--    --, AGENCIA
--    --, PLAZODIAS
--    --, CANAL
--     fecha asc