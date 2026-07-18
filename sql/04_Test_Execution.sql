/*
================================================================================
  SnapDB Project - Comprehensive Test Execution Script
  Demonstrates all key workflows with realistic scenarios
  Run after: 01, 02, 03 scripts
================================================================================
*/

USE SnapDB;
GO

SET NOCOUNT ON;
PRINT REPLICATE('=', 70);
PRINT '  SnapDB - Scenario Test Execution';
PRINT REPLICATE('=', 70);

/* ============================================================================
   HELPER: Display wallet balances
   ============================================================================ */

GO
CREATE OR ALTER PROCEDURE #ShowWallets @Label NVARCHAR(100)
AS
BEGIN
    PRINT '';
    PRINT '--- Wallet Balances: ' + @Label + ' ---';
    SELECT
        wot.TypeName AS WalletType,
        w.OwnerEntityID,
        w.Balance
    FROM SnapFinance.Wallets w
    INNER JOIN SnapFinance.WalletOwnerTypes wot ON wot.OwnerTypeID = w.OwnerTypeID
    WHERE (w.OwnerTypeID = 1 AND w.OwnerEntityID IN (1, 2))
       OR (w.OwnerTypeID = 2 AND w.OwnerEntityID IN (1, 2))
       OR (w.OwnerTypeID = 3 AND w.OwnerEntityID IN (1, 2, 4))
       OR (w.OwnerTypeID = 4 AND w.OwnerEntityID = 0)
    ORDER BY wot.OwnerTypeID, w.OwnerEntityID;
END;
GO

/* ============================================================================
   SCENARIO 1: Validate discount codes
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 1: Discount Code Validation';

SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'WELCOME20', 300000);
SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'EXPIRED', 300000);
SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'WELCOME20', 50000);  -- below min

/* ============================================================================
   SCENARIO 2: Dynamic pricing functions
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 2: Dynamic Pricing';

SELECT SnapFinance.fn_CalculateDeliveryFee(5.2, 25, 1, 1.8) AS DeliveryFee_5km_HighDemand;
SELECT SnapFinance.fn_CalculateDeliveryFee(2.0, 15, 3, 0.8) AS DeliveryFee_2km_LowDemand;
SELECT SnapFinance.fn_CalculateRideFare(8.5, 30, 2, 2) AS RideFare_Sedan_NorthZone;
SELECT SnapFinance.fn_CalculateRideFare(3.0, 12, 3, 1) AS RideFare_SUV_Central;

/* ============================================================================
   SCENARIO 3: View available drivers (nearest allocation candidates)
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 3: Available Drivers (Online + Idle)';

SELECT DriverID, DriverName, ZoneName, Latitude, Longitude, VehicleType
FROM SnapTaxi.vw_AvailableDrivers
ORDER BY DriverID;

/* ============================================================================
   SCENARIO 4: Place & finalize food order (full financial flow + driver assign)
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 4: Place Food Order - Ali orders from Pizza Roma';

EXEC #ShowWallets N'BEFORE Order';

DECLARE @OrderID1 INT;

-- Step 1: Create pending order
EXEC SnapFood.usp_PlaceFoodOrder
    @CustomerID = 1,
    @RestaurantID = 1,
    @DeliveryAddressID = 1,
    @OrderID = @OrderID1 OUTPUT;

PRINT 'Created Order ID: ' + CAST(@OrderID1 AS NVARCHAR(10));

-- Step 2: Add order items
INSERT INTO SnapFood.OrderItems (OrderID, ItemID, Quantity, UnitPrice) VALUES
(@OrderID1, 1, 2, 280000),  -- 2x Margherita Pizza
(@OrderID1, 3, 1, 250000);    -- 1x Carbonara
-- Subtotal = 810000

-- Step 3: Finalize with discount code WELCOME20 (20% off)
EXEC SnapFood.usp_FinalizeFoodOrder @OrderID = @OrderID1, @DiscountCode = N'WELCOME20';

PRINT 'Order finalized with WELCOME20 discount.';

SELECT OrderID, OrderStatus, Subtotal, DiscountAmount, DeliveryFee, TotalAmount, DistanceKm
FROM SnapFood.FoodOrders WHERE OrderID = @OrderID1;

EXEC #ShowWallets N'AFTER Order Placement';

-- Show driver assignment (cross-schema)
SELECT * FROM SnapTaxi.vw_DeliveryTracking WHERE OrderID = @OrderID1;

/* ============================================================================
   SCENARIO 5: Complete delivery - driver gets paid
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 5: Complete Delivery';

EXEC SnapTaxi.usp_CompleteDelivery @OrderID = @OrderID1;

SELECT OrderID, OrderStatus, DeliveredAt FROM SnapFood.FoodOrders WHERE OrderID = @OrderID1;
SELECT * FROM SnapTaxi.vw_DeliveryTracking WHERE OrderID = @OrderID1;

EXEC #ShowWallets N'AFTER Delivery Complete';

/* ============================================================================
   SCENARIO 6: Second order then cancel with refund
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 6: Order Cancellation & Refund';

DECLARE @OrderID2 INT;

EXEC SnapFood.usp_PlaceFoodOrder
    @CustomerID = 2,
    @RestaurantID = 2,
    @DeliveryAddressID = 3,
    @OrderID = @OrderID2 OUTPUT;

INSERT INTO SnapFood.OrderItems (OrderID, ItemID, Quantity, UnitPrice) VALUES
(@OrderID2, 4, 1, 220000),
(@OrderID2, 6, 2, 80000);

EXEC SnapFood.usp_FinalizeFoodOrder @OrderID = @OrderID2, @DiscountCode = NULL;

PRINT 'Order ' + CAST(@OrderID2 AS NVARCHAR(10)) + ' placed. Total:';
SELECT OrderID, TotalAmount, OrderStatus, PlacedAt FROM SnapFood.FoodOrders WHERE OrderID = @OrderID2;

EXEC #ShowWallets N'BEFORE Cancellation';

-- Cancel immediately (should get high refund %)
WAITFOR DELAY '00:00:02';
EXEC SnapFood.usp_CancelFoodOrder @OrderID = @OrderID2, @CancellationReason = N'Customer changed mind';

SELECT OrderID, OrderStatus, CancelledAt, CancellationReason FROM SnapFood.FoodOrders WHERE OrderID = @OrderID2;

DECLARE @RefundPct DECIMAL(5,2);
SELECT @RefundPct = SnapFinance.fn_GetRefundPercentage('FOOD',
    (SELECT PlacedAt FROM SnapFood.FoodOrders WHERE OrderID = @OrderID2),
    (SELECT CancelledAt FROM SnapFood.FoodOrders WHERE OrderID = @OrderID2));
PRINT 'Refund percentage applied: ' + CAST(@RefundPct AS NVARCHAR(10)) + '%';

EXEC #ShowWallets N'AFTER Cancellation Refund';

/* ============================================================================
   SCENARIO 7: Standalone taxi ride request
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 7: Standalone Taxi Ride';

DECLARE @RideID INT;
EXEC SnapTaxi.usp_RequestRide
    @CustomerID = 3,
    @PickupLat = 35.7219000,
    @PickupLng = 51.4056000,
    @DropLat = 35.8040000,
    @DropLng = 51.4700000,
    @ZoneID = 2,
    @RideID = @RideID OUTPUT;

PRINT 'Ride ID: ' + CAST(@RideID AS NVARCHAR(10));
SELECT RideID, DriverID, DistanceKm, TotalFare, RideStatus FROM SnapTaxi.Rides WHERE RideID = @RideID;

/* ============================================================================
   SCENARIO 8: Audit logs & cross-schema interaction proof
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 8: Audit Logs (Triggers fired)';

SELECT TOP 5 LogID, TableName, Operation, RecordID, NewValues, ChangedAt
FROM SnapFood.FoodAuditLog ORDER BY LogID DESC;

SELECT TOP 5 LogID, TableName, Operation, RecordID, NewValues, ChangedAt
FROM SnapTaxi.TaxiAuditLog ORDER BY LogID DESC;

SELECT TOP 5 LogID, TableName, Operation, RecordID, NewValues, ChangedAt
FROM SnapFinance.FinanceAuditLog ORDER BY LogID DESC;

/* ============================================================================
   SCENARIO 9: Performance views
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 9: Business Intelligence Views';

SELECT * FROM SnapFood.vw_ActiveOrdersSummary;
SELECT TOP 5 * FROM SnapFood.vw_RestaurantPerformance ORDER BY TotalRevenue DESC;
SELECT * FROM SnapTaxi.vw_ZoneDemandOverview;

/* ============================================================================
   SCENARIO 10: Transaction ledger for customer 1
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 10: Customer 1 Transaction History';

SELECT wt.TransactionID, wot.TypeName, wt.Amount, wt.BalanceAfter,
       wt.ReferenceType, wt.ReferenceID, wt.Description, wt.CreatedAt
FROM SnapFinance.WalletTransactions wt
INNER JOIN SnapFinance.Wallets w ON w.WalletID = wt.WalletID
INNER JOIN SnapFinance.WalletOwnerTypes wot ON wot.OwnerTypeID = w.OwnerTypeID
WHERE w.OwnerTypeID = 1 AND w.OwnerEntityID = 1
ORDER BY wt.CreatedAt;

/* ============================================================================
   SCENARIO 11: Bonus - Export orders
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 11: Export Orders (Bonus)';

EXEC SnapFood.usp_ExportOrdersToStaging;

/* ============================================================================
   SCENARIO 12: Role permissions check (Bonus)
   ============================================================================ */
PRINT '';
PRINT '>>> SCENARIO 12: User Roles & Permissions (Bonus)';

SELECT u.Username, ur.RoleName, rp.PermissionName, rp.CanRead, rp.CanWrite
FROM SnapFinance.Users u
INNER JOIN SnapFinance.UserRoles ur ON ur.RoleID = u.RoleID
INNER JOIN SnapFinance.RolePermissions rp ON rp.RoleID = ur.RoleID
ORDER BY u.Username, rp.PermissionName;

PRINT '';
PRINT REPLICATE('=', 70);
PRINT '  All scenarios executed successfully.';
PRINT REPLICATE('=', 70);

DROP PROCEDURE IF EXISTS #ShowWallets;
GO
