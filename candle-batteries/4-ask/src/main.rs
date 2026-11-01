use std::{
    fs,
    io::{self, Write},
    time::Instant,
};

use anyhow::{Context, Error as E, Result};
use candle_core::{Device, Tensor, quantized::gguf_file};
use candle_transformers::generation::{LogitsProcessor, Sampling};
use candle_transformers::models::quantized_llama::ModelWeights;
use hf_hub::HFClientSync;
use tokenizers::Tokenizer;

fn main() -> Result<()> {
    let device =
        Device::new_metal(0).or_else(|_| Device::cuda_if_available(0))?;
    let question = std::env::args().nth(1);
    let question = question
        .as_deref()
        .unwrap_or("What is a tensor? Answer in one sentence.");
    let (mut model, tokenizer) = load(&device)?;

    // The chat template is plain text the model saw in fine-tuning.
    let prompt = format!(
        "<|im_start|>user\n{question}<|im_end|>\n<|im_start|>assistant\n"
    );
    let encoding = tokenizer.encode(prompt, true).map_err(E::msg)?;
    let mut tokens = encoding.get_ids().to_vec();
    let end = tokenizer.token_to_id("<|im_end|>").context("no end token")?;
    let sampling = Sampling::TopP { p: 0.9, temperature: 0.5 };
    let mut sampler = LogitsProcessor::from_sampling(42, sampling);
    let mut text = tokenizer.decode_stream(true);

    // The prompt goes in once, then one token per step: the KV cache
    // inside the model remembers everything before `pos`.
    let (start, prompt_len, mut pos) = (Instant::now(), tokens.len(), 0);
    for _ in 0..256 {
        let input = Tensor::new(&tokens[pos..], &device)?.unsqueeze(0)?;
        let logits = model.forward(&input, pos)?.squeeze(0)?;
        pos = tokens.len();
        let next = sampler.sample(&logits)?;
        if next == end {
            break;
        }
        tokens.push(next);
        if let Some(piece) = text.step(next).map_err(E::msg)? {
            print!("{piece}");
            io::stdout().flush()?;
        }
    }
    let n = tokens.len() - prompt_len;
    let rate = n as f64 / start.elapsed().as_secs_f64();
    eprintln!("\n\n{n} tokens, {rate:.1} tokens/s");
    Ok(())
}

/// An 8-bit GGUF file from the llama.cpp world, plus the original tokenizer.
fn load(device: &Device) -> Result<(ModelWeights, Tokenizer)> {
    let hub = HFClientSync::new()?;
    let gguf = hub
        .model("HuggingFaceTB", "SmolLM2-360M-Instruct-GGUF")
        .download_file()
        .filename("smollm2-360m-instruct-q8_0.gguf")
        .send()?;
    let tokenizer = hub
        .model("HuggingFaceTB", "SmolLM2-360M-Instruct")
        .download_file()
        .filename("tokenizer.json")
        .send()?;
    let mut file = fs::File::open(gguf)?;
    let content = gguf_file::Content::read(&mut file)?;
    let model = ModelWeights::from_gguf(content, &mut file, device)?;
    Ok((model, Tokenizer::from_file(tokenizer).map_err(E::msg)?))
}
