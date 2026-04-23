# Data Dictionary – NIS2 Asset Database
**Autore:** Chiarello Manuel Giuseppe – Mat. 0312300543

Questo documento descrive nel dettaglio tutte le tabelle del database, i campi che le compongono e le scelte progettuali che ho fatto durante la progettazione. L'obiettivo è che chiunque legga questo file possa capire la struttura del database senza dover aprire il codice SQL.

---

## Tabella: `organizzazione`

Punto di partenza dell'intero schema. Ogni record rappresenta un'azienda o ente che rientra nell'ambito della Direttiva NIS2. Tutte le altre tabelle (asset, servizi, responsabili) sono collegate a questa tramite chiave esterna.

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| id | SERIAL | PK | Identificatore numerico generato automaticamente |
| nome | VARCHAR(200) | NOT NULL | Ragione sociale dell'azienda o dell'ente |
| codice_fiscale | VARCHAR(16) | UNIQUE | Codice fiscale o P.IVA (campo opzionale ma univoco se presente) |
| settore | VARCHAR(100) | — | Settore di appartenenza secondo NIS2 (es. "Servizi digitali", "Energia") |
| dimensione | VARCHAR(50) | — | Dimensione aziendale: "piccola", "media" o "grande" |
| inserita_il | TIMESTAMP | NOT NULL | Data e ora in cui il record è stato creato |
| aggiornata_il | TIMESTAMP | NOT NULL | Aggiornato automaticamente dal trigger `trg_org_updated_at` ad ogni modifica |

---

## Tabella: `asset`

La tabella centrale del sistema. Censisce tutti gli asset tecnologici dell'organizzazione: server, apparati di rete, software, infrastrutture fisiche e logiche.

Ho introdotto il meccanismo di **versioning temporale** tramite i campi `valido_dal` e `valido_al`. Quando un asset viene modificato, la versione precedente finisce nella tabella `asset_storico` e il record corrente ha `valido_al = NULL`. Questo permette di sapere sempre qual è lo stato attuale e di ricostruire la storia delle modifiche.

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| id | SERIAL | PK | Identificatore numerico dell'asset |
| nome | VARCHAR(200) | NOT NULL | Nome descrittivo (es. "Server Database Primario") |
| descrizione | TEXT | — | Testo libero per descrivere meglio l'asset |
| tipo | tipo_asset | NOT NULL | ENUM: hardware / software / infrastruttura / rete / dato / altro |
| criticita | livello_criticita | NOT NULL | ENUM: bassa / media / alta / critica |
| indirizzo_ip | VARCHAR(45) | — | Indirizzo IP (supporta sia IPv4 che IPv6) |
| sistema_operativo | VARCHAR(100) | — | Sistema operativo installato |
| versione | VARCHAR(50) | — | Versione del software o del firmware |
| localizzazione | VARCHAR(200) | — | Posizione fisica (es. "Datacenter Milano – Rack A1") o logica (es. "Cloud AWS") |
| organizzazione_id | INTEGER | FK → organizzazione | Azienda a cui appartiene l'asset |
| valido_dal | TIMESTAMP | NOT NULL | Data inizio validità di questa versione del record |
| valido_al | TIMESTAMP | — | Data fine validità – se NULL il record è quello corrente |
| note | TEXT | — | Note aggiuntive, non triggera il versioning se modificato |

---

## Tabella: `asset_storico`

Archivio automatico delle versioni precedenti degli asset. Non viene mai popolata manualmente: è il trigger `trg_asset_versioning` che ci scrive ogni volta che un asset viene modificato su un campo sostanziale.

Ho scelto di **non usare una FK** su `asset_id` verso la tabella `asset`. Questo è voluto: se un asset venisse cancellato, voglio che il suo storico rimanga consultabile per fini di audit.

| Campo | Tipo | Descrizione |
|---|---|---|
| id_storico | SERIAL (PK) | Identificatore univoco del record storico |
| asset_id | INTEGER | Riferimento logico all'asset originale (no FK intenzionale) |
| nome | VARCHAR(200) | Nome dell'asset al momento della modifica |
| descrizione | TEXT | Descrizione al momento della modifica |
| tipo | tipo_asset | Tipo al momento della modifica |
| criticita | livello_criticita | Criticità al momento della modifica |
| indirizzo_ip | VARCHAR(45) | IP al momento della modifica |
| sistema_operativo | VARCHAR(100) | OS al momento della modifica |
| versione | VARCHAR(50) | Versione al momento della modifica |
| localizzazione | VARCHAR(200) | Localizzazione al momento della modifica |
| organizzazione_id | INTEGER | Organizzazione al momento della modifica |
| valido_dal | TIMESTAMP | Inizio del periodo di validità di quella versione |
| valido_al | TIMESTAMP | Fine del periodo (quando è stata sostituita dalla versione nuova) |
| modificato_il | TIMESTAMP | Timestamp esatto dell'archiviazione nel storico |
| motivazione | TEXT | Motivo della modifica (campo opzionale, da compilare a mano) |

---

## Tabella: `servizio`

Raccoglie i servizi digitali erogati dall'organizzazione verso clienti interni o esterni. Come per gli asset, anche i servizi usano `valido_dal` / `valido_al` per il versioning.

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| id | SERIAL | PK | Identificatore del servizio |
| nome | VARCHAR(200) | NOT NULL | Nome del servizio (es. "Portale Clienti Online") |
| descrizione | TEXT | — | Descrizione funzionale del servizio |
| criticita | livello_criticita | NOT NULL | Livello di criticità secondo la classificazione NIS2 |
| sla_ore | INTEGER | — | RTO (Recovery Time Objective) in ore – es. 4 = massimo 4h di downtime tollerato |
| url | VARCHAR(300) | — | URL del servizio, se accessibile via web |
| organizzazione_id | INTEGER | FK → organizzazione | Organizzazione che eroga il servizio |
| valido_dal | TIMESTAMP | NOT NULL | Inizio validità del record |
| valido_al | TIMESTAMP | — | Fine validità – NULL = servizio ancora attivo |
| note | TEXT | — | Note operative |

---

## Tabella: `fornitore`

Censisce i fornitori e le terze parti che supportano i servizi dell'organizzazione. È una delle tabelle richieste esplicitamente dalla NIS2 per la gestione della supply chain (Art. 21).

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| id | SERIAL | PK | Identificatore del fornitore |
| nome | VARCHAR(200) | NOT NULL | Ragione sociale del fornitore |
| paese | VARCHAR(100) | — | Paese di residenza o sede legale |
| tipo_servizio | VARCHAR(200) | NOT NULL | Tipo di servizio fornito (es. "Hosting Cloud", "Manutenzione firewall") |
| contatto_nome | VARCHAR(150) | — | Nome del referente tecnico o commerciale |
| contatto_email | VARCHAR(150) | — | Email del referente |
| contatto_tel | VARCHAR(30) | — | Telefono del referente |
| certificazioni | TEXT | — | Elenco certificazioni di sicurezza (es. "ISO 27001, SOC 2 Type II") |
| note | TEXT | — | Note aggiuntive |
| inserito_il | TIMESTAMP | NOT NULL | Data di registrazione del fornitore |

---

## Tabella: `responsabile`

Contiene le persone fisiche che hanno responsabilità formale su asset o servizi. Il campo `attivo` permette di "disattivare" un responsabile senza cancellarlo dal database, preservando così lo storico delle assegnazioni.

| Campo | Tipo | Vincoli | Descrizione |
|---|---|---|---|
| id | SERIAL | PK | Identificatore del responsabile |
| nome | VARCHAR(100) | NOT NULL | Nome di battesimo |
| cognome | VARCHAR(100) | NOT NULL | Cognome |
| ruolo | VARCHAR(100) | NOT NULL | Ruolo aziendale (es. "CISO", "DPO", "Responsabile IT") |
| email | VARCHAR(150) | UNIQUE, NOT NULL | Email aziendale – usata anche come identificativo univoco |
| telefono | VARCHAR(30) | — | Recapito telefonico diretto |
| org_id | INTEGER | FK → organizzazione | Organizzazione di appartenenza |
| attivo | BOOLEAN | DEFAULT TRUE | Se FALSE il responsabile non compare più nelle viste attive |
| inserito_il | TIMESTAMP | NOT NULL | Data di registrazione nel sistema |

---

## Tabella: `servizio_asset` (relazione N:M)

Tabella ponte tra servizi e asset. Uno stesso asset può supportare più servizi (es. il firewall è usato da tutti), e un servizio può dipendere da più asset. Il campo `ruolo` chiarisce la natura della dipendenza.

| Campo | Tipo | Descrizione |
|---|---|---|
| servizio_id | INTEGER (PK, FK) | Riferimento al servizio |
| asset_id | INTEGER (PK, FK) | Riferimento all'asset |
| ruolo | VARCHAR(100) | "primario" = asset fondamentale, "backup" = alternativa, "dipendenza" = necessario ma non principale |
| inserito_il | TIMESTAMP | Data di creazione del collegamento |

La chiave primaria è composta: **(servizio_id, asset_id)** — non possono esserci duplicati della stessa coppia.

---

## Tabella: `servizio_fornitore` (relazione N:M)

Tabella ponte tra servizi e fornitori. Traccia anche la data di scadenza del contratto, che viene monitorata automaticamente dalla vista `vista_dipendenze_fornitori`.

| Campo | Tipo | Descrizione |
|---|---|---|
| servizio_id | INTEGER (PK, FK) | Riferimento al servizio |
| fornitore_id | INTEGER (PK, FK) | Riferimento al fornitore |
| tipo_dipendenza | VARCHAR(100) | "infrastrutturale", "applicativa" o "manutenzione" |
| contratto_scadenza | DATE | Scadenza del contratto con il fornitore |
| inserito_il | TIMESTAMP | Data di creazione del collegamento |

La chiave primaria è composta: **(servizio_id, fornitore_id)**.

---

## Tabella: `responsabilita`

Assegna un responsabile a un servizio oppure a un asset. Invece di avere due tabelle separate (una per servizi e una per asset), ho usato un approccio con `tipo_entita` + `entita_id`: il campo `tipo_entita` vale `'servizio'` o `'asset'` e `entita_id` contiene l'id corrispondente.

Non è il pattern più rigido dal punto di vista dell'integrità referenziale (non c'è FK vera verso entrambe le tabelle), ma è semplice e funziona bene per questo caso d'uso.

| Campo | Tipo | Descrizione |
|---|---|---|
| id | SERIAL (PK) | Identificatore dell'assegnazione |
| tipo_entita | VARCHAR(20) | CHECK: solo 'servizio' o 'asset' |
| entita_id | INTEGER | ID del servizio o dell'asset a cui si riferisce |
| responsabile_id | INTEGER (FK) | Chi è responsabile |
| tipo_ruolo | VARCHAR(100) | "responsabile" (principale), "referente" (di supporto), "backup" |
| data_inizio | DATE | Da quando è valida l'assegnazione |
| data_fine | DATE | Fine dell'incarico – NULL = ancora in corso |
| note | TEXT | Note sull'assegnazione |

---

## Tipi ENUM definiti

Ho definito due tipi personalizzati per rendere il database più robusto e autodescrittivo:

| ENUM | Valori possibili |
|---|---|
| `livello_criticita` | `bassa`, `media`, `alta`, `critica` |
| `tipo_asset` | `hardware`, `software`, `infrastruttura`, `rete`, `dato`, `altro` |

Questi ENUM impediscono l'inserimento di valori non previsti e rendono le query più leggibili rispetto a un semplice VARCHAR.
