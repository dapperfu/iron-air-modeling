VENV := venv_iron-air-modeling
PYTHON := $(VENV)/bin/python
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
RUFF := $(VENV)/bin/ruff
MYPY := $(VENV)/bin/mypy
COVERAGE := $(VENV)/bin/coverage
STRICTDOC := $(VENV)/bin/strictdoc
PRECOMMIT := $(VENV)/bin/pre-commit
PIP_AUDIT := $(VENV)/bin/pip-audit
STRICTDOC_STAGING := .strictdoc_build
STRICTDOC_PAGES := docs

.PHONY: help venv install test test-phase-1 test-phase-2 test-coverage lint typecheck \
	strictdoc-validate strictdoc-generate strictdoc-export strictdoc-serve strictdoc-tree \
	strictdoc-help strictdoc-init pre-commit-install pre-commit security

help:
	@echo "IRONAIR targets: venv install test lint typecheck strictdoc-generate"

venv:
	python3 -m venv $(VENV)

install: venv
	$(PIP) install -U pip
	$(PIP) install -e ".[dev,notebooks]"

test:
	$(PYTEST)

test-phase-1:
	$(PYTEST) -m phase1

test-phase-2:
	$(PYTEST) -m "phase1 or phase2"

test-coverage:
	$(COVERAGE) run -m pytest
	$(COVERAGE) report --fail-under=80
	$(COVERAGE) html
	@echo "Coverage report generated in htmlcov/"

lint:
	$(RUFF) check src tests
	$(RUFF) format --check src tests

typecheck:
	$(MYPY) src/ironair

strictdoc-init:
	@echo "StrictDoc tree already lives under reqs/"

strictdoc-validate:
	$(STRICTDOC) export reqs --formats html --output-dir $(STRICTDOC_STAGING) --project-title iron-air-modeling

strictdoc-generate: strictdoc-validate
	rm -rf $(STRICTDOC_PAGES)
	mkdir -p $(STRICTDOC_PAGES)
	cp -a $(STRICTDOC_STAGING)/html/. $(STRICTDOC_PAGES)/
	touch $(STRICTDOC_PAGES)/.nojekyll

strictdoc-export: strictdoc-generate

strictdoc-serve:
	$(STRICTDOC) server reqs --port 5111

strictdoc-tree:
	$(STRICTDOC) dump-grammar --help >/dev/null
	@find reqs -name '*.sdoc' | sort

strictdoc-help:
	$(STRICTDOC) --help

pre-commit-install:
	$(PRECOMMIT) install

pre-commit:
	$(PRECOMMIT) run --all-files

security:
	$(PIP_AUDIT)
