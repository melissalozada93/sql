USE TemporalesDW
/*SELECT * 
FROM  ST_LISTA_DASHBOARD_PBI*/


----Agregar nuevo reporte
INSERT INTO [dbo].[ST_LISTA_DASHBOARD_PBI]
           ([URL]
           ,[MENSAJE])
     VALUES
           ('https://app.powerbi.com/groups/15bd2eff-a1d7-4a2c-b375-0818764670a2/datasets/4b4a7f17-41c7-4186-b9ba-b7c15bbfade3/details?experience=power-bi', 'RI_Transferencias_Pacinet')



DROP TABLE IF EXISTS ST_DASHBOARD_PBI
SELECT *,1[idestado]
INTO ST_DASHBOARD_PBI
FROM ST_LISTA_DASHBOARD_PBI

select * from ST_DASHBOARD_PBI


update ST_DASHBOARD_PBI set idestado=1


update a
set [URL]='https://app.powerbi.com/groups/15bd2eff-a1d7-4a2c-b375-0818764670a2/datasets/a0bb20b1-abfb-41e4-8821-dfbd471c914d/details?experience=power-bi'
--select*
from [ST_LISTA_DASHBOARD_PBI]a
where ID=23

update a
set MENSAJE='RI_Prov_Alerta_Temprana'
--select*
from [ST_LISTA_DASHBOARD_PBI]a
where ID=23



select*
from [ST_LISTA_DASHBOARD_PBI]