use std::fs;

use anyhow::{Context, Result};
use candle_core::{DType, Device, Tensor};
use candle_nn::{Module, VarBuilder, ops::softmax_last_dim};
use candle_transformers::models::resnet;
use hf_hub::HFClientSync;
use image::imageops::FilterType;

fn main() -> Result<()> {
    let device =
        Device::new_metal(0).or_else(|_| Device::cuda_if_available(0))?;
    let path = std::env::args().nth(1).context("usage: classify <image>")?;

    // Weights from the Hub, architecture from candle-transformers.
    let weights = HFClientSync::new()?
        .model("timm", "resnet18.gluon_in1k")
        .download_file()
        .filename("model.safetensors")
        .send()?;
    let bytes = fs::read(weights)?;
    let vb = VarBuilder::from_buffered_safetensors(bytes, DType::F32, &device)?;
    let model = resnet::resnet18(1000, vb)?;

    let logits = model.forward(&load_image(&path, &device)?)?;
    let probs = softmax_last_dim(&logits)?.squeeze(0)?.to_vec1::<f32>()?;

    let labels = include_str!("imagenet-classes.txt").lines();
    let mut ranked: Vec<_> = labels.zip(probs).collect();
    ranked.sort_by(|a, b| b.1.total_cmp(&a.1));
    for (label, p) in &ranked[..5] {
        println!("{:5.1} %  {label}", 100. * p);
    }
    Ok(())
}

/// A batch of one 224 × 224 RGB image, scaled like the training images.
fn load_image(path: &str, device: &Device) -> Result<Tensor> {
    let rgb = image::open(path)?
        .resize_to_fill(224, 224, FilterType::Triangle)
        .to_rgb8();
    let pixels = Tensor::from_vec(rgb.into_raw(), (224, 224, 3), device)?;
    let pixels = (pixels.permute((2, 0, 1))?.to_dtype(DType::F32)? / 255.)?;
    // ImageNet's per-channel mean and standard deviation.
    let mean = Tensor::new(&[0.485f32, 0.456, 0.406], device)?;
    let std = Tensor::new(&[0.229f32, 0.224, 0.225], device)?;
    let pixels = pixels
        .broadcast_sub(&mean.reshape((3, 1, 1))?)?
        .broadcast_div(&std.reshape((3, 1, 1))?)?;
    Ok(pixels.unsqueeze(0)?)
}
