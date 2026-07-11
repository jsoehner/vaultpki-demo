def hamming_distance(s1: str, s2: str) -> int:
    """
    Calculates the Hamming distance between two strings of equal length.

    The Hamming distance is the number of positions at which the corresponding 
    symbols are different. If the strings are of unequal lengths, a ValueError 
    is raised as hamming distance is only defined for equal-length sequences.

    Args:
        s1 (str): The first string.
        s2 (str): The second string.

    Returns:
        int: The Hamming distance.

    Raises:
        ValueError: If the length of s1 and s2 are not equal.
    """
    if len(s1) != len(s2):
        raise ValueError("Strings must be of equal length to calculate Hamming distance.")

    distance = 0
    for i in range(len(s1)):
        if s1[i] != s2[i]:
            distance += 1
    return distance

# --- Example Usage ---
if __name__ == "__main__":
    # Case 1: Equal lengths, some differences
    str_a = "karolin"
    str_b = "kathrin"
    try:
        distance1 = hamming_distance(str_a, str_b)
        print(f"The Hamming distance between '{str_a}' and '{str_b}' is: {distance1}")
    except ValueError as e:
        print(f"Error calculating distance 1: {e}")

    # Case 2: Identical strings (Distance should be 0)
    str_c = "abcdef"
    str_d = "abcdef"
    try:
        distance2 = hamming_distance(str_c, str_d)
        print(f"The Hamming distance between '{str_c}' and '{str_d}' is: {distance2}")
    except ValueError as e:
        print(f"Error calculating distance 2: {e}")

    # Case 3: Unequal length strings (Should raise ValueError)
    str_e = "short"
    str_f = "longerstring"
    try:
        distance3 = hamming_distance(str_e, str_f)
        print(f"The Hamming distance between '{str_e}' and '{str_f}' is: {distance3}")
    except ValueError as e:
        print(f"\nSuccessfully caught expected error for unequal lengths:")
        print(f"  {e.__class__.__name__}: {e}")