-- Streaming Platform SQL Schema Initialization
-- Creates all required tables for EventReader, EventProcessor, EventAdminUI
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

-- =============================================================================
-- Database Creation
-- =============================================================================

IF DB_ID('StreamingPlatform') IS NULL
BEGIN
    CREATE DATABASE StreamingPlatform;
END
GO

USE StreamingPlatform;
GO

-- =============================================================================
-- Settings Table (KoreForge.Settings schema)
-- =============================================================================

IF OBJECT_ID('dbo.Settings', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Settings
    (
        ID               BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ApplicationId    NVARCHAR(200)  NULL,
        InstanceId       NVARCHAR(200)  NULL,
        [Key]            NVARCHAR(2048) NOT NULL,
        [Value]          NVARCHAR(MAX)  NULL,
        BinaryValue      VARBINARY(MAX) NULL,
        IsSecret         BIT            NOT NULL DEFAULT(0),
        ValueEncrypted   BIT            NOT NULL DEFAULT(0),
        CreatedBy        NVARCHAR(50)   NOT NULL,
        CreatedDate      DATETIME2(3)   NOT NULL,
        ModifiedBy       NVARCHAR(50)   NOT NULL,
        ModifiedDate     DATETIME2(3)   NOT NULL,
        [Comment]        VARCHAR(4000)  NULL,
        [Notes]          VARCHAR(MAX)   NULL,
        RowVersion       ROWVERSION     NOT NULL,
        CONSTRAINT CK_Settings_Value_XOR_Binary CHECK (
            ([Value] IS NOT NULL AND BinaryValue IS NULL)
            OR ([Value] IS NULL AND BinaryValue IS NOT NULL)
            OR ([Value] IS NULL AND BinaryValue IS NULL)
        )
    );
END
GO

-- Unique indexes for scope resolution (Global / Application / Instance)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_Settings_Global_Key')
    CREATE UNIQUE INDEX UX_Settings_Global_Key
        ON dbo.Settings([Key])
        WHERE ApplicationId IS NULL AND InstanceId IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_Settings_App_Key')
    CREATE UNIQUE INDEX UX_Settings_App_Key
        ON dbo.Settings(ApplicationId, [Key])
        WHERE ApplicationId IS NOT NULL AND InstanceId IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_Settings_Instance_Key')
    CREATE UNIQUE INDEX UX_Settings_Instance_Key
        ON dbo.Settings(ApplicationId, InstanceId, [Key])
        WHERE ApplicationId IS NOT NULL AND InstanceId IS NOT NULL;
GO

-- =============================================================================
-- Schema Compatibility Repair (local dev bootstrap)
-- =============================================================================

IF OBJECT_ID('dbo.Scripts', 'U') IS NOT NULL
   AND (COL_LENGTH('dbo.Scripts', 'ApplicationId') IS NULL OR COL_LENGTH('dbo.Scripts', 'RowVersion') IS NULL)
BEGIN
    IF OBJECT_ID('dbo.ShadowTestSessions', 'U') IS NOT NULL DROP TABLE dbo.ShadowTestSessions;
    IF OBJECT_ID('dbo.FunctionScripts', 'U') IS NOT NULL DROP TABLE dbo.FunctionScripts;
    IF OBJECT_ID('dbo.ScriptHistory', 'U') IS NOT NULL DROP TABLE dbo.ScriptHistory;
    DROP TABLE dbo.Scripts;
END
GO

IF OBJECT_ID('dbo.FunctionDefinitions', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.FunctionDefinitions', 'ActionRegex') IS NULL
BEGIN
    IF OBJECT_ID('dbo.FunctionScripts', 'U') IS NOT NULL DROP TABLE dbo.FunctionScripts;
    DROP TABLE dbo.FunctionDefinitions;
END
GO

-- =============================================================================
-- Scripts Table (KoreForge.Scripts schema)
-- =============================================================================

IF OBJECT_ID('dbo.Scripts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Scripts
    (
        ScriptId        BIGINT IDENTITY(1,1) NOT NULL,
        ApplicationId   NVARCHAR(200)        NOT NULL,
        Name            NVARCHAR(500)        NOT NULL,
        TypeTag         NVARCHAR(100)        NOT NULL,
        Language        NVARCHAR(50)         NOT NULL,
        Content         NVARCHAR(MAX)        NOT NULL,
        Description     NVARCHAR(2000)       NULL,
        IsEnabled       BIT                  NOT NULL DEFAULT(1),
        CreatedBy       NVARCHAR(100)        NOT NULL,
        CreatedDate     DATETIME2(3)         NOT NULL DEFAULT(SYSUTCDATETIME()),
        ModifiedBy      NVARCHAR(100)        NOT NULL,
        ModifiedDate    DATETIME2(3)         NOT NULL DEFAULT(SYSUTCDATETIME()),
        Comment         NVARCHAR(4000)       NULL,
        RowVersion      ROWVERSION           NOT NULL,

        CONSTRAINT PK_Scripts PRIMARY KEY CLUSTERED (ScriptId),
        CONSTRAINT UX_Scripts_App_Name UNIQUE (ApplicationId, Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Scripts_App_TypeTag')
    CREATE INDEX IX_Scripts_App_TypeTag ON dbo.Scripts(ApplicationId, TypeTag);
GO

-- =============================================================================
-- Script History Table (KoreForge.Scripts audit trail)
-- =============================================================================

IF OBJECT_ID('dbo.ScriptHistory', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScriptHistory
    (
        HistoryId          BIGINT IDENTITY(1,1) NOT NULL,
        ScriptId           BIGINT               NOT NULL,
        ApplicationId      NVARCHAR(200)       NOT NULL,
        Name               NVARCHAR(500)       NOT NULL,
        OldContent         NVARCHAR(MAX)       NULL,
        NewContent         NVARCHAR(MAX)       NULL,
        OldIsEnabled       BIT                 NULL,
        NewIsEnabled       BIT                 NULL,
        RowVersionBefore   VARBINARY(8)        NULL,
        RowVersionAfter    VARBINARY(8)        NULL,
        ChangedBy          NVARCHAR(100)       NOT NULL,
        ChangedDate        DATETIME2(3)        NOT NULL DEFAULT(SYSUTCDATETIME()),
        Operation          NVARCHAR(50)        NOT NULL,
        Comment            NVARCHAR(4000)      NULL,

        CONSTRAINT PK_ScriptHistory PRIMARY KEY CLUSTERED (HistoryId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ScriptHistory_ScriptId')
    CREATE INDEX IX_ScriptHistory_ScriptId ON dbo.ScriptHistory(ScriptId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_ScriptHistory_AppNameDate')
    CREATE INDEX IX_ScriptHistory_AppNameDate ON dbo.ScriptHistory(ApplicationId, Name, ChangedDate);
GO

-- =============================================================================
-- Shadow Test Sessions
-- =============================================================================

IF OBJECT_ID('dbo.ShadowTestSessions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ShadowTestSessions
    (
        SessionId            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        FunctionId           BIGINT         NOT NULL,
        LiveScriptVersion    INT            NOT NULL,
        CandidateScriptId    BIGINT         NOT NULL,
        ConfiguredSampleSize INT            NOT NULL DEFAULT(1000),
        ActualSamples        INT            NOT NULL DEFAULT(0),
        MatchCount           INT            NOT NULL DEFAULT(0),
        MismatchCount        INT            NOT NULL DEFAULT(0),
        MatchPercent         FLOAT          NULL,
        StartedAt            DATETIME2(3)   NOT NULL DEFAULT(SYSUTCDATETIME()),
        EndedAt              DATETIME2(3)   NULL,
        Status               NVARCHAR(50)   NOT NULL DEFAULT('Running'), -- Running / Completed / Stopped / Promoted
        AvgLatencyLiveMs     FLOAT          NULL,
        AvgLatencyCandidateMs FLOAT         NULL,
        CONSTRAINT FK_ShadowTests_Candidate FOREIGN KEY (CandidateScriptId) REFERENCES dbo.Scripts(ScriptId)
    );
END
GO

-- =============================================================================
-- Function Definitions (action regex patterns per function)
-- =============================================================================

IF OBJECT_ID('dbo.FunctionDefinitions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FunctionDefinitions
    (
        FunctionId       BIGINT          NOT NULL,
        FunctionName     NVARCHAR(200)   NOT NULL,
        ActionRegex      NVARCHAR(500)   NOT NULL,
        GroupId          INT             NOT NULL,
        GroupName        NVARCHAR(200)   NOT NULL,
        IsEnabled        BIT             NOT NULL DEFAULT(1),
        CreatedDate      DATETIME2(3)    NOT NULL DEFAULT(SYSUTCDATETIME()),
        ModifiedDate     DATETIME2(3)    NOT NULL DEFAULT(SYSUTCDATETIME()),

        CONSTRAINT PK_FunctionDefinitions PRIMARY KEY CLUSTERED (FunctionId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_FunctionDefinitions_FunctionName')
    CREATE UNIQUE INDEX UX_FunctionDefinitions_FunctionName ON dbo.FunctionDefinitions(FunctionName);
GO

-- =============================================================================
-- Function Scripts Junction Table (KafkaProcessor.Scripts.API)
-- =============================================================================

IF OBJECT_ID('dbo.FunctionScripts', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FunctionScripts
    (
        FunctionId  BIGINT       NOT NULL,
        ScriptId    BIGINT       NOT NULL,
        Role        NVARCHAR(50) NOT NULL DEFAULT('extract'),
        Ordinal     INT          NOT NULL DEFAULT(0),
        IsEnabled   BIT          NOT NULL DEFAULT(1),
        CreatedDate DATETIME2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),

        CONSTRAINT PK_FunctionScripts PRIMARY KEY (FunctionId, ScriptId, Role),
        CONSTRAINT FK_FunctionScripts_Function FOREIGN KEY (FunctionId) REFERENCES dbo.FunctionDefinitions(FunctionId),
        CONSTRAINT FK_FunctionScripts_Script FOREIGN KEY (ScriptId) REFERENCES dbo.Scripts(ScriptId)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_FunctionScripts_ScriptId')
    CREATE INDEX IX_FunctionScripts_ScriptId ON dbo.FunctionScripts(ScriptId);
GO

-- =============================================================================
-- Incidents Table (runtime operational incidents)
-- =============================================================================

IF OBJECT_ID('dbo.Incidents', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Incidents
    (
        IncidentId       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        Application      NVARCHAR(128)  NOT NULL,
        InstanceId       NVARCHAR(128)  NOT NULL,
        Category         NVARCHAR(128)  NOT NULL,    -- 'Rebalance', 'DlqMessage', 'PipelineError', etc.
        Severity         NVARCHAR(50)   NOT NULL DEFAULT('Warning'),
        Message          NVARCHAR(MAX)  NOT NULL,
        Detail           NVARCHAR(MAX)  NULL,
        OccurredAt       DATETIME2(3)   NOT NULL DEFAULT(SYSUTCDATETIME()),
        ResolvedAt       DATETIME2(3)   NULL,
        IsResolved       BIT            NOT NULL DEFAULT(0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Incidents_App_OccurredAt')
    CREATE INDEX IX_Incidents_App_OccurredAt ON dbo.Incidents(Application, OccurredAt DESC);
GO

-- =============================================================================
-- EventReader Runtime Model Schema
-- Stores function definitions, source systems, matchers, and rules used to
-- build the EventReaderRuntimeModel. Reload is triggered by bumping the
-- EventReader:ModelVersion key in dbo.Settings.
-- =============================================================================

IF SCHEMA_ID('EventReader') IS NULL
    EXEC('CREATE SCHEMA EventReader');
GO

-- Global config key-value pairs (DiscriminatorPaths, ClientIdentityPaths, PrefixLength)
IF OBJECT_ID('EventReader.Config', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.Config
    (
        ConfigKey   NVARCHAR(100) NOT NULL PRIMARY KEY,
        ConfigValue NVARCHAR(500) NOT NULL
    );
END
GO

-- Source systems / Kafka topics
IF OBJECT_ID('EventReader.SourceSystem', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.SourceSystem
    (
        SourceSystemId NVARCHAR(100) NOT NULL PRIMARY KEY,
        KafkaTopic     NVARCHAR(200) NOT NULL,
        ProviderName   NVARCHAR(200) NOT NULL,
        IsEnabled      BIT          NOT NULL DEFAULT(1)
    );
END
GO

-- Arbitrary tags on source systems
IF OBJECT_ID('EventReader.SourceSystemTag', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.SourceSystemTag
    (
        SourceSystemId NVARCHAR(100) NOT NULL
            REFERENCES EventReader.SourceSystem(SourceSystemId) ON DELETE CASCADE,
        TagKey         NVARCHAR(100) NOT NULL,
        TagValue       NVARCHAR(500) NOT NULL DEFAULT(''),
        PRIMARY KEY (SourceSystemId, TagKey)
    );
END
GO

-- Function definitions (global plan)
IF OBJECT_ID('EventReader.Function', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.Function
    (
        FunctionId              INT           NOT NULL PRIMARY KEY,
        FunctionVersion         BIGINT        NOT NULL,
        Name                    NVARCHAR(200) NOT NULL,
        IsEnabled               BIT           NOT NULL DEFAULT(1),
        -- Extraction script reference (resolves to dbo.Scripts by Name)
        ScriptName              NVARCHAR(200) NOT NULL DEFAULT(''),
        ScriptVersion           BIGINT        NOT NULL DEFAULT(0),
        -- Rule set
        RuleSetVersion          BIGINT        NOT NULL DEFAULT(0),
        -- Output route
        OutputRouteVersion      BIGINT        NOT NULL DEFAULT(0),
        OutputRouteName         NVARCHAR(200) NOT NULL DEFAULT('default'),
        OutputTopic             NVARCHAR(500) NOT NULL DEFAULT(''),
        -- Failure policy
        FailWhenNedbankIdMissing BIT          NOT NULL DEFAULT(0),
        MaxProcessingAttempts   INT           NOT NULL DEFAULT(3),
        MaxOutputAttempts       INT           NOT NULL DEFAULT(3)
    );
END
GO

-- Rules within a function's global rule set
IF OBJECT_ID('EventReader.FunctionRule', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.FunctionRule
    (
        FunctionId  INT           NOT NULL
            REFERENCES EventReader.Function(FunctionId) ON DELETE CASCADE,
        RuleId      INT           NOT NULL,
        RuleVersion BIGINT        NOT NULL,
        RuleName    NVARCHAR(200) NOT NULL,
        PRIMARY KEY (FunctionId, RuleId)
    );
END
GO

-- Prefix+regex matchers: map discriminator values to functions
-- SourceSystemId NULL = global (applies to all source systems)
IF OBJECT_ID('EventReader.FunctionMatcher', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.FunctionMatcher
    (
        FunctionMatcherId INT           NOT NULL IDENTITY PRIMARY KEY,
        SourceSystemId    NVARCHAR(100) NULL,
        FunctionId        INT           NOT NULL
            REFERENCES EventReader.Function(FunctionId) ON DELETE CASCADE,
        Priority          INT           NOT NULL DEFAULT(100),
        Prefix            NVARCHAR(100) NOT NULL,
        RegexPattern      NVARCHAR(1000) NOT NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FunctionMatcher_FunctionId')
    CREATE INDEX IX_FunctionMatcher_FunctionId ON EventReader.FunctionMatcher(FunctionId);
GO

-- Source-system-specific overrides for a function plan
IF OBJECT_ID('EventReader.FunctionSourceOverride', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.FunctionSourceOverride
    (
        FunctionId               INT           NOT NULL
            REFERENCES EventReader.Function(FunctionId) ON DELETE CASCADE,
        SourceSystemId           NVARCHAR(100) NOT NULL
            REFERENCES EventReader.SourceSystem(SourceSystemId),
        ScriptName               NVARCHAR(200) NOT NULL DEFAULT(''),
        ScriptVersion            BIGINT        NOT NULL DEFAULT(0),
        RuleSetVersion           BIGINT        NOT NULL DEFAULT(0),
        OutputRouteVersion       BIGINT        NOT NULL DEFAULT(0),
        OutputRouteName          NVARCHAR(200) NOT NULL DEFAULT('default'),
        OutputTopic              NVARCHAR(500) NOT NULL DEFAULT(''),
        FailWhenNedbankIdMissing BIT           NOT NULL DEFAULT(0),
        MaxProcessingAttempts    INT           NOT NULL DEFAULT(3),
        MaxOutputAttempts        INT           NOT NULL DEFAULT(3),
        PRIMARY KEY (FunctionId, SourceSystemId)
    );
END
GO

-- Rules within a source-system-specific override rule set
IF OBJECT_ID('EventReader.FunctionSourceOverrideRule', 'U') IS NULL
BEGIN
    CREATE TABLE EventReader.FunctionSourceOverrideRule
    (
        FunctionId     INT           NOT NULL,
        SourceSystemId NVARCHAR(100) NOT NULL,
        RuleId         INT           NOT NULL,
        RuleVersion    BIGINT        NOT NULL,
        RuleName       NVARCHAR(200) NOT NULL,
        FOREIGN KEY (FunctionId, SourceSystemId)
            REFERENCES EventReader.FunctionSourceOverride(FunctionId, SourceSystemId)
            ON DELETE CASCADE,
        PRIMARY KEY (FunctionId, SourceSystemId, RuleId)
    );
END
GO

PRINT 'StreamingPlatform schema initialized successfully.';
GO
