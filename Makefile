protocols: client/message.ts server/message.ts
.PHONY: protocols

client/message.ts: protocol/protocol.scm
	cd protocol && ./generator.py ts > ../client/message.ts

server/message.ts: protocol/protocol.scm
	cd protocol && ./generator.py ts > ../server/message.ts
