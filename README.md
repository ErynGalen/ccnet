# CCnet
Network protocol for Celeste Classic carts.

## The protocol
See [protocol.scm](protocol/protocol.scm) for more informations.

## Using it
First, the protocol implementation files must be generated.
To do so, run `make protocols`.

Then, in both the `client` and `server` directory:
* install dependencies by running `npm install`
* compile Typescript files by running `npx tsc`

To run the server, run `npm run server` in the `server` directory.

To run the client, first run a web server in the `client` directory. You can for example run `python -m http.server` in the `client` directory. Then you can open in a browser the page exposed by the webserver.
