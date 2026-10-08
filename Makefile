# iron-air-modeling top-level Makefile
PYTHON ?= .venv/Scripts/python.exe
PIP    ?= .venv/Scripts/pip.exe
STRICTDOC ?= .venv/Scripts/strictdoc.exe
MATLAB ?= matlab

.PHONY: help clean build run test lint format \
	strictdoc-init strictdoc-generate strictdoc-validate strictdoc-export \
	strictdoc-serve strictdoc-tree strictdoc-help \
	venv mock-data init-sldd build-lib

help:
	@echo "Targets: clean build run test venv mock-data init-sldd build-lib"
	@echo "StrictDoc: strictdoc-init strictdoc-generate strictdoc-validate strictdoc-export strictdoc-serve strictdoc-tree strictdoc-help"

venv:
	python -m venv .venv
	$(PIP) install --upgrade pip strictdoc

clean:
	-rmdir /s /q docs 2>nul || true
	-$(MATLAB) -batch "if exist('lib_IronAir','file'), close_system('lib_IronAir',0); end" || true

build: init-sldd build-lib strictdoc-generate

run: build
	$(MATLAB) -batch "addpath(genpath('.')); lib_IronAir_init; open_system('models/demo_Plant_EnergyArb_24_100h')"

test:
	$(MATLAB) -batch "addpath(genpath('.')); lib_IronAir_init; results=runtests('tests'); assertSuccess(results)"

lint:
	$(STRICTDOC) manage lint ./requirements || true

format:
	@echo "No formatter configured for MATLAB/StrictDoc sources"

strictdoc-init:
	@echo "StrictDoc tree lives under requirements/ (already initialized)"

strictdoc-generate:
	$(STRICTDOC) export --formats html --output-dir .strictdoc_build requirements
	$(PYTHON) tools/publish_strictdoc_docs.py

strictdoc-validate:
	$(STRICTDOC) manage lint ./requirements

strictdoc-export: strictdoc-generate

strictdoc-serve:
	$(STRICTDOC) server requirements --output-path .strictdoc_build

strictdoc-tree:
	$(STRICTDOC) manage print-rel-paths ./requirements

strictdoc-help:
	$(STRICTDOC) --help

mock-data:
	$(MATLAB) -batch "addpath(genpath('.')); generate_mock_cell_curves"

init-sldd:
	$(MATLAB) -batch "addpath(genpath('.')); lib_IronAir_init"

build-lib:
	$(MATLAB) -batch "addpath(genpath('.')); lib_IronAir_init; build_lib_IronAir"
