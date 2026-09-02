(() => {
  "use strict";

  const storageKey = "ruimarques-theme";
  const themes = ["system", "light", "dark"];
  const icons = { system: "◐", light: "☀︎", dark: "☾" };

  function normaliseTheme(value) {
    return themes.includes(value) ? value : "system";
  }

  function readTheme() {
    try {
      return normaliseTheme(localStorage.getItem(storageKey));
    } catch {
      return "system";
    }
  }

  function saveTheme(theme) {
    try {
      localStorage.setItem(storageKey, theme);
    } catch {
      return;
    }
  }

  function applyTheme(theme) {
    if (theme === "system") {
      delete document.documentElement.dataset.theme;
      return;
    }
    document.documentElement.dataset.theme = theme;
  }

  function nextTheme(theme) {
    return themes[(themes.indexOf(theme) + 1) % themes.length];
  }

  function updateToggle(toggle, icon, theme) {
    const next = nextTheme(theme);
    const label = `Theme: ${theme}. Switch to ${next} theme.`;
    icon.textContent = icons[theme];
    toggle.setAttribute("aria-label", label);
    toggle.title = label;
    toggle.hidden = false;
  }

  let currentTheme = readTheme();
  applyTheme(currentTheme);

  document.addEventListener(
    "DOMContentLoaded",
    () => {
      const toggle = document.querySelector("[data-theme-toggle]");
      const icon = document.querySelector("[data-theme-icon]");
      if (!(toggle instanceof HTMLButtonElement) || !(icon instanceof HTMLElement)) {
        return;
      }

      updateToggle(toggle, icon, currentTheme);
      toggle.addEventListener("click", () => {
        currentTheme = nextTheme(currentTheme);
        applyTheme(currentTheme);
        saveTheme(currentTheme);
        updateToggle(toggle, icon, currentTheme);
      });
    },
    { once: true },
  );
})();
