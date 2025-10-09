# 📁 BLDR-Drugs Image Files

This folder contains the required image files for the **evolved drug items** in the BLDR-Drugs v2.7 Evolution System.

## 📋 Required Image Files

### Evolved Drug Items (v2.7):
- `chronic_kush.png` - Premium evolved cannabis strain
- `pure_cocaine.png` - Pharmaceutical grade cocaine
- `blue_crystal.png` - Laboratory grade methamphetamine

## 🔧 Installation Instructions

Copy these image files to your inventory script's images folder:

### For qb-inventory:
```bash
Copy-Item "resources/[standalone]/bldr-drugs/images/*" "resources/[qb]/qb-inventory/html/images/"
```

### For ox_inventory:
```bash
Copy-Item "resources/[standalone]/bldr-drugs/images/*" "resources/[ox]/ox_inventory/web/images/"
```

## 📐 Image Specifications

- **Format**: PNG (recommended) or JPG
- **Size**: 64x64 pixels (standard inventory size)
- **Background**: Transparent (PNG) for best results
- **Quality**: High resolution for clarity in inventory UI

## 🎨 Image Guidelines

- Use high-quality, premium-looking representations for evolved drugs
- Maintain consistent art style with your existing drug items
- Consider enhanced visual effects (glow, crystals, premium packaging)
- Evolved drugs should look noticeably better than standard variants

## 📝 Important Notes

- **Standard drug images** (weed, cocaine, heroin, meth, xtc) should already exist in your inventory system
- This folder only contains the **new evolved drug variants** introduced in v2.7
- Evolved drugs represent premium, enhanced versions of standard drugs

---

**Note**: Place your evolved drug item images in this folder, then copy them to your inventory script's images directory as shown in the installation instructions above.