-- ================================================================
-- FILE: 05_insert_test.sql
-- DESCRIZIONE: Dati di test per simulare un'azienda reale.
--   Ho scelto "TechSolutions S.r.l." come caso d'uso:
--   una media impresa di servizi digitali con datacenter
--   proprio a Milano e qualche fornitore esterno.
--
--   Questi dati servono a verificare che tutto il sistema
--   funzioni correttamente: trigger, viste, query.
--   Eseguire DOPO 01_schema.sql – 04_views.sql.
-- ================================================================


-- Inserisco l'organizzazione principale
INSERT INTO organizzazione (nome, codice_fiscale, settore, dimensione)
VALUES ('TechSolutions S.r.l.', '12345678901', 'Servizi digitali', 'media');


-- Inserisco i responsabili aziendali
-- Ho scelto ruoli realistici per una PMI del settore IT
INSERT INTO responsabile (nome, cognome, ruolo, email, telefono, org_id) VALUES
    ('Mario',   'Rossi',    'Responsabile IT',           'm.rossi@techsolutions.it',    '+39 02 1234567',  1),
    ('Laura',   'Bianchi',  'CISO',                      'l.bianchi@techsolutions.it',  '+39 02 1234568',  1),
    ('Giorgio', 'Verdi',    'DPO',                       'g.verdi@techsolutions.it',    '+39 02 1234569',  1),
    ('Anna',    'Ferrari',  'Responsabile Compliance',   'a.ferrari@techsolutions.it',  '+39 02 1234570',  1),
    ('Luca',    'Martini',  'Amministratore di Sistema', 'l.martini@techsolutions.it',  '+39 02 1234571',  1);


-- Inserisco gli asset tecnologici dell'azienda
-- Ho incluso hardware, software e infrastruttura di rete
-- per coprire i diversi tipi previsti dall'ENUM tipo_asset
INSERT INTO asset (nome, descrizione, tipo, criticita, indirizzo_ip, sistema_operativo, versione, localizzazione, organizzazione_id) VALUES
    ('Server Database Primario',
        'PostgreSQL principale, contiene i dati dei clienti',
        'hardware', 'critica', '10.0.1.10', 'Ubuntu Server 22.04 LTS', 'PostgreSQL 15.3',
        'Datacenter Milano – Rack A1', 1),

    ('Web Application Server',
        'Server applicativo che espone il frontend ai clienti',
        'hardware', 'alta', '10.0.1.20', 'Ubuntu Server 22.04 LTS', 'Nginx 1.24',
        'Datacenter Milano – Rack A2', 1),

    ('Firewall Perimetrale',
        'Fortinet FortiGate 200F, protezione perimetro di rete',
        'hardware', 'critica', '10.0.0.1', 'FortiOS 7.4', '7.4.2',
        'Datacenter Milano – Rack B1', 1),

    ('Piattaforma CRM',
        'Software per la gestione delle relazioni con i clienti',
        'software', 'alta', NULL, 'Windows Server 2022', 'CRM v3.5',
        'Server virtuale – vSphere', 1),

    ('Sistema di Backup',
        'Veeam Backup & Replication per la copia dei dati critici',
        'infrastruttura', 'alta', '10.0.1.50', 'Windows Server 2022', 'Veeam 12',
        'Datacenter Milano – Rack C1', 1),

    ('Switch Core',
        'Cisco Catalyst 9300, backbone della rete aziendale',
        'rete', 'critica', '10.0.0.2', 'Cisco IOS XE 17.9', '17.9.3',
        'Datacenter Milano – Rack B2', 1),

    ('Storage NAS',
        'NetApp FAS2750 per la conservazione dei documenti aziendali',
        'hardware', 'media', '10.0.1.60', 'ONTAP 9.12', '9.12.1',
        'Datacenter Milano – Rack C2', 1),

    ('Workstation SOC',
        'Postazione del Security Operations Center, usata per l''analisi degli eventi di sicurezza',
        'hardware', 'alta', '10.0.2.10', 'Windows 11 Enterprise', '22H2',
        'Sede legale – Piano 2', 1);


-- Inserisco i servizi digitali erogati dall'azienda
-- SLA espresso in ore di ripristino massimo (RTO)
INSERT INTO servizio (nome, descrizione, criticita, sla_ore, url, organizzazione_id) VALUES
    ('Portale Clienti Online',
        'Gestione ticket, contratti e assistenza in self-service',
        'critica', 4, 'https://clienti.techsolutions.it', 1),

    ('Piattaforma SaaS Fatturazione',
        'Emissione e gestione delle fatture elettroniche verso PA e privati',
        'critica', 8, 'https://fatture.techsolutions.it', 1),

    ('Servizio VPN Aziendale',
        'Accesso remoto sicuro per i dipendenti in smart working',
        'alta', 12, NULL, 1),

    ('Monitoraggio Infrastruttura',
        'Monitoring real-time su tutti gli asset e servizi aziendali',
        'alta', 4, 'https://monitor.techsolutions.it', 1),

    ('Backup e Disaster Recovery',
        'Backup giornaliero con piano di ripristino – RTO target 8 ore',
        'alta', 24, NULL, 1);


-- Collego ogni servizio agli asset che lo supportano
-- Il campo "ruolo" chiarisce se l'asset è primario, di backup
-- o semplicemente una dipendenza della catena
INSERT INTO servizio_asset (servizio_id, asset_id, ruolo) VALUES
    (1, 1, 'primario'),     -- Portale Clienti → Server Database
    (1, 2, 'primario'),     -- Portale Clienti → Web App Server
    (1, 3, 'dipendenza'),   -- Portale Clienti → Firewall
    (1, 6, 'dipendenza'),   -- Portale Clienti → Switch Core
    (2, 1, 'primario'),     -- Fatturazione → Server Database
    (2, 4, 'primario'),     -- Fatturazione → CRM
    (2, 3, 'dipendenza'),   -- Fatturazione → Firewall
    (3, 3, 'primario'),     -- VPN → Firewall (è l'asset cardine per la VPN)
    (3, 6, 'dipendenza'),   -- VPN → Switch Core
    (4, 2, 'dipendenza'),   -- Monitoring → Web App Server
    (4, 6, 'dipendenza'),   -- Monitoring → Switch Core
    (5, 5, 'primario'),     -- Backup → Sistema di Backup
    (5, 7, 'primario');     -- Backup → Storage NAS


-- Inserisco i fornitori esterni
-- Le certificazioni sono quelle che ho verificato essere
-- rilevanti per la valutazione NIS2 della supply chain
INSERT INTO fornitore (nome, paese, tipo_servizio, contatto_nome, contatto_email, contatto_tel, certificazioni) VALUES
    ('CloudProvider S.p.A.',  'Italia',       'Hosting Cloud e colocation datacenter',
        'Stefano Neri',  'support@cloudprovider.it',    '+39 02 9876543',  'ISO 27001, ISO 22301, SOC 2 Type II'),

    ('SecureNet S.r.l.',      'Italia',       'Manutenzione firewall e sicurezza perimetrale',
        'Giulia Conti',  'ops@securenet.it',             '+39 02 8765432',  'ISO 27001, Fortinet NSE7'),

    ('BackupCloud AG',        'Germania',     'Backup offsite e disaster recovery',
        'Hans Mueller',  'support@backupcloud.de',       '+49 89 1234567',  'ISO 27001, SOC 2'),

    ('TelecomFibra S.p.A.',   'Italia',       'Connettività Internet e linee dedicate',
        'Roberto Sala',  'enterprise@telecomfibra.it',  '+39 02 7654321',  'ISO 9001'),

    ('SoftwareHouse Ltd.',    'Regno Unito',  'Sviluppo e manutenzione CRM',
        'Emily Brown',   'support@softwarehouse.co.uk', '+44 20 1234567',  'ISO 27001, Cyber Essentials Plus');


-- Collego i servizi ai rispettivi fornitori
-- Nota: il contratto con SoftwareHouse è già scaduto (2025-12-31)
-- e verrà segnalato dalla vista vista_dipendenze_fornitori
INSERT INTO servizio_fornitore (servizio_id, fornitore_id, tipo_dipendenza, contratto_scadenza) VALUES
    (1, 1, 'infrastrutturale',  '2026-12-31'),  -- Portale Clienti → CloudProvider
    (1, 4, 'infrastrutturale',  '2026-06-30'),  -- Portale Clienti → TelecomFibra
    (2, 1, 'infrastrutturale',  '2026-12-31'),  -- Fatturazione → CloudProvider
    (2, 5, 'applicativa',       '2025-12-31'),  -- Fatturazione → SoftwareHouse (SCADUTO!)
    (3, 2, 'manutenzione',      '2027-03-31'),  -- VPN → SecureNet
    (5, 3, 'infrastrutturale',  '2026-09-30');  -- Backup → BackupCloud


-- Attribuzione delle responsabilità sui servizi e sugli asset
-- Ogni servizio critico ha almeno un responsabile e un referente
INSERT INTO responsabilita (tipo_entita, entita_id, responsabile_id, tipo_ruolo, data_inizio) VALUES
    ('servizio', 1, 1, 'responsabile', '2024-01-15'),  -- Portale Clienti → Mario Rossi
    ('servizio', 1, 2, 'referente',    '2024-01-15'),  -- Portale Clienti → Laura Bianchi (CISO)
    ('servizio', 2, 1, 'responsabile', '2024-01-15'),  -- Fatturazione → Mario Rossi
    ('servizio', 2, 4, 'referente',    '2024-01-15'),  -- Fatturazione → Anna Ferrari (Compliance)
    ('servizio', 3, 5, 'responsabile', '2024-03-01'),  -- VPN → Luca Martini
    ('servizio', 3, 2, 'referente',    '2024-03-01'),  -- VPN → Laura Bianchi
    ('servizio', 4, 5, 'responsabile', '2024-01-15'),  -- Monitoring → Luca Martini
    ('servizio', 5, 5, 'responsabile', '2024-01-15'),  -- Backup → Luca Martini
    ('asset',    1, 5, 'responsabile', '2024-01-15'),  -- Server DB → Luca Martini
    ('asset',    3, 2, 'responsabile', '2024-01-15'),  -- Firewall → Laura Bianchi (CISO)
    ('asset',    6, 5, 'responsabile', '2024-01-15');  -- Switch Core → Luca Martini
