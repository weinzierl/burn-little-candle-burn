//! The character language model in Burn.
use burn::module::Module;
use burn::nn::{
    Embedding, EmbeddingConfig, Linear, LinearConfig,
};
use burn::tensor::{Device, Int, Tensor};
use tiny::charlm::{CTX, EMB, HID, VOCAB};

// ANCHOR: model
// ANCHOR: struct
#[derive(Module, Debug)]
pub struct CharLm {
    emb: Embedding,
    hidden: Linear,
    out: Linear,
}
// ANCHOR_END: struct

impl CharLm {
    pub fn new(dev: &Device) -> Self {
        Self {
            emb: EmbeddingConfig::new(VOCAB, EMB).init(dev),
            hidden: LinearConfig::new(CTX * EMB, HID).init(dev),
            out: LinearConfig::new(HID, VOCAB).init(dev),
        }
    }

    /// [batch, CTX] char ids -> [batch, VOCAB] logits
    // ANCHOR: forward
    pub fn forward(&self, ctx: Tensor<2, Int>) -> Tensor<2> {
        let [batch, _] = ctx.dims();
        let x = self.emb.forward(ctx); // [batch, CTX, EMB]
        let x = x.reshape([batch, CTX * EMB]);
        let x = self.hidden.forward(x).tanh();
        self.out.forward(x)
    }
    // ANCHOR_END: forward
}
// ANCHOR_END: model
