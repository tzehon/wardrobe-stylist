"""Pydantic mirrors of `shared/schemas/purchase.schema.json`.

These models are the runtime guard on every `/extract` response — Claude's tool
output is validated through them before anything leaves the backend. The
contract test in `tests/test_purchase_schema.py` pins the JSON Schema and these
classes against the same golden fixtures so they can't drift.
"""

from typing import Annotated, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

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
    # Model output remains an untrusted string here. The iOS remote-image policy
    # performs the authoritative HTTPS/host/size validation before any fetch.
    image_url: str | None = None


class FashionPurchaseExtraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    is_fashion: bool
    source_msg_id: Annotated[str, Field(min_length=1)]
    items: list[PurchaseItem]

    @model_validator(mode="after")
    def require_items_to_match_fashion_result(self) -> Self:
        if self.is_fashion and not self.items:
            raise ValueError("items must contain at least one item when is_fashion is true")
        if not self.is_fashion and self.items:
            raise ValueError("items must be empty when is_fashion is false")
        return self
