extern crate postgres;
extern crate rocket;
extern crate serde;
extern crate serde_json;
#[macro_use]
extern crate serde_derive;

pub mod connection;

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {}
}
