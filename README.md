# SnapDB — University Database Project

[![SQL Server](https://img.shields.io/badge/DBMS-SQL%20Server-CC2927?logo=microsoft-sql-server)](https://www.microsoft.com/sql-server)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An integrated database system combining **SnapFood** (online food ordering) and **SnapTaxi** (taxi/delivery fleet management) with shared financial wallets, dynamic pricing, and cross-schema driver allocation.

**Repository:** [github.com/azita121/snap-db-project](https://github.com/azita121/snap-db-project)

---

## Features

- **Two interacting schemas** — SnapFood orders trigger SnapTaxi driver assignments
- **Four wallet types** — Customer, Restaurant, Driver, Platform with full transaction ledger
- **Dynamic pricing** — Delivery fees and ride fares calculated from distance, zone surge, and demand
- **Smart discount validation** — Expiry, usage limits, minimum order checks
- **Nearest-driver allocation** — Online + idle drivers selected by GPS proximity
- **Cancellation & refunds** — Time-based refund percentages with wallet reversal
- **33 normalized tables** (3NF) across 3 schemas
- **Audit logging** — Trigger-based logs for all critical operations
- **RBAC bonus** — Admin, Customer, Restaurant Manager, Driver roles

---

## Project Structure

```
snap-db-project/
├── sql/
│   ├── 01_Create_Tables.sql              # DDL for all schemas
│   ├── 02_Insert_Test_Data.sql           # Test data (5–100 rows/table)
│   ├── 03_Views_Functions_Procedures_Triggers.sql
│   ├── 04_Test_Execution.sql             # Demo scenarios
│   └── 05_Backup.sql                     # Database backup command
├── docs/
│   ├── Proposal.md                       # Project proposal (+ PDF)
│   ├── Documentation.md                  # Technical reference (+ PDF)
│   └── Video_Presentation_Script.md      # 15–20 min presentation outline
├── scripts/
│   └── generate_pdfs.ps1                 # Convert Markdown to PDF
├── README.md
└── .gitignore
```

---

## Prerequisites

- **Microsoft SQL Server 2019+** (Express edition works)
- **SQL Server Management Studio (SSMS)** or `sqlcmd`
- Optional: [Pandoc](https://pandoc.org/) for PDF generation

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/azita121/snap-db-project.git
cd snap-db-project
```

### 2. Run SQL scripts in order

Open SSMS and execute:

```
sql/01_Create_Tables.sql
sql/02_Insert_Test_Data.sql
sql/03_Views_Functions_Procedures_Triggers.sql
sql/04_Test_Execution.sql
```

Or via command line:

```powershell
sqlcmd -S localhost -E -i sql/01_Create_Tables.sql
sqlcmd -S localhost -E -i sql/02_Insert_Test_Data.sql
sqlcmd -S localhost -E -i sql/03_Views_Functions_Procedures_Triggers.sql
sqlcmd -S localhost -E -i sql/04_Test_Execution.sql
```

### 3. Create backup

```powershell
sqlcmd -S localhost -E -i sql/05_Backup.sql
```

### 4. Generate PDF documentation (optional)

```powershell
.\scripts\generate_pdfs.ps1
```

---

## Schema Overview

| Schema | Tables | Purpose |
|--------|--------|---------|
| **SnapFood** | 12 | Customers, restaurants, menus, orders, discounts, reviews |
| **SnapTaxi** | 12 | Drivers, vehicles, zones, rides, delivery assignments |
| **SnapFinance** | 9 | Wallets, transactions, pricing, refunds, RBAC |

### Cross-Schema Flow

```
Customer places order (SnapFood)
        ↓
Payment split across wallets (SnapFinance)
        ↓
Nearest driver assigned (SnapTaxi)
        ↓
Delivery completed → driver paid (SnapFinance + SnapTaxi)
```

---

## Key Database Objects

| Type | Count | Examples |
|------|-------|---------|
| Views | 6 | `vw_AvailableDrivers`, `vw_DeliveryTracking` |
| Functions | 9 | 3 per schema — see Documentation |
| Stored Procedures | 8 | `usp_FinalizeFoodOrder`, `usp_AssignNearestDriver` |
| Triggers | 8 | `trg_FoodOrders_OnConfirmed`, `trg_Wallets_BalanceAudit` |

See [docs/Documentation.md](docs/Documentation.md) for full reference.

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, demo-ready code |
| `feature-schema1` | SnapFood schema development |
| `feature-schema2` | SnapTaxi + SnapFinance + cross-schema integration |

### Suggested workflow

```bash
git checkout -b feature-schema1
# ... develop SnapFood tables, procedures, triggers
git push -u origin feature-schema1
# Open PR → merge to main

git checkout -b feature-schema2
# ... develop SnapTaxi, wallets, driver allocation
git push -u origin feature-schema2
# Open PR → merge to main
```

---

## Demo Scenarios (04_Test_Execution.sql)

1. Discount code validation (valid, expired, below minimum)
2. Dynamic delivery fee and ride fare calculation
3. Available drivers view
4. Full food order → payment → driver assignment
5. Delivery completion → driver payment
6. Order cancellation with refund
7. Standalone taxi ride
8. Audit log verification
9. Business intelligence views
10. Customer transaction history
11. Data export (bonus)
12. Role permissions (bonus)

---

## Team

| Member | Contribution |
|--------|-------------|
| Member A | SnapFood schema, order procedures, discount validation |
| Member B | SnapTaxi schema, driver allocation, SnapFinance wallets |

---

## License

MIT License — see [LICENSE](LICENSE) for details.
