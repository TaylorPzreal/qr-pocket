use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=native/Package.swift");
    println!("cargo:rerun-if-changed=native/Sources");
    println!("cargo:rerun-if-env-changed=DEVELOPER_DIR");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("macos") {
        panic!("QR Pocket requires macOS 13 or newer and the Xcode command line tools.");
    }
    if env::var("HOST") != env::var("TARGET") {
        panic!("Cross-compilation is not supported. Build QR Pocket on the target Mac.");
    }
    let root = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let output = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let profile = if env::var("PROFILE").as_deref() == Ok("release") {
        "release"
    } else {
        "debug"
    };
    let mut command = Command::new("swift");
    command
        .arg("build")
        .arg("--package-path")
        .arg(root.join("native"))
        .arg("--scratch-path")
        .arg(output.join("swift"))
        .arg("--configuration")
        .arg(profile)
        .arg("--disable-sandbox")
        .env("CLANG_MODULE_CACHE_PATH", output.join("clang-cache"))
        .env("MACOSX_DEPLOYMENT_TARGET", "13.0");
    let status = command
        .status()
        .expect("Install Xcode command line tools with xcode-select --install, then retry.");
    assert!(
        status.success(),
        "Native Swift build failed (see diagnostics above)."
    );
    let paths = command
        .arg("--show-bin-path")
        .output()
        .expect("Cannot locate the native executable.");
    assert!(
        paths.status.success(),
        "Swift could not report its build path."
    );
    let bin_path = String::from_utf8(paths.stdout).expect("Invalid Swift build path.");
    let executable = PathBuf::from(bin_path.trim()).join("QR Pocket");
    assert!(
        executable.is_file(),
        "Native executable was not produced: {}",
        executable.display()
    );
    println!(
        "cargo:rustc-env=QR_POCKET_EXECUTABLE={}",
        executable.display()
    );
}
