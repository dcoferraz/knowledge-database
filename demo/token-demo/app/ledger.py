"""Tiny append-only ledger the billing and reporting modules both write to."""


def record(ledger, kind, amount):
    ledger.append({"kind": kind, "amount": amount})
    return ledger


def balance(ledger):
    invoiced = sum(e["amount"] for e in ledger if e["kind"] == "invoice")
    paid_out = sum(e["amount"] for e in ledger if e["kind"] == "payout")
    return round(invoiced - paid_out, 2)
