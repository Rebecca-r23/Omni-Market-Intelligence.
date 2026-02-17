/* 1. Create Database only if it doesn't exist */
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'OmniMI')
BEGIN
  CREATE DATABASE OmniMI;
END;
GO

USE OmniMI;
GO

/* 2. Clean start (Drops child tables before parent tables to avoid FK errors) */
IF OBJECT_ID('dbo.web_logs','U') IS NOT NULL DROP TABLE dbo.web_logs;
IF OBJECT_ID('dbo.social_sentiments','U') IS NOT NULL DROP TABLE dbo.social_sentiments;
IF OBJECT_ID('dbo.market_trends','U') IS NOT NULL DROP TABLE dbo.market_trends;
IF OBJECT_ID('dbo.transaction_items','U') IS NOT NULL DROP TABLE dbo.transaction_items;
IF OBJECT_ID('dbo.transactions','U') IS NOT NULL DROP TABLE dbo.transactions;
IF OBJECT_ID('dbo.products','U') IS NOT NULL DROP TABLE dbo.products;
IF OBJECT_ID('dbo.customers','U') IS NOT NULL DROP TABLE dbo.customers;
GO

/* 3. Schema Definitions */

-- Customers
CREATE TABLE dbo.customers (
  customer_id      INT IDENTITY(1,1) PRIMARY KEY,
  email            NVARCHAR(255) NOT NULL UNIQUE,
  first_name       NVARCHAR(100) NOT NULL,
  last_name        NVARCHAR(100) NOT NULL,
  phone            NVARCHAR(50) NULL,
  date_of_birth    DATE NULL,
  loyalty_tier     NVARCHAR(20) NOT NULL CHECK (loyalty_tier IN ('Bronze','Silver','Gold','Platinum')),
  created_at       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  home_store_code  NVARCHAR(10) NULL,
  city             NVARCHAR(80) NULL,
  state_region     NVARCHAR(80) NULL,
  country          NVARCHAR(80) NOT NULL DEFAULT 'US'
);

-- Products
CREATE TABLE dbo.products (
  product_id       INT IDENTITY(1,1) PRIMARY KEY,
  sku              NVARCHAR(60) NOT NULL UNIQUE,
  product_name     NVARCHAR(255) NOT NULL,
  category         NVARCHAR(80) NOT NULL,
  brand            NVARCHAR(80) NOT NULL DEFAULT 'OurBrand',
  current_price    DECIMAL(10,2) NOT NULL CHECK (current_price >= 0),
  cost             DECIMAL(10,2) NULL CHECK (cost >= 0),
  is_active        BIT NOT NULL DEFAULT 1,
  launched_at      DATE NULL,
  updated_at       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Transactions
CREATE TABLE dbo.transactions (
  transaction_id   INT IDENTITY(1,1) PRIMARY KEY,
  customer_id      INT NOT NULL,
  transaction_ts   DATETIME2 NOT NULL,
  channel          NVARCHAR(20) NOT NULL CHECK (channel IN ('Web','App','In-Store')),
  store_code       NVARCHAR(10) NULL,
  order_number     NVARCHAR(30) NOT NULL UNIQUE,
  currency         CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal_amount  DECIMAL(12,2) NOT NULL CHECK (subtotal_amount >= 0),
  discount_amount  DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  tax_amount       DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
  total_amount     AS (subtotal_amount - discount_amount + tax_amount) PERSISTED,
  CONSTRAINT FK_transactions_customers FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id)
);

-- Transaction line items
CREATE TABLE dbo.transaction_items (
  transaction_item_id INT IDENTITY(1,1) PRIMARY KEY,
  transaction_id      INT NOT NULL,
  product_id          INT NOT NULL,
  quantity            INT NOT NULL CHECK (quantity > 0),
  unit_price          DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  line_total          AS (quantity * unit_price) PERSISTED,
  CONSTRAINT FK_ti_txn FOREIGN KEY (transaction_id) REFERENCES dbo.transactions(transaction_id),
  CONSTRAINT FK_ti_product FOREIGN KEY (product_id) REFERENCES dbo.products(product_id)
);

-- Web Logs
CREATE TABLE dbo.web_logs (
  web_log_id      INT IDENTITY(1,1) PRIMARY KEY,
  customer_id     INT NULL,
  event_ts        DATETIME2 NOT NULL,
  channel         NVARCHAR(20) NOT NULL CHECK (channel IN ('Web','App')),
  session_id      NVARCHAR(64) NOT NULL,
  event_type      NVARCHAR(40) NOT NULL,
  url             NVARCHAR(500) NULL,
  referrer        NVARCHAR(500) NULL,
  product_id      INT NULL,
  utm_source      NVARCHAR(80) NULL,
  utm_medium      NVARCHAR(80) NULL,
  utm_campaign    NVARCHAR(120) NULL,
  device_type     NVARCHAR(40) NULL,
  CONSTRAINT FK_weblog_customer FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id),
  CONSTRAINT FK_weblog_product FOREIGN KEY (product_id) REFERENCES dbo.products(product_id)
);

-- Social Sentiments
CREATE TABLE dbo.social_sentiments (
  sentiment_id    INT IDENTITY(1,1) PRIMARY KEY,
  mention_ts      DATETIME2 NOT NULL,
  platform        NVARCHAR(40) NOT NULL,
  handle          NVARCHAR(80) NULL,
  post_url        NVARCHAR(500) NULL,
  customer_id     INT NULL,
  product_id      INT NULL,
  sentiment       NVARCHAR(10) NOT NULL CHECK (sentiment IN ('positive','neutral','negative')),
  sentiment_score DECIMAL(4,3) NOT NULL CHECK (sentiment_score >= -1 AND sentiment_score <= 1),
  mention_text    NVARCHAR(1000) NOT NULL,
  brand_mentioned BIT NOT NULL DEFAULT 1,
  CONSTRAINT FK_social_customer FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id),
  CONSTRAINT FK_social_product FOREIGN KEY (product_id) REFERENCES dbo.products(product_id)
);

-- Market Trends
CREATE TABLE dbo.market_trends (
  market_trend_id  INT IDENTITY(1,1) PRIMARY KEY,
  trend_date       DATE NOT NULL,
  competitor_name  NVARCHAR(80) NOT NULL,
  product_id       INT NOT NULL,
  competitor_price DECIMAL(10,2) NOT NULL CHECK (competitor_price >= 0),
  region           NVARCHAR(80) NULL,
  currency         CHAR(3) NOT NULL DEFAULT 'USD',
  source           NVARCHAR(120) NULL,
  collected_ts     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
  CONSTRAINT FK_market_product FOREIGN KEY (product_id) REFERENCES dbo.products(product_id)
);
GO

/* 4. Performance Indexes */
CREATE INDEX IX_transactions_customer_ts ON dbo.transactions(customer_id, transaction_ts);
CREATE INDEX IX_transactions_channel_ts ON dbo.transactions(channel, transaction_ts);
CREATE INDEX IX_web_logs_customer_ts ON dbo.web_logs(customer_id, event_ts);
CREATE INDEX IX_web_logs_session_ts ON dbo.web_logs(session_id, event_ts);
CREATE INDEX IX_market_trends_product_date ON dbo.market_trends(product_id, trend_date);
GO

/* 5. Sample Data */

-- Customers
INSERT INTO dbo.customers (email, first_name, last_name, phone, date_of_birth, loyalty_tier, city, state_region) VALUES
('ava.miller@example.com','Ava','Miller','+1-415-555-0142','1992-04-12','Gold','San Francisco','CA'),
('liam.johnson@example.com','Liam','Johnson','+1-206-555-0181','1988-09-02','Silver','Seattle','WA'),
('mia.davis@example.com','Mia','Davis','+1-305-555-0129','1995-11-23','Bronze','Miami','FL'),
('noah.brown@example.com','Noah','Brown','+1-512-555-0166','1985-02-14','Platinum','Austin','TX'),
('emma.wilson@example.com','Emma','Wilson','+1-212-555-0101','1990-07-19','Gold','New York','NY');

-- Products
INSERT INTO dbo.products (sku, product_name, category, current_price, cost) VALUES
('SKU-TEE-001','Everyday Tee','Apparel',19.99,7.00),
('SKU-JEA-002','Slim Fit Jeans','Apparel',59.99,24.00),
('SKU-SHO-003','Runner Sneakers','Footwear',89.99,38.00);

-- Transactions
INSERT INTO dbo.transactions (customer_id, transaction_ts, channel, order_number, subtotal_amount, discount_amount, tax_amount) VALUES
(1,'2025-01-05T19:22:00Z','In-Store','ORD-100001',89.99,10.00,7.20),
(2,'2025-01-07T02:10:00Z','Web','ORD-100002',59.99,0.00,4.80);
GO