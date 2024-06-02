USE [DWCOOPAC]
GO
/****** Object:  StoredProcedure [dbo].[usp_dash_calendario]    Script Date: 30/01/2024 11:46:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[usp_crear_st_soporte]

AS
DROP TABLE IF EXISTS #ST_TABLA_SOPORTE
    SELECT identity(int,1,1)[ID],*
    INTO #ST_TABLA_SOPORTE
    FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
                    'Excel 12.0; Database=D:\Files\Carga_archivos\ST_TABLA_SOPORTE.xlsx; HDR=YES; IMEX=1',
                    'SELECT * FROM [Hoja1$]');

DROP TABLE  [dbo].[ST_TABLA_SOPORTE]
CREATE TABLE [dbo].[ST_TABLA_SOPORTE](
	[Item] INT IDENTITY(1,1) PRIMARY KEY,
	[Area] [int] NULL,
	[Tipo] [int] NULL,
	[Descripcion] [varchar](50) NULL,
	[Key] [varchar](50) NULL,
	[Ident] [varchar](50) NULL,
	[Estado] [bigint] NULL,
	[Comentario] [varchar](70) NULL,
	[SYST900] [varchar](50) NULL
) ON [PRIMARY]
GO


    INSERT INTO ST_TABLA_SOPORTE
	SELECT 
	  Area
	, Tipo
	, Descripcion
	, [Key]
	, Ident
	, Estado
	, Comentario
	, SYST900
	FROM #ST_TABLA_SOPORTE
	
