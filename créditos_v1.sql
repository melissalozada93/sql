USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dashs_creditos]    Script Date: 28/02/2024 09:58:38 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_dashs_creditos]
as
set nocount on --
set xact_abort on
	begin transaction
	begin try

        --select cast(getdate()-23 as date)
        --declare @fecha varchar(7) = left(cast((SELECT FECHA FROM ST_FECHAMAESTRA WHERE ESTADO = 1) as date),7)

		DECLARE @FECHA DATE = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE ESTADO = 1)
		
        DECLARE @tipocambio float = (select promedio from DW_XTIPOCAMBIO where fecha = @FECHA AND codigoTipoCambio = 3)

        DROP TABLE IF EXISTS #WT_PERSONA
        select * 
        INTO #WT_PERSONA
        from DWCOOPAC.DBO.WT_PERSONA nolock where dw_fechaCarga = @fecha

        DROP TABLE IF EXISTS #SOLICITUDPRESTAMO
        SELECT DW_FECHACARGA,CODIGOSOLICITUD, AGENCIADESCRI, TASAINTERES
        INTO #SOLICITUDPRESTAMO
        FROM DW_SOLICITUDPRESTAMO nolock where dw_fechaCarga = @fecha

        DROP TABLE IF EXISTS #DATOSSOCIO
        SELECT DW_FECHACARGA,CODIGOPERSONA,CODIGOSOCIO, CODIGOSECTORISTA 
        INTO #DATOSSOCIO
        FROM DW_DATOSSOCIO nolock where dw_fechaCarga = @fecha

        DROP TABLE IF EXISTS #SECTORISTA
        SELECT 
        DISTINCT P.NOMBRECOMPLETO AS NOMSOCIO -- CODPERSONA
        , DS.CODIGOSOCIO
        , DS.CODIGOSECTORISTA
        , P2.NOMBRECORTO AS NOMSECTORISTA
        INTO #SECTORISTA
        FROM #DATOSSOCIO DS
        LEFT JOIN #WT_PERSONA P 
        ON P.codioPersona = DS.CODIGOPERSONA
        LEFT JOIN #WT_PERSONA P2
        ON P2.codioPersona = DS.CODIGOSECTORISTA 



        DROP TABLE IF EXISTS #PRESTAMOHISTORIA
        SELECT dw_fechaCarga, CODIGOSOLICITUD, FECHA_CANCELACION 
        INTO #PRESTAMOHISTORIA
        FROM DW_PRESTAMOHISTORIA nolock where dw_fechaCarga = @fecha

        DROP TABLE IF EXISTS #TIPOCAMBIO
        SELECT fecha, PROMEDIO 
        INTO #TIPOCAMBIO
        FROM DW_XTIPOCAMBIO nolock WHERE codigoTipoCambio = 3 --AND LEFT(fecha,7) = @fecha

        DROP TABLE IF EXISTS #PRESTAMOANEXO
        SELECT *
		INTO #PRESTAMOANEXO 
		FROM DW_PRESTAMOANEXO  nolock where LEFT(dw_fechaCarga,7) = LEFT(@fecha,7)
	    AND left(CODIGOSOLICITUD,4)NOT IN ('0001')
        
		
		---38411



        DROP TABLE IF EXISTS  #X
        SELECT 
          PERIODO = LEFT(P.dw_fechaCarga,7)
        , P.DW_FECHACARGA 
        , p.CODIGOSOLICITUD
        , ESTADO = dbo.ufn_syst900(25,p.ESTADO)
        , p.CODIGOSOCIO
        , p.NOMBREPERSONA
        , TIPOPRODUCTO = case when p.PRODUCTOCORTODESCRI in ('PCL','PLC','PLR','PDD','DSC','PLN') then 'LINEA' ELSE 'CREDITO' END
        , TIPO = p.tipo
        , PRODUCTO = p.PRODUCTOCORTODESCRI
        , CLASIFICACION = CASE WHEN p.dw_clasificacion IS NULL THEN '-' ELSE p.dw_clasificacion END
        , MONEDA = dbo.ufn_syst900(22,p.MONEDA)
        , WTP.tipoPersona
        , AGENCIASOLICITUD = S.AGENCIADESCRI
        , SECTORISTA = CASE WHEN SEC.NOMSECTORISTA IS NULL THEN '-' ELSE SEC.NOMSECTORISTA END
        , FECHACARTA = CASE WHEN p.FECHACARTA IS NULL THEN '-' ELSE CONVERT(varchar,p.FECHACARTA) END
        , FECHADESEMBOLSO = p.FECHAPRESTAMO
        , VALOR_PRESTAMO = case when p.ESTADO = 1 then CASE 
                                                            WHEN p.fechacarta > fc.FECHA_CANCELACION THEN 'ANTICIPADO'
                                                            WHEN p.fechacarta < fc.FECHA_CANCELACION THEN 'REPROGRAMADO'
                                                            WHEN p.fechacarta = fc.FECHA_CANCELACION THEN 'NORMAL'
                                                            ELSE '-'
                                                        END
                                ELSE '-'
                            END
        , FECHACANCELACION = CASE WHEN FC.FECHA_CANCELACION IS NULL THEN '-' ELSE CONVERT(varchar,FC.FECHA_CANCELACION) END
        , DIASPAGO = CASE WHEN FC.FECHA_CANCELACION IS NULL THEN '-' ELSE CONVERT(varchar,DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION)) END
        , RANGODIASPAGO = CASE
                                WHEN FC.FECHA_CANCELACION is null THEN '-'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 0 AND 90 THEN '1.[ 3 MESES ]'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 1 AND 1 THEN '2.[ 6 MESES ]'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 1 AND 1 THEN '3.[ 12 MESES ]'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 1 AND 1 THEN '4.[ 18 MESES ]'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 1 AND 1 THEN '5.[ 36 MESES ]'
                                WHEN DATEDIFF(day, P.FECHAPRESTAMO, FC.FECHA_CANCELACION) BETWEEN 1 AND 1 THEN '6.[ + 36 MESES ]'
                                ELSE '-'
                            END
        , RANGODIASVENCIMIENTO = CASE 
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 0 AND 7 THEN '1.[ 0 a 7 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 8 AND 14 THEN '2.[ 8 a 14 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 15 AND 21 THEN '3.[ 15 a 21 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 22 AND 30 THEN '4.[ 22 a 30 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 31 AND 60 THEN '5.[ 31 a 60 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 61 AND 90 THEN '6.[ 61 a 90 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 91 AND 120 THEN '7.[ 91 a 120 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 121 AND 150 THEN '8.[ 121 a 150 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 151 AND 180 THEN '9.[ 151 a 180 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 181 AND 210 THEN '10.[ 181 a 210 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 211 AND 270 THEN '11.[ 211 a 270 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 271 AND 300 THEN '12.[ 271 a 300 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 301 AND 360 THEN '13.[ 301 a 360 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 361 AND 720 THEN '14.[ 361 a 720 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 721 AND 1080 THEN '15.[ 721 a 1080 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 1081 AND 1440 THEN '16.[ 1081 a 1440 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 1441 AND 1800 THEN '17.[ 1441 a 1800 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 1801 AND 3600 THEN '18.[ 1801 a 3600 ]'
                                WHEN DATEDIFF(DD,P.dw_fechaCarga,P.FECHACARTA) BETWEEN 3601 AND 7200 THEN '19.[ 3601 a 7200 ]'
                                else 'VENCIDO'
                            END
                      
        , RANGOMONTODESEMBOLSO = CASE -- EN ABSE A LA SOLARIZACION
                                WHEN case when tc.promedio is null then  p.MONTOPRESTAMO*@tipocambio else p.MONTOPRESTAMO*TC.promedio end BETWEEN 0 AND 500000 THEN '1.- [0 - 500,000 ]'
                                WHEN case when tc.promedio is null then  p.MONTOPRESTAMO*@tipocambio else p.MONTOPRESTAMO*TC.promedio end BETWEEN 500001 AND 5500000 THEN '2.- [500,001 - 5,500,000 ]'
                                WHEN case when tc.promedio is null then  p.MONTOPRESTAMO*@tipocambio else p.MONTOPRESTAMO*TC.promedio end >= 10001 THEN '3.- [5,500,001 - MAS ]'
                            END
        , TIPOCAMBIO = Case when tc.promedio is null then  @tipocambio else TC.promedio end
        , MONTODESEMBOLSO = CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END
        , MONTODESEMBOLSO_SOLES = case 
                                    when p.moneda = 1 then p.MONTOPRESTAMO 
                                    when p.moneda = 2 then (CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END)*TC.promedio--(case when tc.promedio is null then p.MONTOPRESTAMO*@tipocambio else p.MONTOPRESTAMO*TC.promedio end)
                                    end 

        , SALDOPRESTAMO = CASE WHEN P.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END
        , SALDOPRESTAMO_SOLES = case 
                                    when p.moneda = 1 then p.dw_saldoPrestamo 
                                    when p.moneda = 2 then (CASE WHEN P.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END)*TC.promedio 
                                                            --case 
                                                            --    when tc.promedio is null then p.dw_saldoPrestamo*@tipocambio 
                                                            --    else p.dw_saldoPrestamo*TC.promedio 
                                                            --end
                                end
        , MORA = case when p.DW_MORA is null then 0 else p.DW_MORA end
        , MORA_SOLES =  case 
                            when p.moneda = 1 then (case when p.DW_MORA is null then 0 else p.DW_MORA end)
                            when p.moneda = 2 then (case when p.DW_MORA is null then 0 else p.DW_MORA end)*TC.promedio 
                                                    --case 
                                                    --    when tc.promedio is null then (case when p.DW_MORA is null then 0 else p.DW_MORA end)*@tipocambio 
                                                    --    else (case when p.DW_MORA is null then 0 else p.DW_MORA end)*TC.promedio 
                                                    --end
                        end

        , MONTOATRASO = case when p.dw_montoAtraso  IS NULL THEN 0 ELSE p.dw_montoAtraso END
        , MONTOATRASO_SOLES =  case 
                                    when p.moneda = 1 then p.dw_montoAtraso 
                                    when p.moneda = 2 then (case when p.dw_montoAtraso  IS NULL THEN 0 ELSE p.dw_montoAtraso END)*TC.promedio 
                                                            --case 
                                                            --    when tc.promedio is null then p.dw_montoAtraso*@tipocambio 
                                                            --    else p.dw_montoAtraso*TC.promedio 
                                                            --end
                                end

        , ISALBIN = case when p.dw_isalbin is null then 0 else p.dw_isalbin end
        , ISALBIN_SOLES =  case 
                                when p.moneda = 1 then (case when p.dw_isalbin is null then 0 else p.dw_isalbin end)
                                when p.moneda = 2 then (case when p.dw_isalbin is null then 0 else p.dw_isalbin end)*TC.promedio 
                                                        --case 
                                                        --    when tc.promedio is null then (case when p.dw_isalbin is null then 0 else p.dw_isalbin end)*@tipocambio 
                                                        --    else (case when p.dw_isalbin is null then 0 else p.dw_isalbin end)*TC.promedio 
                                                        --end
                            end 

        , INTERES = case when p.dw_interes IS null then 0 else p.dw_interes end
        , INTERES_SOLES = case 
                                when p.moneda = 1 then (case when p.dw_interes IS null then 0 else p.dw_interes end)
                                when p.moneda = 2 then (case when p.dw_interes IS null then 0 else p.dw_interes end)*TC.promedio
                                                        --case 
                                                        --    when tc.promedio is null then (case when p.dw_interes IS null then 0 else p.dw_interes end)*@tipocambio 
                                                        --    else (case when p.dw_interes IS null then 0 else p.dw_interes end)*TC.promedio 
                                                        --end
                            end 

        , PAGO = ((CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END) - (CASE WHEN p.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END))
        , PAGO_SOLES =  case 
                                when p.moneda = 1 then ((CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END) - (CASE WHEN p.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END))
                                when p.moneda = 2 then ((CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END) - (CASE WHEN p.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END))*TC.promedio 
                                                        --case 
                                                        --    when tc.promedio is null then ((CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END) - (CASE WHEN p.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END))*@tipocambio 
                                                        --    else ((CASE WHEN P.MONTOPRESTAMO IS NULL THEN 0 ELSE P.MONTOPRESTAMO END) - (CASE WHEN p.dw_saldoPrestamo IS NULL THEN 0 ELSE P.dw_saldoPrestamo END))*TC.promedio 
                                                        --end
                            end 

        , DIASATRASO = p.dw_diasAtraso
        , RANGODIASATRASO = CASE 
                                WHEN p.dw_diasAtraso BETWEEN 0 AND 30 THEN '1.[ 0 - 1 MES ]'
                                WHEN p.dw_diasAtraso BETWEEN 31 AND 90 THEN '2.[ 1 - 3 MESES ]'
                                WHEN p.dw_diasAtraso BETWEEN 91 AND 180 THEN '3.[ 3 - 6 MESES ]'
                                WHEN p.dw_diasAtraso BETWEEN 181 AND 360 THEN '4.[ 6 - 12 MESES ]'
                                WHEN p.dw_diasAtraso >= 361 THEN '5.[ + 12 MESES ]'
                                ELSE 'ALGO SALIO MAL'
                            END
        , TASAINTERESACTUAL = case when p.TASAINTERES IS null then 0 else p.TASAINTERES end
        , TASAINTERESINICIAL = S.TASAINTERES
        , ANIOCARTA = CASE WHEN p.FECHACARTA IS NULL THEN '-' else LEFT(p.FECHACARTA,7) END --CASE WHEN p.FECHACARTA IS NULL THEN '-' WHEN YEAR(P.FECHACARTA) = LEFT(@FECHA,4) THEN LEFT(p.FECHACARTA,7) ELSE '-' END
		, FINMESDESEMBOLSO = IIF(p.FECHAPRESTAMO = EOMONTH(p.FECHAPRESTAMO), 'SI', 'NO') 
		, ANIODESEMBOLSO = YEAR(p.FECHAPRESTAMO)
		, FECHACARTA2 = p.FECHACARTA 
		, FECHACANCELACION2 = FC.FECHA_CANCELACION 
		, FECHAACTUALIZACION=@FECHA
        INTO #X
        FROM #PRESTAMOANEXO p--324294
        left join #WT_PERSONA WTP ON p.CODIGOSOCIO = WTP.CIP
        LEFT JOIN #SOLICITUDPRESTAMO S ON S.CODIGOSOLICITUD = p.codigosolicitud
        LEFT JOIN #SECTORISTA SEC ON SEC.CODIGOSOCIO = p.CODIGOSOCIO
        LEFT JOIN #PRESTAMOHISTORIA FC ON FC.CODIGOSOLICITUD = p.codigosolicitud --AND FC.FECHA_CANCELACION >= p.dw_fechaCarga
        LEFT JOIN #TIPOCAMBIO TC ON TC.fecha = p.dw_fechaCarga
        LEFT JOIN dimtiempo DT ON DT.Fecha = p.FECHACARTA
        --where LEFT(p.dw_fechaCarga,7) = @fecha

      --  delete from #x where TIPOPRODUCTO = 'LINEA'




        -- CAMBIAR A ELIMINAR POR PERIODO
        TRUNCATE TABLE DWCOOPAC.DBO.WT_REPORTECREDITOS
        --IF OBJECT_ID('DWCOOPAC.DBO.WT_REPORTECREDITOS') IS NOT NULL drop table DWCOOPAC.DBO.WT_REPORTECREDITOS
        --SELECT * INTO DWCOOPAC.DBO.WT_REPORTECREDITOS FROM #X --where ESTADO = 'cancelado'

		
        INSERT INTO DWCOOPAC.DBO.WT_REPORTECREDITOS
        SELECT * 
		FROM #X



        DROP TABLE #WT_PERSONA
        DROP TABLE #SOLICITUDPRESTAMO
        DROP TABLE #DATOSSOCIO
        DROP TABLE #SECTORISTA
        DROP TABLE #PRESTAMOHISTORIA
        DROP TABLE #TIPOCAMBIO
        DROP TABLE #X

        ;WITH CTE_PAH
        AS (
     --   IF OBJECT_ID('tempdb..#x') IS NOT NULL drop table #x
	        SELECT
	        ROW_NUMBER() OVER(PARTITION BY codigosolicitud, CAST(dw_fechaCarga AS DATE) ORDER BY codigosolicitud, CAST(dw_fechaCarga AS DATE)) AS N
	        , *
         --   into #x
	        FROM DWCOOPAC.DBO.WT_REPORTECREDITOS --WHERE codigosolicitud = '2020-0181169'
        )
        DELETE FROM CTE_PAH WHERE N > 1


        
        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard Creditos',null, 'OK'
        --select * from DWCOOPACIFICO.dbo.WT_RUNOFF
     
	end try
	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'ERROR en la ejecucion del Dashboard Creditos', @error_message, 'ERROR'

	end catch 
	if @@trancount > 0
		commit transaction		
return 0





