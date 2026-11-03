"""Statistics for the move layer: agreement, association and hit rates.

Spectra change add-paragraph-moves. Pure functions over lists of labels, so the
expected values can be worked out by hand in the tests.
"""
from __future__ import annotations

import math
from collections import Counter
from collections.abc import Hashable, Sequence


def cramers_v(pairs: Sequence[tuple[Hashable, Hashable]]) -> float | None:
    """Cramér's V of two labellings; None when either has fewer than two categories."""
    n = len(pairs)
    rows, cols = Counter(a for a, _ in pairs), Counter(b for _, b in pairs)
    smaller = min(len(rows), len(cols)) - 1
    if n == 0 or smaller < 1:
        return None
    cells = Counter(pairs)
    chi2 = 0.0
    for a, row in rows.items():
        for b, col in cols.items():
            expected = row * col / n
            chi2 += (cells[(a, b)] - expected) ** 2 / expected
    return round(math.sqrt(chi2 / (n * smaller)), 4)


def agreement(pairs: Sequence[tuple[Hashable, Hashable]]) -> dict:
    """Raw agreement and Cohen's kappa; kappa is None when chance agreement is 1."""
    n = len(pairs)
    if n == 0:
        return {"n": 0, "raw": None, "kappa": None}
    observed = sum(a == b for a, b in pairs) / n
    first, second = Counter(a for a, _ in pairs), Counter(b for _, b in pairs)
    chance = sum(first[label] * second[label] for label in first) / (n * n)
    kappa = None if chance == 1 else round((observed - chance) / (1 - chance), 4)
    return {"n": n, "raw": round(observed, 4), "kappa": kappa}


def _top(counts: Counter, k: int) -> list:
    return [label for label, _ in sorted(counts.items(), key=lambda kv: (-kv[1], str(kv[0])))[:k]]


def leave_one_group_out(rows: Sequence[tuple[Hashable, Hashable, Hashable]], k: int = 3) -> float | None:
    """Top-k hit rate of `target` given `condition`, each row (group, condition, target).

    Each row is predicted from the rows of the other groups. A condition with no
    row left falls back to the targets of all the other groups, so the rate
    measures the table a reader would actually have.
    """
    if not rows:
        return None
    overall: Counter = Counter()
    by_condition: dict[Hashable, Counter] = {}
    by_group: dict[Hashable, Counter] = {}
    by_group_condition: dict[tuple, Counter] = {}
    for group, condition, target in rows:
        overall[target] += 1
        by_condition.setdefault(condition, Counter())[target] += 1
        by_group.setdefault(group, Counter())[target] += 1
        by_group_condition.setdefault((group, condition), Counter())[target] += 1
    hits = 0
    for group, condition, target in rows:
        rest = by_condition[condition] - by_group_condition[(group, condition)]
        if not rest:
            rest = overall - by_group[group]
        hits += target in _top(rest, k)
    return round(hits / len(rows), 4)
