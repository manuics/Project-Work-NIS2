-- ================================================================
-- FILE: 06_queries_acn.sql
-- DESCRIZIONE: Query per estrarre le informazioni richieste
--   nei profili ACN (Agenzia per la Cybersicurezza Nazionale),
--   come previsto dalla Direttiva NIS2.
--
--   Ogni query corrisponde a una sezione del profilo ACN.
--   Le ho separate con commenti esplicativi per facilitare
--   la comprensione anche a chi non conosce il database.
-- ================================================================


-- ----------------------------------------------------------------
-- QUERY 1 – Elenco asset critici
-- Sezione profilo ACN: "Censimento asset rilevanti"
--
-- Estrae tutti gli asset attivi con criticità alta o critica,
-- ordinati dalla criticità più alta verso il basso.
-- ----------------------------------------------------------------
SELECT
    nome                AS asset,
    tipo,
    criticita,
    indirizzo_ip,
    sistema_operativo,
    versione,
    localizzazione,
    valido_dal          AS data_censimento
FROM asset
WHERE criticita IN ('alta', 'critica')
  AND valido_al IS NULL   -- solo versioni correnti, non lo storico
ORDER BY
    CASE criticita
        WHEN 'critica' THEN 1
        WHEN 'alta'    THEN 2
    END,
    nome;


-- ----------------------------------------------------------------
-- QUERY 2 – Servizi erogati con criticità e SLA
-- Sezione profilo ACN: "Servizi essenziali o importanti"
--
-- Elenca tutti i servizi ancora attivi, ordinati per criticità.
-- L'SLA (sla_ore) indica il tempo massimo di ripristino
-- tollerato per quel servizio.
-- ----------------------------------------------------------------
SELECT
    s.nome              AS servizio,
    s.descrizione,
    s.criticita,
    s.sla_ore           AS sla_ripristino_ore,
    s.url,
    s.valido_dal        AS attivo_dal
FROM servizio s
WHERE s.valido_al IS NULL
ORDER BY
    CASE s.criticita
        WHEN 'critica' THEN 1
        WHEN 'alta'    THEN 2
        ELSE 3
    END,
    s.nome;


-- ----------------------------------------------------------------
-- QUERY 3 – Dipendenze interne: servizi e asset collegati
-- Sezione profilo ACN: "Interdipendenze infrastrutturali"
--
-- Mostra quali asset supportano ciascun servizio e con
-- quale ruolo (primario, backup, dipendenza).
-- ----------------------------------------------------------------
SELECT
    s.nome          AS servizio,
    s.criticita     AS criticita_servizio,
    a.nome          AS asset_dipendente,
    a.tipo          AS tipo_asset,
    a.criticita     AS criticita_asset,
    sa.ruolo        AS ruolo_nel_servizio
FROM servizio s
JOIN servizio_asset sa  ON s.id = sa.servizio_id
JOIN asset a            ON a.id = sa.asset_id
                       AND a.valido_al IS NULL
WHERE s.valido_al IS NULL
ORDER BY
    s.criticita DESC,
    s.nome,
    a.criticita DESC;


-- ----------------------------------------------------------------
-- QUERY 4 – Fornitori terzi e stato dei contratti
-- Sezione profilo ACN: "Gestione supply chain – Art. 21 NIS2"
--
-- Per ogni servizio mostra il fornitore esterno coinvolto
-- e lo stato del contratto. I contratti scaduti o in scadenza
-- entro 90 giorni sono evidenziati per facilitare l'azione.
-- ----------------------------------------------------------------
SELECT
    s.nome                  AS servizio,
    s.criticita             AS criticita_servizio,
    f.nome                  AS fornitore,
    f.paese,
    f.tipo_servizio,
    f.certificazioni,
    sf.tipo_dipendenza,
    sf.contratto_scadenza,
    CASE
        WHEN sf.contratto_scadenza < CURRENT_DATE           THEN 'CONTRATTO SCADUTO'
        WHEN sf.contratto_scadenza < CURRENT_DATE + 90      THEN 'In scadenza entro 90 giorni'
        ELSE 'Regolare'
    END                     AS stato_contratto,
    f.contatto_email
FROM servizio_fornitore sf
JOIN servizio   s ON s.id = sf.servizio_id  AND s.valido_al IS NULL
JOIN fornitore  f ON f.id = sf.fornitore_id
ORDER BY
    s.criticita DESC,
    sf.contratto_scadenza ASC,   -- i contratti più urgenti vengono prima
    s.nome;


-- ----------------------------------------------------------------
-- QUERY 5 – Referenti per la gestione degli incidenti
-- Sezione profilo ACN: "Punti di contatto – servizi critici"
--
-- Elenca i responsabili assegnati ai servizi critici o ad alta
-- criticità, con recapiti e tipo di ruolo.
-- ----------------------------------------------------------------
SELECT
    s.nome                          AS servizio,
    s.criticita,
    r.nome || ' ' || r.cognome      AS responsabile,
    r.ruolo,
    r.email,
    r.telefono,
    resp.tipo_ruolo
FROM responsabilita resp
JOIN servizio     s ON s.id = resp.entita_id
                   AND resp.tipo_entita = 'servizio'
JOIN responsabile r ON r.id = resp.responsabile_id
                   AND r.attivo = TRUE
WHERE s.criticita IN ('alta', 'critica')
  AND s.valido_al IS NULL
  AND resp.data_fine IS NULL
ORDER BY
    s.criticita DESC,
    s.nome,
    resp.tipo_ruolo;


-- ----------------------------------------------------------------
-- QUERY 6 – Storico versioni di un asset
-- Sezione profilo ACN: "Tracciabilità e audit trail"
--
-- Richiama la funzione fn_storico_asset per ottenere tutte
-- le versioni (storiche + corrente) di un asset specifico.
-- Sostituire il parametro '1' con l'id dell'asset da esaminare.
-- ----------------------------------------------------------------
SELECT * FROM fn_storico_asset(1);


-- ----------------------------------------------------------------
-- QUERY 7 – Dashboard: conteggio asset per criticità e tipo
-- Utile per avere una panoramica rapida dello stato del censimento
-- ----------------------------------------------------------------
SELECT
    criticita,
    tipo,
    COUNT(*) AS numero_asset
FROM asset
WHERE valido_al IS NULL
GROUP BY criticita, tipo
ORDER BY
    CASE criticita
        WHEN 'critica' THEN 1
        WHEN 'alta'    THEN 2
        WHEN 'media'   THEN 3
        ELSE 4
    END,
    tipo;


-- ================================================================
-- ESPORTAZIONE CSV
-- Per esportare i report, usare il comando COPY (richiede
-- permessi di scrittura sul filesystem del server PostgreSQL).
-- Modificare il percorso in base all'ambiente in uso.
-- ================================================================

-- Esportazione del report completo ACN
-- COPY report_acn TO '/tmp/report_acn.csv' CSV HEADER;

-- Esportazioni per singola sezione del profilo
-- COPY (SELECT * FROM vista_asset_critici)           TO '/tmp/asset_critici.csv'          CSV HEADER;
-- COPY (SELECT * FROM vista_dipendenze_fornitori)    TO '/tmp/dipendenze_fornitori.csv'    CSV HEADER;
-- COPY (SELECT * FROM vista_responsabilita_complete) TO '/tmp/responsabilita.csv'          CSV HEADER;
