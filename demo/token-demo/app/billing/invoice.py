"""Customer invoicing: line items, discounts, invoice totals."""

from app.ledger import record


def line_subtotal(items):
    """Sum of qty * unit_price for every line on the invoice."""
    return sum(item["qty"] * item["unit_price"] for item in items)


def apply_discount(subtotal, discount_pct):
    """Money off the subtotal for a negotiated discount percentage."""
    return round(subtotal * discount_pct / 100, 2)


def invoice_total(items, discount_pct=0, ledger=None):
    """What the customer owes, in currency units, rounded to cents."""
    subtotal = line_subtotal(items)
    discount = apply_discount(subtotal, discount_pct)
    total = round(subtotal - discount, 2)
    if ledger is not None:
        record(ledger, "invoice", total)
    return total
