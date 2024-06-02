USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dashm_dpfmarketing_stock]    Script Date: 15/02/2024 18:38:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[usp_cargar_lista_negra_transferencias]
as

----Lista Negra socios 
 DROP TABLE IF EXISTS #ListaNegra
    SELECT identity(int,1,1)[ID],*
    INTO #ListaNegra
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Seguridad de la Informacion\ListaNegraSocio.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');


TRUNCATE TABLE ST_SI_LISTA_NEGRA_SOCIOS
INSERT INTO ST_SI_LISTA_NEGRA_SOCIOS
SELECT DNI,NOMBRE,BLACKLIST FROM #ListaNegra



----Lista Blanca dominios 
 DROP TABLE IF EXISTS #ListaBlanca
    SELECT identity(int,1,1)[ID],*
    INTO #ListaBlanca
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\FilesSharePoint\Reportería\Seguridad de la Informacion\ListaBlancaDominios.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');

TRUNCATE TABLE ST_SI_LISTA_BLANCA_DOMINIOS
INSERT INTO  ST_SI_LISTA_BLANCA_DOMINIOS
SELECT DOMINIO FROM #ListaBlanca


