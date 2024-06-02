USE [DWCOOPAC]
GO
---------Cargar Datos de Campañas ------------------------------------------------------------------
DROP TABLE IF EXISTS #TB_Matriz_FlujoCaja
    SELECT *
    INTO #TB_Matriz_FlujoCaja
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Dinero Fresco DPF\matriz_pasiva.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');



TRUNCATE TABLE ST_MATRIZ_FLUJOCAJA
INSERT INTO ST_MATRIZ_FLUJOCAJA
SELECT * 
FROM #TB_Matriz_FlujoCaja
