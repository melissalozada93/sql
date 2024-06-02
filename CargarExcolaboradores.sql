USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dasha_colaboradores]    Script Date: 02/01/2024 16:52:00 ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO

--ALTER procedure [dbo].[usp_dash_excolaboradores]
--as


DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)

DECLARE @tipocambio FLOAT = (SELECT promedio FROM DW_XTIPOCAMBIO WHERE fecha = @fecha AND codigoTipoCambio = 3)


----Obtener colaboradores
DROP TABLE IF EXISTS ST_EXCOLABORADORES
SELECT RIGHT('0000000' + CIP, 7) AS CIP,
	DNI, NOMBRESAPELLIDOS, EMPRESA, RUC, FECHACESE
	INTO ST_EXCOLABORADORES
	FROM  TEMP_EXCOLABORADORES;


-----Obtener datos de los socios 
DROP TABLE IF EXISTS #DW_DATOSSOCIO 
SELECT * 
	INTO #DW_DATOSSOCIO 
	FROM DW_DATOSSOCIO 
	WHERE dw_fechaCarga=(SELECT DISTINCT MAX(dw_fechaCarga) FROM DW_DATOSSOCIO)
	AND CODIGOSOCIO IN(SELECT DISTINCT CIP FROM ST_EXCOLABORADORES)

 CREATE INDEX IND_CODIGOSOCIO on #DW_DATOSSOCIO(CODIGOSOCIO)
 WITH (DROP_EXISTING = OFF)



DROP TABLE IF EXISTS #DW_PERSONA
SELECT DISTINCT P.* ,PR.codigorol_descrip
	INTO #DW_PERSONA
	FROM DW_PERSONA P
	INNER JOIN DW_PERSONAROL PR  ON P.CODIGOPERSONA=PR.CODIGOPERSONA AND P.DW_FECHACARGA=PR.dw_fechaCarga
	AND P.DW_FECHACARGA=(SELECT MAX(dw_fechaCarga) FROM DW_PERSONA)
	AND P.CODIGOPERSONA IN (SELECT DISTINCT CODIGOPERSONA FROM #DW_DATOSSOCIO)


----Obtener tipo cambio
DROP TABLE IF EXISTS #TIPOCAMBIO 
SELECT fecha, PROMEDIO 
     INTO #TIPOCAMBIO
     FROM DW_XTIPOCAMBIO WHERE codigoTipoCambio = 3 


---- Obtener las solicitudes
DROP TABLE IF EXISTS #DW_PRESTAMOANEXO
SELECT PA.*
	,MONTOPRESTAMO_SOLES=IIF(PA.MONEDA=2, IIF(TC.promedio IS NULL,PA.MONTOPRESTAMO*@tipocambio, PA.MONTOPRESTAMO*TC.promedio),PA.MONTOPRESTAMO)
	,SALDOPRESTAMO_SOLES=IIF(PA.MONEDA=2, IIF(TC.promedio IS NULL,PA.SALDOPRESTAMO*@tipocambio, PA.SALDOPRESTAMO*TC.promedio),PA.SALDOPRESTAMO)
	,MORA_SOLES=IIF(PA.MONEDA=2, IIF(TC.promedio IS NULL,PA.DW_MORA*@tipocambio, PA.DW_MORA*TC.promedio),PA.DW_MORA)
	,MONTOATRASO_SOLES=IIF(PA.MONEDA=2, IIF(TC.promedio IS NULL,PA.dw_montoAtraso*@tipocambio, PA.dw_montoAtraso*TC.promedio),PA.dw_montoAtraso)
	,TIPOCAMBIO=IIF(TC.promedio IS NULL,@tipocambio, TC.promedio)
	INTO #DW_PRESTAMOANEXO
	FROM DW_PRESTAMOANEXO PA
	LEFT JOIN #TIPOCAMBIO TC ON TC.fecha = PA.dw_fechaCarga
	WHERE PA.DW_FECHACARGA=(SELECT MAX(DW_FECHACARGA) FROM DW_PRESTAMO)
	AND PA.CODIGOSOCIO IN(SELECT DISTINCT CODIGOSOCIO FROM #DW_DATOSSOCIO)
	


-----Solicitud Prestamo 
DROP TABLE IF EXISTS #DW_SOLICITUDPRESTAMO 
SELECT * 
	INTO #DW_SOLICITUDPRESTAMO 
	FROM DW_SOLICITUDPRESTAMO 
	WHERE DW_FECHACARGA=(SELECT MAX(DW_FECHACARGA) FROM DW_PRESTAMO)
	AND CODIGOSOLICITUD IN(SELECT DISTINCT CODIGOSOLICITUD FROM #DW_PRESTAMOANEXO)


-----C�digo Sectorista
DROP TABLE IF EXISTS #SECTORISTA
SELECT DISTINCT
	  CODIGOPERSONA[CODIGOSECTORISTA]
	, NOMBRECORTO[SECTORISTA]
	INTO #SECTORISTA
	FROM DW_PERSONA 
	WHERE dw_fechaCarga=(SELECT MAX(dw_fechaCarga) FROM DW_PERSONA)
	AND CODIGOPERSONA IN(SELECT CODIGOSECTORISTA FROM #DW_DATOSSOCIO)


----Detalle de las solicitudes
DROP TABLE IF EXISTS #DW_PRESTAMOCUOTASRESUMEN
SELECT * 
	INTO #DW_PRESTAMOCUOTASRESUMEN
	FROM DW_PRESTAMOCUOTASRESUMEN
	WHERE dw_fechaCarga=(SELECT MAX(dw_fechaCarga) FROM DW_PRESTAMOCUOTASRESUMEN)
	AND CODIGOSOLICITUD IN(SELECT DISTINCT CODIGOSOLICITUD FROM #DW_PRESTAMOANEXO)


---Fecha Cancelacion
DROP TABLE IF EXISTS #DW_PRESTAMOHISTORIA
SELECT * 
    INTO #DW_PRESTAMOHISTORIA
	FROM DW_PRESTAMOHISTORIA
	WHERE dw_fechaCarga=(SELECT MAX(dw_fechaCarga) FROM DW_PRESTAMOHISTORIA)
	AND CODIGOSOLICITUD IN(SELECT DISTINCT CODIGOSOLICITUD FROM #DW_PRESTAMOANEXO)


DROP TABLE IF EXISTS #DW_MAESTROTRANSFERENCIA1
SELECT DISTINCT CODIGOSOLICITUD,ESTADO,DW_TIPOOPERACIONDESCRI
	INTO #DW_MAESTROTRANSFERENCIA1
	FROM DW_MAESTROTRANSFERENCIA 
	WHERE CODIGOSOLICITUD IN(SELECT DISTINCT CODIGOSOLICITUD FROM #DW_PRESTAMOANEXO)
	AND ESTADO=1


DROP TABLE IF EXISTS #DW_MAESTROTRANSFERENCIA2
SELECT DISTINCT CODIGOSOLICITUD,ESTADO,DW_TIPOOPERACIONDESCRI
	INTO #DW_MAESTROTRANSFERENCIA2
	FROM DW_MAESTROTRANSFERENCIA 
	WHERE CODIGOSOLICITUD IN(SELECT DISTINCT CODIGOSOLICITUD FROM #DW_PRESTAMOANEXO)
	AND ESTADO=2

---Agencia Codigo Solicitud
DROP TABLE IF EXISTS #AGENCIA
SELECT DISTINCT CODIGOSOLICITUD, 
CASE WHEN DW_PRODUCTO='PLR'THEN 'SAN ISIDRO' 
ELSE DW_AGENCIACAJADESCRI
END AS AGENCIACAJA
INTO #AGENCIA
FROM DW_PRESTAMO 
WHERE dw_fechaCarga=(SELECT MAX(dw_fechaCarga) FROM dw_PRESTAMO)



INSERT INTO WT_COLABORADORES
SELECT 
	  PA.dw_fechaCarga[FECHACARGA]
	, PA.codigosolicitud[CODIGOSOLICITUD]
	, ESTADO= dbo.ufn_syst900(25,PA.ESTADO)
	, ESTADO2= IIF(dbo.ufn_syst900(25,PA.ESTADO)='Vigente','Vig.','Canc.')
	, PA.CODIGOSOCIO
	, PER.NOMBRECORTO
	, DS.RAZONSOCIAL
	, TIPOPRODUCTO = CASE WHEN PA.PRODUCTOCORTODESCRI in ('PCL','PLC','PLR','PDD','DSC','PLN') then 'LINEA' ELSE 'CREDITO' END
	, PA.TIPO
	, PRODUCTO = PA.PRODUCTOCORTODESCRI
	, CLASIFICACION = ISNULL(PA.dw_clasificacion,'-') 
	, MONEDA = dbo.ufn_syst900(22,PA.MONEDA)
	, MONEDA2 = iif(dbo.ufn_syst900(22,PA.MONEDA)='Soles','S','D')
    , SECTORISTA = ISNULL(S.SECTORISTA,'-' )
    , PA.FECHACARTA 
	, FECHADESEMBOLSO = PA.FECHAPRESTAMO
	, FECHACANCELACION = CASE WHEN PH.FECHA_CANCELACION IS NULL THEN '-' ELSE CONVERT(varchar,PH.FECHA_CANCELACION) END
	, TOTALCUOTAS=ISNULL(PCR.TOTALCUOTAS,0)
	, NROCUOTASPAGADAS=ISNULL(PCR.NROCUOTASPAGADAS,0)
	, NROCUOTASVIGENTES=ISNULL(PCR.NROCUOTASVIGENTES,0)
	, DIASATRASO2=ISNULL(PCR.DIASATRASO,0)
	, CUOTASADELANTADAS=ISNULL(PCR.CUOTASADELANTADAS,0)
	, CUOTAMES=ISNULL(PCR.CUOTAMES,0)
	, RANGODIASVENCIMIENTO = CASE 
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 0 AND 7 THEN '1.[ 0 a 7 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 8 AND 14 THEN '2.[ 8 a 14 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 15 AND 21 THEN '3.[ 15 a 21 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 22 AND 30 THEN '4.[ 22 a 30 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 31 AND 60 THEN '5.[ 31 a 60 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 61 AND 90 THEN '6.[ 61 a 90 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 91 AND 120 THEN '7.[ 91 a 120 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 121 AND 150 THEN '8.[ 121 a 150 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 151 AND 180 THEN '9.[ 151 a 180 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 181 AND 210 THEN '10.[ 181 a 210 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 211 AND 270 THEN '11.[ 211 a 270 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 271 AND 300 THEN '12.[ 271 a 300 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 301 AND 360 THEN '13.[ 301 a 360 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 361 AND 720 THEN '14.[ 361 a 720 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 721 AND 1080 THEN '15.[ 721 a 1080 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 1081 AND 1440 THEN '16.[ 1081 a 1440 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 1441 AND 1800 THEN '17.[ 1441 a 1800 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 1801 AND 3600 THEN '18.[ 1801 a 3600 ]'
                                WHEN DATEDIFF(DD,PA.DW_FECHACARGA,PA.FECHACARTA) BETWEEN 3601 AND 7200 THEN '19.[ 3601 a 7200 ]'
                                else 'VENCIDO'
                            END
	, RANGOMONTODESEMBOLSO = CASE 
								WHEN  PA.MONTOPRESTAMO_SOLES BETWEEN 0 AND 500000 THEN '1.- [0 - 500,000 ]'
								WHEN  PA.MONTOPRESTAMO_SOLES BETWEEN 500001 AND 5500000 THEN '2.- [500,001 - 5,500,000 ]'
								WHEN  PA.MONTOPRESTAMO_SOLES >= 10001 THEN '3.- [5,500,001 - MAS ]'
							 END
    , MONTODESEMBOLSO=ISNULL(PA.MONTOPRESTAMO,0)
	, MONTODESEMBOLSOSOLES=ISNULL(PA.MONTOPRESTAMO_SOLES,0)
	, SALDOPRESTAMO=ISNULL(PA.SALDOPRESTAMO,0)
	, SALDOPRESTAMOSOLES=ISNULL(PA.SALDOPRESTAMO_SOLES,0)
	, MORA=ISNULL(PA.MORA,0)
	, MORASOLES=ISNULL(PA.MORA_SOLES,0)
	, MONTOATRASO=ISNULL(PA.MONTOATRASO,0)
	, MONTOATRASOSOLES=ISNULL(PA.MONTOATRASO_SOLES,0)
	, PAGO=ISNULL(PA.MONTOPRESTAMO,0)-ISNULL(PA.SALDOPRESTAMO,0)
	, PAGOSOLES=ISNULL(PA.MONTOPRESTAMO_SOLES,0)-ISNULL(PA.SALDOPRESTAMO_SOLES,0)
	, DIASATRASO = PA.dw_diasAtraso
	, RANGODIASATRASO = CASE 
							WHEN PA.dw_diasAtraso BETWEEN 0 AND 30 THEN '1.[ 0 - 1 MES ]'
                            WHEN PA.dw_diasAtraso BETWEEN 31 AND 90 THEN '2.[ 1 - 3 MESES ]'
                            WHEN PA.dw_diasAtraso BETWEEN 91 AND 180 THEN '3.[ 3 - 6 MESES ]'
                            WHEN PA.dw_diasAtraso BETWEEN 181 AND 360 THEN '4.[ 6 - 12 MESES ]'
                            WHEN PA.dw_diasAtraso >= 361 THEN '5.[ + 12 MESES ]'
                                ELSE '-'
                            END
	, TASAINTERESACTUAL = ISNULL(PA.TASAINTERES,0)
	, TASAINTERESINICIAL = SP.TASAINTERES
	, ANIOCARTA = ISNULL(LEFT(PA.FECHACARTA,7),'-')
	, TIPO_OPERACION = ISNULL(M1.DW_TIPOOPERACIONDESCRI,M2.DW_TIPOOPERACIONDESCRI)
	, DIAVENCIMIENTOCUOTAS=IIF(PA.PRODUCTOCORTODESCRI IN('PLR','PLC'),0, SP.DIAVENCIMIENTOCUOTAS)
	, DEBITO_AUT= IIF (M1.ESTADO=1,'Si','No')
	, A.AGENCIACAJA,
	  FECHA = PA.FECHAPRESTAMO
	, EXCOLABORADOR='SI'	
	, TIPOCAMBIO=@tipocambio
	, FECHAACTUALIZACION=@fecha
	FROM #DW_PRESTAMOANEXO PA
	LEFT JOIN #DW_PERSONA PER ON PA.CODIGOPERSONA=PER.CODIGOPERSONA
	LEFT JOIN #DW_DATOSSOCIO DS ON PA.CODIGOPERSONA=DS.CODIGOPERSONA
	LEFT JOIN #SECTORISTA S ON DS.CODIGOSECTORISTA=S.CODIGOSECTORISTA
	LEFT JOIN #DW_PRESTAMOCUOTASRESUMEN PCR ON PA.CODIGOSOLICITUD=PCR.CODIGOSOLICITUD
	LEFT JOIN #DW_PRESTAMOHISTORIA PH ON PA.CODIGOSOLICITUD=PH.CODIGOSOLICITUD
	LEFT JOIN #DW_SOLICITUDPRESTAMO SP ON PA.CODIGOSOLICITUD=SP.CODIGOSOLICITUD	
	LEFT JOIN #DW_MAESTROTRANSFERENCIA1 M1 ON PA.CODIGOSOLICITUD=M1.CODIGOSOLICITUD
	LEFT JOIN #DW_MAESTROTRANSFERENCIA2 M2 ON PA.CODIGOSOLICITUD=M2.CODIGOSOLICITUD
	LEFT JOIN #AGENCIA A ON PA.CODIGOSOLICITUD=A.CODIGOSOLICITUD



	DROP TABLE #AGENCIA
	DROP TABLE #DW_DATOSSOCIO
	DROP TABLE #DW_MAESTROTRANSFERENCIA1
	DROP TABLE #DW_MAESTROTRANSFERENCIA2
	DROP TABLE #DW_PERSONA
	DROP TABLE #DW_PRESTAMOANEXO
	DROP TABLE #DW_PRESTAMOCUOTASRESUMEN
	DROP TABLE #DW_PRESTAMOHISTORIA
	DROP TABLE #DW_SOLICITUDPRESTAMO
	DROP TABLE #SECTORISTA
	DROP TABLE #TIPOCAMBIO