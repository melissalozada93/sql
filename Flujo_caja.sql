USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dashf_flujocaja]    Script Date: 26/02/2024 18:36:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_dashf_flujocaja]
as
set nocount on --
set xact_abort on
	begin transaction
	begin try

		declare @fecini date = dateadd(dd,1,eomonth(cast(getdate() as date),-1))--'2022-10-27'--cast(getdate()-45 as date)
		declare @fecfin date = cast(getdate() as date)

		----------------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------------------------------------
		-----------------------------------CALENDARIZACION REPOTIPASIVAS  DEPOSITOS O APORTES
		-- 1min
		--Se crea una tabla con la fecha de inicio y termino para cada nro de cuenta existente
		IF OBJECT_ID('tempdb..#soli') IS NOT NULL drop table #soli
		SELECT  NUMEROCUENTA,NOMB_PRODUCTO,PRODUCTO, moneda, @fecini fecha
		into #soli
		FROM DW_REPOTIFINANZASPASIVAS
		WHERE FECHA_SALDO >= @fecini
		union
		SELECT NUMEROCUENTA,NOMB_PRODUCTO,PRODUCTO, moneda, @fecfin
		FROM DW_REPOTIFINANZASPASIVAS
		WHERE FECHA_SALDO >= @fecini

		----------------------------------------------------------------------------------------------------------------------------------------
		--Se crea una tabla de todas las fechas entre la fecha de inicio y termino--1.16min
		IF OBJECT_ID('tempdb..#periodo') IS NOT NULL drop table #periodo
		SELECT distinct [NPeriodo], [Fecha]
		into #periodo
		FROM [DWCOOPAC].[dbo].[dimTiempo] 
		where [Fecha] between @fecini and @fecfin
		
		--Se crea una tabla en la que estan todas las fechas entre la fecha de inicio y termino
		IF OBJECT_ID('tempdb..#solicitudesCalendarizadas') IS NOT NULL drop table #solicitudesCalendarizadas
		select distinct p.NPeriodo, today = p.Fecha, yesterday = dateadd(dd,-1,p.fecha), s.NUMEROCUENTA, s.NOMB_PRODUCTO, S.PRODUCTO, s.MONEDA
		into #solicitudesCalendarizadas
		from #periodo p
		left join #soli s
		on left(p.NPeriodo,4) = convert(varchar,year(s.Fecha))
		order by s.NUMEROCUENTA, p.Fecha

        CREATE INDEX IND_#solicitudesCalendarizadasXnrocuenta on #solicitudesCalendarizadas(NUMEROCUENTA)
        WITH (DROP_EXISTING = off)

        CREATE INDEX IND_#solicitudesCalendarizadasXyesterday on #solicitudesCalendarizadas(yesterday)
        WITH (DROP_EXISTING = off)

        CREATE INDEX IND_#solicitudesCalendarizadasXtoday on #solicitudesCalendarizadas(today)
        WITH (DROP_EXISTING = off)

		--drop table #periodo
		--drop table #soli
		----------------------------------------------------------------------------------------------------------------------------------------

		IF OBJECT_ID('tempdb..#hoy') IS NOT NULL drop table #hoy--15seg
		SELECT 
		  NUMEROCUENTA
		, FECHA_SALDO AS FECHAHOY
		, dateadd(dd,-1,FECHA_SALDO) AS FECHAAYER
		, MONEDA
		, NOMB_PRODUCTO
		, PRODUCTO
		, SUM(SALD_CONTAB) AS SALDOHOY
		into #hoy
		FROM DW_REPOTIFINANZASPASIVAS
		WHERE FECHA_SALDO >= @fecini 
		GROUP BY  NUMEROCUENTA, FECHA_SALDO, dateadd(dd,-1,FECHA_SALDO), MONEDA, NOMB_PRODUCTO, PRODUCTO

        CREATE INDEX IND_#hoyXnrocuenta on #hoy(NUMEROCUENTA)
        WITH (DROP_EXISTING = off)

        CREATE INDEX IND_#hoyXFECHAHOY on #hoy(FECHAHOY)
        WITH (DROP_EXISTING = off)

		IF OBJECT_ID('tempdb..#prereporte') IS NOT NULL drop table #prereporte--3min
		select sc.NPeriodo
		, sc.NUMEROCUENTA
		, sc.yesterday
		, saldoayer = CASE WHEN h.SALDOHOY IS NULL THEN 0 ELSE h.SALDOHOY END 
		, sc.today
		, saldohoy = CASE WHEN hh.SALDOHOY IS NULL THEN 0 ELSE hh.SALDOHOY END 
		, variacion = CASE WHEN hh.SALDOHOY IS NULL THEN 0 ELSE hh.SALDOHOY END - CASE WHEN h.SALDOHOY IS NULL THEN 0 ELSE h.SALDOHOY END 
		, producto = case 
                        when h.NOMB_PRODUCTO is null then hh.NOMB_PRODUCTO
		                else h.NOMB_PRODUCTO
		             end 
		, producto2 = case 
                        when h. PRODUCTO is null then hh. PRODUCTO
		                else h. PRODUCTO
		              end
		, moneda = case 
                    when h.MONEDA is null then hh.MONEDA
		            else h.MONEDA
		           end 
		, origen = 'REPOTIFINANZASPASIVAS'
		into #prereporte
		from #solicitudesCalendarizadas sc
		left join #hoy h--ayer
		    on h.NUMEROCUENTA = sc.NUMEROCUENTA and h.FECHAHOY = sc.yesterday
		left join #hoy hh--hoy
		    on hh.NUMEROCUENTA = sc.NUMEROCUENTA and hh.FECHAHOY = sc.today


		--drop table #solicitudesCalendarizadas
		--drop table #hoy

		delete from #prereporte where (saldohoy+saldoayer)=0
		--select * from #prereporte order by today desc

		--------------------------------TABLA QUE HACE REFERENCIA A DATOS MANIPULABLES --EXCEL INTERNO DE TRABAJO

		IF OBJECT_ID('tempdb..#TABLA_PRODUCTO') IS NOT NULL drop table #TABLA_PRODUCTO
		CREATE TABLE #TABLA_PRODUCTO(NOMB_PRODUCTO VARCHAR(50),Det_producto VARCHAR(50));
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('501-APORTE 501','Aportes');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('502-APORTE 502','Aportes');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('ACV-AHORROS CONVENIOS','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AHF-AHORROS FLOAT','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AHP-AHORRO PROGRAMADO','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AHV - FONDO GARANTIA DOLARES','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AHV - FONDO GARANTIA SOLES','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AHV-AHORROS','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('AMV-KSA: CTA TRANSITO MIVIVIENDA','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('APO-APORTACIONES','Aportes');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('APO-APORTE EXTRAORD.','Aportes');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('ASD-AHORROS - SEGURO DESGRAVAMEN','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('ATS-AHORROS - TIEMPO DE SERVICIOS','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDA-CERTSIICADO SERIE A','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDA-DPF SERIE A','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDB-CERTSIICADO SERIE B','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDB-DPF SERIE B','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-AFP','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-CERT.PLZ.FIJO','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-CERT.PLZ.VARIABLE DOLARES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-CERT.PLZ.VARIABLE SOLES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-DPF','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-DPF AFP','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-DPF CTS','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDE-DPF VARIABLE','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDJ-DPF PACIFIJO','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDJ-PACSIIJO','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDM-DPF GANAMAX','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDM-GANAMAX','Certificados Japón');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDP-CERTIPLUS','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDP-DPF CERTIPLUS','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CNV INTERNA CONVENIOS','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CPD-CUENTA PAGO DESGRAVAMEN','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CPR-CERT.PLZ.FIJO PACIRENTABLE','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CPR-DPF PACIRENTABLE','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTG-CTA TRANSITO Y CTRL GASTOS DOLARES','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTG-CTA TRANSITO Y CTRL GASTOS SOLES','Ahorros a la Vista');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTS-CUENTA SOCIOS DOLARES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTS-CUENTA SOCIOS SOLES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTS-CUENTA TRABAJADORES DOLARES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CTS-CUENTA TRABAJADORES SOLES','Certificados Perú');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('TAN-TANO AHORROS','Tanomoshi');
		INSERT INTO #TABLA_PRODUCTO (NOMB_PRODUCTO,Det_producto) VALUES ('CDD-DPF DAILY','Certificados Perú');

		IF OBJECT_ID('tempdb..#TABLA_PRODUCTO1') IS NOT NULL drop table #TABLA_PRODUCTO1
		SELECT * ,CASE 
		WHEN Det_producto ='Ahorros a la Vista' THEN 'Ahorros'
		WHEN Det_producto in ('Certificados Japón','Certificados Perú') THEN 'Certificados'
		WHEN Det_producto ='Aportes' THEN 'Aportes'
		end as Det_producto2,CASE
		WHEN Det_producto in ('Certificados Japón','Certificados Perú','Ahorros a la Vista') THEN 'Depositos'
		WHEN Det_producto ='Aportes' THEN 'Aportes'
		end as Det_producto3
		INTO #TABLA_PRODUCTO1
		FROM #TABLA_PRODUCTO

		--DROP TABLE #TABLA_PRODUCTO
		--SELECT * FROM #TABLA_PRODUCTO1
		--ORDER BY Det_producto3


		--SE AGREGAN COLUMNA A LA TABLA INICIAL PARA DETERMINAR LA GRANULARIDAD DEL PRODUCTO
		--MODIFICACIONES A LA TABLA PASIVAS = APORTES Y DEPOSITOS
		IF OBJECT_ID('tempdb..#PREREPORTE2') IS NOT NULL drop table #PREREPORTE2--6seg
		SELECT P.NPeriodo,p.today,p.yesterday, p.NUMEROCUENTA,p.saldoayer,p.saldohoy,p.variacion, CASE
		WHEN P.variacion<0 THEN P.variacion*-1
		ELSE P.variacion
		END as variacion_abs,
		p.producto2 as producto,p.moneda,p.origen, TB.Det_producto,TB.Det_producto2,TB.Det_producto3
		INTO #PREREPORTE2
		FROM #prereporte P
		LEFT JOIN #TABLA_PRODUCTO1 TB ON P.producto=TB.NOMB_PRODUCTO
		DROP TABLE #prereporte
		DROP TABLE  #TABLA_PRODUCTO1

		---SE AGREGA LA COLUMNA OPERACION --PARA LUEGO TRBAJAR CON ELLA
		IF OBJECT_ID('tempdb..#PREREPORTE3') IS NOT NULL drop table #PREREPORTE3--7seg
		SELECT CASE
		WHEN saldoayer=0 AND saldohoy>0 THEN '1.APERTURA'
		WHEN saldoayer>0 AND saldohoy=0 THEN '4.CANCELACION'
		WHEN saldoayer = saldohoy  THEN '3.CTE'
		WHEN saldohoy-saldoayer >0 THEN '2.CRECIMIENTO'
		ELSE'5.RETIRO'
		END AS operacion, *
		INTO #PREREPORTE3
		FROM #PREREPORTE2

		--DROP TABLE  #PREREPORTE2
		--SELECT * FROM #PREREPORTE3
		------------------------------------------------------------------------------------------------------------------------------------------------------------
		------------------------------------------------------------------------------------------------------------------------------------------------------------
		------------------------------------------------------------CALENDARIZACION REPOTIPASIVAS  DEPOSITOS O APORTES
		--declare @fecini date = dateadd(dd,1,eomonth(cast(getdate() as date),-1))--'2022-10-27'--cast(getdate()-45 as date)
		--declare @fecfin date = cast(getdate() as date)


		IF OBJECT_ID('tempdb..#solix') IS NOT NULL drop table #solix
		SELECT NUMEROSOLICITUD AS NUMEROCUENTA,producto, moneda, @fecini fecha
		into #solix
		FROM DW_REPOTIFINANZASPADRON
		WHERE FECHAPADRON >= @fecini
		union
		SELECT NUMEROSOLICITUD AS NUMEROCUENTA,producto, moneda, @fecfin
		FROM DW_REPOTIFINANZASPADRON
		WHERE FECHAPADRON >= @fecini

		IF OBJECT_ID('tempdb..#periodox') IS NOT NULL drop table #periodox
		SELECT distinct [NPeriodo], [Fecha]
		into #periodox
		FROM [DWCOOPAC].[dbo].[dimTiempo] 
		where [Fecha] between @fecini and @fecfin

        IF OBJECT_ID('tempdb..#solicitudesCalendarizadasx') IS NOT NULL drop table #solicitudesCalendarizadasx
        select distinct p.NPeriodo, today = p.Fecha, yesterday = dateadd(dd,-1,p.fecha), s.NUMEROCUENTA, s.PRODUCTO, s.MONEDA
        into #solicitudesCalendarizadasx
        from #periodox p
        left join #solix s
        on left(p.NPeriodo,4) = convert(varchar,year(s.Fecha))
        order by s.NUMEROCUENTA, p.Fecha

		IF OBJECT_ID('tempdb..#hoyx') IS NOT NULL drop table #hoyx
		SELECT 
		  NUMEROSOLICITUD AS NUMEROCUENTA
		, FECHAPADRON AS FECHAHOY
		, dateadd(dd,-1,FECHAPADRON) AS FECHAAYER
		, MONEDA
		, PRODUCTO
		, SUM(SALDOPRESTAMO) AS SALDOHOY
		into #hoyx
		FROM DW_REPOTIFINANZASPADRON
		WHERE FECHAPADRON >= @fecini --and NUMEROSOLICITUD=186061
		GROUP BY NUMEROSOLICITUD, FECHAPADRON, dateadd(dd,-1,FECHAPADRON), MONEDA, PRODUCTO

        CREATE INDEX IND_#hoyxXnrocuenta on #hoyx(NUMEROCUENTA)
        WITH (DROP_EXISTING = off)

        CREATE INDEX IND_#hoyxXFECHAHOY on #hoyx(FECHAHOY)
        WITH (DROP_EXISTING = off)

		IF OBJECT_ID('tempdb..#prereportex') IS NOT NULL drop table #prereportex
		select sc.NPeriodo
		, sc.NUMEROCUENTA
		, sc.yesterday
		, saldoayer = CASE WHEN h.SALDOHOY IS NULL THEN 0 ELSE h.SALDOHOY END 
		, sc.today
		, saldohoy = CASE WHEN hh.SALDOHOY IS NULL THEN 0 ELSE hh.SALDOHOY END 
		, variacion = CASE WHEN hh.SALDOHOY IS NULL THEN 0 ELSE hh.SALDOHOY END - CASE WHEN h.SALDOHOY IS NULL THEN 0 ELSE h.SALDOHOY END 
		, operacion = null
		,case when h.PRODUCTO is null then hh.PRODUCTO
		else h.PRODUCTO
		end as producto
		,case when h.MONEDA is null then hh.MONEDA
		else h.MONEDA
		end as moneda
		,origen ='REPOTIFINANZASPADRON'
		,Det_producto ='Creditos'
		,Det_producto2 ='Creditos'
		,Det_producto3 ='Creditos'
		into #prereportex
		from #solicitudesCalendarizadasx sc
		left join #hoyx h--ayer
		on h.NUMEROCUENTA = sc.NUMEROCUENTA and h.FECHAHOY = sc.yesterday
		left join #hoyx hh--hoy
		on hh.NUMEROCUENTA = sc.NUMEROCUENTA and hh.FECHAHOY = sc.today
		--where sc.NUMEROCUENTA =186061
		--order by sc.today desc

		--drop table #solicitudesCalendarizadas
		--drop table #hoyx

		delete from #prereportex where (saldohoy+saldoayer)=0
		--select * from #prereportex order by today desc

		-------------------------------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------------------------------------
		-----------------------------------------------------SE AGREGAN COLUMNA A LA TABLA INICIAL PARA DETERMINAR LA GRANULARIDAD DEL PRODUCTO
		--MODIFICACIONES A LA TABLA PADRON = CREDITOS
		IF OBJECT_ID('tempdb..#PREREPORTE1X') IS NOT NULL drop table #PREREPORTE1X
		SELECT 
            operacion = CASE
		                    WHEN saldoayer=0 AND saldohoy>0 THEN '2.DESEMBOLSO'
		                    WHEN saldoayer>0 AND saldohoy=0 THEN '5.CANCELACION'
		                    WHEN saldoayer = saldohoy THEN '3.CTE'
		                    WHEN saldohoy-saldoayer >0 THEN '1.INCREMENTO'
		                    WHEN saldohoy-saldoayer <0 THEN '4.AMORTIZACION'
		                END 
		, NPeriodo
        , today
        , yesterday
		, NUMEROCUENTA
        , saldoayer
        , saldohoy
        , variacion
        , variacion_abs = CASE
		                    WHEN variacion<0 THEN variacion*-1
		                    ELSE variacion
		                  END 
		, producto
        , moneda
        , origen
        , Det_producto
        , Det_producto2
        , Det_producto3
		INTO #PREREPORTE1X
		FROM #prereportex

		IF OBJECT_ID('tempdb..#REPORTEX') IS NOT NULL drop table #REPORTEX
		SELECT * 
		INTO #REPORTEX
		FROM #PREREPORTE3
		UNION ALL
		SELECT * from #PREREPORTE1X

		DROP TABLE #PREREPORTE1X
		DROP TABLE #PREREPORTE3
		DROP TABLE #prereportex

		IF OBJECT_ID('tempdb..#REPORTE2X') IS NOT NULL drop table #REPORTE2X
		SELECT *, CASE
		WHEN Det_producto2='Creditos' and operacion IN ('1.INCREMENTO','2.DESEMBOLSO') THEN 'Desembolso Total'
		WHEN Det_producto2='Creditos' and operacion IN ('4.AMORTIZACION','5.CANCELACION') THEN 'Amortización Total'

		WHEN Det_producto2 !='Creditos' and operacion IN ('2.CRECIMIENTO','1.APERTURA') THEN 'Apertura Total'
		WHEN Det_producto2 !='Creditos' and operacion IN ('4.CANCELACION','5.RETIRO') THEN 'Cancelaciones Total'
		else '-'
		END AS GRAD_2
		INTO #REPORTE2X	
		FROM #REPORTEX

		DROP TABLE #REPORTEX

		IF OBJECT_ID('tempdb..#REPORTE3X') IS NOT NULL drop table #REPORTE3X
		SELECT CASE
		WHEN Det_producto2='Creditos' and operacion='1.INCREMENTO' THEN 'Incremento de créditos'
		WHEN Det_producto2='Creditos' and operacion='2.DESEMBOLSO' THEN 'Desembolso de créditos'
		WHEN Det_producto2='Creditos' and operacion='4.AMORTIZACION' THEN 'Amortización de créditos'
		WHEN Det_producto2='Creditos' and operacion='5.CANCELACION' THEN 'Cancelaciones de créditos'

		WHEN Det_producto2='Aportes' and operacion='1.APERTURA' THEN 'Apertura de Aportes'
		WHEN Det_producto2='Aportes' and operacion='2.CRECIMIENTO' THEN 'Crecimiento de Aportes'
		WHEN Det_producto2='Aportes' and operacion='4.CANCELACION' THEN 'Cancelación de aportes'
		WHEN Det_producto2='Aportes' and operacion='5.RETIRO' THEN 'Retiro de aportes'

		WHEN Det_producto2='Ahorros' and operacion='1.APERTURA' THEN 'Apertura y crecimiento de Ahorros'
		WHEN Det_producto2='Ahorros' and operacion='2.CRECIMIENTO' THEN 'Apertura y crecimiento de Ahorros'
		WHEN Det_producto2='Ahorros' and operacion='4.CANCELACION' THEN 'Cancelación y retiro de Ahorros'
		WHEN Det_producto2='Ahorros' and operacion='5.RETIRO' THEN 'Cancelación y retiro de Ahorros'


		WHEN Det_producto2='Certificados' and operacion='1.APERTURA' THEN 'Apertura de depósitos a plazo'
		WHEN Det_producto2='Certificados' and operacion='2.CRECIMIENTO' THEN 'Crecimiento de depósitos a plazo'
		WHEN Det_producto2='Certificados' and operacion='4.CANCELACION' THEN 'Cancelación de depósitos a plazo'
		WHEN Det_producto2='Certificados' and operacion='5.RETIRO' THEN 'Retiro de depósitos a plazo'

		else '-'
		end as GRA_3, *
		INTO #REPORTE3X
		FROM #REPORTE2X

		DROP TABLE #REPORTE2X

		IF OBJECT_ID('tempdb..#REPORTE4X') IS NOT NULL drop table #REPORTE4X
		SELECT CASE
		WHEN GRA_3 IN ( 'Incremento de créditos','Desembolso de créditos') THEN 'Colocación de Créditos'
		WHEN GRA_3 IN ( 'Amortización de créditos', 'Cancelaciones de créditos') THEN 'Cobranza de Créditos (Capital)' ---E

		WHEN GRA_3 IN ( 'Apertura de Aportes','Crecimiento de Aportes') THEN 'Captación de Aportes'--E
		WHEN GRA_3 IN ( 'Cancelación de aportes', 'Retiro de aportes') THEN 'Salida de Aportes'

		WHEN GRA_3 = 'Apertura y crecimiento de Ahorros' THEN 'Captación de Depósitos'--E
		WHEN GRA_3 = 'Cancelación y retiro de Ahorros' THEN 'Salida de Depósitos'

		WHEN GRA_3 IN ( 'Apertura de depósitos a plazo','Crecimiento de depósitos a plazo') THEN 'Captación de Depósitos'--E
		WHEN GRA_3 IN ( 'Cancelación de depósitos a plazo','Retiro de depósitos a plazo') THEN 'Salida de Depósitos'
		else '-'
		end as GRA_4 , *
		INTO #REPORTE4X
		FROM  #REPORTE3X

		DROP TABLE #REPORTE3X

		--IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA
        delete from DWCOOPAC.DBO.WT_FLUJOCAJA where today >= @fecini
        insert into DWCOOPAC.DBO.WT_FLUJOCAJA
		SELECT 
		CASE
			WHEN x.GRA_4 like 'Colocación%' THEN 'SALIDAS'
			WHEN x.GRA_4 like 'Salida%' THEN 'SALIDAS'
			WHEN x.GRA_4 like 'Captación%' THEN 'ENTRADAS'
			WHEN x.GRA_4 like 'Cobranza%' THEN 'ENTRADAS'
		else '-'
		END AS GRA_5
		, x.*
		, FLG = CASE WHEN x.today BETWEEN CAST(GETDATE()-45 AS DATE)  AND CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END
		, case when x.moneda='S' then x.saldoayer else x.saldoayer*tt.promedio end as saldoayer_s
		, case when x.moneda='S' then x.saldohoy else x.saldohoy*t.promedio end as saldohoy_s
		, case when x.moneda='S' then x.variacion_abs else x.variacion_abs*t.promedio end as var_s
		--INTO DWCOOPAC.DBO.WT_FLUJOCAJA
		FROM #REPORTE4X x
		left join (select fecha, promedio from dw_xtipocambio where codigotipocambio = 3) t
		on x.today = t.fecha 
		left join (select fecha, promedio from dw_xtipocambio where codigotipocambio = 3) tt
		on x.yesterday = tt.fecha 

--============================================================================================================================================================================
--select distinct today from VW_WT_FLUJOCAJA order by today desc



		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_aportes') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_aportes
		select *
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_aportes
		from VW_WT_FLUJOCAJA
		where Det_producto3 = 'Aportes'--1min
		--------------------------------------------------------------------------------------
		--					A	P	O	R	T	E	S
		--------------------------------------------------------------------------------------

		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB0') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB0
		select  today, operacion, GRAD_2 
		,case when moneda = 'D' then variacion
		else 0 end as 'Dolares'
		,case when moneda = 'S' then variacion
		else 0 end as 'Soles'
		,case when moneda = 'D' then variacion_abs
		else 0 end as 'var_Dolares'
		,case when moneda = 'S' then variacion_abs
		else 0 end as 'var_Soles'
		,variacion_abs
		,var_s
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB0
		from WT_FLUJOCAJA_aportes---------------------------------------------------------------------------------------


		IF OBJECT_ID('tempdb..#APORTES_AYER') IS NOT NULL drop table #APORTES_AYER
		select  today, GRA_5
		,case when moneda = 'D' then saldoayer
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldoayer
		else 0 end as 'Saldo Sol Mo'
		, saldoayer_s as 'Saldo Total'
		INTO #APORTES_AYER
		from WT_FLUJOCAJA_aportes---------------------------------------------------------------------------------------

		IF OBJECT_ID('tempdb..#APORTES_AYER2') IS NOT NULL drop table #APORTES_AYER2
		SELECT today ,GRA_5
		,'Ayer' as moneda 
		,SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #APORTES_AYER2
		FROM #APORTES_AYER
		GROUP BY today, GRA_5

		IF OBJECT_ID('tempdb..#APORTES_HOY') IS NOT NULL drop table #APORTES_HOY
		select  today, GRA_5
		,case when moneda = 'D' then saldohoy
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldohoy
		else 0 end as 'Saldo Sol Mo'
		, saldohoy_s as 'Saldo Total'
		INTO #APORTES_HOY
		from WT_FLUJOCAJA_aportes---------------------------------------------------------------------------------------

	
		IF OBJECT_ID('tempdb..#APORTES_HOY2') IS NOT NULL drop table #APORTES_HOY2 
		SELECT today ,GRA_5
		,'Hoy' as moneda 
		,SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #APORTES_HOY2
		FROM #APORTES_HOY
		GROUP BY today, GRA_5


		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB1') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB1
		SELECT * 
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_aportes_TB1
		FROM #APORTES_AYER2
		UNION 
		SELECT * FROM #APORTES_HOY2

		----------------------------------------------------------------------------------------------
		-----------------------------------------------------------------------------------------------
	

		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos
		select *
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos
		from VW_WT_FLUJOCAJA
		where Det_producto3 = 'Creditos'


		--------------------------------------------------------------------------------------
		--					C	R	E	D	I	T	O	S
		--------------------------------------------------------------------------------------

		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB0') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB0
		select  today, operacion, GRAD_2 
		,case when moneda = 'D' then variacion
		else 0 end as 'Dolares'
		,case when moneda = 'S' then variacion
		else 0 end as 'Soles'
		,case when moneda = 'D' then variacion_abs
		else 0 end as 'var_Dolares'
		,case when moneda = 'S' then variacion_abs
		else 0 end as 'var_Soles'
		,variacion_abs
		,var_s
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB0
		from WT_FLUJOCAJA_Creditos


		IF OBJECT_ID('tempdb..#CREDITOS_AYER') IS NOT NULL drop table #CREDITOS_AYER
		select  today, GRA_5
		,case when moneda = 'D' then saldoayer
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldoayer
		else 0 end as 'Saldo Sol Mo'
		, saldoayer_s as 'Saldo Total'
		INTO #CREDITOS_AYER
		from WT_FLUJOCAJA_Creditos

		IF OBJECT_ID('tempdb..#CREDITOS_AYER2') IS NOT NULL drop table #CREDITOS_AYER2
		SELECT today ,GRA_5
		,'Ayer' as moneda 
		,SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #CREDITOS_AYER2
		FROM #CREDITOS_AYER
		GROUP BY today, GRA_5

		IF OBJECT_ID('tempdb..#CREDITOS_HOY') IS NOT NULL drop table #CREDITOS_HOY
		select  today, GRA_5
		,case when moneda = 'D' then saldohoy
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldohoy
		else 0 end as 'Saldo Sol Mo'
		, saldohoy_s as 'Saldo Total'
		INTO #CREDITOS_HOY
		from WT_FLUJOCAJA_Creditos

	
		IF OBJECT_ID('tempdb..#CREDITOS_HOY2') IS NOT NULL drop table #CREDITOS_HOY2 
		SELECT today ,GRA_5
		, 'Hoy' as moneda 
		, SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #CREDITOS_HOY2
		FROM #CREDITOS_HOY
		GROUP BY today, GRA_5


		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB1') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB1
		SELECT * 
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Creditos_TB1
		FROM #CREDITOS_AYER2
		UNION 
		SELECT * FROM #CREDITOS_HOY2

		----------------------------------------------------------------------------------------------
		-----------------------------------------------------------------------------------------------
	



		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos--
		select *
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos
		from vw_WT_FLUJOCAJA
		where Det_producto3 = 'Depositos'

		
		--------------------------------------------------------------------------------------
		--					D	E	P	O	S	I	T	O	S
		--------------------------------------------------------------------------------------

		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB0') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB0
		select  today, operacion,Det_producto2, GRAD_2 
		,case when moneda = 'D' then variacion
		else 0 end as 'Dolares'
		,case when moneda = 'S' then variacion
		else 0 end as 'Soles'
		,case when moneda = 'D' then variacion_abs
		else 0 end as 'var_Dolares'
		,case when moneda = 'S' then variacion_abs
		else 0 end as 'var_Soles'
		,variacion_abs
		,var_s
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB0
		from WT_FLUJOCAJA_Depositos


		IF OBJECT_ID('tempdb..#DEPOSITOS_AYER') IS NOT NULL drop table #DEPOSITOS_AYER
		select  today, GRA_5
		,case when moneda = 'D' then saldoayer
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldoayer
		else 0 end as 'Saldo Sol Mo'
		, saldoayer_s as 'Saldo Total'
		INTO #DEPOSITOS_AYER
		from WT_FLUJOCAJA_Depositos

		IF OBJECT_ID('tempdb..#DEPOSITOS_AYER2') IS NOT NULL drop table #DEPOSITOS_AYER2
		SELECT today ,GRA_5
		,'Ayer' as moneda 
		,SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #DEPOSITOS_AYER2
		FROM #DEPOSITOS_AYER
		GROUP BY today, GRA_5

		IF OBJECT_ID('tempdb..#DEPOSITOS_HOY') IS NOT NULL drop table #DEPOSITOS_HOY
		select  today, GRA_5
		,case when moneda = 'D' then saldohoy
		else 0 end as 'Saldo Dol Mo'
		,case when moneda = 'S' then saldohoy
		else 0 end as 'Saldo Sol Mo'
		, saldohoy_s as 'Saldo Total'
		INTO #DEPOSITOS_HOY
		from WT_FLUJOCAJA_Depositos

	
		IF OBJECT_ID('tempdb..#DEPOSITOS_HOY2') IS NOT NULL drop table #DEPOSITOS_HOY2 
		SELECT today ,GRA_5
		,'Hoy' as moneda 
		,SUM([Saldo Dol Mo]) AS 'Saldo Dol Mo'
		, SUM([Saldo Sol Mo]) AS 'Saldo Sol Mo'
		, SUM([Saldo Total]) AS 'Saldo Total'
		INTO #DEPOSITOS_HOY2
		FROM #DEPOSITOS_HOY
		GROUP BY today, GRA_5


		IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB1') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB1
		SELECT * 
		INTO DWCOOPAC.DBO.WT_FLUJOCAJA_Depositos_TB1
		FROM #DEPOSITOS_AYER2
		UNION 
		SELECT * FROM #DEPOSITOS_HOY2


		----------------------------------------CONTROL DE PRUEBAS----------------------------------------
--select *from DWCOOPAC.DBO.WT_FLUJOCAJA  

        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard Flujo de Caja',null, 'OK'
        --select * from DWCOOPACIFICO.dbo.WT_RUNOFF


------------------------------------------------------------------------------------------------------------------------
	    IF OBJECT_ID('tempdb..#INTERESES') IS NOT NULL drop table #INTERESES
	    SELECT   PG.FECHACANCELACION,  PG.INTERES*-1 AS INTERES, PG.INTERESMORATORIO*-1 AS INTERESMORATORIO,CASE
	    WHEN P.MONEDA =1 THEN 'S'
	    ELSE 'D'
	    END AS MONEDA, P.CODIGOSOLICITUD ,  PG.CONDICION_DESCRI,
	    PG.TIPOMOVIEMIENTO_DESCRI , PG.NUMEROITEM,
	    INTERES_COBRADO = PG.INTERESMORATORIO*-1 +  PG.INTERES*-1
	    ,P.DW_PRODUCTO
	    INTO #INTERESES
	    FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD and p.DW_FECHACARGA = pg.dw_fechaCarga
	    WHERE  PG.ESTADO=1  
	    AND CONDICION_DESCRI != 'Castigo'
	    AND  PG.TIPOMOVIEMIENTO_DESCRI LIKE '%EXTORNO%'--INTERES NEGATIVOS

        UNION
	    SELECT   PG.FECHACANCELACION,  PG.INTERES*-1 as INTERES , PG.INTERESMORATORIO*-1 AS INTERESMORATORIO ,CASE
	    WHEN P.MONEDA =1 THEN 'S'
	    ELSE 'D'
	    END AS MONEDA, P.CODIGOSOLICITUD ,  PG.CONDICION_DESCRI,
	    PG.TIPOMOVIEMIENTO_DESCRI , PG.NUMEROITEM,
	    INTERES_COBRADO = PG.INTERES*-1+ PG.INTERESMORATORIO*-1
	    ,P.DW_PRODUCTO
	    FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD and p.DW_FECHACARGA = pg.dw_fechaCarga
	    WHERE  PG.ESTADO=1 
	    AND PG.CONDICION=5
	    AND PG.CONDICION!=6
	    AND PG.INTERES + PG.INTERESMORATORIO  >= 0 
	    and pg.tipomovimiento =4 --INTERESES NEGATIVOS

        UNION
	    SELECT   PG.FECHACANCELACION,  PG.INTERES , PG.INTERESMORATORIO ,CASE
	    WHEN P.MONEDA =1 THEN 'S'
	    ELSE 'D'
	    END AS MONEDA, P.CODIGOSOLICITUD,  PG.CONDICION_DESCRI,
	    PG.TIPOMOVIEMIENTO_DESCRI , PG.NUMEROITEM, 
	    INTERES_COBRADO = PG.INTERES + PG.INTERESMORATORIO
	    ,P.DW_PRODUCTO
	    FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD and p.DW_FECHACARGA = pg.dw_fechaCarga
	    WHERE  PG.ESTADO=1  
	    AND PG.FECHAEXTORNO IS NULL
	    and pg.tipomovimiento !=4 --39016
	    AND  PG.TIPOMOVIEMIENTO_DESCRI not  LIKE '%EXTORNO%'

        UNION
	    SELECT   PG.FECHACANCELACION,  PG.INTERES , PG.INTERESMORATORIO,CASE
	    WHEN P.MONEDA =1 THEN 'S'
	    ELSE 'D'
	    END AS MONEDA, P.CODIGOSOLICITUD,  PG.CONDICION_DESCRI,
	    PG.TIPOMOVIEMIENTO_DESCRI , PG.NUMEROITEM ,
	    INTERES_COBRADO = PG.INTERES + PG.INTERESMORATORIO
	    ,P.DW_PRODUCTO
	    FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD and p.DW_FECHACARGA = pg.dw_fechaCarga
	    WHERE  PG.ESTADO=1 
	    AND PG.FECHAEXTORNO > PG.FECHACANCELACION
	    --AND PG.FECHAEXTORNO BETWEEN '01-10-2022' AND '31-10-2022' 
	    and pg.tipomovimiento !=4

--===========================================================================================================================================================

	    --IF OBJECT_ID('DWCOOPAC.DBO.WT_FLUJOCAJAPVT') IS NOT NULL drop table DWCOOPAC.DBO.WT_FLUJOCAJAPVT
        delete from DWCOOPAC.DBO.WT_FLUJOCAJAPVT where today >= @fecini
        insert into DWCOOPAC.DBO.WT_FLUJOCAJAPVT
	    SELECT TODAY ,
	    CASE WHEN GRA_5='ENTRADAS' THEN 1
	    ELSE 2 END AS ORDEN_GRA_5,
	    GRA_5,
	    CASE 
            WHEN GRA_4 ='Cobranza de Créditos(Intereses)' THEN 1
	        WHEN GRA_4 ='Cobranza de Créditos (Capital)' THEN 2
	        WHEN GRA_4 ='Captación de Depósitos' THEN 3
	        WHEN GRA_4 ='Captación de Aportes' THEN 4
	        WHEN GRA_4 ='Colocación de Créditos' THEN 5
	        WHEN GRA_4 ='Salida de Depósitos' THEN 6
	        WHEN GRA_4 ='Salida de Aportes' THEN 7
	    END AS ORDEN_GRA_4,
	    GRA_4,
	    CASE WHEN GRA_3 ='' THEN 0
	        WHEN GRA_3 ='Amortización de créditos' THEN 1
	        WHEN GRA_3 ='Cancelaciones de créditos' THEN 2
	        WHEN GRA_3 ='Apertura y crecimiento de Ahorros' THEN 3
	        WHEN GRA_3 ='Apertura de depósitos a plazo' THEN 4
	        WHEN GRA_3 ='Crecimiento de depósitos a plazo' THEN 5
	        WHEN GRA_3 ='Apertura de Aportes' THEN 6
	        WHEN GRA_3 ='Crecimiento de Aportes' THEN 7
	        WHEN GRA_3 ='Incremento de créditos' THEN 8
	        WHEN GRA_3 ='Desembolso de créditos' THEN 9
	        WHEN GRA_3 ='Cancelación y retiro de Ahorros' THEN 10
	        WHEN GRA_3 ='Cancelación de depósitos a plazo' THEN 11
	        WHEN GRA_3 ='Retiro de depósitos a plazo' THEN 12
	        WHEN GRA_3 ='Cancelación de aportes' THEN 13
	        WHEN GRA_3 ='Retiro de aportes' THEN 14
	    END AS ORDEN_GRA_3,
	    GRA_3, [S], [D]
	   -- INTO DBO.WT_FLUJOCAJAPVT
	    FROM (
	            select GRA_5,GRA_4,GRA_3,  variacion_abs, moneda, today 
                from vw_wt_flujocaja
	            where today>=@fecini AND GRA_3!='-'
	            union all
	            SELECT 'ENTRADAS' as GRA_5,'Cobranza de Créditos(Intereses)'as GRA_4,' 'as GRA_3, INTERES_COBRADO as  variacion_abs, MONEDA,FECHACANCELACION 
	            FROM #INTERESES
                where FECHACANCELACION>=@fecini
	            and DW_PRODUCTO not in ('CUO' ,'DSC','PDP','PEL','TAN')
	            and CONDICION_DESCRI != 'Castigo'
		) AS SourceTable  
		    PIVOT  
		    (  
 			    SUM(variacion_abs)  
 			    FOR moneda IN ([S], [D])  
		    ) AS PivotTable;  

        UPDATE WT_FLUJOCAJAPVT SET D=0 WHERE D IS NULL
        UPDATE WT_FLUJOCAJAPVT SET S=0 WHERE S IS NULL

   ------ Creando WT_FLUJOCAJA_INTERES--- Melissa Lozada

     DROP TABLE IF EXISTS WT_FLUJOCAJA_INTERES
		SELECT   
		PG.FECHACANCELACION
	  , PG.INTERES*-1 AS INTERES
	  , PG.INTERESMORATORIO*-1 AS INTERESMORATORIO
	  , CASE WHEN P.MONEDA =1 THEN 'S'ELSE 'D' END AS MONEDA
	  , P.CODIGOSOLICITUD ,  PG.CONDICION_DESCRI
	  , PG.TIPOMOVIEMIENTO_DESCRI 
	  , PG.NUMEROITEM
	  , INTERES_COBRADO = PG.INTERESMORATORIO*-1 +  PG.INTERES*-1
	  , P.DW_PRODUCTO
	  INTO WT_FLUJOCAJA_INTERES
		FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD
		WHERE  PG.ESTADO=1  
		AND CONDICION_DESCRI != 'Castigo'
		AND  PG.TIPOMOVIEMIENTO_DESCRI LIKE '%EXTORNO%'--INTERES NEGATIVOS
	UNION
		SELECT   
		PG.FECHACANCELACION
	  , PG.INTERES*-1 as INTERES 
	  , PG.INTERESMORATORIO*-1 AS INTERESMORATORIO 
	  , CASE WHEN P.MONEDA =1 THEN 'S'ELSE 'D' END AS MONEDA
	  , P.CODIGOSOLICITUD 
	  , PG.CONDICION_DESCRI
	  , PG.TIPOMOVIEMIENTO_DESCRI 
	  , PG.NUMEROITEM
	  , INTERES_COBRADO = PG.INTERES*-1+ PG.INTERESMORATORIO*-1
		,P.DW_PRODUCTO
		FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD
		WHERE  PG.ESTADO=1 
		AND PG.CONDICION=5
		AND PG.CONDICION!=6
		AND PG.INTERES + PG.INTERESMORATORIO  >= 0 
		and pg.tipomovimiento =4 --INTERESES NEGATIVOS

	UNION
		SELECT   
		PG.FECHACANCELACION
	  , PG.INTERES 
	  , PG.INTERESMORATORIO 
	  , CASE WHEN P.MONEDA =1 THEN 'S'ELSE 'D' END AS MONEDA
	  , P.CODIGOSOLICITUD
	  , PG.CONDICION_DESCRI
	  , PG.TIPOMOVIEMIENTO_DESCRI 
	  , PG.NUMEROITEM
	  , INTERES_COBRADO = PG.INTERES + PG.INTERESMORATORIO
	  , P.DW_PRODUCTO
		FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD
		WHERE  PG.ESTADO=1  
		AND PG.FECHAEXTORNO IS NULL
		and pg.tipomovimiento !=4 --39016
		AND  PG.TIPOMOVIEMIENTO_DESCRI not  LIKE '%EXTORNO%'

	UNION
		SELECT   
		PG.FECHACANCELACION
	  , PG.INTERES 
	  , PG.INTERESMORATORIO
	  , CASE WHEN P.MONEDA =1 THEN 'S'ELSE 'D'END AS MONEDA
	  , P.CODIGOSOLICITUD
	  , PG.CONDICION_DESCRI
	  , PG.TIPOMOVIEMIENTO_DESCRI 
	  , PG.NUMEROITEM 
	  , INTERES_COBRADO = PG.INTERES + PG.INTERESMORATORIO
	  , P.DW_PRODUCTO
		FROM DW_PRESTAMO P INNER JOIN DW_PRESTAMO_PAGOS PG ON PG.CODIGOSOLICITUD = P.CODIGOSOLICITUD
		WHERE  PG.ESTADO=1 
		AND PG.FECHAEXTORNO > PG.FECHACANCELACION
		--AND PG.FECHAEXTORNO BETWEEN '01-10-2022' AND '31-10-2022' 
		and pg.tipomovimiento !=4
	

        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard Flujo de Caja PVT',null, 'OK'

	end try
	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'ERROR en la ejecucion del Dashboard Flujo de Caja', @error_message, 'ERROR'

	end catch 
	if @@trancount > 0
		commit transaction		
return 0
