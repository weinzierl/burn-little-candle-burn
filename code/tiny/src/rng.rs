//! xorshift64*: the same random numbers in Candle, Burn
//! and on a microcontroller, so sampled text can be compared.

pub struct Rng(u64);

impl Rng {
    pub fn new(seed: u64) -> Self {
        Rng(seed.max(1))
    }

    pub fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545_f491_4f6c_dd1d)
    }

    /// Uniform in [0, 1), 24 bits of precision.
    pub fn next_f32(&mut self) -> f32 {
        (self.next_u64() >> 40) as f32 / (1u64 << 24) as f32
    }

    pub fn below(&mut self, n: usize) -> usize {
        (self.next_u64() % n as u64) as usize
    }
}

/// Pick an index from unnormalised log-probabilities
/// (`logits`) at temperature `t`, using one uniform `u`.
pub fn sample(logits: &[f32], t: f32, u: f32) -> usize {
    let max = logits.iter().fold(f32::MIN, |m, &x| m.max(x));
    let mut sum = 0.0;
    for &l in logits {
        sum += exp((l - max) / t);
    }
    let mut acc = 0.0;
    for (i, &l) in logits.iter().enumerate() {
        acc += exp((l - max) / t) / sum;
        if u < acc {
            return i;
        }
    }
    logits.len() - 1
}

/// `core` has no `exp` for f32 without `std`; this is
/// accurate to about 1e-7 relative on the range we use.
pub fn exp(x: f32) -> f32 {
    if x < -87.0 {
        return 0.0;
    }
    // exp(x) = 2^k * exp(r), |r| <= ln2/2
    let t = x * core::f32::consts::LOG2_E;
    // round half away from zero, without libm
    let k = if t >= 0.0 {
        (t + 0.5) as i32
    } else {
        (t - 0.5) as i32
    };
    let r = x - k as f32 * core::f32::consts::LN_2;
    // degree 6 Taylor polynomial for exp(r)
    let p = 1.0
        + r * (1.0
            + r * (0.5
                + r * (1.0 / 6.0
                    + r * (1.0 / 24.0
                        + r * (1.0 / 120.0 + r / 720.0)))));
    p * f32::from_bits(((k + 127) as u32) << 23)
}

/// tanh via exp, same function on every target.
pub fn tanh(x: f32) -> f32 {
    if x > 9.0 {
        return 1.0;
    }
    if x < -9.0 {
        return -1.0;
    }
    let e = exp(2.0 * x);
    (e - 1.0) / (e + 1.0)
}

#[cfg(test)]
mod tests {
    extern crate std;
    use super::*;

    #[test]
    fn exp_matches_std() {
        let mut x = -20.0f32;
        while x < 20.0 {
            let a = exp(x);
            let b = std::primitive::f32::exp(x);
            assert!(
                ((a - b) / b).abs() < 2e-6,
                "{x}: {a} vs {b}"
            );
            x += 0.01;
        }
    }

    #[test]
    fn tanh_matches_std() {
        let mut x = -12.0f32;
        while x < 12.0 {
            let a = tanh(x);
            let b = std::primitive::f32::tanh(x);
            assert!((a - b).abs() < 1e-6, "{x}: {a} vs {b}");
            x += 0.003;
        }
    }

    #[test]
    fn sample_is_inverse_cdf() {
        let logits = [0.0f32, 0.0, 0.0, 0.0];
        assert_eq!(sample(&logits, 1.0, 0.0), 0);
        assert_eq!(sample(&logits, 1.0, 0.3), 1);
        assert_eq!(sample(&logits, 1.0, 0.99), 3);
    }
}
