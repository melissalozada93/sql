USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_wt_activosretiradosagencia]    Script Date: 26/10/2023 17:06:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [dbo].[usp_wt_activosretiradosagencia]
as
set nocount on --
set xact_abort on
	begin transaction
	begin try


DECLARE @fecha DATE = (SELECT fecha FROM st_fechamaestra)

DECLARE @fecha2a�oscierre DATE = (SELECT DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @fecha) - 1, 0)))

DECLARE @fecha1a�osinicio DATE = (SELECT   DATEADD(YEAR, DATEDIFF(YEAR, 0, @fecha) - 1, 0) )


-- Elimina la tabla temporal si existe

-- Calendario desde el a�o pasado y este a�o
	DROP TABLE IF EXISTS #CALENDARIO;
	SELECT DISTINCT fecha 
	INTO #CALENDARIO
	FROM dimtiempo 
	WHERE fecha BETWEEN  @fecha1a�osinicio   AND @fecha;



	----Extraer data socios hace 2 a�os
	DROP TABLE IF EXISTS #Z_DW_SOCIO
	SELECT * 
	INTO #Z_DW_SOCIO
	FROM Z_DW_DATOSSOCIO WITH (NOLOCK)
	WHERE dw_fechaCarga=@fecha2a�oscierre AND SITUACION=1
	AND COMPRACARTERA='N' AND CODIGODEPENDENCIADESCRI<>'Originacion' AND AGENCIADESCRI<>'COMPRA CARTERA'
	

	----Extraer data de personas
	/*DROP TABLE IF EXISTS #Z_DW_PERSONA
	SELECT * 
	INTO #Z_DW_PERSONA
	FROM Z_DW_PERSONA WITH (NOLOCK)
	WHERE  CIP IN (SELECT DISTINCT CODIGOSOCIO FROM #Z_DW_SOCIO)
	AND dw_fechaCarga IN (SELECT max(dw_fechaCarga) FROM Z_DW_PERSONA)*/


	DROP TABLE IF EXISTS #DW_PERSONA
	SELECT * 
	INTO #DW_PERSONA
	FROM DW_PERSONA WITH (NOLOCK)
	WHERE  CIP IN (SELECT DISTINCT CODIGOSOCIO FROM #Z_DW_SOCIO)
	AND dw_fechaCarga IN (SELECT max(dw_fechaCarga) FROM DW_PERSONA)

	DROP TABLE IF EXISTS #DW_SOCIO
	SELECT * 
	INTO #DW_SOCIO
	FROM DW_DATOSSOCIO WITH (NOLOCK)
	WHERE dw_fechaCarga IN (SELECT max(dw_fechaCarga) FROM DW_DATOSSOCIO)


	-----Obtener data de observaci�n
	DROP TABLE IF EXISTS #DW_OBSERVACION
	SELECT *
	INTO #DW_OBSERVACION
	FROM( 
	SELECT *,N=ROW_NUMBER() OVER (PARTITION BY CODIGOPERSONA ORDER BY FECHAHORA)
	FROM DW_OBSERVACION
	WHERE TIPOOBSERVACION=12 )A WHERE A.N=1


-- Datos de socios activos hace 2 a�os

	DROP TABLE IF EXISTS #DW_PERSONA_SOCIO_2a�os
	SELECT DISTINCT
		DS.CODIGOSOCIO,
		P.NOMBRECOMPLETO AS NOMBRE,
		P.TIPOPERSONADESCRI,
		P.TIPOPERSONA,
		ISNULL(CONVERT(VARCHAR (20),P.SEXO),'Sin informacion')SEXO,
		ISNULL(P.EDAD,0)EDAD,
		O.CODIGOUSUARIO AS CODIGOUSUARIO,
		ISNULL(P.ESTADOCIVILDESCRI,'Sin informacion')ESTADOCIVILDESCRI,
		P.NUMERODOCUMENTOID,
		P.TIPODOCUMENTODESCRI,
		@fecha1a�osinicio FECHAINGRESOCOOP,
		DS.CODIGOPERSONA,
		DSH.AGENCIADESCRI,
		DS.SITUACION,
		CONVERT(DATE, NULL) AS FECHAAPROBACIONREN,
		'ACTIVO' AS ESTADO
	INTO #DW_PERSONA_SOCIO_2a�os
	FROM #Z_DW_SOCIO DS 
	INNER JOIN #DW_PERSONA P  ON P.CIP = DS.CODIGOSOCIO 
	LEFT JOIN #DW_OBSERVACION O WITH (NOLOCK) ON P.CODIGOPERSONA=O.CODIGOPERSONA
	LEFT JOIN #DW_SOCIO DSH ON DS.CODIGOSOCIO=DSH.CODIGOSOCIO
	



-- Datos de socios ingresados
	DROP TABLE IF EXISTS #INGRESOS
	SELECT DISTINCT
		DS.CODIGOSOCIO,
		P.NOMBRECOMPLETO AS NOMBRE,
		ISNULL(P.TIPOPERSONADESCRI,'Sin informacion')TIPOPERSONADESCRI,
		P.TIPOPERSONA,
		ISNULL(CONVERT(VARCHAR (20),P.SEXO),'Sin informacion')SEXO,
		ISNULL(P.EDAD,0)EDAD,
		O.CODIGOUSUARIO AS CODIGOUSUARIO,
		ISNULL(P.ESTADOCIVILDESCRI,'Sin informacion')ESTADOCIVILDESCRI,
		P.NUMERODOCUMENTOID,
		P.TIPODOCUMENTODESCRI,
		P.FECHAINGRESOCOOP,
		DS.CODIGOPERSONA,
		DS.AGENCIADESCRI,
		DS.SITUACION,
		CONVERT(DATE, NULL) AS FECHAAPROBACIONREN,
		'INGRESO' AS ESTADO
	INTO #INGRESOS
	FROM DW_DATOSSOCIO DS WITH (NOLOCK)
	INNER JOIN (SELECT CIP[CODIGOSOCIO] ,MAX(dw_fechaCarga)Fmax FROM DW_PERSONA GROUP BY CIP)PMAX ON PMAX.CODIGOSOCIO=DS.CODIGOSOCIO
	INNER JOIN DW_PERSONA P WITH (NOLOCK) ON P.CIP = PMAX.CODIGOSOCIO AND PMAX.Fmax = P.dw_fechaCarga
	LEFT JOIN #DW_OBSERVACION O WITH (NOLOCK) ON P.CODIGOPERSONA=O.CODIGOPERSONA 
	LEFT JOIN #DW_SOCIO DSH ON DS.CODIGOSOCIO=DSH.CODIGOSOCIO
	WHERE P.FECHAINGRESOCOOP >= @fecha1a�osinicio  AND DS.SITUACION<>2 ---Situacion 2 -= anulado
	AND DS.dw_fechaCarga=@fecha AND P.CIP IS NOT NULL
	AND DS.COMPRACARTERA='N' and DS.CODIGODEPENDENCIADESCRI<>'Originacion'AND DS.AGENCIADESCRI<>'COMPRA CARTERA'




-- Datos de socios retirados
	DROP TABLE IF EXISTS #RETIROS
	SELECT DISTINCT
		P.CIP,
		P.NOMBRECOMPLETO AS NOMBRE,
		ISNULL(P.TIPOPERSONADESCRI,'Sin informacion')TIPOPERSONADESCRI,
		P.TIPOPERSONA,
		ISNULL(CONVERT(VARCHAR (20),P.SEXO),'Sin informacion')SEXO,
		ISNULL(P.EDAD,0)EDAD,
		SR.CODIGOUSUARIO AS CODIGOUSUARIO,
		ISNULL(P.ESTADOCIVILDESCRI,'Sin informacion')ESTADOCIVILDESCRI,
		P.NUMERODOCUMENTOID,
		P.TIPODOCUMENTODESCRI,
		P.FECHAINGRESOCOOP,
		DS.CODIGOPERSONA,
		DSH.AGENCIADESCRI,
		DS.SITUACION,
		SR.FECHAAPROBACION AS FECHAAPROBACIONREN,
		'RETIRADO' AS ESTADO
    INTO #RETIROS
	FROM DW_DATOSSOCIO DS WITH (NOLOCK)
	LEFT JOIN #DW_SOCIO DSH ON DS.CODIGOSOCIO=DSH.CODIGOSOCIO
	INNER JOIN DW_SOLICITUDRENUNCIA SR WITH (NOLOCK) ON SR.CODIGOPERSONA = DS.CODIGOPERSONA
	INNER JOIN (SELECT CIP[CODIGOSOCIO] ,MAX(dw_fechaCarga)Fmax FROM DW_PERSONA GROUP BY CIP)PMAX ON PMAX.CODIGOSOCIO=DS.CODIGOSOCIO
	INNER JOIN DW_PERSONA P WITH (NOLOCK) ON P.CIP = PMAX.CODIGOSOCIO AND PMAX.Fmax = P.dw_fechaCarga
	WHERE SR.FECHAAPROBACION >= @fecha1a�osinicio
	AND SR.ESTADORENUNCIA IN (2, 4)
	AND DS.SITUACION = 3
	AND DS.dw_fechaCarga=@fecha
	AND P.CIP IS NOT NULL
	AND DS.COMPRACARTERA='N'
	AND DS.CODIGODEPENDENCIADESCRI<>'Originacion'



	

-----Unir Datos-----------------------
DROP TABLE IF EXISTS #DW_PERSONA_SOCIO
SELECT * 
INTO #DW_PERSONA_SOCIO
FROM #DW_PERSONA_SOCIO_2a�os
UNION ALL
SELECT *
FROM #INGRESOS
UNION ALL
SELECT *
FROM #RETIROS



-- Genera Reporte con el detalle --------
DROP TABLE IF EXISTS WT_ACTRETAGENCIA
SELECT DISTINCT
    NOMBRE,
	CODIGOSOCIO,
    AGENCIADESCRI AS AGENCIA,
    CONVERT(DATE, FECHAINGRESOCOOP) AS FECHAINGRESO,
    FECHAAPROBACIONREN AS FECHARETIRO,
    DATEDIFF(DAY, FECHAINGRESOCOOP, ISNULL(FECHAAPROBACIONREN, CONVERT(DATE, @fecha))) AS DIASDURACION,
    TIPOPERSONADESCRI AS TIPOPERSONA,
    SEXO,
    CODIGOUSUARIO AS USUARIO,
    CASE WHEN EDAD<18 THEN '-18'
		 WHEN EDAD>=18 AND EDAD<=25 THEN'18-25'	
		 WHEN EDAD>=26 AND EDAD<=30 THEN'26-30'
		 WHEN EDAD>=31 AND EDAD<=35 THEN'30-35'
		 WHEN EDAD>=36 AND EDAD<=40 THEN'36-40'
		 WHEN EDAD>=41 AND EDAD<=45 THEN'41-45'
		 WHEN EDAD>=46 AND EDAD<=50 THEN'46-50'
		 WHEN EDAD>=51 AND EDAD<=55 THEN'51-55'
		 WHEN EDAD>=56 AND EDAD<=60 THEN'56-60'
		 WHEN EDAD>=61 AND EDAD<=65 THEN'61-65' 
		 WHEN EDAD>=66  THEN'+66'END AS EDAD,
        CASE WHEN EDAD<18 THEN 1
		 WHEN EDAD>=18 AND EDAD<=25 THEN 2
		 WHEN EDAD>=26 AND EDAD<=30 THEN 3
		 WHEN EDAD>=31 AND EDAD<=35 THEN 4
		 WHEN EDAD>=36 AND EDAD<=40 THEN 5
		 WHEN EDAD>=41 AND EDAD<=45 THEN 6
		 WHEN EDAD>=46 AND EDAD<=50 THEN 7
		 WHEN EDAD>=51 AND EDAD<=55 THEN 8
		 WHEN EDAD>=56 AND EDAD<=60 THEN 9
		 WHEN EDAD>=61 AND EDAD<=65 THEN 10
		 WHEN EDAD>=66  THEN 11 END AS NRANGOEDAD,
    ESTADOCIVILDESCRI AS ESTADOCIVIL,
    TIPODOCUMENTODESCRI AS TIPODOCUMENTO,
    NUMERODOCUMENTOID AS NUMERODOCUMENTO,
    ESTADO AS ESTADOCIP,
    IIF(ESTADO = 'RETIRADO', 1, 0) AS FLAGSOCIORETIRO, 
	IIF(ESTADO = 'INGRESO',1,0) AS FLAGSOCIOINGRESO,
	IIF(ESTADO = 'ACTIVO'OR ESTADO = 'INGRESO', 1, 0) AS FLAGSOCIOACTIVO, 
	FECHA=IIF(FECHAAPROBACIONREN IS NULL , FECHAINGRESOCOOP,FECHAAPROBACIONREN),
	TIPO_AGENCIA=CASE WHEN AGENCIADESCRI IN ('APJ','JOCKEY','CENTENARIO','REGATAS','TERRAZAS','SURQUILLO','SAN ISIDRO','CHACARILLA','AELU','CIRCOLO','JAPON') THEN 'Agencia F�sica' 
				  WHEN AGENCIADESCRI ='PACINET'  THEN 'Pacinet' ELSE 'Otros' END
INTO WT_ACTRETAGENCIA
FROM #DW_PERSONA_SOCIO 




-- Filtrar productos �nicos
	DROP TABLE IF EXISTS #FILTROS;
	SELECT DISTINCT 
	AGENCIA,
	TIPOPERSONA,
	SEXO,
	EDAD,
	NRANGOEDAD,
	ESTADOCIVIL,
	TIPODOCUMENTO,
	TIPO_AGENCIA
	INTO #FILTROS
	FROM WT_ACTRETAGENCIA



-- Crear matriz combinando fechas y filtros
	DROP TABLE IF EXISTS #MATRIZ;
	SELECT *
	INTO #MATRIZ
	FROM #CALENDARIO C
	CROSS JOIN #FILTROS;


-----Agrupando segmentos-------
	DROP TABLE IF EXISTS #WT_ACTRETAGENCIA
	SELECT 	
	FECHA,
	AGENCIA,
	TIPOPERSONA,
	SEXO,
	EDAD,
	NRANGOEDAD,
	ESTADOCIVIL,
	TIPODOCUMENTO,
	TIPO_AGENCIA,
	SUM(FLAGSOCIOACTIVO) FLAGSOCIOACTIVO,
	SUM(FLAGSOCIOINGRESO) FLAGSOCIOINGRESO,
	SUM(FLAGSOCIORETIRO) FLAGSOCIORETIRO 
	INTO #WT_ACTRETAGENCIA
	FROM WT_ACTRETAGENCIA
	GROUP BY 
	FECHA,
	AGENCIA,
	TIPOPERSONA,
	SEXO,
	EDAD,
	NRANGOEDAD,
	ESTADOCIVIL,
	TIPODOCUMENTO,
	TIPO_AGENCIA



-- Crear tabla #CONSOLIDADO para calcular los activos a la fecha
	DROP TABLE IF EXISTS #CONSOLIDADO;
	SELECT M.*,
	ISNULL(D.FLAGSOCIOACTIVO,0)FLAGSOCIOACTIVO,
	ISNULL(D.FLAGSOCIOINGRESO,0)FLAGSOCIOINGRESO,
	ISNULL(D.FLAGSOCIORETIRO,0)FLAGSOCIORETIRO
	INTO #CONSOLIDADO
	FROM 
		#MATRIZ M 
    LEFT JOIN 
		#WT_ACTRETAGENCIA D ON CONVERT(DATE,M.fecha) = CONVERT(DATE,D.Fecha )
		              AND M.AGENCIA = D.AGENCIA 
					  AND M.TIPOPERSONA = D.TIPOPERSONA 
					  AND M.SEXO = D.SEXO 
					  AND M.EDAD = D.EDAD
					  AND M.NRANGOEDAD = D.NRANGOEDAD 
					  AND M.ESTADOCIVIL = D.ESTADOCIVIL 
					  AND M.TIPODOCUMENTO = D.TIPODOCUMENTO 
					  AND M.TIPO_AGENCIA = D.TIPO_AGENCIA 


DROP TABLE IF EXISTS WT_ACTRETAGENCIA_RESUMEN;
-- Calcular y mostrar datos ordenados
	WITH DatosOrdenados AS (
			SELECT 
				FECHA,
				AGENCIA,
				TIPOPERSONA,
				SEXO,
				EDAD,
				NRANGOEDAD,
				ESTADOCIVIL,
				TIPODOCUMENTO,
				TIPO_AGENCIA,
				FLAGSOCIOACTIVO,
				FLAGSOCIOINGRESO,
				FLAGSOCIORETIRO,
			LAG(ACTIVO, 1, 0) OVER (PARTITION BY 
				AGENCIA,
				TIPOPERSONA,
				SEXO,
				EDAD,
				NRANGOEDAD,
				ESTADOCIVIL,
				TIPODOCUMENTO ORDER BY FECHA) AS ActivoAnterior
		FROM (
			SELECT 
				FECHA,
				AGENCIA,
				TIPOPERSONA,
				SEXO,
				EDAD,
				NRANGOEDAD,
				ESTADOCIVIL,
				TIPODOCUMENTO,
				TIPO_AGENCIA,
				FLAGSOCIOACTIVO,
				FLAGSOCIOINGRESO,
				FLAGSOCIORETIRO,
				0 + SUM(FLAGSOCIOACTIVO - FLAGSOCIORETIRO) OVER (PARTITION BY  
				AGENCIA,
				TIPOPERSONA,
				SEXO,
				EDAD,
				NRANGOEDAD,
				ESTADOCIVIL,
				TIPODOCUMENTO,
				TIPO_AGENCIA ORDER BY FECHA) AS ACTIVO
			FROM 
				#CONSOLIDADO
		) AS DatosCalculados
	)

-- Mostrar resultados finales ordenados
	SELECT 
			FECHA,
			AGENCIA,
			TIPOPERSONA,
			SEXO,
			EDAD,
			NRANGOEDAD,
			ESTADOCIVIL,
			TIPODOCUMENTO,
			TIPO_AGENCIA,
			FLAGSOCIOACTIVO,
			FLAGSOCIOINGRESO,
			FLAGSOCIORETIRO,
		ActivoAnterior + FLAGSOCIOINGRESO - FLAGSOCIORETIRO AS ACTIVO,
			@fecha FECHAACTUALIZACION
	INTO WT_ACTRETAGENCIA_RESUMEN
	FROM 
		DatosOrdenados
	ORDER BY 
		FECHA,
			AGENCIA,
			TIPOPERSONA,
			SEXO,
			EDAD,
			NRANGOEDAD,
			ESTADOCIVIL,
			TIPODOCUMENTO,
			TIPO_AGENCIA;



	
-- Limpiar las tablas temporales 



----===================================================================================================================================================================================================--
        insert into ETL_PRC_LOG (log_fecha, log_tarea_id, log_tarea_nombre, log_estado) 
        values (getdate(), 6, 'Tabla WT_ACTRETAGENCIA Cargada', 'OK')

        insert into DWCOOPAC.dbo.LOG_WT (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa de WT_ACTRETAGENCIA',null, 'OK'

        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard Activos y Retirados',null, 'OK'
        --select * from DWCOOPAC.dbo.LOG_WT

	end try
	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()

		insert into DWCOOPAC.dbo.LOG_WT (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'ERROR en la ejecucion de WT_ACTRETAGENCIA', @error_message, 'ERROR'


	end catch 
	if @@trancount > 0
		commit transaction		
return 0


