# Formatting and Linting

To maintain a consistent code style across the Untold Engine repo, we use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat). SwiftFormat is a code formatter for Swift that helps enforce Swift style conventions and keep the codebase clean. If you don't have SwiftFormat installed, see the **Installing SwiftFormat** section below.

## Quick Formatting & Linting 

Navigate to the root directory of Untold Engine and then run the commands below: 

### 🔍 Lint files

To lint (check) all Swift files without making changes:

```bash
swiftformat --lint . --swiftversion 5.8 --reporter github-actions-log
```

Or, using the Makefile:

```bash
make lint
```

This command runs the same lint configuration as our GitHub Actions workflow and pre-commit hook, ensuring consistent results locally and in CI.

### ✅ Formatting Files

To format files: 

```bash
swiftformat --swiftversion 5.8 .
```

Alternatively, you can use the Makefile shortcut:

```bash 
make format
```

💡 Tip
If the pre-commit hook blocks your commit due to formatting issues, simply run:

```bash
make format
```

then re-stage your changes and try committing again.

You can bypass the hook temporarily (not recommended) with:

```bash 
git commit --no-verify
```

## Installing SwiftFormat

The simplest way to install SwiftFormat is through the command line.

1. Install SwiftFormat Using Homebrew: Open the terminal and run the following command:

```bash
brew install swiftformat
```
2. Verify Installation: After installation, verify that SwiftFormat is installed correctly by running:

```bash
swiftformat --version
```
This should print the installed version of SwiftFormat.

### Using SwiftFormat

Format a Single File

To format a specific Swift file:

1. Open the terminal and navigate to your project directory.

2. Run the following command:

```bash
swiftformat path/to/YourFile.swift
```
This will format YourFile.swift according to the default rules.

### Format Multiple Files

To format all Swift files in your project:

1. Navigate to your project directory in the terminal.

2. Run the following command:

```bash
swiftformat .
```

This will recursively format all Swift files in the current directory and its subdirectories.


