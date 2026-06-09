import unittest
from unittest.mock import Mock, patch

from services.cart.app import CARTS, app as cart_app
from services.checkout.app import app as checkout_app
from services.product_catalog.app import app as catalog_app


class ProductCatalogTests(unittest.TestCase):
    def test_lists_products(self):
        response = catalog_app.test_client().get("/products")

        self.assertEqual(response.status_code, 200)
        self.assertGreater(len(response.get_json()), 0)


class CartTests(unittest.TestCase):
    def setUp(self):
        CARTS.clear()

    @patch("services.cart.app.requests.get")
    def test_adds_a_valid_product(self, get_product):
        response = Mock(status_code=200)
        response.json.return_value = {
            "id": "scope-101",
            "name": "Explorer Telescope",
            "description": "Test product",
            "price_cents": 12999,
        }
        response.raise_for_status.return_value = None
        get_product.return_value = response

        result = cart_app.test_client().post(
            "/cart/demo-user/items",
            json={"product_id": "scope-101", "quantity": 2},
        )

        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.get_json()["total_cents"], 25998)


class CheckoutTests(unittest.TestCase):
    @patch("services.checkout.app.requests.delete")
    @patch("services.checkout.app.requests.get")
    def test_creates_order_and_clears_cart(self, get_cart, clear_cart):
        cart_response = Mock()
        cart_response.json.return_value = {
            "user_id": "demo-user",
            "items": [{"product": {"price_cents": 1000}, "quantity": 2}],
            "total_cents": 2000,
        }
        cart_response.raise_for_status.return_value = None
        get_cart.return_value = cart_response

        clear_response = Mock()
        clear_response.raise_for_status.return_value = None
        clear_cart.return_value = clear_response

        result = checkout_app.test_client().post("/checkout/demo-user")

        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.get_json()["status"], "confirmed")
        clear_cart.assert_called_once()


if __name__ == "__main__":
    unittest.main()
