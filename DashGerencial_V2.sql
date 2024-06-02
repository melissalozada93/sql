DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)

--================================================================================================================================================

--Indicador X: nombre del indicador x

IF OBJECT_ID('tempdb..#Desembolsos') IS NOT NULL drop table #Desembolsos
select 
      p.FECHADESEMBOLSO
    , p.CODIGOSOLICITUD
    , p.dw_producto as PRODUCTO
    , sp.TASAADICIONAL as TASA
    , p.MONTODESEMBOLSO, MONEDA = P.DW_MONEDADESCRI
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


DROP TABLE IF EXISTS DW_INDICADORES_GERENCIA
select *,@fecha[FechaActualizacion] 
INTO DW_INDICADORES_GERENCIA
from #Tabla_gerencia


SELECT * FROM DW_INDICADORES_GERENCIA