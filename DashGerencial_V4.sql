USE [DWCOOPAC]

DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)
-- Elimina la tabla temporal si existe

-- Calendario desde el 2022
	DROP TABLE IF EXISTS #CALENDARIO;
	SELECT DISTINCT fecha 
	INTO #CALENDARIO
	FROM dimtiempo 
	WHERE fecha BETWEEN   DATEADD(YEAR, DATEDIFF(YEAR, 0, @fecha) - 1, 0)   AND @fecha;


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
WHERE ( FECHA BETWEEN '2023-01-01' AND CAST(GETDATE()-1 AS DATE))
   OR (FECHA = CAST(GETDATE()-1 AS DATE));


 DROP TABLE IF EXISTS #TEMP_BASETOTAL_1
 SELECT 
	   FECHA=CS.dw_fechaCarga
     , R.CODIGOSOCIO  
	 , NROCUENTA=CS.NUMEROCUENTA
	 , R.MONEDA
	 , CS.SALDOIMPORTE1
	 INTO #TEMP_BASETOTAL_1
 FROM  DW_CUENTASALDOS CS
 INNER JOIN (SELECT * FROM  WT_REPORTEPASIVAS 
 WHERE FECHA = (SELECT FECHA FROM ST_FECHAMAESTRA) )R
 ON CS.NUMEROCUENTA=R.NROCUENTA


 
DROP TABLE IF EXISTS #TEMP_BASETOTAL_2
SELECT 
    FECHA
  , CODIGOSOCIO 
  , MONEDA 
  , SUM(SALDOIMPORTE1)MONTOINICIAL
INTO #TEMP_BASETOTAL_2
FROM #TEMP_BASETOTAL_1
GROUP BY 
    FECHA
  , CODIGOSOCIO 
  , MONEDA



DROP TABLE IF EXISTS #BASETOTAL
SELECT *
  , N = ROW_NUMBER() OVER(PARTITION BY FECHA, MONEDA ORDER BY  MONTOINICIAL DESC)
INTO #BASETOTAL
FROM #TEMP_BASETOTAL_2

 


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
          FECHA
        , MONEDA
        , VALOR = SUM(MONTOINICIAL) 
    FROM #BASETOTAL 
    WHERE N <= 20 
    GROUP BY 
          FECHA
        , MONEDA
) T20 ON T20.FECHA = CT20.FECHA
     AND T20.MONEDA = CT20.MONEDA

LEFT JOIN (
    -- MONTO INICIAL TOTAL
    SELECT 
          FECHA 
        , MONEDA
        , VALOR = SUM(MONTOINICIAL) 
    FROM #BASETOTAL 
    GROUP BY 
          FECHA
        , MONEDA
) NT20 ON NT20.FECHA = CT20.FECHA
     AND NT20.MONEDA = CT20.MONEDA

DROP TABLE #BASETOTAL



--================================================================================================================================================
-- Indicador CONCENTRACION DE CARTERA: 

DROP TABLE IF EXISTS #TEMP_BASETOTALA
SELECT 
    FECHA=p.DW_FECHACARGA
  , p.CODIGOSOCIO 
  , MONEDA = IIF(MONEDA=2,'Dólares','Soles')
  , SUM(p.SALDOPRESTAMO)SALDOPRESTAMO
INTO #TEMP_BASETOTALA
FROM DW_PRESTAMOANEXOHISTORICO p
WHERE P.DW_FECHACARGA >= '2023-01-01'
  AND P.SITUACIONPRESTAMO= 1
GROUP BY 
    p.DW_FECHACARGA
  , p.CODIGOSOCIO 
  , p.MONEDA



DROP TABLE IF EXISTS #BASETOTALA
SELECT *
  , N = ROW_NUMBER() OVER(PARTITION BY FECHA, MONEDA ORDER BY  SALDOPRESTAMO DESC)
INTO #BASETOTALA
FROM #TEMP_BASETOTALA
WHERE SALDOPRESTAMO>0


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
          FECHA 
        , MONEDA
        , VALOR = SUM(SALDOPRESTAMO) 
    FROM #BASETOTALA 
    WHERE N <= 20 
    GROUP BY 
          FECHA
        , MONEDA
) T20 ON T20.FECHA = CT20.FECHA
     AND T20.MONEDA = CT20.MONEDA

LEFT JOIN (
    -- SALDO PRESTAMO TOTAL
    SELECT 
          FECHA 
        , MONEDA
        , VALOR = SUM(SALDOPRESTAMO) 
    FROM #BASETOTALA
    GROUP BY 
          FECHA
        , MONEDA
) NT20 ON NT20.FECHA = CT20.FECHA
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



--Indicador cartera reprogramada
	--DROP TABLE IF EXISTS #TEMP_CARTERA_REPRO
	--SELECT SBS.FECHA, SBS.MONEDA,
	--[CARTERAREPROGRAMADA]=IIF( MONEDA='Dólares',(SBS.SALDOCAPREPRO/TC.PROMEDIO),SBS.SALDOCAPREPRO),
	--[CARTERATOTAL]=IIF( MONEDA='Dólares',(SBS.SALDO/TC.PROMEDIO),SBS.SALDO)
	--INTO #TEMP_CARTERA_REPRO
	--FROM DW_SBSANEXO6RESULTADO SBS
	--INNER JOIN (SELECT YEAR(FechaCambio)AÑO,MONTH(fechaCambio)MES, PROMEDIO FROM  DW_TIPOCAMBIOAJUSTE ) TC
	--ON YEAR(SBS.FECHA)=TC.AÑO AND MONTH(SBS.FECHA)=TC.MES
	--WHERE FECHA  >= '2022-01-01' 
	

	DROP TABLE IF EXISTS #TEMP_CARTERA_REPRO
	SELECT SBS.FECHA, SBS.MONEDA,
	[CARTERAREPROGRAMADA]=SBS.SALDOCAPREPRO,
	[CARTERATOTAL]=SBS.SALDO
	INTO #TEMP_CARTERA_REPRO
	FROM DW_SBSANEXO6RESULTADO SBS
	WHERE FECHA  >= '2022-01-01'


	DROP TABLE IF EXISTS #CARTERA_REPRO
	SELECT FECHA,MONEDA,
	ROUND((SUM(CARTERAREPROGRAMADA)/1000000),2)[CARTERAREPROGRAMADA],
	ROUND((SUM(CARTERATOTAL)/1000000),2)[CARTERATOTAL], 
	VALOR=(SUM( [CARTERAREPROGRAMADA])/SUM([CARTERATOTAL]))*100 
	INTO #CARTERA_REPRO
	FROM #TEMP_CARTERA_REPRO
	GROUP BY FECHA,MONEDA


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
FROM #Nuevos n------------
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

UNION
-- INDICADOR 
SELECT FECHA,MONEDA, 'Repro',VALOR FROM #CARTERA_REPRO



-- Filtrar moneda y nombres únicos
	DROP TABLE IF EXISTS #FILTROS;
	SELECT DISTINCT 
	moneda,nombre
	INTO #FILTROS
	FROM #Tabla_gerencia

-- Crear matriz combinando fechas y filtros
	DROP TABLE IF EXISTS #MATRIZ;
	SELECT *
	INTO #MATRIZ
	FROM #CALENDARIO C
	CROSS JOIN #FILTROS;


---DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)

DROP TABLE IF EXISTS #WT_INDICADORES_GERENCIA
SELECT A.*, ISNULL(B.valor,0)valor,@fecha[FechaActualizacion] 
INTO #WT_INDICADORES_GERENCIA
FROM #MATRIZ A
LEFT JOIN #Tabla_gerencia B
ON A.Fecha=B.Fecha AND A.MONEDA=B.MONEDA AND A.nombre=B.nombre




Drop table if exists #VariacionesFechas
SELECT *,
    DATEADD(DAY, -1, Fecha)  AS FechaAnt,
	DATEADD(MONTH, -1, Fecha) AS FechaMesAnt,
	EOMONTH(Fecha, -1) AS FechaFinMesAnt
into #VariacionesFechas
FROM 
    #WT_INDICADORES_GERENCIA
order by Fecha




Drop table if exists WT_INDICADORES_GERENCIA
SELECT 
a.Fecha,a.Moneda,a.Nombre,a.valor,
a.FechaAnt,ISNULL(b.valor,0)[Valor ant],
a.FechaMesAnt,ISNULL(c.valor,0)[Valor Mes ant],
a.FechaFinMesAnt,ISNULL(d.valor,0)[Valor Fin Mes ant],
a.FechaActualizacion
INTO WT_INDICADORES_GERENCIA
FROM #VariacionesFechas a
left join #WT_INDICADORES_GERENCIA b
on a.FechaAnt=b.Fecha and a.nombre=b.nombre and a.MONEDA=b.MONEDA 
left join #WT_INDICADORES_GERENCIA c
on a.FechaMesAnt=c.Fecha and a.nombre=c.nombre and a.MONEDA=c.MONEDA 
left join #WT_INDICADORES_GERENCIA d
on a.FechaFinMesAnt=d.Fecha and a.nombre=d.nombre and a.MONEDA=d.MONEDA 

--DROP TABLE IF EXISTS #diaAnterior;





SELECT * FROM WT_INDICADORES_GERENCIA
where nombre='pareto'-- and fecha='2022-01-31'
order by fecha asc

