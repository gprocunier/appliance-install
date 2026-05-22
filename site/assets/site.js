const docsGroups = [
  {
    title: "Tutorials",
    links: [
      ["tutorial-full", "Full Lab First Run", "tutorials/full-lab.html"],
      ["tutorial-standalone", "Standalone Foundry Build", "tutorials/standalone-foundry.html"]
    ]
  },
  {
    title: "How-To Guides",
    links: [
      ["howto-reimage", "Reimage The Cluster", "how-to/reimage-cluster.html"],
      ["howto-content", "Customize Mirrored Content", "how-to/customize-content.html"]
    ]
  },
  {
    title: "Reference",
    links: [
      ["reference-scripts", "Script Reference", "reference/scripts.html"],
      ["reference-config", "Configuration Reference", "reference/configuration.html"]
    ]
  },
  {
    title: "Explanation",
    links: [
      ["explanation-architecture", "Architecture", "explanation/architecture.html"]
    ]
  }
];

const basePath = document.body?.dataset.base || "";
const currentPage = document.body?.dataset.page || "home";
const SHIKI_CDN_URL = "https://esm.sh/shiki@4.0.2";
const SHIKI_THEME = "github-dark";
const CODEBOX_DEFAULT_LANGUAGE = "bash";
const CODEBOX_SUPPORTED_LANGUAGES = [
  "bash",
  "json",
  "text",
  "yaml"
];
const CODEBOX_LANGUAGE_ALIASES = {
  "": "text",
  console: "bash",
  plaintext: "text",
  shell: "bash",
  sh: "bash",
  yml: "yaml"
};
const CODEBOX_LANGUAGE_LABELS = {
  bash: "Shell",
  json: "JSON",
  text: "Text",
  yaml: "YAML"
};

let shikiHighlighterPromise;

const withBase = (path) => `${basePath}${path}`;

const normalizeCodeLanguage = (language) => {
  const raw = String(language || "").toLowerCase().trim();
  const normalized = CODEBOX_LANGUAGE_ALIASES[raw] || raw || CODEBOX_DEFAULT_LANGUAGE;
  return CODEBOX_SUPPORTED_LANGUAGES.includes(normalized)
    ? normalized
    : CODEBOX_DEFAULT_LANGUAGE;
};

const inferCodeLanguage = (text) => {
  const stripped = text.trim();
  if (!stripped) {
    return CODEBOX_DEFAULT_LANGUAGE;
  }

  if ((stripped.startsWith("{") || stripped.startsWith("["))) {
    try {
      JSON.parse(stripped);
      return "json";
    } catch {
      return CODEBOX_DEFAULT_LANGUAGE;
    }
  }

  if (/^\s*(apiVersion:|kind:|[A-Za-z0-9_.-]+:)/m.test(stripped)) {
    return "yaml";
  }

  return CODEBOX_DEFAULT_LANGUAGE;
};

const getCodeLanguage = (code, rawCode) => {
  const explicitClass = [...code.classList]
    .find((className) => className.startsWith("language-"));

  if (explicitClass) {
    return normalizeCodeLanguage(explicitClass.replace("language-", ""));
  }

  return inferCodeLanguage(rawCode);
};

const getHighlighter = () => {
  if (!shikiHighlighterPromise) {
    shikiHighlighterPromise = import(SHIKI_CDN_URL).then((shiki) => shiki.createHighlighter({
      themes: [SHIKI_THEME],
      langs: CODEBOX_SUPPORTED_LANGUAGES
    }));
  }

  return shikiHighlighterPromise;
};

const languageLabel = (language) => CODEBOX_LANGUAGE_LABELS[language] || language.toUpperCase();

const renderDocsNav = () => {
  const target = document.querySelector("[data-docs-nav]");
  if (!target) {
    return;
  }

  const nav = document.createElement("nav");
  nav.className = "docs-map";
  nav.setAttribute("aria-label", "Pages");

  const heading = document.createElement("h2");
  heading.textContent = "Pages";
  nav.appendChild(heading);

  const homeList = document.createElement("ul");
  homeList.className = "docs-map__links";
  const homeItem = document.createElement("li");
  const homeLink = document.createElement("a");
  homeLink.href = withBase("index.html");
  homeLink.textContent = "Start Here";
  if (currentPage === "home") {
    homeLink.classList.add("is-current");
    homeLink.setAttribute("aria-current", "page");
  }
  homeItem.appendChild(homeLink);
  homeList.appendChild(homeItem);
  nav.appendChild(homeList);

  docsGroups.forEach((group) => {
    const section = document.createElement("section");
    section.className = "docs-map__group";

    const groupHeading = document.createElement("h3");
    groupHeading.textContent = group.title;
    section.appendChild(groupHeading);

    const list = document.createElement("ul");
    list.className = "docs-map__links";

    group.links.forEach(([id, label, href]) => {
      const item = document.createElement("li");
      const link = document.createElement("a");
      link.href = withBase(href);
      link.textContent = label;
      if (id === currentPage) {
        link.classList.add("is-current");
        link.setAttribute("aria-current", "page");
      }
      item.appendChild(link);
      list.appendChild(item);
    });

    section.appendChild(list);
    nav.appendChild(section);
  });

  target.replaceWith(nav);
};

const createCodebox = (pre) => {
  if (pre.closest(".codebox")) {
    return null;
  }

  const code = pre.querySelector("code");
  if (!code) {
    return null;
  }

  const rawCode = code.textContent.replace(/\n$/, "");
  const language = getCodeLanguage(code, rawCode);
  code.classList.add(`language-${language}`);

  const codebox = document.createElement("div");
  codebox.className = "codebox";
  codebox.dataset.language = language;

  const toolbar = document.createElement("div");
  toolbar.className = "codebox__toolbar";

  const label = document.createElement("span");
  label.className = "codebox__language";
  label.textContent = languageLabel(language);

  const actions = document.createElement("div");
  actions.className = "codebox__actions";

  const wrapButton = document.createElement("button");
  wrapButton.type = "button";
  wrapButton.className = "codebox__button";
  wrapButton.textContent = "Wrap";
  wrapButton.setAttribute("aria-pressed", "false");
  wrapButton.addEventListener("click", () => {
    const wrapped = codebox.classList.toggle("codebox--wrapped");
    wrapButton.setAttribute("aria-pressed", String(wrapped));
  });

  const copyButton = document.createElement("button");
  copyButton.type = "button";
  copyButton.className = "codebox__button";
  copyButton.textContent = "Copy";
  copyButton.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(rawCode);
      copyButton.dataset.copyState = "copied";
      copyButton.textContent = "Copied";
      window.setTimeout(() => {
        copyButton.dataset.copyState = "";
        copyButton.textContent = "Copy";
      }, 1800);
    } catch {
      copyButton.dataset.copyState = "failed";
      copyButton.textContent = "Select";
    }
  });

  actions.append(wrapButton, copyButton);
  toolbar.append(label, actions);

  pre.classList.add("codebox__plain");
  pre.replaceWith(codebox);
  codebox.append(toolbar, pre);

  return { codebox, pre, rawCode, language };
};

const highlightCodebox = async ({ codebox, pre, rawCode, language }) => {
  const highlighter = await getHighlighter();
  const highlightedHtml = highlighter.codeToHtml(rawCode, {
    lang: language,
    theme: SHIKI_THEME
  });

  const template = document.createElement("template");
  template.innerHTML = highlightedHtml.trim();
  const highlightedPre = template.content.firstElementChild;
  if (!highlightedPre) {
    return;
  }

  highlightedPre.classList.add("codebox__highlight");
  highlightedPre.removeAttribute("tabindex");
  pre.replaceWith(highlightedPre);
  codebox.classList.add("codebox--highlighted");
};

const installCodeboxes = () => {
  const codeboxes = [...document.querySelectorAll("pre")]
    .map(createCodebox)
    .filter(Boolean);

  if (!codeboxes.length) {
    return;
  }

  Promise.all(codeboxes.map((codebox) => highlightCodebox(codebox)))
    .catch((error) => {
      console.warn("Shiki highlighting failed; using plain code blocks.", error);
    });
};

renderDocsNav();
installCodeboxes();
