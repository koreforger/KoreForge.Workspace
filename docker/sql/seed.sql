-- Streaming Platform Seed Data
-- Kafka performance settings and default operational configuration
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
USE StreamingPlatform;
GO

-- =============================================================================
-- Global + Application-scoped settings for EventReader
-- =============================================================================
MERGE dbo.Settings AS target
USING (VALUES
    -- ── Kafka cluster (Global) ─────────────────────────────────────────────
    (NULL, NULL, 'Kafka:Clusters:Local:BootstrapServers',           'localhost:29092',   'Redpanda broker address for local dev'),
    (NULL, NULL, 'Kafka:SecurityProfiles:None:Mode',                'None',              NULL),

    -- ── EventReader: Kafka consumer profile ───────────────────────────────
    ('EventReader', NULL, 'Kafka:Profiles:Default:Type',                                'Consumer',          NULL),
    ('EventReader', NULL, 'Kafka:Profiles:Default:Cluster',                             'Local',             NULL),
    ('EventReader', NULL, 'Kafka:Profiles:Default:SecurityProfile',                     'None',              NULL),
    ('EventReader', NULL, 'Kafka:Profiles:Default:Topics:0',                            'raw.events',        'Primary raw intake topic'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ConfluentOptions:group.id',           'event-reader',      'Kafka consumer group'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ConfluentOptions:auto.offset.reset',  'earliest',          'Start from earliest when no committed offset exists'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ConfluentOptions:enable.auto.commit', 'true',              'StoreOffset + auto-commit mode'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ConfluentOptions:auto.commit.interval.ms', '1000',         'Commit every 1s; 5s default is too slow at high throughput'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:ConsumerCount',      '8',                 'One consumer per partition (8-partition topic)'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:StartMode',          'Latest',            'Start from latest on normal startup; seek overrides this'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:MaxBatchSize',       '1000',              'Max messages per processing batch'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:MaxBatchWaitMs',     '100',               'CRITICAL: flush batch after 100ms — default 1000ms starves throughput'),
    ('EventReader', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:PipelineMaxDegreeOfParallelism', '128',   'Parallel record processing per batch; tuned for 8-partition topology'),

    -- ── EventReader: pipeline diagnostic stage ─────────────────────────────
    ('EventReader', NULL, 'EventReader:DiagnosticStage',            'FullPipeline',      'Runtime diagnostic mode: FullPipeline/KafkaOnly/DecodeOnly/ClassifyOnly/ParseOnly/RulesOnly/OutputOnly/NullOutput'),
    ('EventReader', NULL, 'EventReader:EnableDlq',                  'false',             'DLQ is optional — disable by default for local dev'),
    ('EventReader', NULL, 'EventReader:DlqTopic',                   'raw.events.dlq',    'DLQ topic name when EnableDlq=true'),

    -- ── EventReader: seek / replay settings ────────────────────────────────
    ('EventReader', NULL, 'EventReader:Seek:Mode',                  'None',              'None / FromOffset / FromTimestamp / Range; overrides StartMode when set'),
    ('EventReader', NULL, 'EventReader:Seek:StartOffsetOrTimestamp', '',                 'Long offset OR ISO 8601 datetime string (e.g. 2026-04-27T10:00:00Z)'),
    ('EventReader', NULL, 'EventReader:Seek:StopOffsetOrTimestamp',  '',                 'Optional stop boundary — leave empty to run indefinitely'),

    -- ── EventReader: output topics ─────────────────────────────────────────
    ('EventReader', NULL, 'EventReader:OutputTopics:FraudCandidate', 'fraud.candidates',  'Topic for EventProcessor curated events'),
    ('EventReader', NULL, 'EventReader:OutputTopics:Audit',          'events.audit',      'Audit topic for all processed events'),
    ('EventReader', NULL, 'EventReader:OutputTopics:Archive',        'events.archive',    'Raw archive topic'),

    -- ── EventProcessor: Kafka consumer profile ────────────────────────────
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:Type',                                'Consumer',          NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:Cluster',                             'Local',             NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:SecurityProfile',                     'None',              NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:Topics:0',                            'fraud.candidates',  'Curated events from EventReader'),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ConfluentOptions:group.id',           'event-processor',   'Kafka consumer group'),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ConfluentOptions:auto.offset.reset',  'earliest',          NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ConfluentOptions:enable.auto.commit', 'true',              NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ConfluentOptions:auto.commit.interval.ms', '1000',         NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:ConsumerCount',      '8',                 'Match partition count'),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:StartMode',          'Latest',            NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:MaxBatchSize',       '1000',              NULL),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:MaxBatchWaitMs',     '100',               'CRITICAL: 100ms not 1000ms'),
    ('EventProcessor', NULL, 'Kafka:Profiles:Default:ExtendedConsumer:PipelineMaxDegreeOfParallelism', '128',   NULL),

    -- ── EventProcessor: session settings ──────────────────────────────────
    ('EventProcessor', NULL, 'EventProcessor:Sessions:IdleTimeoutMinutes',      '30',   'Evict idle sessions after 30 minutes'),
    ('EventProcessor', NULL, 'EventProcessor:Sessions:MaxSessionDurationMinutes','1440', 'Force-close sessions older than 24 hours'),
    ('EventProcessor', NULL, 'EventProcessor:Sessions:MaxSessionCount',          '500000', 'Max in-memory sessions before eviction pressure'),
    ('EventProcessor', NULL, 'EventProcessor:DiagnosticStage',                  'FullPipeline', NULL),
    ('EventProcessor', NULL, 'EventProcessor:EnableDlq',                        'false',  'DLQ optional — off by default'),
    ('EventProcessor', NULL, 'EventProcessor:DlqTopic',                         'fraud.candidates.dlq', NULL),

    -- ── EventProcessor: seek / replay ──────────────────────────────────────
    ('EventProcessor', NULL, 'EventProcessor:Seek:Mode',                        'None',  'None / FromOffset / FromTimestamp / Range'),
    ('EventProcessor', NULL, 'EventProcessor:Seek:StartOffsetOrTimestamp',      '',      'Long offset OR ISO 8601 datetime'),
    ('EventProcessor', NULL, 'EventProcessor:Seek:StopOffsetOrTimestamp',       '',      'Optional stop boundary'),

    -- ── EventProcessor: output ─────────────────────────────────────────────
    ('EventProcessor', NULL, 'EventProcessor:OutputTopics:Decisions',           'fraud.decisions',  'Fraud decision output'),
    ('EventProcessor', NULL, 'EventProcessor:OutputTopics:Alerts',              'fraud.alerts',     'High-score alert events'),

    -- ── Logging suppressions (global) ─────────────────────────────────────
    (NULL, NULL, 'Logging:LogLevel:Microsoft.EntityFrameworkCore',               'Warning', 'Suppress EF Core info overhead at high throughput'),
    (NULL, NULL, 'Logging:LogLevel:Microsoft.EntityFrameworkCore.Database.Command', 'Warning', NULL)

) AS source (ApplicationId, InstanceId, [Key], [Value], Comment)
ON  ((target.ApplicationId = source.ApplicationId) OR (target.ApplicationId IS NULL AND source.ApplicationId IS NULL))
    AND ((target.InstanceId = source.InstanceId) OR (target.InstanceId IS NULL AND source.InstanceId IS NULL))
    AND target.[Key] = source.[Key]
WHEN NOT MATCHED THEN
    INSERT (ApplicationId, InstanceId, [Key], [Value], IsSecret, ValueEncrypted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, [Comment])
    VALUES (source.ApplicationId, source.InstanceId, source.[Key], source.[Value], 0, 0, 'SYSTEM', SYSUTCDATETIME(), 'SYSTEM', SYSUTCDATETIME(), source.Comment);
GO

-- =============================================================================
-- EventReader function catalog + JEX scripts migrated from old KafkaProcessor demo
-- =============================================================================
MERGE dbo.FunctionDefinitions AS target
USING (VALUES
    (1, 'Login',              '^Login$',                           1, 'Authentication'),
    (2, 'Logout',             '^Logout$',                          1, 'Authentication'),
    (3, 'OTP_Request',        '^OTP[_\s]?Request$',                1, 'Authentication'),
    (4, 'OTP_Validate',       '^OTP[_\s]?Validat(e|ion)$',         1, 'Authentication'),
    (5, 'Transfer_Own',       '^Transfer[_\s]?Own$',               2, 'Transfers'),
    (6, 'Transfer_Third',     '^Transfer[_\s]?Third[_\s]?Party$',  2, 'Transfers'),
    (7, 'Transfer_Intl',      '^Transfer[_\s]?Int(ernational|l)$', 2, 'Transfers'),
    (8, 'Bill_Payment',       '^Bill[_\s]?Payment$',               3, 'Payments'),
    (9, 'Card_Payment',       '^Card[_\s]?Payment$',               3, 'Payments'),
    (10, 'Balance_Enquiry',   '^Balance[_\s]?(Enquiry|Inquiry)$',  4, 'Enquiries')
) AS source (FunctionId, FunctionName, ActionRegex, GroupId, GroupName)
ON target.FunctionId = source.FunctionId
WHEN MATCHED THEN
    UPDATE SET FunctionName = source.FunctionName,
               ActionRegex = source.ActionRegex,
               GroupId = source.GroupId,
               GroupName = source.GroupName,
               IsEnabled = 1,
               ModifiedDate = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (FunctionId, FunctionName, ActionRegex, GroupId, GroupName, IsEnabled)
    VALUES (source.FunctionId, source.FunctionName, source.ActionRegex, source.GroupId, source.GroupName, 1);
GO

SET IDENTITY_INSERT dbo.Scripts ON;

MERGE dbo.Scripts AS target
USING (VALUES
    (1, 'EventReader', 'Login_Extract', 'extract', 'jex',
     '%set $.SessionID = coalescePath($in, "$.SessionId", "$.sessionId");
%set $.UUID = coalescePath($in, "$.UUID", "$.Jwt.Claims.UUID");
%set $.Channel = coalescePath($in, "$.Channel", "$.AuditContent.channel");
%set $.DeviceMake = coalescePath($in, "$.Jwt.Claims.DeviceMake", "$.AuditContent.deviceInformation.deviceMake");
%set $.DeviceOS = coalescePath($in, "$.Jwt.Claims.DeviceOS", "$.AuditContent.deviceInformation.deviceOS");
%set $.IPAddress = coalescePath($in, "$.IPAddress", "$.AuditContent.ipAddress");',
     'Extract fields for Login function', 'SYSTEM'),

    (2, 'EventReader', 'Transfer_Own_Extract', 'extract', 'jex',
     '%set $.SessionID = jp1($in, "$.SessionId");
%set $.UUID = coalescePath($in, "$.Jwt.Claims.UUID", "$.UUID");
%set $.Channel = jp1($in, "$.Channel");
%set $.Amount = toNumber(coalescePath($in, "$.AuditContent.amount", "$.Amount"));
%set $.Currency = jp1($in, "$.AuditContent.currency");
%set $.ToAccount = jp1($in, "$.AuditContent.toAccount");
%set $.FromAccount = jp1($in, "$.AuditContent.fromAccount");',
     'Extract fields for Transfer_Own function', 'SYSTEM'),

    (3, 'EventReader', 'Bill_Payment_Extract', 'extract', 'jex',
     '%set $.SessionID = jp1($in, "$.SessionId");
%set $.UUID = jp1($in, "$.UUID");
%set $.Channel = jp1($in, "$.Channel");
%set $.Amount = toNumber(coalescePath($in, "$.AuditContent.paymentAmount", "$.Amount"));
%set $.BillerCode = jp1($in, "$.AuditContent.billerCode");
%set $.ReferenceNo = jp1($in, "$.AuditContent.referenceNumber");',
     'Extract fields for Bill_Payment function', 'SYSTEM'),

    (4, 'EventReader', 'Balance_Enquiry_Extract', 'extract', 'jex',
     '%set $.SessionID = jp1($in, "$.SessionId");
%set $.UUID = jp1($in, "$.UUID");
%set $.Channel = jp1($in, "$.Channel");
%set $.AccountNumber = jp1($in, "$.AuditContent.accountNumber");',
     'Extract fields for Balance_Enquiry function', 'SYSTEM')
) AS source (ScriptId, ApplicationId, Name, TypeTag, Language, Content, Description, CreatedBy)
ON target.ScriptId = source.ScriptId
WHEN MATCHED THEN
    UPDATE SET ApplicationId = source.ApplicationId,
               Name = source.Name,
               TypeTag = source.TypeTag,
               Language = source.Language,
               Content = source.Content,
               Description = source.Description,
               IsEnabled = 1,
               ModifiedBy = source.CreatedBy,
               ModifiedDate = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (ScriptId, ApplicationId, Name, TypeTag, Language, Content, Description, IsEnabled, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
    VALUES (source.ScriptId, source.ApplicationId, source.Name, source.TypeTag, source.Language,
            source.Content, source.Description, 1, source.CreatedBy, SYSUTCDATETIME(), source.CreatedBy, SYSUTCDATETIME());
GO

SET IDENTITY_INSERT dbo.Scripts OFF;
GO

MERGE dbo.FunctionScripts AS target
USING (VALUES
    (1,  1, 'extract', 0),
    (5,  2, 'extract', 0),
    (8,  3, 'extract', 0),
    (10, 4, 'extract', 0)
) AS source (FunctionId, ScriptId, Role, Ordinal)
ON target.FunctionId = source.FunctionId
   AND target.ScriptId = source.ScriptId
   AND target.Role = source.Role
WHEN NOT MATCHED THEN
    INSERT (FunctionId, ScriptId, Role, Ordinal, IsEnabled)
    VALUES (source.FunctionId, source.ScriptId, source.Role, source.Ordinal, 1);
GO

PRINT 'StreamingPlatform seed data inserted successfully.';
GO
