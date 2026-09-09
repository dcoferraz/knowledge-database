"""Payout tests. Run: python3 tests/test_payout.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.reporting.payout import partner_payout, gross_revenue, statement
from app.ledger import balance

FAILURES = []


def check(name, got, want):
    if got != want:
        FAILURES.append(f"{name}: got {got!r}, want {want!r}")
        print(f"FAIL  {name}: got {got!r}, want {want!r}")
    else:
        print(f"ok    {name}")


SALES = [{"amount": 1000.0}, {"amount": 0.05}]

check("gross revenue", gross_revenue(SALES), 1000.05)
check("full share", partner_payout(SALES, 100), 1000.05)

# A 50/50 revenue share on 1000.05 gross. Half is 500.025, a half-cent, and
# money rounds half-cents UP: the partner is owed 500.03.
check("half-cent share rounds up", partner_payout(SALES, 50), 500.03)

# Same shape, different numbers: half of 33.33 is 16.665 -> 16.67 owed.
check("half-cent share rounds up (small)", partner_payout([{"amount": 33.33}], 50), 16.67)

ledger = []
partner_payout(SALES, 50, ledger)
check("ledger records the payout", balance(ledger), -500.03)
check("statement line", statement(SALES, 50), "gross 1000.05 / share 50% / payout 500.03")

print()
if FAILURES:
    print(f"{len(FAILURES)} failing check(s)")
    sys.exit(1)
print("all payout checks passed")
