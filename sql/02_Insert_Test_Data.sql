/*
================================================================================
  SnapDB Project - Test Data Insert Script
  Inserts 5-100 realistic records per table (within project limits)
  Run after: 01_Create_Tables.sql
================================================================================
*/

USE SnapDB;
GO

SET NOCOUNT ON;

/* ---- SnapFinance Lookups ---- */
INSERT INTO SnapFinance.WalletOwnerTypes (OwnerTypeID, TypeName, Description) VALUES
(1, 'Customer',   'End-user customer wallet'),
(2, 'Restaurant', 'Restaurant merchant wallet'),
(3, 'Driver',     'Driver earnings wallet'),
(4, 'Platform',   'Snap platform commission wallet');

INSERT INTO SnapFinance.TransactionTypes (TransactionTypeID, TypeName) VALUES
(1, 'DEBIT'), (2, 'CREDIT'), (3, 'REFUND'), (4, 'COMMISSION'), (5, 'TRANSFER');

INSERT INTO SnapFinance.RevenueSplitRules (RuleName, RestaurantPct, DriverPct, PlatformPct, IsActive) VALUES
(N'Standard Split', 70.00, 20.00, 10.00, 1),
(N'Promo Split',    75.00, 15.00, 10.00, 1);

INSERT INTO SnapFinance.RefundPolicies (PolicyName, MinutesBeforePrep, RefundPct, AppliesTo) VALUES
(N'Full Refund Early',    30, 100.00, 'FOOD'),
(N'Partial Refund Mid',   15,  50.00, 'FOOD'),
(N'No Refund Late',        0,   0.00, 'FOOD'),
(N'Ride Full Cancel',     10, 100.00, 'RIDE'),
(N'Ride Partial Cancel',   5,  50.00, 'RIDE');

INSERT INTO SnapFinance.PricingRules (RuleName, ServiceType, BaseFare, PerKmRate, PerMinuteRate, DemandMultiplier, MinFare) VALUES
(N'Standard Delivery', 'DELIVERY', 15000, 8000, 500, 1.20, 25000),
(N'Peak Delivery',     'DELIVERY', 20000, 10000, 700, 1.50, 35000),
(N'Economy Ride',      'RIDE',     20000, 12000, 800, 1.10, 30000),
(N'Premium Ride',      'RIDE',     35000, 18000, 1200, 1.30, 50000);

INSERT INTO SnapFinance.UserRoles (RoleID, RoleName, Description) VALUES
(1, 'Admin',              'Full system access'),
(2, 'Customer',           'Place orders and manage wallet'),
(3, 'RestaurantManager',  'Manage restaurant menus and orders'),
(4, 'Driver',             'Accept rides and deliveries');

INSERT INTO SnapFinance.RolePermissions (RoleID, PermissionName, CanRead, CanWrite, CanDelete) VALUES
(1, 'AllModules', 1, 1, 1),
(2, 'OwnOrders',  1, 1, 0),
(2, 'OwnWallet',  1, 0, 0),
(3, 'RestaurantOrders', 1, 1, 0),
(3, 'MenuManagement',   1, 1, 1),
(4, 'RideManagement',   1, 1, 0),
(4, 'DriverWallet',     1, 0, 0);

INSERT INTO SnapFinance.Users (Username, Email, PasswordHash, RoleID) VALUES
(N'admin',       N'admin@snapdb.ir',       N'$2a$hash_admin',       1),
(N'ali.cust',    N'ali@email.com',         N'$2a$hash_ali',         2),
(N'sara.cust',   N'sara@email.com',        N'$2a$hash_sara',        2),
(N'reza.mgr',    N'reza@pizza.ir',         N'$2a$hash_reza',        3),
(N'mina.mgr',    N'mina@burger.ir',        N'$2a$hash_mina',        3),
(N'hamid.driver',N'hamid@snap.ir',         N'$2a$hash_hamid',       4),
(N'fateme.driver',N'fateme@snap.ir',       N'$2a$hash_fateme',      4),
(N'john.driver', N'john@snap.ir',          N'$2a$hash_john',        4),
(N'zahra.cust',  N'zahra@email.com',      N'$2a$hash_zahra',       2),
(N'omar.cust',   N'omar@email.com',        N'$2a$hash_omar',        2);

/* ---- SnapFood ---- */
INSERT INTO SnapFood.Customers (UserID, FirstName, LastName, Phone, Email) VALUES
(2,  N'Ali',    N'Hosseini',  N'09121000001', N'ali@email.com'),
(3,  N'Sara',   N'Mohammadi', N'09121000002', N'sara@email.com'),
(9,  N'Zahra',  N'Karimi',    N'09121000003', N'zahra@email.com'),
(10, N'Omar',   N'Rahimi',    N'09121000004', N'omar@email.com'),
(NULL, N'Neda', N'Ahmadi',    N'09121000005', N'neda@email.com'),
(NULL, N'Pouya',N'Esmaeili',  N'09121000006', N'pouya@email.com'),
(NULL, N'Leila',N'Sadeghi',   N'09121000007', N'leila@email.com'),
(NULL, N'Amir', N'Nouri',     N'09121000008', N'amir@email.com');

INSERT INTO SnapFood.Restaurants (Name, CuisineType, Address, Latitude, Longitude, Phone, Rating) VALUES
(N'Pizza Roma',      N'Italian',   N'Valiasr St, Tehran',       35.7219000, 51.4056000, N'02144000001', 4.50),
(N'Burger House',    N'American',  N'Jordan St, Tehran',        35.7580000, 51.4100000, N'02144000002', 4.20),
(N'Kebab Koobideh',  N'Persian',   N'Enghelab St, Tehran',      35.7001000, 51.3910000, N'02144000003', 4.80),
(N'Sushi Zen',       N'Japanese',  N'Niavaran, Tehran',         35.8040000, 51.4700000, N'02144000004', 4.60),
(N'Salad Bar',       N'Healthy',   N'Saadat Abad, Tehran',      35.7740000, 51.3750000, N'02144000005', 4.00),
(N'Taco Fiesta',     N'Mexican',   N'Tehranpars, Tehran',       35.7320000, 51.5200000, N'02144000006', 3.90),
(N'Pasta Palace',    N'Italian',   N'Vanak Sq, Tehran',         35.7570000, 51.4050000, N'02144000007', 4.30),
(N'Grill Master',    N'BBQ',       N'Shahrak Gharb, Tehran',    35.7550000, 51.3650000, N'02144000008', 4.10);

INSERT INTO SnapFood.RestaurantManagers (RestaurantID, UserID) VALUES
(1, 4), (2, 5), (3, 4), (4, 5);

INSERT INTO SnapFood.MenuCategories (RestaurantID, CategoryName, DisplayOrder) VALUES
(1, N'Pizzas', 1), (1, N'Pastas', 2), (1, N'Drinks', 3),
(2, N'Burgers', 1), (2, N'Sides', 2), (2, N'Drinks', 3),
(3, N'Kebabs', 1), (3, N'Rice', 2), (3, N'Salads', 3),
(4, N'Sushi Rolls', 1), (4, N'Sashimi', 2),
(5, N'Salads', 1), (5, N'Smoothies', 2);

INSERT INTO SnapFood.MenuItems (CategoryID, ItemName, Description, Price, PrepTimeMinutes) VALUES
(1,  N'Margherita Pizza',    N'Classic tomato and mozzarella', 280000, 20),
(1,  N'Pepperoni Pizza',     N'Spicy pepperoni',                 320000, 22),
(2,  N'Carbonara',           N'Creamy pasta',                    250000, 18),
(4,  N'Classic Burger',      N'Beef patty with cheese',          220000, 15),
(4,  N'Chicken Burger',      N'Grilled chicken',                 200000, 15),
(5,  N'French Fries',        N'Crispy fries',                     80000, 10),
(7,  N'Koobideh Kebab',      N'Two skewers',                    350000, 25),
(7,  N'Joojeh Kebab',        N'Chicken kebab',                  300000, 22),
(8,  N'Chelo Kebab',         N'Kebab with rice',                380000, 25),
(10, N'California Roll',     N'8 pieces',                       290000, 20),
(10, N'Spicy Tuna Roll',     N'8 pieces',                       310000, 20),
(12, N'Caesar Salad',        N'Fresh greens',                   180000, 10),
(13, N'Berry Smoothie',      N'Mixed berries',                  120000, 5);

INSERT INTO SnapFood.CustomerAddresses (CustomerID, Label, StreetAddress, City, Latitude, Longitude, IsDefault) VALUES
(1, N'Home',   N'Unit 5, No.12 Valiasr',     N'Tehran', 35.7150000, 51.4000000, 1),
(1, N'Work',   N'Floor 3, Jordan Tower',     N'Tehran', 35.7600000, 51.4120000, 0),
(2, N'Home',   N'No.8 Enghelab Ave',          N'Tehran', 35.6980000, 51.3880000, 1),
(3, N'Home',   N'Niavaran Blvd 45',          N'Tehran', 35.8100000, 51.4750000, 1),
(4, N'Home',   N'Saadat Abad Phase 2',       N'Tehran', 35.7780000, 51.3700000, 1),
(5, N'Home',   N'Tehranpars St 100',         N'Tehran', 35.7350000, 51.5150000, 1),
(6, N'Home',   N'Vanak Square 22',           N'Tehran', 35.7580000, 51.4080000, 1),
(7, N'Home',   N'Shahrak Gharb Block 5',     N'Tehran', 35.7520000, 51.3620000, 1);

INSERT INTO SnapFood.DiscountCodes (Code, DiscountType, DiscountValue, MinOrderValue, MaxUsageCount, UsedCount, ValidFrom, ValidTo) VALUES
(N'WELCOME20',  'PERCENT', 20.00, 100000, 500, 12, '2026-01-01', '2026-12-31'),
(N'FLAT50K',    'FIXED',   50000, 200000, 100,  5, '2026-01-01', '2026-06-30'),
(N'SUMMER15',   'PERCENT', 15.00, 150000, 200,  8, '2026-06-01', '2026-09-30'),
(N'VIP10',      'PERCENT', 10.00, 300000,  50,  2, '2026-01-01', '2026-12-31'),
(N'EXPIRED',    'PERCENT', 25.00, 100000,  10,  0, '2025-01-01', '2025-12-31'),
(N'NEWUSER',    'PERCENT', 30.00,  80000, 1000, 45, '2026-01-01', '2026-12-31');

/* ---- SnapTaxi ---- */
INSERT INTO SnapTaxi.VehicleTypes (VehicleTypeID, TypeName, MaxCapacityKg, BaseMultiplier) VALUES
(1, N'Motorcycle', 15.00, 0.80),
(2, N'Sedan',      50.00, 1.00),
(3, N'SUV',        80.00, 1.25),
(4, N'Van',       200.00, 1.50);

INSERT INTO SnapTaxi.Drivers (UserID, FirstName, LastName, Phone, LicenseNumber, Rating) VALUES
(6,  N'Hamid',   N'Azizi',    N'09131000001', N'LIC-H001', 4.70),
(7,  N'Fateme',  N'Rostami',  N'09131000002', N'LIC-F002', 4.85),
(8,  N'John',    N'Smith',    N'09131000003', N'LIC-J003', 4.50),
(NULL, N'Mehdi', N'Khani',    N'09131000004', N'LIC-M004', 4.20),
(NULL, N'Roya',  N'Jafari',   N'09131000005', N'LIC-R005', 4.60),
(NULL, N'Sina',  N'Pakzad',   N'09131000006', N'LIC-S006', 4.40),
(NULL, N'Niloofar',N'Ghasemi',N'09131000007', N'LIC-N007', 4.75),
(NULL, N'Arash', N'Moradi',   N'09131000008', N'LIC-A008', 4.55);

INSERT INTO SnapTaxi.Vehicles (DriverID, VehicleTypeID, PlateNumber, Make, Model, Year) VALUES
(1, 1, N'12A345-11', N'Honda',   N'CG150',  2022),
(2, 2, N'22B456-22', N'Samand',  N'LX',     2021),
(3, 2, N'33C567-33', N'Peugeot', N'405',    2020),
(4, 1, N'44D678-44', N'Yamaha',  N'YZF',    2023),
(5, 3, N'55E789-55', N'Hyundai', N'Tucson', 2022),
(6, 2, N'66F890-66', N'Kia',     N'Cerato', 2021),
(7, 1, N'77G901-77', N'Honda',   N'Wave',   2022),
(8, 4, N'88H012-88', N'Renault', N'Kangoo', 2020);

INSERT INTO SnapTaxi.DeliveryZones (ZoneName, CenterLatitude, CenterLongitude, RadiusKm) VALUES
(N'Central Tehran',  35.7219000, 51.4056000, 8.0),
(N'North Tehran',    35.8040000, 51.4700000, 6.0),
(N'West Tehran',     35.7550000, 51.3650000, 7.0),
(N'East Tehran',     35.7320000, 51.5200000, 6.5),
(N'South Tehran',    35.6500000, 51.4000000, 5.0);

INSERT INTO SnapTaxi.ZonePricing (ZoneID, ServiceType, SurgeMultiplier) VALUES
(1, 'DELIVERY', 1.10), (1, 'RIDE', 1.05),
(2, 'DELIVERY', 1.25), (2, 'RIDE', 1.15),
(3, 'DELIVERY', 1.00), (3, 'RIDE', 1.00),
(4, 'DELIVERY', 1.20), (4, 'RIDE', 1.10),
(5, 'DELIVERY', 1.30), (5, 'RIDE', 1.20);

INSERT INTO SnapTaxi.DriverAvailability (DriverID, IsOnline, IsIdle, CurrentZoneID) VALUES
(1, 1, 1, 1), (2, 1, 1, 1), (3, 1, 0, 2),
(4, 1, 1, 1), (5, 0, 1, 3), (6, 1, 1, 4),
(7, 1, 1, 2), (8, 1, 0, 1);

INSERT INTO SnapTaxi.DriverLocations (DriverID, Latitude, Longitude, RecordedAt) VALUES
(1, 35.7200000, 51.4040000, DATEADD(MINUTE, -2, SYSUTCDATETIME())),
(2, 35.7230000, 51.4080000, DATEADD(MINUTE, -1, SYSUTCDATETIME())),
(3, 35.8050000, 51.4720000, DATEADD(MINUTE, -3, SYSUTCDATETIME())),
(4, 35.7180000, 51.4020000, DATEADD(MINUTE, -1, SYSUTCDATETIME())),
(5, 35.7540000, 51.3680000, DATEADD(MINUTE, -10, SYSUTCDATETIME())),
(6, 35.7330000, 51.5180000, DATEADD(MINUTE, -2, SYSUTCDATETIME())),
(7, 35.8080000, 51.4680000, DATEADD(MINUTE, -1, SYSUTCDATETIME())),
(8, 35.7220000, 51.4060000, DATEADD(MINUTE, -5, SYSUTCDATETIME()));

INSERT INTO SnapTaxi.DemandMetrics (ZoneID, PendingRequests, ActiveDrivers) VALUES
(1, 8, 4), (2, 3, 2), (3, 2, 1), (4, 5, 2), (5, 4, 0);

/* ---- Wallets (4 types) ---- */
-- Platform wallet (OwnerEntityID = 0)
INSERT INTO SnapFinance.Wallets (OwnerTypeID, OwnerEntityID, Balance) VALUES
(4, 0, 5000000.00);

-- Customer wallets
INSERT INTO SnapFinance.Wallets (OwnerTypeID, OwnerEntityID, Balance)
SELECT 1, CustomerID, v.Balance
FROM SnapFood.Customers c
CROSS APPLY (VALUES
    (1, 1500000.00), (2, 2000000.00), (3, 800000.00), (4, 1200000.00),
    (5, 500000.00),  (6, 950000.00),  (7, 1100000.00), (8, 750000.00)
) v(CustomerID, Balance)
WHERE c.CustomerID = v.CustomerID;

-- Restaurant wallets
INSERT INTO SnapFinance.Wallets (OwnerTypeID, OwnerEntityID, Balance)
SELECT 2, RestaurantID, v.Balance
FROM SnapFood.Restaurants r
CROSS APPLY (VALUES
    (1, 3200000.00), (2, 2100000.00), (3, 4500000.00), (4, 1800000.00),
    (5, 900000.00),  (6, 600000.00),  (7, 1500000.00), (8, 1100000.00)
) v(RestaurantID, Balance)
WHERE r.RestaurantID = v.RestaurantID;

-- Driver wallets
INSERT INTO SnapFinance.Wallets (OwnerTypeID, OwnerEntityID, Balance)
SELECT 3, DriverID, v.Balance
FROM SnapTaxi.Drivers d
CROSS APPLY (VALUES
    (1, 850000.00), (2, 1200000.00), (3, 620000.00), (4, 430000.00),
    (5, 0.00),      (6, 780000.00), (7, 910000.00), (8, 540000.00)
) v(DriverID, Balance)
WHERE d.DriverID = v.DriverID;

PRINT 'Test data inserted successfully.';
GO
