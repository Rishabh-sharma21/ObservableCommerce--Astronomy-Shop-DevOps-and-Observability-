import os

from flask import Flask, jsonify

from services.common import configure_logging

app = Flask(__name__)
logger = configure_logging("product-catalog")

PRODUCTS = [
    {
        "id": "scope-101",
        "name": "Explorer Telescope",
        "description": "A portable telescope for clear views of the moon.",
        "price_cents": 12999,
    },
    {
        "id": "binocular-202",
        "name": "Night Sky Binoculars",
        "description": "Wide-field binoculars for constellations and wildlife.",
        "price_cents": 7499,
    },
    {
        "id": "filter-303",
        "name": "Moon Filter",
        "description": "Reduces glare and improves lunar surface detail.",
        "price_cents": 1899,
    },
    {
        "id": "map-404",
        "name": "Rotating Star Map",
        "description": "A simple guide to finding seasonal constellations.",
        "price_cents": 1499,
    },
    {
        "id": "light-505",
        "name": "Red Astronomy Light",
        "description": "Preserves night vision during observing sessions.",
        "price_cents": 2499,
    },
    {
        "id": "book-606",
        "name": "Beginner Field Guide",
        "description": "A practical introduction to backyard astronomy.",
        "price_cents": 2199,
    },
]


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/products")
def list_products():
    logger.info("Listed products", extra={"product_count": len(PRODUCTS)})
    return jsonify(PRODUCTS)


@app.get("/products/<product_id>")
def get_product(product_id: str):
    product = next((item for item in PRODUCTS if item["id"] == product_id), None)
    if product is None:
        logger.warning("Product not found", extra={"product_id": product_id})
        return {"error": "product not found"}, 404

    logger.info("Loaded product", extra={"product_id": product_id})
    return jsonify(product)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "3550")), threaded=True)
