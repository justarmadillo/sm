"""Generate FSRS-6 reference vectors from py-fsrs and write them as JSON.

The Dart port is verified against these vectors by
``test/py_fsrs_vectors_test.dart``. py-fsrs is the reference implementation of
FSRS-6 maintained by open-spaced-repetition; ts-fsrs (the source of this port)
and py-fsrs share the algorithm but not the card lifecycle, so the vectors cover
the algorithm: the primitives and the memory-state trajectory of a review
sequence. Interval and lifecycle semantics are pinned by the ported ts-fsrs
suite instead.

Usage (from the repository root, with a py-fsrs checkout available):

    python fsrs-dart/tool/gen_py_vectors.py --py-fsrs <path-to-py-fsrs> \
        --out fsrs-dart/test/vectors/py_fsrs_v6_vectors.json
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

RATINGS = (1, 2, 3, 4)

# (label, [(rating, day offset from the previous review)])
SEQUENCES: list[tuple[str, list[tuple[int, int]]]] = [
    ("good-only", [(3, 0), (3, 0), (3, 1), (3, 3), (3, 8), (3, 21)]),
    ("again-then-good", [(1, 0), (3, 0), (3, 1), (3, 3), (3, 8), (3, 21)]),
    (
        "mixed-long",
        [
            (3, 0),
            (3, 0),
            (3, 2),
            (3, 11),
            (3, 46),
            (3, 163),
            (1, 498),
            (1, 0),
            (3, 0),
            (3, 2),
            (3, 4),
            (3, 7),
            (3, 12),
        ],
    ),
    ("hard-heavy", [(2, 0), (2, 0), (2, 1), (2, 2), (2, 4), (2, 7)]),
    ("easy-heavy", [(4, 0), (4, 1), (4, 5), (4, 20), (4, 90)]),
    ("same-day-repeats", [(3, 0), (2, 0), (4, 0), (1, 0), (3, 0)]),
    ("long-gaps", [(3, 0), (3, 30), (3, 180), (3, 400), (2, 900)]),
]

START = datetime(2022, 11, 29, 12, 30, 0, 0, timezone.utc)


def build(scheduler_cls, card_cls, rating_cls) -> dict:
    scheduler = scheduler_cls(enable_fuzzing=False)

    primitives: dict[str, list] = {
        "initial_stability": [],
        "initial_difficulty": [],
        "initial_difficulty_unclamped": [],
        "next_difficulty": [],
        "short_term_stability": [],
        "next_recall_stability": [],
        "next_forget_stability": [],
        "next_interval": [],
        "retrievability": [],
    }

    for rating in RATINGS:
        r = rating_cls(rating)
        primitives["initial_stability"].append(
            {"rating": rating, "value": scheduler._initial_stability(rating=r)}
        )
        primitives["initial_difficulty"].append(
            {
                "rating": rating,
                "value": scheduler._initial_difficulty(rating=r, clamp=True),
            }
        )
        primitives["initial_difficulty_unclamped"].append(
            {
                "rating": rating,
                "value": scheduler._initial_difficulty(rating=r, clamp=False),
            }
        )

    for difficulty in (1.0, 1.5, 3.0, 5.0, 6.3574867, 8.0, 9.5, 10.0):
        for rating in RATINGS:
            primitives["next_difficulty"].append(
                {
                    "difficulty": difficulty,
                    "rating": rating,
                    "value": scheduler._next_difficulty(
                        difficulty=difficulty, rating=rating_cls(rating)
                    ),
                }
            )

    for stability in (0.001, 0.1, 0.5, 1.0, 2.3065, 10.0, 53.62691, 365.0, 3650.0):
        for rating in RATINGS:
            primitives["short_term_stability"].append(
                {
                    "stability": stability,
                    "rating": rating,
                    "value": scheduler._short_term_stability(
                        stability=stability, rating=rating_cls(rating)
                    ),
                }
            )

    for difficulty in (1.0, 3.0, 5.0, 7.5, 10.0):
        for stability in (0.1, 1.0, 10.0, 100.0, 1000.0):
            for retrievability in (0.05, 0.5, 0.9, 0.99, 1.0):
                for rating in (2, 3, 4):
                    primitives["next_recall_stability"].append(
                        {
                            "difficulty": difficulty,
                            "stability": stability,
                            "retrievability": retrievability,
                            "rating": rating,
                            # Clamped here because py-fsrs clamps one level
                            # up, in _next_stability, while ts-fsrs clamps
                            # inside the formula itself.
                            "value": scheduler._clamp_stability(
                                stability=scheduler._next_recall_stability(
                                    difficulty=difficulty,
                                    stability=stability,
                                    retrievability=retrievability,
                                    rating=rating_cls(rating),
                                )
                            ),
                        }
                    )
                primitives["next_forget_stability"].append(
                    {
                        "difficulty": difficulty,
                        "stability": stability,
                        "retrievability": retrievability,
                        "value": scheduler._clamp_stability(
                            stability=scheduler._next_forget_stability(
                                difficulty=difficulty,
                                stability=stability,
                                retrievability=retrievability,
                            )
                        ),
                    }
                )

    for desired_retention in (0.7, 0.8, 0.9, 0.95, 0.99):
        sched = scheduler_cls(
            desired_retention=desired_retention, enable_fuzzing=False
        )
        for stability in (
            0.001,
            0.1,
            1.0,
            2.3065,
            10.0,
            53.62691,
            365.0,
            3650.0,
            36500.0,
        ):
            primitives["next_interval"].append(
                {
                    "desired_retention": desired_retention,
                    "stability": stability,
                    "value": sched._next_interval(stability=stability),
                }
            )

    for stability in (0.1, 1.0, 2.3065, 10.0, 53.62691, 365.0):
        for elapsed_days in (0, 1, 2, 5, 10, 30, 100, 365, 1000):
            card = card_cls(
                stability=stability,
                difficulty=5.0,
                state=None,
                due=START,
                last_review=START,
            )
            primitives["retrievability"].append(
                {
                    "stability": stability,
                    "elapsed_days": elapsed_days,
                    "value": scheduler.get_card_retrievability(
                        card,
                        current_datetime=START + timedelta(days=elapsed_days),
                    ),
                }
            )

    sequences = []
    for label, steps in SEQUENCES:
        card = card_cls()
        now = START
        entries = []
        for rating, offset in steps:
            now = now + timedelta(days=offset)
            retrievability = scheduler.get_card_retrievability(
                card, current_datetime=now
            )
            card, _ = scheduler.review_card(
                card=card,
                rating=rating_cls(rating),
                review_datetime=now,
            )
            entries.append(
                {
                    "rating": rating,
                    "offset_days": offset,
                    "retrievability_before": retrievability,
                    "stability": card.stability,
                    "difficulty": card.difficulty,
                    "next_interval": scheduler._next_interval(
                        stability=card.stability
                    ),
                }
            )
        sequences.append({"label": label, "reviews": entries})

    return {
        "generator": "py-fsrs",
        "start": START.isoformat(),
        "parameters": list(scheduler.parameters),
        "desired_retention": scheduler.desired_retention,
        "decay": scheduler._DECAY,
        "factor": scheduler._FACTOR,
        "primitives": primitives,
        "sequences": sequences,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--py-fsrs",
        required=True,
        help="path to a py-fsrs checkout (the directory containing fsrs/)",
    )
    parser.add_argument("--out", required=True, help="path of the JSON to write")
    args = parser.parse_args()

    sys.path.insert(0, str(Path(args.py_fsrs).resolve()))
    from fsrs.card import Card  # noqa: PLC0415
    from fsrs.rating import Rating  # noqa: PLC0415
    from fsrs.scheduler import Scheduler  # noqa: PLC0415

    payload = build(Scheduler, Card, Rating)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
