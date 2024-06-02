USE [DWCOOPAC]
GO

/****** Object:  Table [dbo].[ST_FUNCIONARIO]    Script Date: 15/11/2023 17:42:07 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
--drop table [ST_TABLA_SOPORTE]
CREATE TABLE [dbo].[ST_TABLA_SOPORTE](
	[Item] INT,
	[Area] INT,
	[Tipo] INT,
	[Descripcion] [varchar](50) NULL,
	[Key] [varchar](50) NULL,
	[Ident] [varchar](50) NULL,
	[Estado] [bigint] NULL,
	[Comentario] [varchar](70) NULL,
	[SYST900] [varchar](50) NULL
) ON [PRIMARY]
GO


insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('1','4','1','EXCLUIR','TAN','EXCLUIR','1','Dash Gerencial','1091-1092-1093')
insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('2','4','1','EXCLUIR','PLC','EXCLUIR','1','Dash Gerencial','1091-1092-1093')
insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('3','4','1','EXCLUIR','LPC','EXCLUIR','1','Dash Gerencial','1091-1092-1093')
insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('4','4','1','EXCLUIR','PDD','EXCLUIR','1','Dash Gerencial','1091-1092-1093')
insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('5','4','1','EXCLUIR','DSC','EXCLUIR','1','Dash Gerencial','1091-1092-1093')
insert into ST_TABLA_SOPORTE ([Item],[Area],[Tipo],[Descripcion],[Key],[Ident],[Estado],[Comentario],[SYST900]) values ('6','4','1','EXCLUIR','PLR','EXCLUIR','1','Dash Gerencial','1091-1092-1093')



select * from [ST_TABLA_SOPORTE]