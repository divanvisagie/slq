#!/bin/bash
# Publish script for slq - creates GitHub releases with artifacts
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DRY_RUN=false
FORCE=false
VERSION=""
YES=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [VERSION]

Publish a new release of slq to GitHub with binary artifacts.

OPTIONS:
    -d, --dry-run    Show what would be done without making changes
    -f, --force      Force release even if tag already exists
    -y, --yes        Skip confirmation prompt
    -h, --help       Show this help message

ARGUMENTS:
    VERSION          Version to release (e.g., "1.2.3" or "v1.2.3")
                     If not provided, will extract from slq.1 man page

EXAMPLES:
    $0                    # Auto-detect version from man page
    $0 1.2.3             # Release version 1.2.3
    $0 v1.2.3            # Release version v1.2.3
    $0 --dry-run         # Preview what would happen
    $0 --force v1.2.3    # Force release even if tag exists
    $0 --yes             # Skip confirmation prompt

REQUIREMENTS:
    - gh CLI tool must be installed and authenticated
    - Git repository must be clean (or use --force)
    - Must be on main/master branch (or use --force)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -y|--yes)
            YES=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$VERSION" ]]; then
                VERSION="$1"
            else
                log_error "Too many arguments. VERSION already set to '$VERSION'"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Change to project directory
cd "$PROJECT_DIR"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) is not installed. Install it with:"
    echo "  brew install gh                    # macOS"
    echo "  sudo apt install gh               # Ubuntu/Debian"
    echo "  See: https://cli.github.com/"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    log_error "GitHub CLI is not authenticated. Run:"
    echo "  gh auth login"
    exit 1
fi

# Extract version from man page if not provided
if [[ -z "$VERSION" ]]; then
    if [[ -f "slq.1" ]]; then
        VERSION=$(grep -o 'slq [0-9]\+\.[0-9]\+\.[0-9]\+' slq.1 | cut -d' ' -f2)
        if [[ -z "$VERSION" ]]; then
            log_error "Could not extract version from slq.1 man page"
            exit 1
        fi
        log_info "Auto-detected version from man page: $VERSION"
    else
        log_error "No version provided and slq.1 not found"
        show_usage
        exit 1
    fi
fi

# Normalize version (ensure it starts with 'v')
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v$VERSION"
fi

log_info "Preparing to release version: $VERSION"

# Check if we're in a git repository
if ! git rev-parse --git-dir &> /dev/null; then
    log_error "Not in a git repository"
    exit 1
fi

# Check if tag already exists
if git tag -l | grep -q "^$VERSION$"; then
    if [[ "$FORCE" == false ]]; then
        log_error "Tag $VERSION already exists. Use --force to override."
        exit 1
    else
        log_warning "Tag $VERSION already exists, but --force was specified"
    fi
fi

# Check if working directory is clean
if [[ "$FORCE" == false ]] && ! git diff-index --quiet HEAD --; then
    log_error "Working directory is not clean. Commit or stash changes first, or use --force."
    exit 1
fi

# Check if we're on main or master branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$FORCE" == false ]] && [[ "$CURRENT_BRANCH" != "main" ]] && [[ "$CURRENT_BRANCH" != "master" ]]; then
    log_error "Not on main/master branch (currently on: $CURRENT_BRANCH). Use --force to override."
    exit 1
fi

# Show what we're about to do
log_info "Release summary:"
echo "  Version: $VERSION"
echo "  Branch: $CURRENT_BRANCH"
echo "  Dry run: $DRY_RUN"
echo "  Force: $FORCE"
echo ""

if [[ "$DRY_RUN" == false ]] && [[ "$YES" == false ]]; then
    read -p "Proceed with release? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Release cancelled"
        exit 0
    fi
fi

# Clean and build release version
log_info "Building release artifacts..."
if [[ "$DRY_RUN" == false ]]; then
    make clean
    make all

    # Verify binary was built
    if [[ ! -f "bin/slq" ]]; then
        log_error "Failed to build binary"
        exit 1
    fi

    # Run tests to make sure everything works
    log_info "Running tests..."
    make test-basic || {
        log_error "Tests failed, aborting release"
        exit 1
    }
else
    log_info "[DRY RUN] Would run: make clean && make all && make test-basic"
fi

# Create archive with binary and documentation
ARCHIVE_NAME="slq-$VERSION-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m).tar.gz"
log_info "Creating archive: $ARCHIVE_NAME"

if [[ "$DRY_RUN" == false ]]; then
    # Create temporary directory for archive contents
    TEMP_DIR=$(mktemp -d)
    ARCHIVE_DIR="$TEMP_DIR/slq-$VERSION"

    mkdir -p "$ARCHIVE_DIR"

    # Copy files to archive directory
    cp bin/slq "$ARCHIVE_DIR/"
    cp slq.1 "$ARCHIVE_DIR/"
    cp README.md "$ARCHIVE_DIR/"
    cp LICENSE "$ARCHIVE_DIR/"

    # Create archive
    (cd "$TEMP_DIR" && tar -czf "$PROJECT_DIR/$ARCHIVE_NAME" "slq-$VERSION")

    # Cleanup temp directory
    rm -rf "$TEMP_DIR"

    log_success "Created archive: $ARCHIVE_NAME ($(du -h "$ARCHIVE_NAME" | cut -f1))"
else
    log_info "[DRY RUN] Would create archive: $ARCHIVE_NAME"
fi

# Generate release notes
RELEASE_NOTES_FILE=$(mktemp)
cat > "$RELEASE_NOTES_FILE" << EOF
# slq $VERSION

A command-line tool for querying Storstockholms Lokaltrafik (SL) information.

## Installation

### Download Binary
Download the appropriate binary for your platform from the assets below.

\`\`\`bash
# Extract and install
tar -xzf slq-$VERSION-*.tar.gz
cd slq-$VERSION
sudo cp slq /usr/local/bin/
sudo cp slq.1 /usr/local/share/man/man1/
\`\`\`

### Build from Source
\`\`\`bash
git clone https://github.com/your-username/slq.git
cd slq
git checkout $VERSION
make install
\`\`\`

## Usage

\`\`\`bash
# Search for stations
slq search "Central"

# Get departures
slq departures "T-Centralen"

# Filter departures
slq departures "T-Centralen" --transport-type metro --line 14
\`\`\`

## What's Included

- \`slq\` - Main binary
- \`slq.1\` - Manual page
- \`README.md\` - Documentation
- \`LICENSE\` - License file

See the [README](README.md) for full documentation.
EOF

if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create release with notes:"
    cat "$RELEASE_NOTES_FILE"
    log_info "[DRY RUN] Would attach archive: $ARCHIVE_NAME"
    rm -f "$RELEASE_NOTES_FILE"
    exit 0
fi

# Create git tag and push
log_info "Creating and pushing git tag..."
git tag -a "$VERSION" -m "Release $VERSION"

# Auto-detect remote name
REMOTE=$(git remote | head -1)
if [[ -z "$REMOTE" ]]; then
    log_error "No git remote found"
    exit 1
fi
log_info "Pushing tag to remote: $REMOTE"
git push "$REMOTE" "$VERSION"

# Create GitHub release
log_info "Creating GitHub release..."
gh release create "$VERSION" \
    --title "slq $VERSION" \
    --notes-file "$RELEASE_NOTES_FILE" \
    "$ARCHIVE_NAME"

# Cleanup
rm -f "$RELEASE_NOTES_FILE" "$ARCHIVE_NAME"

log_success "Successfully published release $VERSION!"
log_info "View the release at: $(gh repo view --web | head -1)/releases/tag/$VERSION"
