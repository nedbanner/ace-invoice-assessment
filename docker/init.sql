/*
  ACE Invoice DB - Docker init (idempotent-ish by drop & recreate objects)
  Creates database AceInvoice, tables, seed data, and stored procedures.

  Notes:
  - customerId/productId/lineItemId are UNIQUEIDENTIFIER (GUID)
  - invoiceNumber is INT (identity primary key)
*/

SET NOCOUNT ON;

IF DB_ID('AceInvoice') IS NULL
BEGIN
  CREATE DATABASE AceInvoice;
END
GO

USE AceInvoice;
GO

-- Required SET options for filtered indexes + computed columns when running via sqlcmd
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET ARITHABORT ON;
GO


-- Drop procs/types first (safe if rerun)
IF OBJECT_ID('dbo.usp_GetAllOrdersWithDetails', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetAllOrdersWithDetails;
IF OBJECT_ID('dbo.usp_GetAllOrdersSummary', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetAllOrdersSummary;
IF OBJECT_ID('dbo.usp_GetOrderDetails', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetOrderDetails;
IF OBJECT_ID('dbo.usp_CreateOrder', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_CreateOrder;
IF OBJECT_ID('dbo.usp_GetAllProducts', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetAllProducts;
IF OBJECT_ID('dbo.usp_GetAllCustomers', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_GetAllCustomers;
IF TYPE_ID('dbo.NewOrderProductType') IS NOT NULL DROP TYPE dbo.NewOrderProductType;
GO

-- Drop tables in dependency order
IF OBJECT_ID('dbo.OrderItems', 'U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

-- Customers
CREATE TABLE dbo.Customers
(
    CustomerId            UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Customers PRIMARY KEY
                          CONSTRAINT DF_Customers_CustomerId DEFAULT (NEWID()),

    CustomerName          NVARCHAR(200) NOT NULL,

    CustomerAddress1      NVARCHAR(200) NOT NULL,
    CustomerAddress2      NVARCHAR(200) NULL,
    CustomerCity          NVARCHAR(100) NOT NULL,
    CustomerState         NVARCHAR(50)  NOT NULL,
    CustomerPostalCode    NVARCHAR(20)  NOT NULL,

    CustomerTelephone     NVARCHAR(50)  NULL,
    CustomerContactName   NVARCHAR(200) NULL,
    CustomerEmailAddress  NVARCHAR(320) NULL,

    CreatedAtUtc          DATETIME2(0)  NOT NULL CONSTRAINT DF_Customers_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
    UpdatedAtUtc          DATETIME2(0)  NOT NULL CONSTRAINT DF_Customers_UpdatedAtUtc DEFAULT (SYSUTCDATETIME())
);
GO

CREATE INDEX IX_Customers_Name ON dbo.Customers(CustomerName);
CREATE INDEX IX_Customers_Email ON dbo.Customers(CustomerEmailAddress) WHERE CustomerEmailAddress IS NOT NULL;
GO

-- Products
CREATE TABLE dbo.Products
(
  ProductId     UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Products PRIMARY KEY
                CONSTRAINT DF_Products_ProductId DEFAULT (NEWID()),
  ProductName   NVARCHAR(200) NOT NULL,
  ProductCost   DECIMAL(12,2) NOT NULL CONSTRAINT CK_Products_Cost_NonNeg CHECK (ProductCost >= 0),
  CreatedAtUtc  DATETIME2(0)  NOT NULL CONSTRAINT DF_Products_Created DEFAULT (SYSUTCDATETIME()),
  UpdatedAtUtc  DATETIME2(0)  NOT NULL CONSTRAINT DF_Products_Updated DEFAULT (SYSUTCDATETIME())
);
GO

CREATE INDEX IX_Products_Name ON dbo.Products(ProductName);
GO

-- Orders
CREATE TABLE dbo.Orders
(
  InvoiceNumber  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
  InvoiceDate    DATETIME2(0)      NOT NULL,
  CustomerId     UNIQUEIDENTIFIER  NOT NULL,

  CreatedAtUtc   DATETIME2(0)      NOT NULL CONSTRAINT DF_Orders_Created DEFAULT (SYSUTCDATETIME()),
  UpdatedAtUtc   DATETIME2(0)      NOT NULL CONSTRAINT DF_Orders_Updated DEFAULT (SYSUTCDATETIME()),

  CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerId) REFERENCES dbo.Customers(CustomerId)
);
GO

CREATE INDEX IX_Orders_CustomerId ON dbo.Orders(CustomerId);
CREATE INDEX IX_Orders_InvoiceDate ON dbo.Orders(InvoiceDate);
GO

-- OrderItems
CREATE TABLE dbo.OrderItems
(
  LineItemId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY
                CONSTRAINT DF_OrderItems_LineItemId DEFAULT (NEWID()),

  InvoiceNumber INT              NOT NULL,
  ProductId     UNIQUEIDENTIFIER NOT NULL,
  Quantity      INT              NOT NULL CONSTRAINT CK_OrderItems_Qty_Pos CHECK (Quantity > 0),
  InvoiceDate   DATETIME2(0)     NOT NULL,

  ProductCost   DECIMAL(12,2)    NOT NULL CONSTRAINT CK_OrderItems_Cost_NonNeg CHECK (ProductCost >= 0),
  TotalCost     AS (Quantity * ProductCost) PERSISTED,

  CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (InvoiceNumber) REFERENCES dbo.Orders(InvoiceNumber) ON DELETE CASCADE,
  CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId)
);
GO

CREATE INDEX IX_OrderItems_InvoiceNumber ON dbo.OrderItems(InvoiceNumber);
GO

-- Seed Customers (match example)
INSERT INTO dbo.Customers
(
  CustomerId, CustomerName, CustomerAddress1, CustomerAddress2,
  CustomerCity, CustomerState, CustomerPostalCode,
  CustomerTelephone, CustomerContactName, CustomerEmailAddress
)
VALUES
(
  'aa5fd07a-05d6-460f-b8e3-6a09142f9d71',
  'Smith, LLC',
  '505 Central Avenue',
  'Suite 100',
  'San Diego',
  'CA',
  '90383',
  '619-483-0987',
  'Jane Smith',
  'email@jane.com'
),
(
  '15907644-3f44-448b-b64e-a949c529fa0b',
  'Doe, Inc',
  '123 Main Street',
  NULL,
  'Los Angeles',
  'CA',
  '90010',
  '310-555-1212',
  'John Doe',
  'email@doe.com'
);
GO

-- Seed Products (match example)
INSERT INTO dbo.Products (ProductId, ProductName, ProductCost)
VALUES
('26812d43-cee0-4413-9a1b-0b2eabf7e92c', 'Thingie', 2.00),
('3c85f645-ce57-43a8-b192-7f46f8bbc273', 'Gadget', 5.15),
('a102e2b7-30d6-4ab6-b92b-8570a7e1659c', 'Gizmo', 1.00),
('9e3ef8ce-a6fd-4c9b-ac5d-c3cb471e1e27', 'Widget', 2.50);
GO

-- Seed Orders so /api/order/details/5 works (insert explicit invoice numbers)
SET IDENTITY_INSERT dbo.Orders ON;
INSERT INTO dbo.Orders (InvoiceNumber, InvoiceDate, CustomerId)
VALUES
(1, '2024-12-01T10:00:00', '15907644-3f44-448b-b64e-a949c529fa0b'),
(2, '2024-12-05T09:15:00', 'aa5fd07a-05d6-460f-b8e3-6a09142f9d71'),
(3, '2024-12-10T13:45:00', '15907644-3f44-448b-b64e-a949c529fa0b'),
(4, '2024-12-15T16:20:00', 'aa5fd07a-05d6-460f-b8e3-6a09142f9d71'),
(5, '2024-12-20T14:30:00', 'aa5fd07a-05d6-460f-b8e3-6a09142f9d71');
SET IDENTITY_INSERT dbo.Orders OFF;
GO

-- Seed OrderItems for invoiceNumber 5 (match your example IDs)
INSERT INTO dbo.OrderItems (LineItemId, InvoiceNumber, ProductId, Quantity, InvoiceDate, ProductCost)
VALUES
('9d91681f-0971-4170-bba4-1617e53e7e8c', 5, '3c85f645-ce57-43a8-b192-7f46f8bbc273', 5, '2024-12-20T14:30:00', 5.15),
('91c75521-b7c5-45bb-b0c6-fdca3a89ecd9', 5, '26812d43-cee0-4413-9a1b-0b2eabf7e92c', 2, '2024-12-20T14:30:00', 2.00);
GO

-- Types/Procs
CREATE TYPE dbo.NewOrderProductType AS TABLE
(
  ProductId UNIQUEIDENTIFIER NOT NULL,
  Quantity  INT NOT NULL
);
GO

CREATE PROCEDURE dbo.usp_GetAllCustomers
AS
BEGIN
  SET NOCOUNT ON;
  SELECT
    CustomerId,
    CustomerName,
    CustomerAddress1,
    CustomerAddress2,
    CustomerCity,
    CustomerState,
    CustomerPostalCode,
    CustomerTelephone,
    CustomerContactName,
    CustomerEmailAddress
  FROM dbo.Customers
  ORDER BY CustomerName;
END
GO

CREATE PROCEDURE dbo.usp_GetAllProducts
AS
BEGIN
  SET NOCOUNT ON;
  SELECT ProductId, ProductName, ProductCost
  FROM dbo.Products
  ORDER BY ProductName;
END
GO

CREATE PROCEDURE dbo.usp_GetAllOrdersSummary
AS
BEGIN
  SET NOCOUNT ON;
  SELECT InvoiceNumber, InvoiceDate, CustomerId
  FROM dbo.Orders
  ORDER BY InvoiceNumber DESC;
END
GO

CREATE PROCEDURE dbo.usp_GetOrderDetails
  @InvoiceNumber INT
AS
BEGIN
  SET NOCOUNT ON;

  -- orderDetail
  SELECT InvoiceNumber, InvoiceDate, CustomerId
  FROM dbo.Orders
  WHERE InvoiceNumber = @InvoiceNumber;

  -- customerDetail
  SELECT
    c.CustomerId,
    c.CustomerName,
    c.CustomerAddress1,
    c.CustomerAddress2,
    c.CustomerCity,
    c.CustomerState,
    c.CustomerPostalCode,
    c.CustomerTelephone,
    c.CustomerContactName,
    c.CustomerEmailAddress
  FROM dbo.Customers c
  JOIN dbo.Orders o ON o.CustomerId = c.CustomerId
  WHERE o.InvoiceNumber = @InvoiceNumber;

  -- lineItems
  SELECT
    oi.LineItemId,
    oi.ProductId,
    oi.Quantity,
    oi.InvoiceDate,
    p.ProductName,
    oi.ProductCost,
    oi.TotalCost
  FROM dbo.OrderItems oi
  JOIN dbo.Products p ON p.ProductId = oi.ProductId
  WHERE oi.InvoiceNumber = @InvoiceNumber
  ORDER BY oi.TotalCost DESC, oi.LineItemId;
END
GO

CREATE PROCEDURE dbo.usp_GetAllOrdersWithDetails
AS
BEGIN
  SET NOCOUNT ON;

  -- Orders
  SELECT InvoiceNumber, InvoiceDate, CustomerId
  FROM dbo.Orders
  ORDER BY InvoiceNumber DESC;

  -- Customers referenced by orders
  SELECT DISTINCT
    c.CustomerId,
    c.CustomerName,
    c.CustomerAddress1,
    c.CustomerAddress2,
    c.CustomerCity,
    c.CustomerState,
    c.CustomerPostalCode,
    c.CustomerTelephone,
    c.CustomerContactName,
    c.CustomerEmailAddress
  FROM dbo.Customers c
  JOIN dbo.Orders o ON o.CustomerId = c.CustomerId;

  -- Line items
  SELECT
    oi.InvoiceNumber,
    oi.LineItemId,
    oi.ProductId,
    oi.Quantity,
    oi.InvoiceDate,
    p.ProductName,
    oi.ProductCost,
    oi.TotalCost
  FROM dbo.OrderItems oi
  JOIN dbo.Products p ON p.ProductId = oi.ProductId
  ORDER BY oi.InvoiceNumber DESC, oi.TotalCost DESC, oi.LineItemId;
END
GO

CREATE PROCEDURE dbo.usp_CreateOrder
  @InvoiceDate DATETIME2(0),
  @CustomerId UNIQUEIDENTIFIER,
  @Products dbo.NewOrderProductType READONLY
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE CustomerId = @CustomerId)
      THROW 50001, 'Customer does not exist.', 1;

    IF EXISTS (
      SELECT 1
      FROM @Products p
      LEFT JOIN dbo.Products pr ON pr.ProductId = p.ProductId
      WHERE pr.ProductId IS NULL
    )
      THROW 50002, 'One or more products do not exist.', 1;

    INSERT INTO dbo.Orders (InvoiceDate, CustomerId)
    VALUES (@InvoiceDate, @CustomerId);

    DECLARE @InvoiceNumber INT = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (InvoiceNumber, ProductId, Quantity, InvoiceDate, ProductCost)
    SELECT
      @InvoiceNumber,
      p.ProductId,
      p.Quantity,
      @InvoiceDate,
      pr.ProductCost
    FROM @Products p
    JOIN dbo.Products pr ON pr.ProductId = p.ProductId;

    COMMIT;

    SELECT @InvoiceNumber AS invoiceNumber;
  END TRY
  BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    THROW;
  END CATCH
END
GO
