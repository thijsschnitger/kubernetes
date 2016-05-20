# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Old-skool build tools.
#
# Targets (see each target for more information):
#   all: Build code.
#   check: Run tests.
#   test: Run tests.
#   clean: Clean up.

OUT_DIR = _output
BIN_DIR := $(OUT_DIR)/bin
PRJ_SRC_PATH := k8s.io/kubernetes
GENERATED_FILE_PREFIX := zz_generated.

KUBE_GOFLAGS = $(GOFLAGS)
export KUBE_GOFLAGS

KUBE_GOLDFLAGS = $(GOLDFLAGS)
export KUBE_GOLDFLAGS

# Build code.
#
# Args:
#   WHAT: Directory names to build.  If any of these directories has a 'main'
#     package, the build will produce executable files under $(OUT_DIR)/go/bin.
#     If not specified, "everything" will be built.
#   GOFLAGS: Extra flags to pass to 'go' when building.
#   GOLDFLAGS: Extra linking flags to pass to 'go' when building.
#
# Example:
#   make
#   make all
#   make all WHAT=cmd/kubelet GOFLAGS=-v
all: gen_deepcopy build
.PHONY: all

# Build ginkgo
#
# Example:
# make ginkgo
ginkgo:
	hack/make-rules/build.sh vendor/github.com/onsi/ginkgo/ginkgo
.PHONY: ginkgo

# This is a helper to break circular dependencies.
build:
	@hack/make-rules/build.sh $(WHAT)
.PHONY: build

# Runs all the presubmission verifications.
#
# Args:
#   BRANCH: Branch to be passed to hack/verify-godeps.sh script.
#
# Example:
#   make verify
#   make verify BRANCH=branch_x
verify:
	@KUBE_VERIFY_GIT_BRANCH=$(BRANCH) hack/make-rules/verify.sh -v
.PHONY: verify

# Build and run tests.
#
# Args:
#   WHAT: Directory names to test.  All *_test.go files under these
#     directories will be run.  If not specified, "everything" will be tested.
#   TESTS: Same as WHAT.
#   GOFLAGS: Extra flags to pass to 'go' when building.
#   GOLDFLAGS: Extra linking flags to pass to 'go' when building.
#
# Example:
#   make check
#   make test
#   make check WHAT=pkg/kubelet GOFLAGS=-v
check test: gen_deepcopy
	@hack/make-rules/test.sh $(WHAT) $(TESTS)
.PHONY: check test

# Build and run integration tests.
#
# Example:
#   make test-integration
test-integration: gen_deepcopy
	@hack/make-rules/test-integration.sh
.PHONY: test-integration

# Build and run end-to-end tests.
#
# Example:
#   make test-e2e
test-e2e: ginkgo gen_deepcopy
	@go run hack/e2e.go -v --build --up --test --down
.PHONY: test-e2e

# Build and run node end-to-end tests.
#
# Args:
#  FOCUS: regexp that matches the tests to be run.  Defaults to "".
#  SKIP: regexp that matches the tests that needs to be skipped.  Defaults to "".
#  RUN_UNTIL_FAILURE: Ff true, pass --untilItFails to ginkgo so tests are run repeatedly until they fail.  Defaults to false.
#  REMOTE: If true, run the tests on a remote host instance on GCE.  Defaults to false.
#  IMAGES: for REMOTE=true only.  Comma delimited list of images for creating remote hosts to run tests against.  Defaults to "e2e-node-containervm-v20160321-image".
#  LIST_IMAGES: If true, don't run tests.  Just output the list of available images for testing.  Defaults to false.
#  HOSTS: for REMOTE=true only.  Comma delimited list of running gce hosts to run tests against.  Defaults to "".
#  DELETE_INSTANCES: for REMOTE=true only.  Delete any instances created as part of this test run.  Defaults to false.
#  ARTIFACTS: for REMOTE=true only.  Local directory to scp test artifacts into from the remote hosts.  Defaults to ""/tmp/_artifacts".
#  REPORT: for REMOTE=false only.  Local directory to write juntil xml results to.  Defaults to "/tmp/".
#  CLEANUP: for REMOTE=true only.  If false, do not stop processes or delete test files on remote hosts.  Defaults to true.
#  IMAGE_PROJECT: for REMOTE=true only.  Project containing images provided to IMAGES.  Defaults to "kubernetes-node-e2e-images".
#  INSTANCE_PREFIX: for REMOTE=true only.  Instances created from images will have the name "${INSTANCE_PREFIX}-${IMAGE_NAME}".  Defaults to "test"/
#
# Example:
#   make test-e2e-node FOCUS=kubelet SKIP=container
#   make test-e2e-node REMOTE=true DELETE_INSTANCES=true
# Build and run tests.
test-e2e-node: ginkgo gen_deepcopy
	@hack/make-rules/test-e2e-node.sh
.PHONY: test-e2e-node

# Build and run cmdline tests.
#
# Example:
#   make test-cmd
test-cmd:
	@hack/make-rules/test-cmd.sh
.PHONY: test-cmd

# Remove all build artifacts.
#
# Example:
#   make clean
clean:
	build/make-clean.sh
	rm -rf $(OUT_DIR)
	find . -type f -name $(GENERATED_FILE_PREFIX)\* | xargs rm -f
	rm -rf Godeps/_workspace # Just until we are sure it is gone
.PHONY: clean

# Run 'go vet'.
#
# Args:
#   WHAT: Directory names to vet.  All *.go files under these
#     directories will be vetted.  If not specified, "everything" will be
#     vetted.
#
# Example:
#   make vet
#   make vet WHAT=pkg/kubelet
vet:
	@hack/make-rules/vet.sh $(WHAT)
.PHONY: vet

# Build a release
#
# Example:
#   make release
release: gen_deepcopy
	@build/release.sh
.PHONY: release

# Build a release, but skip tests
#
# Example:
#   make release-skip-tests
release-skip-tests quick-release: gen_deepcopy
	@KUBE_RELEASE_RUN_TESTS=n KUBE_FASTBUILD=true build/release.sh
.PHONY: release-skip-tests quick-release

#
# Code-generation logic.
#

# Generate a list of all files that have a `+k8s:` comment-tag.  This will be
# used to derive lists of files/dirs for generation tools.
ALL_K8S_TAG_FILES := $(shell                               \
    find .                                                 \
        -not \(                                            \
            \(                                             \
                -path ./vendor -o                          \
                -path ./$(OUT_DIR) -o                      \
                -path ./.git                               \
            \) -prune                                      \
        \)                                                 \
        -type f -name \*.go | xargs grep -l '^// \?+k8s:'  \
    )

#
# Deep-copy generation
#
# Any package that wants deep-copy functions generated must include a
# comment-tag in column 0 of one file of the form:
#     // +k8s:deepcopy-gen=<VALUE>
#
# The <VALUE> may be one of:
#     generate: generate deep-copy functions into the package
#     register: generate deep-copy functions and register them with a
#               scheme

# Find all the directories that request deep-copy generation.
DEEP_COPY_DIRS := $(shell \
    grep -l '+k8s:deepcopy-gen=' $(ALL_K8S_TAG_FILES)  \
        | xargs dirname                                \
        | sort -u                                      \
)

# The result file, in each pkg, of deep-copy generation.
DEEP_COPY_BASENAME := $(GENERATED_FILE_PREFIX)deep_copy
DEEP_COPY_FILENAME := $(DEEP_COPY_BASENAME).go

# Unfortunately there's not a good way to use Go's build tools to check
# if a binary needs to be rebuilt.  We just have to try it.
gen_deepcopy:
	@$(MAKE) -s build WHAT=cmd/libs/go2idl/deepcopy-gen
	@$(MAKE) -s $(addsuffix /$(DEEP_COPY_FILENAME), $(DEEP_COPY_DIRS))

# For each dir in DEEP_COPY_DIRS, this generates a statement of the form:
#     path/to/dir/$(DEEP_COPY_FILENAME): <all files in dir, except generated ones>
#
# Note that this is a deps-only statement, not a full rule (see below).
# This has to be done in a distinct step because wildcards don't seem to work
# in static pattern rules.
#
# The '$(eval)' is needed because this has a different RHS for each LHS, and
# would otherwise produce results that make can't parse.
$(foreach dir, $(DEEP_COPY_DIRS), \
    $(eval $(dir)/$(DEEP_COPY_FILENAME): $(shell ls $(dir)/*.go | grep -v $(GENERATED_FILE_PREFIX))))

# For each dir in DEEP_COPY_DIRS, handle deep-copy generation.
# This has to be done in two steps because wildcards don't seem to work in
# static pattern rules.
$(addsuffix /$(DEEP_COPY_FILENAME), $(DEEP_COPY_DIRS)):
	$(BIN_DIR)/deepcopy-gen \
	    -i $(PRJ_SRC_PATH)/$$(dirname $@) \
	    --bounding-dirs $(PRJ_SRC_PATH) \
	    -O $(DEEP_COPY_BASENAME)
