USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dashm_dpfmarketing_stock]    Script Date: 15/02/2024 18:38:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_dashm_dpfmarketing_stock]
as
set nocount on --
set xact_abort on
	begin transaction
	begin try

    --=================================================================================================================================================================================================

    declare @fecha date = (select fecha from st_fechamaestra where estado = 1)
    --select @fecha,dateadd(dd,1,EOMONTH(cast(@fecha as date),-1))
    --=================================================================================================================================================================================================
    --select EOMONTH(DATEADD(MONTH, -24, @fecha), -1)


    ---- calendario de cierres y mes actual completo - se usa para el tipo de cambio mensual
    DROP TABLE IF EXISTS #calendario
    select distinct fecha 
    into #calendario
    from dimtiempo 
    where (DiaNegativo = -1 and fecha <= @fecha) 
       OR (fecha between dateadd(dd,1,EOMONTH(cast(@fecha as date),-1)) and @fecha)

    ---- calendario este año - se usa para la tabla final, limita el tiempo que figurara, a solicitud de gloria solo 2023 en adelante
    DROP TABLE IF EXISTS #calendathisyear
    select distinct fecha 
    into #calendathisyear
    from dimtiempo 
    where fecha between EOMONTH(DATEADD(MONTH, -24, @fecha), -1) and @fecha
    --where fecha between DATEFROMPARTS(YEAR(DATEADD(YEAR,-1,GETDATE()-1)), 12, 1) and cast(getdate()-1 as date) -- cambio a solicitud de mlozada 20240104 10:02am
   
--=====================================================================================================================================================================================================================================
    DROP TABLE IF EXISTS #DATOSSOCIO
    SELECT DISTINCT CODIGOSOCIO, TIPO_ENTIDAD 
    INTO #DATOSSOCIO
    FROM DW_DATOSSOCIO WHERE dw_fechaCarga = @FECHA

--=====================================================================================================================================================================================================================================

    -- todas las cuentas DPF activas y liquidadas para reducir el numero de cuentas
    DROP TABLE IF EXISTS #cuentas
    select 
          FECHACANCELACION = case when rp.FECHACANCELACION = '-' then null else rp.FECHACANCELACION end 
        , rp.NROCUENTA
        , rp.MONEDA
        , rp.PRODUCTO
        , rp.ESTADO
        , rp.CANCELACIONANTICIPADA
        , AGENCIA = rp.AGENCIAAPERTURA
        , rp.PLAZODIAS
        , CANAL = CASE WHEN rp.USUARIO = 'AGVIRTUAL' THEN 'DIGITAL' ELSE 'PRESENCIAL' END
        , rp.IMPORTECANCELADO
        , rp.PERSONERIA
        , ds.TIPO_ENTIDAD
    into #cuentas
    FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS rp
    left join #DATOSSOCIO ds on ds.CODIGOSOCIO = rp.CODIGOSOCIO
    where rp.fecha = @fecha
    and (rp.TIPOPRODUCTO = 'Plazo Fijo' OR rp.PRODUCTO = 'AHF') and rp.estado in ('Activa','Liquidada')
    --and rp.PRODUCTO != 'AHV' -- ESTO ES DE AHORROS


    --select * from DWCOOPAC.dbo.WT_REPORTEPASIVAS
    --=====================================================================================================================================================================================================================================

	-- de captacion anexo sacamos todas las cuentas con sus respectivos saldos
	DROP TABLE IF EXISTS #DW_CUENTASALDOS1
    select 
          dw_fechacarga
        , numerocuenta
        , saldoimporte1
    into #DW_CUENTASALDOS1
    from DW_CUENTASALDOS
	where dw_fechaCarga >= '2023-07-01'
	union
	SELECT FECHA, NUMEROCUENTA, SALDOIMPORTE1 FROM TemporalesDW.DBO.ST_DPFMONTOSINICIALES_MKT WHERE FECHA < '2023-07-01'

    DROP TABLE IF EXISTS #DW_CUENTASALDOS
    select 
          cs.dw_fechacarga
        , cs.numerocuenta
        , cs.saldoimporte1
        , c.Producto
        , c.Moneda
        , c.Agencia
        , c.PlazoDias
        , c.Canal
        , c.personeria
        , c.TIPO_ENTIDAD
    into #DW_CUENTASALDOS
    from #DW_CUENTASALDOS1  cs
    inner join #cuentas c on cs.NUMEROCUENTA = c.NROCUENTA

	drop table #DW_CUENTASALDOS1
    --=====================================================================================================================================================================================================================================

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
        , c.personeria
        , c.TIPO_ENTIDAD
    into #datoscuentacorriente
    from DW_DATOSCUENTACORRIENTE dc
    inner join #cuentas c on dc.NUMEROCUENTA = c.NROCUENTA
    where dc.dw_fechaCarga = @fecha--(select fecha from st_fechamaestra where estado = 1)--@fecha
    -- and dc.NUMEROCUENTA = '001236923004'
     -- and dc.FECHAVENCIMIENTO >= '2023-01-01'

--=====================================================================================================================================================================================================================================

    -- extraer aperturas
    DROP TABLE IF EXISTS #aperturas
    ; with cte_aperturas as (
        select * 
        , n = ROW_NUMBER() over(partition by numerocuenta order by fechainicio asc) -- Diferencia para determina si es apertura o cancelacion
        from #datoscuentacorriente --WHERE FECHACANCELACION IS NOT NULL
    ) select obs = 'APERTURA', fecha = FECHAINICIO, FECHAINICIO, FECHAVENCIMIENTO, NUMEROCUENTA, MONTOINICIAL, moneda, FECHACANCELACION, PRODUCTO,
             /*ESTADO, CANCELACIONANTICIPADA,*/ AGENCIA, PLAZODIAS, CANAL, PERSONERIA, TIPO_ENTIDAD
    into #aperturas
    from cte_aperturas where n = 1 --and numerocuenta = '050071323001'

    -- extraer cancelaciones
    DROP TABLE IF EXISTS #cancelaciones
    ; with cte_cancelaciones as (
        select * 
        , n = ROW_NUMBER() over(partition by numerocuenta order by fechainicio desc) -- Diferencia para determina si es apertura o cancelacion
        from #datoscuentacorriente --where NUMEROCUENTA = '050071323001'
    ) select obs = 'CANCELACION', fecha = FECHACANCELACION, FECHAINICIO, FECHAVENCIMIENTO, NUMEROCUENTA, MONTOINICIAL, moneda, FECHACANCELACION, PRODUCTO,
             /*ESTADO, CANCELACIONANTICIPADA,*/ AGENCIA, PLAZODIAS, CANAL, PERSONERIA, TIPO_ENTIDAD
    into #cancelaciones
    from cte_cancelaciones where n = 1 and FECHACANCELACION IS NOT NULL --AND numerocuenta = '050071323001'-- Diferencia para determina si es apertura o cancelacion
    --where numerocuenta = '000001423001'

    -- actualizo el saldo de las cancelaciones
    --update c set c.MONTOINICIAL = cs.saldoimporte1
    --from #cancelaciones c inner join #DW_CUENTASALDOS cs
    --on c.NUMEROCUENTA = cs.numerocuenta
    --where cs.dw_fechacarga between c.fechainicio and c.FECHAVENCIMIENTO

    UPDATE #cancelaciones SET MONTOINICIAL = 0

    update c set c.MONTOINICIAL = cs.IMPORTECANCELADO
    from #cancelaciones c inner join #cuentas cs
    on c.NUMEROCUENTA = cs.NROCUENTA
    where cs.FECHACANCELACION = C.fecha
      and c.PRODUCTO != 'AHF'

    update c set c.MONTOINICIAL = cs.SALDOIMPORTE1
    from #cancelaciones c inner join #DW_CUENTASALDOS cs
    on c.NUMEROCUENTA = cs.NUMEROCUENTA
    where dateadd(day,1,cs.dw_fechacarga) = C.fecha
      and c.PRODUCTO = 'AHF'

    UPDATE #aperturas SET MONTOINICIAL = 0 where producto = 'AHF'
    update c set c.MONTOINICIAL = cs.SALDOIMPORTE1
    from #aperturas c inner join #DW_CUENTASALDOS cs
    on c.NUMEROCUENTA = cs.NUMEROCUENTA
    where dw_fechacarga = C.fecha
      and c.PRODUCTO = 'AHF'



--=====================================================================================================================================================================================================================================
 DECLARE @TC DECIMAL(15,3) = (select promedio from DW_XTIPOCAMBIO where fecha = (select fecha from st_fechamaestra where estado = 1) and codigoTipoCambio = 3)
 --SELECT @TC


    -- resumo y solarizo las aperturas
    DROP TABLE IF EXISTS #prefinal_aperturas
    select a.obs, a.fecha, a.moneda, a.PRODUCTO, /*a.ESTADO, a.CANCELACIONANTICIPADA,*/ a.AGENCIA, a.PLAZODIAS, a.CANAL, a.PERSONERIA, a.TIPO_ENTIDAD
       -- , AmontoOriginal = sum(a.MONTOINICIAL)
        , Amonto_diario = case when a.moneda = 'Dólares' then sum(a.MONTOINICIAL)*@TC/*tcd.promedio*/ else sum(a.MONTOINICIAL) end
        , Amonto_mensual = case when a.moneda = 'Dólares' then sum(a.MONTOINICIAL)*TCM.promedio else sum(a.MONTOINICIAL) end
        , Amonto_anual = case when a.moneda = 'Dólares' then sum(a.MONTOINICIAL)*TCA.promedio else sum(a.MONTOINICIAL) end
        , Qaperturas = count(*)
    into #prefinal_aperturas
    from #aperturas a
    --left join DW_XTIPOCAMBIO tcd on tcd.fecha = a.FECHA and tcd.codigoTipoCambio = 3 -- tipo cambio diario


    LEFT JOIN (-- tipo cambio mensual
        SELECT periodo = left(FECHA,7), FECHA, n = ROW_NUMBER() over(partition by left(FECHA,7) order by fecha desc), promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3 AND FECHA IN ( SELECT DISTINCT FECHA FROM #calendario )
    ) TCM ON TCM.periodo = LEFT(a.FECHA,7) and tcm.n = 1

    LEFT JOIN (-- tipo cambio anual
        SELECT periodo1 = left(FECHA,4), PERIODO2 = YEAR(FECHA)+1, FECHA, n = ROW_NUMBER() over(partition by left(FECHA,4) order by fecha desc), promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3
    ) TCA ON TCA.periodo2 = LEFT(a.FECHA,4) and TCA.n = 1

    where a.fecha >= '2021-12-01' -- limitamos por solicitud de gloria, solo 2023 en adelante
    group by a.obs, a.fecha, a.moneda, a.PRODUCTO, /*a.ESTADO, a.CANCELACIONANTICIPADA,*/ a.AGENCIA, a.PLAZODIAS, a.CANAL, a.PERSONERIA, a.TIPO_ENTIDAD, /*tcd.promedio*/ TCM.promedio, TCA.promedio

--=====================================================================================================================================================================================================================================

    -- resumo y solarizo las cancelaciones
    DROP TABLE IF EXISTS #prefinal_cancelaciones
    select c.obs, c.fecha, c.moneda, c.PRODUCTO, /*c.ESTADO, c.CANCELACIONANTICIPADA,*/ c.AGENCIA, c.PLAZODIAS, c.CANAL, c.PERSONERIA, c.TIPO_ENTIDAD
        --, CmontoOriginal = sum(c.MONTOINICIAL) -- aqui se mantiene el monto original por moneda en caso gloria lo solicite despues
        , Cmonto_diario = case when c.moneda = 'Dólares' then sum(c.MONTOINICIAL)*@TC/*tcd.promedio*/ else sum(c.MONTOINICIAL) end
        , Cmonto_mensual = case when c.moneda = 'Dólares' then sum(c.MONTOINICIAL)*TCM.promedio else sum(c.MONTOINICIAL) end
        , Cmonto_anual = case when c.moneda = 'Dólares' then sum(c.MONTOINICIAL)*TCA.promedio else sum(c.MONTOINICIAL) end
        , Qcancelaciones = count(*)
    into #prefinal_cancelaciones
    from #cancelaciones c
  --  left join DW_XTIPOCAMBIO tcd on tcd.fecha = c.FECHA and tcd.codigoTipoCambio = 3 -- tipo cambio diario

    LEFT JOIN (-- tipo cambio mensual
        SELECT periodo = left(FECHA,7), FECHA, n = ROW_NUMBER() over(partition by left(FECHA,7) order by fecha desc), promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3 AND FECHA IN ( SELECT DISTINCT FECHA FROM #calendario )
    ) TCM ON TCM.periodo = LEFT(c.FECHA,7) and tcm.n = 1

    LEFT JOIN (-- tipo cambio anual
        SELECT periodo1 = left(FECHA,4), PERIODO2 = YEAR(FECHA)+1, FECHA, n = ROW_NUMBER() over(partition by left(FECHA,4) order by fecha desc), promedio
        FROM DW_XTIPOCAMBIO 
        WHERE codigoTipoCambio = 3
    ) TCA ON TCA.periodo2 = LEFT(c.FECHA,4) and TCA.n = 1
    where c.fecha >= '2021-12-01'-- limitamos por solicitud de gloria, solo 2023 en adelante
    group by c.obs, c.fecha, c.moneda, c.PRODUCTO, /*c.ESTADO, c.CANCELACIONANTICIPADA,*/ c.AGENCIA, c.PLAZODIAS, c.CANAL, c.PERSONERIA, c.TIPO_ENTIDAD, TCM.promedio, TCA.promedio

--=====================================================================================================================================================================================================================================

    -- SE GENERA LA MATRIZ CALENDARIZADA 
    DROP TABLE IF EXISTS #FILTROS
    select distinct  Producto,Moneda,--Estado,CancelacionAnticipada,
    Agencia,PlazoDias,Canal, PERSONERIA, TIPO_ENTIDAD
    INTO #FILTROS
    from #aperturas
    union
    select distinct  Producto,Moneda,---Estado,CancelacionAnticipada,
    Agencia,PlazoDias,Canal , PERSONERIA, TIPO_ENTIDAD
    from #cancelaciones

    DROP TABLE IF EXISTS #MATRIZ
    SELECT *
    INTO #MATRIZ
    FROM #calendathisyear C
    CROSS JOIN #FILTROS F;

    drop table #FILTROS

    --select * from #MATRIZ
    --SE CONSOLIDA LAS TABLAS 
    drop table if exists #consolidado;
    select 
        m.Fecha, m.Producto, m.Moneda, m.Agencia, m.PlazoDias, m.Canal, m.Personeria,m.TIPO_ENTIDAD,
        APERTURA_TCD_MONTO = isnull(a.Amonto_diario,0), 
        APERTURA_TCM_MONTO = isnull(a.Amonto_mensual,0), 
        APERTURA_TCA_MONTO = isnull(a.Amonto_anual,0), 
        Qaperturas = isnull(A.Qaperturas,0),
        CANCELACION_TCD_MONTO = isnull(c.Cmonto_diario,0), 
        CANCELACION_TCM_MONTO = isnull(c.Cmonto_mensual,0), 
        CANCELACION_TCA_MONTO = isnull(c.Cmonto_anual,0), 
        Qcancelaciones = isnull(C.Qcancelaciones,0)
    INTO #consolidado
    from #MATRIZ m
    left join #prefinal_aperturas a
        on  m.fecha = a.fecha
        and m.moneda = a.moneda
        and m.PRODUCTO = a.PRODUCTO
        and m.AGENCIA = a.AGENCIA
        and m.PLAZODIAS = a.PLAZODIAS
        and m.CANAL = a.CANAL
        and m.personeria = a.personeria
        and m.TIPO_ENTIDAD = a.TIPO_ENTIDAD

    left join #prefinal_cancelaciones c
        on  m.fecha = c.fecha
        and m.moneda = c.moneda
        and m.PRODUCTO = c.PRODUCTO
        and m.AGENCIA = c.AGENCIA
        and m.PLAZODIAS = c.PLAZODIAS
        and m.CANAL = c.CANAL
        and m.personeria = c.personeria
        and m.TIPO_ENTIDAD = c.TIPO_ENTIDAD
    where m.Fecha >= '2021-12-31'
    order by m.Fecha asc

    --=================================================================================================================================================================================================
    -- SE AGREGA EL STOCK AL CIERRE DE DICIEMBRE 2022
    drop table if exists #stockinicial
    ;with cte as(
        select cs.dw_fechacarga, cs.NUMEROCUENTA, cs.SALDOIMPORTE1, cs.Moneda, cs.Producto, cs.Agencia, cs.PlazoDias, cs.Canal, cs.Personeria, cs.TIPO_ENTIDAD
        , SALDO_TCD = case when cs.moneda = 'Dólares' then cs.SALDOIMPORTE1*@TC/*tcd.promedio*/ else cs.SALDOIMPORTE1 end
        , SALDO_TCM = case when cs.moneda = 'Dólares' then cs.SALDOIMPORTE1*TCM.promedio else cs.SALDOIMPORTE1 end
        , SALDO_TCA = case when cs.moneda = 'Dólares' then cs.SALDOIMPORTE1*TCA.promedio else cs.SALDOIMPORTE1 end
        from #DW_CUENTASALDOS cs
      --  left join DW_XTIPOCAMBIO tcd on tcd.fecha = cs.dw_fechacarga and tcd.codigoTipoCambio = 3 -- tipo cambio diario

        LEFT JOIN (-- tipo cambio mensual
            SELECT periodo = left(FECHA,7), FECHA, n = ROW_NUMBER() over(partition by left(FECHA,7) order by fecha desc), promedio
            FROM DW_XTIPOCAMBIO 
            WHERE codigoTipoCambio = 3 AND FECHA IN ( SELECT DISTINCT FECHA FROM #calendario )
        ) TCM ON TCM.periodo = LEFT(cs.dw_fechacarga,7) and tcm.n = 1

        LEFT JOIN (-- tipo cambio anual
            SELECT periodo1 = left(FECHA,4), PERIODO2 = YEAR(FECHA)+1, FECHA, n = ROW_NUMBER() over(partition by left(FECHA,4) order by fecha desc), promedio
            FROM DW_XTIPOCAMBIO 
            WHERE codigoTipoCambio = 3
        ) TCA ON TCA.periodo2 = LEFT(cs.dw_fechacarga,4) and TCA.n = 1
        where cs.dw_fechacarga = '2021-12-31' 
    )
    select dw_fechacarga, Moneda, Producto, Agencia, PlazoDias, Canal, Personeria, TIPO_ENTIDAD, SALDO_TCD = sum(SALDO_TCD), SALDO_TCM = sum(SALDO_TCM), SALDO_TCA = sum(SALDO_TCA), Q = COUNT(*)
    into #stockinicial
    from cte
    group by dw_fechacarga, Moneda, Producto, Agencia, PlazoDias, Canal, Personeria, TIPO_ENTIDAD

    --SELECT * FROM #stockinicial
    --SELECT * FROM #consolidado where fecha = '2022-12-31'

    UPDATE C SET C.APERTURA_TCD_MONTO = M.SALDO_TCD
               , C.APERTURA_TCM_MONTO = M.SALDO_TCM
               , C.APERTURA_TCA_MONTO = M.SALDO_TCA
               , C.Qaperturas = M.Q
    FROM #consolidado C INNER JOIN #stockinicial M
    ON   m.dw_fechaCarga = c.fecha
     and m.moneda = c.moneda
     and m.PRODUCTO = c.PRODUCTO
     and m.AGENCIA = c.AGENCIA
     and m.PLAZODIAS = c.PLAZODIAS
     and m.CANAL = c.CANAL
     and m.personeria = c.personeria
     and m.TIPO_ENTIDAD = c.TIPO_ENTIDAD
     --select * from #consolidado

     --select sum(saldo_tcd),sum(saldo_tcm),sum(saldo_tca) from #stockinicial
    --=================================================================================================================================================================================================

    DROP TABLE IF EXISTS DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO
    SELECT FECHA, PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD
        , APERTURA_TCD_MONTO, CANCELACION_TCD_MONTO
        , SUM(APERTURA_TCD_MONTO - CANCELACION_TCD_MONTO) OVER (
                                                                PARTITION BY PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD
                                                                ORDER BY Fecha 
                                                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                                              ) AS STOCK_TCD
        , APERTURA_TCM_MONTO, CANCELACION_TCM_MONTO
        , SUM(APERTURA_TCM_MONTO - CANCELACION_TCM_MONTO) OVER (
                                                    PARTITION BY PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD
                                                    ORDER BY Fecha 
                                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                                  ) AS STOCK_TCM
        , APERTURA_TCA_MONTO, CANCELACION_TCA_MONTO
        , SUM(APERTURA_TCA_MONTO - CANCELACION_TCA_MONTO) OVER (
                                                    PARTITION BY PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA ,TIPO_ENTIDAD
                                                    ORDER BY Fecha 
                                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                                  ) AS STOCK_TCA
        , QAPERTURAS, Qcancelaciones
        , SUM(QAPERTURAS - Qcancelaciones) OVER (
                                                    PARTITION BY PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD 
                                                    ORDER BY Fecha 
                                                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                                                  ) AS STOCK_Q
    INTO DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO
    FROM #consolidado C
    ORDER BY FECHA, PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD

	delete from DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO where fecha = '2021-12-31'
    
    --select distinct fecha from DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO order by fecha asc
    

    --SELECT distinct fecha FROM DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO order by FECHA asc


    --ORDER BY FECHA, PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, PERSONERIA,TIPO_ENTIDAD
--SELECT * FROM DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO where producto = 'ahf'
--=================================================================================================================================================================================================

        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard DPF Marketing - Stock',null, 'OK'
        --select * from DWCOOPACIFICO.dbo.WT_RUNOFF
     
	end try
	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'ERROR en la ejecucion del Dashboard DPF Marketing - Stock', @error_message, 'ERROR'

	end catch 
	if @@trancount > 0
		commit transaction		
return 0
