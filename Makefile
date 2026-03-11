build:
	go build -o bin/summitsplit ./cmd/server

run:
	go run ./cmd/server

dev:
	which air > /dev/null && air || go run ./cmd/server

test:
	go test ./...

clean:
	rm -rf bin/

# Deploy to shared server — set SERVER=user@host before running
SERVER ?= user@your-server.com
DEPLOY_DIR = /opt/summitsplit

deploy: build
	ssh $(SERVER) "mkdir -p $(DEPLOY_DIR)/web"
	scp bin/summitsplit $(SERVER):$(DEPLOY_DIR)/summitsplit
	scp -r web/templates web/static $(SERVER):$(DEPLOY_DIR)/web/
	ssh $(SERVER) "sudo systemctl restart summitsplit"

.PHONY: build run dev test clean deploy
