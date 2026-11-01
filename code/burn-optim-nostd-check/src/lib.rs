#![no_std]
// Use the optimizer types, so the crate is really compiled and linked into this library.
pub use burn_optim::{AdamConfig, GradientsParams, Optimizer};
