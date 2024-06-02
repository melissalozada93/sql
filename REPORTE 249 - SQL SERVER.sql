--USE [DWCOOPAC]
--GO
--/****** Object:  StoredProcedure [dbo].[usp_dashm_dpfmarketing_stock]    Script Date: 15/02/2024 18:38:46 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--alter procedure [dbo].[usp_dash_solicititud_trans_Pacinet]
--as
--set nocount on --
--set xact_abort on
--	begin transaction
--	begin try

DECLARE @FechaActual DATE = (SELECT FECHA FROM ST_FECHAMAESTRA WHERE ESTADO = 1)--CAST(GETDATE()-1 AS date);

-- Obtener la primera fecha del mes
DECLARE @PrimeraFechaMes DATE = DATEADD(MONTH, DATEDIFF(MONTH, 0, @FechaActual), 0);

-- Obtener la última fecha del mes
DECLARE @UltimaFechaMes DATE = DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @FechaActual) + 1, 0));


--SELECT @FechaActual FechaActual, @PrimeraFechaMes PrimeraFechaMes, @UltimaFechaMes UltimaFechaMes
--======================================================================================================================================================================================

DROP TABLE IF EXISTS #CUENTACORRIENTE
SELECT NUMEROCUENTA, CODIGOPERSONA, DW_CODIGOSOCIO, MONEDA --, SITUACION
INTO #CUENTACORRIENTE
FROM DW_CUENTACORRIENTE
WHERE DW_FECHACARGA = @FechaActual

DROP TABLE IF EXISTS #PERSONA
SELECT DISTINCT CODIGOPERSONA, CIP, NOMBRECOMPLETO, FECHAINGRESOCOOP, NUMERORUC, EMAIL--, SITUACION
INTO #PERSONA
FROM DW_PERSONA
WHERE DW_FECHACARGA = @FechaActual

DROP TABLE IF EXISTS #DATOSSOCIO
SELECT DISTINCT CODIGOPERSONA, CODIGOSOCIO, FECHAINGRESO, FECHAINGRESOCOOP, SITUACION
INTO #DATOSSOCIO
FROM DW_DATOSSOCIO
WHERE DW_FECHACARGA = @FechaActual

DROP TABLE IF EXISTS #PERSONACORREO
SELECT * 
INTO #PERSONACORREO
FROM DW_PERSONACORREO
WHERE DW_FECHACARGA = @FechaActual

DROP TABLE IF EXISTS #PERSONANUMEROTELEFONO
SELECT * 
INTO #PERSONANUMEROTELEFONO
FROM DW_PERSONANUMEROTELEFONO
WHERE DW_FECHACARGA = @FechaActual

DROP TABLE IF EXISTS #DATOSCUENTACORRIENTE
SELECT distinct DW_FECHACARGA, TIPOCONFORMACION, NUMEROCUENTA
INTO #DATOSCUENTACORRIENTE
FROM DW_DATOSCUENTACORRIENTE
WHERE DW_FECHACARGA = @FechaActual

--======================================================================================================================================================================================
--1083

DROP TABLE IF EXISTS #WT_TRANSFERENCIASPACINET
SELECT 
	PERIODO_SOLICITUD =FORMAT(CONVERT(DATE,FECHAUSUARIO), 'yyyyMM')
  , FECHA_SOLICITUD = CAST(C.FECHAUSUARIO AS DATE)
  , FECHA_SOLICITUD_HORA = CAST(C.FECHAUSUARIO AS time(0)) 
  , ESTADO_SOLICITUD = (
		SELECT S900.TBLDESCRI
		FROM DW_SYST900 S900
		WHERE S900.TBLCODTAB = 148
		  AND S900.TBLCODARG = C.ESTADO
    )
  , CIP = CC.dw_codigosocio
  , NOMBRE_SOCIO = (
		SELECT P.NOMBRECOMPLETO
		FROM #PERSONA P
		WHERE P.CIP = CC.dw_codigosocio
    )
  , FECHA_INGRESO_SOCIO = ( -- SEGUN EL QUERY ORIGINAL, SE COLOCA LA FECHA DE INGRESO EN LA QUE EL SOCIO INGRESO A LA EMPRESA EN QUE TRABAJA
		SELECT DS.FECHAINGRESOCOOP
		FROM #DATOSSOCIO DS
		WHERE DS.CODIGOSOCIO = CC.dw_codigosocio
    )
  , DNI_SOCIO = (
		SELECT PN.Numerodocumentoid
        FROM IPERSONA_NATURAL PN
        WHERE PN.Codigopersona = CC.CODIGOPERSONA
    )
  , BENEFICIARIO = UPPER(C.BENEFICIARIOSOLICITUD) 
  , BENEFICIARIOESSOCIO = (
		CASE
			WHEN C.TIPODOCUMENTOID = 1 THEN (
											SELECT CASE WHEN COUNT(*) = 0 THEN 'NO' ELSE 'SI' END
											FROM IPERSONA_NATURAL P
											INNER JOIN #DATOSSOCIO DS
											ON P.CODIGOPERSONA = DS.CODIGOPERSONA
											WHERE P.TIPODOCUMENTOID = 1
											  AND DS.SITUACION NOT IN (2,3)
											  AND p.NUMERODOCUMENTOID = (
																		   CASE
																			  WHEN C.TIPODOCUMENTOID = 1 THEN RIGHT('00000000' + CONVERT(VARCHAR, C.NUMERODOCUMENTOID), 8)
																			  ELSE C.NUMERODOCUMENTOID
																			END
																	    )
									   )
			WHEN C.TIPODOCUMENTOID = 14 THEN (
											SELECT CASE WHEN COUNT(*) = 0 THEN 'NO' ELSE 'SI' END
											FROM #PERSONA P
											INNER JOIN #DATOSSOCIO DS
											ON P.CODIGOPERSONA = DS.CODIGOPERSONA
											WHERE P.NUMERORUC = CAST(C.NUMERODOCUMENTOID AS FLOAT)
											  AND DS.SITUACION NOT IN (2,3)
									   )
			ELSE (
					SELECT CASE WHEN COUNT(*) = 0 THEN 'NO' ELSE 'SI' END
					FROM IPERSONA_NATURAL P
					INNER JOIN #DATOSSOCIO DS
					ON P.CODIGOPERSONA = DS.CODIGOPERSONA
					WHERE P.TIPODOCUMENTOID IN (1,14)
					  AND DS.SITUACION NOT IN (2,3)
				)
		END
  )
  , FECHA_1ERENVIO_BENEFICIARIO = (
		SELECT MIN(CAST(CST.FECHASOLICITUD AS DATE))
        FROM DW_CAJASOLICITUDTRANSFERENCIA CST
        WHERE CST.NUMERODOCUMENTOID = C.NUMERODOCUMENTOID
  )
  , CORREO_SISGO = (
		CASE 
			WHEN (
					SELECT UPPER(descripcionCorreo) 
					FROM #PERSONACORREO
					WHERE esPrincipal = 'S'
					  AND ESTADO = 1
					  AND CODIGOPERSONA = C.CODIGOPERSONA
			 ) IS NULL
			 THEN (
				SELECT EMAIL
				FROM #PERSONA
				WHERE CODIGOPERSONA = C.CODIGOPERSONA
			 )
			 ELSE (
			 	SELECT UPPER(descripcionCorreo) 
				FROM #PERSONACORREO
				WHERE esPrincipal = 'S'
					AND ESTADO = 1
					AND CODIGOPERSONA = C.CODIGOPERSONA
			 )
		END  
  )
  , FECHA_CORREO = (
			 	SELECT FECHAUSUARIO
				FROM #PERSONACORREO
				WHERE esPrincipal = 'S'
					AND ESTADO = 1
					AND CODIGOPERSONA = C.CODIGOPERSONA
  )
  , USUARIO_CORREO = (
		SELECT CODIGOUSUARIO
		FROM #PERSONACORREO
		WHERE esPrincipal = 'S'
			AND ESTADO = 1
			AND CODIGOPERSONA = C.CODIGOPERSONA
  )
  , CORREO_PACINET = (
		SELECT UPPER(DES_EMAIL)
		FROM DWCOOPAC.DBO.IPACCLIENTEMAE
		WHERE ID_CLIENTE = CC.CODIGOPERSONA
  )
  , FECHA_CONTRASENA_PACINET = (
		SELECT FECHA_REGISTRO
		FROM DWCOOPAC.DBO.IPACCLIENTEPASSWORD
		WHERE ID_CLIENTE = CC.CODIGOPERSONA
		  AND ESTADO = 3
  )
  , PRIMERA_CONTRASENA = (
		SELECT MAX(FECHAOPERACION)
		FROM DWCOOPAC.DBO.IOPERACIONESADMINISTRATIVASLOG
		WHERE DESCRIPCION = 'Se cambio la contraseña por primera vez' 
		  AND CIP = CC.dw_codigosocio  
  )
  , CUENTA_ORIGEN = C.NUMEROCUENTA
  , CONFORMACION = (
	select TBLDESCRI
	from DW_SYST900
	WHERE TBLCODTAB = 151
	  AND TBLCODARG = DCC. TIPOCONFORMACION
  )
  , MONEDA = (
		SELECT TBLDESCRI
		FROM DW_SYST900
		WHERE TBLCODTAB = 22 
		AND TBLCODARG = SUBSTRING(C.NUMEROCUENTA,8,1) 
  )
  , IMPORTE = CAST(C.IMPORTESOLICITUD AS DECIMAL(8,2))
  , BANCO_DESTINO = (
		SELECT TBLDESCRI
		FROM DW_SYST900
		WHERE TBLCODTAB = 39 
		AND TBLCODARG = C.BANCOLOCAL
  )
  , CUENTA_DESTINO = C.CUENTABENEFICIARIO
  , TIPO_DOCUMENTO_BENEFICIARIO = (
		SELECT TBLDESCRI
		FROM DW_SYST900
		WHERE TBLCODTAB = 1 
		AND TBLCODARG = C.TIPODOCUMENTOID
  )
  , NUMERO_DOCUMENTO_BENEFICIARIO = C.NUMERODOCUMENTOID
  , USUARIO_OPERACION = C.CODIGOUSUARIO 
  , NUMERO_REG_CELULAR = 
	  CASE 
		WHEN (
				SELECT MAX(FECHAUSUARIO) 
				FROM #PERSONANUMEROTELEFONO 
				WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
				  AND TIPOTELEFONO = 4 
				  AND ESTADO = 1
		) IS NOT NULL THEN (
							SELECT MAX(NUMEROTELEFONO) 
							FROM #PERSONANUMEROTELEFONO P 
							WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
							AND TIPOTELEFONO = 4 
							AND ESTADO = 1
							AND FECHAUSUARIO IN (
												SELECT MAX(FECHAUSUARIO) 
												FROM #PERSONANUMEROTELEFONO 
												WHERE CODIGOPERSONA = P.CODIGOPERSONA 
													AND TIPOTELEFONO = 4 
													AND ESTADO = 1
												)
					   )
		ELSE
				CASE 
					WHEN (
							SELECT MAX(NUMEROTELEFONO) 
							FROM #PERSONANUMEROTELEFONO P 
							WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
							  AND TIPOTELEFONO = 4 
							  AND ESTADO = 1 
							  --AND ROWNUM < 2
					) IS NULL THEN (
									SELECT DES_CELULAR 
									FROM IPACCLIENTEMAE A 
									WHERE ID_CLIENTE = CC.CODIGOPERSONA
							  )
					ELSE (
						SELECT MAX(NUMEROTELEFONO) 
						FROM #PERSONANUMEROTELEFONO P 
						WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
						AND TIPOTELEFONO = 4 
						AND ESTADO = 1 
						--AND ROWNUM < 2
					)
				END
	  END 
  , FECHA_REG_CELULAR = (
		SELECT MAX(FECHAUSUARIO) 
		FROM #PERSONANUMEROTELEFONO P 
		WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
		  AND TIPOTELEFONO = 4 
		  AND ESTADO = 1
  )
  , USUARIO_REG_CELULAR = (
		CASE 
			WHEN (SELECT MAX(FECHAUSUARIO) FROM #PERSONANUMEROTELEFONO WHERE CODIGOPERSONA = CC.CODIGOPERSONA AND TIPOTELEFONO = 4 AND ESTADO = 1) IS NOT NULL 
			   THEN (
					SELECT DISTINCT CODIGOUSUARIO 
					FROM #PERSONANUMEROTELEFONO P 
					WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
					  AND TIPOTELEFONO = 4 
					  AND ESTADO = 1 
					  AND FECHAUSUARIO IN (
											SELECT MAX(FECHAUSUARIO) 
											FROM #PERSONANUMEROTELEFONO 
											WHERE CODIGOPERSONA = P.CODIGOPERSONA 
											  AND TIPOTELEFONO = 4 
											  AND ESTADO = 1
									   )
				) 
			ELSE (
				SELECT DISTINCT CODIGOUSUARIO 
				FROM #PERSONANUMEROTELEFONO P 
				WHERE CODIGOPERSONA = CC.CODIGOPERSONA 
				  AND TIPOTELEFONO = 4 
				  AND ESTADO = 1 
				 -- AND ROWNUM < 2
			)
		END
  )
  , FECHA_CREACION_CUENTA_PACINET = (
		SELECT 
			MIN(CAST(FECHA_REGISTRO AS DATE))
		FROM IPACCLIENTEPASSWORD 
		WHERE ID_CLIENTE = CC.CODIGOPERSONA
  ) ,
FECHA_ACTUALIZACION=(SELECT FECHA FROM ST_FECHAMAESTRA)

INTO #WT_TRANSFERENCIASPACINET
FROM DWCOOPAC.DBO.DW_CAJASOLICITUDTRANSFERENCIA C
INNER JOIN #CUENTACORRIENTE CC
ON CC.NUMEROCUENTA = C.NUMEROCUENTA
INNER JOIN #DATOSCUENTACORRIENTE DCC
ON DCC.NUMEROCUENTA = C.NUMEROCUENTA
WHERE C.DW_FECHACARGA BETWEEN @PrimeraFechaMes AND @UltimaFechaMes
  AND C.CODIGOUSUARIO='AGVIRTUAL'
  --AND C.ESTADO= PESTADO -------------- VARIABLE DE ORACLE
ORDER BY C.SECUENCIASOLICITUD
  

--======================================================================================================================================================================================

DROP TABLE #CUENTACORRIENTE;
DROP TABLE #PERSONA;
DROP TABLE #DATOSSOCIO;
DROP TABLE #PERSONACORREO;
DROP TABLE #PERSONANUMEROTELEFONO;
DROP TABLE #DATOSCUENTACORRIENTE;

DELETE FROM WT_TRANSFERENCIASPACINET WHERE PERIODO_SOLICITUD = (SELECT FORMAT(fecha, 'yyyyMM') FROM ST_FECHAMAESTRA)
INSERT INTO WT_TRANSFERENCIASPACINET
SELECT * FROM #WT_TRANSFERENCIASPACINET


select * from WT_TRANSFERENCIASPACINET where cip='0003677'

select * from WT_TRANSFERENCIASPACINET where BENEFICIARIO='LUIS AGARIE MIYASATO'

 --EXEC  [dbo].[usp_cargar_lista_negra_transferencias]                                                                                                                                                                                                                                                                                                                                                 
--======================================================================================================================================================================================
--======================================================================================================================================================================================
--======================================================================================================================================================================================
--======================================================================================================================================================================================
--======================================================================================================================================================================================
--======================================================================================================================================================================================
--======================================================================================================================================================================================

---------------------------------------------------------------------------------------------------------

/*SELECT * FROM DWCOOPAC.DBO.IPACCLIENTEMAE
SELECT * FROM DWCOOPAC.DBO.IPACCLIENTEPASSWORD
SELECT * FROM DWCOOPAC.DBO.IOPERACIONESADMINISTRATIVASLOG
SELECT * FROM DWCOOPAC.DBO.DW_CAJASOLICITUDTRANSFERENCIA
*/

--select * from DW_CUENTACORRIENTE where numerocuenta = '020177512002'


--        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'Ejecucion Exitosa del Dashboard Solicitud Transferencias Pacinet',null, 'OK'
--        --select * from DWCOOPACIFICO.dbo.WT_RUNOFF
     
--	end try
--	begin catch
--		rollback transaction

--		declare @error_message varchar(4000), @error_severity int, @error_state int
--		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
--		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
--        select getdate(),'ERROR en la ejecucion del Dashboard Solicitud Transferencias Pacinet', @error_message, 'ERROR'

--	end catch 
--	if @@trancount > 0
--		commit transaction		
--return 0
