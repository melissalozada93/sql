CREATE OR REPLACE PACKAGE BODY SISGODBA.PKG_DWH IS

  -- Objetivo    : Paquete para extracción de datos para datawarehouse 
  -- Fecha       : 07/09/2018
  -- Comentarios : Proyecto DatawareHouse
 /* 
        DROP TABLE PERSONA_DWH 
        CREATE TABLE PERSONA_DWH AS
        select CODIGOPERSONA, substr(NOMBRECOMPLETO,1,10) as nombrecompleto, substr(NOMBRECORTO,1,10) as nombrecorto, CIP, 
        substr(substr(NUMERORUC,1,3)|| substr(NUMERORUC,5,20)  || substr(NUMERORUC,4,3) ,1,11) as numeroruc,  
        TIPOPERSONA, CALIFICACION, substr(EMAIL,4,50) as email, substr(PAGINAWEB,6,50) AS PAGINAWEB, NACIONALIDAD,
        ESTADO, CODIGOUSUARIO, FECHAUSUARIO, 
        MODIFICACIONGRUPO, 
        ENVIOCORRESPONDENCIA  from PERSONA 
*/

    Procedure P_OBT_CURSOR(P_CURSOR OUT SISGODBA.GEN08030.CursorType, NOMBRETABLA IN VARCHAR2, FECHAINICIO IN DATE, FECHAFIN IN DATE) is
    nFechaini Date;
    nFechafin Date;

    Begin
        nFechaini := TO_DATE(TO_CHAR(FECHAINICIO),'DD/MM/RRRR');        
        nFechafin := TO_DATE(TO_CHAR(FECHAFIN),'DD/MM/RRRR'); 

if nombretabla = 'MIGRATIONLOG' THEN
    OPEN P_CURSOR FOR

WITH
CTE AS (
    SELECT HOY, HOY-1,P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD,
    PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) AS TOTALCUOTAS,
    (SELECT COUNT(PC.ESTADO) FROM PRESTAMOCUOTAS PC WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=1)  AS NROCUOTASPAGADAS  ,
    (SELECT COUNT(PC.ESTADO) 
    FROM PRESTAMOCUOTAS PC
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 ) AS NROCUOTASVIGENTES ,
    (SELECT COUNT(PC.ESTADO) 
    FROM PRESTAMOCUOTAS PC
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND PC.FECHAVENCIMIENTO < HOY ) AS NROCUOTASATRASADAS,
    (SELECT COUNT(PC.ESTADO) 
    FROM PRESTAMOCUOTAS PC
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=4 ) AS NROCUOTASREPROG,
    (SELECT MIN(PC.FECHAVENCIMIENTO) 
    FROM PRESTAMOCUOTAS PC 
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND FECHAVENCIMIENTO < HOY ) AS FECHAMINCUOTAVENCIDA,
    PKG_CARTERA.F_OBT_DIASATRASO (HOY-1,P.PERIODOSOLICITUD,P.NUMEROSOLICITUD) AS DIASATRASO,
    (SELECT NVL(COUNT(*),0) 
    FROM PRESTAMOCUOTAS PC
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=1 AND FECHAVENCIMIENTO >= HOY) AS CUOTASADELANTADAS,
    (SELECT SUM(PC.AMORTIZACION) 
    FROM PRESTAMOCUOTAS PC 
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND FECHAVENCIMIENTO < HOY ) AS CAPITALVENCIDO,
    (SELECT MAX(PC.FECHAVENCIMIENTO) 
    FROM PRESTAMOCUOTAS PC 
    WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2  ) AS FECHAULTIMACUOTA
    FROM PRESTAMO P 
    WHERE P.PERIODOSOLICITUD NOT IN (1)  AND P.PERIODOSOLICITUDCONCESIONAL IS NULL AND P.NUMEROSOLICITUDCONCESIONAL  IS NULL
    AND PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) > 0
)
select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOCUOTASRESUMEN', COUNT(*), NULL as FECINI, NULL as FECFIN from CTE
UNION
        select SYSDATE AS FECPROC, 'ORACLE' AS ORIGEN, 'PERSONA' AS NOMTABLA, COUNT(*) AS Q, NULL as FECINI, NULL as FECFIN from persona
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'prestamopagos', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') as FECFIN from prestamopagos  WHERE trunc(fechausuario) BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr')
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SYST901', COUNT(*), NULL as FECINI, NULL as FECFIN from SYST901
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SYST902', COUNT(*), NULL as FECINI, NULL as FECFIN from SYST902
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SYST900', COUNT(*), NULL as FECINI, NULL as FECFIN from SYST900
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SYST090', COUNT(*), NULL as FECINI, NULL as FECFIN from SYST090
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SYST010', COUNT(*), NULL as FECINI, NULL as FECFIN from SYST010 
        
       UNION-- aportes
        select SYSDATE, 'ORACLE' AS ORIGEN, 'CUENTAMOVIMIENTO', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechaini,'dd/mm/rrrr') as FECFIN 
        from aportes ap
        left join cuentacorriente cc on cc.numerocuenta = ap.numerocuenta
        left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona 
        where  trunc(ap.fechausuario) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(ap.fechausuario) <=to_date(nFechafin,'dd/mm/rrrr')
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'BIEN', COUNT(*), NULL as FECINI, NULL as FECFIN from BIEN
        
        UNION --CAPTACIONANEXO
        select SYSDATE, 'ORACLE' AS ORIGEN, 'CUENTASALDOS', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') as FECFIN 
        from captacionanexo cca
        inner join cuentacorriente cc on cc.numerocuenta = cca.numerocuenta
        left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona 
        where trunc(cca.fecha) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(cca.fecha) <=to_date(nFechafin,'dd/mm/rrrr')
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'CIIUDETALLE', COUNT(*), NULL as FECINI, NULL as FECFIN from CIIUDETALLE
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'CONVENIOS', COUNT(*), NULL as FECINI, NULL as FECFIN from CONVENIOS
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'CUENTACORRIENTE', COUNT(*), NULL as FECINI, NULL as FECFIN 
        from CUENTACORRIENTE cc
        left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona     
               
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'DATOSCUENTACORRIENTE', COUNT(*), NULL as FECINI, NULL as FECFIN 
        from DATOSCUENTACORRIENTE dcc 
        left join cuentacorriente cc on cc.numerocuenta = dcc.numerocuenta   
        left join (select codigopersona from personarol pr where codigorol in(2,3) 
        group by codigopersona) prol on prol.codigopersona = cc.codigopersona
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'DATOSSOCIO', COUNT(*), NULL as FECINI, NULL as FECFIN from DATOSSOCIO
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'GARANTEBIEN', COUNT(*), NULL as FECINI, NULL as FECFIN from GARANTEBIEN 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'GARANTECUENTA', COUNT(*), NULL as FECINI, NULL as FECFIN from GARANTECUENTA
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SBSBD04', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') as FECFIN from SBSBD04
        where trunc(fecha) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(fecha) <=to_date(nFechafin,'dd/mm/rrrr')
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PADRONCONTROL', COUNT(*), NULL as FECINI, NULL as FECFIN from PADRONCONTROL
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PADRONFECHA', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') as FECFIN FROM PADRONFECHA 
        WHERE FECHA BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr')
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONADATOS', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONADATOS
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONADIRECCION', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONADIRECCION
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONAJURIDICA', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONAJURIDICA 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONANATURAL', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONANATURAL
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONAJURVINCULADA', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONAJURVINCULADA
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONANATVINCULADA', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONANATVINCULADA 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PERSONAROL', COUNT(*), NULL as FECINI, NULL as FECFIN from PERSONAROL
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOANEXO', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from PRESTAMOANEXO
        where (trunc(fecha)-1)>= to_date(nFechaini,'dd/mm/rrrr')  and (trunc(fecha)-1)<= to_date(nFechafin,'dd/mm/rrrr') 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOANEXOHISTORICO', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from PRESTAMOANEXOHISTORICO
        where (trunc(fecha)-1)>= to_date(nFechaini,'dd/mm/rrrr')  and (trunc(fecha)-1)<= to_date(nFechafin,'dd/mm/rrrr') 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOCAMBIOSITUACION', COUNT(*), NULL as FECINI, NULL as FECFIN from PRESTAMOCAMBIOSITUACION

      --  UNION
     --   select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOCUOTASFECHA', COUNT(*), NULL as FECINI, NULL as FECFIN from PRESTAMOCUOTASFECHA
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMODETALLE', COUNT(*), NULL as FECINI, NULL as FECFIN from PRESTAMODETALLE
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'REPOTIFINANZASPADRON', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from REPOTIFINANZASPADRON
        where FECHAPADRON>= to_date(nFechaini,'dd/mm/rrrr') and FECHAPADRON<= to_date(nFechafin,'dd/mm/rrrr') 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'REPOTIFINANZASPASIVAS', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from REPOTIFINANZASPASIVAS
        where FECHA_SALDO>= to_date(nFechaini,'dd/mm/rrrr') and FECHA_SALDO<= to_date(nFechafin,'dd/mm/rrrr') 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SBSBD01', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from SBSBD01
        where FECHA>= to_date(nFechaini,'dd/mm/rrrr') and FECHA<= to_date(nFechafin,'dd/mm/rrrr') 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SBSBD02A', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from SBSBD02A
        WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND PERIODO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') )
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SBSBD02B', COUNT(*), to_date(nFechaini,'dd/mm/rrrr') as FECINI, to_date(nFechafin,'dd/mm/rrrr') from SBSBD02B
        WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND PERIODO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') )
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SBSBD03A', COUNT(*), NULL as FECINI, NULL as FECFIN from SBSBD03A
        WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND ANIO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') ) 
        
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'SOLICITUDPRESTAMO', COUNT(*), NULL as FECINI, NULL as FECFIN FROM SOLICITUDPRESTAMO
               
        UNION
        select SYSDATE, 'ORACLE' AS ORIGEN, 'XTIPOCAMBIO', COUNT(*), NULL as FECINI, NULL as FECFIN from XTIPOCAMBIO
        
       UNION
       select SYSDATE, 'ORACLE' AS ORIGEN, 'XTIPOCAMBIOAJUSTE', COUNT(*), NULL as FECINI, NULL as FECFIN from XTIPOCAMBIOAJUSTE

	UNION
        SELECT SYSDATE, 'ORACLE' AS ORIGEN, 'XLIBRODIARIO', COUNT(*), to_date(nFechaini,'dd/mm/rrrr')as FECINI, to_date(nFechafin,'dd/mm/rrrr')as FECFIN from XLIBRODIARIO 
	WHERE FECHAASIENTO BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr')
         
	UNION
	SELECT SYSDATE, 'ORACLE' AS ORIGEN, 'XLIBRODIARIODETALLE', COUNT(*), NULL as FECINI, NULL as FECFIN 
	FROM XLIBRODIARIODETALLE WHERE PERIODOLIBRO = to_char(to_date(nFechaini,'dd/mm/rrrr'), 'YYYY')||to_char(to_date(nFechafin,'dd/mm/rrrr'), 'mm')

	UNION
	SELECT SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMO', COUNT(*), NULL as FECINI, NULL as FECFIN 
	FROM PRESTAMO 

	/*UNION
	SELECT SYSDATE, 'ORACLE' AS ORIGEN, 'PRESTAMOCUOTASRESUMEN', COUNT(*), NULL as FECINI, NULL as FECFIN FROM PRESTAMO P 
	WHERE P.PERIODOSOLICITUD NOT IN (1) AND P.ESTADO =2 AND P.PERIODOSOLICITUDCONCESIONAL IS NULL AND P.NUMEROSOLICITUDCONCESIONAL  IS NULL
	AND PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) > 0*/




       ;



 
END IF;

        if nombretabla = 'APORTES' then
           Open P_CURSOR For
                                select HOY, ap.fechausuario, ap.NUMEROCUENTA, ap.NUMERODOCUMENTO, ap.CODIGOAGENCIA, ap.FECHAMOVIMIENTO, ap.FECHADISPONIBLE, ap.CONDICION, ap.TIPOMOVIMIENTO,
                                ap.FORMAPAGO, 
                               /* case when prol.codigopersona is not null and cc.tablaservicio = 103 and ap.IMPORTE1>0 then 1 else ap.IMPORTE1 end as IMPORTE1, 
                                case when prol.codigopersona is not null and cc.tablaservicio = 103 and ap.SALDOIMPORTE1>0 then 1 else ap.SALDOIMPORTE1 end as SALDOIMPORTE1, 
                                case when prol.codigopersona is not null and cc.tablaservicio = 103 and ap.IMPORTE2>0 then 1 else ap.IMPORTE2 end as IMPORTE2, 
                                case when prol.codigopersona is not null and cc.tablaservicio = 103 and ap.SALDOIMPORTE2>0 then 1 else ap.SALDOIMPORTE2 end as SALDOIMPORTE2, */
                                ap.IMPORTE1, 
                                ap.SALDOIMPORTE1, 
                                ap.IMPORTE2, 
                                ap.SALDOIMPORTE2, 
                                ap.OBSERVACION, ap.ESTADO, ap.CODIGOUSUARIO, ap.FECHAUSUARIO, 
                                ap.APORTEEXTRAORDINARIO, ap.codigoagenciacaja, ap.periodocaja, ap.numerocaja
								from aportes ap
                                left join cuentacorriente cc on cc.numerocuenta = ap.numerocuenta
                                left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona 
                                where  trunc(ap.fechausuario) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(ap.fechausuario) <=to_date(nFechafin,'dd/mm/rrrr');
       end if ;
        if nombretabla = 'BIEN' then 
                    Open P_CURSOR For       
                            select HOY, HOY-1, CODIGOPERSONA, ITEM, TIPOBIEN, CODIGOBIEN, MONEDA, FECHATASACION, VALORESTIMADO, VALORCOMERCIAL, VALORREALIZACION,
                            REGISTROPUBLICO, SITUACIONBIEN, CODIGOPERSONANOTARIA, ESTADO, OBSERVACION, CODIGODIRECCION, TIPOVINCULACION, CODIGOUSUARIO,
                            FECHAUSUARIO, FECHAVENCIMIENTO, 
                            CODIGOVINCULADO,
                            CIPPERITO, REGISTROPERITOVALUADOR, FECHAVALUACION, OFICINAREGISTRAL, CLASIFICACIONGARANTIA, ZONAREGISTRAL, FECHACRI, CODIGOPERITO,
                            CODIGOGARANTIA, 
                            KARDEXNOTARIA, TOMONOTARIA, FICHANOTARIA,
                            ASIENTONOTARIA, SITUACION, INDMIVIVIENDA from bien;
           end if ;                                   
        if nombretabla = 'CAPTACIONANEXO' then 
                    Open P_CURSOR For           
                            select HOY,cca.FECHA, cca.NUMEROCUENTA, cca.TIPOTRANSACCION, 
                            /*case when prol.codigopersona is not null and cc.tablaservicio = 103 and cca.SALDOIMPORTE1>0 then 1 else cca.SALDOIMPORTE1 end as SALDOIMPORTE1, 
                            case when prol.codigopersona is not null and cc.tablaservicio = 103 and cca.SALDOIMPORTE2>0 then 1 else cca.SALDOIMPORTE2 end as SALDOIMPORTE2,   */
                            cca.SALDOIMPORTE1, 
                            cca.SALDOIMPORTE2, 
                            cca.INTERESTOTAL, cca.INTERESDIA, cca.INTERESCOBRADO,
                            cca.INTERESPORCOBRAR, cca.MONTOGARANTIA, cca.MONTODISPONIBLE, cca.FECHAAPERTURA, cca.TABLASERVICIO, cca.ARGUMENTOSERVICIO, cca.DESCRIPCIONSIP,
                            cca.NUMERORENOVACION, cca.MONEDA, cca.FECHAULTIMOMOVIMIENTO,  cca.TASAINTERES, cca.TASAINTERESANUAL, cca.NUMERODIAS  from captacionanexo cca
                            inner join cuentacorriente cc on cc.numerocuenta = cca.numerocuenta
                            left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona 
                            where trunc(cca.fecha) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(cca.fecha) <=to_date(nFechafin,'dd/mm/rrrr');
                            
           end if ;                                       
        if nombretabla = 'CIIUDETALLE' then
                    Open P_CURSOR For        
                select CODIGOCIIU, CODIGODETALLE, DESCRIPCIONDETALLECIIU, NIVEL, CATEGORIA from ciiudetalle;        
        end if ;                    
        if nombretabla = 'CUENTACORRIENTE' then
                    Open P_CURSOR For        
                                select
                                HOY, HOY-1, NUMEROCUENTA, NOMBRECUENTA, CODIGOAGENCIA, cc.CODIGOPERSONA, TIPOTRANSACCION, TABLASERVICIO, ARGUMENTOSERVICIO,
                                MONEDA, CONDICION, NUEVOAPORTE, FECHAAPERTURA, 
                               /* CASE WHEN PROL.CODIGOPERSONA IS NOT NULL AND TABLASERVICIO = 103 AND SALDOIMPORTE1>0 THEN 1 ELSE SALDOIMPORTE1 END AS SALDOIMPORTE1, 
                                CASE WHEN PROL.CODIGOPERSONA IS NOT NULL AND TABLASERVICIO = 103 AND SALDOIMPORTE2>0 THEN 1 ELSE SALDOIMPORTE2 END AS SALDOIMPORTE2, */
                                SALDOIMPORTE1, 
                                SALDOIMPORTE2,
                                FECHARENUNCIA, DISPONIBILIDAD,
                                ULTIMOMOVIMIENTO, CODIGOTRANSACCION,
                                SUBSTR(PKG_SYST902.F_OBT_TBLDESCRI(TABLASERVICIO, ARGUMENTOSERVICIO),1,3) AS PRODUCTO, 
                                CODIGOUSUARIO, ESTADO   --,
                                --PKG_DATOSCUENTACORRIENTE.F_OBT_TIPOCONFORMACION( CC.NUMEROCUENTA,PKG_DATOSCUENTACORRIENTE.F_OBT_MAXFECHAINICIO(CC.NUMEROCUENTA)) AS TIPOCONFORMACIÓN
                                FROM CUENTACORRIENTE CC
                                LEFT JOIN (SELECT CODIGOPERSONA FROM PERSONAROL PR WHERE CODIGOROL IN(2,3) GROUP BY CODIGOPERSONA) PROL ON PROL.CODIGOPERSONA = CC.CODIGOPERSONA;   
        end if ;
        if nombretabla = 'DATOSCUENTACORRIENTE' then
                    Open P_CURSOR For        
                                select HOY, HOY-1, dcc.NUMEROCUENTA, dcc.FECHAINICIO, dcc.FECHAVENCIMIENTO, 
                                /*case when prol.codigopersona is not null and cc.tablaservicio = 103 and dcc.MONTOINICIAL>0 then 1 else dcc.MONTOINICIAL end as MONTOINICIAL, */
                                dcc.MONTOINICIAL, 
                                dcc.NUMERODIAS, dcc.TASAINTERES,
                                dcc.TIPOPLAZO, dcc.TASAINTERESANUAL, dcc.TASAAUXILIAR, dcc.TASAAUXILIARANUAL, dcc.CONDICIONESESPECIALES, dcc.NUMEROCUOTAS, dcc.MONTOCUOTA,
                                dcc.DIAPAGO, dcc.FINALIDAD, dcc.FLAGENVIO, dcc.DISPONIBLESIP  from DATOSCUENTACORRIENTE dcc left join cuentacorriente cc on cc.numerocuenta = dcc.numerocuenta   
                                left join (select codigopersona from personarol pr where codigorol in(2,3) group by codigopersona) prol on prol.codigopersona = cc.codigopersona;     
        end if ;
        if nombretabla = 'DATOSSOCIO' then
                    Open P_CURSOR For        
select HOY, HOY-1, CODIGOPERSONA, ORIGEN, SITUACIONORIGEN, GRADO, TIPOSOCIO, CODIGOGRUPO, CODIGOSUBGRUPO, CODIGODEPENDENCIA, DESTINOENVIO,
SITUACION, TITULAR, CODIGOAGENCIA, REGIMEN, FECHAINSTITUCION, 
NUMERODEPOSITO, CARTADECLARATORIA, 
NUMERORUC, RAZONSOCIAL, FECHAINGRESO, CARGO, 
CODIGOPROMOTOR, NIKEN, OCUPACION, CODIGOSECTORISTA,
FECHAINGRESOCOOP, INGRESOMENSUAL , MONEDAINGRESOMENSUAL, CODIGOPERSONAJURIDICA, departamentonacimiento,provincianacimiento,distritonacimiento, tipodeposito, autorizaciondatos
from DATOSSOCIO; 
        end if ;
        if nombretabla = 'GARANTEBIEN' then
                    Open P_CURSOR For                
                            select HOY, HOY-1, PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROGARANTE, NUMEROBIEN, CODIGOPERSONA, ITEM, FLAGTIPOBIEN, IMPORTE 
                            from GARANTEBIEN;        
        end if ;
        if nombretabla = 'GARANTECUENTA' then
                    Open P_CURSOR For        
                            select HOY, HOY-1, PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROGARANTE, ITEM, NUMEROCUENTA, IMPORTE, IMPORTEAPLICADO  from garantecuenta;        
        end if ;
        if nombretabla = 'NIVELEVALUATIVO' then
                    Open P_CURSOR For        
                            select CODIGONIVEL, DESCRIPCION, SIGLAS, ESTADO from NIVELEVALUATIVO;
        end if ;
        if nombretabla = 'PERSONA' then
                    Open P_CURSOR For        
                                select HOY, HOY-1,CODIGOPERSONA, NOMBRECOMPLETO, NOMBRECORTO, CIP, NUMERORUC, TIPOPERSONA, CALIFICACION, EMAIL, PAGINAWEB, NACIONALIDAD,
                                ESTADO, CODIGOUSUARIO, FECHAUSUARIO, 
                                MODIFICACIONGRUPO, 
                                ENVIOCORRESPONDENCIA from PERSONA;        
        end if ;
        if nombretabla = 'PERSONADATOS' then
                    Open P_CURSOR For        
                                select CODIGOPERSONA, ORIGEN, GRADO, REGIMEN
                                from PERSONADATOS;        
        end if ;
        if nombretabla = 'PERSONADIRECCION' then
                    Open P_CURSOR For        
                        select HOY, HOY-1, CODIGOPERSONA, CODIGODIRECCION, TIPODIRECCION, ESTADO, ENVIOCORREO, ENVIOBOLETIN, ENVIOCORRESPONDENCIA  
                        from PERSONADIRECCION;        
        end if ;
        if nombretabla = 'PERSONAJURIDICA' then
                    Open P_CURSOR For        
                        select CODIGOPERSONA, NATURALEZAJURIDICA, TIPOEMPRESA, MAGNITUD, NUMEROFICHA, NUMEROTOMO, NUMEROFOLIO, OFICINAREGISTRAL, FECHAANIVERSARIO, 
				NUMEROEMPLEADOS, NUMEROOBREROS,PARTIDAECONOMICA,  CODIGOCIIU, CODIGODETALLE, ZONAREGISTRAL,TIPOSOCIEDAD, CODIGOCIIUSBS, FECHAINICIOACTIVIDADES
				from PERSONAJURIDICA;        
        end if ;
        if nombretabla = 'PERSONANATURAL' then
                    Open P_CURSOR For        
                        select CODIGOPERSONA, APELLIDOPATERNO, APELLIDOMATERNO, NOMBRES, TIPODOCUMENTOID, NUMERODOCUMENTOID, SEXO,
                        ESTADOCIVIL, FECHACUMPLEANOS, LUGARNACIMIENTO, 
                        NUMEROPASAPORTE, CODIGOCIIU, CODIGODETALLE, DEPARTAMENTONACIMIENTO, PROVINCIANACIMIENTO, DISTRITONACIMIENTO,
                        trunc((to_date((to_char(hoy,'yyyy')||'-'||to_char(hoy,'mm')||'-'||to_char(hoy,'dd')),'yyyy-mm-dd')-fechacumpleanos)/365) as edad
                          from personanatural;        
        end if ;
        if nombretabla = 'PRESTAMO' then
                    Open P_CURSOR For        
                            select HOY, HOY-1, PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROCUENTA, CODIGOAGENCIA, CODIGOPERSONA, FORMASOLICITUD, SECTORECONOMICO,
                            TIPOBIENGARANTIA, FINALIDADPRESTAMO, FECHAPRESTAMO, FECHAPROGRAMACION, MONEDA, 
                            MONTOPRESTAMO, SALDOPRESTAMO, 
                            ULTIMOCAPITAL, ULTIMOINTERES, ULTIMAMORA, INTERESNOCOBRADO, MORANOCOBRADO, 
                            FECHACARTA, 
                            NUMEROPAGARE, ESTADO, CODIGOUSUARIO,  FECHAUSUARIO, CODIGOAGENCIACAJA, PERIODOCAJA, NUMEROCAJA,
                            PAGAREANTERIOR, 
                            PERIODOSOLICITUDCONCESIONAL, NUMEROSOLICITUDCONCESIONAL, NUMEROLINEA,
                            ISALBIN, IINTERE, IMORA, LOTE, NUMEROEXPEDIENTE, SITUACIONPRESTAMO--,
                           -- DECODE( pkg_bdsoc.obt_tienecredito (codigopersona),'N','N',pkg_bdsoc.obt_creditoatrasado(codigopersona) ) AS CREDITO_ATRASADO
		--	    substr(pkg_syst902.f_obt_tbldescri(sp.tiposolicitud,sp.tipoprestamo) ,1,3) 
			    from prestamo;
                                    
        end if ;
        if nombretabla = 'PRESTAMOANEXOHISTORICO' then 
                    Open P_CURSOR For           
                                    select HOY, PERIODOSOLICITUD, NUMEROSOLICITUD, FECHA-1, SALDOPRESTAMO, INTERES, MORA, MONTOPRESTAMO, SALDOCAPITAL, 
                                    MONEDA, TIPOSOLICITUD, TIPOPRESTAMO, CODIGOPERSONAANALISTA, TASAINTERES, TASAADICIONAL, FECHAPRESTAMO, ESTADO, SITUACIONPRESTAMO,
                                    CODIGOUSUARIO, CODIGOSOCIO, ULTIMOINTERES, 
                                    CODIGOAGENCIA, NUMEROPAGARE,
                                    CODIGOPROMOTOR, CODIGOZONAPROMOTOR, LOTE, NUMEROEXPEDIENTE,FECHACARTA, ISALBIN, CALIFICACION
                                    from prestamoanexohistorico
                                    where (trunc(fecha)-1)>= to_date(nFechaini,'dd/mm/rrrr')  and (trunc(fecha)-1)<= to_date(nFechafin,'dd/mm/rrrr') ;
                                         
           end if ;        
        if nombretabla = 'PRESTAMODETALLE' then
                    Open P_CURSOR For        
                        select HOY, HOY-1,PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROAMPLIACION, TIPOSOLICITUD, TIPOPRESTAMO, TASAINTERES, CONDICION, DIASPAGO,
                        PERIODOGRACIA, FORMAPAGO, NUMEROCUOTAS, TIPOCUOTA, MONTOCUOTA, CODIGOUSUARIO, FECHAUSUARIO, OBSERVACION, TASAADICIONAL,
                        TIPOINTERES, 
                        TASAMORATORIA 
                        from prestamodetalle;        
        end if ;
        if nombretabla = 'PRESTAMOPAGOS' then 
                    Open P_CURSOR For           
                                select HOY,fechausuario,PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROITEM, CODIGOAGENCIA, CONDICION, TIPOMOVIMIENTO, FORMAPAGO,
                                FECHACANCELACION, AMORTIZACION, INTERES, INTERESNOCOBRADO, REAJUSTE, INTERESMORATORIO, INTMORANOCOBRADO, INTERESANTERIOR,
                                SALDOPRESTAMO, DIASMORA, ESTADO, CODIGOUSUARIO, FECHAUSUARIO, CODIGOAGENCIACAJA, PERIODOCAJA, NUMEROCAJA, OBSERVACIONES,
                                FECHADEPOSITO, PORTES, 
                                FECHAEXTORNO, ITEMEXTORNADO, SEGUROBIEN,
				                PKG_REPORTESCARTERA.F_OBT_INTERES_DIF_DETALLE(
				                periodosolicitud, numerosolicitud, numeroitem, fechacancelacion,SUBSTR(pkg_syst902.f_obt_tbldescri(
				                Pkg_Solicitudprestamo.F_OBT_TIPOSOLICITUD(PERIODOSOLICITUD,NUMEROSOLICITUD),PKG_SOLICITUDPRESTAMO.F_OBT_TIPOPRESTAMO(PERIODOSOLICITUD,NUMEROSOLICITUD)
				                ),1,3)) as  FRP_intdiferido
                                from prestamopagos
                                where trunc(fechausuario) >=to_date(nFechaini,'dd/mm/rrrr') and trunc(fechausuario) <=to_date(nFechafin,'dd/mm/rrrr');
                                
                                                                
                          
           end if ;                
        if nombretabla = 'SOLICITUDPRESTAMO' then
                    Open P_CURSOR For        
                            select HOY, HOY-1, PERIODOSOLICITUD, NUMEROSOLICITUD, NUMEROCUENTA, CODIGOAGENCIA, CODIGOPERSONA, FORMASOLICITUD, TIPOSOLICITUD,
                            TIPOPRESTAMO, SECTORECONOMICO, TIPOBIENGARANTIA, TASAINTERES, FINALIDADPRESTAMO, FECHARECEPCION, FECHASOLICITUD, FECHAPROGRAMACION,
                            CONDICION, DIASPAGO, PERIODOGRACIA, CODIGOPROPUESTA,  CODIGOPERSONAANALISTA, MONEDA, MONTOSOLICITADO, NUMEROCUOTAS,
                            MONTOCUOTA, FORMADESGRAVAMEN, DESGRAVAMEN, TIPOCUOTA, MOTIVOANULACION, ORIGENPRESTAMO, OBSERVACION,  NUMEROPAGARE,
                            ESTADO, CODIGOUSUARIO, FECHAUSUARIO, FORMADESEMBOLSO, TASAADICIONAL, CODIGOPROMOTOR, TIPOINTERES, MONTOBIEN,
                            CODIGOTAMBO, NUMEROCICLO, TIPOAPROBACION, CODIGOFUENTE, 
                            CODIGOZONAPROMOTOR, TASACOSTOEFECTIVOANUAL, DIAVENCIMIENTOCUOTAS,
                            MODALIDADSOLICITUD, CODIGOCLIENTEPROMOTOR,  PAGAINTERESES, PERIODOSOLICITUDCONCESIONAL, NUMEROSOLICITUDCONCESIONAL,
                            NUMEROLINEA, PAGAREANTERIOR, SEGURODESGRAVAMEN, SEGUROADICIONAL, MONTOSEGUROADICIONAL, FLAGCRONOGRAMA, FLAGDESEMBOLSO,
                            TASAMORATORIA  from solicitudprestamo;         
        end if ;
        if nombretabla = 'XTIPOCAMBIOAJUSTE' then
                    Open P_CURSOR For        
                        select HOY, FECHA, COMPRA, VENTA, PROMEDIO, ESTADO, CODIGOUSUARIO, FECHAUSUARIO from xtipocambioajuste;        
        end if ;
        if nombretabla = 'SYST010' then
                    Open P_CURSOR For        
                           select USRCODUSU, USRNOMUSU, CODIGOPERSONA from syst010;        
        end if ;
        if nombretabla = 'SYST090' then
                    Open P_CURSOR For        
                            select UBGCODREG,UBGCODDEP,UBGCODPRO,UBGCODDIS,UBGNOMBRE,CODUBIGEO from syst090;        
        end if ;
        if nombretabla = 'SYST150' then
                    Open P_CURSOR For        
                            select CODIGOZONA, NOMBREZONA, CODIGOOFICINA, NOMBREOFICINA from syst150;        
        end if ;                                                                                                                                                
        if nombretabla = 'SYST900' then
                    Open P_CURSOR For        
                            select TBLCODTAB, TBLCODARG, TBLDESCRI, TBLDESABR, TBLESTADO, TBLDETALLE from syst900;        
        end if ;        
        if nombretabla = 'SYST901' then
                    Open P_CURSOR For        
                            select TBLCODTAB, TBLCODARG, TBLDESCRI, TBLTIPOTARIFA, TBLTARIFA, TBLESTADO from syst901;        
        end if ;
        if nombretabla = 'SYST902' then
                    Open P_CURSOR For        
                            select TBLCODTAB, TBLCODARG, TBLDESCRI, TBLMONEDA, TBLGRUPO, TBLTIPOTARIFA, TBLTARIFA, 
                            TBLDIAS,
                            TBLTARIFAAUXILIAR, 
                            TBLTARIFAANUAL, TBLTARIFAANUALAUXILIAR, 
                            TBLDESCRIGENERAL,
                            TBLTIPOPRODUCTO
                            from syst902 ;         
        end if ;                
        if nombretabla = 'DIRECCION' then
                    Open P_CURSOR For        
                            select codigodireccion, callenumero, plaza, codigoregion, codigodepartamento, codigoprovincia, codigodistrito, codigopais, tipovia, manzana, lote, referencia, codigocalle,
                            numeropuerta, numerointerior, codigopostal from direccion;         
        end if ;  

        
        
          if nombretabla ='CONFIG_MODELO_MODALIDAD' then
                    Open P_CURSOR For  
                            select CODIGOCREDITO,CODIGOPRODUCTO,CODIGOMODALIDAD,DESCRIPCIONMODALIDAD,ESTADO
                            from config_modelo_modalidad
                            where estado=1 ;
                            
           end if;
          

           if nombretabla ='CONFIG_MODELO_DOCUMENTO' then
                    Open P_CURSOR For  
                            select CODIGOCREDITO,CODIGOPRODUCTO,CODIGOMODALIDAD,CODIGODOCUMENTO,DESCRIPCIONDOCUMENTO,ESTADO
                            from config_modelo_documento
                            where estado=1 ;
                            
           end if;
          
        if nombretabla= 'PERSONANATVINCULADA' then
                    Open P_CURSOR For
                            select HOY, HOY-1 ,CODIGOPERSONA,TIPOVINCULO,PERSONAVINCULADA,DERECHOHABIENTE
                            from personanatvinculada
                             ;
            end if;
            
            
            if nombretabla= 'PERSONAJURVINCULADA' then
                    Open P_CURSOR For
                            select HOY, HOY-1 ,CODIGOPERSONA,TIPOVINCULO,PERSONAVINCULADA,INDICADOR,DIRECTOR,ACCIONISTA
                            from personajurvinculada
                             ;
            end if;
            
            if nombretabla='ROLES' then
                    Open P_CURSOR For
                            select CODIGOROL,DESCRIPCION
                            from roles
                            where estado=1 ;
             end if;  
                          
             if nombretabla='PERSONAROL' then
                    Open P_CURSOR For
                            select HOY, HOY-1,CODIGOPERSONA,CODIGOROL
                            from personarol;
                                            
             end if; 
             
             if nombretabla = 'SUBGRUPO' then
                    Open P_CURSOR For        
                            select  CODIGOSUBGRUPO, DESCRIPCION 
                            from subgrupo  ;         
             end if ;
                
             if nombretabla = 'DEPENDENCIA' then
                    Open P_CURSOR For        
                            select CODIGOSUBGRUPO,CODIGODEPENDENCIA, DESCRIPCION,CODIGOPERSONA
                            from dependencia;         
            end if ;
            
            
            if nombretabla = 'PROPUESTAPRESTAMO' then
                    Open P_CURSOR For        
                            select PERIODOSOLICITUD,NUMEROSOLICITUD, ITEMPROPUESTA,CODIGONIVEL,FECHAPROPUESTA,TIPOSOLICITUD,TIPOPRESTAMO,MONTOPROPUESTO,NUMEROCUOTAS,APROBADO,CODIGOUSUARIO,
                            FECHAUSUARIO, MONTOPRIMERDESEMBOLSO, SITUACIONSOLICITUD, MONTOGARANTIASOLES , MONTOGARANTIADOLARES
                            from propuestaprestamo;         
            end if ;

/*
          if nombretabla = 'PRESTAMOCUOTASFECHA' then
                    Open P_CURSOR For  
                                SELECT PC.FECHA-1,P.PERIODOSOLICITUD ,P.NUMEROSOLICITUD,
                                PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(PC.PERIODOSOLICITUD ,  PC.NUMEROSOLICITUD) AS TOTALCUOTAS,
                                (SELECT COUNT(PC.ESTADO)
                                 FROM PRESTAMOCUOTASFECHA PC
                                 WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=1 AND PC.FECHA=ADD_MONTHS(LAST_DAY(HOY),-1) GROUP BY P.NUMEROSOLICITUD,P.PERIODOSOLICITUD)  AS NROCUOTASPAGADAS  ,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTASFECHA PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND PC.FECHA=ADD_MONTHS(LAST_DAY(HOY),-1) GROUP BY P.NUMEROSOLICITUD,P.PERIODOSOLICITUD) AS NROCUOTASVIGENTES ,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTASFECHA PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND PC.FECHAVENCIMIENTO < (ADD_MONTHS(LAST_DAY(HOY),-1)) AND PC.FECHA=ADD_MONTHS(LAST_DAY(HOY),-1) GROUP BY P.NUMEROSOLICITUD,P.PERIODOSOLICITUD) AS NROCUOTASATRASADAS,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTASFECHA PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=4 AND PC.FECHA=ADD_MONTHS(LAST_DAY(HOY),-1) GROUP BY P.NUMEROSOLICITUD,P.PERIODOSOLICITUD) AS NROCUOTASREPROG,
                                (SELECT MIN(PC.FECHAVENCIMIENTO) 
                                FROM PRESTAMOCUOTASFECHA PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2  AND PC.FECHA = ADD_MONTHS(LAST_DAY(HOY),-1) AND FECHAVENCIMIENTO < ADD_MONTHS(LAST_DAY(HOY),-1) )  AS FECHAMINCUOTAVENCIDA,
                                PKG_CARTERA.F_OBT_DIASATRASO (ADD_MONTHS(LAST_DAY(HOY),-1),PC.PERIODOSOLICITUD,PC.NUMEROSOLICITUD) AS DIASATRASO
                                FROM PRESTAMO P 
                                INNER JOIN PRESTAMOCUOTASFECHA PC ON PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD
                                WHERE P.PERIODOSOLICITUD NOT IN (1)  AND P.PERIODOSOLICITUDCONCESIONAL IS NULL AND P.NUMEROSOLICITUDCONCESIONAL  IS NULL
                                AND PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) > 0 AND PC.FECHA=ADD_MONTHS(LAST_DAY(HOY),-1) AND P.ESTADO=2  
                                GROUP BY PC.FECHA,P.PERIODOSOLICITUD ,P.NUMEROSOLICITUD,PC.PERIODOSOLICITUD,PC.NUMEROSOLICITUD; 
            end if ;
  */          
            
          if nombretabla = 'PRESTAMOCUOTASRESUMEN' then
                    Open P_CURSOR For                                    
                                                        SELECT HOY, HOY-1,P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD,
                                PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) AS TOTALCUOTAS,
                                (SELECT COUNT(PC.ESTADO) FROM PRESTAMOCUOTAS PC WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=1)  AS NROCUOTASPAGADAS  ,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTAS PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 ) AS NROCUOTASVIGENTES ,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTAS PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND PC.FECHAVENCIMIENTO < HOY-1 ) AS NROCUOTASATRASADAS,
                                (SELECT COUNT(PC.ESTADO) 
                                FROM PRESTAMOCUOTAS PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=4 ) AS NROCUOTASREPROG,
                                (SELECT MIN(PC.FECHAVENCIMIENTO) 
                                FROM PRESTAMOCUOTAS PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND FECHAVENCIMIENTO < HOY -1) AS FECHAMINCUOTAVENCIDA,
                                PKG_CARTERA.F_OBT_DIASATRASO (HOY-1,P.PERIODOSOLICITUD,P.NUMEROSOLICITUD) AS DIASATRASO,
                                (SELECT NVL(COUNT(*),0) 
                                FROM PRESTAMOCUOTAS PC
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=1 AND FECHAVENCIMIENTO > HOY -1) AS CUOTASADELANTADAS,
                                (SELECT SUM(PC.AMORTIZACION) 
                                FROM PRESTAMOCUOTAS PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 AND FECHAVENCIMIENTO < HOY -1 ) AS CAPITALVENCIDO,
                                (SELECT MAX(PC.FECHAVENCIMIENTO) 
                                FROM PRESTAMOCUOTAS PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2  ) AS FECHAULTIMACUOTA,
                                (SELECT MAX(PC.AMORTIZACION) 
                                FROM PRESTAMOCUOTAS PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 
                                AND PC.FECHAVENCIMIENTO=PKG_PRESTAMOCUOTAS.F_MAX_FECHAVENCIMIENTOII (PC.NUMEROSOLICITUD,PC.PERIODOSOLICITUD) ) AS CAPITALULTCUOTA,
                                (SELECT MAX(PC.AMORTIZACION) 
                                FROM PRESTAMOCUOTAS PC 
                                WHERE PC.NUMEROSOLICITUD=P.NUMEROSOLICITUD AND PC.PERIODOSOLICITUD=P.PERIODOSOLICITUD AND PC.ESTADO=2 
                                AND EXTRACT(MONTH FROM FECHAVENCIMIENTO)=EXTRACT(MONTH FROM (HOY-1))
                                AND EXTRACT(YEAR FROM FECHAVENCIMIENTO)=EXTRACT(YEAR FROM (HOY-1))  ) AS CUOTAMES --CAPITAL DEL MES
                                FROM PRESTAMO P 
                                WHERE P.PERIODOSOLICITUD NOT IN (1)  AND P.PERIODOSOLICITUDCONCESIONAL IS NULL AND P.NUMEROSOLICITUDCONCESIONAL  IS NULL                              
                                AND PKG_PRESTAMOCUOTAS.F_OBT_CUENTACUOTAS(P.PERIODOSOLICITUD ,  P.NUMEROSOLICITUD) > 0 ;  
                    end if ;
                    
          
           if nombretabla = 'PADRONCONTROL' then
                    Open P_CURSOR For 
                            SELECT HOY, FECHA,ESTADO , FECHAUSUARIO ,CODIGOUSUARIO , FECHACIERRE  ,USUARIOCIERRE ,PRECIERRE  ,FECHAPRECIERRE , USUARIOPRECIERRE 
                            FROM PADRONCONTROL  ;         
           end if ;   
            
            
          if nombretabla = 'SBSANEXO6RESULTADO' then
                    Open P_CURSOR For
                            SELECT S.FECHA ,S.MES ,S.ANIO,S.NRO  ,S.APELLIDOPATERNO ,S.FECHANACIMIENTO ,S.SEXO  ,S.ESTADOCIVIL,S.SIGLAEMPRESA,S.CODIGOSOCIO ,S.PARTREGISTRAL  ,S.TIPODOCIDENTIDAD ,S.DOCIDENTIDAD  ,S.TIPOPERSONA ,S.DOMICILIO ,
                            S.CALIFICACION, S.RELACLABORAL,S.CALIFALINEADA, S.CODIGOAGENCIA ,S.MONEDA,S.PERNROSOLICITUD ,S.TIPCREDITO,S.SUBTIPCREDITO,S.FECDESEMBOLSO,S.MONTODESEMBOLSO,S.TASAINTANUAL,S.SALDO,S.CUENTACONTABLE,
                            S.CAPITALVIGENTE ,S.CAPITALREESTRUCTURADO,S.CAPITALREFINANCIADO,S.CAPITALVENCIDO,S.CAPITALJUDICIAL,S.CAPITALCONTINGENTE,S.CTACONCONTINGENTE,S.DIASATRASO,S.GARANTIAPREF,S.GARAUT ,S.PROVISION,
                            S.PROVCONST , S.SALDOCASTIGADOS,S.CTACONCASTIGADO,S.INTXCOBRAR ,S.INTSUSPENSO ,S.INGRESOSDIFERIDOS ,S.NOMPRODUCTO ,S.NUMCUOTAS,S.NROCUOPAGADAS,S.PERIODICIADAD, S.PERIODOGRACIA,S.FECVENCIMIENTO,
                            S.FECVENCIACTUAL,S.ORIGEN ,S.FECHAPROCESO,S.USUARIOPROCESO ,S.PERIODOSOLICITUD,S.NUMEROSOLICITUD,S.SITUACIONPRESTAMO,S.RECUPERACION ,S.SALDOSUSTITUCIONCONTRAPARTE ,S.SALDOSINCOBERTURA ,S.SALDOCAPREPRO,
                            S.SALDOCOVID19,S.SUBCUENTAORDEN,S.RENDEVCOVID19,S.SALDOGARANTIASUSTITUCIONCONT 
                            FROM SBSANEXO6RESULTADO S INNER JOIN PADRONCONTROL P
                            ON S.FECHA=P.FECHA 
                            WHERE S.FECHA BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND  to_date(nFechafin,'dd/mm/rrrr');   
            end if ;                

          --select CODIGOCREDITO AS TIPOSOLICITUD,CODIGOPRODUCTO AS TBLTIPOPRODUCTO , CODIGOMODALIDAD AS NIVEL4,DESCRIPCIONMODALIDAD  from config_modelo_modalidad  WHERE ESTADO=1 AND CODIGOMODALIDAD=6

          if nombretabla = 'PRESTAMOPAGOSCUOTA' then
                    Open P_CURSOR For 
                            SELECT PERIODOSOLICITUD,NUMEROSOLICITUD ,NUMEROITEM ,NUMEROORDEN,NUMEROCUOTA,FECHAVENCIMIENTO,FECHACANCELACION,AMORTIZACION ,
                            INTERES,INTERESNOCOBRADO,REAJUSTE,INTERESMORATORIO,INTMORANOCOBRADO,PORTES,SEGUROBIEN,TIPOOPERACION,ESTADO,FECHADEPOSITO,
                            NUMINTERES ,NUMMORA,SALDOCUOTA,ORIGEN ,FLAGEXTORNO ,INTERESCONDONADO,ITEMEXTORNADO,MORACONDONADA,MORAPORCOBRAR,NUMEROITEMINTERES,
                            NUMEROITEMMORA,SALDOPRESTAMO,MONTOSERVICIOADICIONAL
                            FROM PRESTAMOPAGOSCUOTA WHERE TRUNC(FECHACANCELACION) BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND  to_date(nFechafin,'dd/mm/rrrr');         
           end if ; 
            
             if nombretabla = 'PRESTAMOCAMBIOSITUACION' then
                Open P_CURSOR For 
                        SELECT HOY, HOY-1,FECHAPROCESO,PERIODOSOLICITUD,NUMEROSOLICITUD,SITUACIONANTERIOR,SITUACIONNUEVA,
                        CAPITAL,INTERESANTERIOR,TIPOSALDO,TIPOPROCESO,TIPOSOLICITUDANTERIOR,TIPOSOLICITUDNUEVA,
                        ESTADO,INTERESCONDONADO,MORACONDONADA,MORAANTERIOR,CODIGOUSUARIO,FECHAREGISTRO
                        FROM PRESTAMOCAMBIOSITUACION ;
                end if ; 



if nombretabla = 'REPOTIFINANZASPASIVAS' then
    Open P_CURSOR For  
        SELECT 
        HOY, FECHA_SALDO,FECHAAPERTURA,SALD_DISP
       ,SALD_CONTAB,MONEDA,NUMEROCUENTA,PRODUCTO,NOMB_PRODUCTO,NOMBRECOMPLETO,CODIGOPERSONA,CODIGO_SIP,AGEN_INSCR_SOCIO,FEC_INSCR_SOCIO,
        AGEN_GEST_APCTA,PERSONERIA,GENERO,FECHA_NACIM,ESTADO_CIVIL,TIP_DOC,NRODOC,TASAINTMENAPERT,TASAINTANUALAPERT,TASAINTMENACTUAL,TASAINTANUALACTUAL,TASAINTERESMENS_PERIODO,
        TASAINTERESANUAL_PERIODO,FINICIO_ULTIM,FVENC_ULTIM,PLAZO,DISTRITO,DEPARTAMENTO,PAIS,SECTORISTA_SOCIO,PERS_CREA_CUENTA,PROFESION,OCUPACION,ESTADO_SOCIO,TIPOSOCIEDAD,
        COMPRA,VENTA,PROMEDIO,ESTADO_CONTABLE,GARANT_CIERRE_MES,GARANT_HOY
        FROM REPOTIFINANZASPASIVAS WHERE FECHA_SALDO BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');    
end if;




if nombretabla = 'REPOTIFINANZASPADRON' then
    Open P_CURSOR For  
        SELECT 
        HOY, FECHAPADRON,FECHAUSUARIO,AGEN_INSCR_SOCIO,FEC_INSCR_SOCIO,PERIODOSOLICITUD,NUMEROSOLICITUD,TIP_DOC,NRODOCUMENTO,NOMBRECOMPLETO,
        SEXO,FECHA_NACIM,ESTADO_CIVIL,PROFESION,OCUPACION,ESTADO_SOCIO,CODIGOSIP,CODIGOPERSONA,PERSONERIA,PROMOTOR,SECTORISTA_SOCIO,
        PRODUCTO,MONTOPRESTAMO,F_DESEMBOLSO,NUMEROCUOTAS,PERIODICIDAD,SALDOPRESTAMO,MONEDA,CALIFICACION,DISTRITO,DEPARTAMENTO,PAIS,
        DESSBS,TASAINTERES,TASAANUAL,CUOTASVENCIDAS,DIASATRASO,GAR_DEPOSITO,GAR_HIP_PREND,PROVISION_TOTAL,SITPREST,COMPRA,VENTA,
        PROMEDIO,AHP_AHV,APO,CDA_CDB_CDE_CDG_CDJ_CDM_CDP,AMV_ATS_CPI_CPR_TAN_501_502 ,FEC_VCTO_CRED,DESCRIPCIONDETALLECIIU,AGENCIA_DESEMB,
        GRUPOPRESTAMO,PDP,NUMEROCONVENIO,NOMBRECONVENIO,FECHA_INICIO,PROVINCIA,DEPARTAMENTO2,INMOBILIARIA,NOMPROYECTO,ETAPA,REQUERIDO, 
        PROVCONSTITUIDO       
        FROM REPOTIFINANZASPADRON WHERE FECHAPADRON BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');    
end if;





        if nombretabla = 'PRESTAMOANEXO' then
            Open P_CURSOR For  
                SELECT 
                  HOY, PERIODOSOLICITUD,NUMEROSOLICITUD,FECHA-1,CODIGOPERSONA,SALDOPRESTAMO,INTERES,MORA,TOTALGASTO,MONTOPRESTAMO,SALDOCAPITAL,MONTOATRASO,MONEDA,TIPOSOLICITUD,
                  TIPOPRESTAMO,CODIGOPERSONAANALISTA,TASAINTERES,TASAADICIONAL,FECHAPRESTAMO,ESTADO,SITUACIONPRESTAMO,CODIGOUSUARIO,CODIGOSOCIO,ULTIMOINTERES,ORIGENPRESTAMO,
                  CUOTAS,DIASATRASO,NUMERODOCUMENTOID,FECHACANCELACION,SALDOAPORTE,DIRECCION,ZONA,DESCRIPCIONZONA,ZONAPOSTAL,DESCRIPCIONTIPOPRESTAMO,DESCRIPCIONTIPOSOLICITUD,
                  DESCRIPCIONSITUACIONPRESTAMO,DESCRIPCIONORIGENPRESTAMO,NOMBREANALISTA,NUMEROTELEFONO,NOMBREPERSONA,SIGLASDEPENDENCIA,CALIFICACION,CODIGOAGENCIA,NUMEROPAGARE,
                  DEPENDENCIA,FINALIDADPRESTAMO,CODIGOPROMOTOR,CODIGOZONAPROMOTOR,CODIGOABOGADO,CODIGOREGION,NOMBREREGION,CODIGODEPARTAMENTO,NOMBREDEPARTAMENTO,CODIGOPROVINCIA,
                  NOMBREPROVINCIA,CODIGODISTRITO,NOMBREDISTRITO,LOTE,NUMEROEXPEDIENTE,ISALBIN,MONTOGPAL,MONTOGPRR,MONTOGP,MONTONOCUBIERTO,FECHACARTA,MODALIDADCREDITO
                FROM PRESTAMOANEXO 
                where (trunc(fecha)-1)>= to_date(nFechaini,'dd/mm/rrrr') and (trunc(fecha)-1)<= to_date(nFechafin,'dd/mm/rrrr') ;
        end if;

       if nombretabla = 'CONVENIOS' then
                    Open P_CURSOR For  
                        SELECT NUMEROCONVENIO, TIPOCONVENIO, PERSONACONTACTO, NOMBRECONVENIO, FECHACONVENIO, FECHAINICIO, ESTADO 
                        FROM CONVENIOS;   
        end if;

        if nombretabla = 'XTIPOCAMBIO' then -- luigi was here
                Open P_CURSOR For 
                     select CODIGOTIPOCAMBIO,FECHA,COMPRA,VENTA,PROMEDIO, 'SISGO' AS USUARIO from xtipocambio;
                        
        end if ;


     
        if nombretabla = 'PADRONFECHA' then
            Open P_CURSOR For  
                SELECT 
                FECHA,PERIODOSOLICITUD,NUMEROSOLICITUD,TIPOSOLICITUD,TIPOPRESTAMO,MESATRASO,DIASATRASO,CUOTASVENCIDAS,CODIGOPERSONA,SALDOPRESTAMO,NORMAL,CPP,DEFICIENTE,DUDOSO,
                PERDIDA,REQUERIDO,PROVCONSTITUIDO,PROVXCONSTITUIR,RECUPERACION,INTXCOBRAR,INTSUSPENSO,SITUACIONPRESTAMO,NROCALIFICACION,NROCALIFICACIONALINEADA,PROVPROCICLICAREQUERIDA,
                PROVPROCICLICACONSTITUIDA,CODIGOUSUARIO,FECHAUSUARIO,NROCALIFICACIONALINEADAEXTERNA,EXPUESTORIESGOCAMBIARIO,PROVFOGAPIREQUERIDA,PROVFOGAPICONSTITUIDA,PROVRCCREQUERIDA,
                PROVRCCCONSTITUIDA,PROVISIONSINGARANTIA,PROVISIONGARANTIAPREFERIDA,PROVISIONGARANTIAPREFERIDAAUTO,RIESGOSOBREENDEUDAMIENTO,PROVRSEREQUERIDA,PROVRSECONSTITUIDA,
                CODIGOPROVEEDORFONDOS,INTERESANTERIOR,CODIGOASEGURADOR,SALDOPRESTAMOTOTAL,DIASATRASOREF,INDICADORATRASO,CLASIFICACIONINTERNA,PROVPROCICLICAASEGCONSTITUIDA,
                PROVPROCICLICAASEGREQUERIDA,MAXDIASATRASOGENERAL,SITUACIONPAGARE,FECHACARTA,CIP,NOMBRESOCIO,MONEDA,MONTOGPAL,MONTOGPRR,MONTOGP,MONTONOCUBIERTO,LOTE,NUMEROEXPEDIENTE,MONTOGPALFINAL,
                MONTOGPRRFINAL,MONTOGPFINAL,MONTOGPALEXCLUIDO,MONTOGPEXCLUIDO,MONTONOCUBIERTOFINAL,PROVISIONGARANTIAPREFERIDARR,INDICADORMODIFICACION,FECHAMODIFICACION,USUARIOMODIFICADOR,
                NIVEL5,NUMEROCUENTA,TASAADICIONAL,TASAINTERES,NIVEL4,MODALIDADCREDITO,NROCALIFALINEADAORIG
                FROM PADRONFECHA WHERE FECHA BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');   
        end if;    


        if nombretabla = 'SBSBD01' then
            Open P_CURSOR For  
                SELECT 
                FECHA,MES,ANIO,NRO,PERIODOSOLICITUD,NUMEROSOLICITUD,CODIGOCIPDEUDOR,TIPODOCUMENTO,NRODOCUMENTO,NOMBREDEUDOR,PERNROSOLICITUD,MONEDA,MONEDABD,MONTODESEMBOLSO,SALDOCAPITAL,
                CALIFICACION,CALIFSINALIMSBS,DIASATRASO,DIASATRASOREALES,PROVISIONCONSTITUIDA,SALDOCAPITALVIGENTE,CCSALDOCAPITALVIGENTE,SALDOCAPITALRESTRUCTURADO,CCSALDOCAPITALRESTRUCTURADO,
                SALDOCAPITALREFINANCIADO,CCSALDOCAPITALREFINANCIADO,SALDOCAPITALVENCIDO,CCSALDOCAPITALVENCIDO,SALDOCAPITALCOBRANZA,CCSALDOCAPITALCOBRANZA,SALDOCAPITALCONTINGENTE,CCSALDOCAPITALCONTINGENTE,
                FACTOREQUIVRIESGO,RENDIMIENTOSDEVENGADOS,CCRENDIMIENTOSDEVENGADOS,INGRESOSDIFERIDOS,CCINGRESOSDIFERIDOS,INTERESESSUSPENSO,CCINTERESESSUSPENSO,FECHADESEMBOLSO,ESQUEMAAMORTIZACION,
                NRODIASGRACIA,FECHAPRIMERPAGOCAPICRONO,FECHAVENCIMIENTOGENERAL,FECHAVENCIMIENTOPUNTUAL,PERIOCIDADCUOTAS,NROCUOTASPROGRAMADAS,NROCUOTASPAGADAS,CODIGOCIIU,UBIGEODEUDOR,ACTIVIDADFINANCIAR,
                PRODUCTOCREDITICIO,SUBPRODUCTOCREDITICIO,INDICADORRFA,CODIGOAGENCIA,CODIGOANALISTA,TASAEFECTIVAANUAL,SEGMENTO,REGIMENLABORAL,NRODECRONOGRAMA,HORADESEMBOLSO,CARTERAADQUIRIDA,EMPRESATRANSFERENTECARTERA,
                INDICADORCOMPRADEUDA,MONTODEUDACOMPRADA,MODALIDADESPECIFICACREDITO,LINEAFINANCIAMIENTOCARTERA,DIRECCIONDEUDOR,DIRECCIONEMPRESADEUDOR,UBIGEOEMPRESADEUDOR,FECHAULTIPAGOCAPITAL,MONTOCAPITALULTICUOTA,
                FECHAULTIPAGOINTERES,MONTOINTERESULTICUOTA,TOTALPAGOINTERES,ESTADOCIVILDEUDOR,NROCAMBIOSCONTRACCRONO,NIVELAPROBACIONCREDITO,TIPOGARANTIA,MODALIDADREFINANCIACION,OPINIONRIESGO,
                CALIFICACIONSBS,RECUPERACION,SITUACIONPRESTAMO,ORIGEN,CODIGOPRESTAMO,CODIGOUSUARIO,FECHAUSUARIO,TMP_SALDOCAPITALCASTIGADO,TMP_CCSALDOCAPITALCASTIGADO,TIPOCREDITO,CODIGOCARTAFIANZA,
                TIPOCREDSBS,UBIGEOAGENCIA,USUARIODESEMBOLSO,OCUPACIONCIS,SECTORECONOM
                FROM SBSBD01 WHERE FECHA BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');   
        end if;    

        if nombretabla = 'SBSBD02A' then
            Open P_CURSOR For  
                SELECT 
				PERIODO,MES,CODIGOSOCIO,PERIODOSOLICITUD,NUMEROSOLICITUD,NROCUOTA,MONEDA,MTOCAPCUOTA,MTOINTCUOTA,
				OTROCOBCUOTA,MTOINTMORA,MTODESGRAVAMEN,	MTOTOTALCUOTA,FECVENCUOTA,FECCANCUOTA,DIASATRASO,FORMACANCUOTA,
				CAPITALCONDONADO,SALDOCONDONADO,TIPOPRESTAMO,USUCREA,FECCREA,USUMODI,FECMODI,MTOCAPAMORT,NROCUOTAREAL
                FROM SBSBD02A WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND PERIODO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') );   
                
        end if;   

        if nombretabla = 'SBSBD04' then
            Open P_CURSOR For  
                SELECT
                FECHA,MES,ANIO,NRO,PERIODOSOLICITUD,NUMEROSOLICITUD,CODIGOCIPDEUDOR,NOMBREDEUDOR,TIPODOCUMENTO,NRODOCUMENTO,PERNROSOLICITUD,MONEDA,MONEDABD,MONTOORIGINAL,NROORIGINALCUOTAS,
                FECHADESEMBOLSO,FECHACANCELACION,NROCUOTASPAGADAS,SALDOCAPITALPAGADO,SALDOINTCOMPCANC,MONTOINTMORATORIO,SALDOINTCOMPNUECRED,SALDOINTCOMPENDEUDOR,MONTOPAGADO,CALIFICACIONDEUDOR,
                DIASATRASO,NROCUOTASADELANTADAS,PRODUCTOCREDITICIO,ESQUEMAAMORTIZACION,FORMACANCELACIONCRED,COMISION,SEGMENTACIONDEUDOR,SECTORIZACIONDEUDOR,PRODUCTOCREDITICIOCOOPAC,INDICADOROFICIO2010,
                INDICADOROFICIO2017,MONTOINTPAGADOSDIF,MONTOINTPAGADOSDEV,MONTOINTMORPAGADOSDIF,MONTOINTMORPAGADOSDEV,COMISIONDIFERIDOS,COMOSIONDEVENGADOS,MODALIDADCREDITO,HORADESEMBOLSO,
                HORACANCELACION,TIPOCREDITO,CODIGOPRESTAMO,CODIGOCARTAFIANZA,FECHAUSUARIO,CODIGOUSUARIO,TIPOCREDITOSBS,USRDESEMBOLSOCREDITO,USRCANCELACIONCREDITO       
                FROM SBSBD04 WHERE FECHA BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');   
        end if;    
        
        
        if nombretabla = 'SBSBD02B' then
            Open P_CURSOR For  
                SELECT
                PERIODO,MES,CODIGOSOCIO,PERIODOSOLICITUD,NUMEROSOLICITUD,NROCUOTA,MONEDA,MTOCAPCUOTA,MTOINTCUOTA,OTROCOBCUOTA,MTOINTMORA,MTODESGRAVAMEN,MTOTOTALCUOTA,
                FECVENCUOTA,FECCANCUOTA,DIASATRASO,FORMACANCUOTA,HORACANCUOTA,INDPAGOPARCIAL,TIPOPRESTAMO,USUCREA,FECCREA,USUMODI,FECMODI,MTOSEGURO,SDOCAPAMORTCUOTA,
                SDOCAPCONDCUOTA,SDOINTCOND,NROCUOTAREAL       
                FROM SBSBD02B WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND PERIODO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') );   
               
        end if;          
        
        
        if nombretabla = 'SBSBD03A' then
            Open P_CURSOR For  
                SELECT
                MES,ANIO,CODIGOSOCIODEUDOR,PERIODOSOLICITUD,NUMEROSOLICITUD,CODIGOSOCIOGARANTE,CODVARGARANTIA,CODIGOPERSONA,ITEM,CODIGOGARANTIA,TIPOGARANTIA,CLASEGARANTIA,COBERTURA,
                NROCREDITOS,CODIGODEUDOR,NOMBREDEUDOR,NRODEUDORES,SALDODEUDA,MONEDACREDITO,BLOQUEOREGISTRAL,FECHABLOQUEO,FECHACONSITUTION,NUMEROPOLIZA,FECHAVENPOLIZA,MONEDAGARANTIA,
                VALORCONSTITUCION,FECHAVALIDAGARANTIA,NOMBREPERITO,VALORCOMERCIAL,VALORREALIZACION,CUENTACONTABLE,VALORGARBALCOM,VALORGARANEXO5,GARANTIACOMPARTIDA,RANGOGARANTIA,
                PARTIDAREGISTRAL,CODIGOUSUARIO,FECHAUSUARIO    
                FROM SBSBD03A WHERE MES = EXTRACT(month from to_date(nFechaini,'dd/mm/rrrr') )  AND ANIO = EXTRACT( YEAR FROM to_date(nFechaini,'dd/mm/rrrr') );  
               
        end if;    

        if nombretabla = 'XLIBRODIARIO' then
            Open P_CURSOR For  
                SELECT
        	    HOY,PERIODOLIBRO, CODIGOLIBRO, FECHAASIENTO, TIPOASIENTO, GLOSA, FECHADOCUMENTO, TIPODOCUMENTO, SERIE, DOCUMENTO, CODIGOUSUARIO, FECHAUSUARIO, CODIGOEJERCICIO
                FROM XLIBRODIARIO WHERE FECHAASIENTO BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');
        end if;       
               
        if nombretabla = 'XLIBRODIARIODETALLE' then
            Open P_CURSOR For  
                SELECT
		HOY,hoy-1,PERIODOLIBRO,CODIGOLIBRO,ITEMLIBRO,PERIODOCUENTA,NUMEROCUENTA,CODIGOCENTROCOSTO,CODIGOPERSONA,TIPODOCUMENTO,SERIEDOCUMENTO,
		NUMERODOCUMENTO,MESFECHAASIENTO,TIPOCAMBIO,DEBEDOLARES,HABERDOLARES,DEBESOLES,HABERSOLES,CODIGOAGENCIA,GLOSADETALLE
                FROM XLIBRODIARIODETALLE WHERE PERIODOLIBRO = to_char(nFechaini, 'YYYY')||to_char(nFechaini, 'mm');
       	end if;       

        if nombretabla = 'PRESTAMOCUOTAS' then
            Open P_CURSOR For  
            SELECT periodosolicitud, numerosolicitud, fechavencimiento, amortizacion, interes, portes, segurointeres ,estado, saldoprestamo, montoservicioadicional 
            FROM prestamocuotas 
            WHERE numerosolicitud in (
			SELECT numerosolicitud FROM prestamo WHERE
			periodosolicitud <>1 and
			get_tipoprestamo(periodosolicitud,numerosolicitud) 
 			not in ('PFI','PCC','PCM','PCH','PCY')) AND ESTADO <> 4;
       	end if;  


        if nombretabla = 'PAGOSRECONOCIMIENTO' then
            Open P_CURSOR For  
         select 
              (p.fecha-1) as fechaPrestamoAnexo
            , p.SALDOPRESTAMO
            , p.INTERES
            , p.MORA
            , p.SALDOCAPITAL
            , p.MONTOATRASO
            , p.ISALBIN
            , p.ULTIMOINTERES
            , p.DIASATRASO
            , p.FECHACANCELACION
            , pp.fechausuario
            , p.periodosolicitud
            , p.numerosolicitud
            , pp.fechacancelacion as fechaProceso
            , pp.fechadeposito as fechaReconocimiento
            , pp.obs
            from prestamoanexo p
           inner join (
                SELECT fechausuario
                    , periodoSolicitud
                    , numeroSolicitud
                    , fechaCancelacion 
                    , fechaDeposito
                    , case 
                        when to_date(fechausuario,'dd/mm/rrrr') != to_date(fechaCancelacion,'dd/mm/rrrr') then 'RC' 
                        when to_date(fechaDeposito,'dd/mm/rrrr') < to_date(fechaCancelacion,'dd/mm/rrrr') then 'RF' 
                        else '-' 
                      end as obs
                FROM PRESTAMOPAGOS where estado = 1 
                and fechaDeposito < fechaCancelacion
                and trunc(fechaUsuario) >=to_date('01/12/2022','dd/mm/rrrr') --> debe ir la variable fecha inicio
            ) pp -- prestamo pp
            ON p.periodoSolicitud = pp.periodoSolicitud 
            and p.numerosolicitud = pp.numerosolicitud
            and to_date((p.fecha-1),'dd/mm/rrrr') between to_date(pp.fechaDeposito,'dd/mm/rrrr') and to_date(Sysdate,'dd/mm/rrrr');
          
       	end if; 

        if nombretabla = 'PERSONANUMEROTELEFONO' then
            Open P_CURSOR For  
		SELECT hoy,hoy-1,codigopersona,numerotelefono,tipotelefono,numerolocalidad,numeroanexo,codigousuario,fechausuario,estado FROM PERSONANUMEROTELEFONO;
       	end if; 

                


        if nombretabla = 'INFORMACIONFINANCIERACLIENTE' then
            Open P_CURSOR For  
		select  
    HOY,
    HOY-1,
    CODIGOPERSONA,
    NUMEROITEM,
    PERIODO,
    FECHAINFORMACION,
    MARGENCONTRIBUCIONPROMEDIO,
    CODIGOUSUARIO,
    FECHAUSUARIO,
    PERIODOSOLICITUD,
    NUMEROSOLICITUD,
    		   INDICADORENDEUDAMIENTO,
    		   INDICADORSOBREENDEUDAMIENTO,
		   TIPOCAMBIORIESGO,
 		   INVENTARIOMERCADERIATERMINADO,
		   PORCENTAJEVENTADOLAR,
 		   PORCENTAJECOMPRADOLAR,
 		   PORCENTAJEVENTASOLES,
   		 PORCENTAJECOMPRASOLES
		from InformacionFinancieraCliente;
       	end if; 


        if nombretabla = 'VENTASCLIENTES' then
            Open P_CURSOR For  
select                   
    HOY,
    HOY-1,
    CODIGOPERSONA,
    NUMEROITEM,
    FRECUENCIAVENTA,
    VENTAPROMEDIO,
    OTROSINGRESOS,
    TOTALINGRESOMENSUAL,
    CODIGOUSUARIO,
    FECHAUSUARIO,
    MONEDA
from ventasclientes;
       	end if; 

        if nombretabla = 'VENTASCLIENTESDETALLE' then
            Open P_CURSOR For  
select  
    HOY,
    HOY-1,
    CODIGOPERSONA,
    NUMEROITEM,
    TIPOVENTA,
    IMPORTESOLES,
    IMPORTEDOLARES 
from ventasclientesdetalle;
       	end if; 



        if nombretabla = 'CUARTAQUINTA' then
            Open P_CURSOR For  
SELECT 
hoy, hoy-1,
pkg_persona.f_obt_cip(p.codigopersona)cod_socio,
p.periodosolicitud,
p.numerosolicitud,
P.FECHAPRESTAMO, P.FECHAUSUARIO,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,1,91) IngresoRenta4taSol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,2,91) IngresoRenta4taDol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,1,92) IngresoRenta5taSol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,2,92) IngresoRenta5taDol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,1,93) OtrosIngresosSol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,2,93) OtrosIngresosDol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,1,96) IngIndeInformalSol,
pkg_datosevaluacion.f_obt_datosventa(p.codigopersona,p.periodosolicitud,p.numerosolicitud,2,96) IngIndeInformalDol
FROM prestamo p 
JOIN solicitudprestamo sp ON sp.periodosolicitud=p.periodosolicitud AND sp.numerosolicitud=p.numerosolicitud
LEFT JOIN creditosotrasinstituciones c ON c.codigopersona=p.codigopersona
WHERE sp.estado=4
AND p.saldoprestamo>0
AND p.periodosolicitud!=1;

       	end if; 



        if nombretabla = 'MODALIDADPRESTAMO' then
            Open P_CURSOR For  
select HOY, FECHAUSUARIO,
CODIGOMODALIDADPRESTAMO,  PERIODOSOLICITUD,  NUMEROSOLICITUD,  FECHACAMBIO,  MODALIDADANTIGUA,  MODALIDADNUEVA,  CODIGOUSUARIO,  FECHAUSUARIO,  INSTANCIAAPROBACION,  FECHAAPROBACION,  FECHAPROXIMACUOTA,  MONTOPROXIMACUOTA,
PKG_MODALIDADCREDITO.F_OBT_INDREVERSION(periodosolicitud,numerosolicitud,modalidadnueva,fechacambio,to_date(nFechafin,'dd/mm/rrrr'))
from MODALIDADPRESTAMO WHERE to_date(FECHAUSUARIO ,'dd/mm/rrrr') BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr'); 

       	end if; 

        if nombretabla = 'PERSONACORREO' then
            Open P_CURSOR For  
select
  hoy,
  hoy-1,
  codigoPersona ,
  item,
  tipoCorreo,
  descripcionCorreo,
  estado,
  fechaUsuario,
  codigoUsuario,
  esPrincipal
from PERSONACORREO;
       	end if; 





        if nombretabla = 'PRESTAMOREPROGRAMADO' then
            Open P_CURSOR For  
select 
  HOY	
, fechausuario
, periodosolicitud
, numerosolicitud
, fechareprogramacion
, indreversion
, estado
, observacion
, codigousuario
, fechausuario
, origen
, plazo
, flageliminacion
from prestamoreprogramado;
       	end if; 


if nombretabla = 'XCENTROCOSTORUBRO' then
    Open P_CURSOR For
    select 
      hoy,hoy-1,codigoCenCosRubro,descripcionCenCosRubro,estado,usuarioCreaRegistro,fechaCreaRegistro,usuarioModiRegistro,fechaModiRegistro
    from XCENTROCOSTORUBRO;
end if; 

if nombretabla = 'GRUPOOPERACIONES' then
    Open P_CURSOR For
    select 
      hoy,  hoy-1,  nivelMovimiento,  grupoMovimiento,  conceptoGrupoMovimiento,  tipoMovimientoCaja,  estado,  codigoTarifa,  codigoUsuario,  fechaUsuario,  codigoProductoSunat
    from GRUPOOPERACIONES;
end if; 

if nombretabla = 'XPLANCUENTA' then
    Open P_CURSOR For
    select
      hoy,  hoy-1,  periodoCuenta,  numeroCuenta,  nombreCuenta,  periodoDestino,  numeroDestino,  periodoPuente,  numeroPuente,  observacion,  movimiento,  ajuste_TipoCambio,  estado,  codigoUsuario,  fechaUsuario,  cuentaSoloSoles,  tipoCambioMovimientos,  grabarPersona,  indicadorRCD,  indicadorSBS
    from XPLANCUENTA;
end if; 

if nombretabla = 'XLIBRODIARIODETALLEANEXO' then
    Open P_CURSOR For  
    select
      hoy,  hoy-1,  periodoLibro,  codigoLibro,  itemLibro,  codigoCenCosRubro,  codigoProducto
    from XLIBRODIARIODETALLEANEXO;
end if; 

if nombretabla = 'XREGISTROCOMPRAS' then
    Open P_CURSOR For  
    select
      hoy,  hoy-1,  TIPOREGISTRO,  PERIODOREGISTRO,  NUMEROREGISTRO,  CODIGOPERSONA,  TIPODOCUMENTO,  SERIEDOCUMENTO,  NUMERODOCUMENTO,  FECHAREGISTRO,  FECHADOCUMENTO,  MONEDA,  TIPOCAMBIO,  GLOSA,
      FORMAPAGO,  MONTOBASE,  MONTOINAFECTO,  MONTOIGV,  MONTOREDONDEO,  MONTODESCUENTO,  MONTOPAGAR,  MONTORETENCION,  CODIGOTARIFA,  CODIGOAREA,  GRUPOMOVIMIENTO,  NUMEROREFERENCIA,  FECHAREFERENCIA,  ESTADODOCUMENTO,
      FECHACANCELACION,  OBSERVACION,  PERIODOLIBRO,  CODIGOLIBRO,  CODIGOUSUARIO,  FECHAUSUARIO,  CODIGOAGENCIA,  BASEINAFECTA,  BASEDESTOPERNOGRAVADAS,  IGVDESTOPERNOGRAVADAS,  BASEDESTOPERGRAVADASNOGRAVADAS,
      IGVDESTOPERGRAVADASNOGRAVADAS,  MONTOPERCEPCION,  DOCUMENTOPERCEPCION,  FECHAPERCEPCION,  ARENDIR,  PERSONA,  APROVEEDOR,  FECHAPROGRAMACION,  FECHAVENCIMIENTO,  OPCION,  FLAGCLASIFICACION,  CODIGOCENCOSRUBRO
    from XREGISTROCOMPRAS;
end if; 

if nombretabla = 'APORTEMAXHISTORICO' then
    Open P_CURSOR For
        select HOY, ap.fechausuario, ap.NUMEROCUENTA, ap.NUMERODOCUMENTO, ap.CODIGOAGENCIA, ap.FECHAMOVIMIENTO, ap.FECHADISPONIBLE, ap.CONDICION, ap.TIPOMOVIMIENTO,
        ap.FORMAPAGO, 
        ap.IMPORTE1 as IMPORTE1, 
        ap.SALDOIMPORTE1 as SALDOIMPORTE1, 
        ap.IMPORTE2 as IMPORTE2, 
        ap.SALDOIMPORTE2 as SALDOIMPORTE2, 
        ap.OBSERVACION, ap.ESTADO, ap.CODIGOUSUARIO, ap.FECHAUSUARIO, 
        ap.APORTEEXTRAORDINARIO 
        from aportes ap
        where ap.numerodocumento= pkg_aportes.F_MAX_NUMERODOCUMENTO(ap.numerocuenta)
        and ap.numerocuenta in (select numerocuenta from cuentacorriente where estado=3 and tipotransaccion=3)  -- tablaservicio = 102
        and ap.estado=1;
end if;

if nombretabla = 'CAJA' then
    Open P_CURSOR For
    SELECT
        HOY --DW_FECHAPROCESO
      , FECHAUSUARIO--DW_FECHACARGA
      , CODIGOAGENCIACAJA
      , PERIODOCAJA
      , NUMEROCAJA      
      , CUENTABANCO
      , TIPOMOVIMIENTO
      , TIPOCAJA
      , FORMAPAGO
      , TIPOCAMBIO
      , GLOSA
      , NIVELMOVIMIENTO
      , CODIGOPERSONA
      , NUMEROCHEQUE
      , ESTADOCONCILIACION
      , FECHAOPERACIONBANCO
      , FECHACONCILIACION
      , NUMEROREPOSICION
      , NEGOCIABLE
      , CONTROL
      , ESTADO
      , PERIODOLIBRO
      , CODIGOLIBRO
      , CODIGOUSUARIO
      , FECHAUSUARIO
      , FECHAMOVIMIENTO
      , IMPORTE
      , BANCOORIGEN
      , TURNO
      , NUMEROCHEQUERA
      , NOMBRECHEQUE
      , TIPOREPROGRAMACION
      ,PKG_CAJADETALLE.F_OBT_MONEDA(CODIGOAGENCIACAJA,PERIODOCAJA,NUMEROCAJA,1) AS MONEDA
    FROM CAJA
    WHERE to_date(FECHAUSUARIO ,'dd/mm/rrrr') BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr'); 
end if;


if nombretabla = 'CAJACOMPRAVENTA' then
    Open P_CURSOR For
    SELECT
        HOY -- DW_FECHAPROCESO
      , FECHAUSUARIO -- DW_FECHACARGA
      , CODIGOAGENCIACAJA
      , PERIODOCAJA
      , NUMEROCAJA
      , TIPOMOVIMIENTO
      , FORMAPAGO
      , MONEDA
      , TIPOCAMBIO
      , TIPOCAMBIOPROMEDIO
      , IMPORTEORIGINAL
      , IMPORTETIPOCAMBIO
      , IMPORTETIPOCAMBIOPROMEDIO
      , IMPORTEUTILIDAD
      , ESTADO
      , FECHAUSUARIO
      , CODIGOUSUARIO
    FROM CAJACOMPRAVENTA
    WHERE to_date(FECHAUSUARIO ,'dd/mm/rrrr') BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr'); 
end if;


if nombretabla = 'SOLICITUDRENUNCIA' then
    Open P_CURSOR For
    SELECT
          CODIGOPERSONA
        , PERIODO
        , NUMEROSOLICITUD
        , FECHARENUNCIA
        , ESTADORENUNCIA
        , MOTIVOANULACION
        , FECHAAPROBACION
        , COMENTARIO
        , CODIGOUSUARIO
        , FECHAUSUARIO
        , MOTIVORENUNCIA
        , CODIGOAGENCIA
        , ULTUSUARIOMODIFICA
        , USUARIOAPROBOSOLICITUD
    FROM SOLICITUDRENUNCIA;
end if;


if nombretabla = 'MAESTROTRANSFERENCIA' then
    Open P_CURSOR For
    SELECT
          hoy
        , hoy-1
		, TIPOOPERACION
        , NUMEROCUENTAORIGEN
        , NUMEROCUENTADESTINO
        , PERIODOSOLICITUD
        , NUMEROSOLICITUD
        , INICIOPROCESO
        , FINPROCESO
        , DIAEJECUCION
        , MONEDA
        , IMPORTE
        , OBSERVACION
        , ULTIMATRANSFERENCIA
        , ESTADO
        , CODIGOUSUARIO
        , FECHAUSUARIO
        , USUARIOMODIFICADOR
        , FECHAMODIFICACION
    FROM MAESTROTRANSFERENCIA;
end if;

if nombretabla = 'SOLICITUDPRESTAMOCUOTASRESUMEN' then
    Open P_CURSOR For
        select 
              HOY
            , HOY-1
            , spc.periodosolicitud
            , spc.numerosolicitud
            , sum(spc.amortizacion) as amortizacion
            , sum(spc.interes) as interes
            , sum(spc.portes) as portes
        from solicitudprestamocuotas spc 
        group by spc.periodosolicitud, spc.numerosolicitud;
end if;

if nombretabla = 'SBSANEXO15A' then
    Open P_CURSOR For
        select 
            hoy
          , FECHAUSUARIO
          , COOPERATIVA
          , DIA
          , MES
          , ANIO
          , NRO
          , DESCRIPCION
          , TOTAL
          , CODIGOUSUARIO
          , FECHAUSUARIO
        from sbs_anexo15a;
end if;

if nombretabla = 'FENACREPXLSCOMSALSBS' then
    Open P_CURSOR For
        SELECT
          HOY
        , HOY-1
        , COOPERATIVA
        , MES
        , PERIODO
        , NUMEROCUENTA
        , NUMEROCUENTASBS
        , AGENCIA
        , DESCRIPCION
        , SADEBE
        , SAHABER
        , DEBITO
        , CREDITO
        , SNDEBE
        , SNHABER
        , CODIGOUSUARIO
        , FECHAUSUARIO
        , ORDEN
        , SALDOINICIAL
        , SALDOACTUAL
        , MONEDA
        FROM FENACREP_XLS_COMSALSBS WHERE PERIODO >= 2022;

end if;

if nombretabla = 'PRESTAMOCUOTASRIESGOS' then
    Open P_CURSOR For  
	SELECT   
          hoy-1
        , PERIODOSOLICITUD
        , NUMEROSOLICITUD
        , NUMEROCUOTA
        , FECHAVENCIMIENTO
        , AMORTIZACION
        , INTERES
        , REAJUSTE
        , SALDOPRESTAMO
        , SALDOCUOTA
        , ESTADO
        , CODIGOUSUARIO
        , FECHAUSUARIO
        , INTERESANTERIOR
        , PORTES
        , SEGUROINTERES
        , INDICADORPAGO
        , ORDENPAGO
        , CODIGOAGENCIACAJA
        , PERIODOCAJA
        , NUMEROCAJA
        , INDRESTRUCTURACION
        , NUMERORESTRUCTURACION
        , MONTOSERVICIOADICIONAL
    FROM prestamocuotas 
    WHERE ESTADO <> 4;
end if;  

if nombretabla = 'OBSERVACION' then
    Open P_CURSOR For  
SELECT
CODIGOPERSONA,
CODIGOOBSERVACION,
TIPOOBSERVACION,
CODIGOUSUARIO,
FECHAHORA,
TEXTORESUMEN,
TEXTOOBSERVACION,
FECHAAVISO,
TIPORESULTADO,
FECHAINICIO
FROM OBSERVACION;
end if;



if nombretabla = 'SBSREPORTESGENERAL' then

    PKG_SBS_REPORTES.P_GEN_REPORTES_CONTABLE(7, null, extract(month FROM to_date(nFechaini,'dd/mm/rrrr')), extract(year FROM to_date(nFechafin,'dd/mm/rrrr')),null, null);
    PKG_SBS_REPORTES.P_GEN_REPORTES_CONTABLE(8, null, extract(month FROM to_date(nFechaini,'dd/mm/rrrr')), extract(year FROM to_date(nFechafin,'dd/mm/rrrr')),null, null);
    Open P_CURSOR For 
        SELECT 
              HOY
            , HOY-1--to_date(nFechaini,'dd/mm/rrrr')
            --, CASE WHEN MES<= 9 THEN ANIO||'-0'||MES ELSE ANIO||'-'||MES END
            , CODREPORTE
            , COOPERATIVA
            , DIA
            , MES
            , ANIO
            , FECHADESDE_I
            , FECHADESDE_F
            , FECHAHASTA_I
            , FECHAHASTA_F
            , CODIGOUSUARIO
            , FECHAUSUARIO
            , ESTADO
            , DESCRIPCION
            , CODFILA
            , CAMPO1,  CAMPO2,  CAMPO3,  CAMPO4,  CAMPO5,  CAMPO6,  CAMPO7,  CAMPO8,  CAMPO9,  CAMPO10
            , CAMPO11, CAMPO12, CAMPO13, CAMPO14, CAMPO15, CAMPO16, CAMPO17, CAMPO18, CAMPO19, CAMPO20
            , CAMPO21, CAMPO22, CAMPO23, CAMPO24, CAMPO25, CAMPO26, CAMPO27, CAMPO28, CAMPO29, CAMPO30
            , CAMPO31, CAMPO32, CAMPO33, CAMPO34, CAMPO35, CAMPO36, CAMPO37, CAMPO38, CAMPO39, CAMPO40
            , CAMPO41, CAMPO42, CAMPO43, CAMPO44, CAMPO45, CAMPO46, CAMPO47, CAMPO48, CAMPO49, CAMPO50
            , CAMPO51, CAMPO52, CAMPO53, CAMPO54, CAMPO55, CAMPO56, CAMPO57, CAMPO58, CAMPO59, CAMPO60
            , CAMPO61, CAMPO62, CAMPO63, CAMPO64, CAMPO65, CAMPO66, CAMPO67, CAMPO68, CAMPO69, CAMPO70
            , CAMPO71, CAMPO72, CAMPO73, CAMPO74, CAMPO75, CAMPO76, CAMPO77, CAMPO78, CAMPO79, CAMPO80
            , CAMPO81, CAMPO82, CAMPO83, CAMPO84, CAMPO85, CAMPO86, CAMPO87, CAMPO88, CAMPO89, CAMPO90
            , CAMPO91, CAMPO92, CAMPO93, CAMPO94, CAMPO95, CAMPO96, CAMPO97, CAMPO98, CAMPO99, CAMPO100
            , ESTADOCIERRE
        FROM sbsreportesgeneral where codreporte IN (7,8);
end if;



if nombretabla = 'DETCOLOCACIONESAMORT' then
    SISGODBA.P_GENERA_DET_COLOCA_AMORTIZA(to_date(nFechaini,'dd/mm/rrrr'),to_date(nFechafin,'dd/mm/rrrr'));
   
    Open P_CURSOR For 
             SELECT
                  HOY
                , FECHACANCELACION
                , FECHACANCELACION
                , FECHADEPOSITO
                , FECHAUSUARIO
                , COD_SOCIO
                , PERIODOSOLICITUD
                , NUMEROSOLICITUD
                , TIPO
                , NOMBRECOMPLETO
                , TIPOSBS
                , MONEDA
                , TIPOCAMBIO
                , NUMEROITEM
                , AMORTIZACION
                , INTERES
                , INTERESMORATORIO
                , INTERESDIFERIDO
                , CODIGOLIBRODIF
                , PERIODOLIBRO
                , CODIGOLIBRO
                , CODIGOAGENCIACAJA
                , PERIODOCAJA
                , NUMEROCAJA
                , CODIGOUSUARIO
                , CONDICION
                , TIPOMOVIMIENTO
                , FINALIDADPRESTAMO
                , MODALIDADSOLICITUD
            FROM DETCOLOCACIONESAMORT;
end if;

if nombretabla = 'CANCELACIONCUENTA' then

    Open P_CURSOR For 
        select
              hoy as DW_FECHAPROCESO
            , FECHAUSUARIO as DW_FECHACARGA
            , NUMEROCUENTA
            , CODIGOSOCIO
            , TIPOTRANSACCION
            , SALDOCANCELACION
            , SALDOCONTABLE
            , SALDODISPONIBLE
            , TIPOMOTIVO
            , DESCRIPCIONMOTIVO
            , ESTADO
            , CODIGOAGENCIACAJA
            , PERIODOCAJA
            , NUMEROCAJA
            , CODIGOUSUARIO
            , FECHAUSUARIO
        from CANCELACIONCUENTA
        WHERE to_date(FECHAUSUARIO ,'dd/mm/rrrr') BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');
end if;

if nombretabla = 'PEP' then

    Open P_CURSOR For 
        select
              HOY
            , HOY-1
            , CODIGOPERSONA
            , NOMBREVINCULADO
            , PARENTESCO
            , OBSERVACION
            , CODIGOPARENTESCO
            , INDSUJETOOBLIGADO
            , DESSUJETOOBLIGADO
            , INDPEP
            , CARGOPEP
            , INDFAC
            , INDONU
            , INDUE
            , INDPACIFICO
            , INDPERFILRIESGO
            , FECHACREAREGISTRO
            , USUARIOCREAREGISTRO
            , FECHAMODIREGISTRO
            , USUARIOMODIREGISTRO
            , REGIMEN
        from PEP;
        --WHERE to_date(FECHAUSUARIO ,'dd/mm/rrrr') BETWEEN to_date(nFechaini,'dd/mm/rrrr') AND to_date(nFechafin,'dd/mm/rrrr');
end if;


if nombretabla = 'BDSOCDATOS' then

    Open P_CURSOR For
        select 
              HOY
            , HOY-1
            , p.CODIGOPERSONA
            , p.CIP
            , case NVL(pkg_detalleaportes.f_obt_montocuotasadeudadas( p.codigopersona ),0)
                    when 0 then 
                      null
                    else
                      'Equivalente a : '
                      ||REPLACE(TO_CHAR(ROUND(NVL(pkg_detalleaportes.f_obt_montocuotasadeudadas( p.codigopersona ),0),2),'999999990.99'),' ','') 
                      ||' Soles o '
                      ||REPLACE(TO_CHAR(ROUND(NVL(pkg_detalleaportes.f_obt_montocuotasadeudadas( p.codigopersona ),0)/pkg_xtipocambio.f_obt_venta(2,adm05040),2),'999999990.99'),' ','') 
                      ||' Dolares' 
                    end monto_aport_deuda
            , pkg_bdsoc.F_OBT_ULT_OP_SOC_FEC ( p.codigopersona) AS ULT_OP_SOC_FEC  
            , pkg_bdsoc.F_OBT_ULT_OP_SOC_TMOV ( p.codigopersona) AS ULT_OP_SOC_TMOV  
            , pkg_bdsoc.F_OBT_ULT_OP_SOC_DESCMOV ( p.codigopersona) AS ULT_OP_SOC_DESCMOV  
            , x.fecha_actualizacion   
            , CASE WHEN NVL(t.qty,0) = 0 THEN 'NO' ELSE 'SI' END AS TARJETA_DEBITO_CP
        from PERSONA p
            left join (
                SELECT AUD.CODIGOPERSONA,TRUNC(AUD.FECHAUSUARIO) as fecha_actualizacion
                FROM auditoriamaestros AUD
                WHERE AUD.tabla='DATOSSOCIO'
                AND TRUNC(AUD.FECHAUSUARIO)= (SELECT TRUNC(MAX(FECHAUSUARIO)) FECHA
                                            FROM auditoriamaestros 
                                            WHERE tabla='DATOSSOCIO' AND CODIGOPERSONA=AUD.CODIGOPERSONA)
                GROUP BY AUD.CODIGOPERSONA,TRUNC(AUD.FECHAUSUARIO)
            ) x
            on p.codigopersona = x.codigopersona
            left join (
                select codigopersona, count(*) as qty 
                from tarjetas 
                where situacionactual = 4
                group by codigopersona
            ) t 
            on t.codigopersona = p.codigopersona;
end if;

if nombretabla = 'CUENTACORRIENTEDEUDA' then

    Open P_CURSOR For
        select 
              hoy
            , hoy-1
            , CODIGOPERSONA
            , NUMEROCUENTASOLES
            , NUMEROCUENTADOLARES
            , DEUDASOLES
            , DEUDADOLARES
            , CUOTASADEUDADASSOLES
            , PERIODODEUDA
            , CODIGOUSUARIO
            , FECHAUSUARIO
            , CUOTASADEUDADASDOLARES
            , CUOTASDEUDATOTAL
            , ESTADOPROCESO
            , FECHAULTIMOAJUSTE
            , PERIODOMAXIMO
        from cuentacorrientedeuda;
end if;

if nombretabla = 'CONSENTIMIENTO' then

    Open P_CURSOR For
        select 
              hoy
            , hoy-1
            , CODIGOPERSONA
            , CODIGOCONSENTIMIENTO
            , ESTADO
            , CODIGOUSUARIO
            , FECHAUSUARIO
            , CODIGOUSUARIOMODIFICA
            , FECHAUSUARIOMODIFICA
        from CONSENTIMIENTO;
end if;


if nombretabla = 'PACINET' then
    Open P_CURSOR For
        SELECT 
          id_cliente as codigopersona
        , cip as codigosocio
        , des_estado as estado
        , des_tipo_persona as tipersona
        , 'ACTUAL' AS OBS
        FROM AGVIRTUAL.PAC_CLIENTE_MAE  --where cip=0150603
        union
        ----socios que tienen pacinet antiguo (SIP)-----
        SELECT  
          id_cliente as codigopersona
        , cip as codigosocio
        , estado as estado
        , tipo_persona as tipersona
        , 'ANTIGUO' AS OBS
        FROM AGVIRTUAL.PAC_CLIENTE_PACINET;---where estado=2
end if;


if nombretabla = 'PRESTAMOREFINANCIADO' then
    Open P_CURSOR For
    SELECT
      HOY,
      HOY-1,
      PERIODOSOLICITUD,
      NUMEROSOLICITUD,
      INDICADOR,
      ITEM,
      PERIODOREFERENCIA,
      NUMEROREFERENCIA,
      TASAINTERESANUAL,
      TASAINTERESMENSUAL,
      CUOTASADEUDADAS,
      FECHASALDO,
      SALDOCAPITAL,
      SALDOINTERES,
      FECHAVENCIMIENTO,
      IMPORTEREFINANCIADO,
      FECHAREFINANCIADO,
      FECHAULTREFINANCIADO,
      FECHACADUCIDADVIGENCIA,
      PAGAREANTERIOR,
      ESTADO
    FROM PRESTAMOREFINANCIADO;
end if;


if nombretabla = 'VALIDADORXLIBRODIARIODETALLE' then
    Open P_CURSOR For
        select periodolibro, sum(debedolares+haberdolares+debesoles+habersoles) as totalizado
        from xlibrodiariodetalle
        where periodolibro>=202212
        group by periodolibro;
end if;

End P_OBT_CURSOR;
    
End PKG_DWH;
/