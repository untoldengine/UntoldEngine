---
layout: page
title: Onboarding
permalink: /onboarding/
nav_order: 4
---

#  Choose your starting path

I’ve designed three different ways for you to get started with the Untold Engine. Whether you just want to explore or are ready to make your own game, we’ve got you covered. Before you begin, make sure to [follow the installation guide]({% link installation.markdown %}).


## Demo Game – Jump Right In

Want to see what the Untold Engine can do without any setup? The Demo Game is for you! It's a simple, ready-to-run game where the player dribbles a soccer ball. Perfect for getting a feel for the engine with no extra steps.

- What’s Included:
    - A fully functional dribbling game.
    - Preloaded assets like a soccer stadium, a player, and a ball.

- How to Run: 
    - Select the **DemoGame** Scheme. Set "My Mac" as the target device and hit play
    - Click "p" to toggle between game mode and edit mode
    - Use "WASD" keys to move the player around

Take a look at the GameScene class in main.swift (inside Sources/DemoGame) to see how the game is set up and get a feel for the Untold Engine API.

![DemoGame](../images/choosedemogame.gif)


## Starter Game – Experiment and Learn

If you want to tinker and get hands-on, the Starter Game is perfect. It’s a basic setup with everything you need to start building your own game. Think of it as a sandbox for your creativity!

- What’s Included:
    - A blank canvas with just enough structure to get you going.
    
- How to Run: 
    - Select the **StarterGame** Scheme. Set "My Mac" as the target device and hit play
    - Click "p" to toggle between game mode and edit mode.
    
    
Take a look at the GameScene class in main.swift (inside Sources/StarterGame) and start adding your own ideas—models, animations, or gameplay logic. The sky’s the limit!

![StarterGame](../images/choosestartergame.gif)

## Xcode Template Game – Build Your Masterpiece

Ready to make a full-fledged game? The Xcode Template Game has everything you need to build your own standalone macOS game. It’s great for diving deep and creating something awesome.

What’s Included:
    - A fully set-up Xcode project that’s ready to roll.
    - Easy integration with your own assets or code.

How to Start: Check out the step-by-step guide in [Create a Mac OS Game](CreateMacOSGame.md), and you’ll be on your way in no time.

---

### Preloaded Goodies to Get You Going

To make life easier, the Untold Engine comes packed with preloaded assets you can use right away:

- Models: A soccer stadium, player, ball, and more.
- Animations: Prebuilt running, idle, and other animations.

You’ll find these in the Resources folder of the engine under Models and Animations. No need to hunt for assets—just focus on learning and having fun!

Example:
Want to load the stadium model into your game? It’s as simple as:


```swift
setEntityMesh(entityId: stadium, filename: "soccerStadium", withExtension: "usdc")
```
