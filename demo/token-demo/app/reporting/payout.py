"""Partner reporting: revenue share and monthly payout statements."""

from app.ledger import record


def gross_revenue(sales):
    """Everything booked in the period, before any split."""
    return sum(sale["amount"] for sale in sales)


def share_amount(gross, share_pct):
    """The partner's cut of gross revenue for their agreed share."""
    return round(gross * share_pct / 100, 2)


def partner_payout(sales, share_pct, ledger=None):
    """What we owe the partner for the period, rounded to cents."""
    gross = gross_revenue(sales)
    amount = share_amount(gross, share_pct)
    if ledger is not None:
        record(ledger, "payout", amount)
    return amount


def statement(sales, share_pct):
    """Human-facing summary line for the monthly statement email."""
    gross = gross_revenue(sales)
    return f"gross {gross:.2f} / share {share_pct}% / payout {partner_payout(sales, share_pct):.2f}"
