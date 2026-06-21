//! YSLR v1 parser using nom.

use nom::{
    bytes::complete::{tag, take_until},
    character::complete::{char, multispace0},
    combinator::opt,
    sequence::{delimited, preceded},
    IResult,
};
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct YslrDocument {
    pub lane: String,
    pub route: String,
    pub payload: String,
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum YslrError {
    #[error("parse error: {0}")]
    Parse(String),
}

pub fn parse_yslr(input: &str) -> Result<YslrDocument, YslrError> {
    match yslr_document(input.trim()) {
        Ok((_, doc)) => Ok(doc),
        Err(e) => Err(YslrError::Parse(e.to_string())),
    }
}

fn yslr_document(input: &str) -> IResult<&str, YslrDocument> {
    let (input, _) = tag("YSLR")(input)?;
    let (input, _) = multispace0(input)?;
    let (input, lane) = preceded(tag("lane="), take_until(" "))(input)?;
    let (input, _) = multispace0(input)?;
    let (input, route) = preceded(tag("route="), take_until(" "))(input)?;
    let (input, _) = multispace0(input)?;
    let (input, payload) = preceded(
        tag("payload="),
        opt(delimited(char('{'), take_until("}"), char('}'))),
    )(input)?;

    Ok((
        input,
        YslrDocument {
            lane: lane.to_string(),
            route: route.to_string(),
            payload: payload.unwrap_or_default().to_string(),
        },
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_minimal_yslr() {
        let doc = parse_yslr("YSLR lane=elevator-7 route=helix payload={\"op\":\"ping\"}").unwrap();
        assert_eq!(doc.lane, "elevator-7");
        assert_eq!(doc.route, "helix");
        assert!(doc.payload.contains("ping"));
    }
}
