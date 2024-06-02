USE [DWCOOPAC]
GO
---------Cargar Datos de Campañas ------------------------------------------------------------------
DROP TABLE IF EXISTS #TB_Campanas
    SELECT identity(int,1,1)[ID],*
    INTO #TB_Campanas
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Dinero Fresco DPF\Captaciones_Campañas.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Campañas$]');



TRUNCATE TABLE ST_CAMPANAS_DPF
INSERT INTO ST_CAMPANAS_DPF
SELECT * FROM #TB_Campanas




DROP TABLE IF EXISTS #TB_Subproductos
    SELECT identity(int,1,1)[ID],*
    INTO #TB_Subproductos
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Dinero Fresco DPF\Captaciones_Campañas.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Subproductos$]');


TRUNCATE TABLE ST_CAMPANAS_DPF_DETALLE
INSERT INTO ST_CAMPANAS_DPF_DETALLE
SELECT * FROM #TB_Subproductos



