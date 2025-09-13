# 🌿 BDLR-Drugs  
AI-built drug selling system for **QBCore** (FiveM)

![FiveM](https://img.shields.io/badge/FiveM-QBCore-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Build-Stable-brightgreen)

---

## 🚀 Latest Update – Stage A: Stability, Security & Persistence

### ✨ What’s New (User-Facing)
- **👮 Police proximity detection** – deals are riskier when cops are nearby (success chance lowered).
- **💾 Reliable XP saving** – XP is saved immediately and autosaved regularly.
- **🔐 Secure selling** – trades use **single-use, short-lived server tokens** to prevent replay/spoof attacks.
- **⏱️ Rate limiting** – configurable cooldowns and per-minute sell caps to stop spam selling.
- **📝 Sale auditing** – every sale attempt (success/fail) is logged for admin review.

### 💡 Why It Matters
- More realistic and fair gameplay where **police presence matters**.
- **Far less XP loss** with stronger persistence.
- **Harder to exploit** the selling flow, improving server stability and simplifying admin oversight.

### 🛠️ Admin & Developer Notes
- **Database Changes** – run the migration to create **two tables**:
  ```sql
  -- Player XP
  bldr_drugs
  -- Sale audit logs
  bldr_drugs_logs
````

File: `sql/migration.sql`

* **Requirements**
  Ensure these resources are installed and configured:

  * [`qb-core`](https://github.com/qbcore-framework/qb-core)
  * [`ox_lib`](https://github.com/overextended/ox_lib)
  * [`oxmysql`](https://github.com/overextended/oxmysql)

* **Configurable Values** (`config.lua`)

  * `policeRadius`
  * `autosaveInterval`
  * `sellCooldown`
  * `maxSellsPerMinute`
  * `tokenExpiry`

### ✅ Quick Test Checklist

* [ ] Confirm XP loads on join and increases after sales.
* [ ] Perform a sale → confirm item removal, money payout, and XP save.
* [ ] Attempt rapid selling → ensure cooldowns/rate limits trigger.
* [ ] Test with a nearby police player → success chance drops and `nearbyCops` logs.
* [ ] Check `bldr_drugs_logs` → sale attempts (success/failure) are recorded with reason and coordinates.

---

## 📦 Installation & Setup

### 1️⃣ Place Resource

Move the `bldr-drugs` resource folder into your server’s `resources` directory.

### 2️⃣ Dependencies

Ensure these are installed **and started before** `bldr-drugs`:

* [`qb-core`](https://github.com/qbcore-framework/qb-core)
* [`ox_lib`](https://github.com/overextended/ox_lib)
* [`oxmysql`](https://github.com/overextended/oxmysql)

### 3️⃣ Server.cfg Order

Add the following to your `server.cfg` **in order**:

```cfg
start qb-core
start ox_lib
start oxmysql
start bldr-drugs
```

### 4️⃣ Start the Resource

Restart your server or start manually:

```
refresh
start bldr-drugs
```

---

## 🗄️ Database Setup

Create the required XP table **once** using `oxmysql`:

```sql
CREATE TABLE IF NOT EXISTS bldr_drugs (
    citizenid VARCHAR(50) NOT NULL PRIMARY KEY,
    xp INT NOT NULL DEFAULT 0
);
```

---

## ⚙️ Features & Admin Commands

* **Admin Command**

  ```
  /adddrugxp <id> <xp>
  ```

  Requires an admin ACE group per QBCore’s command permissions.

* **AI-Driven System**

  * Updated **daily** with new improvements and fixes.
  * Report any bugs or issues to BLDR for rapid updates.

---

## 🧩 Runtime Notes & Tips

| Feature             | Details                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| **Persistence**     | XP loads on join/resource start and saves on disconnect. Optional autosave intervals can be added. |
| **Police Counting** | Now supports distance-based proximity checks for realism.                                          |
| **Buyer NPCs**      | Logic ready for ped spawns, animations, and immersive buyer interactions.                          |
| **UI / NUI**        | Functional NUI using resource messages. Optional live price previews and animated UI available.    |
| **Security**        | Server-side item validation and removal before payout. Optional rate-limiting & logging.           |

---

## 🖥️ NUI (Interface)

* Uses the **resource message system** to:

  * Open/close the selling interface
  * Post sell data to the client script
* Optional upgrades:

  * Live multiplier/price previews
  * Lottie/CSS animations, icons, and sound FX

---

## 🔐 Security

* Items are validated **server-side** and removed before giving money.
* Optional add-ons:

  * Rate limiting
  * Abuse protection
  * Transaction logging

---

## ✅ Quick Checklist

* [x] Place `bldr-drugs` in `resources/`
* [x] Add dependencies to `server.cfg`
* [x] Run SQL to create XP table
* [x] Start or restart the resource

---

## 🆕 Changelog

* **2025-09-11** – Stage A update: Stability, Security & Persistence (see details above)
* *(Add further updates here)*

---

## 💡 Support

This script receives **daily updates**.
For issues, feature requests, or contributions:

* Open a [GitHub Issue](../../issues)
* Or contact ME directly




