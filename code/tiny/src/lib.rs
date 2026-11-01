//! `tiny`: framework-free inference for the two talk models.
//!
//! `no_std`, no allocator, no dependencies, no `unsafe`.
//! Weights are read in place from a safetensors byte slice,
//! so on a microcontroller they can stay in flash.
#![no_std]
#![forbid(unsafe_code)]

pub mod charlm;
pub mod rng;
pub mod sine;
pub mod st;
pub mod vocab;
