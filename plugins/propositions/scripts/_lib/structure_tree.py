"""Tree computations shared by the article-structure tools (format 2.0).

Spectra change add-discourse-dependency-tree. Positions are 1-based places in
reading order. A head map sends a position to its head's position, to ``None``
for a paragraph root, or to ``PENDING`` for a draft record whose head has not
been written yet. Format and definitions: ``plugins/propositions/docs/STRUCTURE.md``.

Every function here is pure: it reads integers and lists and returns new values.
"""
from __future__ import annotations

from bisect import bisect_right
from typing import Hashable, Iterable, Mapping, Sequence

PENDING = "pending"

Head = int | str | None  # a position, PENDING, or None for a root


def unit_index(firsts: Sequence[int], position: int) -> int:
    """Index of the unit (paragraph or section) holding `position`; `firsts` strictly increase."""
    return max(bisect_right(firsts, position) - 1, 0)


def crossing_pairs(arcs: Iterable[tuple[int, int, Hashable]]) -> list[tuple[tuple[int, int, Hashable], tuple[int, int, Hashable]]]:
    """Pairs of arcs that cross: with endpoints sorted, a1 < a2 < b1 < b2 or a2 < a1 < b2 < b1.

    Arcs that share an endpoint or nest do not cross. Each arc is
    (one end, other end, key); the key identifies the arc to the caller.
    """
    norm = [(min(a, b), max(a, b), key) for a, b, key in arcs]
    out = []
    for i, (a1, b1, _) in enumerate(norm):
        for a2, b2, key2 in norm[i + 1:]:
            if a1 < a2 < b1 < b2 or a2 < a1 < b2 < b1:
                out.append((norm[i], (a2, b2, key2)))
    return out


def crossing_members(pairs: Sequence[tuple[tuple, tuple]]) -> set:
    """Keys of the arcs that take part in at least one crossing."""
    return {arc[2] for pair in pairs for arc in pair}


def frontier(t: int, head_of: Mapping[int, Head], root: int | None) -> list[int]:
    """Sentence part of the right frontier at `t`.

    `t`, then every ancestor of `t` reached by following heads whose position is
    at most `t` (ancestors after `t` are passed through, not listed), ending at
    the paragraph root when the root has appeared. Stops at a pending head and
    never loops on a cycle.
    """
    nodes: list[int] = []
    seen: set[int] = set()
    current: Head = t
    while isinstance(current, int) and current not in seen:
        seen.add(current)
        if current <= t:
            nodes.append(current)
        current = head_of.get(current)
    if root is not None and root <= t and root not in nodes:
        nodes.append(root)
    return nodes


def depths(parents: Sequence[int | None]) -> list[int]:
    """Depth of each section: 1 for top-level, one more than the parent otherwise.

    `parents[i]` is the index of section i's parent (always < i) or None.
    """
    out: list[int] = []
    for parent in parents:
        out.append(1 if parent is None else out[parent] + 1)
    return out


def ancestors(index: int, parents: Sequence[int | None]) -> list[int]:
    """`index`, its parent, its grandparent, ... up to a top-level section."""
    chain = [index]
    while parents[chain[-1]] is not None:
        chain.append(parents[chain[-1]])
    return chain


def shared_depth(a: int, b: int, parents: Sequence[int | None]) -> int:
    """Depth of the deepest section containing both sections a and b; 0 when none does."""
    above_a = set(ancestors(a, parents))
    levels = depths(parents)
    for candidate in ancestors(b, parents):
        if candidate in above_a:
            return levels[candidate]
    return 0


# ---------- commitment ordering ----------

URGENCY = ("announcement", "hypothesis", "plan", "question", "aim", "setup")
ORDERS = ("kind", "scope")


def ordering_key(kind: str, opened_at: int, depth: int, order: str) -> tuple:
    """Sort key for an open commitment.

    `kind`: by kind (URGENCY), then opening position, earliest first.
    `scope`: by kind, then by `depth` — the depth of the deepest section shared by
    the opening proposition and t — deepest first, then opening position.
    """
    if order == "scope":
        return (URGENCY.index(kind), -depth, opened_at)
    return (URGENCY.index(kind), opened_at)
