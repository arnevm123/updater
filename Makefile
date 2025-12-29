LOG_LEVEL?=info
BINARY_NAME=updater

.PHONY: all
all: help

.PHONY: build
## build: Build the application for the host machine's OS
build:
	@echo "Building the application for the host machine's OS"
	@# the flags "all=-N -l" allow you to attach to the running process with you debugger
	@go build -gcflags="all=-N -l" ${GO_LDFLAGS} -o ./bin/${BINARY_NAME}

.PHONY: run
## run: Run the application
run: build
	@echo "Running the application"
	@./bin/${BINARY_NAME} --log_level=${LOG_LEVEL}

.PHONY: clean
## clean: Clean the environment
clean:
	@echo "Cleaning the environment"
	@go clean
	@rm -rf bin/*
	@rm -f .lint.txt

.PHONY: lint
## lint: Lint the application and add the output to .lint.txt
lint:
	@echo "Linting the application"
	@echo "The output will also be in .lint.txt"
	@if command -v golangci-lint > /dev/null; then \
		golangci-lint run --config=./.golangci.yaml | tee .lint.txt ;\
	else \
		echo "golangci-lint not installed"; \
		echo "https://golangci-lint.run/usage/install/ for more info" ;\
	fi

.PHONY: format
## format: Run gofumpt and goimports-reviser on the whole application, excluding ./docs.
GOFILES := $(shell find . -type f -name '*.go' ! -path "./docs/*")
format:
	@echo "Formatting the application"
	@echo "Running go mod tidy"
	@go mod tidy
	@if command -v gofumpt > /dev/null; then \
		echo "Running gofumpt"; \
		echo "$(GOFILES)" | xargs gofumpt -extra -l -w ;\
	else \
		echo "gofumpt not installed."; \
		echo "Falling back to gofmt (might break pipeline)"; \
		echo "Or install manually: go install mvdan.cc/gofumpt@latest"; \
		echo "$(GOFILES)" | xargs gofmt -l -w ;\
	fi

	@if command -v goimports-reviser > /dev/null; then \
		echo "Running goimports-reviser"; \
		echo "$(GOFILES)" | xargs -n 1 goimports-reviser -rm-unused -project-name=unmatched.eu/lcr/lynxcontroller ;\
	else \
		echo "goimports-reviser not installed."; \
		echo "Please install: go install -v github.com/incu6us/goimports-reviser/v3@latest"; \
	fi

.PHONY: test
## test: Test the application
test:
	@echo "Testing the application"
	@go run gotest.tools/gotestsum@latest --format=pkgname-and-test-fails ./... -coverprofile=.coverage.out -covermode count

.PHONY: swagger
## swagger: Create swagger docs
swagger:
	@echo "Creating swagger docs"
	@swag init -g internal/http/api.go

.PHONY: coverage
## coverage: Generate test coverage report (.coverage.xml and .coverage.out)
coverage: test
	@echo "Generating test coverage report"
	@go tool cover -func .coverage.out
	@go run github.com/boumenot/gocover-cobertura@latest < .coverage.out > .coverage.xml; \

.PHONY: precommit
## precommit: Useful to run before committing, or if the pipeline fails. Runs format, lint and test coverage.
precommit: format coverage lint

.PHONY: help
## help: prints this help message
help:
	@echo "Usage:"
	@echo ""
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'
	@echo ""
	@echo "Advanced usage:"
	@echo ""
	@echo "Add versioning or releases:"
	@echo "make RELEASE=1 VERSION=1.2.3 build-linux"
	@echo "Changing log level (default: info):"
	@echo "make LOG_LEVEL=debug run"

%:
	@echo "Invalid target. Run 'make help' for more information."
