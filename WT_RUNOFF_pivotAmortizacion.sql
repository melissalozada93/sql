DECLARE @pivot_columns NVARCHAR(MAX);
DECLARE @query NVARCHAR(MAX);
declare @table varchar(50) = 'DWCOOPAC.dbo.WT_RUNOFF_pivotAmortizacion'
			         SET @pivot_columns =  STUFF(
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


        SET @query = '
        IF OBJECT_ID('''+@table+''') IS NOT NULL drop table '+@table+'
        select codigoSolicitud,' +@pivot_columns + '  
        into '+@table+' from 
        (
               select origen , codigosocio,codigoSolicitud,nrocuotasatrasadas,amortizacion, saldo_sbs ,TOTALCAPITALVENCIDO_SBS, left(convert(varchar,cast( fecini as date)),7) AS  mes 
                from DWCOOPAC.dbo.WT_RUNOFF
        ) as q1
        pivot (sum(amortizacion) for mes in (' +@pivot_columns+ ')) as pvt

        '

        EXEC sp_executesql @query;

		--drop table WT_RUNOFF_pivot

select * from WT_RUNOFF_pivotAmortizacion WHERE CODIGOSOLICITUD='2023-2530756'

