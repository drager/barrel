extern crate actix;
extern crate actix_web;
extern crate postgres;
extern crate r2d2;
extern crate r2d2_postgres;
#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate serde_json;
extern crate uuid;

pub mod api;
pub mod connection;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {}
}
