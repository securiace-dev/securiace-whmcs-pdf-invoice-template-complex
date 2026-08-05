const states = {
  paid: {
    status: "Paid",
    documentKicker: "Invoice",
    documentTitle: "Invoice",
    documentNumberLabel: "Invoice number",
    invoiceNumber: "ST/2070",
    invoiceDate: "5 Aug 2026",
    proformaNumber: "PI/300000461",
    itemName: "Domain renewal",
    itemDetail: "northstar.example · 5 years",
    servicePeriod: "8 Aug 2026 – 8 Aug 2031",
    quantity: "1",
    rate: "₹7,750.00",
    lineTotal: "₹7,750.00",
    subtotal: "₹7,750.00",
    taxLabel: "GST · 18%",
    tax: "₹0.00",
    credit: "− ₹0.00",
    total: "₹7,750.00 INR",
    stateTotalLabel: "Amount paid",
    stateTotal: "₹7,750.00 INR",
    paidDate: "6 Aug 2026",
    paymentMethod: "Bank transfer",
    transactionId: "DEMO-NEFT-2849",
    transactionAmount: "₹7,750.00",
    transactionCount: "1 record",
    verificationId: "8F3C912A6D44 · 1B70C9D2",
    renewalService: "Domain renewal · northstar.example",
    renewalDate: "8 Aug 2031",
    renewalTiming: "Scheduled",
    generatedAt: "5 Aug 2026, 18:30 IST",
    showTax: false,
    showCredit: false,
  },
  unpaid: {
    status: "Unpaid",
    documentKicker: "Proforma",
    documentTitle: "Proforma Invoice",
    documentNumberLabel: "Proforma reference",
    duePanelLabel: "Balance due",
    dueMessage: "Pay by 18 Aug 2026",
    paymentCalloutLabel: "Payment required",
    paymentHeading: "₹9,990.00 INR is due",
    paymentCopy: "Use proforma PI/300000483 as the transfer reference. The UPI code is tied to this outstanding INR amount.",
    termsDueText: "Payment is due by 18 Aug 2026.",
    invoiceNumber: "PI/300000483",
    invoiceDate: "3 Aug 2026",
    dueDate: "18 Aug 2026",
    itemName: "Managed WordPress hosting",
    itemDetail: "northstar.example · annual service",
    servicePeriod: "3 Aug 2026 – 2 Aug 2027",
    quantity: "1",
    rate: "₹9,990.00",
    lineTotal: "₹9,990.00",
    subtotal: "₹9,990.00",
    taxLabel: "Tax",
    tax: "₹0.00",
    credit: "− ₹0.00",
    total: "₹9,990.00 INR",
    balance: "₹9,990.00 INR",
    stateTotalLabel: "Balance due",
    stateTotal: "₹9,990.00 INR",
    transactionCount: "No records",
    generatedAt: "5 Aug 2026, 18:30 IST",
    showTax: false,
    showCredit: false,
  },
  overdue: {
    status: "Overdue",
    documentKicker: "Proforma",
    documentTitle: "Proforma Invoice",
    documentNumberLabel: "Proforma reference",
    duePanelLabel: "Overdue balance",
    dueMessage: "2 days overdue · pay now",
    paymentCalloutLabel: "Overdue payment",
    paymentHeading: "₹9,990.00 INR is overdue",
    paymentCopy: "Pay immediately using proforma PI/300000484 as the transfer reference. The UPI code remains tied to the outstanding INR amount.",
    termsDueText: "Payment was due on 3 Aug 2026 and is now overdue.",
    invoiceNumber: "PI/300000484",
    invoiceDate: "4 Jul 2026",
    dueDate: "3 Aug 2026",
    itemName: "Managed WordPress hosting",
    itemDetail: "northstar.example · annual service",
    servicePeriod: "3 Aug 2026 – 2 Aug 2027",
    quantity: "1",
    rate: "₹9,990.00",
    lineTotal: "₹9,990.00",
    subtotal: "₹9,990.00",
    taxLabel: "Tax",
    tax: "₹0.00",
    credit: "− ₹0.00",
    total: "₹9,990.00 INR",
    balance: "₹9,990.00 INR",
    stateTotalLabel: "Balance due",
    stateTotal: "₹9,990.00 INR",
    transactionCount: "No records",
    generatedAt: "5 Aug 2026, 18:30 IST",
    showTax: false,
    showCredit: false,
  },
};

const stateButtons = [...document.querySelectorAll("[data-state-button]")];
const paidOnly = [...document.querySelectorAll("[data-paid-only]")];
const outstandingOnly = [...document.querySelectorAll("[data-outstanding-only]")];
const taxRows = [...document.querySelectorAll("[data-tax-row]")];
const creditRows = [...document.querySelectorAll("[data-credit-row]")];

function setState(nextState, { updateUrl = true } = {}) {
  const normalizedState = Object.hasOwn(states, nextState) ? nextState : "paid";
  const values = states[normalizedState];

  document.documentElement.dataset.invoiceState = normalizedState;
  document.title = `Securiace ${normalizedState} invoice redesign preview`;

  document.querySelectorAll("[data-bind]").forEach((element) => {
    const key = element.dataset.bind;
    if (Object.hasOwn(values, key)) {
      element.textContent = values[key];
    }
  });

  paidOnly.forEach((element) => {
    element.hidden = normalizedState !== "paid";
  });
  outstandingOnly.forEach((element) => {
    element.hidden = normalizedState === "paid";
  });
  taxRows.forEach((element) => {
    element.hidden = !values.showTax;
  });
  creditRows.forEach((element) => {
    element.hidden = !values.showCredit;
  });

  stateButtons.forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.stateButton === normalizedState));
  });

  if (updateUrl) {
    const url = new URL(window.location.href);
    url.searchParams.set("state", normalizedState);
    window.history.replaceState({}, "", url);
  }
}

stateButtons.forEach((button) => {
  button.addEventListener("click", () => setState(button.dataset.stateButton));
});

document.querySelector("[data-print]").addEventListener("click", () => window.print());

const initialState = new URL(window.location.href).searchParams.get("state") || "paid";
setState(initialState, { updateUrl: false });
