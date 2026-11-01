//! Character vocabulary shared by every implementation.
//!
//! Index 0 is `\n`, indices 1..=95 are the printable
//! ASCII characters `' '..='~'`. Everything else is dropped.

pub const VOCAB: usize = 96;

pub fn encode(b: u8) -> Option<u8> {
    match b {
        b'\n' => Some(0),
        b' '..=b'~' => Some(b - 31),
        _ => None,
    }
}

pub fn decode(i: usize) -> u8 {
    if i == 0 { b'\n' } else { i as u8 + 31 }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trip() {
        for b in (b' '..=b'~').chain([b'\n']) {
            let i = encode(b).unwrap() as usize;
            assert!(i < VOCAB);
            assert_eq!(decode(i), b);
        }
        assert_eq!(encode(b'\t'), None);
    }
}
