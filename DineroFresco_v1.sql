-- Utilizar la base de datos DWCOOPAC
USE [DWCOOPAC];

-- Declarar la fecha de la tabla FECHAMAESTRA
DECLARE @FECHA DATE;
SET @FECHA = (SELECT FECHA FROM [DWCOOPAC].dbo.ST_FECHAMAESTRA);

-- Eliminar la tabla temporal si existe
DROP TABLE IF EXISTS #REPORTEDINEROFRESCO;

-- Seleccionar los datos y almacenarlos en la tabla temporal #REPORTEDINEROFRESCO
SELECT
    cc.CODIGOPERSONA AS CodSocio,
    per.NOMBRECOMPLETO AS NombreCompleto,
    CASE WHEN cc.moneda = 1 THEN 'S' ELSE 'D' END AS Moneda,
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
    a.FechaUsuario
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
    a.periodocaja = 202310
    AND CAST(a.fechausuario AS DATE) BETWEEN '2023-10-10' AND '2023-10-16'
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
    AND a.codigousuario NOT IN ('COMPRACAR1', 'SISGODBA', 'MIGRA', 'Interna', 'Compra Cartera')
    AND a.codigoagencia NOT IN (9, 12)
    AND cc.dw_fechaCarga = @FECHA
	AND per.dw_fechaCarga = @FECHA;

-- Seleccionar los datos de la tabla temporal
SELECT * FROM #REPORTEDINEROFRESCO;

-- Eliminar la tabla temporal
-- DROP TABLE IF EXISTS #REPORTEDINEROFRESCO;

-- Seleccionar datos de la tabla DW_SYST900 donde TBLCODTAB es 21
-- SELECT * FROM DW_SYST900 WHERE TBLCODTAB = 21;
