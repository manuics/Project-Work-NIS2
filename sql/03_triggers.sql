-- ================================================================
-- FILE: 03_triggers.sql
-- DESCRIZIONE: Trigger e funzioni per il versioning automatico
--   degli asset e per mantenere aggiornati i timestamp.
--
--   Ho scelto di usare i trigger per questa logica perché così
--   è trasparente all'applicazione: qualunque UPDATE sull'asset
--   genera automaticamente il record storico, senza bisogno
--   di ricordarselo nel codice applicativo.
-- ================================================================


-- ----------------------------------------------------------------
-- FUNZIONE + TRIGGER 1: Versioning degli asset
--
-- Ogni volta che si aggiorna un asset (su campi significativi),
-- la versione precedente viene copiata in asset_storico
-- e il record corrente viene aggiornato con il nuovo valido_dal.
--
-- Il trigger si attiva SOLO se cambiano i campi "sostanziali"
-- (nome, criticità, tipo, ip, os, versione, localizzazione).
-- Modifiche a note o descrizione non generano una voce storica.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_asset_versioning()
RETURNS TRIGGER AS $$
BEGIN
    -- Prima di sovrascrivere i dati, salvo la versione precedente
    INSERT INTO asset_storico (
        asset_id,
        nome,
        descrizione,
        tipo,
        criticita,
        indirizzo_ip,
        sistema_operativo,
        versione,
        localizzazione,
        organizzazione_id,
        valido_dal,
        valido_al,
        modificato_il
    ) VALUES (
        OLD.id,
        OLD.nome,
        OLD.descrizione,
        OLD.tipo,
        OLD.criticita,
        OLD.indirizzo_ip,
        OLD.sistema_operativo,
        OLD.versione,
        OLD.localizzazione,
        OLD.organizzazione_id,
        OLD.valido_dal,
        CURRENT_TIMESTAMP,   -- il vecchio record "finisce" adesso
        CURRENT_TIMESTAMP
    );

    -- Il record aggiornato diventa quello corrente:
    -- parte da adesso e non ha ancora una data di fine
    NEW.valido_dal := CURRENT_TIMESTAMP;
    NEW.valido_al  := NULL;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Collego la funzione alla tabella asset.
-- La condizione WHEN evita di archiviare modifiche banali
-- (es. solo aggiornamento delle note)
CREATE TRIGGER trg_asset_versioning
BEFORE UPDATE ON asset
FOR EACH ROW
WHEN (
    OLD.nome              IS DISTINCT FROM NEW.nome              OR
    OLD.criticita         IS DISTINCT FROM NEW.criticita         OR
    OLD.tipo              IS DISTINCT FROM NEW.tipo              OR
    OLD.indirizzo_ip      IS DISTINCT FROM NEW.indirizzo_ip      OR
    OLD.sistema_operativo IS DISTINCT FROM NEW.sistema_operativo OR
    OLD.versione          IS DISTINCT FROM NEW.versione          OR
    OLD.localizzazione    IS DISTINCT FROM NEW.localizzazione
)
EXECUTE FUNCTION fn_asset_versioning();

COMMENT ON TRIGGER trg_asset_versioning ON asset
IS 'Archivia la versione precedente in asset_storico ad ogni modifica su campi sostanziali';


-- ----------------------------------------------------------------
-- FUNZIONE + TRIGGER 2: Aggiornamento automatico del timestamp
--   sulla tabella organizzazione.
--
--   Ogni volta che si modifica un record di organizzazione,
--   il campo aggiornata_il viene impostato all'ora corrente.
--   Evita di doverlo passare manualmente da ogni query di UPDATE.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_org_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.aggiornata_il := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_org_updated_at
BEFORE UPDATE ON organizzazione
FOR EACH ROW
EXECUTE FUNCTION fn_update_org_timestamp();


-- ----------------------------------------------------------------
-- STORED PROCEDURE: fn_storico_asset(p_asset_id)
--
-- Restituisce tutte le versioni di un asset in ordine cronologico,
-- dalla prima registrata fino a quella attualmente attiva.
-- Ogni riga ha un numero progressivo di versione e un campo
-- "stato" che vale 'storico' o 'corrente'.
--
-- Uso: SELECT * FROM fn_storico_asset(1);
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_storico_asset(p_asset_id INTEGER)
RETURNS TABLE (
    versione_nr       INTEGER,
    nome              VARCHAR,
    tipo              tipo_asset,
    criticita         livello_criticita,
    indirizzo_ip      VARCHAR,
    sistema_operativo VARCHAR,
    localizzazione    VARCHAR,
    valido_dal        TIMESTAMP,
    valido_al         TIMESTAMP,
    stato             VARCHAR
) AS $$
BEGIN
    RETURN QUERY

    -- Versioni archiviate in asset_storico
    SELECT
        ROW_NUMBER() OVER (ORDER BY s.valido_dal)::INTEGER  AS versione_nr,
        s.nome,
        s.tipo,
        s.criticita,
        s.indirizzo_ip,
        s.sistema_operativo,
        s.localizzazione,
        s.valido_dal,
        s.valido_al,
        'storico'::VARCHAR                                   AS stato
    FROM asset_storico s
    WHERE s.asset_id = p_asset_id

    UNION ALL

    -- Versione corrente (ancora attiva in asset)
    SELECT
        -- numero di versione = storico + 1
        (SELECT COUNT(*) + 1 FROM asset_storico WHERE asset_id = p_asset_id)::INTEGER,
        a.nome,
        a.tipo,
        a.criticita,
        a.indirizzo_ip,
        a.sistema_operativo,
        a.localizzazione,
        a.valido_dal,
        NULL,                    -- valido_al NULL = è quella corrente
        'corrente'::VARCHAR
    FROM asset a
    WHERE a.id = p_asset_id

    ORDER BY valido_dal;

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_storico_asset IS
'Restituisce tutte le versioni (storiche + corrente) di un asset, ordinate per data';
