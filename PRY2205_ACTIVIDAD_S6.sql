/* CASO 1: Reportería de Asesorías para Banca y Retail */

SELECT 
    p.id_profesional AS "ID PROFESIONAL",
    -- Concatenación de nombre completo
    INITCAP(p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre) AS "NOMBRE COMPLETO",
    
    -- Cálculos para Sector Banca (Cod 3)
    COUNT(CASE WHEN e.cod_sector = 3 THEN 1 END) AS "NRO ASESORIA BANCA",
    TO_CHAR(SUM(CASE WHEN e.cod_sector = 3 THEN a.honorario ELSE 0 END), '$999G999G999') AS "MONTO TOTAL BANCA",
    
    -- Cálculos para Sector Retail (Cod 4)
    COUNT(CASE WHEN e.cod_sector = 4 THEN 1 END) AS "NRO ASESORIA RETAIL",
    TO_CHAR(SUM(CASE WHEN e.cod_sector = 4 THEN a.honorario ELSE 0 END), '$999G999G999') AS "MONTO TOTAL RETAIL",
    
    -- Totales Generales
    COUNT(a.id_profesional) AS "TOTAL ASESORIAS",
    TO_CHAR(SUM(a.honorario), '$999G999G999') AS "TOTAL HONORARIOS"

FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
JOIN empresa e ON a.cod_empresa = e.cod_empresa

WHERE p.id_profesional IN (
    -- Subconsulta con Operador SET (INTERSECT) requerida por instrucciones
    SELECT id_profesional 
    FROM asesoria a 
    JOIN empresa e ON a.cod_empresa = e.cod_empresa 
    WHERE e.cod_sector = 3 -- Banca
    
    INTERSECT
    
    SELECT id_profesional 
    FROM asesoria a 
    JOIN empresa e ON a.cod_empresa = e.cod_empresa 
    WHERE e.cod_sector = 4 -- Retail
)
-- Solo consideramos datos de esos dos sectores para el conteo mostrado
AND e.cod_sector IN (3, 4) 

GROUP BY p.id_profesional, p.appaterno, p.apmaterno, p.nombre
ORDER BY p.id_profesional ASC;


/* CASO 2: Creación de tabla REPORTE_MES con resumen de honorarios */

-- Eliminamos la tabla si ya existe para evitar errores al re-ejecutar
-- DROP TABLE REPORTE_MES; 

CREATE TABLE REPORTE_MES AS
SELECT 
    p.id_profesional AS "ID PROF",
    INITCAP(p.appaterno || ' ' || p.apmaterno || ' ' || p.nombre) AS "NOMBRE COMPLETO",
    pr.nombre_profesion AS "NOMBRE PROFESION",
    c.nom_comuna AS "NOM COMUNA",
    COUNT(a.id_profesional) AS "NRO ASESORIAS",
    ROUND(SUM(a.honorario)) AS "MONTO TOTAL HONORARIOS",
    ROUND(AVG(a.honorario)) AS "PROMEDIO HONORARIO",
    ROUND(MIN(a.honorario)) AS "HONORARIO MINIMO",
    ROUND(MAX(a.honorario)) AS "HONORARIO MAXIMO"
FROM profesional p
JOIN asesoria a ON p.id_profesional = a.id_profesional
JOIN profesion pr ON p.cod_profesion = pr.cod_profesion
JOIN comuna c ON p.cod_comuna = c.cod_comuna
WHERE 
    -- Filtro dinámico: Abril del año pasado respecto a la fecha actual
    EXTRACT(MONTH FROM a.fin_asesoria) = 4 
    AND EXTRACT(YEAR FROM a.fin_asesoria) = (EXTRACT(YEAR FROM SYSDATE) - 1)
GROUP BY 
    p.id_profesional, 
    p.appaterno, 
    p.apmaterno, 
    p.nombre, 
    pr.nombre_profesion, 
    c.nom_comuna
ORDER BY p.id_profesional ASC;

-- Verificación del contenido de la tabla creada
SELECT * FROM REPORTE_MES;


/* CASO 3: Modificación de Honorarios e Incentivos */

-- 1. Reporte ANTES de la actualización (Para verificación)
SELECT 
    a.id_profesional AS "ID_PROFESIONAL", 
    p.numrun_prof AS "NUMRUN_PROF",
    SUM(a.honorario) AS "TOTAL_HONORARIOS_MARZO",
    p.sueldo AS "SUELDO_ACTUAL"
FROM asesoria a
JOIN profesional p ON a.id_profesional = p.id_profesional
WHERE EXTRACT(MONTH FROM a.fin_asesoria) = 3
  AND EXTRACT(YEAR FROM a.fin_asesoria) = (EXTRACT(YEAR FROM SYSDATE) - 1)
GROUP BY a.id_profesional, p.numrun_prof, p.sueldo
ORDER BY a.id_profesional;

-- 2. Sentencia DML de Actualización (UPDATE)
UPDATE profesional p
SET sueldo = (
    SELECT 
        CASE 
            -- Si el total es menor a 1 millón, aumento del 10%
            WHEN SUM(a.honorario) < 1000000 THEN ROUND(p.sueldo * 1.10)
            -- Si el total es mayor o igual a 1 millón, aumento del 15%
            WHEN SUM(a.honorario) >= 1000000 THEN ROUND(p.sueldo * 1.15)
            ELSE p.sueldo
        END
    FROM asesoria a
    WHERE a.id_profesional = p.id_profesional
      AND EXTRACT(MONTH FROM a.fin_asesoria) = 3
      AND EXTRACT(YEAR FROM a.fin_asesoria) = (EXTRACT(YEAR FROM SYSDATE) - 1)
    GROUP BY a.id_profesional
)
WHERE p.id_profesional IN (
    -- Solo actualizamos a quienes tuvieron asesorías en marzo del año pasado
    SELECT id_profesional 
    FROM asesoria 
    WHERE EXTRACT(MONTH FROM fin_asesoria) = 3 
      AND EXTRACT(YEAR FROM fin_asesoria) = (EXTRACT(YEAR FROM SYSDATE) - 1)
);

-- Confirmar cambios de transacción
COMMIT;

-- 3. Reporte DESPUÉS de la actualización (Para verificación)
SELECT 
    a.id_profesional AS "ID_PROFESIONAL", 
    p.numrun_prof AS "NUMRUN_PROF",
    SUM(a.honorario) AS "TOTAL_HONORARIOS_MARZO",
    p.sueldo AS "NUEVO_SUELDO"
FROM asesoria a
JOIN profesional p ON a.id_profesional = p.id_profesional
WHERE EXTRACT(MONTH FROM a.fin_asesoria) = 3
  AND EXTRACT(YEAR FROM a.fin_asesoria) = (EXTRACT(YEAR FROM SYSDATE) - 1)
GROUP BY a.id_profesional, p.numrun_prof, p.sueldo
ORDER BY a.id_profesional;

