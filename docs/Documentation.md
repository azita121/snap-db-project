# SnapDB — Technical Documentation

Complete reference for all Views, Functions, Stored Procedures, and Triggers.

---

## 1. Architecture Overview

SnapDB uses three SQL Server schemas:

| Schema | Role |
|--------|------|
| `SnapFood` | Food ordering domain |
| `SnapTaxi` | Driver fleet and ride management |
| `SnapFinance` | Wallets, pricing, refunds, RBAC |

Cross-schema calls flow: **SnapFood → SnapFinance → SnapTaxi** during order finalization.

---

## 2. Functions

### 2.1 SnapTaxi Functions

| Function | Purpose |
|----------|---------|
| `fn_HaversineDistanceKm` | GPS distance between two coordinates |
| `fn_EstimateArrivalMinutes` | ETA from distance and traffic factor |
| `fn_GetZoneDemandIndex` | Current demand index for a delivery zone |

### 2.2 `SnapFood.fn_ValidateDiscountCode`

**Purpose:** Validate a discount/voucher code before application.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| @Code | NVARCHAR(30) | Discount code string |
| @OrderSubtotal | DECIMAL(12,2) | Current order subtotal |

**Returns:** Table with columns:
- `ValidationStatus`: `VALID`, `EXPIRED`, `INACTIVE`, `NOT_YET_VALID`, `USAGE_LIMIT_REACHED`, `BELOW_MIN_ORDER`
- `CalculatedDiscount`: Amount to deduct if valid

**Validation rules:**
1. Code must be active (`IsActive = 1`)
2. Current UTC time must be between `ValidFrom` and `ValidTo`
3. `UsedCount < MaxUsageCount`
4. `@OrderSubtotal >= MinOrderValue`

---

### 2.3 `SnapFood.fn_CalculateOrderSubtotal`

**Purpose:** Sum line items for an order.

**Parameters:** `@OrderID INT`

**Returns:** `DECIMAL(12,2)`

---

### 2.4 `SnapFood.fn_EstimatePrepTimeMinutes`

**Purpose:** Return maximum prep time among ordered items.

**Parameters:** `@OrderID INT`

**Returns:** `INT` — minutes

---

### 2.5 `SnapFinance.fn_CalculateDeliveryFee`

**Purpose:** **Dynamic delivery fee** — not a fixed value.

**Formula:**
```
Fee = (BaseFare + Distance×PerKm + Minutes×PerMin)
      × DemandMultiplier × ZoneSurge × DemandIndexFactor
Fee = MAX(Fee, MinFare)
```

**Parameters:**
| Param | Description |
|-------|-------------|
| @DistanceKm | Restaurant-to-customer distance |
| @EstimatedMin | Estimated delivery time |
| @ZoneID | Delivery zone for surge lookup |
| @DemandIndex | PendingRequests / ActiveDrivers ratio |

**Demand index factor:** >1.5 → ×1.2, >1.0 → ×1.1, else ×1.0

---

### 2.6 `SnapFinance.fn_CalculateRideFare`

**Purpose:** Dynamic standalone ride fare.

**Formula:**
```
Fare = (BaseFare + Distance×PerKm + Minutes×PerMin) × VehicleMultiplier × ZoneSurge
Fare = MAX(Fare, MinFare)
```

---

### 2.7 `SnapFinance.fn_GetRefundPercentage`

**Purpose:** Determine refund % based on minutes elapsed since order placement.

**Logic:** Selects the highest `MinutesBeforePrep` threshold that the elapsed time satisfies, returning the associated `RefundPct`.

**Example policies:**
| Minutes Elapsed | Refund % |
|-----------------|----------|
| ≥ 30 | 100% |
| ≥ 15 | 50% |
| < 15 | 0% |

---

## 3. Views

### SnapFood Views

| View | Purpose |
|------|---------|
| `vw_ActiveOrdersSummary` | All non-terminal orders with customer/restaurant names and elapsed time |
| `vw_RestaurantPerformance` | Revenue, order count, and average review rating per restaurant |
| `vw_MenuWithCategories` | Denormalized menu for display (read-only reporting) |

### SnapTaxi Views

| View | Purpose |
|------|---------|
| `vw_AvailableDrivers` | Online + idle drivers with latest GPS and vehicle type |
| `vw_DeliveryTracking` | End-to-end delivery status linking food orders to drivers |
| `vw_ZoneDemandOverview` | Zone-level demand index and surge multipliers |

---

## 4. Stored Procedures

### 4.1 `SnapFinance.usp_WalletDebit` / `usp_WalletCredit`

**Purpose:** Atomic wallet balance updates with ledger entries.

**Safety:** Debit throws error 50002 if insufficient balance. Both throw if wallet not found.

---

### 4.2 `SnapFood.usp_PlaceFoodOrder`

**Purpose:** Create a PENDING order shell.

**Output:** `@OrderID`

**Flow:**
1. INSERT into `FoodOrders` with status PENDING
2. INSERT into `OrderStatusHistory`

---

### 4.3 `SnapFood.usp_FinalizeFoodOrder` ⭐ Key Procedure

**Purpose:** Complete order placement with payment and driver assignment.

**Flow:**
1. Calculate subtotal from order items
2. Validate discount code (if provided)
3. Calculate distance (Haversine) and dynamic delivery fee
4. Update order totals and set status CONFIRMED
5. **Debit Customer wallet** for total amount
6. **Credit Restaurant wallet** (70% of net subtotal)
7. **Credit Platform wallet** (commission + delivery platform share)
8. **Cross-schema call:** `SnapTaxi.usp_AssignNearestDriver`

**Transaction:** Wrapped in TRY/CATCH with ROLLBACK on failure.

---

### 4.4 `SnapFood.usp_CancelFoodOrder` ⭐ Key Procedure

**Purpose:** Cancel order with time-based refund.

**Flow:**
1. Validate order is cancellable
2. Calculate refund % via `fn_GetRefundPercentage`
3. Credit Customer wallet with refund amount
4. Debit Restaurant and Platform wallets proportionally
5. Cancel delivery assignment and free driver (set IsIdle = 1)

---

### 4.5 `SnapTaxi.usp_AssignNearestDriver` ⭐ Key Procedure (Cross-Schema)

**Purpose:** Smart driver allocation — nearest online idle driver.

**Algorithm:**
```sql
SELECT TOP 1 DriverID
FROM vw_AvailableDrivers
ORDER BY HaversineDistance(driver_location, pickup_point) ASC
```

**Actions:**
1. Create `Rides` record with ASSIGNED status
2. Create `DeliveryAssignments` linking FoodOrderID ↔ DriverID
3. Set driver `IsIdle = 0`
4. Update food order status to OUT_FOR_DELIVERY

---

### 4.6 `SnapTaxi.usp_CompleteDelivery`

**Purpose:** Mark delivery complete and pay driver (80% of delivery fee).

---

### 4.7 `SnapTaxi.usp_RequestRide`

**Purpose:** Standalone taxi ride with dynamic fare and auto driver assignment.

---

### 4.8 `SnapFood.usp_ExportOrdersToStaging` (Bonus)

**Purpose:** Export orders to temp table for bcp/Excel export.

---

## 5. Triggers

### SnapFood Triggers

| Trigger | Event | Purpose |
|---------|-------|---------|
| `trg_FoodOrders_Audit` | INSERT/UPDATE/DELETE on FoodOrders | Log all order changes to FoodAuditLog |
| `trg_OrderItems_ValidatePrice` | INSERT/UPDATE on OrderItems | Block orders for unavailable menu items |
| `trg_FoodOrders_OnConfirmed` | UPDATE on FoodOrders | **Cross-schema:** Log to TaxiAuditLog when order confirmed |

### SnapTaxi Triggers

| Trigger | Event | Purpose |
|---------|-------|---------|
| `trg_DeliveryAssignments_Audit` | INSERT/UPDATE/DELETE | Log assignment lifecycle |
| `trg_DriverAvailability_Log` | UPDATE | Log online/idle status changes |
| `trg_Rides_StatusAudit` | UPDATE | Log ride status transitions |

### SnapFinance Triggers

| Trigger | Event | Purpose |
|---------|-------|---------|
| `trg_Wallets_BalanceAudit` | UPDATE | Log every balance change |
| `trg_WalletTransactions_Audit` | INSERT | Log new ledger entries |

---

## 6. Financial Flow Diagram

### Order Placement (810,000 subtotal, 20% discount, ~45,000 delivery fee)

```
Customer Wallet          Restaurant Wallet       Driver Wallet          Platform Wallet
     │                          │                      │                       │
     │ ──── Debit 693,000 ────► │                      │                       │
     │                          │ ◄── Credit 453,600 ──│                       │
     │                          │   (70% of net)       │                       │
     │                          │                      │                       │
     │                          │                      │ ◄── Credit 36,000 ────│ (on delivery)
     │                          │                      │   (80% delivery fee)  │
     │                          │                      │                       │
     │                          │                      │                       │ ◄── Credit 239,400
     │                          │                      │                       │   (commission + 20% delivery)
```

### Cancellation Refund (within 30 min → 100%)

```
Customer Wallet ◄── Credit refund amount
Restaurant Wallet ──► Debit proportional share
Platform Wallet ──► Debit proportional share
```

---

## 7. Wallet Types

| OwnerTypeID | TypeName | OwnerEntityID maps to |
|-------------|----------|----------------------|
| 1 | Customer | SnapFood.Customers.CustomerID |
| 2 | Restaurant | SnapFood.Restaurants.RestaurantID |
| 3 | Driver | SnapTaxi.Drivers.DriverID |
| 4 | Platform | 0 (singleton) |

---

## 8. Execution Order

```
01_Create_Tables.sql
02_Insert_Test_Data.sql
03_Views_Functions_Procedures_Triggers.sql
04_Test_Execution.sql
05_Backup.sql
```

---

## 9. Error Codes

| Code | Message |
|------|---------|
| 50001 | Wallet not found |
| 50002 | Insufficient wallet balance |
| 50100 | Order not found |
| 50101 | Order has no items |
| 50102 | Invalid discount code |
| 50200 | Order cannot be cancelled |
| 50300 | No available drivers |
| 50400 | Delivery assignment not found |

---

*Convert to PDF: `pandoc docs/Documentation.md -o docs/Documentation.pdf`*
