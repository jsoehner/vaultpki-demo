import pytest
from hamming_distance import hamming_distance

def test_hamming_distance_equal_strings():
    assert hamming_distance("abcdef", "abcdef") == 0

def test_hamming_distance_some_differences():
    assert hamming_distance("karolin", "kathrin") == 3

def test_hamming_distance_all_differences():
    assert hamming_distance("aaaaa", "bbbbb") == 5

def test_hamming_distance_unequal_lengths():
    with pytest.raises(ValueError, match="Strings must be of equal length to calculate Hamming distance."):
        hamming_distance("short", "longerstring")

def test_hamming_distance_empty_strings():
    assert hamming_distance("", "") == 0

@pytest.mark.parametrize("s1, s2, expected", [
    ("abc", "abd", 1),
    ("123", "124", 1),
    ("!@#", "!#%", 2),
    (" ", " ", 0),
    ("a", "b", 1),
])
def test_hamming_distance_parametrized(s1, s2, expected):
    assert hamming_distance(s1, s2) == expected
