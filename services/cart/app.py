import os
from copy import deepcopy
from threading import Lock

import requests
from flask import Flask, jsonify, request

from services.common import configure_logging

app = Flask(__name__)
logger = configure_logging("cart")

PRODUCT_CATALOG_URL = os.getenv("PRODUCT_CATALOG_URL", "http://localhost:3550")
CARTS: dict[str, dict[str, dict]] = {}
CART_LOCK = Lock()


def cart_payload(user_id: str) -> dict:
    with CART_LOCK:
        stored_items = deepcopy(list(CARTS.get(user_id, {}).values()))

    items = [
        {"product": item["product"], "quantity": item["quantity"]}
        for item in stored_items
    ]
    total_cents = sum(
        item["product"]["price_cents"] * item["quantity"] for item in items
    )
    return {"user_id": user_id, "items": items, "total_cents": total_cents}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/cart/<user_id>")
def get_cart(user_id: str):
    payload = cart_payload(user_id)
    logger.info(
        "Loaded cart",
        extra={"user_id": user_id, "item_count": len(payload["items"])},
    )
    return jsonify(payload)


@app.post("/cart/<user_id>/items")
def add_item(user_id: str):
    body = request.get_json(silent=True) or {}
    product_id = body.get("product_id")
    quantity = body.get("quantity", 1)

    if not product_id:
        return {"error": "product_id is required"}, 400
    if not isinstance(quantity, int) or isinstance(quantity, bool) or quantity < 1:
        return {"error": "quantity must be a positive integer"}, 400

    try:
        response = requests.get(
            f"{PRODUCT_CATALOG_URL}/products/{product_id}",
            timeout=3,
        )
        if response.status_code == 404:
            return {"error": "product not found"}, 404
        response.raise_for_status()
        product = response.json()
    except requests.RequestException:
        logger.exception("Product Catalog request failed")
        return {"error": "product catalog unavailable"}, 503

    with CART_LOCK:
        cart = CARTS.setdefault(user_id, {})
        existing = cart.get(product_id)
        cart[product_id] = {
            "product": product,
            "quantity": quantity + (existing["quantity"] if existing else 0),
        }

    logger.info(
        "Added item to cart",
        extra={"user_id": user_id, "product_id": product_id, "quantity": quantity},
    )
    return jsonify(cart_payload(user_id)), 201


@app.delete("/cart/<user_id>")
def clear_cart(user_id: str):
    with CART_LOCK:
        CARTS.pop(user_id, None)

    logger.info("Cleared cart", extra={"user_id": user_id})
    return {"user_id": user_id, "items": [], "total_cents": 0}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "7070")), threaded=True)
