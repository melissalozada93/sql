USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_updiff_operacionesagenciasc]    Script Date: 29/02/2024 10:44:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[usp_updiff_operacionesagenciasc] 
as  
    set nocount on  
    set xact_abort on  
    begin transaction  
    begin try  


	DECLARE @FECINI DATE
    DECLARE @FECFIN DATE

	SET @FECINI = dateadd(dd,((day(eomonth(cast(getdate()-1 as date),-1))-1))*-1,eomonth(cast(getdate()-1 as date),-1))
	SET @FECFIN = eomonth(cast(getdate()-1 as date),-1) 

	--select @FECINI, @FECFIN

------------------------------
 IF OBJECT_ID('tempdb..#OP_AGENCIAS') IS NOT NULL drop table #OP_AGENCIAS

   
   select *
   into #OP_AGENCIAS
   from   ( select c.periodocaja,c.numerocaja, c.dw_codagenciacajadescri as codigoagencianom,
                per.cip as codigo,
                per.nombrecompleto as nombre, 
                'PASIVAS' as producto,
                case when cc.moneda=1 then 'S' else 'D' end as m,
                case when c.numerocaja=ccv.numerocaja and c.periodocaja=ccv.periodocaja and c.codigoagenciacaja =ccv.codigoagenciacaja then ccv.moneda
                     when a.numerocaja=ccv.numerocaja and a.periodocaja=ccv.periodocaja and a.codigoagenciacaja =ccv.codigoagenciacaja then ccv.moneda
                     when a.numerocaja=c.numerocaja and a.periodocaja=c.periodocaja and a.codigoagenciacaja =c.codigoagenciacaja then c.dw_moneda end as moneda,
               cc.numerocuenta as numerocuenta,
                case when a.tipomovimiento in(1,3,5,7) then 'ENTRADA'  
                                     when a.tipomovimiento in(2,4,6,8) then 'SALIDA'
                            else ' ' end as tip_mov,   
                c.importe as importe,                                                                    
                cast(a.fechausuario as date) as fechausuario,
                c.dw_formapagodescri as formapago, 
                s10.usrnomusu as  usuario ,
                c.dw_control as tipo_operacion,
                c.glosa
                from dw_caja c
                inner join dw_cuentamovimiento  a on c.periodocaja=a.periodocaja and c.numerocaja=a.numerocaja and c.codigoagenciacaja=a.codigoagenciacaja  
                inner join (select numerocuenta,max (dw_fechacarga) as fmax from vw_cuentacorriente group by numerocuenta)ccmax on a.numerocuenta = ccmax.numerocuenta
				inner join (select * from vw_cuentacorriente )cc on ccmax.numerocuenta = cc.numerocuenta and cc.dw_fechacarga=ccmax.fmax
				inner join (select codiopersona,max (dw_fechacarga) as pfmax from vw_wt_persona group by codiopersona)pmax on pmax.codiopersona = cc.codigopersona
				inner join vw_wt_persona per on per.codiopersona=pmax.codiopersona and per.dw_fechaCarga=pmax.pfmax
				inner join isyst010 s10 on s10.usrcodusu=a.codigousuario                 
                left join dw_cajacompraventa ccv on ccv.periodocaja=c.periodocaja and ccv.numerocaja=c.numerocaja and ccv.codigoagenciacaja=c.codigoagenciacaja    
                where a.estado=1 and cast(a.fechausuario as date)>=@FECINI and cast(a.fechausuario as date)<=@FECFIN
				and a.codigousuario not in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='EXCLUIR')
                and a.codigoagenciacaja in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='INCLUIR') 
                and a.numerocaja is not null
                 and cc.codigopersona<> 1 and c.estado=1 and c.control <> 9 and c.importe >0
				union				
					select pp.periodocaja,pp.numerocaja, c.dw_codagenciacajadescri as codigoagencianom,
					per.cip as codigo,
					per.nombrecompleto as nombre,
					'CREDITOS' as producto,
					case when sp.moneda=1 then 'S' else 'D' end as m,     
					c.dw_moneda as moneda ,          
					pp.codigosolicitud as numerocuenta,                
					case when pp.tipomovimiento in(1,3,5,7) then 'ENTRADA'  
										 when pp.tipomovimiento in(2,4,6,8) then 'SALIDA'
								else ' ' end as tip_mov,
					c.importe as importe,
					cast(pp.fechausuario as date) as fechausuario,
					c.dw_formapagodescri as formapago, 
					s10.usrnomusu as  usuario  ,
					c.dw_control as tipo_operacion,
					c.glosa
					from dw_prestamo_pagos pp 
					inner join (select codigosolicitud, max (dw_fechacarga) as spfmax , codigopersona from vw_solicitudprestamo group by codigosolicitud,codigopersona) spmax on pp.codigosolicitud = spmax.codigosolicitud 
					inner join dw_solicitudprestamo sp on  sp.codigosolicitud = spmax.codigosolicitud and sp.dw_fechacarga=spmax.spfmax
					inner join (select codiopersona,max (dw_fechacarga) as pfmax from vw_wt_persona group by codiopersona)pmax on pmax.codiopersona = sp.codigopersona
					inner join vw_wt_persona per on per.codiopersona=pmax.codiopersona and per.dw_fechaCarga=pmax.pfmax
					inner join dw_caja c on c.periodocaja=pp.periodocaja and c.numerocaja=pp.numerocaja and c.codigoagenciacaja=pp.codigoagenciacaja  
					inner join isyst010 s10 on s10.usrcodusu=pp.codigousuario   
					where pp.estado=1 and cast(pp.fechausuario as date)>=@FECINI and cast(pp.fechausuario as date)<=@FECFIN
					and pp.codigousuario not in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='EXCLUIR')
					and pp.codigoagenciacaja in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='INCLUIR')  
					and pp.numerocaja is not null    
					 and pp.fechaextorno is null and pp.itemextornado is null and c.importe > 0
					 union
					 select ccv.periodocaja,ccv.numerocaja, c.dw_codagenciacajadescri as codigoagencianom,
                per.cip as codigo,
                per.nombrecompleto as nombre, 
                '-' as producto,
                case when ccv.moneda=1 then 'S' else 'D' end as m,
                ccv.moneda as moneda,
                '-' as numerocuenta,
                case when ccv.tipomovimiento=1 then 'ENTRADA'  
                                     when ccv.tipomovimiento=2 then 'SALIDA'
                            when ccv.tipomovimiento=3 then 'TRANSFERENCIA ' end as tip_mov,   
                c.importe as importe,                                                                    
                cast(c.fechausuario as date) as fechausuario,
                c.dw_formapagodescri as formapago,
                s10.usrnomusu as  usuario ,
                c.dw_control as tipo_operacion,
                c.glosa
                from dw_caja c  
				inner join (select codiopersona,max (dw_fechacarga) as pfmax from vw_wt_persona group by codiopersona)pmax on pmax.codiopersona = c.codigopersona
				inner join vw_wt_persona per on per.codiopersona=pmax.codiopersona and per.dw_fechaCarga=pmax.pfmax
                inner join dw_cajacompraventa ccv on c.periodocaja=ccv.periodocaja and c.numerocaja=ccv.numerocaja and c.codigoagenciacaja=ccv.codigoagenciacaja
				inner join isyst010 s10 on s10.usrcodusu=c.codigousuario  
                where c.estado=1 and cast(c.fechausuario as date)>=@FECINI and cast(c.fechausuario as date)<=@FECFIN
                and c.codigousuario not in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='EXCLUIR')
                and c.codigoagenciacaja in (SELECT DISTINCT [KEY] FROM ST_TABLA_SOPORTE WHERE Comentario='Op Agencias' AND Descripcion='INCLUIR')  
                and c.numerocaja is not null     
                and c.codigopersona<> 1   and c.importe > 0
				 ) unido order by periodocaja,numerocaja,codigoagencianom



--LOGICA PARA ARMAR CAMPO TIPO OPERACION--

 IF OBJECT_ID('tempdb..#OP_AGENCIAS_TIP_OP') IS NOT NULL drop table #OP_AGENCIAS_TIP_OP

SELECT O.*,
CASE 
    WHEN formapago='Cheque' and tipo_operacion='Ingreso Cuenta/Prestamo' and producto='PASIVAS' then 'Deposito de Cheque' 
    WHEN formapago='Cheque' and tipo_operacion='Egreso Cuenta/Prestamo' and producto='PASIVAS' then 'Retiro de Cheque'
    WHEN formapago in ('Transf. Bancaria','Nota de Abono') and  tipo_operacion='Transferencia caja / bancos' and producto='PASIVAS' then 'Transf. Bancaria'
    WHEN glosa='APORTE INICIAL - Pago Cuota Inscripcion' then 'Pago Cuota De Inscripcion'
    WHEN tipo_operacion='Transferencia Prestamo' then 'Pago de Prestamo'
    WHEN formapago='Efectivo' and producto='CREDITOS' and tipo_operacion='Ingreso Cuenta/Prestamo' then 'Pago de Prestamo'
    WHEN formapago='Efectivo' and tipo_operacion='Compra/Venta' and producto in ('PASIVAS','-') then 'Compra y Venta de Dolares'
    WHEN formapago='Efectivo' and tipo_operacion='Egreso Cuenta/Prestamo' and producto ='PASIVAS' then 'Retiro de Cuenta'
    WHEN formapago='Efectivo' and tipo_operacion='Egreso Cuenta/Prestamo' and producto ='CREDITOS' then 'Retiro de Linea de Credito'
    WHEN formapago='Efectivo' and tipo_operacion='Ingreso Cuenta/Prestamo' and producto ='PASIVAS' then 'Deposito en cuenta'
    WHEN tipo_operacion='Transferencia Cuenta Propia' and producto in ('PASIVAS','-') then 'Transf. Cuenta Propia'
    WHEN tipo_operacion='Transferencia Cuenta Terceros' and producto in ('PASIVAS','-') then 'Transf. Cuenta Terceros'
    WHEN tipo_operacion='Pago De Servicios' and producto ='PASIVAS' then 'Pago De Servicios'
    WHEN formapago='Transf. Interna' and tipo_operacion='Egreso Cuenta/Prestamo' and producto in ('PASIVAS','CREDITOS') then 'Desembolso De Prestamo'
    WHEN glosa='APORTE INICIAL - Pago Cuota Inscripcion' then 'Pago Cuota De Inscripcion'
    ELSE 'Otros'
    end as tipo_operacion_final
	into #OP_AGENCIAS_TIP_OP
FROM #OP_AGENCIAS O			;	


---QUITA DUPLICADOS--
WITH tabla_duplicado AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY periodocaja,numerocaja, codigoagencianom ORDER BY periodocaja,numerocaja,codigoagencianom) AS fila_numero
  FROM #OP_AGENCIAS_TIP_OP
)
DELETE FROM tabla_duplicado
WHERE fila_numero > 1;


 --Tabla final---

 
 IF OBJECT_ID('tempdb..#OP_FINAL') IS NOT NULL drop table #OP_FINAL

 select
PERIODOCAJA
,NUMEROCAJA
,CODIGOAGENCIANOM
,CODIGO
,NOMBRE
,PRODUCTO
,CASE WHEN MONEDA = 1 THEN 'SOLES' ELSE 'DOLARES' END AS moneda
,NUMEROCUENTA
,IMPORTE
,FECHAUSUARIO
,FORMAPAGO
,USUARIO
,GLOSA
, TIPO_OPERACION_FINAL
, llaveOperaciones = case when (ROW_NUMBER() over(partition by periodocaja, numerocaja, CODIGOAGENCIANOM order by periodocaja, numerocaja, CODIGOAGENCIANOM))>1 then 0 else 1 end
, llaveFrecuencia = case when (ROW_NUMBER() over(partition by CODIGO, fechausuario, CODIGOAGENCIANOM order by CODIGO, fechausuario, CODIGOAGENCIANOM))>1 then 0 else 1 end
, llaveVisitasMes = case when (ROW_NUMBER() over(partition by CODIGO, left(fechausuario,7), CODIGOAGENCIANOM order by CODIGO, left(fechausuario,7), CODIGOAGENCIANOM))>1 then 0 else 1 end
, llaveOperacionesDia = case when (ROW_NUMBER() over(partition by periodocaja, numerocaja, CODIGOAGENCIANOM, fechausuario order by periodocaja, numerocaja, CODIGOAGENCIANOM, fechausuario))>1 then 0 else 1 end
into #OP_FINAL
from #OP_AGENCIAS_TIP_OP


----INSERTAR A LA TABLA DEL REPORTE---
INSERT INTO DW_AGENCIAOPERACIONES
SELECT * FROM #OP_FINAL;



        insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'Ejecucion Exitosa del Dashboard AGENCIAOPERACIONES',null, 'OK'
        --select * from DWCOOPACIFICO.dbo.WT_RUNOFF
     
	end try
	begin catch
		rollback transaction

		declare @error_message varchar(4000), @error_severity int, @error_state int
		select @error_message = error_message(), @error_severity = error_severity(), @error_state = error_state()
		insert into DWCOOPAC.dbo.LOG_DASHBOARD (logFecha,logMensaje,logError,logEstado) 
        select getdate(),'ERROR en la ejecucion del Dashboard AGENCIAOPERACIONES', @error_message, 'ERROR'

	end catch 
	if @@trancount > 0
		commit transaction		
return 0