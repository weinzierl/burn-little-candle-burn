//! Build data/corpus.txt from Candle's own source code
//! (candle-core 0.11.0 and candle-nn 0.11.0, MIT OR Apache-2.0),
//! taken from the local cargo registry or a `vendor/` dir.
use std::path::{Path, PathBuf};

fn find_src(krate: &str) -> PathBuf {
    for dir in [krate.to_string(), format!("{krate}-0.11.0")] {
        let vendored = Path::new("vendor").join(dir).join("src");
        if vendored.is_dir() {
            return vendored;
        }
    }
    let home = std::env::var("CARGO_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            PathBuf::from(std::env::var("HOME").unwrap())
                .join(".cargo")
        });
    let reg = home.join("registry").join("src");
    for idx in std::fs::read_dir(&reg).expect("cargo registry") {
        let p = idx
            .unwrap()
            .path()
            .join(format!("{krate}-0.11.0"))
            .join("src");
        if p.is_dir() {
            return p;
        }
    }
    panic!(
        "{krate} 0.11.0 sources not found; run `cargo fetch` first"
    )
}

fn collect(dir: &Path, out: &mut Vec<PathBuf>) {
    let mut entries: Vec<_> = std::fs::read_dir(dir)
        .unwrap()
        .map(|e| e.unwrap().path())
        .collect();
    entries.sort();
    for p in entries {
        if p.is_dir() {
            collect(&p, out);
        } else if p.extension().is_some_and(|e| e == "rs") {
            // SIMD intrinsics are noise for a language model
            let name = p.file_name().unwrap().to_str().unwrap();
            if !matches!(
                name,
                "avx.rs" | "neon.rs" | "simd128.rs"
            ) {
                out.push(p);
            }
        }
    }
}

fn main() {
    let mut files = Vec::new();
    for krate in ["candle-core", "candle-nn"] {
        collect(&find_src(krate), &mut files);
    }
    let mut text = Vec::new();
    for f in &files {
        let src = std::fs::read(f).unwrap();
        for &b in &src {
            match b {
                b'\t' => text.extend_from_slice(b"    "),
                b'\r' => {}
                b if tiny::vocab::encode(b).is_some() => {
                    text.push(b)
                }
                _ => {}
            }
        }
        text.extend_from_slice(b"\n\n");
    }
    std::fs::write("data/corpus.txt", &text).unwrap();
    println!(
        "{} files, {} bytes -> data/corpus.txt",
        files.len(),
        text.len()
    );
}
