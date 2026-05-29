"""Pydantic mirrors of `shared/schemas/purchase.schema.json`.

These models are the runtime guard on every `/extract` response — Claude's tool
output is validated through them before anything leaves the backend. The
contract test in `tests/test_purchase_schema.py` pins the JSON Schema and these
classes against the same golden fixtures so they can't drift.
"""

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

Category = Literal[
    "top", "bottom", "dress", "outerwear", "shoe", "bag", "jewelry", "accessory"
]
Confidence = Literal["high", "medium", "low"]
Currency = Annotated[str, StringConstraints(pattern=r"^[A-Z]{3}$")]


class PurchaseItem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: Annotated[str, Field(min_length=1)]
    category: Category
    confidence: Confidence
    brand: str | None = None
    color: str | None = None
    material: str | None = None
    style_notes: str | None = None
    price: Annotated[float, Field(ge=0)] | None = None
    currency: Currency | None = None
    image_url: str | None = None  # lenient: receipts surface odd URLs; let it through


class FashionPurchaseExtraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    is_fashion: bool
    source_msg_id: Annotated[str, Field(min_length=1)]
    items: list[PurchaseItem]
