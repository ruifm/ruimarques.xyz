(() => {
  "use strict";

  const storageKey = "ruimarques-theme";
  const themes = ["light", "dark"];
  const icons = { light: "sun", dark: "moon" };
  const browserPreference = matchMedia("(prefers-color-scheme: dark)");

  function normaliseTheme(value) {
    return themes.includes(value) ? value : null;
  }

  function readTheme() {
    try {
      const storedTheme = localStorage.getItem(storageKey);
      const theme = normaliseTheme(storedTheme);
      if (storedTheme !== null && theme === null) {
        localStorage.removeItem(storageKey);
      }
      return theme;
    } catch {
      return null;
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
    if (theme === null) {
      delete document.documentElement.dataset.theme;
      return;
    }
    document.documentElement.dataset.theme = theme;
  }

  function preferredTheme() {
    return browserPreference.matches ? "dark" : "light";
  }

  function oppositeTheme(theme) {
    return theme === "dark" ? "light" : "dark";
  }

  function updateToggle(toggle, icon, theme) {
    const next = oppositeTheme(theme);
    const label = `Switch to ${next} theme`;
    icon.setAttribute("href", `/icons.svg#icon-${icons[next]}`);
    toggle.setAttribute("aria-label", label);
    toggle.title = label;
    toggle.hidden = false;
  }

  let selectedTheme = readTheme();
  applyTheme(selectedTheme);

  document.addEventListener(
    "DOMContentLoaded",
    () => {
      const toggle = document.querySelector("[data-theme-toggle]");
      const icon = document.querySelector("[data-theme-icon] use");
      if (!(toggle instanceof HTMLButtonElement) || icon === null) {
        return;
      }

      const effectiveTheme = () => selectedTheme ?? preferredTheme();
      updateToggle(toggle, icon, effectiveTheme());
      toggle.addEventListener("click", () => {
        selectedTheme = oppositeTheme(effectiveTheme());
        applyTheme(selectedTheme);
        saveTheme(selectedTheme);
        updateToggle(toggle, icon, selectedTheme);
      });
      browserPreference.addEventListener("change", () => {
        if (selectedTheme === null) {
          updateToggle(toggle, icon, preferredTheme());
        }
      });
    },
    { once: true },
  );
})();
