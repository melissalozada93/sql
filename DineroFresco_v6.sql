-- Utilizar la base de datos DWCOOPAC
USE [DWCOOPAC];

-- Declarar la fecha de la tabla FECHAMAESTRA
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA FROM [DWCOOPAC].dbo.FECHAMAESTRA);


DECLARE @FECHA7 DATE;
SET @FECHA7 = (SELECT DATEADD(DAY, -7, FECHA )FROM [DWCOOPAC].dbo.FECHAMAESTRA);



---d�posito en dol�res $ 500  , plazo fijo S/.15 000 ----MONEDA CRUZADA

--------APERTURAS---------------------------------------------------------------------------------------------------
      DROP TABLE IF EXISTS #PASIVAS
      SELECT CODIGOSOCIO
	  , NROCUENTA
	  , MONEDA
	  , FECHAAPERTURA
	  , MONTOINICIAL
	  , MONTOINICIAL_SOLES
	  INTO #PASIVAS
      FROM DWCOOPAC.dbo.WT_REPORTEPASIVAS
      WHERE FECHA = @FECHA
      AND ESTADO ='Activa' AND (TIPOPRODUCTO = 'Plazo Fijo' )
      AND FECHAAPERTURA>=@FECHA7



 --------DATOS CUENTA CORRIENTE---------------------------------------------------------------------------------------
	  DROP TABLE IF EXISTS #DATOSCUENTACORRIENTE
	  SELECT 
	    NUMEROCUENTA
	  , FECHAINICIO
      INTO #DATOSCUENTACORRIENTE
      FROM DW_DATOSCUENTACORRIENTE a
      WHERE NUMEROCUENTA IN (SELECT DISTINCT NROCUENTA FROM #PASIVAS)
      AND A.dw_fechacarga = @fecha--'2023-07-19' 
	  AND A.FECHAINICIO>=@FECHA7




 --------OBTENIENDO MONTOS DE APERTURA-------------------------------------------------------------------------------
	  DROP TABLE IF EXISTS #APERTURAS_DETALLE
	  SELECT 
	    P.CODIGOSOCIO
	  , P.NROCUENTA
	  , P.MONEDA
	  , P.FECHAAPERTURA
	  , MONTOINICIAL= CASE WHEN (ROW_NUMBER() OVER(PARTITION BY NUMEROCUENTA ORDER BY FECHAINICIO ASC))=1 THEN MONTOINICIAL ELSE 0 END
	  , MONTOINICIAL_SOLES= CASE WHEN (ROW_NUMBER() OVER(PARTITION BY NUMEROCUENTA ORDER BY FECHAINICIO ASC))=1 THEN MONTOINICIAL_SOLES ELSE 0 END
	  INTO #APERTURAS_DETALLE
	  FROM #PASIVAS P
	  LEFT JOIN #DATOSCUENTACORRIENTE DCC	
	  ON P.NROCUENTA=DCC.NUMEROCUENTA 

	 

 --------APERTURAS POR SOCIO Y MONEDA---------------------------------------------------------------------------------
      DROP TABLE IF EXISTS #APERTURAS
	  SELECT 
	    CODIGOSOCIO
	  , UPPER(LEFT(MONEDA,1)) MONEDA
	  , FECHAAPERTURA
	  , SUM(MONTOINICIAL)MONTOAPERTURA 
	  , SUM(MONTOINICIAL)MONTOAPERTURA_SOLES 
	  INTO #APERTURAS
	  FROM #APERTURAS_DETALLE
	  GROUP BY CODIGOSOCIO, UPPER(LEFT(MONEDA,1)), FECHAAPERTURA


	

---------REPORTE DINERO FRESCO----------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #REPORTEDINEROFRESCO;
	SELECT
		per.CIP AS CodSocio,
		per.NOMBRECOMPLETO AS NombreCompleto,
		UPPER(LEFT(cc.MONEDADESCRI,1)) Moneda,
		a.NumeroCuenta,
		a.importe1 AS Importe,
		a.PeriodoCaja,
		a.NumeroCaja,
		a.Observacion,
		s90.TBLDESCRI AS FormaPago,
		CASE
			WHEN a.formapago = 1 THEN 'Efectivo'
			WHEN a.formapago = 3 THEN 'Bancos'
			WHEN a.formapago = 2 THEN 'Cheque'
			WHEN a.formapago = 8 THEN 'Nota Abono'
		END AS FormaPagoFinal,
		a.FechaUsuario,
		A.CODIGOUSUARIO,
		CONVERT(DATE,a.FechaUsuario)FECHAMOVIMIENTO
	INTO #REPORTEDINEROFRESCO
	FROM
		DW_CUENTAMOVIMIENTO  (NOLOCK) a
	INNER JOIN
		VW_CUENTACORRIENTE cc ON cc.numerocuenta = a.numerocuenta
	LEFT JOIN 
		DW_PERSONA (NOLOCK) per ON cc.CODIGOPERSONA = per.CODIGOPERSONA
	LEFT JOIN
		DW_SYST900 s90 (NOLOCK) ON a.FORMAPAGO = s90.TBLCODARG AND s90.TBLCODTAB = 21
	WHERE
		a.periodocaja IS NOT NULL AND 
		CAST(a.fechausuario AS DATE) BETWEEN DATEADD(DAY, -7,@FECHA7) AND @FECHA
		AND (
			a.observacion LIKE '%DEPOSITO EN CUENTA%'
			OR a.observacion LIKE '%REMESA KYODAI%'
			OR a.observacion LIKE '%22889%'
			OR a.observacion LIKE '%12117%'
			OR a.observacion LIKE '%Liberacion de Cheque%'
		)
		AND a.estado = 1
		AND a.tipomovimiento IN (1, 3, 5, 7)
		AND a.formapago IN (1, 2, 3, 8)
		AND cc.PRODUCTOCODIGO = 'AHV'
		AND a.codigousuario NOT IN (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Dinero fresco')
		AND a.codigoagencia NOT IN (9, 12)
		--AND cc.dw_fechaCarga = @FECHA
		--AND per.dw_fechaCarga = @FECHA
		AND cc.dw_fechaCarga = '2024-02-29'
		AND per.dw_fechaCarga = '2024-03-04';



---------OBTENER MOVIMIENTOS--------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #TEMP_MOVIMIENTOS
		SELECT
		  CodSocio
		, Moneda
		, FECHAMOVIMIENTO
		, SUM(Importe)MOVIMIENTO
		INTO #TEMP_MOVIMIENTOS
		FROM #REPORTEDINEROFRESCO 
		GROUP BY CodSocio, Moneda, FECHAMOVIMIENTO



---------SIN MOVIMIENTOS CUANDO EL MISMO DIA DE LA APERTURA, EL MONTO DE MOVIMIENTO SEA 0-------------------
		DROP TABLE IF EXISTS #SIN_MOVIMIENTOS1
		SELECT 
		  A.CODIGOSOCIO
		, A.FECHAAPERTURA
		, M.MOVIMIENTO
		, M.FECHAMOVIMIENTO
		, M.MONEDA
		INTO #SIN_MOVIMIENTOS1
		FROM #APERTURAS A
		LEFT JOIN #TEMP_MOVIMIENTOS M ON A.CODIGOSOCIO=M.CodSocio 
		AND A.MONEDA=M.MONEDA AND A.FECHAAPERTURA>M.FECHAMOVIMIENTO
		AND A.CODIGOSOCIO NOT IN (SELECT DISTINCT CODIGOSOCIO FROM #APERTURAS A
		INNER JOIN #TEMP_MOVIMIENTOS M ON A.CODIGOSOCIO=M.CodSocio 
		AND A.MONEDA=M.MONEDA AND A.FECHAAPERTURA=M.FECHAMOVIMIENTO)
		WHERE M.MOVIMIENTO IS NOT NULL AND M.FECHAMOVIMIENTO BETWEEN DATEADD(DAY, -7, A.FECHAAPERTURA ) AND A.FECHAAPERTURA 
		--AND A.CODIGOSOCIO='0008548'


----------SIN MOVIMIENTOS CUANDO EL MISMO DIA DE LA APERTURA, EL MONTO DE MOVIMIENTO SEA MENOR A LA APERTURA-----
		DROP TABLE IF EXISTS #SIN_MOVIMIENTOS2
		SELECT 
		  A.CODIGOSOCIO
		, A.FECHAAPERTURA
		, M.MOVIMIENTO
		, M.FECHAMOVIMIENTO
		, M.MONEDA
		INTO #SIN_MOVIMIENTOS2
		FROM #APERTURAS A
		LEFT JOIN #TEMP_MOVIMIENTOS M ON A.CODIGOSOCIO=M.CodSocio 
		AND A.MONEDA=M.MONEDA AND A.FECHAAPERTURA>=M.FECHAMOVIMIENTO
		AND A.CODIGOSOCIO NOT IN (SELECT DISTINCT CODIGOSOCIO FROM #APERTURAS A
		INNER JOIN #TEMP_MOVIMIENTOS M ON A.CODIGOSOCIO=M.CodSocio 
		AND A.MONEDA=M.MONEDA AND A.FECHAAPERTURA>=M.FECHAMOVIMIENTO AND M.MOVIMIENTO>=A.MONTOAPERTURA)
		WHERE M.MOVIMIENTO IS NOT NULL AND M.FECHAMOVIMIENTO BETWEEN DATEADD(DAY, -7, A.FECHAAPERTURA ) AND A.FECHAAPERTURA 
		AND A.CODIGOSOCIO NOT IN (SELECT DISTINCT CODIGOSOCIO FROM #SIN_MOVIMIENTOS1)
		--AND A.CODIGOSOCIO='0008548'



		DROP TABLE IF EXISTS #SIN_MOVIMIENTOS3
		SELECT * 
		INTO #SIN_MOVIMIENTOS3
		FROM #SIN_MOVIMIENTOS1
		UNION ALL
		SELECT * FROM #SIN_MOVIMIENTOS2


		DROP TABLE IF EXISTS #SIN_MOVIMIENTOS4
		SELECT 
		  CODIGOSOCIO
		, FECHAAPERTURA[FECHAMOVIMIENTO]
		, MONEDA
		, SUM(MOVIMIENTO)MOVIMIENTO
		INTO #SIN_MOVIMIENTOS4 
		FROM #SIN_MOVIMIENTOS3
		GROUP BY CODIGOSOCIO, FECHAAPERTURA, MONEDA


		DROP TABLE IF EXISTS #SIN_MOVIMIENTOS
		SELECT 
		  A.CODIGOSOCIO
		, A.MONEDA
		, M.FECHAMOVIMIENTO
		, M.MOVIMIENTO
		INTO #SIN_MOVIMIENTOS
		FROM #APERTURAS A
		INNER JOIN #SIN_MOVIMIENTOS4 M ON A.CODIGOSOCIO=M.CODIGOSOCIO 
		AND A.MONEDA=M.MONEDA AND A.FECHAAPERTURA=M.FECHAMOVIMIENTO
		AND M.MOVIMIENTO>=A.MONTOAPERTURA



		DROP TABLE IF EXISTS #MOVIMIENTOS
		SELECT * 
		INTO #MOVIMIENTOS
		FROM #TEMP_MOVIMIENTOS WHERE CodSocio NOT IN (SELECT DISTINCT CODIGOSOCIO FROM #SIN_MOVIMIENTOS)
		UNION ALL
		SELECT * FROM #SIN_MOVIMIENTOS




		----OBTENER SOCIOS CON MOVIMIENTOS EN MONEDA CRUZADA--------------------------------------------------------------   
		DROP TABLE IF EXISTS #MONEDACRUZADA
		SELECT A.CODIGOSOCIO,A.MONEDA,M.FECHAMOVIMIENTO
		INTO #MONEDACRUZADA
		FROM (SELECT * FROM #APERTURAS WHERE CODIGOSOCIO IN (SELECT DISTINCT CodSocio FROM #MOVIMIENTOS)) A 
		LEFT JOIN #MOVIMIENTOS M ON A.CODIGOSOCIO=M.CodSocio AND A.MONEDA=M.Moneda AND A.FECHAAPERTURA=M.FECHAMOVIMIENTO
		WHERE M.Moneda IS NULL


		----CONVERTIR MONTOS DE MOVIMIENTOS EN MONEDA CRUZADA
		DROP TABLE IF EXISTS #MOVIMIENTOS2
		SELECT M.* 
		, MONEDA2=ISNULL(MC.MONEDA,M.Moneda)
		, MOVIMIENTO2=CASE WHEN MC.MONEDA IS NULL THEN M.MOVIMIENTO 
						   WHEN MC.MONEDA='D' THEN M.MOVIMIENTO/3.875 
						   WHEN MC.MONEDA='S' THEN M.MOVIMIENTO*3.875 END
        INTO #MOVIMIENTOS2
		FROM #MOVIMIENTOS M
		LEFT JOIN #MONEDACRUZADA MC ON M.CodSocio=MC.CODIGOSOCIO AND M.FECHAMOVIMIENTO=MC.FECHAMOVIMIENTO


-------DINERO FRESO DEL MISMO DIA CON EL MISMO TIPO DE MONEDA
		SELECT 
		  A.CODIGOSOCIO
		, A.MONEDA
		, A.FECHAAPERTURA[FECHA]
		, A.MONTOAPERTURA
		---, ISNULL(M.MOVIMIENTO,0)[MOVIMIENTO_INICIAL]
		, ISNULL(M.MOVIMIENTO2,0)[MOVIMIENTO]
		, DINEROFRESCO= CASE WHEN ISNULL(M.MOVIMIENTO2,0)>=A.MONTOAPERTURA THEN A.MONTOAPERTURA
		                     WHEN A.MONTOAPERTURA>ISNULL(M.MOVIMIENTO2,0)  THEN ISNULL(M.MOVIMIENTO2,0) ELSE 0 END
		, DINERONOFRESCO=CASE WHEN ISNULL(M.MOVIMIENTO2,0)>=A.MONTOAPERTURA THEN 0 
		                      WHEN A.MONTOAPERTURA>ISNULL(M.MOVIMIENTO2,0)THEN A.MONTOAPERTURA-ISNULL(M.MOVIMIENTO2,0) ELSE A.MONTOAPERTURA END
	    , MONEDA_CRUZADA=IIF(MC.Moneda IS NOT NULL,'SI','NO')


		FROM #APERTURAS A
		LEFT JOIN #MOVIMIENTOS2 M ON A.CODIGOSOCIO=M.CodSocio AND A.MONEDA=M.MONEDA2 AND A.FECHAAPERTURA=M.FECHAMOVIMIENTO
		LEFT JOIN #MONEDACRUZADA MC ON A.CODIGOSOCIO=MC.CODIGOSOCIO AND A.MONEDA=MC.MONEDA AND A.FECHAAPERTURA=M.FECHAMOVIMIENTO

		WHERE A.CODIGOSOCIO='0154075'

		--SELECT * FROM #MOVIMIENTOS2
		
		--SELECT * FROM #REPORTEDINEROFRESCO WHERE CodSocio='0002090'

		--select * from #SIN_MOVIMIENTOS1 WHERE CODIGOSOCIO='0002090'

		 
		 --select DISTINCT CODIGOSOCIO from #SIN_MOVIMIENTOS

		 SELECT * FROM #REPORTEDINEROFRESCO WHERE CodSocio='0036407'


---------REPORTE DINERO FRESCO----------------------------------------------------------------------------------------
	
	SELECT
		per.CIP AS CodSocio,
		per.NOMBRECOMPLETO AS NombreCompleto,
		UPPER(LEFT(cc.MONEDADESCRI,1)) Moneda,
		a.NumeroCuenta,
		a.importe1 AS Importe,
		a.PeriodoCaja,
		a.NumeroCaja,
		a.Observacion,
		s90.TBLDESCRI AS FormaPago,
		CASE
			WHEN a.formapago = 1 THEN 'Efectivo'
			WHEN a.formapago = 3 THEN 'Bancos'
			WHEN a.formapago = 2 THEN 'Cheque'
			WHEN a.formapago = 8 THEN 'Nota Abono'
		END AS FormaPagoFinal,
		a.FechaUsuario,
		A.CODIGOUSUARIO,
		CONVERT(DATE,a.FechaUsuario)FECHAMOVIMIENTO
	FROM
		DW_CUENTAMOVIMIENTO  (NOLOCK) a
	INNER JOIN
		VW_CUENTACORRIENTE cc ON cc.numerocuenta = a.numerocuenta
	LEFT JOIN 
		DW_PERSONA (NOLOCK) per ON cc.CODIGOPERSONA = per.CODIGOPERSONA
	LEFT JOIN
		DW_SYST900 s90 (NOLOCK) ON a.FORMAPAGO = s90.TBLCODARG AND s90.TBLCODTAB = 21
	WHERE
		a.periodocaja IS NOT NULL 
		--AND  CAST(a.fechausuario AS DATE) BETWEEN DATEADD(DAY, -7,@FECHA7) AND @FECHA
		AND (
			a.observacion LIKE '%DEPOSITO EN CUENTA%'
			OR a.observacion LIKE '%REMESA KYODAI%'
			OR a.observacion LIKE '%22889%'
			OR a.observacion LIKE '%12117%'
			OR a.observacion LIKE '%Liberacion de Cheque%'
		)
		AND a.estado = 1
		AND a.tipomovimiento IN (1, 3, 5, 7)
		AND a.formapago IN (1, 2, 3, 8)
		AND cc.PRODUCTOCODIGO = 'AHV'
		AND a.codigousuario NOT IN (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Dinero fresco')
		AND a.codigoagencia NOT IN (9, 12)
		--AND cc.dw_fechaCarga = @FECHA
		--AND per.dw_fechaCarga = @FECHA
		AND cc.dw_fechaCarga = '2024-02-29'
		AND per.dw_fechaCarga = '2024-03-04'
		AND per.CIP = '0036407';
