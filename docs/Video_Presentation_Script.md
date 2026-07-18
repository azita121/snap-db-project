# SnapDB — Video Presentation Script (15–20 Minutes)

**Format:** Screen recording with SSMS + split speaking roles  
**Recommended split:** Member A (SnapFood) / Member B (SnapTaxi + Finance)

---

## Segment 1: Introduction & Architecture (3 min) — Both Members

### Member A (0:00 – 1:30)
> "Hello, we are [Team Name]. Our project is **SnapDB** — an integrated database for food ordering and taxi delivery.
>
> We built two main schemas: **SnapFood** for restaurants and orders, and **SnapTaxi** for our delivery fleet. They interact when a food order needs a driver.
>
> A third schema, **SnapFinance**, handles four wallet types: Customer, Restaurant, Driver, and Platform."

**[Show:** GitHub repo structure, `sql/` folder listing**]**

### Member B (1:30 – 3:00)
> "Let me walk through the ER diagram. SnapFood has 12 tables — customers, restaurants, menus, orders. SnapTaxi has 12 tables — drivers, vehicles, zones, delivery assignments.
>
> The key cross-schema link is `DeliveryAssignments.FoodOrderID` → `FoodOrders.OrderID`. When an order is confirmed, our stored procedure finds the nearest online idle driver and creates an assignment automatically."

**[Show:** Proposal ER diagram (mermaid or draw.io export), highlight cross-schema arrow**]**

---

## Segment 2: Scenario Execution (8 min) — Primary Demo

### Scenario A: Discount Validation (1 min) — Member A

**[Run in SSMS]:**
```sql
SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'WELCOME20', 300000);
SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'EXPIRED', 300000);
SELECT * FROM SnapFood.fn_ValidateDiscountCode(N'WELCOME20', 50000);
```

> "Our discount function checks expiry, usage limits, and minimum order value. WELCOME20 is valid for 300K orders but fails for 50K because it's below the minimum."

---

### Scenario B: Dynamic Pricing (1 min) — Member B

**[Run]:**
```sql
SELECT SnapFinance.fn_CalculateDeliveryFee(5.2, 25, 1, 1.8) AS HighDemand;
SELECT SnapFinance.fn_CalculateDeliveryFee(2.0, 15, 3, 0.8) AS LowDemand;
```

> "Delivery fees are never fixed. This function combines base fare, per-km rate, zone surge, and demand index. A 5km high-demand delivery costs significantly more than a 2km low-demand one."

---

### Scenario C: Full Order Flow + Wallet Movement (3 min) — Member A leads, Member B shows wallets

**[Run wallet snapshot BEFORE]:**
```sql
SELECT wot.TypeName, w.OwnerEntityID, w.Balance
FROM SnapFinance.Wallets w
JOIN SnapFinance.WalletOwnerTypes wot ON wot.OwnerTypeID = w.OwnerTypeID
WHERE w.OwnerEntityID IN (1,1,0) OR w.OwnerTypeID IN (1,2,3,4)
ORDER BY wot.OwnerTypeID, w.OwnerEntityID;
```

**[Place order]:**
```sql
DECLARE @OID INT;
EXEC SnapFood.usp_PlaceFoodOrder @CustomerID=1, @RestaurantID=1,
     @DeliveryAddressID=1, @OrderID=@OID OUTPUT;

INSERT INTO SnapFood.OrderItems (OrderID, ItemID, Quantity, UnitPrice)
VALUES (@OID, 1, 2, 280000), (@OID, 3, 1, 250000);

EXEC SnapFood.usp_FinalizeFoodOrder @OrderID=@OID, @DiscountCode=N'WELCOME20';
```

> Member A: "Ali orders two Margherita pizzas and a Carbonara — 810K subtotal. WELCOME20 gives 20% off."

**[Show order + assignment]:**
```sql
SELECT * FROM SnapFood.FoodOrders WHERE OrderID = @OID;
SELECT * FROM SnapTaxi.vw_DeliveryTracking WHERE OrderID = @OID;
```

> Member B: "The system automatically assigned the nearest idle driver — you can see the cross-schema link in DeliveryTracking view."

**[Run wallet snapshot AFTER]:**
> "Watch the Customer wallet decrease and Restaurant/Platform wallets increase in real time."

---

### Scenario D: Complete Delivery (1 min) — Member B

```sql
EXEC SnapTaxi.usp_CompleteDelivery @OrderID = @OID;
```

**[Show wallets again]**
> "On delivery completion, the driver receives 80% of the delivery fee. All four wallets updated correctly."

---

### Scenario E: Cancellation & Refund (2 min) — Member A

```sql
-- Place second order
DECLARE @OID2 INT;
EXEC SnapFood.usp_PlaceFoodOrder @CustomerID=2, @RestaurantID=2,
     @DeliveryAddressID=3, @OrderID=@OID2 OUTPUT;
INSERT INTO SnapFood.OrderItems (OrderID, ItemID, Quantity, UnitPrice)
VALUES (@OID2, 4, 1, 220000), (@OID2, 6, 2, 80000);
EXEC SnapFood.usp_FinalizeFoodOrder @OrderID=@OID2;

EXEC SnapFood.usp_CancelFoodOrder @OrderID=@OID2,
     @CancellationReason=N'Customer changed mind';
```

> "Because we cancelled within 30 minutes, the refund function returns 100%. Customer wallet is credited back, and restaurant/platform shares are reversed."

**[Show]:**
```sql
SELECT SnapFinance.fn_GetRefundPercentage('FOOD', PlacedAt, CancelledAt)
FROM SnapFood.FoodOrders WHERE OrderID = @OID2;
```

---

## Segment 3: Deep Code Dive (5 min)

### 3.1 Trigger Deep Dive (1.5 min) — Member A

**File:** `03_Views_Functions_Procedures_Triggers.sql` → `trg_FoodOrders_OnConfirmed`

> "This cross-schema trigger fires when an order status changes to CONFIRMED. It writes an entry to SnapTaxi's audit log, creating a traceable link between the two schemas without tight coupling."

**[Show trigger code, highlight INSERT INTO SnapTaxi.TaxiAuditLog]**

---

### 3.2 Stored Procedure Deep Dive (2 min) — Member B

**File:** `usp_AssignNearestDriver`

> "Driver allocation uses a CTE with Haversine distance. We filter through vw_AvailableDrivers — only online AND idle drivers. We pick TOP 1 ordered by distance to the restaurant pickup point."

**[Show the CTE and ORDER BY DistanceToPickup ASC]**

> "Then we atomically: create a Ride, create DeliveryAssignment, mark driver busy, and update food order to OUT_FOR_DELIVERY."

---

### 3.3 Function Deep Dive (1.5 min) — Member A

**File:** `fn_ValidateDiscountCode`

> "This is a table-valued function returning both validation status AND calculated discount in one call. The CASE expression handles all failure modes explicitly — expired, usage limit, below minimum — so the calling procedure gets a clear reason."

---

## Segment 4: Bonus Features (2 min) — Member B

### RBAC Demo
```sql
SELECT u.Username, ur.RoleName, rp.PermissionName, rp.CanRead, rp.CanWrite
FROM SnapFinance.Users u
JOIN SnapFinance.UserRoles ur ON ur.RoleID = u.RoleID
JOIN SnapFinance.RolePermissions rp ON rp.RoleID = ur.RoleID;
```

### Export Demo
```sql
EXEC SnapFood.usp_ExportOrdersToStaging;
-- bcp SnapDB..FoodOrders out orders.csv -c -T -S localhost
```

> "We implemented four roles with granular permissions and an export staging procedure compatible with bcp for Excel export."

---

## Segment 5: Audit Logs & Wrap-Up (2 min) — Both

```sql
SELECT TOP 3 * FROM SnapFood.FoodAuditLog ORDER BY LogID DESC;
SELECT TOP 3 * FROM SnapTaxi.TaxiAuditLog ORDER BY LogID DESC;
SELECT TOP 3 * FROM SnapFinance.FinanceAuditLog ORDER BY LogID DESC;
```

### Member A (0:30)
> "Every critical table has trigger-based audit logging. Food orders, delivery assignments, and wallet changes are all traceable."

### Member B (0:30)
> "To recap: dynamic pricing, four-wallet financial flow, nearest-driver allocation, discount validation, and cross-schema triggers — all demonstrated with live data."

### Both (0:30)
> "Thank you. Our code is on GitHub at github.com/azita121/snap-db-project. Questions?"

---

## Presentation Checklist

- [ ] SSMS connected to SnapDB with test data loaded
- [ ] Increase SSMS font size for recording
- [ ] Pre-run scripts 01-03 before recording
- [ ] Have wallet query saved as snippet for quick before/after
- [ ] Split speaking time ~50-50
- [ ] Total runtime target: 15–18 minutes

---

## Timing Summary

| Segment | Duration | Speaker |
|---------|----------|---------|
| Intro & ER | 3 min | Both |
| Scenario Execution | 8 min | A + B |
| Code Deep Dive | 5 min | A + B |
| Bonus Features | 2 min | B |
| Wrap-Up | 2 min | Both |
| **Total** | **~20 min** | |
