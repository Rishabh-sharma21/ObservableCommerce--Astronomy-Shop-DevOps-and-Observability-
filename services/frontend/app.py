import os

import requests
from flask import Flask, jsonify, render_template, request

from services.common import configure_logging

app = Flask(__name__)
logger = configure_logging("frontend")

PRODUCT_CATALOG_URL = os.getenv("PRODUCT_CATALOG_URL", "http://localhost:3550")
CART_URL = os.getenv("CART_URL", "http://localhost:7070")
CHECKOUT_URL = os.getenv("CHECKOUT_URL", "http://localhost:5050")


def proxy(method: str, url: str):
    try:
        response = requests.request(
            method,
            url,
            json=request.get_json(silent=True),
            timeout=5,
        )
        return jsonify(response.json()), response.status_code
    except requests.RequestException:
        logger.exception("Upstream request failed", extra={"upstream_url": url})
        return {"error": "upstream service unavailable"}, 503


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/")
def home():
    return render_template("index.html")


@app.get("/api/products")
def products():
    return proxy("GET", f"{PRODUCT_CATALOG_URL}/products")


@app.get("/api/cart/<user_id>")
def get_cart(user_id: str):
    return proxy("GET", f"{CART_URL}/cart/{user_id}")


@app.post("/api/cart/<user_id>/items")
def add_cart_item(user_id: str):
    return proxy("POST", f"{CART_URL}/cart/{user_id}/items")


@app.post("/api/checkout/<user_id>")
def checkout(user_id: str):
    return proxy("POST", f"{CHECKOUT_URL}/checkout/{user_id}")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")), threaded=True)
