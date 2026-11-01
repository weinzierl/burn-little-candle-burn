//! Prints, as JSON, the MiniLM vectors and scores that the `similar` program
//! computes, at full precision, for the reference check in `check.py`.
//! Same model files, same device choice, same batching; `embed` is copied
//! unchanged from candle-batteries/3-similar/src/main.rs.

use std::fs;

use anyhow::{Error as E, Result};
use candle_core::{Device, IndexOp, Tensor};
use candle_nn::VarBuilder;
use candle_transformers::models::bert::{BertModel, DTYPE};
use hf_hub::HFClientSync;
use tokenizers::{PaddingParams, Tokenizer};

const DOCS: [&str; 5] = [
    "Two towers lean over the town.",
    "Tortellini are served till late.",
    "Porticoes keep the streets dry.",
    "The university dates from 1088.",
    "Fast trains run to Florence.",
];

/// The queries on the slides, in the order of the capture script.
const QUERIES: [&str; 4] = [
    "Where can I eat tonight?",
    "It is raining.",
    "How old is the city?",
    "How do I reset my router?",
];

fn main() -> Result<()> {
    let device =
        Device::new_metal(0).or_else(|_| Device::cuda_if_available(0))?;
    let repo =
        HFClientSync::new()?.model("sentence-transformers", "all-MiniLM-L6-v2");
    let file = |name: &str| repo.download_file().filename(name).send();
    let config = serde_json::from_slice(&fs::read(file("config.json")?)?)?;
    let bytes = fs::read(file("model.safetensors")?)?;
    let vb = VarBuilder::from_buffered_safetensors(bytes, DTYPE, &device)?;
    let model = BertModel::load(vb, &config)?;
    let mut tokenizer =
        Tokenizer::from_file(file("tokenizer.json")?).map_err(E::msg)?;
    tokenizer.with_padding(Some(PaddingParams::default()));

    let mut runs = Vec::new();
    for query in QUERIES {
        // One batch per query, exactly as `similar` builds it.
        let texts: Vec<&str> = [query].into_iter().chain(DOCS).collect();
        let vectors = embed(&model, &tokenizer, texts.clone(), &device)?;
        let scores = vectors.i(1..)?.matmul(&vectors.i(0)?.unsqueeze(1)?)?;
        runs.push(serde_json::json!({
            "texts": texts,
            "vectors": vectors.to_vec2::<f32>()?,
            "scores": scores.flatten_all()?.to_vec1::<f32>()?,
        }));
    }
    println!("{}", serde_json::Value::Array(runs));
    Ok(())
}

/// One vector of length 1 per text, 384 numbers each.
fn embed(
    model: &BertModel,
    tokenizer: &Tokenizer,
    texts: Vec<&str>,
    device: &Device,
) -> Result<Tensor> {
    let batch = tokenizer.encode_batch(texts, true).map_err(E::msg)?;
    let ids: Vec<_> = batch.iter().map(|e| e.get_ids().to_vec()).collect();
    let mask: Vec<_> =
        batch.iter().map(|e| e.get_attention_mask().to_vec()).collect();
    let (ids, mask) = (Tensor::new(ids, device)?, Tensor::new(mask, device)?);
    let hidden = model.forward(&ids, &ids.zeros_like()?, Some(&mask))?;

    // Average over the real tokens; padding must not count.
    let mask = mask.to_dtype(DTYPE)?.unsqueeze(2)?;
    let sum = hidden.broadcast_mul(&mask)?.sum(1)?;
    let mean = sum.broadcast_div(&mask.sum(1)?)?;
    Ok(mean.broadcast_div(&mean.sqr()?.sum_keepdim(1)?.sqrt()?)?)
}
