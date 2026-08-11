"use strict";

const printButton = document.querySelector("[data-print]");
const quoteDocument = document.querySelector("#quote-document");
const themeToggle = document.getElementById("securiace-theme-toggle");

printButton?.addEventListener("click", () => window.print());

if (themeToggle) {
  const applyLabel = () => {
    const mode = document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
    const label = themeToggle.querySelector("[data-mode-label]");
    if (label) {
      label.textContent = mode === "dark" ? "Dark" : "Light";
    }
    themeToggle.setAttribute("aria-pressed", mode === "dark" ? "true" : "false");
  };
  applyLabel();
  themeToggle.addEventListener("click", () => {
    const current = document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
    const next = current === "dark" ? "light" : "dark";
    document.documentElement.setAttribute("data-theme", next);
    try {
      localStorage.setItem("securiace-theme-mode", next);
    } catch (err) {
      /* ignore */
    }
    applyLabel();
  });
}

window.addEventListener("beforeprint", () => {
  quoteDocument?.setAttribute("aria-busy", "true");
});

window.addEventListener("afterprint", () => {
  quoteDocument?.removeAttribute("aria-busy");
});
