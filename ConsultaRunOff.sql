SELECT 
Gerencia	,Jefatura	,Funcionario	,NombreSocio	,CodigoSolicitud	,Producto ,	CompraCartera
, SUM(Saldo_SBS)Saldo_SBS, SUM(TotalCapitalVencido_SBS)	[Monto Cuotas Atrasadas]

FROM WT_REPORTE_RUNOFF_RESUMIDO
GROUP BY Gerencia	,Jefatura	,Funcionario	,NombreSocio	,CodigoSolicitud	,Producto ,	CompraCartera