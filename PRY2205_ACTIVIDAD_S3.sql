-- CASO 1: Listado de Clientes con Rango de Renta
-- Variables de sustitución para el rango de renta
--Ingrese la renta mínima:
ACCEPT RENTA_MINIMA NUMBER PROMPT 'Renta Mínima: '
--Ingrese la renta máxima:
ACCEPT RENTA_MAXIMA NUMBER PROMPT 'Renta Máxima: '

SELECT 
    -- Formatear RUT con puntos y guion
    TO_CHAR(numrut_cli, 'FM99G999G999') || '-' || dvrut_cli AS "RUT CLIENTE",
    
    -- Nombre completo en mayúsculas
    UPPER(nombre_cli || ' ' || appaterno_cli || ' ' || apmaterno_cli) AS "NOMBRE COMPLETO",
    
    -- Renta formateada con separador de miles
    TO_CHAR(renta_cli, 'FM$999G999G999') AS "RENTA",
    
    -- Clasificación por tramos usando CASE
    CASE 
        WHEN renta_cli > 500000 THEN 'TRAMO 1'
        WHEN renta_cli BETWEEN 400000 AND 500000 THEN 'TRAMO 2'
        WHEN renta_cli BETWEEN 200000 AND 399999 THEN 'TRAMO 3'
        ELSE 'TRAMO 4'
    END AS "TRAMO"
    
FROM cliente

WHERE 
    -- Filtrar por rango de renta (parámetros)
    renta_cli BETWEEN &RENTA_MINIMA AND &RENTA_MAXIMA
    -- Solo clientes con celular registrado
    AND celular_cli IS NOT NULL

ORDER BY 
    -- Ordenar por nombre completo
    nombre_cli, appaterno_cli, apmaterno_cli;
    
    -- CASO 2: Sueldo Promedio por Categoría de Empleado
-- Variable de sustitución para sueldo promedio mínimo
--Ingrese el sueldo promedio mínimo:
ACCEPT SUELDO_PROMEDIO_MINIMO NUMBER PROMPT 'Sueldo Promedio Mínimo: '

SELECT 
    -- Decodificar el código de categoría
    CASE e.id_categoria_emp
        WHEN 1 THEN 'Gerente'
        WHEN 2 THEN 'Supervisor'
        WHEN 3 THEN 'Ejecutivo de Arriendo'
        WHEN 4 THEN 'Auxiliar'
    END AS "CATEGORIA",
    
    -- Decodificar el código de sucursal
    CASE e.id_sucursal
        WHEN 10 THEN 'Sucursal Las Condes'
        WHEN 20 THEN 'Sucursal Santiago Centro'
        WHEN 30 THEN 'Sucursal Providencia'
        WHEN 40 THEN 'Sucursal Vitacura'
    END AS "SUCURSAL",
    
    -- Contar empleados por grupo
    COUNT(*) AS "CANTIDAD EMPLEADOS",
    
    -- Calcular promedio redondeado y formateado
    TO_CHAR(ROUND(AVG(e.sueldo_emp)), 'FM$999G999G999') AS "SUELDO PROMEDIO"
    
FROM empleado e

-- Agrupar por categoría y sucursal
GROUP BY e.id_categoria_emp, e.id_sucursal

-- Filtrar grupos con sueldo promedio mayor al mínimo
HAVING ROUND(AVG(e.sueldo_emp)) > &SUELDO_PROMEDIO_MINIMO

-- Ordenar por sueldo promedio descendente
ORDER BY ROUND(AVG(e.sueldo_emp)) DESC;

-- CASO 3: Arriendo Promedio por Tipo de Propiedad

SELECT 
    -- Decodificar el tipo de propiedad
    CASE p.id_tipo_propiedad
        WHEN 'A' THEN 'CASA'
        WHEN 'B' THEN 'DEPARTAMENTO'
        WHEN 'C' THEN 'LOCAL'
        WHEN 'D' THEN 'PARCELA SIN CASA'
        WHEN 'E' THEN 'PARCELA CON CASA'
    END AS "TIPO PROPIEDAD",
    
    -- Contar total de propiedades
    COUNT(*) AS "TOTAL PROPIEDADES",
    
    -- Promedio de valor de arriendo redondeado y formateado
    TO_CHAR(ROUND(AVG(p.valor_arriendo)), 'FM$999G999G999') AS "PROMEDIO VALOR ARRIENDO",
    
    -- Promedio de superficie redondeado
    ROUND(AVG(p.superficie)) AS "PROMEDIO SUPERFICIE M2",
    
    -- Razón: arriendo por metro cuadrado
    ROUND(AVG(p.valor_arriendo / p.superficie)) AS "VALOR ARRIENDO X M2",
    
    -- Clasificación según valor arriendo por m²
    CASE 
        WHEN ROUND(AVG(p.valor_arriendo / p.superficie)) < 5000 THEN 'Económico'
        WHEN ROUND(AVG(p.valor_arriendo / p.superficie)) BETWEEN 5000 AND 10000 THEN 'Medio'
        ELSE 'Alto'
    END AS "CLASIFICACION"
    
FROM propiedad p

-- Agrupar por tipo de propiedad
GROUP BY p.id_tipo_propiedad

-- Filtrar grupos donde promedio arriendo/m² > 1000
HAVING ROUND(AVG(p.valor_arriendo / p.superficie)) > 1000

-- Ordenar por valor arriendo por m² descendente
ORDER BY ROUND(AVG(p.valor_arriendo / p.superficie)) DESC;

