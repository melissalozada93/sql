
select distinct codigopersona 

from DW_CUENTACORRIENTE where NUMEROCUENTA in (select distinct nrocuenta from ##temp_basetotal_1 where codigosocio is null)
 
select * from dw_persona where codigopersona = '0000001'
 
 
select distinct nrocuenta from ##temp_basetotal_1 where codigosocio is null