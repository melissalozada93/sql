USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dasha_colaboradores]    Script Date: 14/03/2024 11:23:16 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_dwt_reporte6]
as

  DROP TABLE IF EXISTS #DW_PERSONA
  SELECT 
  dw_fechaCarga,
  CODIGOPERSONA,
  CIP,
  NOMBRECOMPLETO,
  TIPOPERSONADESCRI
  INTO #DW_PERSONA
  FROM DW_PERSONA NOLOCK
  WHERE dw_fechaCarga=(SELECT MAX(dw_fechaCarga) FROM DW_PERSONA NOLOCK)  

-----------DWT_CUENTAMOVIMIENTO----------------------------------------
  DROP TABLE IF EXISTS #REPORTE6
  SELECT 
  CODIGO=PR.CIP,
  pr.NOMBRECOMPLETO,
  pnat.FECHACUMPLEANOS,
  PRODUCTO=cc.PRODUCTOCODIGO,
  CC.NUMEROCUENTA,
  MONEDA = CASE WHEN cc.MONEDA=1 THEN 'S' ELSE 'D' END, 
  TIPOMOVIMIENTO = CASE WHEN a.TIPOMOVIMIENTO in(1,3,5,7) THEN 'ENTRADA'  
                        WHEN a.TIPOMOVIMIENTO in(2,4,6,8) THEN 'SALIDA'
                        ELSE ' ' END,
  IMPORTE = a.IMPORTE1,
  FECHAUSUARIO = CONVERT(DATE,a.FECHAUSUARIO),
  HORA = CONVERT(TIME,a.FECHAUSUARIO),
  FORMAPAGO = a.FORMAPAGODESCRI,
  CODIGOAGENCIANOM = a.AGENCIADESCRI,
  a.CODIGOUSUARIO,
  a.OBSERVACION,
  pr.TIPOPERSONADESCRI,
  TIPOPERSONA=IIF(pr.TIPOPERSONADESCRI='Persona Natural','P. Natural','P.Jur�dica'),
  a.PERIODOCAJA
  INTO #REPORTE6
  FROM DWT_CUENTAMOVIMIENTO a
  INNER JOIN DWT_CUENTACORRIENTE cc on a.NUMEROCUENTA = cc.NUMEROCUENTA
  LEFT JOIN DWT_PERSONA_NATURAL pnat on pnat.codigopersona = cc.codigopersona
  LEFT JOIN #DW_PERSONA pr  on pr.codigopersona = cc.codigopersona
  WHERE a.ESTADO=1 AND a.CODIGOUSUARIO not in('COMPRACAR1','SISGODBA','MIGRA','INTERNA', 'COMPRA CARTERA')
  AND a.CODIGOAGENCIA not in(9,12)


  UNION ALL

---------DWT_PRESTAMO_PAGOS----------------------------------------
  
  SELECT 
  p.DW_CODIGOSOCIO,
  pr.NOMBRECOMPLETO,
  pnat.FECHACUMPLEANOS,
  sp.PRODUCTO,
  NUMEROCUENTA = pp.CODIGOSOLICITUD,
  MONEDA = CASE WHEN sp.MONEDA=1 THEN 'S' ELSE 'D' END ,
  TIPOMOVIMIENTO = CASE WHEN pp.TIPOMOVIMIENTO in(1,3,5,7) THEN 'ENTRADA'  
                        WHEN pp.TIPOMOVIMIENTO in(2,4,6,8) THEN 'SALIDA'
                        ELSE ' ' END,
  IMPORTE = pp.AMORTIZACION+pp.INTERES+pp.INTERESNOCOBRADO+pp.INTERESMORATORIO+pp.INTMORANOCOBRADO,
  FECHAUSUARIO = CONVERT(DATE,pp.FECHAUSUARIO),
  HORA = CONVERT(TIME,pp.FECHAUSUARIO),
  FORMAPAGO = pp.FORMAPAGO_DESCRI,
  CODIGOAGENCIANOM = syst.TBLDESCRI,
  pp.CODIGOUSUARIO,
  OBSERVACION = '',
  pr.TIPOPERSONADESCRI,
  TIPOPERSONA=IIF(pr.TIPOPERSONADESCRI='Persona Natural','P. Natural','P.Jur�dica'),
  pp.PERIODOCAJA
  FROM DWT_PRESTAMO_PAGOS pp 
  INNER JOIN DWT_PRESTAMO p ON pp.CODIGOSOLICITUD = p.CODIGOSOLICITUD 
  INNER JOIN DWT_SOLICITUDPRESTAMO sp ON sp.CODIGOSOLICITUD = p.CODIGOSOLICITUD 
  LEFT JOIN DWT_PERSONA_NATURAL pnat ON pnat.codigopersona = sp.codigopersona
  LEFT JOIN #DW_PERSONA pr  ON pr.codigopersona = sp.codigopersona
  LEFT JOIN (SELECT * FROM [dbo].[DW_SYST900] WHERE TBLCODTAB=32) syst ON pp.CODIGOAGENCIACAJA = syst.TBLCODARG
  WHERE pp.ESTADO=1  AND pp.CODIGOUSUARIO not in('COMPRACAR1','SISGODBA','MIGRA','INTERNA','COMPRA CARTERA') 
  and pp.CODIGOAGENCIACAJA not in(9,12) 




  DELETE FROM WT_REPORTE6 WHERE FECHAUSUARIO= (SELECT DISTINCT FECHAUSUARIO FROM #REPORTE6)
  INSERT INTO WT_REPORTE6
  SELECT * 
  ,RANGO = CASE WHEN IMPORTE<=5000   THEN 'A. 5K'
                WHEN IMPORTE<=10000  THEN 'B. 10K'
				WHEN IMPORTE<=20000  THEN 'C. 20K'
				WHEN IMPORTE<=50000  THEN 'D. 50K'
				WHEN IMPORTE<=80000  THEN 'E. 80K'
				WHEN IMPORTE<=100000 THEN 'F. 100K'
				ELSE 'G. >100K'
				END
  ,FILTRO_MONTO = IIF(IMPORTE>99999.99, 'S�', 'NO')
  ,FILTRO_ABACO = IIF(OBSERVACION LIKE '%3227%','SI','NO')
  ,RANGO_HORA = IIF(DATENAME(HOUR, HORA)=0,0, DATENAME(HOUR, DATEADD(HOUR, 1, HORA)))
  ,FILTRO_DF = IIF(PERIODOCAJA IS NOT NULL AND ( OBSERVACION LIKE '%DEPOSITO EN CUENTA%'
				 OR OBSERVACION LIKE '%REMESA KYODAI%'
				 OR OBSERVACION LIKE '%22889%'
				 OR OBSERVACION LIKE '%12117%'
				 OR OBSERVACION LIKE '%Liberacion de Cheque%'),'Dinero fresco','Transf. Interna')
  ,[DINERO_FRESCO]=IIF(PERIODOCAJA IS NOT NULL AND( OBSERVACION LIKE '%DEPOSITO EN CUENTA%'
				 OR OBSERVACION LIKE '%REMESA KYODAI%'
				 OR OBSERVACION LIKE '%22889%'
				 OR OBSERVACION LIKE '%12117%'
				 OR OBSERVACION LIKE '%Liberacion de Cheque%'),'SI','NO')
  ,[DEP_BANCOS]=IIF(PERIODOCAJA IS NOT NULL, IIF( OBSERVACION LIKE '%22889%'
				 OR OBSERVACION LIKE '%12117%','SI','NO'),'')
  ,[FORMAPAGO2]=CASE WHEN PRODUCTO = 'AHV' 
				AND TIPOMOVIMIENTO = 'ENTRADA' 
				AND OBSERVACION like '%12117%' OR OBSERVACION like '%22889%'
				THEN 'Bancos' ELSE FORMAPAGO END

  --INTO #WT_REPORTE6
  FROM #REPORTE6
      
 
 --SELECT * FROM WT_REPORTE6 WHERE CODIGO='0013752'


 
 UPDATE A
 SET FILTRO_DF='Dinero fresco' ,DINERO_FRESCO='SI'
 --SELECT * 
 FROM WT_REPORTE6 A WHERE OBSERVACION LIKE '%Liberacion de Cheque%' AND PERIODOCAJA IS NULL AND DINERO_FRESCO='NO'


