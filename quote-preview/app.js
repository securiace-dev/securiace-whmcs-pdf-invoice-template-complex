"use strict";

const printButton = document.querySelector("[data-print]");
const quoteDocument = document.querySelector("#quote-document");

printButton?.addEventListener("click", () => window.print());

window.addEventListener("beforeprint", () => {
  quoteDocument?.setAttribute("aria-busy", "true");
});

window.addEventListener("afterprint", () => {
  quoteDocument?.removeAttribute("aria-busy");
});
