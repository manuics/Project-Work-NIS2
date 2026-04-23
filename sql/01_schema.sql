-- ================================================================
-- FILE: 01_schema.sql
-- PROGETTO: NIS2 Asset Database
-- AUTORE: Chiarello Manuel Giuseppe  -  Mat. 0312300543
-- DESCRIZIONE: Schema relazionale per la gestione degli asset,
--   dei servizi, delle dipendenze e delle responsabilità
--   in linea con quanto richiesto dalla Direttiva NIS2.
--
--   Lo schema è normalizzato in 3NF.
--   Ogni tabella ha commento esplicativo.
-- ================================================================


-- Prima di ricreare tutto, pulisco le tabelle se esistono già
-- (utile quando si riesegue lo script in fase di sviluppo/test)
DROP TABLE IF EXISTS asset_storico        CASCADE;
DROP TABLE IF EXISTS responsabilita       CASCADE;
DROP TABLE IF EXISTS servizio_fornitore   CASCADE;
DROP TABLE IF EXISTS servizio_asset       CASCADE;
DROP TABLE IF EXISTS fornitore            CASCADE;
DROP TABLE IF EXISTS responsabile         CASCADE;
DROP TABLE IF EXISTS asset                CASCADE;
DROP TABLE IF EXISTS servizio             CASCADE;
DROP TABLE IF EXISTS organizzazione       CASCADE;

-- Creo i tipi ENUM personalizzati.
-- Uso il blocco DO per evitare errori se il tipo esiste già
-- (capita spesso in fase di test ripetuti)
DO $$ BEGIN
    CREATE TYPE livello_criticita AS ENUM ('bassa', 'media', 'alta', 'critica');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE tipo_asset AS ENUM ('hardware', 'software', 'infrastruttura', 'rete', 'dato', 'altro');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- ----------------------------------------------------------------
-- TABELLA: organizzazione
-- Contiene i dati anagrafici dell'azienda/ente che rientra
-- nell'ambito applicativo della Direttiva NIS2.
-- ----------------------------------------------------------------
CREATE TABLE organizzazione (
    id              SERIAL          PRIMARY KEY,
    nome            VARCHAR(200)    NOT NULL,
    codice_fiscale  VARCHAR(16)     UNIQUE,
    settore         VARCHAR(100),        -- es. "Servizi digitali", "Energia", "Sanità"
    dimensione      VARCHAR(50),         -- "piccola", "media", "grande"
    inserita_il     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    aggiornata_il   TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE organizzazione IS 'Anagrafica delle organizzazioni soggette alla Direttiva NIS2';


-- ----------------------------------------------------------------
-- TABELLA: responsabile
-- Persone fisiche che hanno una responsabilità formale
-- su uno o più asset o servizi aziendali.
-- ----------------------------------------------------------------
CREATE TABLE responsabile (
    id          SERIAL          PRIMARY KEY,
    nome        VARCHAR(100)    NOT NULL,
    cognome     VARCHAR(100)    NOT NULL,
    ruolo       VARCHAR(100)    NOT NULL,    -- es. "CISO", "Responsabile IT", "DPO"
    email       VARCHAR(150)    NOT NULL UNIQUE,
    telefono    VARCHAR(30),
    org_id      INTEGER         NOT NULL REFERENCES organizzazione(id) ON DELETE CASCADE,
    attivo      BOOLEAN         NOT NULL DEFAULT TRUE,
    inserito_il TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE responsabile IS 'Persone fisiche responsabili di asset o servizi aziendali';


-- ----------------------------------------------------------------
-- TABELLA: asset
-- Rappresenta gli asset tecnologici dell'organizzazione:
-- server, apparati di rete, software, ecc.
--
-- Il campo valido_al serve per il versioning temporale:
--   - NULL  = record attualmente in uso (versione corrente)
--   - data  = record storico, superato da una versione più recente
-- ----------------------------------------------------------------
CREATE TABLE asset (
    id                  SERIAL              PRIMARY KEY,
    nome                VARCHAR(200)        NOT NULL,
    descrizione         TEXT,
    tipo                tipo_asset          NOT NULL,
    criticita           livello_criticita   NOT NULL,
    indirizzo_ip        VARCHAR(45),         -- supporta sia IPv4 che IPv6
    sistema_operativo   VARCHAR(100),
    versione            VARCHAR(50),
    localizzazione      VARCHAR(200),        -- datacenter, sede fisica, cloud region...
    organizzazione_id   INTEGER             NOT NULL REFERENCES organizzazione(id) ON DELETE CASCADE,
    valido_dal          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valido_al           TIMESTAMP,           -- NULL = corrente; valorizzato = versione storica
    note                TEXT,
    CONSTRAINT chk_validita CHECK (valido_al IS NULL OR valido_al > valido_dal)
);

COMMENT ON TABLE asset IS 'Asset tecnologici censiti. Il campo valido_al gestisce il versioning temporale.';


-- ----------------------------------------------------------------
-- TABELLA: asset_storico
-- Archivio delle versioni precedenti degli asset.
-- Questa tabella viene popolata in automatico dal trigger
-- trg_asset_versioning ogni volta che si aggiorna un asset.
--
-- Non uso FK su asset_id di proposito: così anche se l'asset
-- venisse cancellato, lo storico rimane consultabile.
-- ----------------------------------------------------------------
CREATE TABLE asset_storico (
    id_storico          SERIAL              PRIMARY KEY,
    asset_id            INTEGER             NOT NULL,    -- collegamento logico (senza FK intenzionale)
    nome                VARCHAR(200)        NOT NULL,
    descrizione         TEXT,
    tipo                tipo_asset          NOT NULL,
    criticita           livello_criticita   NOT NULL,
    indirizzo_ip        VARCHAR(45),
    sistema_operativo   VARCHAR(100),
    versione            VARCHAR(50),
    localizzazione      VARCHAR(200),
    organizzazione_id   INTEGER             NOT NULL,
    valido_dal          TIMESTAMP           NOT NULL,
    valido_al           TIMESTAMP           NOT NULL,
    modificato_il       TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivazione         TEXT                           -- es. "aggiornamento versione OS"
);

COMMENT ON TABLE asset_storico IS 'Storico versioni asset. Popolato automaticamente dal trigger trg_asset_versioning.';


-- ----------------------------------------------------------------
-- TABELLA: servizio
-- Servizi digitali erogati dall'organizzazione.
-- Anche qui uso valido_al per gestire lo storico del servizio.
-- ----------------------------------------------------------------
CREATE TABLE servizio (
    id                  SERIAL              PRIMARY KEY,
    nome                VARCHAR(200)        NOT NULL,
    descrizione         TEXT,
    criticita           livello_criticita   NOT NULL,
    sla_ore             INTEGER,             -- tempo massimo di ripristino in ore
    url                 VARCHAR(300),
    organizzazione_id   INTEGER             NOT NULL REFERENCES organizzazione(id) ON DELETE CASCADE,
    valido_dal          TIMESTAMP           NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valido_al           TIMESTAMP,
    note                TEXT
);

COMMENT ON TABLE servizio IS 'Servizi digitali erogati. Collegati ad asset e fornitori tramite tabelle di associazione.';


-- ----------------------------------------------------------------
-- TABELLA: fornitore
-- Terze parti e fornitori esterni che fanno parte della
-- supply chain dell'organizzazione (rilevante NIS2 Art. 21).
-- ----------------------------------------------------------------
CREATE TABLE fornitore (
    id              SERIAL          PRIMARY KEY,
    nome            VARCHAR(200)    NOT NULL,
    paese           VARCHAR(100),
    tipo_servizio   VARCHAR(200)    NOT NULL,    -- es. "Hosting Cloud", "Manutenzione HW"
    contatto_nome   VARCHAR(150),
    contatto_email  VARCHAR(150),
    contatto_tel    VARCHAR(30),
    certificazioni  TEXT,                        -- es. "ISO 27001, SOC 2"
    note            TEXT,
    inserito_il     TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE fornitore IS 'Fornitori e terze parti rilevanti per la supply chain NIS2';


-- ----------------------------------------------------------------
-- TABELLA: servizio_asset  (relazione N:M)
-- Collega i servizi agli asset che li supportano.
-- Il campo "ruolo" specifica se l'asset è primario, di backup
-- o semplicemente una dipendenza del servizio.
-- ----------------------------------------------------------------
CREATE TABLE servizio_asset (
    servizio_id     INTEGER     NOT NULL REFERENCES servizio(id) ON DELETE CASCADE,
    asset_id        INTEGER     NOT NULL REFERENCES asset(id)    ON DELETE CASCADE,
    ruolo           VARCHAR(100),    -- "primario", "backup", "dipendenza"
    inserito_il     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (servizio_id, asset_id)
);

COMMENT ON TABLE servizio_asset IS 'Tabella di associazione N:M tra servizi e asset che li supportano';


-- ----------------------------------------------------------------
-- TABELLA: servizio_fornitore  (relazione N:M)
-- Collega i servizi ai rispettivi fornitori esterni.
-- Traccia anche la scadenza del contratto, utile per i controlli
-- sulla supply chain richiesti dalla NIS2.
-- ----------------------------------------------------------------
CREATE TABLE servizio_fornitore (
    servizio_id         INTEGER     NOT NULL REFERENCES servizio(id)   ON DELETE CASCADE,
    fornitore_id        INTEGER     NOT NULL REFERENCES fornitore(id)  ON DELETE CASCADE,
    tipo_dipendenza     VARCHAR(100),    -- "infrastrutturale", "applicativa", "manutenzione"
    contratto_scadenza  DATE,
    inserito_il         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (servizio_id, fornitore_id)
);

COMMENT ON TABLE servizio_fornitore IS 'Tabella di associazione N:M tra servizi e fornitori (dipendenze supply chain)';


-- ----------------------------------------------------------------
-- TABELLA: responsabilita
-- Associa un responsabile a un servizio oppure a un asset.
-- Ho usato un approccio "polimorfismo leggero": invece di avere
-- due tabelle separate (una per servizi e una per asset),
-- uso un campo tipo_entita che distingue il contesto.
-- Non è la soluzione più elegante in assoluto ma è semplice
-- da leggere e da interrogare.
-- ----------------------------------------------------------------
CREATE TABLE responsabilita (
    id              SERIAL          PRIMARY KEY,
    tipo_entita     VARCHAR(20)     NOT NULL CHECK (tipo_entita IN ('servizio', 'asset')),
    entita_id       INTEGER         NOT NULL,
    responsabile_id INTEGER         NOT NULL REFERENCES responsabile(id) ON DELETE CASCADE,
    tipo_ruolo      VARCHAR(100)    NOT NULL DEFAULT 'responsabile',  -- "responsabile", "referente", "backup"
    data_inizio     DATE            NOT NULL DEFAULT CURRENT_DATE,
    data_fine       DATE,
    note            TEXT,
    CONSTRAINT chk_date_responsabilita CHECK (data_fine IS NULL OR data_fine >= data_inizio)
);

COMMENT ON TABLE responsabilita IS 'Attribuzione responsabilità su servizi o asset. tipo_entita distingue il contesto.';
