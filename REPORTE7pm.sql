--SELECT *
--FROM wt_reporte9

DROP TABLE IF EXISTS #R133;
WITH CTE AS (
       SELECT *
       FROM (
             SELECT Recaudación = 'Total', MONEDA, total
             FROM wt_reporte133
             where condicion in ('Caja', 'Desembolso')
             and tipomovimiento in ('Amortizacion','Nota Abono')
             and estado_pago = 'ACTIVO'
       ) AS R6
       PIVOT (
             SUM(total)
             FOR MONEDA IN ([DOLARES],[SOLES])
       ) AS PivotTable
)
SELECT *
INTO #R133
FROM CTE


DROP TABLE IF EXISTS #R9_PRE;
SELECT [Depositos a Plazo] = 'Total', MONEDA, cast(replace(montoinicial,',','') as float) as montoinicial, 1 AS AUX
INTO #R9_PRE
FROM wt_reporte9
UNION
SELECT [Depositos a Plazo] = 'TEA PROM %', MONEDA, cast(replace(tasaintanualapert,',','') as float) as tasaintanualapert, 2 AS AUX
FROM wt_reporte9


DROP TABLE IF EXISTS #R9;
WITH CTE AS (
       SELECT *
       FROM (
             SELECT [Depositos a Plazo] = 'Nuevo', MONEDA, dinerofresco, 1 AS ORDEN
             FROM wt_reporte9
       ) AS R9
       PIVOT (
             SUM(dinerofresco)
             FOR MONEDA IN ([D],[S])
       ) AS PivotTable

       union

       SELECT *
       FROM (
             SELECT [Depositos a Plazo] = 'Canc. Anticipada', MONEDA, renovacion, 2 AS ORDEN
             FROM wt_reporte9
       ) AS R9
       PIVOT (
             SUM(renovacion)
             FOR MONEDA IN ([D],[S])
       ) AS PivotTable

       union

       SELECT *
       FROM (
             SELECT [Depositos a Plazo], MONEDA, montoinicial, 3 AS ORDEN
             FROM #R9_PRE
             WHERE AUX = 1
       ) AS R9
       PIVOT (
             SUM(montoinicial)
             FOR MONEDA IN ([D],[S])
       ) AS PivotTable

       union

       SELECT *
       FROM (
             SELECT [Depositos a Plazo], MONEDA, montoinicial/*tasaintanualapert*/, 4 AS ORDEN
             FROM #R9_PRE
             WHERE AUX = 2
       ) AS R9
       PIVOT (
             AVG(montoinicial)
             FOR MONEDA IN ([D],[S])
       ) AS PivotTable
)
SELECT *
INTO #R9
FROM CTE




-- cuadro inicial
select Recaudación, DOLARES, SOLES, Consolidado = (SOLES+(DOLARES*(SELECT PROMEDIO FROM DW_XTIPOCAMBIO WHERE codigoTipoCambio = 3 AND FECHA = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE ESTADO = 1))))
from #R133

-- PARTE 2
select [Depositos a Plazo],D,S,
CONSOLIDADO = CASE 
                                 WHEN [Depositos a Plazo] = 'TEA PROM %' THEN NULL
                                 ELSE (S+(D*(SELECT PROMEDIO FROM DW_XTIPOCAMBIO WHERE codigoTipoCambio = 3 AND FECHA = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE ESTADO = 1))))
                      END
from #R9
ORDER BY ORDEN ASC


--select * from wt_reporte6
--select distinct rango_hora from wt_reporte6 order by rango_hora desc

