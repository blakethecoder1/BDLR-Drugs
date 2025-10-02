# 🌿 BLDR-Drugs v2.6 - Advanced Drug Dealing System
**Next-Generation Drug Dealing for QBCore FiveM Servers**

![FiveM](https://img.shields.io/badge/FiveM-QBCore-green)
![License](https://img.shields.io/badge/License-MIT-blue)
![Version](https://img.shields.io/badge/Version-2.6-brightgreen)
![Status](https://img.shields.io/badge/Status-Production%20Ready-success)

---

## 🚀 **What Makes This Amazing**

### 🎯 **Dual Interaction System**
- **Traditional NPC Approach**: Walk up to randomly spawning NPCs for classic drug dealing
- **Third-Eye Universal Selling**: Use qb-target/ox_target to sell to ANY player, NPC, or object anywhere
- **Smart Detection**: System automatically switches between interaction methods
- **Zone Protection**: Blacklisted areas prevent selling in inappropriate locations
- **Flexible Configuration**: Enable/disable either system based on server preferences

### 🚫 **Smart NPC Filtering System** (NEW in v2.6)
- **Anti-Shop Protection**: Prevents selling to shop keepers, gas station workers, and other inappropriate NPCs
- **Blacklist System**: Pre-configured list of NPCs that won't buy drugs (24/7 stores, Ammunation, etc.)
- **Distance Filtering**: 50-meter safe zone around shops and legitimate businesses
- **Vehicle Protection**: Blocks selling to NPCs sitting in cars
- **Mission NPC Protection**: Safeguards story-important characters
- **Admin Tools**: `/checknpc` command to identify and add NPCs to blacklist

### � **Enhanced NPC Interactions**
- **Smart Looking System**: NPCs stop and face you when selling
- **Conversation Animations**: NPCs switch to talking stance during deals
- **Post-Sale Reactions**: 
  - **Successful Sale**: NPC waves goodbye and walks away
  - **Failed Sale**: NPC shrugs in disappointment
- **Third-Eye Integration**: Any NPC automatically faces you when targeted
- **Realistic Timing**: 2-second interaction windows for natural conversation flow

### 💰 **Advanced Money & Reward System**
- **Markedbills Support**: 80% chance to receive marked bills instead of direct money
- **Multiple Money Types**: Cash, Bank, Black Money (ESX), Crypto Currency
- **Configurable Rewards**: Full control over reward types and chances
- **Enhanced Notifications**: Detailed rewards showing exactly what you received
- **ESX Compatibility**: Automatic detection and support for ESX black money

### �🎮 **Dynamic NPC System**
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
| Level | Title | XP Required | Money Multiplier |
|-------|-------|-------------|------------------|
| **0** | Street Rookie | 0 XP | 1.0x |
| **1** | Corner Dealer | 100 XP | 1.05x |
| **2** | Block Runner | 300 XP | 1.12x |
| **3** | Neighborhood Pusher | 700 XP | 1.2x |
| **4** | District Supplier | 1,500 XP | 1.35x |
| **5** | City Kingpin | 3,000 XP | 1.5x |
| **6** | Regional Boss | 6,000 XP | 1.75x |
| **7** | Drug Lord | 12,000 XP | 2.0x |

### 🎨 **Enhanced UI Experience**
- **Semi-transparent interface** - see the world behind while dealing
- **Cyberpunk styling** with glowing effects and animations
- **Real-time XP tracking** with animated progress bars
- **Smart item selection** with descriptions and requirements
- **Responsive Design** - works perfectly on all screen resolutions

---

## ⚙️ **Configuration**

### 💰 **Money & Rewards Configuration**
```lua
Config.Money = {
  type = 'cash',           -- 'cash', 'bank', 'crypto', 'black_money'
  useMarkedBills = true,   -- Give markedbills instead of direct money
  markedBillsChance = 0.8, -- 80% chance to get markedbills, 20% cash
  markedBillsItem = 'markedbills', -- Item name for marked bills
}
```

### 🐛 **Debug System**
```lua
Config.Debug = {
  enabled = false,         -- Master debug toggle - set to false to disable ALL debug output
  showNPCs = true,        -- Show NPC debug info
  showSales = true,       -- Show sale transactions
  showSpawning = true,    -- Show NPC spawning/despawning
  showInteractions = true,-- Show player-NPC interactions
  showPolice = true,      -- Show police detection
  showXP = true,          -- Show XP calculations
  drawMarkers = true,     -- Draw 3D markers for NPCs
  printToConsole = true,  -- Print debug to server console
  printToChat = false     -- Print debug to player chat
}
```

### 🎯 **Third-Eye Integration**
```lua
Config.ThirdEye = {
  enabled = true,          -- Enable third-eye interactions
  useQBTarget = true,      -- Use qb-target (false for ox_target)
  sellAnywhere = true,     -- Allow selling to any ped anywhere
  targetDistance = 3.0,    -- Interaction distance
  targetIcon = 'fas fa-cannabis', -- Target icon
  targetLabel = 'Sell Drugs',     -- Target label
  
  targets = {
    peds = true,           -- Target NPCs/players
    vehicles = false,      -- Target vehicles
    objects = false,       -- Target objects
    players = true         -- Target other players
  }
}
```

### 🚫 **NPC Filtering Configuration** (NEW in v2.6)
```lua
Config.NPCs = {
  -- NPC Filtering System
  filteringEnabled = true,  -- Enable NPC filtering (recommended)
  filterMode = 'blacklist', -- 'blacklist' = block specific NPCs, 'whitelist' = only allow specific NPCs
  
  -- Blacklist: NPCs you CANNOT sell to
  blacklistedModels = {
    'mp_m_shopkeep_01',     -- Shop keepers
    's_m_m_shopkeeper_01',  -- Store NPCs
    'ig_manuel',            -- Gas station workers
    'cs_hunter',            -- Ammunation clerks
    'cs_carbuyer',          -- Car dealers
    -- Add more as needed
  },
  
  -- Additional filtering options
  blockVehicleNPCs = true,        -- Don't allow selling to NPCs in vehicles
  blockMissionNPCs = true,        -- Don't allow selling to mission-critical NPCs
  minDistanceFromShops = 50.0,    -- Minimum distance from shops/stores to sell (0.0 to disable)
}
```

---

## 🎮 **Admin Commands**

### 💊 **XP Management**
```bash
/adddrugxp [player_id] [xp_amount]    # Give XP to player
/checkdrugstats [player_id]           # Check player's drug stats
```

### 🚫 **NPC Filtering Tools** (NEW)
```bash
/checknpc                             # Identify nearby NPC models for blacklist
```

### 🐛 **Debug Controls**
```bash
/drugdebug                            # Toggle debug mode on/off
```

### 🎯 **Testing Commands**
```bash
/bldr_test_nui                        # Test NUI interface
```

---

## 📊 **Enhanced Notifications**

The system now provides detailed feedback for all transactions:

### ✅ **Success Notifications**
- `"Deal completed successfully! | Received $500 in marked bills 💰 | +15 XP 📈"`
- `"Deal completed successfully! | Received $300 cash 💵 | +12 XP 📈"`
- `"Deal completed successfully! | Received $800 dirty money 🖤 | +20 XP 📈"`

### ❌ **Error Handling**
- Proper error messages for all failure cases
- Clear indication of why transactions fail
- Helpful hints for resolving issues

---

## 🛠️ **Installation**

### 1. **Download & Extract**
```bash
# Extract to your resources folder
resources/[standalone]/bldr-drugs/
```

### 2. **Database Setup**
```sql
-- Run the migration.sql file
-- Creates bldr_drugs and bldr_drugs_logs tables
```

### 3. **Dependencies**
```bash
# Required
qb-core
oxmysql (or mysql-async)

# Optional (for third-eye)
qb-target OR ox_target
```

### 4. **Server Configuration**
```lua
-- Add to server.cfg
ensure bldr-drugs

-- Add items to qb-core/shared/items.lua
['weed'] = {['name'] = 'weed', ['label'] = 'Weed', ['weight'] = 100, ['type'] = 'item', ['image'] = 'weed.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Some good quality weed.'},
['ecstasy'] = {['name'] = 'ecstasy', ['label'] = 'Ecstasy', ['weight'] = 50, ['type'] = 'item', ['image'] = 'ecstasy.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Party pills for the night.'},
['cocaine'] = {['name'] = 'cocaine', ['label'] = 'Cocaine', ['weight'] = 75, ['type'] = 'item', ['image'] = 'cocaine.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Pure white powder.'},
['meth'] = {['name'] = 'meth', ['label'] = 'Meth', ['weight'] = 50, ['type'] = 'item', ['image'] = 'meth.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Crystal clear danger.'},
['heroin'] = {['name'] = 'heroin', ['label'] = 'Heroin', ['weight'] = 60, ['type'] = 'item', ['image'] = 'heroin.png', ['unique'] = false, ['useable'] = true, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'The most dangerous substance.'},
['markedbills'] = {['name'] = 'markedbills', ['label'] = 'Marked Bills', ['weight'] = 10, ['type'] = 'item', ['image'] = 'markedbills.png', ['unique'] = true, ['useable'] = false, ['shouldClose'] = true, ['combinable'] = nil, ['description'] = 'Suspicious looking money.'},
```

---

## 🔧 **Troubleshooting**

### ❌ **Common Issues**

**"Processing transaction..." hangs forever**
- Fixed in v2.5 - inventory parameter issue resolved
- Restart the resource if you encounter this

**NPCs not spawning**
- Check if third-eye is enabled in config
- Ensure you're not in a blacklisted zone
- Verify NPC spawn settings in config

**Third-eye not working**
- Ensure qb-target or ox_target is installed
- Check Config.ThirdEye.useQBTarget setting
- Verify target distance settings

**Debug spam in console**
- Use `/drugdebug` command to toggle debug mode
- Set `Config.Debug.enabled = false` in config.lua

### 🐛 **Debug Information**
- Enable debug mode to see detailed transaction logs
- Check server console for error messages
- Use `/checkdrugstats` to verify player data

---

## 🎯 **Features Comparison**

| Feature | BLDR-Drugs v2.5 | Other Scripts |
|---------|------------------|---------------|
| **NPC Interactions** | ✅ Smart looking, animations, reactions | ❌ Static NPCs |
| **Third-Eye Integration** | ✅ Universal selling to anyone/anything | ❌ Limited locations |
| **Money Types** | ✅ Cash, Bank, Black Money, Crypto, Markedbills | ❌ Cash only |
| **UI Transparency** | ✅ See-through interface | ❌ Blocking UI |
| **XP System** | ✅ 8 levels with multipliers | ❌ No progression |
| **Debug Controls** | ✅ In-game toggle, detailed logging | ❌ Limited debugging |
| **Error Handling** | ✅ Comprehensive error system | ❌ Basic errors |
| **Notifications** | ✅ Detailed reward information | ❌ Basic messages |

---

## 🤝 **Support & Updates**

### 📧 **Getting Help**
- Check the troubleshooting section first
- Review the configuration options
- Test with debug mode enabled

### 🔄 **Version History**
- **v2.5**: Enhanced NPC interactions, markedbills system, money types, debug controls
- **v2.1**: Third-eye integration, UI improvements, zone protection
- **v2.0**: Dynamic NPC system, XP progression, advanced UI
- **v1.0**: Basic drug dealing functionality

---

## 📜 **License**

This project is licensed under the MIT License - feel free to modify and distribute.

**Happy Dealing! 🌿💰**
- **Price estimation** with risk assessment
- **ESC key support** for quick closing
- **Improved error handling** with retry mechanisms

### 🛡️ **Advanced Security & Realism**
- **Police proximity detection** - more cops = lower success rates
- **Token-based transactions** prevent exploits and replays
- **Rate limiting** with configurable cooldowns
- **Comprehensive logging** for admin oversight
- **Dynamic pricing** with market variations
- **Auto-database migration** ensures proper table structure

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

### **2. Database Setup (Automatic!)**
The resource now handles database setup automatically! No manual SQL execution required.

**Option 1 (Recommended): Automatic Setup**
- Simply restart the resource: `restart bldr-drugs`  
- Tables will be created/updated automatically
- Missing columns will be added to existing tables

**Option 2: Manual Setup (if needed)**
If automatic setup fails, run the migration manually:
```sql
SOURCE path/to/bldr-drugs/sql/migration.sql;
-- OR use the column addition script:
SOURCE path/to/bldr-drugs/sql/add_missing_columns.sql;
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
}
```

### **Third-Eye Configuration**
Complete control over the universal selling system:
```lua
Config.ThirdEye = {
  enabled = false,                   -- Enable third-eye selling (disabled by default)
  useQBTarget = true,               -- true for qb-target, false for ox_target
  targetIcon = 'fa-solid fa-cannabis', -- Target interaction icon
  targetLabel = 'Sell Drugs',      -- Target interaction label
  targetDistance = 2.5,             -- Interaction range
  
  -- Target Types
  targets = {
    peds = true,                    -- Target NPCs
    vehicles = false,               -- Target vehicles
    objects = false,                -- Target objects (be careful!)
  },
  
  -- Blacklisted Areas (no selling zones)
  blacklistedZones = {
    -- Add zones where selling should be prohibited
    -- Example: { coords = vector3(441.8, -982.0, 30.68), radius = 50.0, name = "LSPD" }
  },
  
  -- Object models that can be targeted (if objects enabled)
  targetModels = {
    -- Add prop hashes here if you want specific objects to be sellable
  }
}
```

### **Database Auto-Migration**
The system now automatically creates and updates database tables:
```lua
-- No manual SQL execution needed!
-- The resource automatically:
-- 1. Creates tables if they don't exist  
-- 2. Adds missing columns to existing tables
-- 3. Ensures proper indexing for performance
```
  description = 'Pure Colombian powder'
}
```

---

## 🎮 **How to Play**

### **For Players**

#### **Traditional NPC Method**
1. **Find NPCs**: Walk around the city to find drug buyers (green markers if debug enabled)
2. **Approach**: Get close to an NPC and press `[E]` to approach
3. **Request Session**: System will create a secure trading session

#### **Third-Eye Universal Method** 🎯
1. **Aim and Target**: Look at any NPC, player, or allowed object
2. **Open Third-Eye**: Use your targeting system (default: Alt)
3. **Select "Sell Drugs"**: Choose the drug dealing option from the menu
4. **Trade Interface**: Same interface opens for seamless dealing
5. **Sell Anywhere**: No need to find specific NPCs - sell to anyone!

#### **Universal Steps (Both Methods)**
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

## 🆕 **Recent Updates & Fixes**

### **v2.1 - Enhanced Stability & UX**
- ✅ **Fixed script errors** - Resolved ThirdEye config issues causing crashes
- ✅ **Auto-database migration** - Automatic table creation and column updates
- ✅ **Enhanced UI transparency** - See the world behind the interface
- ✅ **ESC key support** - Press ESC to quickly close the UI
- ✅ **Improved error handling** - Better JSON parsing and retry mechanisms
- ✅ **Fixed duplicate callbacks** - Resolved 404 errors in UI requests
- ✅ **Player stats initialization** - Proper XP loading on resource start
- ✅ **Better debugging output** - Enhanced troubleshooting information

### **v2.0 - Complete Overhaul**
- ✅ Dynamic NPC system with intelligent AI
- ✅ 5-tier drug progression system
- ✅ Cyberpunk-style UI with animations
- ✅ Enhanced security and anti-exploit measures
- ✅ Comprehensive admin tools and statistics
- ✅ Advanced debug system with multiple categories
- ✅ Performance optimizations for large servers

---

## 🛠️ **Troubleshooting**

### **Fixed Issues**
- ❌ ~~"attempt to index a nil value (field 'ThirdEye')"~~ ✅ **FIXED**
- ❌ ~~"Unknown column 'total_sales' in field list"~~ ✅ **FIXED**  
- ❌ ~~"Failed to get available items: HTTP 404"~~ ✅ **FIXED**
- ❌ ~~UI transparency issues~~ ✅ **FIXED**
- ❌ ~~Cancel button not working~~ ✅ **FIXED**

### **Common Issues & Solutions**
1. **NPCs not spawning**: Enable debug mode with `/drugdebug` and check console
2. **Database errors**: Resource now auto-creates tables and columns
3. **UI not opening**: Verify dependencies are loaded and restart resource  
4. **Items not being removed**: Check QBCore item names match config exactly

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

## � **Changelog & Roadmap**

### **🔥 Latest Updates (v2.1.0 - Current)**
**Released: September 2025**

#### **✅ Implemented Features:**
- **💰 Advanced Money System**
  - Markedbills support (80% chance by default)
  - Multiple money types: Cash, Bank, Black Money, Crypto
  - Configurable reward probabilities
  - Enhanced notifications with reward details

- **🎭 Enhanced NPC Interactions**
  - NPCs stop and face player during transactions  
  - Realistic conversation animations and gestures
  - Post-sale reactions (wave goodbye, shrug on failure)
  - Third-eye integration with automatic NPC facing

- **🚫 NPC Cooldown System**
  - 5-minute cooldown per NPC after successful sale
  - Visual markers (red for cooldown, green for available)
  - Real-time countdown timers
  - Smart blocking of repeat interactions

- **🐛 Debug System Overhaul**
  - Master debug toggle (disabled by default)
  - In-game `/drugdebug` command for admins
  - Categorized debug output for better troubleshooting
  - Cleaner console output in production

- **🔧 Technical Improvements**
  - Fixed inventory integration errors
  - Automatic database schema management
  - ESX compatibility for black money
  - Enhanced error handling and logging

---

### **🚀 Coming Soon (v2.2.0 - Next Update)**
**Expected: October 2025**

#### **🔮 Planned Features:**
- **🏠 Territory System**
  - Gang territories with different profit multipliers
  - Territory control mechanics
  - Rival gang encounters and disputes
  - Territory expansion through successful dealing

- **📱 Burner Phone Integration**
  - Anonymous drug orders via phone
  - Text message based dealing system
  - Encrypted communication channels
  - Drop-off location coordination

- **🎭 Advanced NPC AI**
  - NPC personality types (cautious, eager, suspicious)
  - Dynamic pricing based on NPC wealth
  - NPC reputation system
  - Word-of-mouth referral system

#### **⚡ Performance Enhancements:**
- **🎯 Optimized Spawning**
  - Smart NPC population based on server load
  - Distance-based LOD for better performance
  - Memory-efficient entity management

---

### **🌟 Future Roadmap (v3.0.0+)**
**Expected: Q1 2026**

#### **🏗️ Major Systems:**
- **🏭 Drug Manufacturing**
  - Multi-step drug creation process
  - Resource gathering and processing
  - Quality control affecting prices
  - Laboratory setup and management

- **🚓 Advanced Police System**
  - Dynamic police response scaling
  - Undercover operations
  - Drug busts and evidence collection
  - Witness protection and snitching mechanics

- **🌐 Multi-Server Support**
  - Cross-server drug trading
  - Shared reputation systems
  - Global leaderboards
  - Inter-server gang conflicts

#### **📊 Analytics & Management:**
- **📈 Business Metrics Dashboard**
  - Profit/loss tracking
  - Market trend analysis
  - Customer loyalty metrics
  - Risk assessment tools

- **🎨 UI/UX Overhaul**
  - Modern React-based interface
  - Mobile-responsive design
  - Customizable themes
  - Accessibility improvements

---

### **📋 Version History**

#### **v2.0.0** *(Major Release - August 2025)*
- Complete rewrite with modern architecture
- Third-eye integration and ThirdEye support
- Leveling system with XP and multipliers
- Advanced debugging and logging systems

#### **v1.5.0** *(Feature Update - July 2025)*
- Police detection system
- Blacklisted zones for selling
- Rate limiting and cooldown systems
- Enhanced security measures

#### **v1.0.0** *(Initial Release - June 2025)*
- Basic drug selling functionality
- NPC interaction system
- Simple economy mechanics
- QBCore integration

---

### **🤝 How to Contribute**
Want to help shape the future of BDLR-Drugs? Here's how:

1. **🗳️ Vote on Features** - Join our Discord to vote on upcoming features
2. **🐛 Report Bugs** - Help us identify and fix issues
3. **💡 Suggest Ideas** - Share your creative ideas for new features  
4. **💻 Code Contributions** - Submit pull requests for improvements
5. **📚 Documentation** - Help improve guides and tutorials
6. **🎮 Beta Testing** - Test new features before public release

---

## �📜 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🌟 Made with ❤️ by Blakethepet and BLDR CHAT**

*Transform your FiveM server with the most advanced drug dealing system available!*
