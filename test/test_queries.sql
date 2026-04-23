-- ================================================================
-- FILE: test_queries.sql
-- DESCRIZIONE: Script di validazione del database.
--   Verifica che i dati inseriti siano corretti, che i trigger
--   funzionino e che le viste restituiscano risultati sensati.
--
--   Eseguire DOPO 05_insert_test.sql.
--   Ogni test stampa un messaggio OK o un errore specifico.
-- ================================================================


-- Test 1: Controllo che ci siano asset censiti nel database
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM asset
    WHERE valido_al IS NULL;

    ASSERT v_count > 0, 'ERRORE: nessun asset trovato nel database';
    RAISE NOTICE 'Test 1 OK – Asset correnti trovati: %', v_count;
END $$;


-- Test 2: Verifica che esistano asset con criticità "critica"
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM asset
    WHERE criticita = 'critica'
      AND valido_al IS NULL;

    ASSERT v_count > 0, 'ERRORE: nessun asset critico trovato';
    RAISE NOTICE 'Test 2 OK – Asset critici: %', v_count;
END $$;


-- Test 3: Ogni servizio critico deve avere almeno un responsabile
-- (requisito minimo per la conformità NIS2)
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM servizio s
    WHERE s.criticita = 'critica'
      AND s.valido_al IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM responsabilita r
          WHERE r.entita_id   = s.id
            AND r.tipo_entita = 'servizio'
            AND r.data_fine IS NULL
      );

    ASSERT v_count = 0,
        'ERRORE: trovati ' || v_count || ' servizi critici senza responsabile assegnato';
    RAISE NOTICE 'Test 3 OK – Tutti i servizi critici hanno un responsabile';
END $$;


-- Test 4: Integrità referenziale nella tabella servizio_asset
-- Non devono esserci righe con asset_id che puntano a nulla
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM servizio_asset sa
    LEFT JOIN asset a ON a.id = sa.asset_id
    WHERE a.id IS NULL;

    ASSERT v_count = 0,
        'ERRORE: trovati ' || v_count || ' riferimenti orfani in servizio_asset';
    RAISE NOTICE 'Test 4 OK – Nessun riferimento orfano in servizio_asset';
END $$;


-- Test 5: La vista report_acn deve restituire almeno una riga
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM report_acn;

    ASSERT v_count > 0, 'ERRORE: la vista report_acn non restituisce dati';
    RAISE NOTICE 'Test 5 OK – report_acn restituisce % righe', v_count;
END $$;


-- Test 6: Controllo contratti fornitori scaduti
-- Questo non è un errore bloccante, ma emette un WARNING
-- così l'operatore sa che deve intervenire
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM servizio_fornitore
    WHERE contratto_scadenza < CURRENT_DATE;

    IF v_count > 0 THEN
        RAISE WARNING 'ATTENZIONE: % contratti fornitore risultano scaduti – verificare', v_count;
    ELSE
        RAISE NOTICE 'Test 6 OK – Nessun contratto fornitore scaduto';
    END IF;
END $$;


-- Test 7: Verifica del trigger di versioning
-- Modifica un campo significativo su un asset e controlla
-- che la versione precedente venga salvata in asset_storico
DO $$
DECLARE
    v_storico_prima  INTEGER;
    v_storico_dopo   INTEGER;
BEGIN
    -- Quante versioni storiche ci sono prima della modifica?
    SELECT COUNT(*) INTO v_storico_prima
    FROM asset_storico
    WHERE asset_id = 1;

    -- Modifico la versione del software (campo sostanziale → trigger si attiva)
    UPDATE asset
    SET versione = '15.4-test',
        note     = 'Modifica temporanea per test del trigger'
    WHERE id = 1;

    -- Quante versioni storiche ci sono dopo la modifica?
    SELECT COUNT(*) INTO v_storico_dopo
    FROM asset_storico
    WHERE asset_id = 1;

    ASSERT v_storico_dopo = v_storico_prima + 1,
        'ERRORE: il trigger trg_asset_versioning non ha salvato la versione precedente';
    RAISE NOTICE 'Test 7 OK – Trigger versioning funzionante (storico: % → %)',
        v_storico_prima, v_storico_dopo;

    -- Ripristino il valore originale
    UPDATE asset
    SET versione = 'PostgreSQL 15.3',
        note     = NULL
    WHERE id = 1;

    RAISE NOTICE 'Test 7 – Valore ripristinato correttamente';
END $$;


-- Messaggio finale di riepilogo
DO $$
BEGIN
    RAISE NOTICE '=== Tutti i test completati con successo ===';
END $$;
