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

const withBase = (path) => `${basePath}${path}`;

const renderDocsNav = () => {
  const target = document.querySelector("[data-docs-nav]");
  if (!target) {
    return;
  }

  const nav = document.createElement("nav");
  nav.className = "docs-map";
  nav.setAttribute("aria-label", "Documentation");

  const heading = document.createElement("h2");
  heading.textContent = "Documentation";
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

const installCopyButtons = () => {
  document.querySelectorAll("pre").forEach((pre) => {
    const code = pre.querySelector("code");
    if (!code) {
      return;
    }

    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy-button";
    button.textContent = "Copy";

    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(code.textContent);
        button.dataset.copyState = "copied";
        button.textContent = "Copied";
        window.setTimeout(() => {
          button.dataset.copyState = "";
          button.textContent = "Copy";
        }, 1800);
      } catch {
        button.textContent = "Select";
      }
    });

    pre.appendChild(button);
  });
};

renderDocsNav();
installCopyButtons();
