use std::os::unix::process::CommandExt;
use std::process::Command;

fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.first().is_some_and(|arg| arg == "--native-path") {
        println!("{}", env!("QR_POCKET_EXECUTABLE"));
        return;
    }
    if args
        .first()
        .is_some_and(|arg| arg == "--help" || arg == "-h")
    {
        println!("QR Pocket - macOS menu bar QR code manager\n\nRun without arguments to open the app.\n--native-path  Print the native executable path for packaging.");
        return;
    }
    let error = Command::new(env!("QR_POCKET_EXECUTABLE")).args(args).exec();
    eprintln!(
        "Unable to launch QR Pocket: {error}\nRebuild with cargo build, or use the packaged .app."
    );
    std::process::exit(1);
}
