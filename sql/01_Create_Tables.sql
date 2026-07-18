/*
================================================================================
  SnapDB Project - Table Creation Script
  Schemas: SnapFood | SnapTaxi | SnapFinance (shared wallets & pricing)
  Database Engine: Microsoft SQL Server 2019+
  Normalization: Third Normal Form (3NF)
================================================================================
  Run order: Execute this script first, then 02, 03, 04.
================================================================================
*/

USE master;
GO

IF DB_ID(N'SnapDB') IS NOT NULL
BEGIN
    ALTER DATABASE SnapDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SnapDB;
END
GO

CREATE DATABASE SnapDB;
GO

USE SnapDB;
GO

/* ============================================================================
   SCHEMA CREATION
   ============================================================================ */
CREATE SCHEMA SnapFood;
GO
CREATE SCHEMA SnapTaxi;
GO
CREATE SCHEMA SnapFinance;
GO

/* ============================================================================
   SNAPFINANCE - Shared financial & access-control layer
   ============================================================================ */

-- Lookup: wallet owner types (Customer, Restaurant, Driver, Platform)
CREATE TABLE SnapFinance.WalletOwnerTypes (
    OwnerTypeID   TINYINT       NOT NULL PRIMARY KEY,
    TypeName      NVARCHAR(30)  NOT NULL UNIQUE,
    Description   NVARCHAR(200) NULL
);

-- Lookup: transaction types
CREATE TABLE SnapFinance.TransactionTypes (
    TransactionTypeID TINYINT      NOT NULL PRIMARY KEY,
    TypeName          NVARCHAR(30) NOT NULL UNIQUE
);

-- Configurable revenue-split rules (restaurant %, driver %, platform %)
CREATE TABLE SnapFinance.RevenueSplitRules (
    RuleID            INT            IDENTITY(1,1) PRIMARY KEY,
    RuleName          NVARCHAR(100)  NOT NULL,
    RestaurantPct     DECIMAL(5,2)   NOT NULL CHECK (RestaurantPct BETWEEN 0 AND 100),
    DriverPct         DECIMAL(5,2)   NOT NULL CHECK (DriverPct BETWEEN 0 AND 100),
    PlatformPct       DECIMAL(5,2)   NOT NULL CHECK (PlatformPct BETWEEN 0 AND 100),
    IsActive          BIT            NOT NULL DEFAULT 1,
    EffectiveFrom     DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveTo       DATETIME2      NULL,
    CONSTRAINT CK_RevenueSplit_Total100 CHECK (RestaurantPct + DriverPct + PlatformPct = 100)
);

-- Refund policy tiers based on cancellation timing
CREATE TABLE SnapFinance.RefundPolicies (
    PolicyID          INT            IDENTITY(1,1) PRIMARY KEY,
    PolicyName        NVARCHAR(100)  NOT NULL,
    MinutesBeforePrep INT            NOT NULL,  -- cancel >= this many minutes after order => refund %
    RefundPct         DECIMAL(5,2)   NOT NULL CHECK (RefundPct BETWEEN 0 AND 100),
    AppliesTo         NVARCHAR(20)   NOT NULL CHECK (AppliesTo IN ('FOOD','RIDE','BOTH')),
    IsActive          BIT            NOT NULL DEFAULT 1
);

-- Dynamic pricing configuration (distance, demand, time-of-day multipliers)
CREATE TABLE SnapFinance.PricingRules (
    RuleID            INT            IDENTITY(1,1) PRIMARY KEY,
    RuleName          NVARCHAR(100)  NOT NULL,
    ServiceType       NVARCHAR(20)   NOT NULL CHECK (ServiceType IN ('DELIVERY','RIDE')),
    BaseFare          DECIMAL(10,2)  NOT NULL CHECK (BaseFare >= 0),
    PerKmRate         DECIMAL(10,2)  NOT NULL CHECK (PerKmRate >= 0),
    PerMinuteRate     DECIMAL(10,2)  NOT NULL DEFAULT 0,
    DemandMultiplier  DECIMAL(5,2)   NOT NULL DEFAULT 1.0,
    MinFare           DECIMAL(10,2)  NOT NULL DEFAULT 0,
    IsActive          BIT            NOT NULL DEFAULT 1
);

-- User roles for access control (bonus feature)
CREATE TABLE SnapFinance.UserRoles (
    RoleID            TINYINT        NOT NULL PRIMARY KEY,
    RoleName          NVARCHAR(50)   NOT NULL UNIQUE,
    Description       NVARCHAR(200)  NULL
);

CREATE TABLE SnapFinance.RolePermissions (
    PermissionID      INT            IDENTITY(1,1) PRIMARY KEY,
    RoleID            TINYINT        NOT NULL REFERENCES SnapFinance.UserRoles(RoleID),
    PermissionName    NVARCHAR(100)  NOT NULL,
    CanRead           BIT            NOT NULL DEFAULT 0,
    CanWrite          BIT            NOT NULL DEFAULT 0,
    CanDelete         BIT            NOT NULL DEFAULT 0,
    CONSTRAINT UQ_RolePermission UNIQUE (RoleID, PermissionName)
);

-- Unified user accounts
CREATE TABLE SnapFinance.Users (
    UserID            INT            IDENTITY(1,1) PRIMARY KEY,
    Username          NVARCHAR(50)   NOT NULL UNIQUE,
    Email             NVARCHAR(100)  NOT NULL UNIQUE,
    PasswordHash      NVARCHAR(256)  NOT NULL,
    RoleID            TINYINT        NOT NULL REFERENCES SnapFinance.UserRoles(RoleID),
    IsActive          BIT            NOT NULL DEFAULT 1,
    CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Four distinct wallet types mapped to owner entities
CREATE TABLE SnapFinance.Wallets (
    WalletID          INT            IDENTITY(1,1) PRIMARY KEY,
    OwnerTypeID       TINYINT        NOT NULL REFERENCES SnapFinance.WalletOwnerTypes(OwnerTypeID),
    OwnerEntityID     INT            NOT NULL,  -- FK to Customer/Restaurant/Driver; 0 for Platform
    Balance           DECIMAL(14,2)  NOT NULL DEFAULT 0 CHECK (Balance >= 0),
    Currency          CHAR(3)        NOT NULL DEFAULT 'IRR',
    IsActive          BIT            NOT NULL DEFAULT 1,
    CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Wallet_Owner UNIQUE (OwnerTypeID, OwnerEntityID)
);

-- Immutable financial transaction ledger
CREATE TABLE SnapFinance.WalletTransactions (
    TransactionID     BIGINT         IDENTITY(1,1) PRIMARY KEY,
    WalletID          INT            NOT NULL REFERENCES SnapFinance.Wallets(WalletID),
    TransactionTypeID TINYINT        NOT NULL REFERENCES SnapFinance.TransactionTypes(TransactionTypeID),
    Amount            DECIMAL(14,2)  NOT NULL,
    BalanceAfter      DECIMAL(14,2)  NOT NULL,
    ReferenceType     NVARCHAR(30)   NULL,  -- FOOD_ORDER, RIDE, REFUND, etc.
    ReferenceID       INT            NULL,
    Description       NVARCHAR(300)  NULL,
    CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapFinance.FinanceAuditLog (
    LogID             BIGINT         IDENTITY(1,1) PRIMARY KEY,
    TableName         NVARCHAR(128)  NOT NULL,
    Operation         CHAR(1)        NOT NULL CHECK (Operation IN ('I','U','D')),
    RecordID          NVARCHAR(50)   NULL,
    OldValues         NVARCHAR(MAX)  NULL,
    NewValues         NVARCHAR(MAX)  NULL,
    ChangedBy         NVARCHAR(100)  NULL DEFAULT SYSTEM_USER,
    ChangedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

/* ============================================================================
   SNAPFOOD - Online Food Ordering System (12 tables)
   ============================================================================ */

CREATE TABLE SnapFood.Customers (
    CustomerID        INT            IDENTITY(1,1) PRIMARY KEY,
    UserID            INT            NULL REFERENCES SnapFinance.Users(UserID),
    FirstName         NVARCHAR(50)   NOT NULL,
    LastName          NVARCHAR(50)   NOT NULL,
    Phone             NVARCHAR(20)   NOT NULL UNIQUE,
    Email             NVARCHAR(100)  NOT NULL UNIQUE,
    RegisteredAt      DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive          BIT            NOT NULL DEFAULT 1
);

CREATE TABLE SnapFood.Restaurants (
    RestaurantID      INT            IDENTITY(1,1) PRIMARY KEY,
    Name              NVARCHAR(100)  NOT NULL,
    CuisineType       NVARCHAR(50)   NOT NULL,
    Address           NVARCHAR(200)  NOT NULL,
    Latitude          DECIMAL(10,7)  NOT NULL,
    Longitude         DECIMAL(10,7)  NOT NULL,
    Phone             NVARCHAR(20)   NOT NULL,
    Rating            DECIMAL(3,2)   NULL CHECK (Rating BETWEEN 0 AND 5),
    IsActive          BIT            NOT NULL DEFAULT 1,
    CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapFood.RestaurantManagers (
    ManagerID         INT            IDENTITY(1,1) PRIMARY KEY,
    RestaurantID      INT            NOT NULL REFERENCES SnapFood.Restaurants(RestaurantID),
    UserID            INT            NOT NULL REFERENCES SnapFinance.Users(UserID),
    AssignedAt        DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_RestaurantManager UNIQUE (RestaurantID, UserID)
);

CREATE TABLE SnapFood.MenuCategories (
    CategoryID        INT            IDENTITY(1,1) PRIMARY KEY,
    RestaurantID      INT            NOT NULL REFERENCES SnapFood.Restaurants(RestaurantID),
    CategoryName      NVARCHAR(60)   NOT NULL,
    DisplayOrder      INT            NOT NULL DEFAULT 0,
    CONSTRAINT UQ_CategoryPerRestaurant UNIQUE (RestaurantID, CategoryName)
);

CREATE TABLE SnapFood.MenuItems (
    ItemID            INT            IDENTITY(1,1) PRIMARY KEY,
    CategoryID        INT            NOT NULL REFERENCES SnapFood.MenuCategories(CategoryID),
    ItemName          NVARCHAR(100)  NOT NULL,
    Description       NVARCHAR(300)  NULL,
    Price             DECIMAL(10,2)  NOT NULL CHECK (Price > 0),
    IsAvailable       BIT            NOT NULL DEFAULT 1,
    PrepTimeMinutes   INT            NOT NULL DEFAULT 15 CHECK (PrepTimeMinutes > 0)
);

CREATE TABLE SnapFood.CustomerAddresses (
    AddressID         INT            IDENTITY(1,1) PRIMARY KEY,
    CustomerID        INT            NOT NULL REFERENCES SnapFood.Customers(CustomerID),
    Label             NVARCHAR(30)   NOT NULL,
    StreetAddress     NVARCHAR(200)  NOT NULL,
    City              NVARCHAR(50)   NOT NULL,
    Latitude          DECIMAL(10,7)  NOT NULL,
    Longitude         DECIMAL(10,7)  NOT NULL,
    IsDefault         BIT            NOT NULL DEFAULT 0
);

CREATE TABLE SnapFood.DiscountCodes (
    DiscountID        INT            IDENTITY(1,1) PRIMARY KEY,
    Code              NVARCHAR(30)   NOT NULL UNIQUE,
    DiscountType      NVARCHAR(10)   NOT NULL CHECK (DiscountType IN ('PERCENT','FIXED')),
    DiscountValue     DECIMAL(10,2)  NOT NULL CHECK (DiscountValue > 0),
    MinOrderValue     DECIMAL(10,2)  NOT NULL DEFAULT 0,
    MaxUsageCount     INT            NOT NULL DEFAULT 100,
    UsedCount         INT            NOT NULL DEFAULT 0,
    ValidFrom         DATETIME2      NOT NULL,
    ValidTo           DATETIME2      NOT NULL,
    IsActive          BIT            NOT NULL DEFAULT 1,
    CONSTRAINT CK_Discount_Dates CHECK (ValidTo > ValidFrom)
);

CREATE TABLE SnapFood.FoodOrders (
    OrderID           INT            IDENTITY(1,1) PRIMARY KEY,
    CustomerID        INT            NOT NULL REFERENCES SnapFood.Customers(CustomerID),
    RestaurantID      INT            NOT NULL REFERENCES SnapFood.Restaurants(RestaurantID),
    DeliveryAddressID INT            NOT NULL REFERENCES SnapFood.CustomerAddresses(AddressID),
    DiscountID        INT            NULL REFERENCES SnapFood.DiscountCodes(DiscountID),
    OrderStatus       NVARCHAR(20)   NOT NULL DEFAULT 'PENDING'
                      CHECK (OrderStatus IN ('PENDING','CONFIRMED','PREPARING','READY',
                                             'OUT_FOR_DELIVERY','DELIVERED','CANCELLED')),
    Subtotal          DECIMAL(12,2)  NOT NULL DEFAULT 0,
    DiscountAmount    DECIMAL(12,2)  NOT NULL DEFAULT 0,
    DeliveryFee       DECIMAL(10,2)  NOT NULL DEFAULT 0,
    TotalAmount       DECIMAL(12,2)  NOT NULL DEFAULT 0,
    DistanceKm        DECIMAL(8,3)   NULL,
    PlacedAt          DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    ConfirmedAt       DATETIME2      NULL,
    DeliveredAt       DATETIME2      NULL,
    CancelledAt       DATETIME2      NULL,
    CancellationReason NVARCHAR(200) NULL
);

CREATE TABLE SnapFood.OrderItems (
    OrderItemID       INT            IDENTITY(1,1) PRIMARY KEY,
    OrderID           INT            NOT NULL REFERENCES SnapFood.FoodOrders(OrderID),
    ItemID            INT            NOT NULL REFERENCES SnapFood.MenuItems(ItemID),
    Quantity          INT            NOT NULL CHECK (Quantity > 0),
    UnitPrice         DECIMAL(10,2)  NOT NULL CHECK (UnitPrice > 0),
    LineTotal         AS (Quantity * UnitPrice) PERSISTED
);

CREATE TABLE SnapFood.OrderStatusHistory (
    HistoryID         INT            IDENTITY(1,1) PRIMARY KEY,
    OrderID           INT            NOT NULL REFERENCES SnapFood.FoodOrders(OrderID),
    OldStatus         NVARCHAR(20)   NULL,
    NewStatus         NVARCHAR(20)   NOT NULL,
    ChangedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    ChangedBy         NVARCHAR(100)  NULL DEFAULT SYSTEM_USER
);

CREATE TABLE SnapFood.Reviews (
    ReviewID          INT            IDENTITY(1,1) PRIMARY KEY,
    OrderID           INT            NOT NULL REFERENCES SnapFood.FoodOrders(OrderID) UNIQUE,
    CustomerID        INT            NOT NULL REFERENCES SnapFood.Customers(CustomerID),
    RestaurantID      INT            NOT NULL REFERENCES SnapFood.Restaurants(RestaurantID),
    Rating            TINYINT        NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comment           NVARCHAR(500)  NULL,
    CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapFood.FoodAuditLog (
    LogID             BIGINT         IDENTITY(1,1) PRIMARY KEY,
    TableName         NVARCHAR(128)  NOT NULL,
    Operation         CHAR(1)        NOT NULL CHECK (Operation IN ('I','U','D')),
    RecordID          NVARCHAR(50)   NULL,
    OldValues         NVARCHAR(MAX)  NULL,
    NewValues         NVARCHAR(MAX)  NULL,
    ChangedBy         NVARCHAR(100)  NULL DEFAULT SYSTEM_USER,
    ChangedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

/* ============================================================================
   SNAPTAXI - Online Taxi & Delivery Fleet (12 tables)
   ============================================================================ */

CREATE TABLE SnapTaxi.VehicleTypes (
    VehicleTypeID     TINYINT        NOT NULL PRIMARY KEY,
    TypeName          NVARCHAR(30)   NOT NULL UNIQUE,
    MaxCapacityKg     DECIMAL(6,2)   NOT NULL,
    BaseMultiplier    DECIMAL(4,2)   NOT NULL DEFAULT 1.0
);

CREATE TABLE SnapTaxi.Drivers (
    DriverID          INT            IDENTITY(1,1) PRIMARY KEY,
    UserID            INT            NULL REFERENCES SnapFinance.Users(UserID),
    FirstName         NVARCHAR(50)   NOT NULL,
    LastName          NVARCHAR(50)   NOT NULL,
    Phone             NVARCHAR(20)   NOT NULL UNIQUE,
    LicenseNumber     NVARCHAR(30)   NOT NULL UNIQUE,
    Rating            DECIMAL(3,2)   NULL CHECK (Rating BETWEEN 0 AND 5),
    HiredAt           DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive          BIT            NOT NULL DEFAULT 1
);

CREATE TABLE SnapTaxi.Vehicles (
    VehicleID         INT            IDENTITY(1,1) PRIMARY KEY,
    DriverID          INT            NOT NULL REFERENCES SnapTaxi.Drivers(DriverID),
    VehicleTypeID     TINYINT        NOT NULL REFERENCES SnapTaxi.VehicleTypes(VehicleTypeID),
    PlateNumber       NVARCHAR(20)   NOT NULL UNIQUE,
    Make              NVARCHAR(40)   NOT NULL,
    Model             NVARCHAR(40)   NOT NULL,
    Year              SMALLINT       NOT NULL,
    IsActive          BIT            NOT NULL DEFAULT 1
);

CREATE TABLE SnapTaxi.DeliveryZones (
    ZoneID            INT            IDENTITY(1,1) PRIMARY KEY,
    ZoneName          NVARCHAR(60)   NOT NULL UNIQUE,
    CenterLatitude    DECIMAL(10,7)  NOT NULL,
    CenterLongitude   DECIMAL(10,7)  NOT NULL,
    RadiusKm          DECIMAL(6,2)   NOT NULL CHECK (RadiusKm > 0)
);

CREATE TABLE SnapTaxi.ZonePricing (
    ZonePricingID     INT            IDENTITY(1,1) PRIMARY KEY,
    ZoneID            INT            NOT NULL REFERENCES SnapTaxi.DeliveryZones(ZoneID),
    ServiceType       NVARCHAR(20)   NOT NULL CHECK (ServiceType IN ('DELIVERY','RIDE')),
    SurgeMultiplier   DECIMAL(4,2)   NOT NULL DEFAULT 1.0 CHECK (SurgeMultiplier >= 1.0),
    EffectiveFrom     DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    EffectiveTo       DATETIME2      NULL
);

CREATE TABLE SnapTaxi.DriverLocations (
    LocationID        BIGINT         IDENTITY(1,1) PRIMARY KEY,
    DriverID          INT            NOT NULL REFERENCES SnapTaxi.Drivers(DriverID),
    Latitude          DECIMAL(10,7)  NOT NULL,
    Longitude         DECIMAL(10,7)  NOT NULL,
    RecordedAt        DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapTaxi.DriverAvailability (
    AvailabilityID    INT            IDENTITY(1,1) PRIMARY KEY,
    DriverID          INT            NOT NULL REFERENCES SnapTaxi.Drivers(DriverID) UNIQUE,
    IsOnline          BIT            NOT NULL DEFAULT 0,
    IsIdle            BIT            NOT NULL DEFAULT 1,
    CurrentZoneID     INT            NULL REFERENCES SnapTaxi.DeliveryZones(ZoneID),
    LastStatusChange  DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapTaxi.DemandMetrics (
    MetricID          INT            IDENTITY(1,1) PRIMARY KEY,
    ZoneID            INT            NOT NULL REFERENCES SnapTaxi.DeliveryZones(ZoneID),
    RecordedAt        DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    PendingRequests   INT            NOT NULL DEFAULT 0,
    ActiveDrivers     INT            NOT NULL DEFAULT 0,
    DemandIndex       AS (
        CASE WHEN ActiveDrivers = 0 THEN 2.0
             ELSE CAST(PendingRequests AS DECIMAL(8,2)) / ActiveDrivers
        END
    ) PERSISTED
);

CREATE TABLE SnapTaxi.Rides (
    RideID            INT            IDENTITY(1,1) PRIMARY KEY,
    CustomerID        INT            NULL,  -- optional passenger (non-food ride)
    DriverID          INT            NULL REFERENCES SnapTaxi.Drivers(DriverID),
    PickupLatitude    DECIMAL(10,7)  NOT NULL,
    PickupLongitude   DECIMAL(10,7)  NOT NULL,
    DropoffLatitude   DECIMAL(10,7)  NOT NULL,
    DropoffLongitude  DECIMAL(10,7)  NOT NULL,
    DistanceKm        DECIMAL(8,3)   NOT NULL,
    EstimatedMinutes  INT            NOT NULL,
    RideStatus        NVARCHAR(20)   NOT NULL DEFAULT 'REQUESTED'
                      CHECK (RideStatus IN ('REQUESTED','ASSIGNED','IN_PROGRESS','COMPLETED','CANCELLED')),
    BaseFare          DECIMAL(10,2)  NOT NULL DEFAULT 0,
    SurgeMultiplier   DECIMAL(4,2)   NOT NULL DEFAULT 1.0,
    TotalFare         DECIMAL(10,2)  NOT NULL DEFAULT 0,
    RequestedAt       DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    CompletedAt       DATETIME2      NULL,
    CancelledAt       DATETIME2      NULL
);

CREATE TABLE SnapTaxi.RideStatusHistory (
    HistoryID         INT            IDENTITY(1,1) PRIMARY KEY,
    RideID            INT            NOT NULL REFERENCES SnapTaxi.Rides(RideID),
    OldStatus         NVARCHAR(20)   NULL,
    NewStatus         NVARCHAR(20)   NOT NULL,
    ChangedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE SnapTaxi.DeliveryAssignments (
    AssignmentID      INT            IDENTITY(1,1) PRIMARY KEY,
    FoodOrderID       INT            NOT NULL REFERENCES SnapFood.FoodOrders(OrderID) UNIQUE,
    DriverID          INT            NOT NULL REFERENCES SnapTaxi.Drivers(DriverID),
    RideID            INT            NULL REFERENCES SnapTaxi.Rides(RideID),
    AssignmentStatus  NVARCHAR(20)   NOT NULL DEFAULT 'ASSIGNED'
                      CHECK (AssignmentStatus IN ('ASSIGNED','PICKED_UP','DELIVERED','CANCELLED')),
    AssignedAt        DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    DeliveredAt       DATETIME2      NULL
);

CREATE TABLE SnapTaxi.TaxiAuditLog (
    LogID             BIGINT         IDENTITY(1,1) PRIMARY KEY,
    TableName         NVARCHAR(128)  NOT NULL,
    Operation         CHAR(1)        NOT NULL CHECK (Operation IN ('I','U','D')),
    RecordID          NVARCHAR(50)   NULL,
    OldValues         NVARCHAR(MAX)  NULL,
    NewValues         NVARCHAR(MAX)  NULL,
    ChangedBy         NVARCHAR(100)  NULL DEFAULT SYSTEM_USER,
    ChangedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
);

/* ============================================================================
   INDEXES for performance on hot paths
   ============================================================================ */
CREATE INDEX IX_FoodOrders_Status       ON SnapFood.FoodOrders(OrderStatus);
CREATE INDEX IX_FoodOrders_Customer     ON SnapFood.FoodOrders(CustomerID);
CREATE INDEX IX_DriverAvailability_Online ON SnapTaxi.DriverAvailability(IsOnline, IsIdle);
CREATE INDEX IX_DriverLocations_Driver  ON SnapTaxi.DriverLocations(DriverID, RecordedAt DESC);
CREATE INDEX IX_WalletTransactions_Wallet ON SnapFinance.WalletTransactions(WalletID, CreatedAt DESC);
CREATE INDEX IX_DeliveryAssignments_Order ON SnapTaxi.DeliveryAssignments(FoodOrderID);

PRINT 'SnapDB tables created successfully.';
GO
