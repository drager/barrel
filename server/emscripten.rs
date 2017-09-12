#![feature(link_args)]

extern crate postgres;
extern crate stdweb;
extern crate database_manager;

use std::os::raw::{c_char, c_int, c_void};
use std::cell::RefCell;
use std::ptr::null_mut;
use std::ffi::CString;
use std::slice;
use std::str;
use database_manager::connection::pg_connection::PgDatabaseConnection;
use database_manager::connection::DatabaseConnection;


// #[cfg_attr(target_arch="asmjs",
//     link_args="\
//         -s INVOKE_RUN=0
// ")]
// extern "C" {}

#[no_mangle]
pub extern "C" fn get_name(name: *const u8, len: usize) -> *mut c_char {
    let name = unsafe { slice::from_raw_parts(name, len) };
    CString::new(format!("Hello {} !", str::from_utf8(name).unwrap()).as_bytes())
        .unwrap()
        .into_raw()
}

#[no_mangle]
pub extern "C" fn connect_to_postgresql(raw_connection_string: *const u8,
                                        len: usize)
                                        -> *mut c_char {
    let raw_connection_string = unsafe { slice::from_raw_parts(raw_connection_string, len) };
    let connection_string = CString::new(str::from_utf8(raw_connection_string).unwrap())
        .unwrap()
        .into_raw();

    let connection =
        PgDatabaseConnection::connect(str::from_utf8(raw_connection_string).unwrap().to_owned());

    println!("connection: {:?}", connection);
    connection.unwrap();
    // Ok(connection.unwrap())
    connection_string
}


fn main() {
    stdweb::initialize();
    println!("Hello from Rust");

    // connect_to_postgresql("postgres://postgres@localhost:5433".as_ptr(), 34);

    stdweb::event_loop();
}
