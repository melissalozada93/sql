select 
im$_cippersona(c.codigopersona) as codigosocio, 
c.numerocuenta,
case when c.moneda=1 then 'S' else 'D' end as m,
   a.importe1,
                case when a.tipomovimiento in(1,3,5,7) then 'ENTRADA'  
                                     when a.tipomovimiento in(2,4,6,8) then 'SALIDA'
                            else ' ' end as tip_mov,   
  pkg_syst900.f_obt_tbldescri(15, a.tipomovimiento) as movimiento,
  a.fechamovimiento, 
  a.observacion
from aportes a 
inner join cuentacorriente c on c.numerocuenta = a.numerocuenta
-- where  im$_cippersona(c.codigopersona) = '0010285'
where c.codigopersona = 10286
and trunc(fechamovimiento)>= '26/01/2024' and trunc(fechamovimiento)<= '01/02/2024'
and a.TIPOMOVIMIENTO not in(5) and a.estado=1
order by a.fechamovimiento