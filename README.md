# CCnet
Network protocol for Celeste Classic carts.

## The protocol
See [protocol.scm](protocol/protocol.scm) for more informations.

## Implementing the protocol in carts

See [PICO-8](pico8/README.md) for more information.

There you will also find informations on how to run carts.

## Using it
First, the protocol implementation files must be generated.
To do so, run `make protocols`.

Then, in the `server` directory:
* install dependencies by running `npm install`
* compile Typescript files by running `npx tsc`
* run `npm run server`

## Acknowledgements
* This project is inspired by [classicnet](https://github.com/EvergreenGames/EvergreenGames.github.io/tree/master/classicnet).
* Special thanks to [Ruby](https://github.com/EvergreenGames) and [Pablito](https://github.com/probablypablito) for the PICO-8 code, the inspiration and the rest of `classicnet`.
