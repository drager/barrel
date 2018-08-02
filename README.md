# Barrel

Manage your databases, from PostgreSQL to sqlite.

Barrel is a web application that let's you manage your databases.
Connect to multiple databases at the same time, switch between them and
show all tables, display the data in the tables etc.

## UI
Barrel has a web client written in Elm as it's default ui.

## Server
Barrel comes with a server, a web api that's written in Rust.
It handles all the active sessions, connections and such. It exposes
this via an API, which means that you can bring your own client that uses this API
if the default ui client isn't what you want to use.

## Installation
In order to install the barrel you will need to have [Rust](https://www.rust-lang.org/en-US/install.html)
and [Elm](https://guide.elm-lang.org/install.html) installed.

First `cd` into the `server` directory and run `cargo run` in order to install and run
the server.

Then `cd` into the `client` directory and run `yarn` and after that run `bower i` to install
all the needed dependencies. Then run `yarn start` to start the application.

