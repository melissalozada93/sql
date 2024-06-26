USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_crear_st_soporte]    Script Date: 10/04/2024 16:58:25 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter procedure [dbo].[usp_cargar_archivos_externos_indicadores_finanzas]

AS

---------Cargar Datos de Riesgo Liquidez------------------------------------------------------------------
DROP TABLE IF EXISTS #TB_Riesgos_Liquidez
    SELECT identity(int,1,1)[ID],*
    INTO #TB_Riesgos_Liquidez
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Tablero Indicadores\Riesgos de Liquidez.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');



TRUNCATE TABLE DWCOOPAC_EXTERNOS.dbo.IND_LIQUIDEZ 
INSERT INTO DWCOOPAC_EXTERNOS.dbo.IND_LIQUIDEZ 
SELECT CONVERT(DATE,FECHA_SALDO),NOMBRE,VALOR from #TB_Riesgos_Liquidez  



---------Cargar Datos de Ratio Capital------------------------------------------------------------------
DROP TABLE IF EXISTS #TB_Ratio_Capital
    SELECT identity(int,1,1)[ID],*
    INTO #TB_Ratio_Capital
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Tablero Indicadores\Ratio Capital.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');




TRUNCATE TABLE DWCOOPAC_EXTERNOS.dbo.IND_RATIO_CAPITAL
INSERT INTO DWCOOPAC_EXTERNOS.dbo.IND_RATIO_CAPITAL
SELECT CONVERT(DATE,FECHA_SALDO),NOMBRE,VALOR from #TB_Ratio_Capital  




---------Cargar Datos de Ratio Capital------------------------------------------------------------------
DROP TABLE IF EXISTS #TB_Base_Repro
    SELECT identity(int,1,1)[ID],*
    INTO #TB_Base_Repro
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Tablero Indicadores\Base_Repro.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');


TRUNCATE TABLE DWCOOPAC_EXTERNOS.dbo.IND_REPRO
INSERT INTO DWCOOPAC_EXTERNOS.dbo.IND_REPRO
SELECT CONVERT(DATE,Fecha),Nombre,Resultado FROM #TB_Base_Repro



SELECT fechaCambio,promedio FROM DW_TIPOCAMBIOAJUSTE WHERE  fechaCambio='2024-02-29'
order by fechacambio desc




select * from  DWCOOPAC_EXTERNOS.dbo.IND_REPRO

