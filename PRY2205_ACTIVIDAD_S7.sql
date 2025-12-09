-- ACTIVIDAD: OPTIMIZANDO CONSULTAS SQL (SEMANA 7)

-- 1: CREACIÓN DE SINÓNIMOS
CREATE OR REPLACE SYNONYM syn_trab FOR TRABAJADOR;
CREATE OR REPLACE SYNONYM syn_bono FOR BONO_ANTIGUEDAD;
CREATE OR REPLACE SYNONYM syn_tkt FOR TICKETS_CONCIERTO;
CREATE OR REPLACE SYNONYM syn_esc FOR BONO_ESCOLAR;
CREATE OR REPLACE SYNONYM syn_asig FOR ASIGNACION_FAMILIAR;

-- CASO 1: BONIFICACIÓN DE TRABAJADORES (INSERT)
INSERT INTO DETALLE_BONIFICACIONES_TRABAJADOR (
    NUM, RUT, NOMBRE_TRABAJADOR, SUELDO_BASE, 
    NUM_TICKET, DIRECCION, SISTEMA_SALUD, MONTO, 
    BONIF_X_TICKET, SIMULACION_X_TICKET, SIMULACION_ANTIGUEDAD
)
SELECT 
    SEQ_DET_BONIF.NEXTVAL,
    TO_CHAR(t.numrut) || '-' || t.dvrut,
    INITCAP(t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno),
    TO_CHAR(t.sueldo_base),
    
    -- Regla: Si no hay ticket, mostrar 'No hay info'
    NVL(TO_CHAR(tk.nro_ticket), 'No hay info'),
    
    t.direccion,
    i.nombre_isapre,
    TO_CHAR(NVL(tk.monto_ticket, 0)),
    
    -- Lógica Bono Ticket: 0% (<=50k), 5% (50-100k), 7% (>100k)
    TO_CHAR(CASE 
        WHEN tk.monto_ticket <= 50000 THEN 0
        WHEN tk.monto_ticket > 50000 AND tk.monto_ticket <= 100000 THEN ROUND(tk.monto_ticket * 0.05)
        WHEN tk.monto_ticket > 100000 THEN ROUND(tk.monto_ticket * 0.07)
        ELSE 0 
    END),

    -- Simulación Sueldo + Bono Ticket
    TO_CHAR(t.sueldo_base + 
    CASE 
        WHEN tk.monto_ticket <= 50000 THEN 0
        WHEN tk.monto_ticket > 50000 AND tk.monto_ticket <= 100000 THEN ROUND(tk.monto_ticket * 0.05)
        WHEN tk.monto_ticket > 100000 THEN ROUND(tk.monto_ticket * 0.07)
        ELSE 0 
    END),

    -- Simulación Antigüedad (NonEquiJoin)
    TO_CHAR(ROUND(t.sueldo_base * (1 + ba.porcentaje)))

FROM syn_trab t
JOIN ISAPRE i ON t.cod_isapre = i.cod_isapre
LEFT JOIN syn_tkt tk ON t.numrut = tk.numrut_t
JOIN syn_bono ba ON ROUND(MONTHS_BETWEEN(SYSDATE, t.fecing)/12) 
      BETWEEN ba.limite_inferior AND ba.limite_superior
WHERE 
    ROUND(MONTHS_BETWEEN(SYSDATE, t.fecnac)/12) < 50
    AND i.porc_descto_isapre > 4
ORDER BY 
    NVL(tk.monto_ticket, 0) DESC,
    3 ASC; -- Ordena por la 3ra columna (Nombre Completo) para cumplir criterio exacto

COMMIT;

-- CASO 2: VISTA DE AUMENTOS POR ESTUDIOS
CREATE OR REPLACE VIEW V_AUMENTOS_ESTUDIOS AS
SELECT 
    be.descrip AS "DESCRIP",
    TO_CHAR(t.numrut) || '-' || t.dvrut AS "RUT_TRABAJADOR",
    INITCAP(t.nombre || ' ' || t.appaterno || ' ' || t.apmaterno) AS "NOMBRE_TRABAJADOR",
    be.porc_bono || '%' AS "PCT_ESTUDIOS",
    t.sueldo_base AS "SUELDO_ACTUAL",
    ROUND(t.sueldo_base * (be.porc_bono / 100)) AS "AUMENTO",
    ROUND(t.sueldo_base * (1 + (be.porc_bono / 100))) AS "SUELDO_AUMENTADO"
FROM syn_trab t
JOIN TIPO_TRABAJADOR tt ON t.id_categoria_t = tt.id_categoria
JOIN syn_esc be ON t.id_escolaridad_t = be.id_escolar
WHERE 
    UPPER(tt.desc_categoria) = 'CAJERO'
    AND (
        -- Subconsulta requerida por pauta para filtrar cargas
        SELECT COUNT(*) 
        FROM syn_asig a 
        WHERE a.numrut_t = t.numrut
    ) IN (1, 2)
ORDER BY 
    be.porc_bono ASC,
    3 ASC; -- Ordena por la 3ra columna (Nombre Completo)

-- CASO 2: OPTIMIZACIÓN (ÍNDICE)
-- Crea índice basado en función para evitar Full Table Scan con UPPER()
CREATE INDEX IDX_TRABAJADOR_APM_UPPER 
ON TRABAJADOR(UPPER(apmaterno));