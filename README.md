# NIS2 Asset Database – TechSolutions S.r.l.

**Autore:** Chiarello Manuel Giuseppe – Mat. 0312300543  
**Corso:** Informatica per le Aziende Digitali (L-31)  
**Università:** Telematica Pegaso

---

## Di cosa si tratta

Questo repository contiene il progetto realizzato per il Project Work del corso. L'obiettivo era progettare una base dati relazionale per gestire asset tecnologici, servizi erogati, fornitori e responsabilità di un'azienda soggetta alla Direttiva NIS2.

Il caso d'uso scelto è quello di **TechSolutions S.r.l.**, una media impresa di servizi digitali con sede a Milano, che prima del progetto gestiva tutte queste informazioni in modo frammentato tra Excel, email e documenti Word sparsi. L'idea era di centralizzare tutto in un database PostgreSQL interrogabile e pronto per generare automaticamente i report richiesti dall'ACN (Agenzia per la Cybersicurezza Nazionale).

---

## Struttura del repository

```
nis2_db/
├── README.md                    ← questo file
├── data_dictionary.md           ← descrizione dettagliata di ogni tabella
│
├── 01_schema.sql                ← creazione di tabelle, vincoli ed ENUM
├── 02_indexes.sql               ← indici per velocizzare le query principali
├── 03_triggers.sql              ← trigger versioning asset e stored procedure
├── 04_views.sql                 ← viste per i report ACN
├── 05_insert_test.sql           ← dati di esempio per TechSolutions S.r.l.
├── 06_queries_acn.sql           ← query per le sezioni del profilo ACN
└── test_queries.sql             ← script di validazione automatica
```

---

## Tecnologie usate

- **Database:** PostgreSQL 15+
- **Modellazione ER:** draw.io (diagramma allegato alla documentazione)
- **Client SQL:** DBeaver (per sviluppo e test delle query)
- **Versionamento:** Git / GitHub

---

## Come eseguire il progetto

### Cosa serve prima di iniziare
- PostgreSQL 15 o versione più recente, installato e avviato
- Accesso a `psql` da terminale (o in alternativa DBeaver/pgAdmin)

### Creazione del database da zero

Gli script vanno eseguiti **nell'ordine indicato**, perché ognuno dipende dal precedente:

```bash
# Crea il database
psql -U postgres -c "CREATE DATABASE nis2_db;"

# Esegui gli script in sequenza
psql -U postgres -d nis2_db -f 01_schema.sql
psql -U postgres -d nis2_db -f 02_indexes.sql
psql -U postgres -d nis2_db -f 03_triggers.sql
psql -U postgres -d nis2_db -f 04_views.sql

# Carica i dati di test
psql -U postgres -d nis2_db -f 05_insert_test.sql
```

> **Nota:** se si vuole ricominciare da capo, basta rieseguire `01_schema.sql` che contiene i `DROP TABLE IF EXISTS CASCADE` all'inizio.

### Esecuzione delle query ACN

```bash
psql -U postgres -d nis2_db -f 06_queries_acn.sql
```

Oppure, se si vuole eseguire una sola query, aprire il file con DBeaver e selezionare solo il blocco che interessa.

### Esportazione CSV per i profili ACN

```sql
-- Report completo (richiede permessi di scrittura sul filesystem del server)
COPY report_acn TO '/tmp/report_acn.csv' CSV HEADER;

-- Solo gli asset critici
COPY (SELECT * FROM vista_asset_critici) TO '/tmp/asset_critici.csv' CSV HEADER;

-- Dipendenze fornitori con stato contratti
COPY (SELECT * FROM vista_dipendenze_fornitori) TO '/tmp/fornitori.csv' CSV HEADER;
```

### Validazione del database

```bash
psql -U postgres -d nis2_db -f test_queries.sql
```

Lo script esegue 7 test automatici e stampa un messaggio OK per ognuno. Se qualcosa non va, mostra un errore descrittivo con il numero di record problematici.

---

## Struttura del database in breve

Il database è composto da 9 tabelle in 3NF. Ecco una panoramica rapida:

| Tabella | Cosa contiene |
|---|---|
| `organizzazione` | L'azienda soggetta agli obblighi NIS2 |
| `asset` | Tutti gli asset tecnologici censiti (server, reti, software...) |
| `asset_storico` | Storico automatico delle versioni precedenti degli asset |
| `servizio` | Servizi digitali erogati dall'organizzazione |
| `fornitore` | Fornitori e terze parti della supply chain |
| `responsabile` | Persone fisiche con ruoli di responsabilità |
| `servizio_asset` | Collegamento N:M tra servizi e asset che li supportano |
| `servizio_fornitore` | Collegamento N:M tra servizi e i loro fornitori |
| `responsabilita` | Chi è responsabile di cosa (servizi o asset) |

Le relazioni N:M tra servizi, asset e fornitori sono gestite tramite tabelle ponte (`servizio_asset` e `servizio_fornitore`), in modo da mantenere lo schema normalizzato.

---

## Funzionalità principali

### Versioning storico degli asset
Ogni volta che un asset viene modificato su un campo rilevante (nome, criticità, IP, OS, versione, localizzazione), il trigger `trg_asset_versioning` salva automaticamente la versione precedente in `asset_storico`. Questo permette di avere un audit trail completo senza intervento manuale.

### Report ACN pronti all'uso
La vista `report_acn` aggrega in un'unica query tutte le informazioni richieste dal profilo ACN: organizzazione, servizi, asset, fornitori e responsabili. Si esporta direttamente in CSV.

### Monitoraggio contratti fornitori
La vista `vista_dipendenze_fornitori` include una colonna `stato_contratto` che segnala automaticamente se un contratto è scaduto o in scadenza entro 90 giorni.

---

## Contesto normativo

Il progetto è pensato per supportare gli adempimenti previsti dalla **Direttiva NIS2 (UE 2022/2555)**, recepita in Italia con il D.Lgs. 138/2024. In particolare, supporta la compilazione dei profili richiesti dall'**ACN** per la sezione dedicata a:
- Censimento asset rilevanti
- Mappatura servizi essenziali e importanti  
- Gestione della supply chain (Art. 21 NIS2)
- Attribuzione delle responsabilità operative
