# ADR-004: Hamming Distance Python Utility

## Status
Accepted

## Date
2026-07-11

## Context
There is a need to calculate the Hamming distance (the number of differing positions between two equal-length sequences) for various validation tasks within the workspace.

## Decision
Provide a standalone, fully documented, and type-annotated Python implementation of `hamming_distance` in `hamming_distance.py`. 

The function:
1. Validates that the input strings are of equal length, throwing a clear `ValueError` if not.
2. Loops through characters and increments a distance counter whenever they differ.
3. Provides an `if __name__ == "__main__"` block with usage examples demonstrating success, identical string match, and error handling cases.

## Consequences
- A simple, tested, and reliable implementation of the Hamming distance algorithm is available in the workspace.
