# Wrenches & Souls - Game Loop Architecture

These are a few modules that manage the state of the game. 

## Includes:
* **GameLoop.luau** The script governing the overall game loop. Each task is delegated to a specific module.
* **RoleManager.luau** The script calculating and assigning roles for each of the player. Deals with the cleanup as well. 
* **RoundManager.luau** Provides the countdown and timer for when the round starts, and continuously checks for game-ending scenarios, and cleanly deals with the post-game.     