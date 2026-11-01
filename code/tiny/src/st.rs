//! A minimal, read-only safetensors reader for `no_std`.
//!
//! Supports exactly what the talk models need: F32 tensors,
//! looked up by name. No allocation: tensors are borrowed
//! byte slices of the original buffer (flash on an MCU).

pub struct SafeTensors<'a> {
    header: &'a [u8],
    data: &'a [u8],
}

#[derive(Debug, PartialEq)]
pub enum Error {
    TooShort,
    BadHeader,
    Missing,
    NotF32,
    BadShape,
}

impl<'a> SafeTensors<'a> {
    pub fn parse(bytes: &'a [u8]) -> Result<Self, Error> {
        let len: [u8; 8] = bytes
            .get(..8)
            .ok_or(Error::TooShort)?
            .try_into()
            .map_err(|_| Error::TooShort)?;
        let n = u64::from_le_bytes(len) as usize;
        let header =
            bytes.get(8..8 + n).ok_or(Error::TooShort)?;
        let data = &bytes[8 + n..];
        Ok(SafeTensors { header, data })
    }

    /// Borrow the raw little-endian bytes of an F32 tensor
    /// with exactly `numel` elements.
    pub fn f32s(
        &self,
        name: &str,
        numel: usize,
    ) -> Result<F32s<'a>, Error> {
        // find "name":{
        let key = find_key(self.header, name.as_bytes())
            .ok_or(Error::Missing)?;
        let rest = &self.header[key..];
        let end = find(rest, b"}").ok_or(Error::BadHeader)?;
        let entry = &rest[..end];
        if find(entry, b"\"F32\"").is_none() {
            return Err(Error::NotF32);
        }
        let off = find(entry, b"\"data_offsets\":[")
            .ok_or(Error::BadHeader)?
            + 16;
        let (a, i) = number(&entry[off..])?;
        let (b, _) = number(&entry[off + i + 1..])?;
        if b < a || b - a != numel * 4 {
            return Err(Error::BadShape);
        }
        let bytes =
            self.data.get(a..b).ok_or(Error::BadHeader)?;
        Ok(F32s(bytes))
    }
}

/// Little-endian f32 values, read in place.
#[derive(Clone, Copy)]
pub struct F32s<'a>(&'a [u8]);

impl F32s<'_> {
    #[inline(always)]
    pub fn get(&self, i: usize) -> f32 {
        let b = &self.0[4 * i..4 * i + 4];
        f32::from_le_bytes([b[0], b[1], b[2], b[3]])
    }

    pub fn len(&self) -> usize {
        self.0.len() / 4
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }
}

fn find(hay: &[u8], needle: &[u8]) -> Option<usize> {
    hay.windows(needle.len()).position(|w| w == needle)
}

fn find_key(hay: &[u8], name: &[u8]) -> Option<usize> {
    // match `"name":` exactly, not a longer key
    let mut start = 0;
    while let Some(p) = find(&hay[start..], name) {
        let p = start + p;
        let q = p + name.len();
        if p > 0
            && hay[p - 1] == b'"'
            && hay.get(q) == Some(&b'"')
            && hay.get(q + 1) == Some(&b':')
        {
            return Some(q);
        }
        start = p + 1;
    }
    None
}

fn number(s: &[u8]) -> Result<(usize, usize), Error> {
    let mut v: usize = 0;
    let mut i = 0;
    while i < s.len() && s[i].is_ascii_digit() {
        v = v * 10 + (s[i] - b'0') as usize;
        i += 1;
    }
    if i == 0 { Err(Error::BadHeader) } else { Ok((v, i)) }
}
