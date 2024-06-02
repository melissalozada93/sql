USE [DWCOOPAC]
GO

/****** Object:  Table [dbo].[ST_BITACORA_CAMBIOS_DINERO_FRESCO]    Script Date: 04/04/2024 17:28:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ST_BITACORA_CAMBIOS_DINERO_FRESCO](
	ID INT IDENTITY(1,1) PRIMARY KEY,
	[CODCIPPERSONA] [varchar](12) NULL,
	[FECHAAPERTURA] [date] NULL,
	[MONTOAPERTURA] [decimal](38, 2) NULL,
	[DF] [decimal](38, 2) NULL,
	[DF_ACTUALIZADO] [decimal](38, 2) NULL,
	[DNF] [decimal](38, 2) NULL,
	[DNF_ACTUALIZADO] [decimal](38, 2) NULL,
	[DF_CONS] [decimal](38, 2) NULL,
	[DF_CONS_ACTUALIZADO] [decimal](38, 2) NULL,
	[DNF_CONS] [decimal](38, 2) NULL,
	[DNF_CONS_ACTUALIZADO] [decimal](38, 2) NULL,
	[FECHA_PROCESO] [datetime] NOT NULL,
	[FECHA_ACTUALIZACION] [datetime] NOT NULL
) ON [PRIMARY]
GO


