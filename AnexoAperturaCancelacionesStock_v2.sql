USE [DWCOOPAC]
-- Definición de las fechas
	DECLARE @FECHA DATE = (SELECT fecha FROM ST_FECHAMAESTRA WHERE estado = 1);


-- Calendario de cierres y mes actual completo - se usa para el tipo de cambio mensual
	DROP TABLE IF EXISTS #CALENDARIO;
	SELECT DISTINCT Fecha 
	INTO #CALENDARIO
	FROM dimtiempo 
	WHERE (DiaNegativo = -1 AND fecha <= @fecha) 
	   OR (fecha BETWEEN DATEADD(dd, 1, EOMONTH(CAST(@fecha AS DATE), -1)) AND @fecha);


-- Calendario este año - se usa para la tabla final, limita el tiempo que figurara, a solicitud de gloria solo 2023 en adelante
	DROP TABLE IF EXISTS #CALENDARIOHISYEAR;
	SELECT DISTINCT fecha 
	INTO #CALENDARIOHISYEAR
	FROM dimtiempo 
	WHERE fecha BETWEEN DATEFROMPARTS(YEAR(GETDATE() - 1), 1, 1) AND CAST(GETDATE() - 1 AS DATE);


-- Todas las cuentas DPF activas y liquidadas para reducir el número de cuentas
	DROP TABLE IF EXISTS #cuentas;
	SELECT 
		FECHACANCELACION = CASE WHEN FECHACANCELACION = '-' THEN NULL ELSE FECHACANCELACION END,
		NROCUENTA,
		MONEDA,
		PRODUCTO,
		ESTADO,
		CANCELACIONANTICIPADA,
		AGENCIA = AGENCIAAPERTURA,
		PLAZODIAS,
		CANAL = CASE WHEN USUARIO = 'AGVIRTUAL' THEN 'DIGITAL' ELSE 'PRESENCIAL' END,
		IMPORTECANCELADO
	INTO #cuentas
	FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS
	WHERE fecha = @fecha
	AND TIPOPRODUCTO = 'Plazo Fijo' AND estado IN ('Activa','Liquidada')
	AND PRODUCTO != 'AHV';


-- De captación anexo sacamos todas las cuentas con sus respectivos saldos
	DROP TABLE IF EXISTS #DW_CUENTASALDOS;
	SELECT 
		cs.dw_fechacarga,
		cs.numerocuenta,
		c.Producto,
		c.Moneda,
		c.Agencia,
		c.PlazoDias,
		c.Canal,
		cs.saldoimporte1
	INTO #DW_CUENTASALDOS
	FROM DW_CUENTASALDOS cs
	INNER JOIN #cuentas c ON cs.NUMEROCUENTA = c.NROCUENTA;


-- Extraemos los datos de las renovaciones, para luego determinar las aperturas y las cancelaciones
-- Al mismo tiempo, se limita la data con #cuentas
	DROP TABLE IF EXISTS #datoscuentacorriente;
	SELECT 
		dc.dw_fechaCarga,
		dc.FECHAINICIO,
		dc.FECHAVENCIMIENTO,
		dc.NUMEROCUENTA,
		dc.MONTOINICIAL,
		c.moneda,
		c.FECHACANCELACION,
		c.PRODUCTO,
		c.ESTADO,
		c.CANCELACIONANTICIPADA,
		c.AGENCIA,
		c.PLAZODIAS,
		c.CANAL
	INTO #datoscuentacorriente
	FROM DW_DATOSCUENTACORRIENTE dc
	INNER JOIN #cuentas c ON dc.NUMEROCUENTA = c.NROCUENTA
	WHERE dc.dw_fechaCarga = @fecha;


-- Extraer aperturas
	DROP TABLE IF EXISTS #aperturas;
	WITH cte_aperturas AS (
		SELECT *, n = ROW_NUMBER() OVER(PARTITION BY numerocuenta ORDER BY fechainicio ASC)
		FROM #datoscuentacorriente
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
		CANAL
	INTO #aperturas
	FROM cte_aperturas
	WHERE n = 1;


-- Extraer cancelaciones
	DROP TABLE IF EXISTS #cancelaciones;
	WITH cte_cancelaciones AS (
		SELECT *, n = ROW_NUMBER() OVER(PARTITION BY numerocuenta ORDER BY fechainicio DESC)
		FROM #datoscuentacorriente
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
		CANAL
	INTO #cancelaciones
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
		Producto,
		Moneda,
		Agencia,
		PlazoDias,
		Canal 
	INTO #FILTROS
	FROM #aperturas
	UNION
	SELECT DISTINCT 
		Producto,
		Moneda,
		Agencia,
		PlazoDias,
		Canal  
	FROM #cancelaciones;


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
			fecha,
			Producto,
			Moneda,
			Agencia,
			PlazoDias,
			Canal,
			SUM(montoinicial) AS apertura,
			0 AS cancelacion,
			COUNT(*) AS qApertura,
			0 AS qCancelacion
		FROM #Aperturas
		GROUP BY 
			fecha,
			Producto,
			Moneda,
			Agencia,
			PlazoDias,
			Canal
		UNION ALL
		SELECT 
			fecha,
			Producto,
			Moneda,
			Agencia,
			PlazoDias,
			Canal,
			0 AS apertura,
			SUM(montoinicial) AS cancelacion,
			0 AS qApertura,
			COUNT(*) AS qCancelacion
		FROM #Cancelaciones
		GROUP BY 
			fecha,
			Producto,
			Moneda,
			Agencia,
			PlazoDias,
			Canal
	)
	SELECT 
		fecha,
		Producto,
		Moneda,
		Agencia,
		PlazoDias,
		Canal,
		SUM(apertura) AS apertura,
		SUM(cancelacion) AS cancelacion,
		SUM(qApertura) AS qApertura,
		SUM(qCancelacion) AS qCancelacion
	INTO #CONSOLIDADO
	FROM DatosCombinados
	GROUP BY 
		fecha,
		Producto,
		Moneda,
		Agencia,
		PlazoDias,
		Canal
	ORDER BY fecha ASC;


-- Crear tabla #CONSOLIDADO2
	DROP TABLE IF EXISTS #CONSOLIDADO2;
	SELECT 
		M.*,
		ISNULL(IIF(M.Moneda='Dólares', (Apertura * TCD.promedio), Apertura), 0) AS AperturaTCD,
		ISNULL(IIF(M.Moneda='Dólares', (Apertura * TCM.promedio), Apertura), 0) AS AperturaTCM,
		ISNULL(IIF(M.Moneda='Dólares', (Apertura * TCA.promedio), Apertura), 0) AS AperturaTCA,
		ISNULL(qApertura, 0) AS qApertura,
		ISNULL(IIF(M.Moneda='Dólares', (Cancelacion * TCD.promedio), Cancelacion), 0) AS CancelacionTCD,
		ISNULL(IIF(M.Moneda='Dólares', (Cancelacion * TCM.promedio), Cancelacion), 0) AS CancelacionTCM,
		ISNULL(IIF(M.Moneda='Dólares', (Cancelacion * TCA.promedio), Cancelacion), 0) AS CancelacionTCA,
		ISNULL(qCancelacion, 0) AS qCancelacion
	INTO #CONSOLIDADO2
	FROM 
		#MATRIZ M 
	LEFT JOIN 
		#CONSOLIDADO D ON M.fecha = D.Fecha 
		              AND M.Producto = D.Producto 
					  AND M.Moneda = D.Moneda 
					  AND M.Agencia = D.Agencia 
					  AND M.PlazoDias = D.PlazoDias 
					  AND M.Canal = D.Canal 
	LEFT JOIN 
		DW_XTIPOCAMBIO TCD ON TCD.fecha = D.fecha AND TCD.codigoTipoCambio = 3 -- tipo cambio diario
	LEFT JOIN (

		SELECT 
			periodo = LEFT(FECHA, 7),
			Fecha,
			N = ROW_NUMBER() OVER (PARTITION BY LEFT(FECHA, 7) ORDER BY fecha DESC),
			Promedio
		FROM 
			DW_XTIPOCAMBIO 
		WHERE 
			codigoTipoCambio = 3 AND FECHA IN (SELECT DISTINCT FECHA FROM #calendario)
	) TCM ON TCM.periodo = LEFT(D.fecha, 7) AND TCM.N = 1 					  -- tipo cambio mensual
	LEFT JOIN (
		
		SELECT 
			Periodo1 = LEFT(FECHA, 4),
			Periodo2 = YEAR(FECHA) + 1,
			Fecha,
			N = ROW_NUMBER() OVER (PARTITION BY LEFT(FECHA, 4) ORDER BY fecha DESC),
			Promedio
		FROM 
			DW_XTIPOCAMBIO 
		WHERE 
			codigoTipoCambio = 3
	) TCA ON TCA.periodo2 = LEFT(D.fecha, 4) AND TCA.n = 1					  -- tipo cambio anual
	WHERE 
		M.fecha >= '2023-01-01'
	ORDER BY 
		fecha ASC;



-- Calcular STOCK 2022
	DROP TABLE IF EXISTS #stockinicial;

	WITH cte AS (
		SELECT 
			cs.*,
			ISNULL(IIF(CS.Moneda='Dólares', (SaldoImporte1 * TCD.promedio), SaldoImporte1), 0) AS SaldoTCD,
			ISNULL(IIF(CS.Moneda='Dólares', (SaldoImporte1 * TCM.promedio), SaldoImporte1), 0) AS SaldoTCM,
			ISNULL(IIF(CS.Moneda='Dólares', (SaldoImporte1 * TCA.promedio), SaldoImporte1), 0) AS SaldoTCA,
			1 AS Q
		FROM  
			#DW_CUENTASALDOS CS
		LEFT JOIN 
			DW_XTIPOCAMBIO TCD ON TCD.fecha = CS.dw_fechacarga AND TCD.codigoTipoCambio = 3 -- tipo cambio diario
		LEFT JOIN (

			SELECT 
				periodo = LEFT(FECHA, 7),
				Fecha,
				N = ROW_NUMBER() OVER (PARTITION BY LEFT(FECHA, 7) ORDER BY fecha DESC),
				Promedio
			FROM 
				DW_XTIPOCAMBIO 
			WHERE 
				codigoTipoCambio = 3 AND FECHA IN (SELECT DISTINCT FECHA FROM #calendario)
		) TCM ON TCM.periodo = LEFT(CS.dw_fechacarga, 7) AND TCM.N = 1                     -- tipo cambio mensual
		LEFT JOIN (

			SELECT 
				Periodo1 = LEFT(FECHA, 4),
				Periodo2 = YEAR(FECHA) + 1,
				Fecha,
				N = ROW_NUMBER() OVER (PARTITION BY LEFT(FECHA, 4) ORDER BY fecha DESC),
				Promedio
			FROM 
				DW_XTIPOCAMBIO 
			WHERE 
				codigoTipoCambio = 3
		) TCA ON TCA.periodo2 = LEFT(CS.dw_fechacarga, 4) AND TCA.n = 1                    -- tipo cambio anual
		WHERE 
			CS.dw_fechacarga = '2022-12-31'
	)
	SELECT 
		dw_fechacarga AS Fecha,
		Producto,
		Moneda,
		-- Estado,CancelacionAnticipada,
		Agencia,
		PlazoDias,
		Canal,
		AperturaTCD = SUM(SaldoTCD),
		AperturaTCM = SUM(SaldoTCM),
		AperturaTCA = SUM(SaldoTCA),
		qApertura = SUM(Q)
	INTO 
		#stockinicial
	FROM 
		cte
	GROUP BY 
		dw_fechacarga, Producto, Moneda,
		-- Estado,CancelacionAnticipada,
		Agencia, PlazoDias, Canal;




-- Insertar en #CONSOLIDADO2 desde #stockinicial
	INSERT INTO 
		#CONSOLIDADO2
	SELECT 
		Fecha,
		Producto,
		Moneda,
		Agencia,
		PlazoDias,
		Canal,
		AperturaTCD,
		AperturaTCM,
		AperturaTCA,
		qApertura,
		0 AS CancelacionTCD,
		0 AS CancelacionTCM,
		0 AS CancelacionTCA,
		0 AS qCancelacion
	FROM 
		#stockinicial;


-- Calcular y mostrar datos ordenados
	WITH DatosOrdenados AS (
		SELECT 
			fecha,
			Producto,
			Moneda,
			-- Estado,CancelacionAnticipada,
			Agencia,
			PlazoDias,
			Canal,
			AperturaTCD,
			CancelacionTCD,
			LAG(StockTCD, 1, 0) OVER (PARTITION BY 
				Producto, Moneda,
				-- Estado,CancelacionAnticipada,
				Agencia, PlazoDias, Canal ORDER BY fecha) AS stock_anteriorTCD,
			AperturaTCM,
			CancelacionTCM,
			LAG(StockTCM, 1, 0) OVER (PARTITION BY 
				Producto, Moneda,
				-- Estado,CancelacionAnticipada,
				Agencia, PlazoDias, Canal ORDER BY fecha) AS stock_anteriorTCM,
			AperturaTCA,
			CancelacionTCA,
			LAG(StockTCM, 1, 0) OVER (PARTITION BY 
				Producto, Moneda,
				-- Estado,CancelacionAnticipada,
				Agencia, PlazoDias, Canal ORDER BY fecha) AS stock_anteriorTCA
		FROM (
			SELECT 
				fecha,
				Producto,
				Moneda,
				-- Estado,CancelacionAnticipada,
				Agencia,
				PlazoDias,
				Canal,
				AperturaTCD,
				CancelacionTCD,
				0 + SUM(AperturaTCD - CancelacionTCD) OVER (PARTITION BY  
					Producto, Moneda,
					-- Estado,CancelacionAnticipada,
					Agencia, PlazoDias, Canal ORDER BY fecha) AS StockTCD,
				AperturaTCM,
				CancelacionTCM,
				0 + SUM(AperturaTCM - CancelacionTCM) OVER (PARTITION BY  
					Producto, Moneda,
					-- Estado,CancelacionAnticipada,
					Agencia, PlazoDias, Canal ORDER BY fecha) AS StockTCM,
				AperturaTCA,
				CancelacionTCA,
				0 + SUM(AperturaTCA - CancelacionTCA) OVER (PARTITION BY  
					Producto, Moneda,
					-- Estado,CancelacionAnticipada,
					Agencia, PlazoDias, Canal ORDER BY fecha) AS StockTCA
			FROM 
				#CONSOLIDADO2
		) AS DatosCalculados
	)

-- Mostrar resultados finales ordenados
	SELECT 
		fecha,
		Producto,
		Moneda,
		-- Estado,CancelacionAnticipada,
		Agencia,
		PlazoDias,
		Canal,
		AperturaTCD,
		CancelacionTCD,
		stock_anteriorTCD + AperturaTCD - CancelacionTCD AS StockTCD,
		AperturaTCM,
		CancelacionTCM,
		stock_anteriorTCM + AperturaTCM - CancelacionTCM AS StockTCM,
		AperturaTCA,
		CancelacionTCA,
		stock_anteriorTCA + AperturaTCA - CancelacionTCA AS StockTCA
	FROM 
		DatosOrdenados
	ORDER BY 
		Fecha, Producto, Moneda, Agencia, PlazoDias, Canal;




------Revisión------------------------------

	--select * from #CONSOLIDADO where fecha='2023-01-16' and producto='CDE'
	--AND Moneda='Dólares' and Agencia='APJ' and PlazoDias='90' and CANAL='PRESENCIAL'




	--SELECT * FROM DWCOOPAC.DBO.WT_STOCK_DPF_SEGMENTADO


	--SELECT * FROM DW_XTIPOCAMBIO where fecha='2023-01-16'