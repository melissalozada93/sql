USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dwt_reporte9]    Script Date: 21/03/2024 16:44:11 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_dwt_reporte9]
as


	DECLARE @FECHA DATE = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE estado = 1)

	DROP TABLE IF EXISTS #PERSONA
	SELECT DISTINCT P.CODIGOPERSONA, P.CIP, P.NOMBRECOMPLETO, P.TIPOPERSONADESCRI, P.TIPODOCUMENTOID, P.NUMERODOCUMENTOID, P.NUMERORUC
	INTO #PERSONA
	FROM DW_PERSONA P
	WHERE P.DW_FECHACARGA = @FECHA

	DROP TABLE IF EXISTS #datossocio
	SELECT distinct
		CODIGOPERSONA, CODIGOSOCIO, CODIGOAGENCIA, FECHAINGRESOCOOP
	INTO #datossocio
	FROM dw_datossocio 
	WHERE DW_FECHACARGA = @FECHA

/*
	DROP TABLE IF EXISTS #R6;
	WITH CTE AS (
		SELECT *
		FROM (
			SELECT CODIGO, MONEDA, IMPORTE
			FROM WT_REPORTE6
		) AS R6
		PIVOT (
			SUM(IMPORTE)
			FOR MONEDA IN ([S], [D])
		) AS PivotTable
	)
	SELECT 
		CODIGO, S = ISNULL(S,0), D = ISNULL(D,0) 
	INTO #R6
	FROM CTE
*/
	DROP TABLE IF EXISTS WT_REPORTE9
	select
		case 
			when p.TIPOPERSONADESCRI = 'Persona Natural' then 'N' 
			else 'J' 
		end as tperson,
		p.CIP as codcippersona,
		p.nombrecompleto, 
		case 
			when p.TIPOPERSONADESCRI = 'Persona Natural' then (
																SELECT 
																	TBLDESCRI
																FROM ISYST900
																WHERE TBLCODTAB = 1 AND TBLCODARG = P.TIPODOCUMENTOID
															)
			else 'RUC' 
		end tipodocumento,
		case 
			when p.TIPOPERSONADESCRI = 'Persona Natural' then p.NUMERODOCUMENTOID
			else convert(varchar,p.numeroruc)
		end numerodocumento,
		cc.productocodigo as producto,
		subproducto = (
					SELECT 
						TBLDESCRIGENERAL
					FROM ISYST902
					WHERE TBLCODTAB = cc.tablaservicio AND TBLCODARG = cc.argumentoservicio
		),
		cc.numerocuenta as numerocuenta,
		case 
			when cc.moneda = 1 then 'S' 
			else 'D' 
		end as moneda,
		FORMAT(dc.montoinicial, 'N2') as montoinicial,
		FORMAT(dcmin.tasainteres, '0.00######') as tasaintmenapert,
		FORMAT(dcmin.tasainteresanual, '0.00') as tasaintanualapert,
		CONVERT(VARCHAR(10), dcmax.fechainicio, 103) as f_inicio_ren,
		CONVERT(VARCHAR(10), dcmax.fechavencimiento, 103) as f_ult_ren,
		FORMAT(dcmax.tasainteres, '0.00######') as tasaintmenactual,
		FORMAT(dcmax.tasainteresanual, '0.00') as tasaintanualactual,
		estado_sol = (
			SELECT 
				TBLDESCRI
			FROM ISYST900
			WHERE TBLCODTAB = 29 AND TBLCODARG = cc.estado
		),
	   CONVERT(VARCHAR(10), cc.fechaapertura, 103) as fechaapertura,
	   FORMAT(cc.saldoimporte1, 'N2') as saldoimporte1,
		agencia_apert = (
			SELECT 
				TBLDESCRI
			FROM ISYST900
			WHERE TBLCODTAB = 32 AND TBLCODARG = cc.codigoagencia
		),
		dc.numerodias, 
		cc.codigousuario, 
		agen_insc_socio = (
			SELECT 
				TBLDESCRI
			FROM ISYST900
			WHERE TBLCODTAB = 32 AND TBLCODARG = dsoc.codigoagencia
		),
	   CONVERT(VARCHAR(10), dsoc.fechaingresocoop, 103) as fechaingresocoop,
	   CONVERT(VARCHAR(10), cc.fecharenuncia, 103) as f_renuncia,
	   CONVERT(VARCHAR(10), cc.ultimomovimiento, 103) as f_ultmov,
	   cantimov = (
			select 
				count(*) 
			from DWT_CUENTAMOVIMIENTO 
			where numerocuenta = cc.numerocuenta
	   ),
		r.cant_renov,
		vinc_regalo = null,
		--case 
		--    when spp.numerooperacion=cc.numerocuenta then 'SI' 
		--    else 'NO' 
		--end as vinc_regalo,
		nombresorteo = null, --s.nombresorteo,
		regalo = null, --sp.descripcion as regalo,
		cts_saldo = (
			select 
				case 
					when count(*)=0 then 'N' 
					else 'S' 
				end 
			from DWT_CUENTACORRIENTE cccts  
			where cccts.codigopersona = cc.codigopersona 
			  and tablaservicio=103 
			  and saldoimporte1>0
		),
		F_CancelaLiquida = CASE 
								WHEN cc.estado = 1 THEN NULL
								ELSE CONVERT(VARCHAR, cc.UltimoMovimiento, 103) -- Formato dd/mm/yyyy
						   END

	INTO WT_REPORTE9
	from DWT_CUENTACORRIENTE cc --25 942

	inner join #PERSONA p 
		on cc.codigopersona = p.codigopersona

	INNER JOIN dwt_datoscuentacorriente dc 
		on  dc.numerocuenta = cc.numerocuenta 
		and dc.fechainicio = cc.fechaapertura
    
	inner join #datossocio dsoc 
		on dsoc.codigopersona = cc.codigopersona
    
	inner join (
				select 
					numerocuenta, 
					min(fechainicio) as fmin, 
					max(fechainicio) as fmax 
				from dwt_datoscuentacorriente 
				group by numerocuenta
	) gfecha 
		on gfecha.numerocuenta = cc.numerocuenta 
    
	inner join dwt_datoscuentacorriente dcmin 
		on dcmin.numerocuenta = cc.numerocuenta 
		and dcmin.fechainicio = gfecha.fmin
    
	inner join dwt_datoscuentacorriente dcmax 
		on dcmax.numerocuenta = cc.numerocuenta 
		and dcmax.fechainicio =  gfecha.fmax

	inner join (
		select 
			numerocuenta, 
			count(numerocuenta)-1 as cant_renov 
		from dwt_datoscuentacorriente
		group by numerocuenta
	) r on r.numerocuenta=cc.numerocuenta 

	/*
	left join sorteo_persona_premio spp 
		on spp.numerooperacion=cc.numerocuenta 

	left join sorteo s 
		on s.codigosorteo = spp.codigosorteo 
		and s.periodo = spp.periodo 
		and s.tiposorteo = spp.tiposorteo 

	left join sorteo_premio sp 
		on sp.codigosorteo=spp.codigosorteo 
		and sp.periodo=spp.periodo 
		and sp.tiposorteo=spp.tiposorteo 
		and sp.codigopremio=spp.codigopremio
	*/
	where cc.tablaservicio=102 
	  and cc.estado=1 
	  --and trunc(fechaapertura) between P_FINICIO and P_FFIN
	order by cts_saldo

	--DROP TABLE IF EXISTS WT_REPORTE9
	--SELECT 
	--	R9.*, 
	--	DINEROFRESCO = ISNULL(
	--					CASE 
	--						WHEN ISNULL(CASE WHEN R9.MONEDA = 'S' THEN R6.S	ELSE R6.D END,0)>REPLACE(R9.montoinicial, ',', '') THEN REPLACE(R9.montoinicial, ',', '')
	--						ELSE ISNULL(CASE WHEN R9.MONEDA = 'S' THEN R6.S	ELSE R6.D END,0)
	--					END
	--					,0),
	--	RENOVACION = REPLACE(R9.montoinicial, ',', '') - ISNULL(
	--														CASE 
	--															WHEN ISNULL(CASE WHEN R9.MONEDA = 'S' THEN R6.S	ELSE R6.D END,0)>REPLACE(R9.montoinicial, ',', '') THEN REPLACE(R9.montoinicial, ',', '')
	--															ELSE ISNULL(CASE WHEN R9.MONEDA = 'S' THEN R6.S	ELSE R6.D END,0)
	--														END
	--													,0)
	--into WT_REPORTE9
	--FROM #WT_REPORTE9 R9
	--LEFT JOIN #R6 R6
	--	ON R6.CODIGO = R9.CODCIPPERSONA

--select * from WT_REPORTE9

	/*
		select COUNT(*)
	from DWT_CUENTACORRIENTE
	where tablaservicio=102 
	  and estado=1 
	  */

--SELECT * FROM WT_REPORTE9