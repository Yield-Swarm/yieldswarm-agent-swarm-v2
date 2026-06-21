//! YSLR language parser — Prompt 37.
//!
//! Grammar (v1):
//! `YSLR lane=<id> route=<council> payload=<json>`

mod yslr;

pub use yslr::{parse_yslr, YslrDocument, YslrError};
