//! Installation script for slq - Stockholm Local Traffic Query Tool
//!
//! This is a standalone Rust installer that can be compiled and run.
//! To use: cargo run --bin install -- [OPTIONS]

use clap::{Arg, Command as ClapCommand};
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::{Command, exit};

struct Config {
    install_dir: PathBuf,
    man_dir: PathBuf,
    project_dir: PathBuf,
}

impl Config {
    fn new() -> Self {
        // Try to find project directory relative to current location
        let current_dir = env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        let project_dir = if current_dir
            .file_name()
            .map(|name| name == "scripts")
            .unwrap_or(false)
        {
            current_dir.parent().unwrap_or(&current_dir).to_path_buf()
        } else {
            current_dir
        };

        let install_dir = env::var("INSTALL_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/usr/local/bin"));

        let man_dir = env::var("MAN_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/usr/local/share/man/man1"));

        Self {
            install_dir,
            man_dir,
            project_dir,
        }
    }

    fn set_user_install(&mut self) {
        if let Some(home) = env::var_os("HOME") {
            let home_path = PathBuf::from(home);
            self.install_dir = home_path.join(".local/bin");
            self.man_dir = home_path.join(".local/share/man/man1");
            log_info(&format!(
                "Installing to user directory: {}",
                home_path.join(".local").display()
            ));
        } else {
            log_error("HOME environment variable not set");
            exit(1);
        }
    }

    fn set_prefix(&mut self, prefix: &str) {
        let prefix_path = PathBuf::from(prefix);
        self.install_dir = prefix_path.join("bin");
        self.man_dir = prefix_path.join("share/man/man1");
        log_info(&format!("Installing to prefix: {}", prefix));
    }
}

// ANSI color codes
const RED: &str = "\x1b[31m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const BLUE: &str = "\x1b[34m";
const BOLD: &str = "\x1b[1m";
const RESET: &str = "\x1b[0m";

fn log_info(msg: &str) {
    println!("{}{}[INFO]{} {}", BLUE, BOLD, RESET, msg);
}

fn log_success(msg: &str) {
    println!("{}{}[SUCCESS]{} {}", GREEN, BOLD, RESET, msg);
}

fn log_error(msg: &str) {
    eprintln!("{}{}[ERROR]{} {}", RED, BOLD, RESET, msg);
}

fn log_warning(msg: &str) {
    println!("{}{}[WARNING]{} {}", YELLOW, BOLD, RESET, msg);
}

fn check_and_adjust_permissions(config: &mut Config) -> Result<(), Box<dyn std::error::Error>> {
    if config.install_dir.starts_with("/usr") {
        #[cfg(unix)]
        {
            let euid = unsafe { libc::geteuid() };
            if euid != 0 {
                log_warning("No root privileges detected, switching to user installation");
                config.set_user_install();
            }
        }
        #[cfg(not(unix))]
        {
            log_warning("Permission checking not available on this platform, using user directory");
            config.set_user_install();
        }
    }
    Ok(())
}

fn build_binary(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    log_info("Building slq...");

    // Check if we're in the right directory
    let cargo_toml = config.project_dir.join("Cargo.toml");
    if !cargo_toml.exists() {
        log_error(&format!("Cargo.toml not found at {}", cargo_toml.display()));
        log_error("Please run this from the project root directory");
        exit(1);
    }

    // Check if cargo is available
    if Command::new("cargo").arg("--version").output().is_err() {
        log_error("Cargo not found. Please install Rust: https://rustup.rs/");
        exit(1);
    }

    // Build the project
    let output = Command::new("cargo")
        .arg("build")
        .arg("--release")
        .current_dir(&config.project_dir)
        .output()?;

    if !output.status.success() {
        log_error("Build failed");
        io::stderr().write_all(&output.stderr)?;
        exit(1);
    }

    let binary_path = config.project_dir.join("target/release/slq");
    if !binary_path.exists() {
        log_error("Build failed - binary not found");
        exit(1);
    }

    log_success("Build completed successfully");
    Ok(())
}

fn install_binary(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    log_info(&format!(
        "Installing binary to {}",
        config.install_dir.display()
    ));

    // Create directory if it doesn't exist
    fs::create_dir_all(&config.install_dir)?;

    // Copy binary
    let source = config.project_dir.join("target/release/slq");
    let destination = config.install_dir.join("slq");

    fs::copy(&source, &destination)?;

    // Set executable permissions (Unix only)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&destination)?.permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&destination, perms)?;
    }

    log_success(&format!("Binary installed to {}", destination.display()));
    Ok(())
}

fn install_man_page(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    let man_file = config.project_dir.join("slq.1");

    if !man_file.exists() {
        log_warning(&format!(
            "Man page not found at {}, skipping",
            man_file.display()
        ));
        return Ok(());
    }

    log_info(&format!(
        "Installing man page to {}",
        config.man_dir.display()
    ));

    // Create directory if it doesn't exist
    fs::create_dir_all(&config.man_dir)?;

    // Copy man page
    let destination = config.man_dir.join("slq.1");
    fs::copy(&man_file, &destination)?;

    // Set permissions (Unix only)
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&destination)?.permissions();
        perms.set_mode(0o644);
        fs::set_permissions(&destination, perms)?;
    }

    // Update man database if available
    if Command::new("mandb").output().is_ok() {
        let _ = Command::new("mandb").output(); // Ignore errors
    }

    log_success(&format!("Man page installed to {}", destination.display()));
    Ok(())
}

fn uninstall(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    log_info("Uninstalling slq...");

    // Remove binary
    let binary_path = config.install_dir.join("slq");
    if binary_path.exists() {
        fs::remove_file(&binary_path)?;
        log_success(&format!("Removed binary from {}", binary_path.display()));
    } else {
        log_warning(&format!("Binary not found at {}", binary_path.display()));
    }

    // Remove man page
    let man_path = config.man_dir.join("slq.1");
    if man_path.exists() {
        fs::remove_file(&man_path)?;
        log_success(&format!("Removed man page from {}", man_path.display()));

        // Update man database if available
        if Command::new("mandb").output().is_ok() {
            let _ = Command::new("mandb").output(); // Ignore errors
        }
    } else {
        log_warning(&format!("Man page not found at {}", man_path.display()));
    }

    log_success("Uninstallation completed");
    Ok(())
}

fn verify_installation(config: &Config) -> Result<(), Box<dyn std::error::Error>> {
    log_info("Verifying installation...");

    let binary_path = config.install_dir.join("slq");

    // Check if binary exists and is executable
    if binary_path.exists() {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let perms = fs::metadata(&binary_path)?.permissions();
            if perms.mode() & 0o111 != 0 {
                log_success("Binary is executable");
            } else {
                log_error("Binary is not executable");
                return Err("Binary is not executable".into());
            }
        }
        #[cfg(not(unix))]
        {
            log_success("Binary exists");
        }
    } else {
        log_error("Binary not found after installation");
        return Err("Binary not found".into());
    }

    // Check if binary is in PATH and works
    match Command::new("slq").arg("--help").output() {
        Ok(output) if output.status.success() => {
            let first_line = String::from_utf8_lossy(&output.stdout)
                .lines()
                .next()
                .unwrap_or("slq")
                .to_string();
            log_success(&format!("slq is in PATH: {}", first_line));
        }
        _ => {
            log_warning(
                "slq is not in PATH. You may need to add the install directory to your PATH",
            );
            log_info("Add this to your shell profile (.bashrc, .zshrc, etc.):");
            log_info(&format!(
                "  export PATH=\"{}:$PATH\"",
                config.install_dir.display()
            ));
        }
    }

    // Check man page
    let man_path = config.man_dir.join("slq.1");
    if man_path.exists() {
        log_success("Man page installed (try 'man slq')");
    } else {
        log_warning("Man page not installed");
    }

    Ok(())
}

fn main_install(config: &mut Config) -> Result<(), Box<dyn std::error::Error>> {
    log_info("Installing slq - Stockholm Local Traffic Query Tool");

    check_and_adjust_permissions(config)?;

    log_info(&format!(
        "Installation directory: {}",
        config.install_dir.display()
    ));
    log_info(&format!("Man page directory: {}", config.man_dir.display()));
    println!();
    build_binary(config)?;
    install_binary(config)?;
    install_man_page(config)?;
    verify_installation(config)?;

    println!();
    log_success("Installation completed successfully!");
    log_info("Try running: slq search \"Central\"");
    log_info("For help: slq --help or man slq");
    log_info("Licensed under BSD 3-Clause License");

    Ok(())
}

fn main() {
    let matches = ClapCommand::new("slq-installer")
        .about("Installation script for slq - Stockholm Local Traffic Query Tool")
        .long_about("Installs slq binary and man page. Automatically falls back to user directory when system-wide installation requires root privileges.")
        .arg(
            Arg::new("uninstall")
                .long("uninstall")
                .action(clap::ArgAction::SetTrue)
                .help("Uninstall slq"),
        )
        .arg(
            Arg::new("user")
                .long("user")
                .action(clap::ArgAction::SetTrue)
                .help("Install to user directory (~/.local)"),
        )
        .arg(
            Arg::new("prefix")
                .long("prefix")
                .value_name("PREFIX")
                .help("Install to custom prefix (default: /usr/local)"),
        )
        .after_help("Environment Variables:
  INSTALL_DIR         Binary installation directory (default: /usr/local/bin)
  MAN_DIR            Man page directory (default: /usr/local/share/man/man1)

Examples:
  cargo run --bin install                                # Auto-detects privileges (recommended)
  cargo run --bin install -- --user                      # Force user installation
  INSTALL_DIR=~/bin cargo run --bin install              # Custom directory
  sudo cargo run --bin install -- --prefix /opt/slq     # Custom prefix

Note: The installer automatically falls back to user directory (~/.local)
      when system-wide installation requires root privileges.")
        .get_matches();

    let mut config = Config::new();

    if matches.get_flag("user") {
        config.set_user_install();
    }

    if let Some(prefix) = matches.get_one::<String>("prefix") {
        config.set_prefix(prefix);
    }

    if matches.get_flag("uninstall") {
        if let Err(e) = check_and_adjust_permissions(&mut config) {
            log_error(&format!("Permission check failed: {}", e));
            exit(1);
        }
        if let Err(e) = uninstall(&config) {
            log_error(&format!("Uninstallation failed: {}", e));
            exit(1);
        }
        return;
    }

    if let Err(e) = main_install(&mut config) {
        log_error(&format!("Installation failed: {}", e));
        exit(1);
    }
}
