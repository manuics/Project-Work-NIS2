-- ================================================================
-- FILE: 02_indexes.sql
-- DESCRIZIONE: Indici per migliorare le prestazioni delle query
--   più frequenti nel contesto dei profili ACN/NIS2.
--
--   Ho creato indici sulle colonne che compaiono più spesso
--   nelle clausole WHERE e JOIN delle query principali.
-- ================================================================


-- Asset: le ricerche più comuni sono per criticità e per organizzazione
CREATE INDEX idx_asset_criticita        ON asset(criticita);
CREATE INDEX idx_asset_organizzazione   ON asset(organizzazione_id);
CREATE INDEX idx_asset_tipo             ON asset(tipo);
-- Questo indice velocizza il filtro "valido_al IS NULL" (record correnti)
CREATE INDEX idx_asset_valido_al        ON asset(valido_al);

-- Servizi: stessa logica degli asset
CREATE INDEX idx_servizio_criticita     ON servizio(criticita);
CREATE INDEX idx_servizio_org           ON servizio(organizzazione_id);
CREATE INDEX idx_servizio_valido_al     ON servizio(valido_al);

-- Responsabilità: la combo (tipo_entita, entita_id) è quella
-- usata più spesso per trovare i responsabili di un servizio o asset
CREATE INDEX idx_resp_entita            ON responsabilita(tipo_entita, entita_id);
CREATE INDEX idx_resp_responsabile      ON responsabilita(responsabile_id);

-- Storico asset: serve per trovare velocemente tutte le versioni
-- di un determinato asset e per filtrare per periodo di validità
CREATE INDEX idx_storico_asset_id       ON asset_storico(asset_id);
CREATE INDEX idx_storico_periodo        ON asset_storico(valido_dal, valido_al);

-- Fornitore: ricerca per nome (utile nelle join e nelle ricerche manuali)
CREATE INDEX idx_fornitore_nome         ON fornitore(nome);

-- Responsabile: la email è usata per login/ricerche, l'org_id per filtrare
CREATE INDEX idx_responsabile_email     ON responsabile(email);
CREATE INDEX idx_responsabile_org       ON responsabile(org_id);
