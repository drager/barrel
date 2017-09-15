#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate postgres;
extern crate rocket;
extern crate rocket_contrib;
extern crate r2d2;
extern crate r2d2_postgres;
#[macro_use]
extern crate serde_json;
#[macro_use]
extern crate serde_derive;

pub mod connection;
pub mod api;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {}
}
