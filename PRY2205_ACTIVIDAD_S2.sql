ALTER SESSION SET NLS_LANGUAGE = 'SPANISH';

-- Caso 1: Análisis de Facturas del año anterior

SELECT
  f.numfactura                                                            AS nro_factura,
  -- Fecha en formato texto: DD "de" Mes YYYY
  TO_CHAR(f.fecha, 'DD "de" Month YYYY')                                  AS fecha_emision,
  -- RUT cliente de largo 10, completando con ceros a la izquierda 
  LPAD(f.rutcliente, 10, '0')                                             AS rut_cliente,
  -- Monto neto, IVA y total redondeados a entero y formateados en CLP
  TO_CHAR(ROUND(f.neto),  '$999G999G999')                                 AS neto_clp,
  TO_CHAR(ROUND(f.iva),   '$999G999G999')                                 AS iva_clp,
  TO_CHAR(ROUND(f.total), '$999G999G999')                                 AS total_clp,
  -- Clasificación por total: 0–50.000 Bajo; 50.001–100.000 Medio; >100.000 Alto
  CASE
    WHEN f.total <= 50000                 THEN 'Bajo'
    WHEN f.total BETWEEN 50001 AND 100000 THEN 'Medio'
    ELSE                                       'Alto'
  END                                                                     AS clasificacion_total,
  -- Forma de pago textual (si no hay código, se informa 'Sin registro')
  CASE
    WHEN f.codpago IS NULL THEN 'Sin registro'
    WHEN f.codpago = 1     THEN 'EFECTIVO'
    WHEN f.codpago = 2     THEN 'TARJETA DEBITO'
    WHEN f.codpago = 3     THEN 'TARJETA CREDITO'
    WHEN f.codpago = 4     THEN 'CHEQUE'
    ELSE                        'OTRO'
  END                                                                     AS forma_pago
FROM factura f
WHERE EXTRACT(YEAR FROM f.fecha) = EXTRACT(YEAR FROM SYSDATE) - 1
ORDER BY
  f.fecha DESC,         -- primero por fecha descendente
  f.neto  DESC;         -- luego por neto descendente
  
-- Caso 2: Clasificación de Clientes (estado A, crédito > 0) - SIN WITH

SELECT
  -- RUT invertido y rellenado a la derecha con '*' hasta el largo original
  RPAD(
    (
      SELECT LISTAGG(SUBSTR(c.rutcliente, pos, 1), '') WITHIN GROUP (ORDER BY pos)
      FROM (
        SELECT (LENGTH(c.rutcliente) - LEVEL + 1) AS pos
        FROM dual
        CONNECT BY LEVEL <= LENGTH(c.rutcliente)
      )
    ),
    LENGTH(c.rutcliente),
    '*'
  )                                                                AS rut_inv_pad,
  c.nombre                                                         AS nombre_cliente,
  -- Teléfono en texto; si NULL, mensaje
  NVL(TO_CHAR(c.telefono), 'Sin teléfono')                        AS telefono,
  -- Comuna por JOIN; si NULL, mensaje
  NVL(co.descripcion, 'Sin comuna')                               AS comuna,
  -- Correo; si NULL, mensaje
  NVL(c.mail, 'Correo no registrado')                             AS correo,
  -- Dominio del correo; si correo es NULL o no tiene '@', mostrar 'N/A'
  CASE
    WHEN c.mail IS NULL OR INSTR(c.mail, '@') = 0
      THEN 'N/A'
    ELSE SUBSTR(c.mail, INSTR(c.mail, '@') + 1)
  END                                                              AS dominio_correo,
  -- Relación saldo/credito (como referencia numérica)
  ROUND(c.saldo / c.credito, 4)                                    AS relacion_saldo_credito,
  -- Categoría y valor a mostrar según regla del enunciado
  CASE
    WHEN c.saldo / c.credito < 0.5
      THEN 'Bueno'
    WHEN c.saldo / c.credito <= 0.8
      THEN 'Regular'
    ELSE 'Crítico'
  END                                                              AS categoria_credito,
  CASE
    WHEN c.saldo / c.credito < 0.5
      THEN TO_CHAR(ROUND(c.credito - c.saldo), '$999G999G999')
    WHEN c.saldo / c.credito <= 0.8
      THEN TO_CHAR(ROUND(c.saldo), '$999G999G999')
    ELSE ' '
  END                                                              AS valor_mostrado
FROM cliente c
LEFT JOIN comuna co
  ON c.codcomuna = co.codcomuna
WHERE
  c.estado = 'A'
  AND c.credito > 0
ORDER BY
  c.nombre ASC;
  
  -- Caso 3: Stock de productos con filtros, conversión de USD a CLP y alertas

SELECT
  p.codproducto                                                     AS id_producto,
  p.descripcion                                                     AS descripcion,
  -- Valor de compra en USD con 2 decimales; si no hay dato, mostrar 'Sin registro'
  CASE
    WHEN p.valorcompradolar IS NULL
      THEN 'Sin registro'
    ELSE TO_CHAR(ROUND(p.valorcompradolar, 2), 'FM999G999G990D00')
  END                                                               AS valor_compra_usd,
  -- Valor de compra convertido a CLP usando variable de sustitución; si USD es NULL, 'Sin registro'
  CASE
    WHEN p.valorcompradolar IS NULL
      THEN 'Sin registro'
    ELSE TO_CHAR(ROUND(p.valorcompradolar * &TIPOCAMBIO_DOLAR), '$999G999G999')
  END                                                               AS valor_compra_clp,
  -- Stock total tal cual; podría ser NULL en algunos productos
  NVL(p.totalstock, 0)                                              AS stock_total,
  -- Alerta de stock según umbrales de sustitución (maneja NULL como 'Sin datos')
  CASE
    WHEN p.totalstock IS NULL
      THEN 'Sin datos'
    WHEN p.totalstock < &UMBRAL_BAJO
      THEN '¡ALERTA stock muy bajo!'
    WHEN p.totalstock <= &UMBRAL_ALTO
      THEN '¡Reabastecer pronto!'
    ELSE 'OK'
  END                                                               AS alerta_stock,
  -- Precio oferta: 10% descuento sobre vunitario si totalstock > 80; en otro caso 'N/A'
  CASE
    WHEN p.totalstock > 80
      THEN TO_CHAR(ROUND(p.vunitario * 0.9), '$999G999G999')
    ELSE 'N/A'
  END                                                               AS precio_oferta
FROM producto p
WHERE
  -- Solo descripciones que contengan 'zapato' (insensible a mayúsculas/minúsculas)
  UPPER(p.descripcion) LIKE '%ZAPATO%'
  -- Solo procedencia internacional 'I' (se usa UPPER por seguridad)
  AND UPPER(p.procedencia) = 'I'
ORDER BY
  p.codproducto DESC;