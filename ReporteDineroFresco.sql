-- Utilizar la base de datos DWCOOPAC
USE [DWCOOPAC];

-- Declarar la fecha de la tabla FECHAMAESTRA
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA);


DECLARE @FECHA7 DATE;
SET @FECHA7 = (SELECT DATEADD(DAY, -6, FECHA )FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA);




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
		CONVERT(DATE,a.FechaUsuario)FECHAMOVIMIENTO,
		cc.PRODUCTOCODIGO 
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
		a.periodocaja IS NOT NULL 
		AND CAST(a.fechausuario AS DATE) BETWEEN @FECHA7 AND @FECHA
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
		AND cc.dw_fechaCarga = @FECHA
		AND per.dw_fechaCarga = @FECHA


	UNION

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
		CONVERT(DATE,a.FechaUsuario)FECHAMOVIMIENTO,
		cc.PRODUCTOCODIGO 
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
		AND CAST(a.fechausuario AS DATE) BETWEEN @FECHA7 AND @FECHA
		AND a.estado = 1
		AND a.tipomovimiento IN (1, 3, 5, 7)
		AND a.formapago IN (1, 2, 3, 8)
		AND cc.TABLASERVICIO = 103
		AND a.codigousuario NOT IN (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Dinero fresco')
		AND a.codigoagencia NOT IN (9, 12)
		AND cc.dw_fechaCarga = @FECHA
		AND per.dw_fechaCarga = @FECHA

	UNION

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
		CONVERT(DATE,a.FechaUsuario)FECHAMOVIMIENTO,
		cc.PRODUCTOCODIGO 
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
		AND CAST(a.fechausuario AS DATE) BETWEEN @FECHA7 AND @FECHA
		AND a.estado = 1
		AND a.tipomovimiento IN (1, 3, 5, 7)
		AND a.formapago =1
		AND cc.TABLASERVICIO = 102
		AND a.codigousuario NOT IN (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Dinero fresco')
		AND a.codigoagencia NOT IN (9, 12)
		AND cc.dw_fechaCarga = @FECHA
		AND per.dw_fechaCarga = @FECHA


		----tabla de servicio 103---cts
		----operaciones en efectivo dpf
		----Agregar PRODUCTO


		select * from #REPORTEDINEROFRESCO