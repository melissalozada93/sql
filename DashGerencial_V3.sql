DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)

--================================================================================================================================================

--Indicador X: nombre del indicador x

IF OBJECT_ID('tempdb..#Desembolsos') IS NOT NULL drop table #Desembolsos
select 
      p.FECHADESEMBOLSO
    , p.CODIGOSOLICITUD
    , p.dw_producto as PRODUCTO
    , sp.TASAADICIONAL as TASA
    , p.MONTODESEMBOLSO
    , MONEDA = P.DW_MONEDADESCRI
    , monto_por_tasa = p.MONTODESEMBOLSO*sp.TASAADICIONAL
into #Desembolsos
from DW_PRESTAMO p
inner join DW_SOLICITUDPRESTAMO sp  
on  p.CODIGOSOLICITUD = sp.codigosolicitud 
and p.DW_FECHACARGA=sp.DW_FECHACARGA
where p.dw_fechacarga= @fecha
 
 -- agregar ingrementos de lineas no olvidar
drop table if exists #acumulado
select 
      FECHADESEMBOLSO as Fecha
    , MONEDA
    , sum(MONTODESEMBOLSO) AS SUMA
    , count(*) as CANTIDAD 
    , monto_por_tasa = sum(monto_por_tasa)
into #acumulado
from #Desembolsos
where FECHADESEMBOLSO >= '2022-01-01'
group by FECHADESEMBOLSO,MONEDA
order by FECHADESEMBOLSO

--================================================================================================================================================

--Indicador y: nombre del indicador y

DROP TABLE IF EXISTS #tablita
SELECT 
      p.dw_codigoSocio
	, p.DW_MONEDADESCRI as moneda
    , ds.fechaIngresoCoop
    , p.codigoSolicitud
    , p.dw_monedaDescri
    , p.montoDesembolso
    , p.fechaDesembolso
    , ds.fechaMaxParaDesembolsar
    , diffFechas = DATEDIFF(DAY,p.fechaDesembolso,ds.fechaMaxParaDesembolsar)
    , socioNuevo = CASE 
                       WHEN DATEDIFF(DAY,p.fechaDesembolso,ds.fechaMaxParaDesembolsar) >= 0 THEN 'Si'
                       ELSE 'No'
                   END
INTO #tablita
FROM dw_prestamo p
LEFT JOIN (
    SELECT DISTINCT 
          codigoSocio
        , fechaIngresoCoop
        , fechaMaxParaDesembolsar = DATEADD(MONTH,6,FechaIngresoCoop) 
    FROM DW_DATOSSOCIO 
    where dw_fechaCarga = @fecha
) ds on ds.codigoSocio = p.dw_codigoSocio

WHERE p.dw_fechacarga = @fecha



DROP TABLE IF EXISTS #Nuevos
SELECT 
     fechaDesembolso, moneda
   , desembolsoNuevos = SUM(montoDesembolso)
INTO #Nuevos
FROM #tablita
WHERE socioNuevo = 'Si'
AND fechaDesembolso >= '2022-01-01'
GROUP BY 
     fechaDesembolso,moneda

	 

DROP TABLE IF EXISTS #Todos
SELECT 
     fechaDesembolso, moneda
   , desembolsoTotal = SUM(montoDesembolso)
INTO #Todos
FROM #tablita
WHERE fechaDesembolso >= '2022-01-01'
GROUP BY 
     fechaDesembolso, moneda

DROP TABLE #tablita

--================================================================================================================================================
-- Indicador Liquidez (pasivas): 
DROP TABLE IF EXISTS #CALENDARIOTOP20
SELECT 
      FECHA
    , MONEDA
INTO #CALENDARIOTOP20
FROM dimtiempo 
CROSS JOIN (VALUES ('Dólares'), ('Soles')) AS Monedas(MONEDA)
WHERE (DiaNegativo = -1 AND FECHA BETWEEN '2023-01-01' AND CAST(GETDATE()-1 AS DATE))
   OR (FECHA = CAST(GETDATE()-1 AS DATE));


DROP TABLE IF EXISTS #BASETOTAL
SELECT 
    R.FECHAAPERTURA
  , R.NROCUENTA 
  , R.MONEDA
  , R.MONTOINICIAL
  , R.MONTOINICIAL_SOLES
  , N = ROW_NUMBER() OVER(PARTITION BY LEFT(FECHAAPERTURA,7), MONEDA ORDER BY MONTOINICIAL DESC)
INTO #BASETOTAL
FROM WT_REPORTEPASIVAS R
WHERE R.FECHA = (SELECT FECHA FROM ST_FECHAMAESTRA)
  AND R.FECHAAPERTURA >= '2023-01-01'

DROP TABLE IF EXISTS #LIQUIDEZ
SELECT 
  CT20.FECHA
, CT20.MONEDA
, T20 = T20.VALOR
, NT20 = NT20.VALOR
, VALOR = T20.VALOR/NT20.VALOR
INTO #LIQUIDEZ
FROM #CALENDARIOTOP20 CT20

LEFT JOIN (
    -- TOP20
    SELECT 
          PERIODO = LEFT(FECHAAPERTURA,7)
        , MONEDA
        , VALOR = SUM(MONTOINICIAL) 
    FROM #BASETOTAL 
    WHERE N <= 20 
    GROUP BY 
          LEFT(FECHAAPERTURA,7)
        , MONEDA
) T20 ON T20.PERIODO = LEFT(CT20.FECHA,7)
     AND T20.MONEDA = CT20.MONEDA

LEFT JOIN (
    -- NO TOP20
    SELECT 
          PERIODO = LEFT(FECHAAPERTURA,7)
        , MONEDA
        , VALOR = SUM(MONTOINICIAL) 
    FROM #BASETOTAL 
    GROUP BY 
          LEFT(FECHAAPERTURA,7)
        , MONEDA
) NT20 ON NT20.PERIODO = LEFT(CT20.FECHA,7)
     AND NT20.MONEDA = CT20.MONEDA

DROP TABLE #BASETOTAL

--================================================================================================================================================
-- Indicador CONCENTRACION DE CARTERA: 

DROP TABLE IF EXISTS #BASETOTALA
SELECT 
    p.FECHADESEMBOLSO
  , p.CODIGOSOLICITUD 
  , MONEDA = p.DW_MONEDADESCRI
  , p.SALDOPRESTAMO
  , ESTADO = P.DW_ESTADODESCRI
  , N = ROW_NUMBER() OVER(PARTITION BY LEFT(p.FECHADESEMBOLSO,7), p.MONEDA ORDER BY  p.SALDOPRESTAMO DESC)
INTO #BASETOTALA
FROM DW_PRESTAMO p
WHERE P.DW_FECHACARGA = (SELECT FECHA FROM ST_FECHAMAESTRA)
  AND P.FECHADESEMBOLSO >= '2023-01-01'
  AND P.DW_ESTADODESCRI = 'Vigente'


DROP TABLE IF EXISTS #ConcentracionCartera
SELECT 
  CT20.FECHA
, CT20.MONEDA
, T20 = T20.VALOR
, NT20 = NT20.VALOR
, VALOR = T20.VALOR/NT20.VALOR
INTO #ConcentracionCartera
FROM #CALENDARIOTOP20 CT20

LEFT JOIN (
    -- TOP20
    SELECT 
          PERIODO = LEFT(FECHADESEMBOLSO,7)
        , MONEDA
        , VALOR = SUM(SALDOPRESTAMO) 
    FROM #BASETOTALA 
    WHERE N <= 20 
    GROUP BY 
          LEFT(FECHADESEMBOLSO,7)
        , MONEDA
) T20 ON T20.PERIODO = LEFT(CT20.FECHA,7)
     AND T20.MONEDA = CT20.MONEDA

LEFT JOIN (
    -- NO TOP20
    SELECT 
          PERIODO = LEFT(FECHADESEMBOLSO,7)
        , MONEDA
        , VALOR = SUM(SALDOPRESTAMO) 
    FROM #BASETOTALA
    GROUP BY 
          LEFT(FECHADESEMBOLSO,7)
        , MONEDA
) NT20 ON NT20.PERIODO = LEFT(CT20.FECHA,7)
     AND NT20.MONEDA = CT20.MONEDA


DROP TABLE #BASETOTALA


--================================================================================================================================================
--Indicador pareto 80/20: 
DROP TABLE IF EXISTS #pareto_desembolsos
; WITH cte AS (
    SELECT 
          fechaDesembolso
        , codigoSolicitud
        , moneda = dw_monedaDescri
        , estado = dw_estadoDescri
        , montoDesembolso
        --, montoDesembolsoAcumulado = SUM(montoDesembolso) OVER(PARTITION BY fechaDesembolso, moneda order by montoDesembolso desc)
        , orden = ROW_NUMBER() OVER(PARTITION BY fechaDesembolso, moneda order by montoDesembolso desc)
    --into #pareto_desembolsos
    FROM DW_PRESTAMO 
    WHERE fechaDesembolso >= '2022-01-01'
      AND DW_FECHACARGA = @fecha
) 
SELECT 
      *
    , montoDesembolsoAcumulado = SUM(montoDesembolso) OVER(PARTITION BY fechaDesembolso, moneda order by orden asc)
into #pareto_desembolsos
FROM cte
--where fechadesembolso = '2022-01-06'

DROP TABLE IF EXISTS #pareto
; with cte2 as (
    SELECT pd.*, pt.totalDesembolso, porcentaje = pd.montoDesembolsoAcumulado/pt.totalDesembolso,
    n = ROW_NUMBER() over(partition by pd.fechadesembolso, pd.moneda order by pd.montoDesembolsoAcumulado/pt.totalDesembolso )
    FROM #pareto_desembolsos pd
    left join (
        SELECT fechaDesembolso, moneda, totalDesembolso = SUM(montoDesembolso) 
        FROM #pareto_desembolsos
        --WHERE fechadesembolso = '2022-01-06'
        GROUP BY fechaDesembolso, moneda
    ) pt ON pt.fechaDesembolso = pd.fechaDesembolso 
        AND pt.moneda = pd.moneda
    --WHERE pd.fechadesembolso = '2022-01-06'
) select *,valor = (montoDesembolsoAcumulado*0.8)/porcentaje, nombre = 'pareto' 
into #pareto
from cte2 where n = 1



--select fechaDesembolso, moneda, totalDesembolso = sum(montoDesembolso) 
--from #pareto_desembolsos
--where fechadesembolso = '2022-01-06'
--group by fechaDesembolso, moneda

--================================================================================================================================================

-- resumen tabla general
IF OBJECT_ID('tempdb..#Tabla_gerencia') IS NOT NULL drop table #Tabla_gerencia
-- indicador x: comentario que indica donde inicia el indicador x
select 
      Fecha, MONEDA
	,'ticket_ponderado' as nombre
    , valor = (sum(SUMA) over(partition by moneda, left(fecha,7) order by fecha asc))/(sum(CANTIDAD) over(partition by moneda, left(fecha,7) order by fecha asc))
into #Tabla_gerencia
from #acumulado
union
select 
      Fecha,MONEDA
	,'monto_por_tasa' as nombre
    , valor =sum(monto_por_tasa) over(partition by moneda, left(fecha,7) order by fecha asc)/(sum(SUMA) over(partition by moneda, left(fecha,7) order by fecha asc))
from #acumulado
union
select 
      Fecha, MONEDA 
	,'p' as nombre
    , valor =0
from #acumulado
union
-- indicador y: comentario que indica donde inicia el indicador y
SELECT 
      n.fechaDesembolso, n.moneda 
    , nombre = 'desembolsosNuevosSocios'
    , valor = CASE WHEN t.desembolsoTotal = 0 THEN 0 ELSE n.desembolsoNuevos/t.desembolsoTotal END
FROM #Nuevos n
left join #Todos t
on  n.fechaDesembolso = t.fechaDesembolso
and n.moneda = t.moneda

union
-- Indicador pareto 80/20
select fechadesembolso, moneda, nombre, valor from #pareto

UNION
-- INDICADOR LIQUIDEZ (PASIVAS)
SELECT FECHA, MONEDA, 'Top20liquidez', valor FROM #LIQUIDEZ

UNION
-- INDICADOR CONCENTRACION DE CARTERA
SELECT FECHA, MONEDA, 'Top20Comercial', VALOR FROM #ConcentracionCartera


DROP TABLE IF EXISTS DW_INDICADORES_GERENCIA
select *,@fecha[FechaActualizacion] 
INTO DW_INDICADORES_GERENCIA
from #Tabla_gerencia




SELECT * FROM DW_INDICADORES_GERENCIA

