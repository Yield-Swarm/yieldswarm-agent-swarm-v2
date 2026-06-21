//! Mandelbrot particle accelerator — 3 solenoid rings + 14-elevator synchrotron.

mod mandelbrot;
mod solenoid;

pub use mandelbrot::MandelbrotAccelerator;
pub use solenoid::{ParticleFrame, SolenoidPhase, SolenoidRing};
