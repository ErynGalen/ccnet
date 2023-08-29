var pico8_gpio = new Array(128);
let input_queue = [];


const STATE_WAITING = 1;
const STATE_IN_MSG = 2;
const STATE_OUT_MSG = 3;
const STATE_BUSY = 10;


onmessage = function (event) {
    let data = event.data;
    input_queue.push(data);
}

while (true) {
    if (pico8_gpio[0] == STATE_WAITING) {
        if (input_queue.length > 0) {
            // write message
            pico8_gpio[0] = STATE_BUSY;
            let message = input_queue[0];
            console.log("input message:", message);
            input_queue = input_queue.slice(1);
            let i = 0;
            for (; i < 127 && i < message.length; i++) {
                pico8_gpio[i + 1] = message.charCodeAt(i);
            }
            if (i < 127) {
                pico8_gpio[i + 1] = 0;
            }
            pico8_gpio[0] = STATE_IN_MSG;
        } else {
            console.log("input queue empty");
            pico8_gpio[1] = 0;
            pico8_gpio[0] = STATE_IN_MSG;
        }
    } else if (pico8_gpio[0] == STATE_OUT_MSG) {
        pico8_gpio[0] = 0;
        continue;
        // get message
        let message = "";
        let i = 1;
        while (i < 128) {
            let c = pico8_gpio[i];
            if (c == 0) {
                break;
            }
            message += String.fromCharCode(c);
            i += 1;
        }
        pico8_gpio[0] = 0;
        postMessage(message);
    }
}
