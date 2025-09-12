# 🌿 BDLR-Drugs  
AI-built drug selling system for **QBCore** (FiveM)

![FiveM](https://img.shields.io/badge/FiveM-QBCore-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Status](https://img.shields.io/badge/Build-Stable-brightgreen)

Wanna Build you own? 
https://discord.gg/bldr
---

## 📦 Installation & Setup

### 1️⃣ Place Resource
Move the `bldr-drugs` resource folder into your server’s `resources` directory.

### 2️⃣ Dependencies
Ensure these are installed **and started before** `bldr-drugs`:
- [`qb-core`](https://github.com/qbcore-framework/qb-core)
- [`ox_lib`](https://github.com/overextended/ox_lib)
- [`oxmysql`](https://github.com/overextended/oxmysql)

### 3️⃣ Server.cfg Order
Add the following to your `server.cfg` **in order**:
```cfg
start qb-core
start ox_lib
start oxmysql
start bldr-drugs


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
  * Report any bugs or issues to Here for rapid updates.

---

## 🧩 Runtime Notes & Tips

| Feature             | Details                                                                                            |
| ------------------- | -------------------------------------------------------------------------------------------------- |
| **Persistence**     | XP loads on join/resource start and saves on disconnect. Optional autosave intervals can be added. |
| **Police Counting** | Uses job presence for detection. Optional distance-based checks can be implemented.                |
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

## 💡 Support

This script receives **daily updates**.
For issues, feature requests, or contributions:

* Open a [GitHub Issue](../../issues)
* Or contact ME directly

---
