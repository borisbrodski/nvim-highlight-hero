local function invoice_total(items, tax_rate, discount)
  local subtotal = 0
  for _, item in ipairs(items) do
    local price = item.price * item.quantity
    subtotal = subtotal + price
  end
  if discount then
    subtotal = subtotal - subtotal * discount
  end
  local tax = subtotal * tax_rate
  local total = subtotal + tax
  return total, tax
end
