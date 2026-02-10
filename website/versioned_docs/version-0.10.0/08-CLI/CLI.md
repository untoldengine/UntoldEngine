# UntoldEngine CLI Tool

> **Note:** The CLI tool source code is located in the `Tools/UntoldEngineCLI/` directory of the repository.
> 
> For the most up-to-date documentation, see `Tools/UntoldEngineCLI/README.md` in the repository.

The `untoldengine-create` command-line tool allows you to create and manage UntoldEngine game projects without launching the UntoldEditor.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/untoldengine/UntoldEngine.git
cd UntoldEngine

# Install the CLI globally
./scripts/install-create.sh

# Create a project from anywhere
cd ~/anywhere
mkdir MyGame && cd MyGame
untoldengine-create create MyGame
```

## Complete Documentation

For complete CLI documentation including:

- Installation instructions
- Command reference
- Platform options
- Usage examples
- Troubleshooting

Please refer to `Tools/UntoldEngineCLI/README.md` in the repository.

## Quick Start

Create a new game project in three simple steps:

```bash
# 1. Create and enter your project directory
mkdir MyGame && cd MyGame

# 2. Create the project (default: macOS)
untoldengine-create create MyGame

# 3. Open in Xcode
open MyGame/MyGame.xcodeproj
```

All project files and assets will be created in the current directory.

## Commands

### create

Creates a new UntoldEngine game project with the specified platform configuration.

**Usage:**
```bash
untoldengine-create create <project-name> [--platform <platform>]
```

**Arguments:**
- `<project-name>`: Name of your game project (required)

**Options:**
- `--platform <platform>`: Target platform (default: `macos`)
  - `macos` - macOS desktop application
  - `ios` - iOS application
  - `iosar` - iOS with ARKit support
  - `visionos` - visionOS (Apple Vision Pro)

**Examples:**

Create a macOS game:
```bash
mkdir SpaceShooter && cd SpaceShooter
untoldengine-create create SpaceShooter
```

Create an iOS game:
```bash
mkdir MobileRPG && cd MobileRPG
untoldengine-create create MobileRPG --platform ios
```

Create an AR game for iOS:
```bash
mkdir ARAdventure && cd ARAdventure
untoldengine-create create ARAdventure --platform iosar
```

Create a visionOS game:
```bash
mkdir VisionGame && cd VisionGame
untoldengine-create create VisionGame --platform visionos
```

**What it does:**

1. Creates the complete project structure in the current directory
2. Generates an Xcode project using XcodeGen
3. Sets up the game asset directories at `<project-name>/Sources/<project-name>/GameData/`
4. Configures the UntoldEngine to load assets from the GameData directory
5. Creates platform-specific configuration files

### update

Updates the game data directory structure for an existing project.

**Usage:**
```bash
untoldengine-create update <project-name>
```

**Arguments:**
- `<project-name>`: Name of the existing project (required)

**What it does:**

Re-creates the GameData folder structure at `<project-name>/Sources/<project-name>/GameData/` with all standard asset directories:
- Models/
- Scenes/
- Scripts/
- Animations/
- Gaussians/
- Shaders/
- Textures/

**Example:**

```bash
cd MyGame
untoldengine-create update MyGame
```

**When to use:**
- After accidentally deleting asset folders
- When you need to reset the folder structure
- To ensure all standard directories exist

## Platform Options

### macOS
**Command:** `--platform macos` (default)

**Features:**
- Full desktop application
- Window management
- Keyboard and mouse input
- High performance rendering

**Use for:**
- Desktop games
- Development and testing
- Maximum performance applications

### iOS
**Command:** `--platform ios`

**Features:**
- iPhone and iPad support
- Touch input
- Accelerometer support
- App Store distribution

**Use for:**
- Mobile games
- Touch-based experiences
- Wide distribution via App Store

### iOS AR (ARKit)
**Command:** `--platform iosar`

**Features:**
- All iOS features
- ARKit integration
- World tracking
- Plane detection
- Face tracking

**Use for:**
- Augmented reality games
- AR experiences
- Real-world interactive applications

### visionOS
**Command:** `--platform visionos`

**Features:**
- Apple Vision Pro support
- Spatial computing
- 3D UI elements
- Hand tracking
- Eye tracking

**Use for:**
- Immersive 3D experiences
- Spatial applications
- Next-generation mixed reality

## Project Structure

After running `untoldengine-create create MyGame`, your project structure will look like:

```
MyGame/                                    # Your working directory
└── MyGame/                                # Generated project
    ├── MyGame.xcodeproj                   # Xcode project (generated)
    ├── project.yml                        # XcodeGen configuration
    ├── README.md                          # Project documentation
    └── Sources/
        └── MyGame/
            ├── GameData/                  # Game assets location
            │   ├── Models/                # 3D models (.usdz, etc.)
            │   ├── Scenes/                # Scene files
            │   ├── Scripts/               # Game logic scripts
            │   ├── Animations/            # Animation data
            │   ├── Gaussians/             # Gaussian splatting data
            │   ├── Shaders/               # Custom shaders
            │   └── Textures/              # Image files
            ├── AppDelegate.swift          # Application entry point
            ├── GameViewController.swift   # Main game controller
            └── Info.plist                 # App configuration
```

### Important Directories

**GameData/**: The single location for all game assets
- Path: `MyGame/Sources/MyGame/GameData/`
- The UntoldEngine is configured to load all assets from this location
- Copy your game assets (models, textures, etc.) here
- Subdirectories are organized by asset type

**Sources/**: Swift source code
- Contains your game's Swift files
- Platform-specific delegates and controllers
- Can add additional Swift files here

### Adding Assets

To add assets to your game, copy them into the appropriate GameData subdirectory:

```bash
# Add a 3D model
cp ~/Downloads/spaceship.usdz MyGame/Sources/MyGame/GameData/Models/

# Add textures
cp ~/Downloads/texture_*.png MyGame/Sources/MyGame/GameData/Textures/

# Add a scene
cp ~/Downloads/level1.json MyGame/Sources/MyGame/GameData/Scenes/
```

The engine will automatically find assets in these locations.

## Workflow Examples

### Typical Development Workflow

```bash
# 1. Create project directory
mkdir MyAwesomeGame
cd MyAwesomeGame

# 2. Create the game project
untoldengine-create create MyAwesomeGame --platform ios

# 3. Add your game assets
cp -r ~/GameAssets/Models/* MyAwesomeGame/Sources/MyAwesomeGame/GameData/Models/
cp -r ~/GameAssets/Textures/* MyAwesomeGame/Sources/MyAwesomeGame/GameData/Textures/

# 4. Open in Xcode and start developing
open MyAwesomeGame/MyAwesomeGame.xcodeproj
```

### Starting from Scratch

```bash
# Create a new game from scratch
mkdir PuzzleGame && cd PuzzleGame
untoldengine-create create PuzzleGame --platform macos

# The GameData directory is ready for your assets
ls -la PuzzleGame/Sources/PuzzleGame/GameData/
# Models/ Scenes/ Scripts/ Animations/ Gaussians/ Shaders/ Textures/
```

### Multi-Platform Development

You might want to test the same game on different platforms:

```bash
# Create macOS version for development
mkdir MyGame-macOS && cd MyGame-macOS
untoldengine-create create MyGame --platform macos

# Create iOS version in a separate directory
cd ..
mkdir MyGame-iOS && cd MyGame-iOS
untoldengine-create create MyGame --platform ios

# Copy assets between projects
cp -r ../MyGame-macOS/MyGame/Sources/MyGame/GameData/* \
      MyGame/Sources/MyGame/GameData/
```

### Resetting Asset Structure

If you accidentally delete asset folders or need to reset:

```bash
cd MyGame
untoldengine-create update MyGame
# GameData structure is recreated
```

## Troubleshooting

### Command Not Found

**Problem:** `untoldengine-create: command not found`

**Solution:**
1. Ensure you ran the installation script:
   ```bash
   cd /path/to/UntoldEngine
   ./Scripts/install-create.sh
   ```

2. Check if the tool exists:
   ```bash
   ls -l /usr/local/bin/untoldengine-create
   ```

3. If it exists but still not found, add `/usr/local/bin` to your PATH:
   ```bash
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

### XcodeGen Failed

**Problem:** Error message about XcodeGen failing

**Solution:**
1. Ensure XcodeGen is installed:
   ```bash
   brew install xcodegen
   ```

2. Verify XcodeGen works:
   ```bash
   xcodegen --version
   ```

3. Check the project.yml file for syntax errors:
   ```bash
   cat path/to/project/project.yml
   ```

### Build System Errors

**Problem:** Error message about BuildSystem failure

**Solution:**
1. Verify the UntoldEngine framework is properly built
2. Check that you're running the command from the correct directory
3. Ensure sufficient disk space for the project

### Permission Denied

**Problem:** Permission errors during installation

**Solution:**
Use sudo for installation:
```bash
sudo ./Scripts/install-create.sh
```

Or install to a user directory (advanced):
```bash
# Edit install-create.sh to use a different install location
# Change INSTALL_PATH to ~/bin/untoldengine-create
```

### Xcode Project Won't Open

**Problem:** Generated .xcodeproj file won't open

**Solution:**
1. Regenerate the project:
   ```bash
   cd path/to/project
   xcodegen generate
   ```

2. Check Xcode version compatibility:
   ```bash
   xcodebuild -version
   ```
   (Requires Xcode 15.0+)

3. Verify project.yml is valid:
   ```bash
   cat project.yml
   ```

### Assets Not Loading

**Problem:** Game can't find assets at runtime

**Solution:**
1. Verify assets are in the correct location:
   ```bash
   ls -la MyGame/Sources/MyGame/GameData/
   ```

2. Ensure assets are in the right subdirectories:
   - Models go in `GameData/Models/`
   - Textures go in `GameData/Textures/`
   - etc.

3. Check asset file names and extensions are correct

4. Verify the GameData directory structure by running update:
   ```bash
   untoldengine-create update MyGame
   ```

## Advanced Usage

### Scripting and Automation

The CLI tool is designed to work well in scripts:

```bash
#!/bin/bash
# create-all-platforms.sh

PROJECT_NAME="MyGame"

for PLATFORM in macos ios iosar visionos; do
    DIR="${PROJECT_NAME}-${PLATFORM}"
    mkdir -p "$DIR" && cd "$DIR"
    untoldengine-create create "$PROJECT_NAME" --platform "$PLATFORM"
    cd ..
done
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Create Game Projects
on: [push]

jobs:
  create-projects:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install CLI tool
        run: |
          cd UntoldEngine
          ./Scripts/install-create.sh
      
      - name: Create projects
        run: |
          mkdir -p builds/MyGame-iOS && cd builds/MyGame-iOS
          untoldengine-create create MyGame --platform ios
```

### Environment Variables

While the CLI doesn't currently use environment variables, you can use them in your workflow:

```bash
export GAME_NAME="MyGame"
export PLATFORM="ios"

mkdir "$GAME_NAME" && cd "$GAME_NAME"
untoldengine-create create "$GAME_NAME" --platform "$PLATFORM"
```

## Getting Help

For additional help:

```bash
# General help
untoldengine-create --help

# Command-specific help
untoldengine-create create --help
untoldengine-create update --help
```

## Feedback and Issues

Found a bug or have a feature request? Please report it on the [UntoldEngine GitHub repository](https://github.com/untoldengine/UntoldEngine/issues).
