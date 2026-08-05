const states = {
  paid: {
    status: "Paid",
    invoiceNumber: "INV-2026-00482",
    invoiceDate: "5 Aug 2026",
    proformaNumber: "PF-2026-00461",
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
    invoiceNumber: "INV-2026-00483",
    invoiceDate: "3 Aug 2026",
    dueDate: "18 Aug 2026",
    itemName: "Managed WordPress hosting",
    itemDetail: "northstar.example · annual service",
    servicePeriod: "3 Aug 2026 – 2 Aug 2027",
    quantity: "1",
    rate: "₹8,466.10",
    lineTotal: "₹8,466.10",
    subtotal: "₹8,466.10",
    taxLabel: "GST · 18%",
    tax: "₹1,523.90",
    credit: "− ₹0.00",
    total: "₹9,990.00 INR",
    balance: "₹9,990.00 INR",
    stateTotalLabel: "Balance due",
    stateTotal: "₹9,990.00 INR",
    transactionCount: "No records",
    generatedAt: "5 Aug 2026, 18:30 IST",
    showTax: true,
    showCredit: false,
  },
};

const stateButtons = [...document.querySelectorAll("[data-state-button]")];
const paidOnly = [...document.querySelectorAll("[data-paid-only]")];
const unpaidOnly = [...document.querySelectorAll("[data-unpaid-only]")];
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
  unpaidOnly.forEach((element) => {
    element.hidden = normalizedState !== "unpaid";
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
