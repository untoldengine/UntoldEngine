# Multi-Platform CLI Usage

The `untoldengine-create` CLI tool now supports creating multi-platform game projects that target macOS, iOS, and visionOS simultaneously.

## Quick Start

Create a multi-platform project in one command:

```bash
mkdir MyGame && cd MyGame
untoldengine-create create MyGame --platform multi --team-id YOUR_TEAM_ID
```

This creates a single Xcode project that can be built for macOS, iOS, and visionOS.

## Command Options

### Basic Multi-Platform Project

```bash
untoldengine-create create <project-name> --platform multi
```

**Required for iOS/visionOS builds:**
```bash
untoldengine-create create MyGame --platform multi --team-id ABCD1234EF
```

The `--team-id` is your Apple Developer Team ID, required for code signing iOS and visionOS apps.

### Custom Deployment Targets

Specify deployment versions for each platform:

```bash
untoldengine-create create MyGame \
  --platform multi \
  --macos-version 14 \
  --ios-version 17 \
  --visionos-version 2 \
  --team-id YOUR_TEAM_ID
```

**Available versions:**
- macOS: `13`, `14`, `15` (default: `15`)
- iOS: `16`, `17`, `18` (default: `17`)
- visionOS: `1`, `2` (default: `2`)

### Full Options

```bash
untoldengine-create create MyGame \
  --platform multi \
  --bundle-id com.mycompany.mygame \
  --output ~/Projects \
  --macos-version 14 \
  --ios-version 17 \
  --visionos-version 2 \
  --team-id YOUR_TEAM_ID \
  --optimization speed \
  --debug
```

**All options:**
- `--platform multi` - Create multi-platform project
- `--bundle-id` - Bundle identifier (default: auto-generated)
- `--output` - Output directory (default: current directory)
- `--macos-version` - macOS deployment target
- `--ios-version` - iOS deployment target
- `--visionos-version` - visionOS deployment target
- `--team-id` - Apple Developer Team ID
- `--optimization` - Optimization level: `none`, `speed`, `size` (default: `none`)
- `--debug` / `--no-debug` - Include debug info (default: `true`)

## Output

The CLI will display a configuration summary:

```
🎮 UntoldEngine Project Creator
Creating project: MyGame

📋 Configuration:
   Project Name:    MyGame
   Bundle ID:       com.example.mygame
   Platform:        Multi-Platform
     - macOS:       15.0
     - iOS:         17.0
     - visionOS:    2.0
   Project Dir:     /path/to/MyGame
   GameData Path:   /path/to/MyGame/Sources/MyGame/GameData
   Optimization:    -Onone
   Debug Info:      Yes
   Team ID:         ABCD1234EF

🔨 Starting build process...

✅ Settings validated
📁 Created project directory
📋 Copied template project
📦 Bundled 0 assets
⚙️ Configured Xcode project
✅ Build complete in 2.15s

✅ Project created at: /path/to/MyGame
ℹ️  Bundled 0 assets

📁 Add your game assets to: /path/to/MyGame/Sources/MyGame/GameData

Open project in Xcode? [Y/n]: 
```

## Using the Generated Project

### Open in Xcode

```bash
open MyGame/MyGame.xcodeproj
```

### Select Platform

In Xcode, use the scheme selector at the top to choose your target platform:
- **My Mac** - Build and run on macOS
- **iPhone/iPad** - Build and run on iOS device/simulator
- **Apple Vision Pro** - Build and run on visionOS device/simulator

### Build and Run

Press `Cmd+R` or click the Play button to build and run for the selected platform.

## Comparison: Single vs Multi-Platform

### Single Platform (Separate Projects)

```bash
# Create three separate projects
untoldengine-create create MyGame --platform macos
untoldengine-create create MyGame --platform ios
untoldengine-create create MyGame --platform visionos
```

**Result:** 3 separate Xcode projects to maintain

### Multi-Platform (One Project)

```bash
# Create one unified project
untoldengine-create create MyGame --platform multi --team-id YOUR_TEAM_ID
```

**Result:** 1 Xcode project that targets all platforms

## Project Structure

```
MyGame/
├── MyGame.xcodeproj          # Multi-platform Xcode project
├── project.yml               # XcodeGen configuration
├── README.md
└── Sources/
    └── MyGame/
        ├── AppDelegate.swift         # Platform-specific (with #if os(...))
        ├── GameScene.swift           # Shared across all platforms
        ├── GameViewController.swift  # Platform-specific (with #if os(...))
        ├── Base.lproj/
        │   └── Main.storyboard      # For macOS/iOS
        ├── Info.plist               # Multi-platform compatible
        └── GameData/                # Shared game assets
            ├── Scenes/
            ├── Scripts/
            ├── Models/
            ├── Animations/
            ├── Gaussians/
            ├── Textures/
            └── Shaders/
```

## Platform-Specific Code

The generated templates use conditional compilation. You can add platform-specific logic:

```swift
class GameScene {
    func setupControls() {
        #if os(macOS)
        // macOS: keyboard + mouse
        setupKeyboardControls()
        #elseif os(iOS)
        // iOS: touch controls
        setupTouchControls()
        #elseif os(visionOS)
        // visionOS: spatial gestures
        setupSpatialControls()
        #endif
    }
}
```

## Finding Your Apple Developer Team ID

Your Team ID is required for iOS and visionOS code signing. Find it:

1. **Via Xcode:**
   - Open Xcode preferences
   - Go to Accounts
   - Select your Apple ID
   - Your Team ID is shown next to your team name

2. **Via Developer Portal:**
   - Visit https://developer.apple.com/account
   - Go to Membership
   - Your Team ID is listed

3. **Via Keychain:**
   ```bash
   security find-identity -v -p codesigning | grep "Developer"
   ```

## Tips

✅ **Always specify `--team-id`** for multi-platform projects (required for iOS/visionOS)  
✅ **One GameData folder** - assets are shared across all platforms  
✅ **One GameScene** - game logic is identical across platforms  
✅ **Version control friendly** - one project instead of three  
✅ **Switch platforms** easily in Xcode without changing projects  

## Examples

### Basic Multi-Platform Game

```bash
mkdir SpaceGame && cd SpaceGame
untoldengine-create create SpaceGame \
  --platform multi \
  --bundle-id com.studio.spacegame \
  --team-id ABCD1234EF
```

### Production Build with Optimization

```bash
mkdir ReleaseGame && cd ReleaseGame
untoldengine-create create ReleaseGame \
  --platform multi \
  --bundle-id com.studio.releasegame \
  --team-id ABCD1234EF \
  --optimization speed \
  --no-debug
```

### Custom Deployment Targets

```bash
mkdir ModernGame && cd ModernGame
untoldengine-create create ModernGame \
  --platform multi \
  --macos-version 15 \
  --ios-version 18 \
  --visionos-version 2 \
  --team-id ABCD1234EF
```

## Troubleshooting

**Error: "Build failed: xcodegen not found"**
```bash
brew install xcodegen
```

**Error: "Invalid bundle identifier"**
- Use format: `com.company.app`
- Only alphanumeric, dots, and hyphens
- Example: `com.mystudio.mygame`

**iOS/visionOS build fails with signing error:**
- Ensure you've provided `--team-id`
- Verify your Team ID is correct
- Check your Apple Developer account is active

**Platform switch not working in Xcode:**
- Make sure you've opened the `.xcodeproj` file
- Check that all platforms appear in the scheme selector
- Try cleaning the build folder (`Cmd+Shift+K`)

## See Also

- [Multi-Platform Build System Documentation](../../Documentation/MultiPlatformBuildExample.md)
- [UntoldEngine Documentation](https://github.com/untoldengine/UntoldEngine)
