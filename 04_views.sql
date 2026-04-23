-- ================================================================
-- FILE: 04_views.sql
-- DESCRIZIONE: Viste SQL per estrarre le informazioni richieste
--   nei profili ACN (Agenzia per la Cybersicurezza Nazionale),
--   in conformità alla Direttiva NIS2.
--
--   Le viste sono pensate per essere esportate in CSV da un
--   operatore o da uno script di reporting automatico.
--   Comando di esportazione (esempio):
--     COPY report_acn TO '/tmp/report_acn.csv' CSV HEADER;
-- ================================================================


-- ----------------------------------------------------------------
-- VISTA 1: report_acn
-- Vista generale per la generazione del profilo ACN completo.
-- Mette insieme organizzazione, servizi, asset, fornitori
-- e referenti in un unico risultato "piatto" (denormalizzato),
-- comodo da esportare su foglio di calcolo o da passare
-- al sistema di reportistica.
--
-- Nota: i LEFT JOIN garantiscono che l'organizzazione compaia
-- anche se non ha ancora servizi o fornitori collegati.
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW report_acn AS
SELECT
    o.nome                              AS organizzazione,
    o.settore                           AS settore_acn,
    s.nome                              AS servizio,
    s.criticita                         AS criticita_servizio,
    s.sla_ore                           AS sla_ripristino_ore,
    a.nome                              AS asset,
    a.tipo                              AS tipo_asset,
    a.criticita                         AS criticita_asset,
    a.indirizzo_ip,
    a.sistema_operativo,
    a.versione                          AS versione_asset,
    a.localizzazione,
    f.nome                              AS fornitore,
    f.paese                             AS paese_fornitore,
    f.tipo_servizio                     AS servizio_fornitore,
    f.contatto_email                    AS email_fornitore,
    sf.tipo_dipendenza,
    sf.contratto_scadenza,
    r.nome || ' ' || r.cognome          AS responsabile,
    r.ruolo                             AS ruolo_responsabile,
    r.email                             AS email_responsabile,
    r.telefono                          AS tel_responsabile
FROM organizzazione o
-- Prendo solo i servizi attualmente attivi (valido_al IS NULL)
LEFT JOIN servizio s
       ON s.organizzazione_id = o.id
      AND s.valido_al IS NULL
-- Per ogni servizio prendo gli asset collegati (anch'essi solo correnti)
LEFT JOIN servizio_asset sa
       ON sa.servizio_id = s.id
LEFT JOIN asset a
       ON a.id = sa.asset_id
      AND a.valido_al IS NULL
-- Fornitori associati al servizio
LEFT JOIN servizio_fornitore sf
       ON sf.servizio_id = s.id
LEFT JOIN fornitore f
       ON f.id = sf.fornitore_id
-- Responsabile attivo del servizio (senza data di fine)
LEFT JOIN responsabilita resp
       ON resp.entita_id = s.id
      AND resp.tipo_entita = 'servizio'
      AND resp.data_fine IS NULL
LEFT JOIN responsabile r
       ON r.id = resp.responsabile_id
      AND r.attivo = TRUE;

COMMENT ON VIEW report_acn IS
'Vista principale per i profili ACN. Esportare con: COPY report_acn TO ''/tmp/report_acn.csv'' CSV HEADER;';


-- ----------------------------------------------------------------
-- VISTA 2: vista_asset_critici
-- Elenco degli asset con criticità "alta" o "critica".
-- Corrisponde alla sezione "Censimento asset rilevanti"
-- del profilo ACN.
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vista_asset_critici AS
SELECT
    o.nome                  AS organizzazione,
    a.id,
    a.nome,
    a.tipo,
    a.criticita,
    a.indirizzo_ip,
    a.sistema_operativo,
    a.versione,
    a.localizzazione,
    a.valido_dal            AS data_censimento
FROM asset a
JOIN organizzazione o ON o.id = a.organizzazione_id
-- Solo asset attivi e con criticità rilevante per NIS2
WHERE a.criticita IN ('alta', 'critica')
  AND a.valido_al IS NULL;

COMMENT ON VIEW vista_asset_critici IS 'Asset con criticità alta o critica – sezione profilo ACN';


-- ----------------------------------------------------------------
-- VISTA 3: vista_dipendenze_fornitori
-- Mappa le dipendenze tra i servizi attivi e i fornitori terzi.
-- Include una colonna "stato_contratto" che segnala se il
-- contratto è scaduto, in scadenza entro 90 giorni o regolare.
-- Utile per il monitoraggio della supply chain (NIS2 Art. 21).
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vista_dipendenze_fornitori AS
SELECT
    o.nome                          AS organizzazione,
    s.nome                          AS servizio,
    s.criticita                     AS criticita_servizio,
    f.nome                          AS fornitore,
    f.paese,
    f.tipo_servizio,
    f.certificazioni,
    sf.tipo_dipendenza,
    sf.contratto_scadenza,
    CASE
        WHEN sf.contratto_scadenza < CURRENT_DATE           THEN 'SCADUTO'
        WHEN sf.contratto_scadenza < CURRENT_DATE + 90      THEN 'in_scadenza_90gg'
        ELSE 'regolare'
    END                             AS stato_contratto,
    f.contatto_email
FROM servizio_fornitore sf
JOIN servizio       s ON s.id = sf.servizio_id    AND s.valido_al IS NULL
JOIN fornitore      f ON f.id = sf.fornitore_id
JOIN organizzazione o ON o.id = s.organizzazione_id;

COMMENT ON VIEW vista_dipendenze_fornitori IS
'Dipendenze supply chain – include il controllo automatico sui contratti in scadenza';


-- ----------------------------------------------------------------
-- VISTA 4: vista_responsabilita_complete
-- Mappa completa di tutti i responsabili attivi, con indicazione
-- dell'entità (servizio o asset) di cui si occupano.
-- Usata per la sezione "Contatti" del profilo ACN.
--
-- Ho usato LEFT JOIN su servizio e asset perché ogni riga di
-- responsabilita si riferisce a uno solo dei due: la condizione
-- nel JOIN filtra automaticamente il caso corretto.
-- ----------------------------------------------------------------
CREATE OR REPLACE VIEW vista_responsabilita_complete AS
SELECT
    o.nome                          AS organizzazione,
    resp.tipo_entita,
    CASE resp.tipo_entita
        WHEN 'servizio' THEN s.nome
        WHEN 'asset'    THEN a.nome
    END                             AS entita_nome,
    CASE resp.tipo_entita
        WHEN 'servizio' THEN s.criticita::TEXT
        WHEN 'asset'    THEN a.criticita::TEXT
    END                             AS criticita,
    r.nome || ' ' || r.cognome      AS responsabile,
    r.ruolo,
    r.email,
    r.telefono,
    resp.tipo_ruolo,
    resp.data_inizio,
    resp.data_fine
FROM responsabilita resp
JOIN responsabile r
       ON r.id = resp.responsabile_id
-- Servizio collegato (solo se tipo_entita = 'servizio')
LEFT JOIN servizio s
       ON resp.tipo_entita = 'servizio'
      AND s.id = resp.entita_id
-- Asset collegato (solo se tipo_entita = 'asset')
LEFT JOIN asset a
       ON resp.tipo_entita = 'asset'
      AND a.id = resp.entita_id
-- Recupero l'organizzazione da servizio o asset, a seconda del caso
LEFT JOIN organizzazione o
       ON o.id = COALESCE(s.organizzazione_id, a.organizzazione_id)
-- Solo responsabilità attive e responsabili ancora in forza
WHERE resp.data_fine IS NULL
  AND r.attivo = TRUE;

COMMENT ON VIEW vista_responsabilita_complete IS
'Mappa responsabili attivi per servizi e asset – usata nella sezione contatti del profilo ACN';
