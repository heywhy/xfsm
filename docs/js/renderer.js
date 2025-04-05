let initialized = false;

window.addEventListener("exdoc:loaded", () => {
  if (!initialized) {
    mermaid.initialize({
      startOnLoad: false,
      theme: document.body.className.includes("dark") ? "dark" : "default"
    });

    initialized = true;
  }

  let id = 0;
  for (const codeEl of document.querySelectorAll("pre code.mermaid")) {
    const preEl = codeEl.parentElement;
    const graphDefinition = codeEl.textContent;
    const graphEl = document.createElement("div");
    const graphId = "mermaid-graph-" + id++;

    graphEl.style.display = "flex";
    graphEl.style.justifyContent = "center";
    graphEl.style.alignItems = "center";
    graphEl.style.margin = "2rem 0";

    mermaid.render(graphId, graphDefinition).then(({ svg, bindFunctions }) => {
      graphEl.innerHTML = svg;
      bindFunctions?.(graphEl);
      preEl.insertAdjacentElement("afterend", graphEl);
      preEl.remove();
    });
  }
});
