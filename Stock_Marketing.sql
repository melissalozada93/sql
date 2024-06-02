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

-- Definición de las fechas
	DECLARE @FECHA DATE = (SELECT fecha FROM ST_FECHAMAESTRA WHERE estado = 1);
	DECLARE @TC DECIMAL(15,3) = (select promedio from DW_XTIPOCAMBIO where fecha = (select fecha from st_fechamaestra where estado = 1) and codigoTipoCambio = 3)
	SELECT @TC

-- Calendario de cierres y mes actual completo - se usa para el tipo de cambio mensual
	DROP TABLE IF EXISTS #CALENDARIO;
	SELECT DISTINCT Fecha 
	INTO #CALENDARIO
	FROM DIMTIEMPO
	WHERE (DiaNegativo = -1 AND fecha <= @FECHA) 
	   OR (FECHA BETWEEN DATEADD(dd, 1, EOMONTH(CAST(@fecha AS DATE), -1)) AND @FECHA);


-- Calendario este año - se usa para la tabla final, limita el tiempo que figurara, desde el 2023
	DROP TABLE IF EXISTS #CALENDARIOHISYEAR;
	SELECT DISTINCT FECHA 
	INTO #CALENDARIOHISYEAR
	FROM DIMTIEMPO 
	WHERE FECHA BETWEEN  EOMONTH(DATEADD(MONTH, -12, @fecha), -1) AND @FECHA;

	---2022-01-31

--=====================================================================================================================================================================================================================================
--- Extraer Tipo entidad de datos socio
    DROP TABLE IF EXISTS #DATOSSOCIO
    SELECT DISTINCT CODIGOSOCIO, TIPO_ENTIDAD 
    INTO #DATOSSOCIO
    FROM DW_DATOSSOCIO WHERE dw_fechaCarga = @FECHA


-- Todas las cuentas DPF activas y liquidadas para reducir el número de cuentas
    DROP TABLE IF EXISTS #CUENTAS
    SELECT 
          FECHACANCELACION = CASE WHEN rp.FECHACANCELACION = '-' THEN NULL ELSE rp.FECHACANCELACION END 
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
    INTO #CUENTAS
    FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS rp
    LEFT JOIN  #DATOSSOCIO ds ON ds.CODIGOSOCIO = rp.CODIGOSOCIO
    WHERE rp.fecha = @fecha
    AND (rp.TIPOPRODUCTO = 'Plazo Fijo' OR rp.PRODUCTO = 'AHF') AND rp.estado IN ('Activa','Liquidada')




-- De captación anexo sacamos todas las cuentas con sus respectivos saldos
	DROP TABLE IF EXISTS #DW_CUENTASALDOS1
    SELECT 
          dw_fechacarga
        , numerocuenta
        , saldoimporte1
    INTO #DW_CUENTASALDOS1
    FROM DW_CUENTASALDOS
	--WHERE dw_fechaCarga >= '2023-01-31'
	--UNION 
	--SELECT FECHA, NUMEROCUENTA, SALDOIMPORTE1 FROM TemporalesDW.DBO.ST_DPFMONTOSINICIALES_MKT WHERE FECHA < '2023-07-01'


    DROP TABLE IF EXISTS #DW_CUENTASALDOS
    SELECT 
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
    INTO #DW_CUENTASALDOS
    FROM #DW_CUENTASALDOS1  cs
    INNER JOIN #cuentas c on cs.NUMEROCUENTA = c.NROCUENTA

	--DROP TABLE #DW_CUENTASALDOS1

	




-- Extraemos los datos de las renovaciones, para luego determinar las aperturas y las cancelaciones
-- Al mismo tiempo, se limita la data con #cuentas
    DROP TABLE IF EXISTS #DATOSCUENTACORRIENTE
    SELECT 
          dc.dw_fechaCarga
        , dc.FECHAINICIO
        , dc.FECHAVENCIMIENTO
        , dc.NUMEROCUENTA 
        , dc.MONTOINICIAL
        , c.MONEDA
        , c.FECHACANCELACION
        , c.PRODUCTO
        , c.ESTADO
        , c.CANCELACIONANTICIPADA
        , c.AGENCIA
        , c.PLAZODIAS
        , C.CANAL
        , c.PERSONERIA
        , c.TIPO_ENTIDAD
    INTO #DATOSCUENTACORRIENTE
    FROM DW_DATOSCUENTACORRIENTE dc
    INNER JOIN #CUENTAS c ON dc.NUMEROCUENTA = c.NROCUENTA
    WHERE dc.dw_fechaCarga = @fecha

-- Extraer aperturas
	DROP TABLE IF EXISTS #APERTURAS;
	WITH cte_aperturas AS (
		SELECT *, n = ROW_NUMBER() OVER(PARTITION BY numerocuenta ORDER BY fechainicio ASC)
		FROM #DATOSCUENTACORRIENTE
	)
	SELECT 
		obs = 'APERTURA',
		fecha = FECHAINICIO,
		FECHAINICIO,
		FECHAVENCIMIENTO,
		NUMEROCUENTA,
		MONTOINICIAL,
		moneda,
		FECHACANCELACION,
		PRODUCTO,
		ESTADO,
		CANCELACIONANTICIPADA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA
	INTO #APERTURAS
	FROM cte_aperturas
	WHERE n = 1;


-- Extraer cancelaciones
	DROP TABLE IF EXISTS #CANCELACIONES;
	WITH cte_cancelaciones AS (
		SELECT *, n = ROW_NUMBER() OVER(PARTITION BY numerocuenta ORDER BY fechainicio DESC)
		FROM #DATOSCUENTACORRIENTE
	)
	SELECT 
		obs = 'CANCELACION',
		fecha = FECHACANCELACION,
		FECHAINICIO,
		FECHAVENCIMIENTO,
		NUMEROCUENTA,
		MONTOINICIAL,
		moneda,
		FECHACANCELACION,
		PRODUCTO,
		ESTADO,
		CANCELACIONANTICIPADA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA
	INTO #CANCELACIONES
	FROM cte_cancelaciones
	WHERE n = 1 AND FECHACANCELACION IS NOT NULL;


	UPDATE #cancelaciones SET MONTOINICIAL = 0

	update c set c.MONTOINICIAL = cs.IMPORTECANCELADO
	from #cancelaciones c inner join #cuentas cs
	on c.NUMEROCUENTA = cs.NROCUENTA
	where cs.FECHACANCELACION = C.fecha


-- Filtrar productos únicos
	DROP TABLE IF EXISTS #FILTROS;
	SELECT DISTINCT 
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA
	INTO #FILTROS
	FROM #APERTURAS
	UNION
	SELECT DISTINCT 
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA
	FROM #CANCELACIONES;

-- Crear matriz combinando fechas y filtros
	DROP TABLE IF EXISTS #MATRIZ;
	SELECT *
	INTO #MATRIZ
	FROM #CALENDARIOHISYEAR C
	CROSS JOIN #FILTROS;


-- Combinar datos de aperturas y cancelaciones
	DROP TABLE IF EXISTS #CONSOLIDADO;
	WITH DatosCombinados AS (
		SELECT 
			FECHA,
			PRODUCTO,
			MONEDA,
			AGENCIA,
			PLAZODIAS,
			CANAL,
			TIPO_ENTIDAD,
			PERSONERIA,
			SUM(montoinicial) AS APERTURA,
			0 AS CANCELACION,
			COUNT(*) AS QAPERTURA,
			0 AS QCANCELACION
		FROM #Aperturas
		GROUP BY 
            FECHA,PRODUCTO,MONEDA,AGENCIA,PLAZODIAS,CANAL,TIPO_ENTIDAD,PERSONERIA
		UNION ALL
		SELECT 
			FECHA,
			PRODUCTO,
			MONEDA,
			AGENCIA,
			PLAZODIAS,
			CANAL,
			TIPO_ENTIDAD,
			PERSONERIA,
			0 AS APERTURA,
			SUM(montoinicial) AS CANCELACION,
			0 AS QAPERTURA,
			COUNT(*) AS QCANCELACION
		FROM #CANCELACIONES
		GROUP BY 
			FECHA,PRODUCTO,MONEDA,AGENCIA,PLAZODIAS,CANAL,TIPO_ENTIDAD,PERSONERIA
	)
	SELECT 
		FECHA,
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA,
		SUM(apertura) AS APERTURA,
		SUM(cancelacion) AS CANCELACION,
		SUM(qApertura) AS QAPERTURA,
		SUM(qCancelacion) AS QCANCELACION
	INTO #CONSOLIDADO
	FROM DatosCombinados
	GROUP BY 
		FECHA,PRODUCTO,MONEDA,AGENCIA,PLAZODIAS,CANAL,TIPO_ENTIDAD,PERSONERIA
	ORDER BY fecha ASC;


-- Crear tabla #CONSOLIDADO2
	DROP TABLE IF EXISTS #CONSOLIDADO2;
	SELECT 
		M.*,
		ISNULL(IIF(M.Moneda='Dólares', (Apertura * @TC), Apertura), 0) AS APERTURATCD,
		ISNULL(qApertura, 0) AS QAPERTURA,
		ISNULL(IIF(M.Moneda='Dólares', (Cancelacion * @TC), Cancelacion), 0) AS CANCELACIONTCD,
		ISNULL(qCancelacion, 0) AS QCANCELACION
	INTO #CONSOLIDADO2
	FROM 
		#MATRIZ M 
	LEFT JOIN 
		#CONSOLIDADO D ON M.FECHA = D.FECHA 
		              AND M.PRODUCTO = D.PRODUCTO 
					  AND M.MONEDA = D.MONEDA 
					  AND M.AGENCIA = D.AGENCIA 
					  AND M.PLAZODIAS = D.PLAZODIAS 
					  AND M.CANAL = D.CANAL 
					  AND M.TIPO_ENTIDAD=D.TIPO_ENTIDAD
					  AND M.PERSONERIA=D.PERSONERIA
	--LEFT JOIN 
	--	DW_XTIPOCAMBIO TCD ON TCD.fecha = D.fecha AND TCD.codigoTipoCambio = 3 -- tipo cambio diario
	WHERE 
		M.fecha >= (SELECT DATEADD(DAY, 1, MIN(Fecha)) from #CALENDARIOHISYEAR)
	ORDER BY 
		fecha ASC;



-- Calcular STOCK 
	DROP TABLE IF EXISTS #STOCKINICIAL;

	WITH cte AS (
		SELECT 
			cs.*,
			ISNULL(IIF(CS.Moneda='Dólares', (SaldoImporte1 *@TC), SaldoImporte1), 0) AS SALDOTCD,
			1 AS Q
		FROM  
			#DW_CUENTASALDOS CS
		--LEFT JOIN 
		--	DW_XTIPOCAMBIO TCD ON TCD.fecha = CS.dw_fechacarga  -- tipo cambio diario
		WHERE 
			CS.dw_fechacarga = (SELECT MIN(Fecha) from #CALENDARIOHISYEAR)
		--	AND TCD.codigoTipoCambio = 3
	)
	SELECT 
		dw_fechacarga AS FECHA,
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA,
		APERTURATCD = SUM(SaldoTCD),
		QAPERTURA = SUM(Q)
	INTO 
		#STOCKINICIAL
	FROM 
		cte
	GROUP BY 
		dw_fechacarga, PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA;




	INSERT INTO 
		#CONSOLIDADO2
	SELECT 
		FECHA,
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA,
		APERTURATCD,
		QAPERTURA,
		0 AS CANCELACIONTCD,
		0 AS QCANCELACION
	FROM 
		#stockinicial;


-- Calcular y mostrar datos ordenados
DROP TABLE IF EXISTS WT_STOCK_DPF_SEGMENTADO;
WITH DatosOrdenados AS (
		SELECT 
			FECHA,
			PRODUCTO,
			MONEDA,
			AGENCIA,
			PLAZODIAS,
			CANAL,
			TIPO_ENTIDAD,
			PERSONERIA,
			APERTURATCD,
			CANCELACIONTCD,
			LAG(StockTCD, 1, 0) OVER (PARTITION BY 
				PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA ORDER BY FECHA) AS stock_anteriorTCD,
			QAPERTURA,
			QCANCELACION,
			LAG(QSTOCK, 1, 0) OVER (PARTITION BY 
				PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA ORDER BY FECHA) AS Qstock_anterior
		FROM (
			SELECT 
				FECHA,
				PRODUCTO,
				MONEDA,
				AGENCIA,
				PLAZODIAS,
				CANAL,
				TIPO_ENTIDAD,
				PERSONERIA,
				APERTURATCD,
				CANCELACIONTCD,
				0 + SUM(AperturaTCD - CancelacionTCD) OVER (PARTITION BY  
				PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA ORDER BY FECHA) AS STOCKTCD,
				QAPERTURA,
				QCANCELACION,
				0 + SUM(QAPERTURA -QCANCELACION ) OVER (PARTITION BY  
				PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA ORDER BY FECHA) AS QSTOCK
			FROM 
				#CONSOLIDADO2
		) AS DatosCalculados
	)

-- Mostrar resultados finales ordenados
	SELECT 
		FECHA,
		PRODUCTO,
		MONEDA,
		AGENCIA,
		PLAZODIAS,
		CANAL,
		TIPO_ENTIDAD,
		PERSONERIA,
		APERTURATCD AS APERTURA_TCD_MONTO,
		CANCELACIONTCD AS CANCELACION_TCD_MONTO,
		stock_anteriorTCD + AperturaTCD - CancelacionTCD AS STOCK_TCD,
		QAPERTURA AS QAPERTURAS,
		QCANCELACION AS Qcancelaciones,
		Qstock_anterior + QAPERTURA - QCANCELACION AS STOCK_Q
    INTO WT_STOCK_DPF_SEGMENTADO
	FROM 
		DatosOrdenados
	ORDER BY 
		FECHA, PRODUCTO, MONEDA, AGENCIA, PLAZODIAS, CANAL, TIPO_ENTIDAD, PERSONERIA;


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



