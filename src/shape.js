function shapeCustomer(row) {
  return {
    customerId: row.CustomerId,
    customerName: row.CustomerName,
    customerAddress1: row.CustomerAddress1,
    customerAddress2: row.CustomerAddress2,
    customerCity: row.CustomerCity,
    customerState: row.CustomerState,
    customerPostalCode: row.CustomerPostalCode,
    customerTelephone: row.CustomerTelephone,
    customerContactName: row.CustomerContactName,
    customerEmailAddress: row.CustomerEmailAddress
  };
}

function shapeProduct(row) {
  return {
    productId: row.ProductId,
    productName: row.ProductName,
    productCost: Number(row.ProductCost)
  };
}

function shapeOrderSummary(row) {
  return {
    invoiceNumber: row.InvoiceNumber,
    invoiceDate: row.InvoiceDate,
    customerId: row.CustomerId
  };
}

function shapeLineItem(row) {
  return {
    lineItemId: row.LineItemId,
    productId: row.ProductId,
    quantity: row.Quantity,
    invoiceDate: row.InvoiceDate,
    productName: row.ProductName,
    productCost: Number(row.ProductCost),
    totalCost: Number(row.TotalCost)
  };
}

function shapeOrderDetails(orderRow, customerRow, lineItemRows) {
  return {
    customerDetail: shapeCustomer(customerRow),
    orderDetail: {
      invoiceNumber: orderRow.InvoiceNumber,
      invoiceDate: orderRow.InvoiceDate,
      customerId: orderRow.CustomerId
    },
    lineItems: lineItemRows.map(shapeLineItem)
  };
}

module.exports = {
  shapeCustomer,
  shapeProduct,
  shapeOrderSummary,
  shapeOrderDetails
};
