const formatBTC = price => {
  const _price = parseFloat(price)
  return _price > 1
    ? parseFloat(_price.toFixed(2))
    : parseFloat(_price.toFixed(8))
}

const formatNumber = (amount, currency, options = {}) => {
  if (currency === 'SAN') {
    const value = amount / 10000000000
    if (value % 1 === 0) {
      return `SAN ${value}.000`
    }
    return `SAN ${value}`
  }

  let value = new Intl.NumberFormat('en', {
    style: currency ? 'currency' : 'decimal',
    currency,
    ...options
  }).format(amount)

  // Include positive +
  if (options.directionSymbol && amount >= 0) {
    value = `+${value}`
  }

  return value
}

export { formatNumber, formatBTC }
