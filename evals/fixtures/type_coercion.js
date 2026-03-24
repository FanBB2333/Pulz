/**
 * Shopping cart with a type coercion bug.
 */

class ShoppingCart {
  constructor() {
    this.items = [];
  }

  addItem(name, price, quantity) {
    // BUG: price comes from form input as string, not parsed to number
    this.items.push({ name, price, quantity });
  }

  getTotal() {
    let total = 0;
    for (const item of this.items) {
      // BUG: string concatenation instead of addition when price is string
      total += item.price * item.quantity;
    }
    return total;
  }

  applyDiscount(percentage) {
    // BUG: percentage from URL param is string "10", not number 10
    // "10" / 100 works in JS but ("10" / 100) type issues compound
    const discount = percentage / 100;
    return this.getTotal() * (1 - discount);
  }
}

// Simulates form/URL input (values arrive as strings)
const cart = new ShoppingCart();
cart.addItem("Widget", "19.99", 2);    // price is string "19.99"
cart.addItem("Gadget", "9.50", "3");   // both price and quantity are strings

console.log("Total:", cart.getTotal());
// Expected: 19.99*2 + 9.50*3 = 39.98 + 28.50 = 68.48
// Actual: "19.9919.99" + "9.509.509.50" = NaN (string concat then multiply)
// Actually in JS: "19.99" * 2 = 39.98 (works), "9.50" * "3" = 28.5 (works)
// The real bug: if quantity is string "3", item.price * item.quantity
// does implicit coercion which works for multiplication but fails for addition
// Let's make the bug more obvious:

function formatReceipt(cart) {
  let receipt = "Receipt:\n";
  for (const item of cart.items) {
    const lineTotal = item.price + item.price; // BUG: string concat "19.9919.99"
    receipt += `${item.name}: ${lineTotal}\n`;
  }
  return receipt;
}

console.log(formatReceipt(cart));
// "Widget: 19.9919.99" instead of "Widget: 39.98"

module.exports = { ShoppingCart, formatReceipt };
