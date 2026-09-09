"""Invoice tests. Run: python3 tests/test_invoice.py"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.billing.invoice import invoice_total, line_subtotal
from app.ledger import balance

FAILURES = []


def check(name, got, want):
    if got != want:
        FAILURES.append(f"{name}: got {got!r}, want {want!r}")
        print(f"FAIL  {name}: got {got!r}, want {want!r}")
    else:
        print(f"ok    {name}")


ITEMS = [{"qty": 1, "unit_price": 100.00}, {"qty": 1, "unit_price": 0.05}]

check("subtotal of the lines", line_subtotal(ITEMS), 100.05)
check("no discount", invoice_total(ITEMS), 100.05)

# A 50% negotiated discount on a 100.05 subtotal. Half of 100.05 is 50.025,
# a half-cent: money rounds half-cents UP, so the discount is 50.03 and the
# customer owes 50.02.
check("half-cent discount rounds up", invoice_total(ITEMS, 50), 50.02)

# Same shape, different numbers: half of 12.35 is 6.175 -> 6.18 off, 6.17 owed.
check("half-cent discount rounds up (small)",
      invoice_total([{"qty": 1, "unit_price": 12.35}], 50), 6.17)

ledger = []
invoice_total(ITEMS, 50, ledger)
check("ledger records the invoice", balance(ledger), 50.02)

print()
if FAILURES:
    print(f"{len(FAILURES)} failing check(s)")
    sys.exit(1)
print("all invoice checks passed")
