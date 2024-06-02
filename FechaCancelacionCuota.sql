USE [DWCOOPAC]
---------------------------
SELECT A.CodigoSolicitud,A.Estado,A.N,
FechaCancelacion= IIF(A.ESTADO=1,B.FECHACANCELACION,NULL)
,FechaPagoParcial= IIF(A.ESTADO=2,B.FECHACANCELACION,NULL)
FROM DW_PRESTAMOCUOTAS  A
LEFT JOIN 
(SELECT PERIODOSOLICITUD,
DBO.UFN_CODIGOSOLICITUD(PERIODOSOLICITUD,NUMEROSOLICITUD)CODIGOSOLICITUD,
NUMEROCUOTA,max(FECHACANCELACION)FECHACANCELACION 
FROM dw_prestamopagoscuota 
GROUP BY PERIODOSOLICITUD,NUMEROSOLICITUD,NUMEROCUOTA)B
ON A.CODIGOSOLICITUD=B.CODIGOSOLICITUD
AND A.N=B.NUMEROCUOTA
--WHERE  A.CODIGOSOLICITUD='2018-0017173'
ORDER BY CODIGOSOLICITUD,N ASC





--Select NUMEROSOLICITUD,NUMEROCUOTA,max(FECHACANCELACION)FECHACANCELACION 
--from dw_prestamopagoscuota
--WHERE NUMEROSOLICITUD='0017173'
--group by NUMEROSOLICITUD,NUMEROCUOTA
--ORDER BY NUMEROSOLICITUD , NUMEROCUOTA ASC

--SELECT * FROM DW_PRESTAMOCUOTAS  WHERE  CODIGOSOLICITUD='2023-0188269'
--ORDER BY CODIGOSOLICITUD, N ASC


--SELECT * FROM dw_prestamopagoscuota
--WHERE  NUMEROSOLICITUD='0188269' and PERIODOSOLICITUD='2023'


--0001-0017173