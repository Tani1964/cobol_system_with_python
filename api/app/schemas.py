"""Request bodies. Only transport-level checks live here (lengths,
characters that would break the pipe-delimited COBOL request line,
JSON types). Every BUSINESS rule is enforced by the COBOL services so
there is exactly one source of truth for the rules."""
from __future__ import annotations

from datetime import date
from decimal import Decimal
from typing import Annotated, Literal, Optional

from pydantic import AfterValidator, BaseModel, ConfigDict, Field


def _safe(value: str) -> str:
    if any(ch in value for ch in "|\r\n\t\x00"):
        raise ValueError("must not contain | or control characters")
    if not value.isascii():
        raise ValueError("must be ASCII")
    return value.strip()


def Text(max_len: int):
    return Annotated[str, Field(min_length=1, max_length=max_len),
                     AfterValidator(_safe)]


Money = Annotated[Decimal, Field(allow_inf_nan=False,
                                 max_digits=17, decimal_places=2)]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CustomerCreate(Strict):
    customer_id: Text(8)
    full_name: Text(40)
    phone: Text(15)
    email: Text(50)
    date_of_birth: date


class AccountCreate(Strict):
    account_number: Text(10)
    customer_id: Text(8)
    type: Text(3)               # SAV or CUR - checked by COBOL (107)
    currency: Optional[Text(3)] = None
    overdraft_limit: Money = Decimal("0")


class StatusChange(Strict):
    status: Literal["A", "I", "B"]


class Movement(Strict):
    amount: Money
    reference: Text(30)


class Transfer(Strict):
    source_account: Text(10)
    destination_account: Text(10)
    amount: Money
    reference: Text(30)


class Reversal(Strict):
    reference: Text(30)


class DailyRun(Strict):
    business_date: Optional[date] = None
