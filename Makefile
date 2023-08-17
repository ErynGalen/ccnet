protocols: examples/webclient/message.ts server/message.ts
.PHONY: protocols

examples/webclient/message.ts: protocol/protocol.scm
	cd protocol && ./generator.py ts > ../examples/webclient/message.ts

server/message.ts: protocol/protocol.scm
	cd protocol && ./generator.py ts > ../server/message.ts
