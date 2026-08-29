BUILD_DIR ?= build
CMAKE_COMMAND ?= cmake
RAPIDGZIP_CC ?= clang-19
RAPIDGZIP_CXX ?= clang++-19
DIST_VERSION ?=

.PHONY: all test package clean

all:
	CC="$(RAPIDGZIP_CC)" CXX="$(RAPIDGZIP_CXX)" \
		"$(CMAKE_COMMAND)" -S . -B "$(BUILD_DIR)" \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo
	"$(CMAKE_COMMAND)" --build "$(BUILD_DIR)" --parallel

test: all
	ctest --test-dir "$(BUILD_DIR)" --output-on-failure

package: all
	BUILD_DIR="$(BUILD_DIR)" DIST_VERSION="$(DIST_VERSION)" \
		sh scripts/package.sh

clean:
	"$(CMAKE_COMMAND)" -E remove_directory "$(BUILD_DIR)"
