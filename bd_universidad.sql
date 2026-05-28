
USE master;
GO

IF DB_ID(N'bd_universidad') IS NOT NULL
BEGIN
    ALTER DATABASE bd_universidad SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
END
GO

DROP DATABASE IF EXISTS bd_universidad;
GO



-- Ejercicio 01: Crear base de datos y seleccionarla.
CREATE DATABASE bd_universidad;
GO

USE bd_universidad;
GO

-- GO es un separador de lotes usado por SSMS/Azure Data Studio.
-- No es una instrucción T-SQL del motor; sirve para enviar bloques separados al servidor.

-- Verificar creación de la base de datos.
SELECT name
FROM sys.databases
WHERE name = N'bd_universidad';
GO

-- Verificar collation heredada de la instancia.
-- En esta instancia se observó: Modern_Spanish_CI_AS.
SELECT SERVERPROPERTY('Collation') AS collation_instancia;
GO

-- SQL Server crea archivos .mdf para datos y .ldf para log de transacciones.
-- Esta consulta muestra la ubicación real en la instancia.
SELECT name AS nombre_logico,
       type_desc AS tipo_archivo,
       physical_name AS ubicacion_fisica
FROM sys.master_files
WHERE database_id = DB_ID(N'bd_universidad');
GO

/*
   Ejercicio 02: Tablas carrera y materia
 */

-- Se usa NVARCHAR en lugar de VARCHAR porque NVARCHAR soporta Unicode,
-- útil para tildes, ñ y otros caracteres especiales.
-- Se usa IDENTITY(1,1) en lugar de AUTO_INCREMENT porque esa es la sintaxis de SQL Server:
-- el primer 1 es la semilla inicial y el segundo 1 es el incremento.

CREATE TABLE dbo.CARRERA (
    id_carrera INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    duracion_anios TINYINT NOT NULL,
    modalidad NVARCHAR(20) NOT NULL,

    CONSTRAINT ck_modalidad_carrera
        CHECK (modalidad IN (N'Presencial', N'Virtual', N'Semipresencial'))
);
GO


CREATE TABLE dbo.MATERIA (
    id_materia INT IDENTITY(1,1) NOT NULL,
    codigo NVARCHAR(10) NOT NULL UNIQUE,
    nombre NVARCHAR(100) NOT NULL,
    creditos TINYINT NOT NULL,
    semestre TINYINT NOT NULL CHECK (semestre BETWEEN 1 AND 10),

    CONSTRAINT pk_materia PRIMARY KEY (id_materia),
    CONSTRAINT ck_creditos_positivos CHECK (creditos > 0)
);
GO

/* =================================================
   Ejercicio 03: Tabla ESTUDIANTE con clave foránea
   ================================================= */

CREATE TABLE dbo.ESTUDIANTE (
    id_estudiante INT IDENTITY(1,1) PRIMARY KEY,
    carnet NVARCHAR(10) NOT NULL UNIQUE,
    nombre_completo NVARCHAR(150) NOT NULL,
    fecha_nacimiento DATE NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    id_carrera INT NOT NULL,

    CONSTRAINT fk_estudiante_carrera
        FOREIGN KEY (id_carrera)
        REFERENCES dbo.CARRERA (id_carrera)
        ON DELETE NO ACTION
        ON UPDATE CASCADE
        /*Tanto on delete no action como restrict se utilizan para impedir que se borre una tabja padre si tiene registos hijos
        su diferencia es que restrict se ejecuta de inmediato y no action al final de la instruccion.
     */
);
GO

-- Verificar la FK creada.
select * from INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS

-- Intento controlado de insertar un estudiante con id_carrera inexistente.
begin try
    insert into ESTUDIANTE(carnet,nombre_completo,fecha_nacimiento,email,id_carrera)
    values(25011543,'Sara Ruiz','2007-08-22','sararuiz@gmail.com',452365)
end try
begin catch
    select ERROR_NUMBER() as error,
    ERROR_MESSAGE() as descripcion,
    ERROR_LINE() as linea
end catch
    


-- Datos base válidos para continuar con las pruebas.
INSERT INTO dbo.CARRERA (nombre, duracion_anios, modalidad)
VALUES
    (N'Ingeniería en Sistemas', 5, N'Presencial'),
    (N'Administración de Empresas', 4, N'Virtual');
GO

INSERT INTO dbo.MATERIA (codigo, nombre, creditos, semestre)
VALUES
    (N'BD101', N'Bases de Datos I', 4, 3),
    (N'POO101', N'Programación Orientada a Objetos', 4, 2),
    (N'RED101', N'Redes I', 3, 4);
GO

INSERT INTO dbo.ESTUDIANTE (carnet, nombre_completo, fecha_nacimiento, email, id_carrera)
SELECT N'20260001',
       N'Sara Ruiz',
       '2006-05-15',
       N'sara.ruiz@uam.edu.ni',
       id_carrera
FROM dbo.CARRERA
WHERE nombre = N'Ingeniería en Sistemas';
GO

/*
   Ejercicio 04: Tabla INSCRIPCION, relación N:M
   */

CREATE TABLE dbo.INSCRIPCION (
    id_inscripcion INT IDENTITY(1,1) PRIMARY KEY,
    id_estudiante INT NOT NULL,
    id_materia INT NOT NULL,

    -- nota_final admite NULL porque un estudiante puede estar inscrito
    -- y todavía no tener calificación asignada.
    -- Si fuera NOT NULL, no podríamos registrar la inscripción
    -- hasta que exista una nota, lo cual rompe el flujo académico real.
    nota_final DECIMAL(4,2) NULL,

    periodo NVARCHAR(3) NOT NULL,
    anio SMALLINT NOT NULL,

    CONSTRAINT fk_inscripcion_estudiante
        FOREIGN KEY (id_estudiante)
        REFERENCES dbo.ESTUDIANTE (id_estudiante),

    CONSTRAINT fk_inscripcion_materia
        FOREIGN KEY (id_materia)
        REFERENCES dbo.MATERIA (id_materia),

    CONSTRAINT ck_periodo_valido
        CHECK (periodo IN (N'I', N'II', N'III')),

    CONSTRAINT ck_anio_valido
        CHECK (anio BETWEEN 2000 AND 2099),

    CONSTRAINT uq_inscripcion
        UNIQUE (id_estudiante, id_materia, anio, periodo)
);
GO

INSERT INTO dbo.INSCRIPCION (id_estudiante, id_materia, nota_final, periodo, anio)
SELECT e.id_estudiante,
       m.id_materia,
       NULL,
       N'I',
       2026
FROM dbo.ESTUDIANTE e
CROSS JOIN dbo.MATERIA m
WHERE e.carnet = N'20260001'
  AND m.codigo = N'BD101';
GO

/*
   Ejercicio 05: Agregar columnas nuevas con ALTER TABLE ADD
    */

-- SQL Server usa ADD sin la palabra COLUMN.
ALTER TABLE dbo.ESTUDIANTE
    ADD telefono NVARCHAR(20) NULL;
GO

-- Se agrega estado con DEFAULT y CHECK nombrado.
ALTER TABLE dbo.ESTUDIANTE
    ADD estado NVARCHAR(10) NOT NULL
            CONSTRAINT df_estudiante_estado DEFAULT N'Activo',
        CONSTRAINT ck_estado_valido CHECK (estado IN (N'Activo', N'Inactivo'));
GO

-- NVARCHAR(MAX) se usa en lugar de TEXT/NTEXT porque TEXT y NTEXT están deprecados.
ALTER TABLE dbo.MATERIA
    ADD descripcion NVARCHAR(MAX) NULL;
GO

/*
   Ejercicio 06: Modificar y renombrar columnas
   \ */

ALTER TABLE dbo.ESTUDIANTE
    ALTER COLUMN telefono NVARCHAR(25) NULL;
GO

-- En SQL Server no existe RENAME COLUMN como en otros motores.
-- Se usa sp_rename.
-- SQL Server mostrará una advertencia porque los objetos dependientes
-- como vistas, procedimientos o funciones que usen el nombre anterior podrían romperse.
-- A diferencia de MySQL, SQL Server no actualiza automáticamente todas esas referencias textuales.
EXEC sp_rename
    N'dbo.CARRERA.duracion_anios',
    N'duracion',
    N'COLUMN';
GO

-- Cambiar nota_final de DECIMAL(4,2) a DECIMAL(5,2).
ALTER TABLE dbo.INSCRIPCION
    ALTER COLUMN nota_final DECIMAL(5,2) NULL;
GO

/* 
   Ejercicio 07: Gestionar restricciones e índices
  */

-- Agregar CHECK a CARRERA después de renombrar duracion_anios a duracion.
ALTER TABLE dbo.CARRERA
    ADD CONSTRAINT ck_duracion_carrera CHECK (duracion BETWEEN 3 AND 6);
GO

-- Índice no agrupado sobre email.
-- La PRIMARY KEY crea un índice CLUSTERED por defecto si no se indica lo contrario.
-- Un índice CLUSTERED ordena físicamente los datos de la tabla según su clave.
-- Un índice NONCLUSTERED crea una estructura separada que apunta a las filas y ayuda a buscar por otras columnas.
CREATE NONCLUSTERED INDEX IX_estudiante_email
ON dbo.ESTUDIANTE (email);
GO

-- Ver todos los CHECK constraints de MATERIA.
SELECT name, definition
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID(N'dbo.MATERIA');
GO

-- Ver todos los constraints de la base de datos.
SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
ORDER BY TABLE_NAME;
GO

-- Consultar el CHECK autogenerado de semestre en MATERIA, eliminarlo y recrearlo con nombre explícito.
DECLARE @nombre_check_semestre SYSNAME;
DECLARE @sql NVARCHAR(MAX);

SELECT @nombre_check_semestre = cc.name
FROM sys.check_constraints cc
WHERE cc.parent_object_id = OBJECT_ID(N'dbo.MATERIA')
  AND cc.definition LIKE N'%semestre%'
  AND cc.definition LIKE N'%1%'
  AND cc.definition LIKE N'%10%';

SELECT @nombre_check_semestre AS check_semestre_materia_autogenerado;

IF @nombre_check_semestre IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE dbo.MATERIA DROP CONSTRAINT ' + QUOTENAME(@nombre_check_semestre) + N';';
    EXEC sp_executesql @sql;
END;
GO

ALTER TABLE dbo.MATERIA
    ADD CONSTRAINT ck_semestre_valido CHECK (semestre BETWEEN 1 AND 10);
GO

/* 
   Ejercicio 08: Eliminar columnas con ALTER TABLE DROP COLUMN
   */

-- SQL Server exige eliminar primero objetos dependientes de una columna,
-- como DEFAULT constraints, porque esos objetos quedan enlazados internamente a la columna.
-- En algunos gestores, como MySQL, esta limpieza puede hacerse de forma implícita;
-- en SQL Server normalmente se debe controlar explícitamente.

DECLARE @default_descripcion SYSNAME;
DECLARE @sql_default NVARCHAR(MAX);

SELECT @default_descripcion = d.name
FROM sys.default_constraints d
JOIN sys.columns c
    ON d.parent_column_id = c.column_id
   AND d.parent_object_id = c.object_id
WHERE c.object_id = OBJECT_ID(N'dbo.MATERIA')
  AND c.name = N'descripcion';

SELECT @default_descripcion AS default_ligado_a_descripcion;

IF @default_descripcion IS NOT NULL
BEGIN
    SET @sql_default = N'ALTER TABLE dbo.MATERIA DROP CONSTRAINT ' + QUOTENAME(@default_descripcion) + N';';
    EXEC sp_executesql @sql_default;
END;
GO

ALTER TABLE dbo.MATERIA
    DROP COLUMN descripcion;
GO

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = N'MATERIA';
GO

-- Consultas para capturas de pantalla del entregable después de los ALTER.
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'CARRERA';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'MATERIA';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'ESTUDIANTE';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'INSCRIPCION';
GO

/* 
   Ejercicio 09: DROP TABLE respetando dependencias FK
  */

-- Intento controlado de eliminar CARRERA directamente.
-- Debe fallar porque ESTUDIANTE tiene una FK que referencia CARRERA.
-- SQL Server normalmente devuelve el error 3726 en este escenario.
BEGIN TRY
    DROP TABLE dbo.CARRERA;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error,
           ERROR_MESSAGE() AS mensaje_error;
END CATCH;
GO

-- SQL Server no tiene DROP TABLE ... CASCADE como PostgreSQL.
-- En producción se maneja eliminando primero las FK dependientes o eliminando primero las tablas hijas.
-- El orden correcto lo impone el motor mediante las claves foráneas.
DROP TABLE IF EXISTS dbo.INSCRIPCION;
DROP TABLE IF EXISTS dbo.ESTUDIANTE;
DROP TABLE IF EXISTS dbo.MATERIA;
DROP TABLE IF EXISTS dbo.CARRERA;
GO

/*
   Ejercicio 10: DROP vs TRUNCATE vs DELETE en SQL Server
  */

-- Recreación de las 4 tablas con la estructura final obtenida después de los ALTER.
CREATE TABLE dbo.CARRERA (
    id_carrera INT IDENTITY(1,1) PRIMARY KEY,
    nombre NVARCHAR(100) NOT NULL,
    duracion TINYINT NOT NULL,
    modalidad NVARCHAR(20) NOT NULL,

    CONSTRAINT ck_modalidad_carrera
        CHECK (modalidad IN (N'Presencial', N'Virtual', N'Semipresencial')),
    CONSTRAINT ck_duracion_carrera
        CHECK (duracion BETWEEN 3 AND 6)
);
GO

CREATE TABLE dbo.MATERIA (
    id_materia INT IDENTITY(1,1) NOT NULL,
    codigo NVARCHAR(10) NOT NULL UNIQUE,
    nombre NVARCHAR(100) NOT NULL,
    creditos TINYINT NOT NULL,
    semestre TINYINT NOT NULL,

    CONSTRAINT pk_materia PRIMARY KEY (id_materia),
    CONSTRAINT ck_creditos_positivos CHECK (creditos > 0),
    CONSTRAINT ck_semestre_valido CHECK (semestre BETWEEN 1 AND 10)
);
GO

CREATE TABLE dbo.ESTUDIANTE (
    id_estudiante INT IDENTITY(1,1) PRIMARY KEY,
    carnet NVARCHAR(10) NOT NULL UNIQUE,
    nombre_completo NVARCHAR(150) NOT NULL,
    fecha_nacimiento DATE NULL,
    email NVARCHAR(100) NOT NULL UNIQUE,
    id_carrera INT NOT NULL,
    telefono NVARCHAR(25) NULL,
    estado NVARCHAR(10) NOT NULL CONSTRAINT df_estudiante_estado DEFAULT N'Activo',

    CONSTRAINT fk_estudiante_carrera
        FOREIGN KEY (id_carrera)
        REFERENCES dbo.CARRERA (id_carrera)
        ON DELETE NO ACTION
        ON UPDATE CASCADE,
    CONSTRAINT ck_estado_valido CHECK (estado IN (N'Activo', N'Inactivo'))
);
GO

CREATE NONCLUSTERED INDEX IX_estudiante_email
ON dbo.ESTUDIANTE (email);
GO

CREATE TABLE dbo.INSCRIPCION (
    id_inscripcion INT IDENTITY(1,1) PRIMARY KEY,
    id_estudiante INT NOT NULL,
    id_materia INT NOT NULL,
    nota_final DECIMAL(5,2) NULL,
    periodo NVARCHAR(3) NOT NULL,
    anio SMALLINT NOT NULL,

    CONSTRAINT fk_inscripcion_estudiante
        FOREIGN KEY (id_estudiante)
        REFERENCES dbo.ESTUDIANTE (id_estudiante),

    CONSTRAINT fk_inscripcion_materia
        FOREIGN KEY (id_materia)
        REFERENCES dbo.MATERIA (id_materia),

    CONSTRAINT ck_periodo_valido CHECK (periodo IN (N'I', N'II', N'III')),
    CONSTRAINT ck_anio_valido CHECK (anio BETWEEN 2000 AND 2099),
    CONSTRAINT uq_inscripcion UNIQUE (id_estudiante, id_materia, anio, periodo)
);
GO

INSERT INTO dbo.CARRERA (nombre, duracion, modalidad)
VALUES
    (N'Ingeniería en Sistemas', 5, N'Presencial'),
    (N'Administración de Empresas', 4, N'Virtual');
GO

INSERT INTO dbo.MATERIA (codigo, nombre, creditos, semestre)
VALUES
    (N'BD101', N'Bases de Datos I', 4, 3),
    (N'POO101', N'Programación Orientada a Objetos', 4, 2),
    (N'RED101', N'Redes I', 3, 4);
GO

-- DROP TABLE elimina estructura, datos, constraints e índices.
-- Es DDL, pero en SQL Server puede participar en transacciones y revertirse con ROLLBACK.
-- Al eliminar la tabla también desaparece la propiedad IDENTITY.

-- DELETE FROM sin WHERE elimina fila por fila, registra operaciones en el log y NO reinicia IDENTITY.
DELETE FROM dbo.MATERIA;
GO

INSERT INTO dbo.MATERIA (codigo, nombre, creditos, semestre)
VALUES (N'MAT999', N'Materia después de DELETE', 3, 1);
GO

SELECT id_materia, codigo, nombre
FROM dbo.MATERIA;
GO

-- TRUNCATE TABLE mantiene la estructura, elimina los datos y reinicia IDENTITY.
-- En SQL Server es transaccional y puede revertirse con ROLLBACK.
-- Sin embargo, no puede ejecutarse sobre una tabla referenciada por una FK activa.
BEGIN TRY
    TRUNCATE TABLE dbo.MATERIA;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error_truncate_materia,
           ERROR_MESSAGE() AS mensaje_error_truncate_materia;
END CATCH;
GO

-- Prueba transaccional de TRUNCATE con ROLLBACK en una tabla independiente.
CREATE TABLE dbo.PRUEBA_TRUNCATE_ROLLBACK (
    id_prueba INT IDENTITY(1,1) PRIMARY KEY,
    valor NVARCHAR(50) NOT NULL
);
GO

INSERT INTO dbo.PRUEBA_TRUNCATE_ROLLBACK (valor)
VALUES (N'A'), (N'B'), (N'C');
GO

BEGIN TRANSACTION;
    TRUNCATE TABLE dbo.PRUEBA_TRUNCATE_ROLLBACK;
    SELECT COUNT(*) AS filas_durante_truncate
    FROM dbo.PRUEBA_TRUNCATE_ROLLBACK;
ROLLBACK;
GO

SELECT COUNT(*) AS filas_despues_rollback
FROM dbo.PRUEBA_TRUNCATE_ROLLBACK;
GO

-- Comparación de IDENTITY con DELETE: después de borrar, el siguiente id continúa.
CREATE TABLE dbo.PRUEBA_IDENTITY_DELETE (
    id INT IDENTITY(1,1) PRIMARY KEY,
    valor NVARCHAR(20) NOT NULL
);
GO

INSERT INTO dbo.PRUEBA_IDENTITY_DELETE (valor)
VALUES (N'Uno'), (N'Dos'), (N'Tres');
GO

DELETE FROM dbo.PRUEBA_IDENTITY_DELETE;
GO

INSERT INTO dbo.PRUEBA_IDENTITY_DELETE (valor)
VALUES (N'Después DELETE');
GO

SELECT id AS id_despues_delete, valor
FROM dbo.PRUEBA_IDENTITY_DELETE;
GO

-- Comparación de IDENTITY con TRUNCATE: después de truncar, el id vuelve a la semilla.
CREATE TABLE dbo.PRUEBA_IDENTITY_TRUNCATE (
    id INT IDENTITY(1,1) PRIMARY KEY,
    valor NVARCHAR(20) NOT NULL
);
GO

INSERT INTO dbo.PRUEBA_IDENTITY_TRUNCATE (valor)
VALUES (N'Uno'), (N'Dos'), (N'Tres');
GO

TRUNCATE TABLE dbo.PRUEBA_IDENTITY_TRUNCATE;
GO

INSERT INTO dbo.PRUEBA_IDENTITY_TRUNCATE (valor)
VALUES (N'Después TRUNCATE');
GO

SELECT id AS id_despues_truncate, valor
FROM dbo.PRUEBA_IDENTITY_TRUNCATE;
GO

-- Limpieza de tablas auxiliares de prueba.
DROP TABLE IF EXISTS dbo.PRUEBA_TRUNCATE_ROLLBACK;
DROP TABLE IF EXISTS dbo.PRUEBA_IDENTITY_DELETE;
DROP TABLE IF EXISTS dbo.PRUEBA_IDENTITY_TRUNCATE;
GO

-- Estado final de las tablas principales.
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'CARRERA';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'MATERIA';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'ESTUDIANTE';
SELECT * FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = N'INSCRIPCION';
GO
