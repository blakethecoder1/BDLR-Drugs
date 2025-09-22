# 🌿 BDLR-Drugs v2.0 - Advanced Drug Dealing System
**Next-Generation Drug Dealing for QBCore FiveM Servers**

![FiveM](https://img.shields.io/badge/FiveM-QBCore-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Version](https://img.shields.io/badge/Version-2.0-brightgreen)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)

---

## 🚀 **What Makes This Amazing**

### 🎮 **Dynamic NPC System**
- **15 intelligent NPCs** spawn around players automatically
- **Realistic AI behavior**: NPCs walk, smoke, and use phones
- **Interactive dealing**: Approach walking NPCs instead of static locations
- **Smart spawning**: NPCs appear in safe zones with ground detection
- **Auto-cleanup**: Old/distant NPCs despawn automatically

### 💎 **5-Tier Drug Progression System**
| Drug | Level Required | Base Price | Risk Level | XP per Unit |
|------|----------------|------------|------------|-------------|
| 🌿 **Weed** | 0 (Street Rookie) | $50 | Low | 5 XP |
| 💊 **Ecstasy** | 1 (Corner Dealer) | $80 | Low-Med | 6 XP |
| ❄️ **Cocaine** | 2 (Block Runner) | $120 | Medium | 8 XP |
| 🧪 **Meth** | 3 (Neighborhood Pusher) | $180 | High | 10 XP |
| 💉 **Heroin** | 4 (District Supplier) | $200 | Very High | 12 XP |

### 🏆 **8-Level Progression System**
- **Level 0**: Street Rookie (1.0x multiplier)
- **Level 1**: Corner Dealer (1.05x multiplier)
- **Level 2**: Block Runner (1.12x multiplier)
- **Level 3**: Neighborhood Pusher (1.2x multiplier)
- **Level 4**: District Supplier (1.35x multiplier)
- **Level 5**: City Kingpin (1.5x multiplier)
- **Level 6**: Regional Boss (1.75x multiplier)
- **Level 7**: Drug Lord (2.0x multiplier)

### 🎨 **Cyberpunk UI Experience**
- **Futuristic interface** with glowing effects and animations
- **Real-time XP tracking** with animated progress bars
- **Smart item selection** with descriptions and requirements
- **Price estimation** with risk assessment
- **Responsive feedback** for all user actions

### 🛡️ **Advanced Security & Realism**
- **Police proximity detection** - more cops = lower success rates
- **Token-based transactions** prevent exploits and replays
- **Rate limiting** with configurable cooldowns
- **Comprehensive logging** for admin oversight
- **Dynamic pricing** with market variations

---

## 📋 **Requirements**

### **Dependencies**
- [`qb-core`](https://github.com/qbcore-framework/qb-core) - QBCore Framework
- [`ox_lib`](https://github.com/overextended/ox_lib) - OX Library
- [`oxmysql`](https://github.com/overextended/oxmysql) - MySQL Resource

### **Server Requirements**
- **FiveM Server** with artifact 6000+
- **MySQL Database** (MariaDB 10.6+ recommended)
- **QBCore Framework** (latest version)

---

## 🚀 **Installation**

### **1. Download & Extract**
```bash
# Clone or download the repository
git clone https://github.com/your-repo/BDLR-Drugs-main
```

### **2. Database Setup**
Run the SQL migration to create required tables:
```sql
-- Run sql/migration.sql in your database
SOURCE path/to/BDLR-Drugs-main/sql/migration.sql;
```

### **3. Server Configuration**
Add to your `server.cfg`:
```lua
ensure bldr-drugs
```

### **4. Item Configuration**
Add drug items to your QBCore shared items:
```lua
-- In qb-core/shared/items.lua
['weed'] = {['name'] = 'weed', ['label'] = 'Weed', ['weight'] = 100, ['type'] = 'item', ['image'] = 'weed.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['description'] = 'High quality street weed'},
['cocaine'] = {['name'] = 'cocaine', ['label'] = 'Cocaine', ['weight'] = 50, ['type'] = 'item', ['image'] = 'cocaine.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['description'] = 'Pure Colombian powder'},
['heroin'] = {['name'] = 'heroin', ['label'] = 'Heroin', ['weight'] = 30, ['type'] = 'item', ['image'] = 'heroin.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['description'] = 'High grade black tar'},
['meth'] = {['name'] = 'meth', ['label'] = 'Meth', ['weight'] = 40, ['type'] = 'item', ['image'] = 'meth.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['description'] = 'Crystal blue persuasion'},
['xtc'] = {['name'] = 'xtc', ['label'] = 'Ecstasy', ['weight'] = 20, ['type'] = 'item', ['image'] = 'xtc.png', ['unique'] = false, ['useable'] = false, ['shouldClose'] = false, ['description'] = 'Party pills for the night'}
```

---

## ⚙️ **Configuration**

### **Main Settings** (`config.lua`)
```lua
-- Debug system with multiple categories
Config.Debug = {
  enabled = true,              -- Master debug toggle
  showNPCs = true,            -- NPC spawn/despawn info
  showSales = true,           -- Sale transaction details
  showPolice = true,          -- Police detection info
  drawMarkers = true,         -- Visual NPC markers
}

-- NPC Management
Config.NPCs = {
  maxActive = 15,             -- Max NPCs at once
  spawnRadius = 500.0,        -- Spawn distance from player
  despawnRadius = 600.0,      -- Despawn distance
  checkInterval = 5000,       -- Spawn check frequency (ms)
  lifetimeMin = 60000,        -- Min NPC lifetime (ms)
  lifetimeMax = 180000,       -- Max NPC lifetime (ms)
}
```

### **Item Customization**
Each drug can be fully customized:
```lua
['cocaine'] = {
  label = 'Cocaine',
  basePrice = 120,            -- Base price per unit
  priceVariation = 0.25,      -- ±25% price variation
  xpPerUnit = 8,              -- XP gained per unit
  minLevel = 2,               -- Required level
  maxAmount = 25,             -- Max amount per transaction
  successChance = 0.85,       -- Base success rate
  policePenalty = 0.08,       -- Success reduction per cop
  description = 'Pure Colombian powder'
}
```

---

## 🎮 **How to Play**

### **For Players**
1. **Find NPCs**: Walk around the city to find drug buyers (green markers if debug enabled)
2. **Approach**: Get close to an NPC and press `[E]` to approach
3. **Request Session**: System will create a secure trading session
4. **Select Items**: Choose from available drugs based on your level
5. **Set Amount**: Use +/- buttons or type amount (respects maximums)
6. **Make Deal**: Click "Make Deal" and watch the negotiation
7. **Level Up**: Gain XP and unlock higher-tier drugs

### **Progression Tips**
- Start with **Weed** to build XP safely
- Higher-tier drugs = more profit but more risk
- Police presence reduces success rates
- Level up to access better drugs and multipliers

---

## 👨‍💼 **Admin Commands**

### **Debug Commands**
```lua
/drugdebug                  -- Toggle debug mode on/off
/bldr_debug_npcs           -- Show active NPC information
```

### **Player Management**
```lua
/adddrugxp [playerid] [amount]     -- Add XP to player
/checkdrugstats [playerid]         -- View player statistics
```

### **Admin Examples**
```lua
/adddrugxp 1 500          -- Give player ID 1 500 XP
/checkdrugstats 1         -- Check stats for player ID 1
```

---

## 📊 **Database Schema**

### **Player XP Table** (`bldr_drugs`)
```sql
citizenid VARCHAR(50)     -- Player identifier
xp INT                    -- Current XP
total_sales INT           -- Total successful sales
total_earned INT          -- Total money earned
last_sale TIMESTAMP       -- Last sale timestamp
created_at TIMESTAMP      -- Account creation
updated_at TIMESTAMP      -- Last update
```

### **Transaction Logs** (`bldr_drugs_logs`)
```sql
id INT AUTO_INCREMENT     -- Unique log ID
citizenid VARCHAR(50)     -- Player identifier
item VARCHAR(100)         -- Drug sold
amount INT                -- Quantity sold
base_price INT            -- Base item price
final_price INT           -- Final transaction price
success TINYINT(1)        -- Success/failure
reason VARCHAR(250)       -- Failure reason
nearbyCops INT           -- Police count during sale
success_chance DOUBLE     -- Calculated success rate
created_at TIMESTAMP      -- Transaction time
```

---

## 🔧 **Advanced Features**

### **Security Measures**
- **Token-based transactions** prevent replay attacks
- **Rate limiting** stops spam selling
- **Server-side validation** for all transactions
- **Comprehensive logging** for audit trails

### **Performance Optimization**
- **Efficient NPC management** with distance-based cleanup
- **Optimized database queries** with proper indexing
- **Smart spawning algorithms** to prevent server lag
- **Memory management** for long-running sessions

### **Customization Options**
- **Fully configurable items** with individual properties
- **Adjustable risk/reward ratios** per drug type
- **Flexible NPC behavior settings**
- **Customizable UI themes** and colors

---

## 🛠️ **Troubleshooting**

### **Common Issues**
1. **NPCs not spawning**: Check debug mode and console for errors
2. **Database errors**: Ensure SQL migration was run properly
3. **UI not opening**: Verify all dependencies are loaded
4. **Items not being removed**: Check QBCore item names match config

### **Debug Mode**
Enable debug mode to see detailed information:
```lua
/drugdebug  -- Toggle debug on/off
```

This will show:
- NPC spawn/despawn information
- Sale transaction details
- Police detection results
- XP calculations

---

## 📈 **Performance & Scaling**

### **Optimization Features**
- **Smart NPC management** prevents server overload
- **Database indexing** for fast queries
- **Memory-efficient** state management
- **Configurable limits** to control resource usage

### **Recommended Settings**
- **Small servers** (< 50 players): Default settings
- **Medium servers** (50-100 players): Reduce `maxActive` NPCs to 10
- **Large servers** (100+ players): Reduce to 8 NPCs, increase `checkInterval`

---

## 🆕 **Changelog**

### **v2.0 - Complete Overhaul**
- ✅ Dynamic NPC system with intelligent AI
- ✅ 5-tier drug progression system
- ✅ Cyberpunk-style UI with animations
- ✅ Enhanced security and anti-exploit measures
- ✅ Comprehensive admin tools and statistics
- ✅ Advanced debug system with multiple categories
- ✅ Performance optimizations for large servers

### **v1.0 - Original Release**
- Basic drug selling system
- XP progression
- Police detection
- Simple UI

---

## 💡 **Support & Contributing**

### **Getting Help**
- 📖 Read this documentation thoroughly
- 🐛 Check the [Issues](../../issues) page for known problems
- 💬 Join our Discord for community support

### **Contributing**
We welcome contributions! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

### **Feature Requests**
Have an idea for improvement? Open an issue with the `enhancement` label!

---

## 📜 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🌟 Made with ❤️ by the BDLR Team**

*Transform your FiveM server with the most advanced drug dealing system available!*


