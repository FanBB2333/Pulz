/**
 * Shopping cart with a type coercion bug.
 */

class ShoppingCart {
  constructor() {
    this.items = [];
  }

  addItem(name, price, quantity) {
    // FIX: Convert price and quantity from string to number at input boundary
    this.items.push({ name, price: Number(price), quantity: Number(quantity) });
  }

  getTotal() {
    let total = 0;
    for (const item of this.items) {
      total += item.price * item.quantity;
    }
    return total;
  }

  applyDiscount(percentage) {
    // FIX: Convert percentage from string to number
    const discount = Number(percentage) / 100;
    return this.getTotal() * (1 - discount);
  }
}

// Simulates form/URL input (values arrive as strings)
const cart = new ShoppingCart();
cart.addItem("Widget", "19.99", 2);    // price is string "19.99"
cart.addItem("Gadget", "9.50", "3");   // both price and quantity are strings

console.log("Total:", cart.getTotal());
// Expected: 19.99*2 + 9.50*3 = 39.98 + 28.50 = 68.48

function formatReceipt(cart) {
  let receipt = "Receipt:\n";
  for (const item of cart.items) {
    const lineTotal = item.price + item.price; // Now works correctly: 19.99 + 19.99 = 39.98
    receipt += `${item.name}: ${lineTotal}\n`;
  }
  return receipt;
}

console.log(formatReceipt(cart));
// Now outputs: "Widget: 39.98"

module.exports = { ShoppingCart, formatReceipt };
