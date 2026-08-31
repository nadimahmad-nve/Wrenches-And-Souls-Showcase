# Wrenches & Souls - Generator Repair Architecture

This module manages the core generator repair mechanics in *Wrenches & Souls* using a secure client-server architecture consisting of a server script (`RepairHandler`) and a local client script (`RepairClient`)

## Server Architecture: `RepairHandler`
The `RepairHandler` acts as the server-authoritative manager for all repair requests to ensure the process remains robust and secure against exploits.

* **State Tracking:** Maintains a dictionary of active repairers to track exactly which player is working on which generator at any given time.
* **Security Validation:** Before initiating a repair loop, the server confirms that the player's `RoundStatus` is "Alive", that they are not already flagged as repairing, and that the generator is not already fixed.
* **Positional Polling:** Continuously verifies the player's position during the 58-second repair process by using `workspace:GetPartsInPart` to ensure they are physically inside the required repair slot.
* **Visual & Audio Syncing:** Dynamically updates the player's progress bar GUI every 0.1 seconds and manages the playback of the generator's repair sound based on player presence.
* **Failure Handling:** When a QTE is failed, the server temporarily flags the generator with an `IsOverloaded` attribute for 3 seconds.
* **Global Alerts:** Distributes a visual ping via the `ExterminatorPingEvent` and plays a localised 2D sound for Exterminators, Mechanics, and Spectators when a generator overloads.

## Client Architecture: `RepairClient`
The `RepairClient` handles local user input, animation states, and the Quick Time Event (QTE) interface, acting as the bridge between the player and the `RepairHandler`.

* **Spatial Queries:** Uses `OverlapParams` to cast a hitbox around the player's `HumanoidRootPart` to detect and assign the closest unoccupied repair slot.
* **Animation Management:** Preloads custom intro and looping animations, automatically aligning the character's `CFrame` to the generator slot before playing them.
* **Continuous Monitoring:** Uses `RunService.Heartbeat` to constantly check the player's `MoveDirection` and `MovementState`, automatically cancelling the repair action if the player attempts to walk away or is forced into a crouched or stunned state.
* **Dynamic QTEs:** Spawns a radial QTE interface at randomised intervals (calculated based on current repair progress), requiring the player to stop a spinning needle within a randomly generated 45-degree success zone.
* **Session Tracking (Zombie Thread Prevention):** Implements a `repairSessionID` integer that increments every time a new repair action starts. 
* **Thread Safety:** The background QTE loop constantly verifies that its local `mySession` variable matches the global `repairSessionID`, which successfully prevents orphaned "zombie threads" from initiating QTE popups if the player previously cancelled the interaction.
* **Edge-Case Handling:** Silently ignores QTE failures or timeouts if the generator reaches 100% completion right as the skillcheck appears.