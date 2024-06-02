--USE [DWCOOPAC]
--GO
--/****** Object:  StoredProcedure [dbo].[usp_dashm_dpfmarketing]    Script Date: 01/02/2024 10:45:33 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--CREATE procedure [dbo].[usp_dashm_dpfmarketing2]
--as
--set nocount on --
--set xact_abort on
--	begin transaction
--	begin try


 DECLARE @fecha DATE = (SELECT fecha FROM ST_FECHAMAESTRA WHERE estado = 1)--cast(getdate()-1 as date)--'2023-07-26'

 --------ORIGINACIÓN-----------------------------------------------------------------------------
	 DROP TABLE IF EXISTS #ORIGINACION
	 SELECT DISTINCT 
		NUMEROCUENTA
	  , CODIGOUSUARIO
	  , TASAINTERESMENSUALPERTURA
	  , TASAINTERESMENSUALACTUAL
	  , TASAINTERESANUALAPERTURA
	  , TASAINTERESANUALACTUAL
	  , TABLASERVICIO
	  , ARGUMENTOSERVICIO 
	  , FECHAAPERTURA
	  , ORIGINACION = CASE WHEN CODIGOUSUARIO = 'AGVIRTUAL' THEN 'DIGITAL' ELSE 'PRESENCIAL' END
	  INTO #ORIGINACION
	  FROM DW_CUENTACORRIENTE 
	  WHERE dw_fechaCarga = @fecha--'2023-07-19'


 --------LIQUIDACIÓN-----------------------------------------------------------------------------
      DROP TABLE IF EXISTS #LIQ
      SELECT 
	     FECHACANCELACION= CASE WHEN FECHACANCELACION = '-' THEN NULL ELSE FECHACANCELACION END 
	   , ESTADO
	   , NROCUENTA
	   , CODIGOSOCIO
	   , PERSONERIA
	   , MONEDA
	   , TIPOCAMBIO
	   , IMPORTECANCELADO
	   , IMPORTECANCELADO_SOLES
	   , SALDO
	   , SALDO_SOLES
	   , PRODUCTO
       , PLAZODIASO = PLAZODIAS
       , AGENCIAAPERTURA
       , CANCELACIONANTICIPADA
       , NRORENOVACION----------- rev
       , NOMB_PRODUCTO
       , AGRUPAMIENTO =
          CASE 
            WHEN PRODUCTO IN ('CDM','CDJ','CDB','CDA') THEN 'DEP. JAPON'
            WHEN PRODUCTO IN ('CTS','CPR','CDP','CDM','CDJ','CDE','CDB') THEN 'DEP. A PLAZO'
            WHEN PRODUCTO IN ('DPF') AND NOMB_PRODUCTO = 'DPF AFP' AND PLAZODIAS = '5400' THEN 'BANCA MASTER'
            WHEN PRODUCTO IN ('CTG','ATS','ASD','AMW','AHV','AHP','ACV','AHF') THEN 'AHORROS'--> CAMBIO SOLICITADO POR CARINA Y GLORIA: 2023-11-13 - LFC
            WHEN PRODUCTO IN ('APO','501','502') THEN 'APORTES'
            ELSE '----------------------------'
          END
        INTO #LIQ
        FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS
        WHERE FECHA = @fecha 
        AND ESTADO in ('Activa','Liquidada') AND (TIPOPRODUCTO = 'Plazo Fijo' OR PRODUCTO = 'AHF')--> CAMBIO SOLICITADO POR CARINA Y GLORIA: 2023-11-13 - LFC
        --and estado = 'Liquidada'154069
		AND (FECHACANCELACION >= '2018-01-01' OR FECHACANCELACION ='-')

	

 --------DATOS CUENTA CORRIENTE-----------------------------------------------------------------------------
		DROP TABLE IF EXISTS #DATOSCUENTACORRIENTE
        SELECT A.* ,
		PLAZODIAS_O= CASE WHEN NUMERODIAS IN (3600,5400,30,60,90,180,360,720,1080,1800) THEN CONVERT(varchar,NUMERODIAS) ELSE 'OTROS' END,
		ORDENPLAZODIAS_O = CASE
                            WHEN NUMERODIAS = '30' THEN 1
                            WHEN NUMERODIAS = '60' THEN 2
                            WHEN NUMERODIAS = '90' THEN 3
                            WHEN NUMERODIAS = '180' THEN 4
                            WHEN NUMERODIAS = '360' THEN 5
                            WHEN NUMERODIAS = '720' THEN 6
                            WHEN NUMERODIAS = '1080' THEN 7
                            WHEN NUMERODIAS = '1800' THEN 8
                            WHEN NUMERODIAS = '3600' THEN 9
                            WHEN NUMERODIAS = '5400' THEN 10
                            ELSE 11
                           -- when DC.NUMERODIAS = 'OTROS' then 11
                            END,
		FLAG_APERTURA = CASE WHEN (ROW_NUMBER() OVER(PARTITION BY NUMEROCUENTA ORDER BY FECHAINICIO ASC))=1 THEN 1 ELSE 0 END,
		MONTOAPERTURA = CASE WHEN (ROW_NUMBER() OVER(PARTITION BY NUMEROCUENTA ORDER BY FECHAINICIO ASC))=1 THEN MONTOINICIAL ELSE 0 END
        INTO #DATOSCUENTACORRIENTE
        FROM DW_DATOSCUENTACORRIENTE a
        WHERE NUMEROCUENTA IN (SELECT DISTINCT NROCUENTA FROM #LIQ)
        AND A.dw_fechacarga = @fecha--'2023-07-19' 
		AND A.FECHAINICIO<=@fecha




        CREATE INDEX IND_#datoscuentacorrientexnumerocuenta on #DATOSCUENTACORRIENTE(numerocuenta)
        WITH (DROP_EXISTING = off)

		DROP TABLE IF EXISTS #FECHAVENCIMIENTO
		SELECT NUMEROCUENTA, MAX(FECHAVENCIMIENTO)FECHAVENCIMIENTO
		INTO #FECHAVENCIMIENTO
		FROM #DATOSCUENTACORRIENTE
		GROUP BY NUMEROCUENTA


 --------DATOS CUENTA CORRIENTE-----------------------------------------------------------------------------		
		DROP TABLE IF EXISTS #DATOSCUENTACORRIENTECANCELACION
		SELECT * 
		INTO #DATOSCUENTACORRIENTECANCELACION
		FROM #DATOSCUENTACORRIENTE
		WHERE NUMEROCUENTA IN(
		SELECT NUMEROCUENTA
		FROM #DATOSCUENTACORRIENTE
		GROUP BY NUMEROCUENTA
		HAVING COUNT(*) < 2)


 --------CUENTAS SALDOS-----------------------------------------------------------------------------
        DROP TABLE IF EXISTS #DW_CUENTASALDOS
        SELECT DW_FECHACARGA, NUMEROCUENTA, SALDOIMPORTE1
        INTO #DW_CUENTASALDOS
        FROM DW_CUENTASALDOS 
        WHERE DW_FECHACARGA >= '2023-07-01' 
		AND NUMEROCUENTA IN (SELECT DISTINCT NUMEROCUENTA FROM #DATOSCUENTACORRIENTE)
        UNION
        SELECT FECHA, NUMEROCUENTA, SALDOIMPORTE1 FROM TemporalesDW.DBO.ST_DPFMONTOSINICIALES_MKT WHERE FECHA < '2023-07-01'
		AND NUMEROCUENTA IN (SELECT DISTINCT NUMEROCUENTA FROM #DATOSCUENTACORRIENTE)

		CREATE INDEX IND_#DW_CUENTASALDOSxnumerocuenta on #DW_CUENTASALDOS(numerocuenta)
        WITH (DROP_EXISTING = off)




 --------ABONO INTERESES-----------------------------------------------------------------------------
        DROP TABLE IF EXISTS #ABONOINTERESES
		SELECT AA.NUMEROCUENTA, AA.FECHAINICIO, AA.FECHAVENCIMIENTO, ABONOINTERES = SUM(AA.IMPORTE1) 
		INTO #ABONOINTERESES
        FROM (
		SELECT 
		DCM.NUMEROCUENTA,DCC.FECHAINICIO,DCC.FECHAVENCIMIENTO,DCM.IMPORTE1 
		FROM  DW_CUENTAMOVIMIENTO DCM
		LEFT JOIN #DATOSCUENTACORRIENTE DCC ON DCM.NUMEROCUENTA=DCC.NUMEROCUENTA
		WHERE DCM.TIPOMOVIMIENTO = 5 
              AND DCM.FORMAPAGO = 3 
              AND DCM.CODIGOUSUARIO = 'SISGODBA' 
              AND DCM.ESTADO = 1
              AND DCM.NUMEROCUENTA ='000636923007'
              AND DCM.OBSERVACION LIKE 'Abono de Interes%'
              AND DCM.FECHAMOVIMIENTO BETWEEN DCC.FECHAINICIO and DCC.FECHAVENCIMIENTO)AA
        GROUP BY AA.NUMEROCUENTA, AA.FECHAINICIO,AA.FECHAVENCIMIENTO
        ORDER BY AA.NUMEROCUENTA


 --------DATOS SOCIOS----------------------------------------------------------------------------
        DROP TABLE IF EXISTS #DATOSSOCIO
        SELECT DISTINCT CODIGOSOCIO, TIPO_ENTIDAD 
        INTO #DATOSSOCIO
        FROM DW_DATOSSOCIO WHERE dw_fechaCarga = @FECHA

 --------DATOS PERSONA----------------------------------------------------------------------------
		DROP TABLE IF EXISTS #PERSONA
		SELECT DISTINCT CIP, SEXO, EDAD, FECHAINGRESOCOOP, NOMBRECOMPLETO, NOMBRECORTO 
		INTO #PERSONA
		from DW_PERSONA
        WHERE dw_fechaCarga=@fecha AND CIP !='-'


 --------DATOS CONTABILIDAD----------------------------------------------------------------------------
		DROP TABLE IF EXISTS #CONTABILIDAD		
		SELECT DISTINCT CODIGOSOCIO,PROVINCIADP,DPTODP, PAISDP
		INTO #CONTABILIDAD
		FROM WT_CONTACTABILIDAD
		WHERE dw_fechaCarga = @fecha
		and CODIGOSOCIO in (SELECT distinct codigoSocio FROM #DATOSSOCIO)


 --------CANCELACIÓN CUENTA----------------------------------------------------------------------------
		DROP TABLE IF EXISTS #CANCELACION_CUENTA
		SELECT * 
		INTO #CANCELACION_CUENTA
		FROM (
		SELECT DISTINCT A.NUMEROCUENTA, A.DW_TIPOMOTIVODESCRI, A.DW_ESTADODESCRI, N= ROW_NUMBER() OVER(PARTITION BY NUMEROCUENTA ORDER BY A.DW_FECHACARGA DESC)	
		FROM DW_CANCELACIONCUENTA  A
		INNER JOIN DW_CAJA B
		ON A.NUMEROCAJA=B.NUMEROCAJA AND A.PERIODOCAJA=B.PERIODOCAJA and A.CODIGOUSUARIO=B.CODIGOUSUARIO AND B.ESTADO=1) A
		WHERE A.N=1




 --DECLARE @fecha DATE = (SELECT fecha FROM ST_FECHAMAESTRA WHERE estado = 1)--cast(getdate()-1 as date)--'2023-07-26'
		DROP TABLE IF EXISTS DBO.TEMP_WT_DPF_MARKETING
		SELECT  DISTINCT
	      DCC.DW_FECHACARGA
		, DCC.FECHAINICIO
		, DCC.FECHAVENCIMIENTO
		, DCC.NUMEROCUENTA
		, PLAZODIAS = DCC.NUMERODIAS
		, O.FECHAAPERTURA
		, O.TASAINTERESMENSUALPERTURA
		, O.TASAINTERESMENSUALACTUAL
		, O.TASAINTERESANUALAPERTURA
		, O.TASAINTERESANUALACTUAL
		, O.TABLASERVICIO
		, O.ARGUMENTOSERVICIO
		, L.FECHACANCELACION
		, ESTADOCUENTA = L.ESTADO
		, L.MONEDA
		, L.TIPOCAMBIO
		, L.CODIGOSOCIO
		, L.PERSONERIA
		, L.PRODUCTO
		, L.NOMB_PRODUCTO
		, AGENCIA = L.AGENCIAAPERTURA
		, QR.QRENOVACIONES
		, L.AGRUPAMIENTO
		, DCC.PLAZODIAS_O
		, DCC.ORDENPLAZODIAS_O
		, DCC.MONTOAPERTURA
		, CANAL = O.ORIGINACION
		, ABONOINTERES = ISNULL(AB.ABONOINTERES,0)
		, FECVENCAN = CASE WHEN L.ESTADO = 'Liquidada' AND 
		                      L.FECHACANCELACION BETWEEN DCC.FECHAINICIO AND DCC.FECHAVENCIMIENTO THEN L.FECHACANCELACION--fechacancelacion
                              WHEN DCC.FECHAVENCIMIENTO>@fecha THEN NULL  --cuentacorriente//estado 
						      ELSE CONVERT(VARCHAR,DCC.FECHAVENCIMIENTO)
						 END
		, ESTADO_RE = CASE WHEN ( CASE WHEN L.ESTADO = 'Liquidada' AND 
		                      L.FECHACANCELACION BETWEEN DCC.FECHAINICIO AND DCC.FECHAVENCIMIENTO THEN L.FECHACANCELACION--fechacancelacion
                              WHEN DCC.FECHAVENCIMIENTO>@fecha THEN NULL  --cuentacorriente//estado 
						      ELSE CONVERT(VARCHAR,DCC.FECHAVENCIMIENTO)
						 END) IS NULL THEN L.ESTADO ELSE 'Liquidada' END
		, MONTOINICIAL =  CASE WHEN DCC.MONTOINICIAL = 0 THEN CS.SALDOIMPORTE1 ELSE DCC.MONTOINICIAL END
        , MONTOINICIAL_SOLES = CASE WHEN DCC.MONTOINICIAL = 0 THEN 
											CASE WHEN l.MONEDA = 'Dólares' THEN CS.SALDOIMPORTE1 *L.TIPOCAMBIO ELSE CS.SALDOIMPORTE1 END
		                               ELSE CASE WHEN l.MONEDA = 'Dólares' THEN DCC.MONTOINICIAL*L.TIPOCAMBIO ELSE DCC.MONTOINICIAL END END
		
		, CANCELACIONANTICIPADA_RE = CASE WHEN DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL THEN '-' 
                                             WHEN L.FECHACANCELACION  < DCC.FECHAVENCIMIENTO THEN 'SI' 
                                             ELSE 'NO' end 
		, SALDO = CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL THEN L.SALDO ELSE 0 END
		, SALDO_SOLES = CASE WHEN ( CASE WHEN L.ESTADO = 'Liquidada' AND 
		                      L.FECHACANCELACION BETWEEN DCC.FECHAINICIO AND DCC.FECHAVENCIMIENTO THEN L.FECHACANCELACION--fechacancelacion
                              WHEN DCC.FECHAVENCIMIENTO>@fecha THEN NULL  --cuentacorriente//estado 
						      ELSE CONVERT(VARCHAR,DCC.FECHAVENCIMIENTO)
						 END) IS NULL THEN L.SALDO_SOLES ELSE 0 END
		, CONCENTRACION_SALDOS = CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL 
									THEN CASE 
                                        WHEN SALDO_SOLES BETWEEN 0.0 AND 5000.99 THEN 'De 1,000 a 5,000'
                                        WHEN SALDO_SOLES BETWEEN 5001.0 AND 10000.99 THEN 'De 5,001 a 10,000'
                                        WHEN SALDO_SOLES BETWEEN 10001.0 AND 15000.99 THEN 'De 10,001 a 15,000'
                                        WHEN SALDO_SOLES BETWEEN 15001.0 AND 25000.99 THEN 'De 15,001 a 25,000'
                                        WHEN SALDO_SOLES BETWEEN 25001.0 AND 50000.99 THEN 'De 25,001 a 50,000'
                                        WHEN SALDO_SOLES BETWEEN 50001.0 AND 100000.99 THEN 'De 50,001 a 100,000'
                                        WHEN SALDO_SOLES BETWEEN 100001.0 AND 500000.99 THEN 'De 100,001 a 500,000'
                                        WHEN SALDO_SOLES >= 500001.0 THEN 'De 500,000 a más'
                                        ELSE '-'
                                    END ELSE '-' END
	     , CONCENTRACION_SALDOS_O =  CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL 
									THEN CASE 
                                        WHEN SALDO_SOLES BETWEEN 0.0 AND 5000.99 THEN 1
                                        WHEN SALDO_SOLES BETWEEN 5001.0 AND 10000.99 THEN 2
                                        WHEN SALDO_SOLES BETWEEN 10001.0 AND 15000.99 THEN 3
                                        WHEN SALDO_SOLES BETWEEN 15001.0 AND 25000.99 THEN 4
                                        WHEN SALDO_SOLES BETWEEN 25001.0 AND 50000.99 THEN 5
                                        WHEN SALDO_SOLES BETWEEN 50001.0 AND 100000.99 THEN 6
                                        WHEN SALDO_SOLES BETWEEN 100001.0 AND 500000.99 THEN 7
                                        WHEN SALDO_SOLES >= 500001.0 THEN 8
                                        ELSE 999
                                    END ELSE 0 END
         , IMPORTECANCELADO =   CASE WHEN A.NUMEROCUENTA IS NOT NULL THEN 0 ELSE
										CASE WHEN  F.FECHAVENCIMIENTO IS NULL THEN 0 
											 WHEN  L.ESTADO='Liquidada'  THEN  L.IMPORTECANCELADO
										ELSE 0 END END
		 , IMPORTECANCELADO_SOLES = CASE WHEN A.NUMEROCUENTA IS NOT NULL THEN 0 ELSE
										CASE WHEN  F.FECHAVENCIMIENTO IS NULL THEN 0 
											 WHEN  L.ESTADO='Liquidada'  THEN  L.IMPORTECANCELADO_SOLES
										ELSE 0 END END
		 , ABONOINTERES_SOLES = CASE WHEN L.MONEDA = 'Dólares' THEN ISNULL(AB.ABONOINTERES,0)*L.TIPOCAMBIO ELSE ISNULL(AB.ABONOINTERES,0) END
		 , IMPORTE_CANCELADO_INTERES = CASE WHEN L.MONEDA = 'Dólares' THEN L.IMPORTECANCELADO_SOLES+(ISNULL(AB.ABONOINTERES,0)*L.TIPOCAMBIO) 
											   ELSE L.IMPORTECANCELADO_SOLES+ISNULL(AB.ABONOINTERES,0) end
		 , DCC.FLAG_APERTURA
		 , MONTOAPERTURA_SOLES= CASE WHEN DCC.FLAG_APERTURA=1 THEN
											CASE WHEN l.MONEDA = 'Dólares' THEN DCC.MONTOINICIAL*L.TIPOCAMBIO ELSE DCC.MONTOINICIAL END END 

		 , FLAG_CANCELACION = CASE WHEN A.NUMEROCUENTA IS NOT NULL THEN 0 ELSE
									CASE WHEN  F.FECHAVENCIMIENTO IS NULL THEN 0 
										 WHEN  L.ESTADO='Liquidada' THEN 1 
									ELSE 0 END END
		 , FLAG_DIARIO = 0
	     , FLAG_FIN = CASE WHEN A.NUMEROCUENTA IS NOT NULL THEN 0 ELSE
								CASE WHEN  L.ESTADO='Liquidada' AND DCC.FECHAVENCIMIENTO > L.FECHACANCELACION  THEN 1 ELSE 0 END END
		 , DS.TIPO_ENTIDAD
		 , TIPO_PRODUCTO = IIF(L.PRODUCTO='AHF','SI','NO')
		 , P.NOMBRECOMPLETO
		 , p.SEXO
		 , p.EDAD
		 , p.FECHAINGRESOCOOP
		 , CANCELACION_CUENTA = IIF(CC.DW_TIPOMOTIVODESCRI  IS NOT NULL,'SI','NO')
		 , CC.DW_TIPOMOTIVODESCRI
		 , FECHA = ISNULL(CASE WHEN FLAG_APERTURA=1 THEN FECHAAPERTURA 
						WHEN L.ESTADO='Liquidada' AND F.FECHAVENCIMIENTO > L.FECHACANCELACION  THEN L.FECHACANCELACION
						ELSE NULL END,DCC.FECHAVENCIMIENTO)
         , FLAG=1
		 , CANCELACIONANTICIPADA_C=  CASE WHEN l.FECHACANCELACION < DCC.FECHAVENCIMIENTO AND qr.QRENOVACIONES = 0 THEN 'SI' ELSE 'NO' END  
		 , [dbo].[InitCap](PROVINCIADP)PROVINCIADP
		 , [dbo].[InitCap](DPTODP)DPTODP
		 , [dbo].[InitCap](PAISDP)PAISDP
		 , FECHAACTUALIZACION = @fecha
		INTO DBO.TEMP_WT_DPF_MARKETING
		FROM #DATOSCUENTACORRIENTE DCC
		LEFT JOIN #FECHAVENCIMIENTO F ON DCC.NUMEROCUENTA = F.NUMEROCUENTA AND DCC.FECHAVENCIMIENTO = F.FECHAVENCIMIENTO
		LEFT JOIN #LIQ L ON DCC.NUMEROCUENTA = L.NROCUENTA 
		LEFT JOIN #ORIGINACION O ON DCC.NUMEROCUENTA = O.NUMEROCUENTA
		LEFT JOIN #DW_CUENTASALDOS CS ON CS.NUMEROCUENTA = DCC.NUMEROCUENTA AND CS.dw_fechaCarga = DCC.FECHAINICIO
		LEFT JOIN #ABONOINTERESES AB ON AB.FECHAINICIO = DCC.FECHAINICIO AND AB.FECHAVENCIMIENTO = DCC.FECHAVENCIMIENTO
		LEFT JOIN (SELECT NUMEROCUENTA, QRENOVACIONES = COUNT(*) - SUM(FLAG_APERTURA) from #DATOSCUENTACORRIENTE GROUP BY NUMEROCUENTA) QR ON QR.NUMEROCUENTA = DCC.NUMEROCUENTA
		LEFT JOIN #DATOSSOCIO DS ON DS.CODIGOSOCIO = L.CODIGOSOCIO
		LEFT JOIN #PERSONA P ON P.CIP=L.CODIGOSOCIO
		LEFT JOIN (SELECT DISTINCT NUMEROCUENTA FROM #DATOSCUENTACORRIENTECANCELACION) A ON A.NUMEROCUENTA=DCC.NUMEROCUENTA
		LEFT JOIN #CANCELACION_CUENTA CC ON CC.NUMEROCUENTA=DCC.NUMEROCUENTA AND L.ESTADO=CC.DW_ESTADODESCRI
		LEFT JOIN #CONTABILIDAD C ON C.CODIGOSOCIO=L.CODIGOSOCIO 
		UNION


		SELECT  DISTINCT
	      DCC.DW_FECHACARGA
		, DCC.FECHAINICIO
		, DCC.FECHAVENCIMIENTO
		, DCC.NUMEROCUENTA
		, PLAZODIAS = DCC.NUMERODIAS
		, O.FECHAAPERTURA
		, O.TASAINTERESMENSUALPERTURA
		, O.TASAINTERESMENSUALACTUAL
		, O.TASAINTERESANUALAPERTURA
		, O.TASAINTERESANUALACTUAL
		, O.TABLASERVICIO
		, O.ARGUMENTOSERVICIO
		, L.FECHACANCELACION
		, ESTADOCUENTA = L.ESTADO
		, L.MONEDA
		, L.TIPOCAMBIO
		, L.CODIGOSOCIO
		, L.PERSONERIA
		, L.PRODUCTO
		, L.NOMB_PRODUCTO
		, AGENCIA = L.AGENCIAAPERTURA
		, QR.QRENOVACIONES
		, L.AGRUPAMIENTO
		, DCC.PLAZODIAS_O
		, DCC.ORDENPLAZODIAS_O
		, DCC.MONTOAPERTURA
		, CANAL = O.ORIGINACION
		, ABONOINTERES = ISNULL(AB.ABONOINTERES,0)
		, FECVENCAN = CASE WHEN L.ESTADO = 'Liquidada' AND 
		                      L.FECHACANCELACION BETWEEN DCC.FECHAINICIO AND DCC.FECHAVENCIMIENTO THEN L.FECHACANCELACION--fechacancelacion
                              WHEN DCC.FECHAVENCIMIENTO>@fecha THEN NULL  --cuentacorriente//estado 
						      ELSE CONVERT(VARCHAR,DCC.FECHAVENCIMIENTO)
						 END
		, ESTADO_RE = ''
		, MONTOINICIAL =  0
        , MONTOINICIAL_SOLES = 0
		, CANCELACIONANTICIPADA_RE = CASE WHEN DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL THEN '-' 
                                             WHEN L.FECHACANCELACION  < DCC.FECHAVENCIMIENTO THEN 'SI' 
                                             ELSE 'NO' end 
		, SALDO = CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL THEN L.SALDO ELSE 0 END
		, SALDO_SOLES = 0
		, CONCENTRACION_SALDOS = CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL 
									THEN CASE 
                                        WHEN SALDO_SOLES BETWEEN 0.0 AND 5000.99 THEN 'De 1,000 a 5,000'
                                        WHEN SALDO_SOLES BETWEEN 5001.0 AND 10000.99 THEN 'De 5,001 a 10,000'
                                        WHEN SALDO_SOLES BETWEEN 10001.0 AND 15000.99 THEN 'De 10,001 a 15,000'
                                        WHEN SALDO_SOLES BETWEEN 15001.0 AND 25000.99 THEN 'De 15,001 a 25,000'
                                        WHEN SALDO_SOLES BETWEEN 25001.0 AND 50000.99 THEN 'De 25,001 a 50,000'
                                        WHEN SALDO_SOLES BETWEEN 50001.0 AND 100000.99 THEN 'De 50,001 a 100,000'
                                        WHEN SALDO_SOLES BETWEEN 100001.0 AND 500000.99 THEN 'De 100,001 a 500,000'
                                        WHEN SALDO_SOLES >= 500001.0 THEN 'De 500,000 a más'
                                        ELSE '-'
                                    END ELSE '-' END
	     , CONCENTRACION_SALDOS_O =  CASE WHEN  DCC.FECHAVENCIMIENTO>@fecha OR L.FECHACANCELACION IS NULL 
									THEN CASE 
                                        WHEN SALDO_SOLES BETWEEN 0.0 AND 5000.99 THEN 1
                                        WHEN SALDO_SOLES BETWEEN 5001.0 AND 10000.99 THEN 2
                                        WHEN SALDO_SOLES BETWEEN 10001.0 AND 15000.99 THEN 3
                                        WHEN SALDO_SOLES BETWEEN 15001.0 AND 25000.99 THEN 4
                                        WHEN SALDO_SOLES BETWEEN 25001.0 AND 50000.99 THEN 5
                                        WHEN SALDO_SOLES BETWEEN 50001.0 AND 100000.99 THEN 6
                                        WHEN SALDO_SOLES BETWEEN 100001.0 AND 500000.99 THEN 7
                                        WHEN SALDO_SOLES >= 500001.0 THEN 8
                                        ELSE 999
                                    END ELSE 0 END
         , IMPORTECANCELADO =  CASE WHEN  L.ESTADO='Liquidada'   THEN L.IMPORTECANCELADO ELSE 0 END
								
		 , IMPORTECANCELADO_SOLES = CASE WHEN  L.ESTADO='Liquidada'   THEN L.IMPORTECANCELADO_SOLES ELSE 0 END
		 , ABONOINTERES_SOLES = CASE WHEN L.MONEDA = 'Dólares' THEN ISNULL(AB.ABONOINTERES,0)*L.TIPOCAMBIO ELSE ISNULL(AB.ABONOINTERES,0) END
		 , IMPORTE_CANCELADO_INTERES = CASE WHEN L.MONEDA = 'Dólares' THEN L.IMPORTECANCELADO_SOLES+(ISNULL(AB.ABONOINTERES,0)*L.TIPOCAMBIO) 
											   ELSE L.IMPORTECANCELADO_SOLES+ISNULL(AB.ABONOINTERES,0) end
		 , FLAG_APERTURA = 0
		 , MONTOAPERTURA_SOLES = 0
		 , FLAG_CANCELACION = CASE WHEN  F.FECHAVENCIMIENTO IS NULL THEN 0 
										 WHEN  L.ESTADO='Liquidada'  THEN 1 
									ELSE 0 END
		 , FLAG_DIARIO = 0
	     , FLAG_FIN = 1
		 , DS.TIPO_ENTIDAD
		 , TIPO_PRODUCTO = IIF(L.PRODUCTO='AHF','SI','NO')
		 , P.NOMBRECOMPLETO
		 , p.SEXO
		 , p.EDAD
		 , p.FECHAINGRESOCOOP
		 , CANCELACION_CUENTA = IIF(CC.DW_TIPOMOTIVODESCRI  IS NOT NULL,'SI','NO')
		 , CC.DW_TIPOMOTIVODESCRI
		 , FECHA = ISNULL(L.FECHACANCELACION,DCC.FECHAVENCIMIENTO)
		 , FLAG=0
		 , CANCELACIONANTICIPADA_C=  CASE WHEN l.FECHACANCELACION < DCC.FECHAVENCIMIENTO AND qr.QRENOVACIONES = 0 THEN 'SI' ELSE 'NO' END  
		 , [dbo].[InitCap](PROVINCIADP)PROVINCIADP
		 , [dbo].[InitCap](DPTODP)DPTODP
		 , [dbo].[InitCap](PAISDP)PAISDP
		 , FECHAACTUALIZACION = @fecha
		FROM #DATOSCUENTACORRIENTECANCELACION DCC
		LEFT JOIN #FECHAVENCIMIENTO F ON DCC.NUMEROCUENTA = F.NUMEROCUENTA AND DCC.FECHAVENCIMIENTO = F.FECHAVENCIMIENTO
		LEFT JOIN #LIQ L ON DCC.NUMEROCUENTA = L.NROCUENTA 
		LEFT JOIN #ORIGINACION O ON DCC.NUMEROCUENTA = O.NUMEROCUENTA
		LEFT JOIN #DW_CUENTASALDOS CS ON CS.NUMEROCUENTA = DCC.NUMEROCUENTA AND CS.dw_fechaCarga = DCC.FECHAINICIO
		LEFT JOIN #ABONOINTERESES AB ON AB.FECHAINICIO = DCC.FECHAINICIO AND AB.FECHAVENCIMIENTO = DCC.FECHAVENCIMIENTO
		LEFT JOIN (SELECT NUMEROCUENTA, QRENOVACIONES = COUNT(*) - SUM(FLAG_APERTURA) from #DATOSCUENTACORRIENTE GROUP BY NUMEROCUENTA) QR ON QR.NUMEROCUENTA = DCC.NUMEROCUENTA
		LEFT JOIN #DATOSSOCIO DS ON DS.CODIGOSOCIO = L.CODIGOSOCIO
		LEFT JOIN #PERSONA P ON P.CIP=L.CODIGOSOCIO
		LEFT JOIN (SELECT DISTINCT NUMEROCUENTA FROM #DATOSCUENTACORRIENTECANCELACION) A ON A.NUMEROCUENTA=DCC.NUMEROCUENTA
		LEFT JOIN #CANCELACION_CUENTA CC ON CC.NUMEROCUENTA=DCC.NUMEROCUENTA AND L.ESTADO=CC.DW_ESTADODESCRI
		LEFT JOIN #CONTABILIDAD C ON C.CODIGOSOCIO=L.CODIGOSOCIO 
		
		

        --====================================================================================================================
        --====================================================================================================================

--        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'Ejecucion Exitosa del Dashboard DPF Marketing 2',null, 'OK'

     
--	end try
--	begin catch
--		rollback transaction

--		declare @error_message varchar(4000), @error_severity int, @error_state int
--		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
--		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'ERROR en la ejecucion del Dashboard DPF Marketing 2', @error_message, 'ERROR'

--	end catch 
--	if @@trancount > 0
--		commit transaction		
--return 0


SELECT 
  NUMEROCUENTA
, MONTOAPERTURA
, MONTOAPERTURA_SOLES
, ID_MONEDA=IIF(MONEDA='Dólares',2,1)
, AÑO=YEAR(FECHAAPERTURA)
, MONEDA
FROM TEMP_WT_DPF_MARKETING WHERE  FLAG_APERTURA=1 ---AND MONTOAPERTURA>0
and year(FECHAAPERTURA)>=2018
and NUMEROCUENTA='000001113001'

SELECT MONTOAPERTURA,MONTOAPERTURA_SOLES,
MONTOINICIAL,MONTOINICIAL_SOLES
FLAG_APERTURA,*
FROM TEMP_WT_DPF_MARKETING 
WHERE NUMEROCUENTA='003588413001'

SELECT MONTOINICIAL, MONTOINICIAL_SOLES,* FROM WT_REPORTEPASIVAS
WHERE NROCUENTA='003588413001'
ORDER  BY FECHAAPERTURA ASC

SELECT MONTOINICIAL,* FROM
#DATOSCUENTACORRIENTE
WHERE NUMEROCUENTA='003588413001'


SELECT MONTOINICIAL,* FROM
DW_DATOSCUENTACORRIENTE DCC
WHERE NUMEROCUENTA='003588413001'
ORDER BY DCC.MONTOINICIAL ASC


SELECT MONTOINICIAL,* FROM
vW_DATOSCUENTACORRIENTE DCC
WHERE NUMEROCUENTA='003588413001'
ORDER BY DCC.MONTOINICIAL ASC
