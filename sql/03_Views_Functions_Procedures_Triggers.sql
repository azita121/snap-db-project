/*
================================================================================
  SnapDB Project - Views, Functions, Stored Procedures, Triggers
  Run after: 01_Create_Tables.sql, 02_Insert_Test_Data.sql
================================================================================
*/

USE SnapDB;
GO

/* ============================================================================
   HELPER: Haversine distance (km) between two lat/lng points
   ============================================================================ */
CREATE OR ALTER FUNCTION SnapTaxi.fn_HaversineDistanceKm (
    @Lat1 DECIMAL(10,7),
    @Lng1 DECIMAL(10,7),
    @Lat2 DECIMAL(10,7),
    @Lng2 DECIMAL(10,7)
)
RETURNS DECIMAL(10,3)
AS
BEGIN
    DECLARE @R DECIMAL(10,3) = 6371.0;
    DECLARE @dLat DECIMAL(18,10) = RADIANS(@Lat2 - @Lat1);
    DECLARE @dLng DECIMAL(18,10) = RADIANS(@Lng2 - @Lng1);
    DECLARE @a DECIMAL(18,10) =
        SIN(@dLat / 2) * SIN(@dLat / 2) +
        COS(RADIANS(@Lat1)) * COS(RADIANS(@Lat2)) *
        SIN(@dLng / 2) * SIN(@dLng / 2);
    DECLARE @c DECIMAL(18,10) = 2 * ATN2(SQRT(@a), SQRT(1 - @a));
    RETURN CAST(@R * @c AS DECIMAL(10,3));
END;
GO

/* ============================================================================
   SNAPFOOD FUNCTIONS (3+)
   ============================================================================ */

-- F1: Validate discount code (expiry, usage limit, min order value)
CREATE OR ALTER FUNCTION SnapFood.fn_ValidateDiscountCode (
    @Code           NVARCHAR(30),
    @OrderSubtotal  DECIMAL(12,2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        d.DiscountID,
        d.Code,
        d.DiscountType,
        d.DiscountValue,
        CASE
            WHEN d.IsActive = 0 THEN N'INACTIVE'
            WHEN SYSUTCDATETIME() < d.ValidFrom THEN N'NOT_YET_VALID'
            WHEN SYSUTCDATETIME() > d.ValidTo THEN N'EXPIRED'
            WHEN d.UsedCount >= d.MaxUsageCount THEN N'USAGE_LIMIT_REACHED'
            WHEN @OrderSubtotal < d.MinOrderValue THEN N'BELOW_MIN_ORDER'
            ELSE N'VALID'
        END AS ValidationStatus,
        CASE
            WHEN d.DiscountType = 'PERCENT' THEN
                CASE WHEN d.IsActive = 1
                      AND SYSUTCDATETIME() BETWEEN d.ValidFrom AND d.ValidTo
                      AND d.UsedCount < d.MaxUsageCount
                      AND @OrderSubtotal >= d.MinOrderValue
                     THEN ROUND(@OrderSubtotal * d.DiscountValue / 100.0, 0)
                     ELSE 0 END
            WHEN d.DiscountType = 'FIXED' THEN
                CASE WHEN d.IsActive = 1
                      AND SYSUTCDATETIME() BETWEEN d.ValidFrom AND d.ValidTo
                      AND d.UsedCount < d.MaxUsageCount
                      AND @OrderSubtotal >= d.MinOrderValue
                     THEN d.DiscountValue
                     ELSE 0 END
            ELSE 0
        END AS CalculatedDiscount
    FROM SnapFood.DiscountCodes d
    WHERE d.Code = @Code
);
GO

-- F2: Calculate order subtotal from items
CREATE OR ALTER FUNCTION SnapFood.fn_CalculateOrderSubtotal (
    @OrderID INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Subtotal DECIMAL(12,2);
    SELECT @Subtotal = ISNULL(SUM(oi.Quantity * oi.UnitPrice), 0)
    FROM SnapFood.OrderItems oi
    WHERE oi.OrderID = @OrderID;
    RETURN @Subtotal;
END;
GO

-- F3: Estimate preparation time for an order
CREATE OR ALTER FUNCTION SnapFood.fn_EstimatePrepTimeMinutes (
    @OrderID INT
)
RETURNS INT
AS
BEGIN
    DECLARE @MaxPrep INT;
    SELECT @MaxPrep = ISNULL(MAX(mi.PrepTimeMinutes), 15)
    FROM SnapFood.OrderItems oi
    INNER JOIN SnapFood.MenuItems mi ON mi.ItemID = oi.ItemID
    WHERE oi.OrderID = @OrderID;
    RETURN @MaxPrep;
END;
GO

-- F4: Estimate arrival time from distance and traffic factor
CREATE OR ALTER FUNCTION SnapTaxi.fn_EstimateArrivalMinutes (
    @DistanceKm     DECIMAL(8,3),
    @TrafficFactor  DECIMAL(4,2) = 1.0
)
RETURNS INT
AS
BEGIN
    DECLARE @BaseMinutes INT = CAST(@DistanceKm * 3 AS INT);
    RETURN CAST(@BaseMinutes * @TrafficFactor AS INT) + 5;
END;
GO

-- F5: Get current demand index for a zone
CREATE OR ALTER FUNCTION SnapTaxi.fn_GetZoneDemandIndex (
    @ZoneID INT
)
RETURNS DECIMAL(8,2)
AS
BEGIN
    DECLARE @Index DECIMAL(8,2);
    SELECT TOP 1 @Index = DemandIndex
    FROM SnapTaxi.DemandMetrics
    WHERE ZoneID = @ZoneID
    ORDER BY RecordedAt DESC;
    RETURN ISNULL(@Index, 1.0);
END;
GO

/* ============================================================================
   SNAPFINANCE FUNCTIONS (3+)
   ============================================================================ */

-- F6: Dynamic delivery fee based on distance, demand, zone surge, time
CREATE OR ALTER FUNCTION SnapFinance.fn_CalculateDeliveryFee (
    @DistanceKm     DECIMAL(8,3),
    @EstimatedMin   INT,
    @ZoneID         INT,
    @DemandIndex    DECIMAL(8,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @BaseFare DECIMAL(10,2);
    DECLARE @PerKm DECIMAL(10,2);
    DECLARE @PerMin DECIMAL(10,2);
    DECLARE @MinFare DECIMAL(10,2);
    DECLARE @DemandMult DECIMAL(5,2);
    DECLARE @ZoneSurge DECIMAL(4,2) = 1.0;
    DECLARE @Fee DECIMAL(10,2);

    SELECT TOP 1
        @BaseFare = BaseFare,
        @PerKm = PerKmRate,
        @PerMin = PerMinuteRate,
        @MinFare = MinFare,
        @DemandMult = DemandMultiplier
    FROM SnapFinance.PricingRules
    WHERE ServiceType = 'DELIVERY' AND IsActive = 1
    ORDER BY RuleID;

    SELECT TOP 1 @ZoneSurge = SurgeMultiplier
    FROM SnapTaxi.ZonePricing
    WHERE ZoneID = @ZoneID AND ServiceType = 'DELIVERY'
      AND EffectiveFrom <= SYSUTCDATETIME()
      AND (EffectiveTo IS NULL OR EffectiveTo > SYSUTCDATETIME())
    ORDER BY EffectiveFrom DESC;

    SET @Fee = (@BaseFare + (@DistanceKm * @PerKm) + (@EstimatedMin * @PerMin))
               * @DemandMult * @ZoneSurge
               * CASE WHEN @DemandIndex > 1.5 THEN 1.2 WHEN @DemandIndex > 1.0 THEN 1.1 ELSE 1.0 END;

    IF @Fee < @MinFare SET @Fee = @MinFare;
    RETURN ROUND(@Fee, 0);
END;
GO

-- F7: Dynamic ride fare
CREATE OR ALTER FUNCTION SnapFinance.fn_CalculateRideFare (
    @DistanceKm     DECIMAL(8,3),
    @EstimatedMin   INT,
    @VehicleTypeID  TINYINT,
    @ZoneID         INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @BaseFare DECIMAL(10,2);
    DECLARE @PerKm DECIMAL(10,2);
    DECLARE @PerMin DECIMAL(10,2);
    DECLARE @MinFare DECIMAL(10,2);
    DECLARE @VehicleMult DECIMAL(4,2);
    DECLARE @ZoneSurge DECIMAL(4,2) = 1.0;
    DECLARE @Fare DECIMAL(10,2);

    SELECT TOP 1
        @BaseFare = BaseFare, @PerKm = PerKmRate,
        @PerMin = PerMinuteRate, @MinFare = MinFare
    FROM SnapFinance.PricingRules
    WHERE ServiceType = 'RIDE' AND IsActive = 1
    ORDER BY RuleID;

    SELECT @VehicleMult = BaseMultiplier FROM SnapTaxi.VehicleTypes WHERE VehicleTypeID = @VehicleTypeID;

    SELECT TOP 1 @ZoneSurge = SurgeMultiplier
    FROM SnapTaxi.ZonePricing
    WHERE ZoneID = @ZoneID AND ServiceType = 'RIDE'
      AND EffectiveFrom <= SYSUTCDATETIME()
      AND (EffectiveTo IS NULL OR EffectiveTo > SYSUTCDATETIME())
    ORDER BY EffectiveFrom DESC;

    SET @Fare = (@BaseFare + (@DistanceKm * @PerKm) + (@EstimatedMin * @PerMin))
                * ISNULL(@VehicleMult, 1.0) * @ZoneSurge;

    IF @Fare < @MinFare SET @Fare = @MinFare;
    RETURN ROUND(@Fare, 0);
END;
GO

-- F8: Refund percentage based on cancellation timing
CREATE OR ALTER FUNCTION SnapFinance.fn_GetRefundPercentage (
    @ReferenceType  NVARCHAR(20),
    @PlacedAt       DATETIME2,
    @CancelledAt    DATETIME2
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @MinutesElapsed INT = DATEDIFF(MINUTE, @PlacedAt, @CancelledAt);
    DECLARE @RefundPct DECIMAL(5,2) = 0;

    SELECT TOP 1 @RefundPct = RefundPct
    FROM SnapFinance.RefundPolicies
    WHERE IsActive = 1
      AND (AppliesTo = @ReferenceType OR AppliesTo = 'BOTH')
      AND @MinutesElapsed >= MinutesBeforePrep
    ORDER BY MinutesBeforePrep DESC;

    RETURN ISNULL(@RefundPct, 0);
END;
GO

/* ============================================================================
   VIEWS - SnapFood (3+)
   ============================================================================ */

CREATE OR ALTER VIEW SnapFood.vw_ActiveOrdersSummary
AS
SELECT
    fo.OrderID,
    c.FirstName + N' ' + c.LastName AS CustomerName,
    r.Name AS RestaurantName,
    fo.OrderStatus,
    fo.Subtotal,
    fo.DiscountAmount,
    fo.DeliveryFee,
    fo.TotalAmount,
    fo.PlacedAt,
    DATEDIFF(MINUTE, fo.PlacedAt, SYSUTCDATETIME()) AS MinutesSincePlaced
FROM SnapFood.FoodOrders fo
INNER JOIN SnapFood.Customers c ON c.CustomerID = fo.CustomerID
INNER JOIN SnapFood.Restaurants r ON r.RestaurantID = fo.RestaurantID
WHERE fo.OrderStatus NOT IN ('DELIVERED', 'CANCELLED');
GO

CREATE OR ALTER VIEW SnapFood.vw_RestaurantPerformance
AS
SELECT
    r.RestaurantID,
    r.Name,
    r.CuisineType,
    r.Rating AS StaticRating,
    COUNT(DISTINCT fo.OrderID) AS TotalOrders,
    ISNULL(SUM(CASE WHEN fo.OrderStatus = 'DELIVERED' THEN fo.TotalAmount END), 0) AS TotalRevenue,
    ISNULL(AVG(rv.Rating), r.Rating) AS AvgReviewRating,
    COUNT(rv.ReviewID) AS ReviewCount
FROM SnapFood.Restaurants r
LEFT JOIN SnapFood.FoodOrders fo ON fo.RestaurantID = r.RestaurantID
LEFT JOIN SnapFood.Reviews rv ON rv.RestaurantID = r.RestaurantID
GROUP BY r.RestaurantID, r.Name, r.CuisineType, r.Rating;
GO

CREATE OR ALTER VIEW SnapFood.vw_MenuWithCategories
AS
SELECT
    r.RestaurantID,
    r.Name AS RestaurantName,
    mc.CategoryName,
    mi.ItemID,
    mi.ItemName,
    mi.Description,
    mi.Price,
    mi.IsAvailable,
    mi.PrepTimeMinutes
FROM SnapFood.MenuItems mi
INNER JOIN SnapFood.MenuCategories mc ON mc.CategoryID = mi.CategoryID
INNER JOIN SnapFood.Restaurants r ON r.RestaurantID = mc.RestaurantID;
GO

/* ============================================================================
   VIEWS - SnapTaxi (3+)
   ============================================================================ */

CREATE OR ALTER VIEW SnapTaxi.vw_AvailableDrivers
AS
SELECT
    d.DriverID,
    d.FirstName + N' ' + d.LastName AS DriverName,
    d.Phone,
    d.Rating,
    da.IsOnline,
    da.IsIdle,
    dz.ZoneName,
    dl.Latitude,
    dl.Longitude,
    dl.RecordedAt AS LastLocationUpdate,
    vt.TypeName AS VehicleType
FROM SnapTaxi.Drivers d
INNER JOIN SnapTaxi.DriverAvailability da ON da.DriverID = d.DriverID
INNER JOIN SnapTaxi.Vehicles v ON v.DriverID = d.DriverID AND v.IsActive = 1
INNER JOIN SnapTaxi.VehicleTypes vt ON vt.VehicleTypeID = v.VehicleTypeID
LEFT JOIN SnapTaxi.DeliveryZones dz ON dz.ZoneID = da.CurrentZoneID
OUTER APPLY (
    SELECT TOP 1 Latitude, Longitude, RecordedAt
    FROM SnapTaxi.DriverLocations
    WHERE DriverID = d.DriverID
    ORDER BY RecordedAt DESC
) dl
WHERE d.IsActive = 1 AND da.IsOnline = 1 AND da.IsIdle = 1;
GO

CREATE OR ALTER VIEW SnapTaxi.vw_DeliveryTracking
AS
SELECT
    da.AssignmentID,
    fo.OrderID,
    fo.OrderStatus AS FoodOrderStatus,
    da.AssignmentStatus,
    d.FirstName + N' ' + d.LastName AS DriverName,
    d.Phone AS DriverPhone,
    r.Name AS RestaurantName,
    c.FirstName + N' ' + c.LastName AS CustomerName,
    ca.StreetAddress AS DeliveryAddress,
    da.AssignedAt,
    da.DeliveredAt
FROM SnapTaxi.DeliveryAssignments da
INNER JOIN SnapFood.FoodOrders fo ON fo.OrderID = da.FoodOrderID
INNER JOIN SnapTaxi.Drivers d ON d.DriverID = da.DriverID
INNER JOIN SnapFood.Restaurants r ON r.RestaurantID = fo.RestaurantID
INNER JOIN SnapFood.Customers c ON c.CustomerID = fo.CustomerID
INNER JOIN SnapFood.CustomerAddresses ca ON ca.AddressID = fo.DeliveryAddressID;
GO

CREATE OR ALTER VIEW SnapTaxi.vw_ZoneDemandOverview
AS
SELECT
    dz.ZoneID,
    dz.ZoneName,
    dm.PendingRequests,
    dm.ActiveDrivers,
    dm.DemandIndex,
    zp_del.SurgeMultiplier AS DeliverySurge,
    zp_ride.SurgeMultiplier AS RideSurge,
    dm.RecordedAt
FROM SnapTaxi.DeliveryZones dz
OUTER APPLY (
    SELECT TOP 1 PendingRequests, ActiveDrivers, DemandIndex, RecordedAt
    FROM SnapTaxi.DemandMetrics WHERE ZoneID = dz.ZoneID
    ORDER BY RecordedAt DESC
) dm
OUTER APPLY (
    SELECT TOP 1 SurgeMultiplier FROM SnapTaxi.ZonePricing
    WHERE ZoneID = dz.ZoneID AND ServiceType = 'DELIVERY'
    ORDER BY EffectiveFrom DESC
) zp_del
OUTER APPLY (
    SELECT TOP 1 SurgeMultiplier FROM SnapTaxi.ZonePricing
    WHERE ZoneID = dz.ZoneID AND ServiceType = 'RIDE'
    ORDER BY EffectiveFrom DESC
) zp_ride;
GO

/* ============================================================================
   INTERNAL: Credit / Debit wallet helpers
   ============================================================================ */
CREATE OR ALTER PROCEDURE SnapFinance.usp_WalletDebit
    @OwnerTypeID    TINYINT,
    @OwnerEntityID  INT,
    @Amount         DECIMAL(14,2),
    @TransactionTypeID TINYINT = 1,
    @ReferenceType  NVARCHAR(30) = NULL,
    @ReferenceID    INT = NULL,
    @Description    NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @WalletID INT;
    DECLARE @NewBalance DECIMAL(14,2);

    SELECT @WalletID = WalletID FROM SnapFinance.Wallets
    WHERE OwnerTypeID = @OwnerTypeID AND OwnerEntityID = @OwnerEntityID AND IsActive = 1;

    IF @WalletID IS NULL
        THROW 50001, 'Wallet not found.', 1;

    UPDATE SnapFinance.Wallets
    SET Balance = Balance - @Amount, UpdatedAt = SYSUTCDATETIME()
    WHERE WalletID = @WalletID AND Balance >= @Amount;

    IF @@ROWCOUNT = 0
        THROW 50002, 'Insufficient wallet balance.', 1;

    SELECT @NewBalance = Balance FROM SnapFinance.Wallets WHERE WalletID = @WalletID;

    INSERT INTO SnapFinance.WalletTransactions
        (WalletID, TransactionTypeID, Amount, BalanceAfter, ReferenceType, ReferenceID, Description)
    VALUES
        (@WalletID, @TransactionTypeID, -@Amount, @NewBalance, @ReferenceType, @ReferenceID, @Description);
END;
GO

CREATE OR ALTER PROCEDURE SnapFinance.usp_WalletCredit
    @OwnerTypeID    TINYINT,
    @OwnerEntityID  INT,
    @Amount         DECIMAL(14,2),
    @TransactionTypeID TINYINT = 2,
    @ReferenceType  NVARCHAR(30) = NULL,
    @ReferenceID    INT = NULL,
    @Description    NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @WalletID INT;
    DECLARE @NewBalance DECIMAL(14,2);

    SELECT @WalletID = WalletID FROM SnapFinance.Wallets
    WHERE OwnerTypeID = @OwnerTypeID AND OwnerEntityID = @OwnerEntityID AND IsActive = 1;

    IF @WalletID IS NULL
        THROW 50003, 'Wallet not found.', 1;

    UPDATE SnapFinance.Wallets
    SET Balance = Balance + @Amount, UpdatedAt = SYSUTCDATETIME()
    WHERE WalletID = @WalletID;

    SELECT @NewBalance = Balance FROM SnapFinance.Wallets WHERE WalletID = @WalletID;

    INSERT INTO SnapFinance.WalletTransactions
        (WalletID, TransactionTypeID, Amount, BalanceAfter, ReferenceType, ReferenceID, Description)
    VALUES
        (@WalletID, @TransactionTypeID, @Amount, @NewBalance, @ReferenceType, @ReferenceID, @Description);
END;
GO

/* ============================================================================
   STORED PROCEDURES - SnapFood (3+)
   ============================================================================ */

-- SP1: Place food order with discount validation and payment split
CREATE OR ALTER PROCEDURE SnapFood.usp_PlaceFoodOrder
    @CustomerID         INT,
    @RestaurantID       INT,
    @DeliveryAddressID  INT,
    @DiscountCode       NVARCHAR(30) = NULL,
    @OrderID            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO SnapFood.FoodOrders (CustomerID, RestaurantID, DeliveryAddressID, OrderStatus)
        VALUES (@CustomerID, @RestaurantID, @DeliveryAddressID, 'PENDING');

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO SnapFood.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@OrderID, NULL, 'PENDING');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP4: Assign nearest available online idle driver (cross-schema) — defined before Finalize
CREATE OR ALTER PROCEDURE SnapTaxi.usp_AssignNearestDriver
    @OrderID        INT,
    @PickupLat      DECIMAL(10,7),
    @PickupLng      DECIMAL(10,7),
    @DropLat        DECIMAL(10,7),
    @DropLng        DECIMAL(10,7),
    @DeliveryFee    DECIMAL(10,2) = 0,
    @DriverShare    DECIMAL(10,2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DriverID INT;
    DECLARE @DistanceKm DECIMAL(8,3);
    DECLARE @EstMin INT;
    DECLARE @RideID INT;

    ;WITH NearestDrivers AS (
        SELECT
            d.DriverID,
            SnapTaxi.fn_HaversineDistanceKm(dl.Latitude, dl.Longitude, @PickupLat, @PickupLng) AS DistanceToPickup
        FROM SnapTaxi.vw_AvailableDrivers d
        CROSS APPLY (
            SELECT TOP 1 Latitude, Longitude
            FROM SnapTaxi.DriverLocations
            WHERE DriverID = d.DriverID
            ORDER BY RecordedAt DESC
        ) dl
    )
    SELECT TOP 1 @DriverID = DriverID
    FROM NearestDrivers
    ORDER BY DistanceToPickup ASC;

    IF @DriverID IS NULL
        THROW 50300, 'No available drivers online.', 1;

    SET @DistanceKm = SnapTaxi.fn_HaversineDistanceKm(@PickupLat, @PickupLng, @DropLat, @DropLng);
    SET @EstMin = SnapTaxi.fn_EstimateArrivalMinutes(@DistanceKm, 1.0);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO SnapTaxi.Rides (DriverID, PickupLatitude, PickupLongitude,
            DropoffLatitude, DropoffLongitude, DistanceKm, EstimatedMinutes,
            RideStatus, BaseFare, TotalFare)
        VALUES (@DriverID, @PickupLat, @PickupLng, @DropLat, @DropLng,
            @DistanceKm, @EstMin, 'ASSIGNED', @DeliveryFee, @DeliveryFee);

        SET @RideID = SCOPE_IDENTITY();

        INSERT INTO SnapTaxi.RideStatusHistory (RideID, OldStatus, NewStatus)
        VALUES (@RideID, NULL, 'ASSIGNED');

        INSERT INTO SnapTaxi.DeliveryAssignments (FoodOrderID, DriverID, RideID, AssignmentStatus)
        VALUES (@OrderID, @DriverID, @RideID, 'ASSIGNED');

        UPDATE SnapTaxi.DriverAvailability SET IsIdle = 0 WHERE DriverID = @DriverID;

        UPDATE SnapFood.FoodOrders SET OrderStatus = 'OUT_FOR_DELIVERY'
        WHERE OrderID = @OrderID AND OrderStatus = 'CONFIRMED';

        INSERT INTO SnapFood.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        SELECT @OrderID, 'CONFIRMED', 'OUT_FOR_DELIVERY'
        WHERE EXISTS (SELECT 1 FROM SnapFood.FoodOrders WHERE OrderID = @OrderID AND OrderStatus = 'OUT_FOR_DELIVERY');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP2: Add items and finalize order (calculate totals, pay, assign driver)
CREATE OR ALTER PROCEDURE SnapFood.usp_FinalizeFoodOrder
    @OrderID        INT,
    @DiscountCode   NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @CustomerID INT, @RestaurantID INT, @DeliveryAddressID INT;
    DECLARE @Subtotal DECIMAL(12,2), @DiscountAmt DECIMAL(12,2) = 0;
    DECLARE @DiscountID INT = NULL;
    DECLARE @RestLat DECIMAL(10,7), @RestLng DECIMAL(10,7);
    DECLARE @DelLat DECIMAL(10,7), @DelLng DECIMAL(10,7);
    DECLARE @DistanceKm DECIMAL(8,3), @EstMin INT;
    DECLARE @DeliveryFee DECIMAL(10,2), @Total DECIMAL(12,2);
    DECLARE @ZoneID INT = 1, @DemandIndex DECIMAL(8,2) = 1.0;
    DECLARE @RestPct DECIMAL(5,2), @DriverPct DECIMAL(5,2), @PlatformPct DECIMAL(5,2);
    DECLARE @RestShare DECIMAL(12,2), @DriverShare DECIMAL(12,2), @PlatformShare DECIMAL(12,2);

    SELECT @CustomerID = CustomerID, @RestaurantID = RestaurantID,
           @DeliveryAddressID = DeliveryAddressID
    FROM SnapFood.FoodOrders WHERE OrderID = @OrderID;

    IF @CustomerID IS NULL
        THROW 50100, 'Order not found.', 1;

    SET @Subtotal = SnapFood.fn_CalculateOrderSubtotal(@OrderID);
    IF @Subtotal <= 0
        THROW 50101, 'Order has no items.', 1;

    IF @DiscountCode IS NOT NULL
    BEGIN
        SELECT @DiscountID = DiscountID, @DiscountAmt = CalculatedDiscount
        FROM SnapFood.fn_ValidateDiscountCode(@DiscountCode, @Subtotal)
        WHERE ValidationStatus = 'VALID';

        IF @DiscountID IS NULL
            THROW 50102, 'Invalid or expired discount code.', 1;
    END

    SELECT @RestLat = Latitude, @RestLng = Longitude
    FROM SnapFood.Restaurants WHERE RestaurantID = @RestaurantID;

    SELECT @DelLat = Latitude, @DelLng = Longitude
    FROM SnapFood.CustomerAddresses WHERE AddressID = @DeliveryAddressID;

    SET @DistanceKm = SnapTaxi.fn_HaversineDistanceKm(@RestLat, @RestLng, @DelLat, @DelLng);
    SET @EstMin = SnapFood.fn_EstimatePrepTimeMinutes(@OrderID) + CAST(@DistanceKm * 3 AS INT);

    SELECT TOP 1 @DemandIndex = DemandIndex FROM SnapTaxi.DemandMetrics
    WHERE ZoneID = @ZoneID ORDER BY RecordedAt DESC;

    SET @DeliveryFee = SnapFinance.fn_CalculateDeliveryFee(@DistanceKm, @EstMin, @ZoneID, @DemandIndex);
    SET @Total = @Subtotal - @DiscountAmt + @DeliveryFee;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE SnapFood.FoodOrders
        SET Subtotal = @Subtotal, DiscountID = @DiscountID, DiscountAmount = @DiscountAmt,
            DeliveryFee = @DeliveryFee, TotalAmount = @Total, DistanceKm = @DistanceKm,
            OrderStatus = 'CONFIRMED', ConfirmedAt = SYSUTCDATETIME()
        WHERE OrderID = @OrderID;

        INSERT INTO SnapFood.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@OrderID, 'PENDING', 'CONFIRMED');

        IF @DiscountID IS NOT NULL
            UPDATE SnapFood.DiscountCodes SET UsedCount = UsedCount + 1 WHERE DiscountID = @DiscountID;

        -- Debit customer wallet
        EXEC SnapFinance.usp_WalletDebit
            @OwnerTypeID = 1, @OwnerEntityID = @CustomerID, @Amount = @Total,
            @ReferenceType = 'FOOD_ORDER', @ReferenceID = @OrderID,
            @Description = N'Payment for food order';

        -- Revenue split (subtotal only; delivery fee goes to driver + platform)
        SELECT TOP 1 @RestPct = RestaurantPct, @DriverPct = DriverPct, @PlatformPct = PlatformPct
        FROM SnapFinance.RevenueSplitRules WHERE IsActive = 1 ORDER BY RuleID;

        SET @RestShare = ROUND((@Subtotal - @DiscountAmt) * @RestPct / 100.0, 0);
        SET @DriverShare = ROUND(@DeliveryFee * 0.80, 0);  -- 80% of delivery fee to driver
        SET @PlatformShare = (@Subtotal - @DiscountAmt - @RestShare) + (@DeliveryFee - @DriverShare);

        EXEC SnapFinance.usp_WalletCredit 2, @RestaurantID, @RestShare, 2, 'FOOD_ORDER', @OrderID, N'Restaurant share';
        EXEC SnapFinance.usp_WalletCredit 4, 0, @PlatformShare, 4, 'FOOD_ORDER', @OrderID, N'Platform commission';

        -- Driver share credited after delivery assignment (held in platform temporarily)
        -- Stored in order metadata via platform wallet; transferred on delivery completion

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Cross-schema: assign nearest idle online driver
    EXEC SnapTaxi.usp_AssignNearestDriver @OrderID = @OrderID, @PickupLat = @RestLat,
         @PickupLng = @RestLng, @DropLat = @DelLat, @DropLng = @DelLng,
         @DeliveryFee = @DeliveryFee, @DriverShare = @DriverShare;
END;
GO

-- SP3: Cancel order with refund
CREATE OR ALTER PROCEDURE SnapFood.usp_CancelFoodOrder
    @OrderID            INT,
    @CancellationReason NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Status NVARCHAR(20), @CustomerID INT, @RestaurantID INT;
    DECLARE @Total DECIMAL(12,2), @Subtotal DECIMAL(12,2), @DiscountAmt DECIMAL(12,2);
    DECLARE @DeliveryFee DECIMAL(10,2), @PlacedAt DATETIME2;
    DECLARE @RefundPct DECIMAL(5,2), @RefundAmt DECIMAL(12,2);
    DECLARE @RestShare DECIMAL(12,2), @PlatformShare DECIMAL(12,2);

    SELECT @Status = OrderStatus, @CustomerID = CustomerID, @RestaurantID = RestaurantID,
           @Total = TotalAmount, @Subtotal = Subtotal, @DiscountAmt = DiscountAmount,
           @DeliveryFee = DeliveryFee, @PlacedAt = PlacedAt
    FROM SnapFood.FoodOrders WHERE OrderID = @OrderID;

    IF @Status IN ('DELIVERED', 'CANCELLED')
        THROW 50200, 'Order cannot be cancelled.', 1;

    IF @Status = 'PENDING'
    BEGIN
        UPDATE SnapFood.FoodOrders SET OrderStatus = 'CANCELLED', CancelledAt = SYSUTCDATETIME(),
               CancellationReason = @CancellationReason WHERE OrderID = @OrderID;
        RETURN;
    END

    SET @RefundPct = SnapFinance.fn_GetRefundPercentage('FOOD', @PlacedAt, SYSUTCDATETIME());
    SET @RefundAmt = ROUND(@Total * @RefundPct / 100.0, 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE SnapFood.FoodOrders
        SET OrderStatus = 'CANCELLED', CancelledAt = SYSUTCDATETIME(),
            CancellationReason = @CancellationReason
        WHERE OrderID = @OrderID;

        INSERT INTO SnapFood.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@OrderID, @Status, 'CANCELLED');

        IF @RefundAmt > 0
        BEGIN
            EXEC SnapFinance.usp_WalletCredit 1, @CustomerID, @RefundAmt, 3, 'REFUND', @OrderID,
                 N'Order cancellation refund';

            -- Reverse restaurant/platform shares proportionally
            SELECT TOP 1 @RestShare = ROUND((@Subtotal - @DiscountAmt) * RestaurantPct / 100.0, 0)
            FROM SnapFinance.RevenueSplitRules WHERE IsActive = 1 ORDER BY RuleID;

            SET @PlatformShare = (@Subtotal - @DiscountAmt - @RestShare);
            DECLARE @RestRefund DECIMAL(12,2) = ROUND(@RestShare * @RefundPct / 100.0, 0);
            DECLARE @PlatRefund DECIMAL(12,2) = ROUND(@PlatformShare * @RefundPct / 100.0, 0)
                + ROUND(@DeliveryFee * @RefundPct / 100.0, 0);

            IF @RestRefund > 0
                EXEC SnapFinance.usp_WalletDebit 2, @RestaurantID, @RestRefund, 3, 'REFUND', @OrderID, N'Refund reversal';
            IF @PlatRefund > 0
                EXEC SnapFinance.usp_WalletDebit 4, 0, @PlatRefund, 3, 'REFUND', @OrderID, N'Refund reversal';
        END

        -- Cancel delivery assignment if exists
        UPDATE SnapTaxi.DeliveryAssignments SET AssignmentStatus = 'CANCELLED'
        WHERE FoodOrderID = @OrderID AND AssignmentStatus <> 'DELIVERED';

        UPDATE SnapTaxi.DriverAvailability SET IsIdle = 1
        WHERE DriverID IN (SELECT DriverID FROM SnapTaxi.DeliveryAssignments WHERE FoodOrderID = @OrderID);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ============================================================================
   STORED PROCEDURES - SnapTaxi (continued)
   ============================================================================ */

-- SP5: Complete delivery and pay driver
CREATE OR ALTER PROCEDURE SnapTaxi.usp_CompleteDelivery
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @DriverID INT, @RideID INT, @DeliveryFee DECIMAL(10,2);
    DECLARE @DriverShare DECIMAL(10,2);

    SELECT @DriverID = da.DriverID, @RideID = da.RideID, @DeliveryFee = fo.DeliveryFee
    FROM SnapTaxi.DeliveryAssignments da
    INNER JOIN SnapFood.FoodOrders fo ON fo.OrderID = da.FoodOrderID
    WHERE da.FoodOrderID = @OrderID AND da.AssignmentStatus = 'ASSIGNED';

    IF @DriverID IS NULL
        THROW 50400, 'Active delivery assignment not found.', 1;

    SET @DriverShare = ROUND(@DeliveryFee * 0.80, 0);

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE SnapTaxi.DeliveryAssignments
        SET AssignmentStatus = 'DELIVERED', DeliveredAt = SYSUTCDATETIME()
        WHERE FoodOrderID = @OrderID;

        UPDATE SnapTaxi.Rides SET RideStatus = 'COMPLETED', CompletedAt = SYSUTCDATETIME()
        WHERE RideID = @RideID;

        INSERT INTO SnapTaxi.RideStatusHistory (RideID, OldStatus, NewStatus)
        VALUES (@RideID, 'ASSIGNED', 'COMPLETED');

        UPDATE SnapFood.FoodOrders SET OrderStatus = 'DELIVERED', DeliveredAt = SYSUTCDATETIME()
        WHERE OrderID = @OrderID;

        INSERT INTO SnapFood.OrderStatusHistory (OrderID, OldStatus, NewStatus)
        VALUES (@OrderID, 'OUT_FOR_DELIVERY', 'DELIVERED');

        EXEC SnapFinance.usp_WalletCredit 3, @DriverID, @DriverShare, 2, 'DELIVERY', @OrderID,
             N'Driver delivery fee share';

        UPDATE SnapTaxi.DriverAvailability SET IsIdle = 1 WHERE DriverID = @DriverID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- SP6: Request standalone taxi ride with dynamic fare
CREATE OR ALTER PROCEDURE SnapTaxi.usp_RequestRide
    @CustomerID     INT,
    @PickupLat      DECIMAL(10,7),
    @PickupLng      DECIMAL(10,7),
    @DropLat        DECIMAL(10,7),
    @DropLng        DECIMAL(10,7),
    @ZoneID         INT = 1,
    @RideID         INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DistanceKm DECIMAL(8,3);
    DECLARE @EstMin INT;
    DECLARE @VehicleTypeID TINYINT = 2;
    DECLARE @Fare DECIMAL(10,2);
    DECLARE @DriverID INT;

    SET @DistanceKm = SnapTaxi.fn_HaversineDistanceKm(@PickupLat, @PickupLng, @DropLat, @DropLng);
    SET @EstMin = CAST(@DistanceKm * 3 AS INT) + 5;
    SET @Fare = SnapFinance.fn_CalculateRideFare(@DistanceKm, @EstMin, @VehicleTypeID, @ZoneID);

    INSERT INTO SnapTaxi.Rides (CustomerID, PickupLatitude, PickupLongitude,
        DropoffLatitude, DropoffLongitude, DistanceKm, EstimatedMinutes,
        RideStatus, BaseFare, TotalFare)
    VALUES (@CustomerID, @PickupLat, @PickupLng, @DropLat, @DropLng,
        @DistanceKm, @EstMin, 'REQUESTED', @Fare, @Fare);

    SET @RideID = SCOPE_IDENTITY();

    INSERT INTO SnapTaxi.RideStatusHistory (RideID, OldStatus, NewStatus)
    VALUES (@RideID, NULL, 'REQUESTED');

    -- Assign nearest driver
    ;WITH NearestDrivers AS (
        SELECT d.DriverID,
            SnapTaxi.fn_HaversineDistanceKm(dl.Latitude, dl.Longitude, @PickupLat, @PickupLng) AS Dist
        FROM SnapTaxi.vw_AvailableDrivers d
        CROSS APPLY (
            SELECT TOP 1 Latitude, Longitude FROM SnapTaxi.DriverLocations
            WHERE DriverID = d.DriverID ORDER BY RecordedAt DESC
        ) dl
    )
    SELECT TOP 1 @DriverID = DriverID FROM NearestDrivers ORDER BY Dist;

    IF @DriverID IS NOT NULL
    BEGIN
        UPDATE SnapTaxi.Rides SET DriverID = @DriverID, RideStatus = 'ASSIGNED' WHERE RideID = @RideID;
        INSERT INTO SnapTaxi.RideStatusHistory (RideID, OldStatus, NewStatus) VALUES (@RideID, 'REQUESTED', 'ASSIGNED');
        UPDATE SnapTaxi.DriverAvailability SET IsIdle = 0 WHERE DriverID = @DriverID;

        EXEC SnapFinance.usp_WalletDebit 1, @CustomerID, @Fare, 1, 'RIDE', @RideID, N'Ride fare payment';
        DECLARE @DriverShare DECIMAL(10,2) = ROUND(@Fare * 0.75, 0);
        DECLARE @PlatformShare DECIMAL(10,2) = @Fare - @DriverShare;
        EXEC SnapFinance.usp_WalletCredit 3, @DriverID, @DriverShare, 2, 'RIDE', @RideID, N'Ride earnings';
        EXEC SnapFinance.usp_WalletCredit 4, 0, @PlatformShare, 4, 'RIDE', @RideID, N'Ride commission';
    END
END;
GO

/* ============================================================================
   BONUS: Data Export staging table & Import procedure
   ============================================================================ */
CREATE OR ALTER PROCEDURE SnapFood.usp_ExportOrdersToStaging
AS
BEGIN
    SET NOCOUNT ON;
    IF OBJECT_ID('tempdb..#OrderExport') IS NOT NULL DROP TABLE #OrderExport;
    SELECT
        fo.OrderID, c.FirstName, c.LastName, r.Name AS Restaurant,
        fo.OrderStatus, fo.Subtotal, fo.TotalAmount, fo.PlacedAt
    INTO #OrderExport
    FROM SnapFood.FoodOrders fo
    INNER JOIN SnapFood.Customers c ON c.CustomerID = fo.CustomerID
    INNER JOIN SnapFood.Restaurants r ON r.RestaurantID = fo.RestaurantID;

    SELECT * FROM #OrderExport;
    PRINT N'Export ready. Use bcp or SSIS to write #OrderExport to Excel/CSV.';
END;
GO

/* ============================================================================
   TRIGGERS - SnapFood Audit Log (3+ triggers)
   ============================================================================ */

CREATE OR ALTER TRIGGER SnapFood.trg_FoodOrders_Audit
ON SnapFood.FoodOrders
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapFood.FoodAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'FoodOrders', 'I', CAST(i.OrderID AS NVARCHAR(50)),
           NULL,
           CONCAT(N'Status=', i.OrderStatus, N'; Total=', i.TotalAmount)
    FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted);

    INSERT INTO SnapFood.FoodAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'FoodOrders', 'U', CAST(i.OrderID AS NVARCHAR(50)),
           CONCAT(N'Status=', d.OrderStatus, N'; Total=', d.TotalAmount),
           CONCAT(N'Status=', i.OrderStatus, N'; Total=', i.TotalAmount)
    FROM inserted i INNER JOIN deleted d ON i.OrderID = d.OrderID;

    INSERT INTO SnapFood.FoodAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'FoodOrders', 'D', CAST(d.OrderID AS NVARCHAR(50)),
           CONCAT(N'Status=', d.OrderStatus), NULL
    FROM deleted d WHERE NOT EXISTS (SELECT 1 FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER SnapFood.trg_OrderItems_ValidatePrice
ON SnapFood.OrderItems
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN SnapFood.MenuItems mi ON mi.ItemID = i.ItemID
        WHERE mi.IsAvailable = 0
    )
    BEGIN
        RAISERROR('Cannot order unavailable menu item.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

-- Cross-schema trigger: auto-log when order moves to CONFIRMED (delivery pipeline)
CREATE OR ALTER TRIGGER SnapFood.trg_FoodOrders_OnConfirmed
ON SnapFood.FoodOrders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, NewValues)
    SELECT 'CrossSchema_FoodConfirmed', 'I',
           CAST(i.OrderID AS NVARCHAR(50)),
           CONCAT(N'Food order confirmed; awaiting driver assignment. Total=', i.TotalAmount)
    FROM inserted i
    INNER JOIN deleted d ON i.OrderID = d.OrderID
    WHERE i.OrderStatus = 'CONFIRMED' AND d.OrderStatus <> 'CONFIRMED';
END;
GO

/* ============================================================================
   TRIGGERS - SnapTaxi Audit Log (3+ triggers)
   ============================================================================ */

CREATE OR ALTER TRIGGER SnapTaxi.trg_DeliveryAssignments_Audit
ON SnapTaxi.DeliveryAssignments
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, NewValues)
    SELECT 'DeliveryAssignments', 'I', CAST(i.AssignmentID AS NVARCHAR(50)),
           CONCAT(N'Order=', i.FoodOrderID, N'; Driver=', i.DriverID, N'; Status=', i.AssignmentStatus)
    FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted);

    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'DeliveryAssignments', 'U', CAST(i.AssignmentID AS NVARCHAR(50)),
           d.AssignmentStatus, i.AssignmentStatus
    FROM inserted i INNER JOIN deleted d ON i.AssignmentID = d.AssignmentID;

    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, OldValues)
    SELECT 'DeliveryAssignments', 'D', CAST(d.AssignmentID AS NVARCHAR(50)), d.AssignmentStatus
    FROM deleted d WHERE NOT EXISTS (SELECT 1 FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER SnapTaxi.trg_DriverAvailability_Log
ON SnapTaxi.DriverAvailability
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'DriverAvailability', 'U', CAST(i.DriverID AS NVARCHAR(50)),
           CONCAT(N'Online=', d.IsOnline, N'; Idle=', d.IsIdle),
           CONCAT(N'Online=', i.IsOnline, N'; Idle=', i.IsIdle)
    FROM inserted i INNER JOIN deleted d ON i.DriverID = d.DriverID
    WHERE i.IsOnline <> d.IsOnline OR i.IsIdle <> d.IsIdle;
END;
GO

CREATE OR ALTER TRIGGER SnapTaxi.trg_Rides_StatusAudit
ON SnapTaxi.Rides
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapTaxi.TaxiAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'Rides', 'U', CAST(i.RideID AS NVARCHAR(50)),
           d.RideStatus, i.RideStatus
    FROM inserted i INNER JOIN deleted d ON i.RideID = d.RideID
    WHERE i.RideStatus <> d.RideStatus;
END;
GO

/* ============================================================================
   TRIGGERS - SnapFinance Audit Log
   ============================================================================ */

CREATE OR ALTER TRIGGER SnapFinance.trg_Wallets_BalanceAudit
ON SnapFinance.Wallets
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapFinance.FinanceAuditLog (TableName, Operation, RecordID, OldValues, NewValues)
    SELECT 'Wallets', 'U', CAST(i.WalletID AS NVARCHAR(50)),
           CONCAT(N'Balance=', d.Balance),
           CONCAT(N'Balance=', i.Balance)
    FROM inserted i INNER JOIN deleted d ON i.WalletID = d.WalletID
    WHERE i.Balance <> d.Balance;
END;
GO

CREATE OR ALTER TRIGGER SnapFinance.trg_WalletTransactions_Audit
ON SnapFinance.WalletTransactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO SnapFinance.FinanceAuditLog (TableName, Operation, RecordID, NewValues)
    SELECT 'WalletTransactions', 'I', CAST(i.TransactionID AS NVARCHAR(50)),
           CONCAT(N'Wallet=', i.WalletID, N'; Amount=', i.Amount, N'; Ref=', i.ReferenceType)
    FROM inserted i;
END;
GO

PRINT 'Views, functions, procedures, and triggers created successfully.';
GO
