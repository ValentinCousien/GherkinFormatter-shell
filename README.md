# Ghokin Shell

A pure Bash implementation of the Ghokin Gherkin formatter.

## Description

Ghokin Shell is a shell script version of [Ghokin](https://github.com/antham/ghokin), a tool to format and apply transformations on Gherkin (`.feature`) files.

## Features

- Format Gherkin feature files with proper indentation
- Align table columns automatically based on content width
- Support for UTF-8 characters (including French, Spanish, and other accented characters)
- Read from stdin or file
- Format and replace files in place
- Check if files are properly formatted
- Configuration via `.ghokin.yml` or environment variables
- Support for shell command transformations via annotations

## Requirements

- Bash 3.0 or higher
- awk (BSD or GNU awk)
- Standard Unix tools (find, cat)

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/ValentinCousien/Ghokin-shell/master/ghokin.sh

# Make it executable
chmod +x ghokin.sh

# Optionally, move to a directory in your PATH
sudo mv ghokin.sh /usr/local/bin/ghokin.sh
```

## Usage

### Format to stdout

```bash
# Format a file and output to stdout
./ghokin.sh fmt stdout features/test.feature

# Read from stdin
cat features/test.feature | ./ghokin.sh fmt stdout
```

### Format and replace

```bash
# Format and replace a single file
./ghokin.sh fmt replace features/test.feature

# Format all .feature files in a directory
./ghokin.sh fmt replace features/

# Use custom file extensions
./ghokin.sh fmt replace features/ -e feature,spec
```

### Check formatting

```bash
# Check if a file is properly formatted
./ghokin.sh check features/test.feature

# Check all files in a directory
./ghokin.sh check features/
```

## Configuration

### Using .ghokin.yml

Create a `.ghokin.yml` file in your home directory or current directory:

```yaml
indent: 2
aliases:
  json: "jq ."
```

### Using environment variables

```bash
export GHOKIN_INDENT=2
export GHOKIN_ALIASES='{"json":"jq ."}'
```

## Features

### Proper indentation

The script applies proper indentation to all Gherkin elements:

- Feature: no indentation
- Background/Scenario: 1 level
- Steps (Given/When/Then): 2 levels
- DocStrings/Tables: 3 levels
- Rule support with additional indentation

### Table alignment

Tables are automatically aligned based on the longest content in each column:

```gherkin
| name           | age | city          |
| John           | 25  | New York      |
| Jane           | 30  | Los Angeles   |
| Bob            | 45  | San Francisco |
```

### UTF-8 support

Full support for multi-byte UTF-8 characters, including French accents:

```gherkin
| Document d'Informations Clés                           | obligatoire |
| Conditions de l'offre exceptionnelle Gestion Pilotée   | optionnel   |
```

### Language support

Supports multiple Gherkin languages:
- English (Feature, Scenario, Given, When, Then, And, But)
- French (Fonctionnalité, Scénario, Soit, Quand, Alors, Et, Mais)
- Spanish (Función, Escenario, Dado, Cuando, Entonces, Y, Pero)

## Command Reference

```
Usage:
  ghokin.sh [command]

Available Commands:
  check       Check a file/folder is well formatted
  fmt         Format a feature file/folder
  help        Show this help message

Flags:
  --config string   config file
  -h, --help       help for ghokin
```

### fmt stdout

```
Format stdin or a file and dump the result on stdout

Usage:
  ghokin.sh fmt stdout [file path]
```

### fmt replace

```
Format and replace a file or a pool of files in folder

Usage:
  ghokin.sh fmt replace [file or folder path]

Flags:
  -e, --extensions   Define file extensions to use (default: feature)
```

### check

```
Check a file/folder is well formatted

Usage:
  ghokin.sh check [file or folder path]

Flags:
  -e, --extensions   Define file extensions to use (default: feature)
```

## Compatibility

This script is compatible with:
- macOS (BSD awk)
- Linux (GNU awk)
- Bash 3.x and higher

## Differences from Go version

While this shell version aims to replicate the core functionality of the Go version, there are some differences:

- **Performance**: The Go version is faster for processing large numbers of files
- **Shell commands**: Simplified implementation of annotation-based transformations
- **Character encoding**: Automatic UTF-8 conversion is not implemented (assumes UTF-8 input)

## License

This project is inspired by [Ghokin](https://github.com/antham/ghokin) by Anthony Hamon.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
