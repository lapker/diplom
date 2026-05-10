-- ============================================================
-- МИГРАЦИЯ: Добавление новых функций FSN GALLERY CRM
-- ============================================================

USE TileCompanyDB;
GO

-- ============================================================
-- 1. Обновление таблицы Products (плитка в штуках)
-- ============================================================

-- Добавляем новые поля к Products
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Products') AND name='TileWidth')
    ALTER TABLE Products ADD TileWidth  DECIMAL(10,2) NULL;  -- ширина в мм
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Products') AND name='TileLength')
    ALTER TABLE Products ADD TileLength DECIMAL(10,2) NULL;  -- длина в мм
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Products') AND name='TileThickness')
    ALTER TABLE Products ADD TileThickness DECIMAL(10,2) NULL; -- толщина в мм
GO

-- Обновляем Unit для всех товаров на 'шт.'
UPDATE Products SET Unit = N'шт.' WHERE Unit = N'м²' OR Unit IS NULL OR Unit = '';
GO

-- Обновляем seed-данные: добавляем размеры плитки
-- Плитка напольная "Мрамор Белый" 60x60
UPDATE Products SET TileWidth=600, TileLength=600, TileThickness=10 WHERE SKU='FL-MW-6060';
-- Плитка напольная "Антрацит" 60x60
UPDATE Products SET TileWidth=600, TileLength=600, TileThickness=10 WHERE SKU='FL-AN-6060';
-- Плитка напольная "Дерево Дуб" 20x120
UPDATE Products SET TileWidth=200, TileLength=1200, TileThickness=10 WHERE SKU='FL-WO-20120';
-- Плитка настенная "Белая глянец" 30x60
UPDATE Products SET TileWidth=300, TileLength=600, TileThickness=8 WHERE SKU='WL-WG-3060';
-- Плитка настенная "Серый камень" 30x60
UPDATE Products SET TileWidth=300, TileLength=600, TileThickness=8 WHERE SKU='WL-GS-3060';
-- Мозаика стеклянная "Аква" 30x30
UPDATE Products SET TileWidth=300, TileLength=300, TileThickness=6 WHERE SKU='MO-AQ-3030';
-- Керамогранит "Индастриал" 60x60
UPDATE Products SET TileWidth=600, TileLength=600, TileThickness=10 WHERE SKU='PG-IN-6060';
-- Керамогранит "Лофт Серый" 80x80
UPDATE Products SET TileWidth=800, TileLength=800, TileThickness=10 WHERE SKU='PG-LG-8080';
-- Клинкер "Терракота" 30x30
UPDATE Products SET TileWidth=300, TileLength=300, TileThickness=12 WHERE SKU='CL-TE-3030';
GO

-- ============================================================
-- 2. Таблица коммерческих предложений
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'CommercialOffers') AND type='U')
BEGIN
    CREATE TABLE CommercialOffers (
        OfferID       INT IDENTITY(1,1) PRIMARY KEY,
        OfferNumber   NVARCHAR(50)  NOT NULL UNIQUE,   -- КП-2026-00001
        ClientID      INT NOT NULL REFERENCES Clients(ClientID) ON DELETE CASCADE,
        DealID        INT NULL,                         -- сделка (если применено)
        CreatedBy     INT NOT NULL REFERENCES Users(UserID),
        CreatedAt     DATETIME2 NOT NULL DEFAULT GETDATE(),
        ExpiresAt     DATE NOT NULL,                    -- срок действия
        Status        NVARCHAR(20) NOT NULL DEFAULT N'active', -- 'active','expired','used'
        Notes         NVARCHAR(MAX) NULL,
        UsedAt        DATETIME2 NULL,
        UsedInDealID  INT NULL,                         -- в какой сделке использовано
    );
END
GO

-- Таблица позиций КП
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'CommercialOfferItems') AND type='U')
BEGIN
    CREATE TABLE CommercialOfferItems (
        ItemID        INT IDENTITY(1,1) PRIMARY KEY,
        OfferID       INT NOT NULL REFERENCES CommercialOffers(OfferID) ON DELETE CASCADE,
        ProductID     INT NOT NULL REFERENCES Products(ProductID),
        DiscountPct   DECIMAL(5,2) NOT NULL DEFAULT 0, -- скидка в % (1-100)
        CONSTRAINT UQ_OfferItem UNIQUE (OfferID, ProductID)
    );
END
GO

-- Счётчик для нумерации КП
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID(N'OfferNumberSequence') AND type='U')
BEGIN
    CREATE TABLE OfferNumberSequence (
        SeqYear  INT NOT NULL,
        SeqValue INT NOT NULL DEFAULT 0,
        CONSTRAINT PK_OfferSeq PRIMARY KEY (SeqYear)
    );
END
GO

-- Индексы для КП
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CommercialOffers_ClientID')
    CREATE INDEX IX_CommercialOffers_ClientID ON CommercialOffers(ClientID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_CommercialOffers_CreatedBy')
    CREATE INDEX IX_CommercialOffers_CreatedBy ON CommercialOffers(CreatedBy);
GO

-- Добавляем поле AppliedOfferID в Deals (применённое КП)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('Deals') AND name='AppliedOfferID')
    ALTER TABLE Deals ADD AppliedOfferID INT NULL;
GO

PRINT N'Миграция выполнена успешно.';
GO
