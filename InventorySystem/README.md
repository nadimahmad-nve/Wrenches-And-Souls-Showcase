# Wrenches & Souls - Shop Architecture

These are the scripts that manage the inventory system. 

## Includes:
* **InventoryPopulator.luau** Populates the shop with UI assets representing the player's inventory, and connects functions to buttons so the player can seamlessly equip and unequip.  
* **InventoryManager.luau** Server-side script that handles: the adding of items to inventory; the buying of items; the equipping of items, and is fundamental in grabbing the players inventory from the DataStore when they first join. 
