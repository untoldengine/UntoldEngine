#  Formatting and Linting

To maintain a consistent code style across the Untold Engine repo, we use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat). SwiftFormat is a code formatter for Swift that helps enforce Swift style conventions and keep the codebase clean.

### Installing SwiftFormat

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

### Format files with a Swift version

To format all Swift files in your project with a Swift version (I'm currently using 5.7):

1. Navigate to your project directory in the terminal.

2. Run the following command:

```bash
swiftformat --swiftversion 5.7 .
```

### Lint files

To lint all files, you can run the following command

```bash
swiftformat --swiftversion 5.7 --lint .
```
