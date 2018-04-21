#![feature(plugin)]
#![plugin(rocket_codegen)]
#![feature(const_atomic_bool_new)]

extern crate postgres;
extern crate r2d2;
extern crate r2d2_postgres;
extern crate rocket;
extern crate rocket_contrib;
#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate serde_json;
extern crate uuid;

pub mod connection;
pub mod api;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {}
}
