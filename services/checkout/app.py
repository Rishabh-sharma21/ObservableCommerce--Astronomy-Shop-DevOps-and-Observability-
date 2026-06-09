import os
import time
import uuid

import requests
from flask import Flask, jsonify
from opentelemetry import trace

from services.common import configure_logging

app = Flask(__name__)
logger = configure_logging("checkout")
tracer = trace.get_tracer("astronomy-shop-lite.checkout")

CART_URL = os.getenv("CART_URL", "http://localhost:7070")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/checkout/<user_id>")
def checkout(user_id: str):
    try:
        response = requests.get(f"{CART_URL}/cart/{user_id}", timeout=3)
        response.raise_for_status()
        cart = response.json()
    except requests.RequestException:
        logger.exception("Cart request failed")
        return {"error": "cart unavailable"}, 503

    if not cart["items"]:
        return {"error": "cart is empty"}, 400

    order_id = str(uuid.uuid4())
    with tracer.start_as_current_span("create-order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.item_count", len(cart["items"]))
        span.set_attribute("order.total_cents", cart["total_cents"])
        time.sleep(0.05)

    try:
        response = requests.delete(f"{CART_URL}/cart/{user_id}", timeout=3)
        response.raise_for_status()
    except requests.RequestException:
        logger.exception("Could not clear cart after checkout")
        return {"error": "order created but cart could not be cleared"}, 503

    order = {
        "order_id": order_id,
        "user_id": user_id,
        "items": cart["items"],
        "total_cents": cart["total_cents"],
        "status": "confirmed",
    }
    logger.info(
        "Order confirmed",
        extra={
            "order_id": order_id,
            "user_id": user_id,
            "total_cents": cart["total_cents"],
        },
    )
    return jsonify(order), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5050")), threaded=True)
