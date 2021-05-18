GOVERSION := $(shell go version | cut -d ' ' -f 3 | cut -d '.' -f 2)

.PHONY: check fmt lint test test-race vet test-cover-html help
.DEFAULT_GOAL := help

check: test-race fmt vet lint ## Run tests and linters

build:
	go build -o proxy && ./proxy

test: ## Run tests
	go test ./... -race

test-race: ## Run tests with race detector
	go test -race ./...

fmt: ## Run gofmt linter
ifeq "$(GOVERSION)" "12"
	@for d in `go list` ; do \
		if [ "`gofmt -l -s $$GOPATH/src/$$d | tee /dev/stderr`" ]; then \
			echo "^ improperly formatted go files" && echo && exit 1; \
		fi \
	done
endif

lint: ## Run golint linter
	@for d in `go list` ; do \
		if [ "`golint $$d | tee /dev/stderr`" ]; then \
			echo "^ golint errors!" && echo && exit 1; \
		fi \
	done

vet: ## Run go vet linter
	@if [ "`go vet | tee /dev/stderr`" ]; then \
		echo "^ go vet errors!" && echo && exit 1; \
	fi

test-cover-html: ## Generate test coverage report
	go test -coverprofile=coverage.out -covermode=count
	go tool cover -func=coverage.out

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

cert: ## generate tls self signed cert
	@echo "> cleaning old certs"
	mkdir -p ./certs
	cd ./certs; rm -f ./ca-key.pem ./ca-cert.pem ./ca-cert.srl ./service-key.pem ./service-cert.pem
	@echo "> Generate CA's private key and self-signed certificate"
	cd ./certs; openssl req -x509 -newkey rsa:4096 -days 365 -nodes -keyout ca-key.pem -out ca-cert.pem -subj "/C=IN/ST=KA/L=Bangalore/O=Kush/OU=KushTech/CN=*.example.io/emailAddress=kush@example.com"
	@echo "> Generate server's private key and certificate signing request (CSR)"
	cd ./certs; openssl genrsa -out service-key.pem 4096
	cd ./certs; openssl req -new -key service-key.pem -out service.csr -config ./certificate.conf
	@echo "Use CA's private key to sign web server's CSR and get back the signed certificate"
	cd ./certs; openssl x509 -req -in service.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial \
		-out service-cert.pem -days 365 -sha256 -extfile ./certificate.conf -extensions req_ext
	cd ./certs; rm service.csr
	cd ./certs; openssl x509 -in service-cert.pem -noout -text
	@echo "> certs generated successfully"