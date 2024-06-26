--USE [DWCOOPAC]
--GO
--/****** Object:  StoredProcedure [dbo].[usp_wt_activosretiradosagencia]    Script Date: 26/10/2023 11:50:32 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER procedure [dbo].[usp_wt_activosretiradosagencia]
--as
--set nocount on --
--set xact_abort on
--	begin transaction
--	begin try


--===========================================================================================================================
    IF OBJECT_ID('tempdb..#calendario') IS NOT NULL drop table #calendario
    select fecha 
    into #calendario
    from dimtiempo where DiaNegativo = -1
    union all
    select cast(getdate()-1 as date)

    IF OBJECT_ID('tempdb..#QtyPersonas') IS NOT NULL drop table #QtyPersonas
    select 
          dw_fechaCarga
        , fechaCruce = dateadd(mm,1,cast(dw_fechaCarga as date))
        , AGENCIADESCRI ,TIPOPERSONADESCRI 
        , COUNT(*) as CUENTA
        , cuenta2 = LAG(COUNT(*)) over(partition by AGENCIADESCRI, TIPOPERSONADESCRI order by dw_fechacarga desc)
    into #QtyPersonas
    from VW_PERSONA
    where FECHAINGRESOCOOP is not null
      and CODIGOAGENCIA IN (25,2,4,6,13,5,15,7,1,10,16)
      and DW_FECHACARGA in (select distinct fecha from #calendario )
      --and AGENCIADESCRI = 'san isidro'
    group by dw_fechaCarga, AGENCIADESCRI, TIPOPERSONADESCRI

    update #QtyPersonas set cuenta2 = 0 where cuenta2 is null and left(fechaCruce,7) != left(cast(getdate() as date),7)
    update #QtyPersonas set cuenta2 = cuenta where cuenta2 is null --and left(fechaCruce,7) != left(cast(getdate() as date),7)

    --select distinct dw_fechacarga from VW_PERSONA where dw_fechacarga >= '2023-06-01' order by dw_fechacarga desc
    --select * from #QtyPersonas where dw_fechacarga >= '2023-06-01'
    --order by AGENCIADESCRI, TIPOPERSONADESCRI , dw_fechacarga desc
--===========================================================================================================================
    IF OBJECT_ID('tempdb..#SoliRenuncia') IS NOT NULL drop table #SoliRenuncia
    select distinct 
          sr.codigopersona
        , FECHAAPROBACION2 = EOMONTH(sr.FECHAAPROBACION) 
    into #SoliRenuncia
    from DW_SOLICITUDRENUNCIA  sr
    where sr.FECHAAPROBACION >= '2019-01-01'
      AND sr.ESTADORENUNCIA IN (2,4)
      and sr.CODIGOPERSONA not in ( select distinct codigopersona from dw_datossocio where codigosubgrupo in (14,15,6,5,4)) -- estos son los de compracartera


    --RETIRADOS
    IF OBJECT_ID('tempdb..#QtyRetirados') IS NOT NULL drop table #QtyRetirados
    select 
          p.dw_fechacarga
        , p.AGENCIADESCRI
        , p.TIPOPERSONADESCRI
        , sr.FECHAAPROBACION2
        , COUNT(DISTINCT p.CIP) AS RETIRADOS
    into #QtyRetirados
    from VW_PERSONA p
    inner join #SoliRenuncia sr on sr.codigopersona = p.CODIGOPERSONA
    where p.cip is not null
    AND p.SITUACION=3
    AND P.dw_fechaCarga= CAST(GETDATE()-1 AS DATE)
    AND p.CODIGOAGENCIA IN (25,2,4,6,13,5,15,7,1,10,16)
    group by p.dw_fechacarga, p.AGENCIADESCRI, p.TIPOPERSONADESCRI, sr.FECHAAPROBACION2

--===========================================================================================================================

    IF OBJECT_ID('tempdb..#PreOk') IS NOT NULL drop table #PreOk
    select 
    AGENCIA = P.AGENCIADESCRI
    , P.dw_fechaCarga
    , PERSONERIA = P.TIPOPERSONADESCRI
    , PERIODO = LEFT(P.FECHACRUCE,7)
    , NROSOCIOS = P.CUENTA
    , NUEVOSINSCRITOS = abs(p.cuenta-p.cuenta2) 
    , RETIRADOS = case when r.RETIRADOS is null then 0 else r.retirados end
    , N = ROW_NUMBER() OVER(PARTITION BY P.AGENCIADESCRI, P.TIPOPERSONADESCRI ORDER BY LEFT(P.FECHACRUCE,7) ASC)
    , TERMINAMES = null
    into #PreOk
    from #QtyPersonas p 
    left join (
        SELECT AGENCIADESCRI, TIPOPERSONADESCRI, PERIODO=LEFT(FECHAAPROBACION2,7), RETIRADOS = SUM(RETIRADOS) FROM #QtyRetirados
        GROUP BY AGENCIADESCRI, TIPOPERSONADESCRI, LEFT(FECHAAPROBACION2,7)
    ) r
    on r.AGENCIADESCRI = p.AGENCIADESCRI
    and r.TIPOPERSONADESCRI = p.TIPOPERSONADESCRI
    and PERIODO = left(p.fechaCruce,7)


--===========================================================================================================================

    UPDATE #PreOk SET TERMINAMES = (NROSOCIOS+NUEVOSINSCRITOS-RETIRADOS) WHERE N = 1

--===========================================================================================================================
    /*
    nro socios +	nuevos inscri -	retirados	
    EL VALOR ANTERIOR + NUEVOS - RETIRADOS			
    */
    IF OBJECT_ID('tempdb..#Ok') IS NOT NULL drop table #Ok
    SELECT agencia, personeria, dw_fechaCarga, periodo, nrosocios, nuevosinscritos,retirados,n,
    TERMINAMES = 
    SUM(case when n = 1 then nrosocios else 0 end+nuevosinscritos-retirados) OVER (PARTITION BY agencia, personeria ORDER BY periodo asc ROWS UNBOUNDED PRECEDING)
    INTO #Ok
    FROM #PreOk

    IF OBJECT_ID('DWCOOPAC.DBO.WT_ACTRETAGENCIA') IS NOT NULL drop table DWCOOPAC.DBO.WT_ACTRETAGENCIA
    SELECT  
    agencia
    , personeria
    , periodo
    , nrosocios
    , nuevosInscritos
    , retirados
    , terminaMes
    , nuevoInicio = CASE WHEN N = 1 THEN NROSOCIOS ELSE LAG(TERMINAMES) over(partition by AGENCIA, PERSONERIA order by PERIODO ASC) END
    INTO DWCOOPAC.DBO.WT_ACTRETAGENCIA
    FROM #Ok


----===================================================================================================================================================================================================--
--        insert into ETL_PRC_LOG (log_fecha, log_tarea_id, log_tarea_nombre, log_estado) 
--        values (getdate(), 6, 'Tabla WT_ACTRETAGENCIA Cargada', 'OK')

--        insert into DWCOOPAC.dbo.LOG_WT (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'Ejecucion Exitosa de WT_ACTRETAGENCIA',null, 'OK'

--        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'Ejecucion Exitosa del Dashboard Activos y Retirados',null, 'OK'
--        --select * from DWCOOPAC.dbo.LOG_WT

--	end try
--	begin catch
--		rollback transaction

--		declare @error_message varchar(4000), @error_severity int, @error_state int
--		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()

--		insert into DWCOOPAC.dbo.LOG_WT (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'ERROR en la ejecucion de WT_ACTRETAGENCIA', @error_message, 'ERROR'


--	end catch 
--	if @@trancount > 0
--		commit transaction		
--return 0







