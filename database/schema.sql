-- ============================================================
-- База данных: Управление клиентской базой компании по продаже керамической плитки
-- СУБД: Microsoft SQL Server
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'TileCompanyDB')
BEGIN
    ALTER DATABASE TileCompanyDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TileCompanyDB;
END
GO

CREATE DATABASE TileCompanyDB
    COLLATE Cyrillic_General_CI_AS;
GO

USE TileCompanyDB;
GO

-- ============================================================
-- Таблица ролей пользователей
-- ============================================================
CREATE TABLE Roles (
    RoleID   INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE  -- 'admin', 'manager'
);
GO

INSERT INTO Roles (RoleName) VALUES (N'admin'), (N'manager');
GO

-- ============================================================
-- Таблица пользователей (администраторы и менеджеры)
-- RoleID = NULL означает "зарегистрирован, но роль не назначена"
-- ============================================================
CREATE TABLE Users (
    UserID        INT IDENTITY(1,1) PRIMARY KEY,
    RoleID        INT NULL REFERENCES Roles(RoleID),   -- NULL = ожидает назначения роли
    Login         NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash  NVARCHAR(256) NOT NULL,               -- SHA-256 hex
    FullName      NVARCHAR(200) NOT NULL,
    Email         NVARCHAR(200) NULL,
    Phone         NVARCHAR(50)  NULL,
    IsActive      BIT NOT NULL DEFAULT 0,               -- 0 = заблокирован до назначения роли
    IsPendingRole BIT NOT NULL DEFAULT 0,               -- 1 = зарегистрирован самостоятельно, ждёт роли
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETDATE(),
    LastLoginAt   DATETIME2 NULL
);
GO

-- ============================================================
-- Справочник: типы клиентов
-- ============================================================
CREATE TABLE ClientTypes (
    ClientTypeID   INT IDENTITY(1,1) PRIMARY KEY,
    TypeName       NVARCHAR(100) NOT NULL UNIQUE  -- 'Физическое лицо', 'Юридическое лицо', 'ИП'
);
GO

INSERT INTO ClientTypes (TypeName)
VALUES (N'Физическое лицо'), (N'Юридическое лицо'), (N'ИП');
GO

-- ============================================================
-- Справочник: источники привлечения клиентов
-- ============================================================
CREATE TABLE LeadSources (
    LeadSourceID INT IDENTITY(1,1) PRIMARY KEY,
    SourceName   NVARCHAR(150) NOT NULL UNIQUE
);
GO

INSERT INTO LeadSources (SourceName)
VALUES
    (N'Сайт'),
    (N'Рекомендация'),
    (N'Социальные сети'),
    (N'Холодный звонок'),
    (N'Выставка'),
    (N'Другое');
GO

-- ============================================================
-- Справочник: статусы клиентов
-- ============================================================
CREATE TABLE ClientStatuses (
    StatusID   INT IDENTITY(1,1) PRIMARY KEY,
    StatusName NVARCHAR(100) NOT NULL UNIQUE
);
GO

INSERT INTO ClientStatuses (StatusName)
VALUES
    (N'Новый'),
    (N'Активный'),
    (N'Постоянный'),
    (N'Неактивный'),
    (N'Потерянный');
GO

-- ============================================================
-- Таблица клиентов
-- ============================================================
CREATE TABLE Clients (
    ClientID         INT IDENTITY(1,1) PRIMARY KEY,
    ManagerID        INT NOT NULL REFERENCES Users(UserID),
    ClientTypeID     INT NOT NULL REFERENCES ClientTypes(ClientTypeID),
    LeadSourceID     INT NOT NULL REFERENCES LeadSources(LeadSourceID),
    StatusID         INT NOT NULL REFERENCES ClientStatuses(StatusID) DEFAULT 1,
    FullName         NVARCHAR(300) NOT NULL,
    CompanyName      NVARCHAR(300) NULL,
    Phone            NVARCHAR(50)  NOT NULL,
    Email            NVARCHAR(200) NULL,
    Address          NVARCHAR(500) NULL,
    BirthDate        DATE NULL,                -- День рождения клиента (необязательное)
    FirstContactDate DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    TotalPurchases   DECIMAL(18,2) NOT NULL DEFAULT 0,
    LastPurchaseDate DATE NULL,
    Notes            NVARCHAR(MAX) NULL,
    CreatedAt        DATETIME2 NOT NULL DEFAULT GETDATE(),
    UpdatedAt        DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Справочник: категории товаров
-- ============================================================
CREATE TABLE ProductCategories (
    CategoryID   INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(150) NOT NULL UNIQUE
);
GO

INSERT INTO ProductCategories (CategoryName)
VALUES
    (N'Напольная плитка'),
    (N'Настенная плитка'),
    (N'Мозаика'),
    (N'Керамогранит'),
    (N'Клинкер');
GO

-- ============================================================
-- Таблица товаров
-- ============================================================
CREATE TABLE Products (
    ProductID    INT IDENTITY(1,1) PRIMARY KEY,
    CategoryID   INT NOT NULL REFERENCES ProductCategories(CategoryID),
    ProductName  NVARCHAR(300) NOT NULL,
    SKU          NVARCHAR(100) NULL UNIQUE,
    Unit         NVARCHAR(50)  NOT NULL DEFAULT N'м²',
    Price        DECIMAL(18,2) NOT NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Справочник: этапы сделок (воронка продаж)
-- ============================================================
CREATE TABLE DealStages (
    StageID      INT IDENTITY(1,1) PRIMARY KEY,
    StageName    NVARCHAR(150) NOT NULL UNIQUE,
    StageOrder   INT NOT NULL DEFAULT 0,    -- порядок отображения на канбан-доске
    IsCompleted  BIT NOT NULL DEFAULT 0     -- 1 = финальный успешный этап
);
GO

INSERT INTO DealStages (StageName, StageOrder, IsCompleted)
VALUES
    (N'Новый контакт',            1, 0),
    (N'Выявление потребностей',   2, 0),
    (N'Подбор и расчёт',          3, 0),
    (N'Согласование',             4, 0),
    (N'Счёт выставлен',           5, 0),
    (N'Оплата получена',          6, 0),
    (N'Заказ передан на склад',   7, 0),
    (N'Выполнено',                8, 1);
GO

-- ============================================================
-- Таблица сделок (заменяет Sales)
-- ============================================================
CREATE TABLE Deals (
    DealID       INT IDENTITY(1,1) PRIMARY KEY,
    ClientID     INT NOT NULL REFERENCES Clients(ClientID),
    ManagerID    INT NOT NULL REFERENCES Users(UserID),
    StageID      INT NOT NULL REFERENCES DealStages(StageID) DEFAULT 1,
    DealType     NVARCHAR(20) NOT NULL DEFAULT N'розница',  -- 'розница' / 'опт'
    Title        NVARCHAR(300) NOT NULL,          -- описание объекта/сделки
    Budget       DECIMAL(18,2) NULL,              -- бюджет сделки
    Priority     INT NOT NULL DEFAULT 2,          -- 1=низкий, 2=средний, 3=высокий
    DealDate     DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
    Deadline     DATE NULL,                       -- срок выполнения
    Notes        NVARCHAR(MAX) NULL,
    IsArchived   BIT NOT NULL DEFAULT 0,
    CompletedAt  DATETIME2 NULL,                          -- заполняется при переходе на этап "Выполнено"
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETDATE(),
    UpdatedAt    DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица позиций сделки (товары)
-- ============================================================
CREATE TABLE DealItems (
    DealItemID  INT IDENTITY(1,1) PRIMARY KEY,
    DealID      INT NOT NULL REFERENCES Deals(DealID) ON DELETE CASCADE,
    ProductID   INT NOT NULL REFERENCES Products(ProductID),
    Quantity    DECIMAL(18,4) NOT NULL,
    UnitPrice   DECIMAL(18,2) NOT NULL,
    LineTotal   AS (Quantity * UnitPrice) PERSISTED
);
GO

-- ============================================================
-- Таблица событий по сделке (лента)
-- ============================================================
CREATE TABLE DealEvents (
    EventID     INT IDENTITY(1,1) PRIMARY KEY,
    DealID      INT NOT NULL REFERENCES Deals(DealID) ON DELETE CASCADE,
    EventType   NVARCHAR(50) NOT NULL,     -- 'stage_change', 'item_added', 'payment_received', 'closed', 'created', 'task_completed', 'doc_added', 'doc_deleted'
    Description NVARCHAR(MAX) NOT NULL,
    IsAutomatic BIT NOT NULL DEFAULT 1,    -- 1 = авто-событие, нельзя удалять менеджеру
    EventDate   DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица задач по сделке
-- ============================================================
CREATE TABLE DealTasks (
    TaskID       INT IDENTITY(1,1) PRIMARY KEY,
    DealID       INT NOT NULL REFERENCES Deals(DealID) ON DELETE CASCADE,
    TaskType     NVARCHAR(50) NOT NULL,    -- 'call', 'meeting', 'letter'
    Title        NVARCHAR(300) NOT NULL,
    Description  NVARCHAR(MAX) NULL,
    ScheduledAt  DATETIME2 NOT NULL,
    CompletedAt  DATETIME2 NULL,
    IsCompleted  BIT NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица документов сделки
-- ============================================================
CREATE TABLE DealDocuments (
    DocID        INT IDENTITY(1,1) PRIMARY KEY,
    DealID       INT NOT NULL REFERENCES Deals(DealID) ON DELETE CASCADE,
    UploadedBy   INT NOT NULL REFERENCES Users(UserID),
    FileName     NVARCHAR(500) NOT NULL,
    OriginalName NVARCHAR(500) NOT NULL,
    FileSize     BIGINT NOT NULL DEFAULT 0,
    MimeType     NVARCHAR(200) NULL,
    UploadedAt   DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица заметок по клиентам
-- ============================================================
CREATE TABLE ClientNotes (
    NoteID    INT IDENTITY(1,1) PRIMARY KEY,
    ClientID  INT NOT NULL REFERENCES Clients(ClientID) ON DELETE CASCADE,
    AuthorID  INT NOT NULL REFERENCES Users(UserID),
    NoteText  NVARCHAR(MAX) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица ленты событий по клиенту (звонки, встречи, письма)
-- ============================================================
CREATE TABLE ClientEvents (
    EventID         INT IDENTITY(1,1) PRIMARY KEY,
    ClientID        INT NOT NULL REFERENCES Clients(ClientID) ON DELETE CASCADE,
    AuthorID        INT NOT NULL REFERENCES Users(UserID),
    EventType       NVARCHAR(50) NOT NULL,     -- 'call', 'meeting', 'email', 'note', 'task_completed', 'doc_added', 'doc_deleted', 'deal_stage', 'deal_closed'
    EventDate       DATETIME2 NOT NULL DEFAULT GETDATE(),
    Title           NVARCHAR(300) NOT NULL,
    Description     NVARCHAR(MAX) NULL,
    IsAutomatic     BIT NOT NULL DEFAULT 0,    -- 1 = авто-событие, нельзя удалять менеджеру
    SourceDealID    INT NULL,                  -- источник: сделка (для дублирования событий)
    SourceDealTaskID INT NULL,                 -- источник: задача сделки
    CreatedAt       DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица задач / плановых событий (звонки, встречи, письма)
-- ============================================================
CREATE TABLE Tasks (
    TaskID       INT IDENTITY(1,1) PRIMARY KEY,
    ClientID     INT NOT NULL REFERENCES Clients(ClientID) ON DELETE CASCADE,
    ManagerID    INT NOT NULL REFERENCES Users(UserID),
    DealID       INT NULL,                            -- если задача создана из сделки (DealID без FK из-за CASCADE)
    TaskType     NVARCHAR(50) NOT NULL,    -- 'call', 'meeting', 'letter'
    Title        NVARCHAR(300) NOT NULL,
    Description  NVARCHAR(MAX) NULL,
    ScheduledAt  DATETIME2 NOT NULL,       -- запланированное время
    CompletedAt  DATETIME2 NULL,           -- время выполнения (NULL = не выполнено)
    IsCompleted  BIT NOT NULL DEFAULT 0,
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица документов клиента
-- ============================================================
CREATE TABLE ClientDocuments (
    DocumentID   INT IDENTITY(1,1) PRIMARY KEY,
    ClientID     INT NOT NULL REFERENCES Clients(ClientID) ON DELETE CASCADE,
    UploadedBy   INT NOT NULL REFERENCES Users(UserID),
    FileName     NVARCHAR(500) NOT NULL,
    OriginalName NVARCHAR(500) NOT NULL,
    FileSize     BIGINT NOT NULL DEFAULT 0,
    MimeType     NVARCHAR(200) NULL,
    UploadedAt   DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- Таблица планов продаж (устанавливается на месяц компанией)
-- ============================================================
CREATE TABLE SalesPlans (
    PlanID       INT IDENTITY(1,1) PRIMARY KEY,
    PlanYear     INT NOT NULL,
    PlanMonth    INT NOT NULL,
    TargetAmount DECIMAL(18,2) NOT NULL,    -- целевая сумма продаж
    CreatedBy    INT NOT NULL REFERENCES Users(UserID),
    CreatedAt    DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_SalesPlan_YearMonth UNIQUE (PlanYear, PlanMonth)
);
GO

-- ============================================================
-- Таблица квот менеджеров (индивидуальные цели)
-- ============================================================
CREATE TABLE ManagerQuotas (
    QuotaID       INT IDENTITY(1,1) PRIMARY KEY,
    ManagerID     INT NOT NULL REFERENCES Users(UserID),
    QuotaYear     INT NOT NULL,
    QuotaMonth    INT NOT NULL,
    QuotaType     NVARCHAR(50) NOT NULL,    -- 'sales_amount', 'deals_count', 'new_clients', 'plan_percent'
    TargetValue   DECIMAL(18,2) NOT NULL,
    CreatedBy     INT NOT NULL REFERENCES Users(UserID),
    CreatedAt     DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_ManagerQuota UNIQUE (ManagerID, QuotaYear, QuotaMonth, QuotaType)
);
GO

-- ============================================================
-- Триггер: автоматическое обновление финансовой информации клиента
-- при добавлении сделки (когда она завершена)
-- ============================================================
CREATE TRIGGER trg_Deals_AfterUpdate
ON Deals
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- Когда сделка переходит в финальный этап ("Выполнено") — обновляем TotalPurchases клиента
    -- Используем сумму позиций (DealItems), а не Budget
    UPDATE c
    SET
        c.TotalPurchases   = ISNULL((
            SELECT SUM(ISNULL(di_sum.ItemsTotal, 0))
            FROM (
                SELECT d2.DealID,
                       ISNULL((SELECT SUM(LineTotal) FROM DealItems WHERE DealID = d2.DealID), 0) AS ItemsTotal
                FROM Deals d2
                INNER JOIN DealStages ds2 ON d2.StageID = ds2.StageID
                WHERE d2.ClientID = c.ClientID AND ds2.IsCompleted = 1
            ) di_sum
        ), 0),
        c.LastPurchaseDate = CAST(GETDATE() AS DATE),
        c.UpdatedAt        = GETDATE()
    FROM Clients c
    INNER JOIN inserted i ON c.ClientID = i.ClientID
    INNER JOIN DealStages ds ON i.StageID = ds.StageID
    WHERE ds.IsCompleted = 1;
END;
GO

-- ============================================================
-- Триггер: обновление UpdatedAt у сделки при изменении
-- ============================================================
CREATE TRIGGER trg_Deals_AfterUpdateTs
ON Deals
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(UpdatedAt)
    BEGIN
        UPDATE d SET d.UpdatedAt = GETDATE()
        FROM Deals d INNER JOIN inserted i ON d.DealID = i.DealID;
    END
END;
GO

-- ============================================================
-- Триггер: обновление UpdatedAt у клиента при изменении
-- ============================================================
CREATE TRIGGER trg_Clients_AfterUpdate
ON Clients
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(UpdatedAt)
    BEGIN
        UPDATE c SET c.UpdatedAt = GETDATE()
        FROM Clients c INNER JOIN inserted i ON c.ClientID = i.ClientID;
    END
END;
GO

-- ============================================================
-- Хранимая процедура: авторизация пользователя
-- ============================================================
CREATE PROCEDURE sp_AuthenticateUser
    @Login       NVARCHAR(100),
    @PasswordHash NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.UserID,
        u.Login,
        u.FullName,
        u.Email,
        u.Phone,
        u.IsActive,
        u.IsPendingRole,
        r.RoleName
    FROM Users u
    LEFT JOIN Roles r ON u.RoleID = r.RoleID
    WHERE u.Login = @Login
      AND u.PasswordHash = @PasswordHash
      AND u.IsActive = 1;

    -- Обновляем дату последнего входа
    UPDATE Users SET LastLoginAt = GETDATE()
    WHERE Login = @Login AND PasswordHash = @PasswordHash AND IsActive = 1;
END;
GO

-- ============================================================
-- Хранимая процедура: статистика менеджера
-- ============================================================
CREATE PROCEDURE sp_GetManagerStats
    @ManagerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        (SELECT COUNT(*) FROM Clients WHERE ManagerID = @ManagerID) AS TotalClients,
        -- Продажи за месяц: завершённые сделки (IsCompleted=1), CompletedAt в этом месяце
        ISNULL((
            SELECT SUM(ISNULL(d.Budget,0))
            FROM Deals d
            INNER JOIN DealStages ds ON d.StageID = ds.StageID
            WHERE d.ManagerID = @ManagerID
              AND ds.IsCompleted = 1
              AND d.CompletedAt IS NOT NULL
              AND YEAR(d.CompletedAt)  = YEAR(GETDATE())
              AND MONTH(d.CompletedAt) = MONTH(GETDATE())
        ), 0) AS MonthlySales,
        -- Количество завершённых сделок за этот месяц
        ISNULL((
            SELECT COUNT(*)
            FROM Deals d INNER JOIN DealStages ds ON d.StageID = ds.StageID
            WHERE d.ManagerID = @ManagerID
              AND ds.IsCompleted = 1
              AND d.CompletedAt IS NOT NULL
              AND YEAR(d.CompletedAt)  = YEAR(GETDATE())
              AND MONTH(d.CompletedAt) = MONTH(GETDATE())
        ), 0) AS MonthlyDeals,
        -- Активные сделки (не завершены, не архив)
        (SELECT COUNT(*) FROM Deals d
         INNER JOIN DealStages ds ON d.StageID = ds.StageID
         WHERE d.ManagerID = @ManagerID
           AND d.IsArchived = 0
           AND ds.IsCompleted = 0
        ) AS ActiveDeals;
END;
GO

-- ============================================================
-- Хранимая процедура: общая статистика компании (для администратора)
-- ============================================================
CREATE PROCEDURE sp_GetCompanyStats
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurYear  INT = YEAR(GETDATE());
    DECLARE @CurMonth INT = MONTH(GETDATE());
    SELECT
        (SELECT COUNT(*) FROM Clients)                          AS TotalClients,
        ISNULL((SELECT SUM(ISNULL(Budget,0)) FROM Deals
                INNER JOIN DealStages ds ON Deals.StageID = ds.StageID
                WHERE ds.IsCompleted = 1), 0)                  AS TotalSales,
        (SELECT COUNT(*) FROM Deals)                           AS TotalDeals,
        -- Продажи за месяц: завершённые сделки, CompletedAt в этом месяце
        ISNULL((SELECT SUM(ISNULL(d.Budget,0)) FROM Deals d
                INNER JOIN DealStages ds ON d.StageID = ds.StageID
                WHERE ds.IsCompleted = 1
                  AND d.CompletedAt IS NOT NULL
                  AND YEAR(d.CompletedAt)  = @CurYear
                  AND MONTH(d.CompletedAt) = @CurMonth), 0)     AS MonthlySales,
        -- Количество завершённых сделок за этот месяц
        ISNULL((SELECT COUNT(*) FROM Deals d
                INNER JOIN DealStages ds ON d.StageID = ds.StageID
                WHERE ds.IsCompleted = 1
                  AND d.CompletedAt IS NOT NULL
                  AND YEAR(d.CompletedAt)  = @CurYear
                  AND MONTH(d.CompletedAt) = @CurMonth), 0)    AS MonthlyDeals,
        (SELECT COUNT(*) FROM Users
         WHERE RoleID = (SELECT RoleID FROM Roles WHERE RoleName = 'manager')
           AND IsActive = 1)                                   AS ActiveManagers,
        (SELECT COUNT(*) FROM Clients
         WHERE YEAR(CreatedAt)  = @CurYear
           AND MONTH(CreatedAt) = @CurMonth)                   AS NewClients,
        (SELECT COUNT(*) FROM Users WHERE IsPendingRole = 1)   AS PendingManagers;
END;
GO

-- ============================================================
-- Хранимая процедура: получение списка клиентов менеджера
-- ============================================================
CREATE PROCEDURE sp_GetManagerClients
    @ManagerID INT,
    @Search    NVARCHAR(200) = NULL,
    @StatusID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ClientID,
        c.FullName,
        c.CompanyName,
        c.Phone,
        c.Email,
        c.BirthDate,
        ct.TypeName   AS ClientType,
        cs.StatusName AS Status,
        ls.SourceName AS LeadSource,
        c.FirstContactDate,
        ISNULL((SELECT SUM(ISNULL(d.Budget,0)) FROM Deals d
                INNER JOIN DealStages ds ON d.StageID = ds.StageID
                WHERE d.ClientID = c.ClientID AND ds.IsCompleted = 1), 0) AS TotalPurchases,
        c.LastPurchaseDate,
        c.UpdatedAt
    FROM Clients c
    INNER JOIN ClientTypes    ct ON c.ClientTypeID  = ct.ClientTypeID
    INNER JOIN ClientStatuses cs ON c.StatusID      = cs.StatusID
    INNER JOIN LeadSources    ls ON c.LeadSourceID  = ls.LeadSourceID
    WHERE c.ManagerID = @ManagerID
      AND (@Search IS NULL OR c.FullName LIKE N'%' + @Search + N'%'
                           OR c.CompanyName LIKE N'%' + @Search + N'%'
                           OR c.Phone LIKE N'%' + @Search + N'%')
      AND (@StatusID IS NULL OR c.StatusID = @StatusID)
    ORDER BY c.UpdatedAt DESC;
END;
GO

-- ============================================================
-- Хранимая процедура: получение всех клиентов (для администратора)
-- ============================================================
CREATE PROCEDURE sp_GetAllClients
    @Search    NVARCHAR(200) = NULL,
    @StatusID  INT = NULL,
    @ManagerID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.ClientID,
        c.FullName,
        c.CompanyName,
        c.Phone,
        c.Email,
        c.BirthDate,
        ct.TypeName   AS ClientType,
        cs.StatusName AS Status,
        ls.SourceName AS LeadSource,
        c.FirstContactDate,
        ISNULL((SELECT SUM(ISNULL(d.Budget,0)) FROM Deals d
                INNER JOIN DealStages ds ON d.StageID = ds.StageID
                WHERE d.ClientID = c.ClientID AND ds.IsCompleted = 1), 0) AS TotalPurchases,
        c.LastPurchaseDate,
        u.FullName    AS ManagerName,
        c.ManagerID,
        c.UpdatedAt
    FROM Clients c
    INNER JOIN ClientTypes    ct ON c.ClientTypeID  = ct.ClientTypeID
    INNER JOIN ClientStatuses cs ON c.StatusID      = cs.StatusID
    INNER JOIN LeadSources    ls ON c.LeadSourceID  = ls.LeadSourceID
    INNER JOIN Users          u  ON c.ManagerID     = u.UserID
    WHERE (@Search IS NULL OR c.FullName LIKE N'%' + @Search + N'%'
                           OR c.CompanyName LIKE N'%' + @Search + N'%'
                           OR c.Phone LIKE N'%' + @Search + N'%')
      AND (@StatusID  IS NULL OR c.StatusID  = @StatusID)
      AND (@ManagerID IS NULL OR c.ManagerID = @ManagerID)
    ORDER BY c.UpdatedAt DESC;
END;
GO

-- ============================================================
-- Хранимая процедура: перераспределение клиента
-- ============================================================
CREATE PROCEDURE sp_ReassignClient
    @ClientID     INT,
    @NewManagerID INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Clients
    SET ManagerID = @NewManagerID, UpdatedAt = GETDATE()
    WHERE ClientID = @ClientID;
END;
GO

-- ============================================================
-- Хранимая процедура: блокировка/разблокировка менеджера
-- ============================================================
CREATE PROCEDURE sp_ToggleUserActive
    @UserID   INT,
    @IsActive BIT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Users SET IsActive = @IsActive WHERE UserID = @UserID;
END;
GO

-- ============================================================
-- Индексы для ускорения запросов
-- ============================================================
CREATE INDEX IX_Clients_ManagerID    ON Clients(ManagerID);
CREATE INDEX IX_Clients_StatusID     ON Clients(StatusID);
CREATE INDEX IX_Deals_ClientID       ON Deals(ClientID);
CREATE INDEX IX_Deals_ManagerID      ON Deals(ManagerID);
CREATE INDEX IX_Deals_StageID        ON Deals(StageID);
CREATE INDEX IX_Deals_DealDate       ON Deals(DealDate);
CREATE INDEX IX_DealItems_DealID     ON DealItems(DealID);
CREATE INDEX IX_DealEvents_DealID    ON DealEvents(DealID);
CREATE INDEX IX_DealTasks_DealID     ON DealTasks(DealID);
CREATE INDEX IX_DealDocuments_DealID ON DealDocuments(DealID);
CREATE INDEX IX_ClientNotes_ClientID ON ClientNotes(ClientID);
CREATE INDEX IX_ClientEvents_ClientID ON ClientEvents(ClientID);
CREATE INDEX IX_Tasks_ManagerID      ON Tasks(ManagerID);
CREATE INDEX IX_Tasks_ClientID       ON Tasks(ClientID);
CREATE INDEX IX_Tasks_ScheduledAt    ON Tasks(ScheduledAt);
CREATE INDEX IX_ClientDocuments_ClientID ON ClientDocuments(ClientID);
GO

-- ============================================================
-- Тестовые данные
-- ============================================================

-- Пароли (SHA-256):
-- admin    / admin123  -> 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
-- managers / manager1  -> 0a041b9462caa4a31bac3567e0b6e6fd9100787db2ab433d96f6d178cabfce90

INSERT INTO Users (RoleID, Login, PasswordHash, FullName, Email, Phone, IsActive, IsPendingRole)
VALUES
(1, N'admin', N'240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
 N'Администратор Системы', N'admin@fsngallery.by', N'+375291000000', 1, 0),

(2, N'ivanova', N'8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
 N'Иванова Мария Сергеевна', N'ivanova@fsngallery.by', N'+375291111111', 1, 0),

(2, N'petrov', N'8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
 N'Петров Алексей Владимирович', N'petrov@fsngallery.by', N'+375292222222', 1, 0),

(2, N'sidorova', N'8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92',
 N'Сидорова Елена Николаевна', N'sidorova@fsngallery.by', N'+375293333333', 1, 0);
GO

-- Товары — только плитка (цены в BYN)
INSERT INTO Products (CategoryID, ProductName, SKU, Unit, Price)
VALUES
(1, N'Плитка напольная "Мрамор Белый" 60x60', N'FL-MW-6060',  N'м²', 89.90),
(1, N'Плитка напольная "Антрацит" 60x60',     N'FL-AN-6060',  N'м²', 62.50),
(1, N'Плитка напольная "Дерево Дуб" 20x120',  N'FL-WO-20120', N'м²', 105.00),
(2, N'Плитка настенная "Белая глянец" 30x60', N'WL-WG-3060',  N'м²', 38.50),
(2, N'Плитка настенная "Серый камень" 30x60', N'WL-GS-3060',  N'м²', 52.00),
(3, N'Мозаика стеклянная "Аква" 30x30',       N'MO-AQ-3030',  N'м²', 145.00),
(4, N'Керамогранит "Индастриал" 60x60',       N'PG-IN-6060',  N'м²', 71.00),
(4, N'Керамогранит "Лофт Серый" 80x80',       N'PG-LG-8080',  N'м²', 122.00),
(5, N'Клинкер "Терракота" 30x30',             N'CL-TE-3030',  N'м²', 58.00);
GO

-- Клиенты (белорусские номера и адреса, суммы в BYN)
INSERT INTO Clients (ManagerID, ClientTypeID, LeadSourceID, StatusID, FullName, CompanyName, Phone, Email, Address, BirthDate, FirstContactDate, TotalPurchases, LastPurchaseDate, Notes)
VALUES
(2, 2, 1, 3, N'ООО "СтройМастер"',         N'ООО "СтройМастер"',         N'+375291501020', N'info@stroymaster.by',   N'г. Минск, ул. Строителей, 15', NULL,         '2024-01-10', 27500.00, '2025-02-15', N'Крупный застройщик, постоянный клиент'),
(2, 1, 2, 2, N'Козлов Дмитрий Иванович',   NULL,                          N'+375291234567', N'kozlov@mail.ru',        N'г. Минск, ул. Ленина, 5, кв. 12', '1985-06-15', '2024-03-15', 4100.00,  '2025-01-20', N'Ремонт квартиры'),
(2, 3, 3, 2, N'ИП Смирнова Анна',          N'ИП Смирнова А.В.',          N'+375339876543', N'smirnova@gmail.com',    N'г. Минск, пр. Независимости, 88', '1990-03-22', '2024-05-20', 10500.00, '2025-03-01', N'Дизайнер интерьеров'),
(3, 2, 1, 3, N'ОАО "ТехноСтрой"',          N'ОАО "ТехноСтрой"',          N'+375176002030', N'info@technostroy.by',   N'г. Минск, ул. Промышленная, 3', NULL,          '2023-11-05', 41000.00, '2025-03-10', N'Генеральный подрядчик'),
(3, 1, 4, 1, N'Новиков Сергей Петрович',   NULL,                          N'+375295554433', N'novikov@tut.by',        N'г. Минск, ул. Садовая, 22, кв. 5', '1978-12-01', '2025-03-18', 0.00, NULL, N'Первичный контакт, интересует напольная плитка'),
(3, 2, 5, 2, N'ООО "ДизайнПроект"',        N'ООО "ДизайнПроект"',        N'+375177003040', N'design@designproject.by',N'г. Минск, пр. Победителей, 10', NULL,          '2024-07-12', 15800.00, '2025-02-28', N'Дизайн-студия'),
(4, 1, 2, 2, N'Фёдорова Ольга Михайловна', NULL,                          N'+375292223344', N'fedorova@mail.ru',      N'г. Гродно, ул. Победы, 7, кв. 34', '1992-04-15', '2024-09-01', 3100.00, '2024-12-15', N'Ремонт ванной комнаты'),
(4, 2, 1, 3, N'ОАО "МегаСтрой"',           N'ОАО "МегаСтрой"',           N'+375178004050', N'info@megastroy.by',     N'г. Минск, ул. Заводская, 1', NULL,             '2023-06-15', 68000.00, '2025-03-05', N'Крупнейший клиент компании');
GO

-- Сделки
INSERT INTO Deals (ClientID, ManagerID, StageID, DealType, Title, Budget, Priority, DealDate, Deadline, Notes)
VALUES
(1, 2, 8, N'опт',     N'Поставка для ЖК "Северный"',         27500.00, 3, '2025-02-15', '2025-04-01', N'Поставка плитки для жилого комплекса'),
(2, 2, 6, N'розница', N'Ремонт квартиры — кухня и коридор',   4100.00,  2, '2025-01-20', '2025-03-01', N'Ремонт квартиры, кухня и коридор'),
(3, 2, 5, N'розница', N'Заказ для клиента дизайнера',         10500.00, 2, '2025-03-01', '2025-05-01', N'Заказ для клиента дизайнера'),
(4, 3, 8, N'опт',     N'Поставка для офисного центра',        41000.00, 3, '2025-03-10', '2025-06-01', N'Поставка для офисного центра'),
(6, 3, 4, N'розница', N'Заказ для дизайн-проекта',            15800.00, 2, '2025-02-28', '2025-05-15', N'Заказ для дизайн-проекта'),
(5, 3, 2, N'розница', N'Первый контакт — напольная плитка',   NULL,     1, '2025-03-18', NULL,         N'Выявление потребностей'),
(7, 4, 8, N'розница', N'Ванная комната',                       3100.00,  1, '2024-12-15', '2025-02-01', N'Ванная комната'),
(8, 4, 6, N'опт',     N'Поставка для торгового центра',       68000.00, 3, '2025-03-05', '2025-07-01', N'Поставка для торгового центра');
GO

-- Заметки
INSERT INTO ClientNotes (ClientID, AuthorID, NoteText)
VALUES
(1, 2, N'Обсудили новый проект ЖК "Западный". Ожидаем заявку на 500 м² керамогранита.'),
(1, 2, N'Клиент запросил каталог новинок 2026 года. Отправлен по email.'),
(2, 2, N'Клиент доволен качеством плитки. Рекомендует нас знакомым.'),
(4, 3, N'Переговоры о долгосрочном контракте на поставку. Встреча назначена на следующую неделю.'),
(6, 3, N'Дизайнер работает над проектом загородного дома. Интересует мозаика и керамогранит.'),
(8, 4, N'Обсуждаем поставку для нового торгового центра в Подмосковье. Объём ~2000 м².'),
(8, 4, N'Клиент запросил скидку 5% при объёме от 1000 м². Согласовано с руководством.');
GO

-- Примеры событий в ленте
INSERT INTO ClientEvents (ClientID, AuthorID, EventType, EventDate, Title, Description)
VALUES
(1, 2, N'call',    '2025-02-10 10:30:00', N'Звонок по новому проекту',          N'Обсудили детали поставки для ЖК "Северный"'),
(1, 2, N'meeting', '2025-02-12 14:00:00', N'Встреча в офисе клиента',            N'Подписание договора на поставку'),
(1, 2, N'email',   '2025-02-13 09:00:00', N'Отправлен каталог новинок',          N'По запросу клиента'),
(2, 2, N'call',    '2025-01-18 11:00:00', N'Звонок по выбору плитки',            N'Обсудили варианты для кухни'),
(4, 3, N'meeting', '2025-03-08 15:00:00', N'Переговоры о долгосрочном контракте', N'Встреча с директором компании');
GO

-- Пример задач
INSERT INTO Tasks (ClientID, ManagerID, TaskType, Title, Description, ScheduledAt)
VALUES
(1, 2, N'call',    N'Позвонить по статусу отгрузки',   N'Уточнить дату отгрузки товара',  DATEADD(DAY, 1, GETDATE())),
(4, 3, N'meeting', N'Встреча по новому контракту',     N'Обсудить условия нового договора', DATEADD(DAY, 3, GETDATE())),
(5, 3, N'call',    N'Уточнить бюджет клиента',         N'Позвонить и уточнить бюджет на ремонт', DATEADD(DAY, -1, GETDATE())); -- просроченная задача
GO

-- Пример планов продаж
INSERT INTO SalesPlans (PlanYear, PlanMonth, TargetAmount, CreatedBy)
VALUES
(2026, 4, 150000.00, 1),
(2026, 5, 180000.00, 1);
GO

-- Пример квот
INSERT INTO ManagerQuotas (ManagerID, QuotaYear, QuotaMonth, QuotaType, TargetValue, CreatedBy)
VALUES
(2, 2026, 4, N'sales_amount',  50000.00, 1),
(2, 2026, 4, N'deals_count',   5.00,     1),
(3, 2026, 4, N'sales_amount',  60000.00, 1),
(3, 2026, 4, N'new_clients',   3.00,     1),
(4, 2026, 4, N'sales_amount',  40000.00, 1),
(4, 2026, 4, N'plan_percent',  80.00,    1);
GO

PRINT N'База данных TileCompanyDB успешно создана и заполнена тестовыми данными.';
GO
