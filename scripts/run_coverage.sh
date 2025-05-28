#!/bin/bash
# Run tests with coverage analysis

set -e

echo "Running tests with coverage analysis..."

# Create coverage directory if it doesn't exist
mkdir -p coverage

# Clean previous coverage data
rm -f coverage/*.txt

# Compile and run tests with coverage
cd tests
nim c --coverage:on --coverageDir:../coverage --path:../src -r coverage_runner.nim

# Generate coverage report
cd ../coverage
echo ""
echo "Coverage Report:"
echo "================"

# Combine all coverage files
for file in *.txt; do
    if [ -f "$file" ]; then
        echo "Processing $file..."
    fi
done

# Calculate total coverage
total_lines=0
covered_lines=0

for file in *.txt; do
    if [ -f "$file" ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+:[0-9]+ ]]; then
                total_lines=$((total_lines + 1))
                count=$(echo "$line" | cut -d':' -f2)
                if [ "$count" -gt 0 ]; then
                    covered_lines=$((covered_lines + 1))
                fi
            fi
        done < "$file"
    fi
done

if [ $total_lines -gt 0 ]; then
    coverage_percent=$(awk "BEGIN {printf \"%.2f\", $covered_lines * 100.0 / $total_lines}")
    echo ""
    echo "Total lines: $total_lines"
    echo "Covered lines: $covered_lines"
    echo "Coverage: ${coverage_percent}%"
else
    echo "No coverage data found"
fi

echo ""
echo "Detailed coverage files available in coverage/"