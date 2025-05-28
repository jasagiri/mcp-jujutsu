## Coverage runner for all tests
## Run with: nim c --coverage:on --coverageDir:../coverage -r coverage_runner.nim

import test_runner

# The test_runner already imports and runs all tests
# This file is just for running with coverage enabled