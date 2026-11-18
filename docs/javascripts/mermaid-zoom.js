/**
 * Mermaid Lightbox & Interactive Zoom
 * Enables click-to-expand in a native <dialog> modal with pan-and-zoom for all Mermaid diagrams.
 *
 * NOTE: Zensical / Material renders Mermaid diagrams inside a closed shadow DOM
 * (attachShadow({ mode: "closed" })). Intercepting attachShadow to force
 * mode: "open" exposes the rendered SVG for cloning into the modal.
 */
(function () {
  const shadowRoots = new WeakMap();

  const origAttachShadow = Element.prototype.attachShadow;
  Element.prototype.attachShadow = function (init) {
    const root = origAttachShadow.call(this, { ...init, mode: "open" });
    shadowRoots.set(this, root);
    this._mermaidShadowRoot = root;

    if (this.classList && this.classList.contains("mermaid")) {
      try {
        const style = document.createElement("style");
        style.textContent = `
        :host {
          --_m-font: var(--md-text-font-family, "Inter", system-ui, sans-serif);
          --_m-fg: var(--md-default-fg-color, #1e293b);
          --_m-muted: var(--md-default-fg-color--light, #64748b);
          --_m-primary: var(--md-primary-fg-color, #3f51b5);
          --_m-accent: var(--md-accent-fg-color, #00bcd4);
          --_m-surface: var(--md-default-bg-color, #ffffff);
          cursor: zoom-in !important;
          display: flex !important;
          justify-content: center !important;
          align-items: center !important;
          margin-left: auto !important;
          margin-right: auto !important;
        }
        svg {
          cursor: zoom-in !important;
          display: block !important;
          margin-left: auto !important;
          margin-right: auto !important;
          font-family: var(--_m-font) !important;
        }
        * { cursor: zoom-in !important; }
        svg .node rect {
          rx: 8px;
          ry: 8px;
        }
        svg .node rect,
        svg .node polygon,
        svg .node circle,
        svg .node ellipse {
          fill: color-mix(in oklab, var(--_m-primary) 9%, var(--_m-surface)) !important;
          stroke: color-mix(in oklab, var(--_m-primary) 60%, var(--_m-fg)) !important;
          stroke-width: 1.5px !important;
        }
        svg .cluster rect {
          rx: 10px;
          ry: 10px;
          fill: color-mix(in oklab, var(--_m-accent) 5%, var(--_m-surface)) !important;
          stroke: color-mix(in oklab, var(--_m-primary) 30%, var(--_m-muted)) !important;
          stroke-width: 1.25px !important;
          stroke-dasharray: 4 3;
        }
        svg .nodeLabel,
        svg .cluster-label span,
        svg .label,
        svg text {
          color: var(--_m-fg) !important;
          fill: var(--_m-fg) !important;
          font-family: var(--_m-font) !important;
        }
        svg .edgePath .path,
        svg .flowchart-link {
          stroke: var(--_m-muted) !important;
          stroke-width: 1.5px !important;
        }
        svg .marker,
        svg marker path {
          fill: var(--_m-muted) !important;
          stroke: var(--_m-muted) !important;
        }
        svg .edgeLabel rect {
          fill: var(--_m-surface) !important;
          opacity: 0.92 !important;
          rx: 4px;
          ry: 4px;
        }
        svg .edgeLabel span,
        svg .edgeLabel p {
          background: var(--_m-surface) !important;
          color: var(--_m-fg) !important;
          padding: 1px 5px;
          border-radius: 4px;
        }
        @media (forced-colors: active) {
          svg .node rect,
          svg .node polygon,
          svg .cluster rect {
            fill: Canvas !important;
            stroke: CanvasText !important;
          }
          svg .nodeLabel,
          svg .cluster-label span,
          svg .label,
          svg text {
            color: CanvasText !important;
            fill: CanvasText !important;
          }
        }
      `;
        root.appendChild(style);
      } catch (_) {}
    }

    return root;
  };

  let lightbox = null;
  let viewport = null;
  let content = null;

  let scale = 1;
  let translateX = 0;
  let translateY = 0;
  let isDragging = false;
  let startX = 0;
  let startY = 0;

  function createIconSvg(pathData) {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("width", "18");
    svg.setAttribute("height", "18");
    svg.setAttribute("aria-hidden", "true");
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("fill", "currentColor");
    path.setAttribute("d", pathData);
    svg.appendChild(path);
    return svg;
  }

  function createToolbarButton(id, label, iconPath, extraClass) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.id = id;
    btn.className = extraClass ? `mermaid-lightbox-btn ${extraClass}` : "mermaid-lightbox-btn";
    btn.title = label;
    btn.setAttribute("aria-label", label);
    btn.appendChild(createIconSvg(iconPath));
    return btn;
  }

  function createLightbox() {
    if (lightbox) return;

    lightbox = document.createElement("dialog");
    lightbox.className = "mermaid-lightbox";
    lightbox.id = "mermaid-lightbox";
    lightbox.setAttribute("closedby", "any");
    lightbox.setAttribute("aria-label", "Mermaid diagram viewer");

    const toolbar = document.createElement("div");
    toolbar.className = "mermaid-lightbox-toolbar";

    const zoomInBtn = createToolbarButton(
      "ml-zoom-in",
      "Zoom in (+)",
      "M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14zM10 7H9v2H7v1h2v2h1v-2h2V9h-2V7z"
    );
    const zoomOutBtn = createToolbarButton(
      "ml-zoom-out",
      "Zoom out (-)",
      "M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14zM7 9h5v1H7V9z"
    );
    const resetBtn = createToolbarButton(
      "ml-reset",
      "Reset zoom (0)",
      "M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"
    );
    const closeBtn = createToolbarButton(
      "ml-close",
      "Close (Esc)",
      "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z",
      "ml-close"
    );

    toolbar.append(zoomInBtn, zoomOutBtn, resetBtn, closeBtn);

    const hint = document.createElement("div");
    hint.className = "mermaid-lightbox-hint";
    hint.textContent = "Scroll wheel to zoom · Drag to pan · Click outside or Esc to close";

    viewport = document.createElement("div");
    viewport.className = "mermaid-lightbox-viewport";
    viewport.id = "ml-viewport";

    content = document.createElement("div");
    content.className = "mermaid-lightbox-content mermaid";
    content.id = "ml-content";

    viewport.appendChild(content);
    lightbox.append(toolbar, viewport, hint);
    document.body.appendChild(lightbox);

    zoomInBtn.addEventListener("click", () => applyZoom(1.3));
    zoomOutBtn.addEventListener("click", () => applyZoom(0.77));
    resetBtn.addEventListener("click", resetTransform);
    closeBtn.addEventListener("click", () => lightbox.close());

    // Clear diagram content when dialog closes (via Esc, button, or light-dismiss)
    lightbox.addEventListener("close", () => {
      isDragging = false;
      if (viewport) viewport.style.cursor = "grab";
      if (content) content.replaceChildren();
    });

    // Fallback for browsers without <dialog closedby="any"> support (e.g. Safari)
    if (!("closedBy" in HTMLDialogElement.prototype)) {
      lightbox.addEventListener("click", (event) => {
        if (event.target !== lightbox) return;
        const rect = lightbox.getBoundingClientRect();
        const isDialogContent =
          rect.top <= event.clientY &&
          event.clientY <= rect.top + rect.height &&
          rect.left <= event.clientX &&
          event.clientX <= rect.left + rect.width;
        if (!isDialogContent) {
          lightbox.close();
        }
      });
    }

    viewport.addEventListener("wheel", onWheel, { passive: false });
    viewport.addEventListener("mousedown", onMouseDown);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mouseup", onMouseUp);

    viewport.addEventListener("dblclick", () => {
      if (scale > 1.2) {
        resetTransform();
      } else {
        applyZoom(1.8);
      }
    });

    window.addEventListener("keydown", (e) => {
      if (!lightbox || !lightbox.open) return;
      if (e.key === "+" || e.key === "=") {
        applyZoom(1.25);
      } else if (e.key === "-" || e.key === "_") {
        applyZoom(0.8);
      } else if (e.key === "0") {
        resetTransform();
      }
    });
  }

  function updateTransform() {
    if (!content) return;
    content.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`;
  }

  function applyZoom(factor) {
    scale = Math.min(Math.max(scale * factor, 0.4), 8.0);
    updateTransform();
  }

  function resetTransform() {
    scale = 1;
    translateX = 0;
    translateY = 0;
    updateTransform();
  }

  function onWheel(e) {
    e.preventDefault();
    applyZoom(e.deltaY < 0 ? 1.15 : 0.87);
  }

  function onMouseDown(e) {
    if (e.button !== 0) return;
    isDragging = true;
    startX = e.clientX - translateX;
    startY = e.clientY - translateY;
    viewport.style.cursor = "grabbing";
  }

  function onMouseMove(e) {
    if (!isDragging) return;
    translateX = e.clientX - startX;
    translateY = e.clientY - startY;
    updateTransform();
  }

  function onMouseUp() {
    if (!isDragging) return;
    isDragging = false;
    if (viewport) viewport.style.cursor = "grab";
  }

  function openLightbox(svgElement, root) {
    createLightbox();

    const clonedSvg = svgElement.cloneNode(true);

    let vbW = 0;
    let vbH = 0;
    const viewBox = svgElement.getAttribute("viewBox") || clonedSvg.getAttribute("viewBox");
    if (viewBox) {
      const parts = viewBox
        .split(/[\s,]+/)
        .map(parseFloat)
        .filter((n) => !Number.isNaN(n));
      if (parts.length >= 4 && parts[2] > 0 && parts[3] > 0) {
        vbW = parts[2];
        vbH = parts[3];
      }
    }

    if (!vbW || !vbH) {
      const rect = svgElement.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        vbW = rect.width;
        vbH = rect.height;
      }
    }

    if (!vbW || !vbH) {
      vbW = 850;
      vbH = 320;
    }

    const maxW = Math.min(window.innerWidth * 0.82, 1150);
    const maxH = window.innerHeight * 0.72;
    const aspect = vbW / vbH;

    let displayW = maxW;
    let displayH = displayW / aspect;
    if (displayH > maxH) {
      displayH = maxH;
      displayW = displayH * aspect;
    }

    displayW = Math.max(Math.round(displayW), 420);
    displayH = Math.max(Math.round(displayH), Math.round(420 / aspect));

    clonedSvg.setAttribute("viewBox", viewBox || `0 0 ${vbW} ${vbH}`);
    clonedSvg.setAttribute("width", `${displayW}`);
    clonedSvg.setAttribute("height", `${displayH}`);
    clonedSvg.style.width = `${displayW}px`;
    clonedSvg.style.height = `${displayH}px`;
    clonedSvg.style.minWidth = `${displayW}px`;
    clonedSvg.style.minHeight = `${displayH}px`;
    clonedSvg.style.maxWidth = "none";
    clonedSvg.style.maxHeight = "none";
    clonedSvg.style.display = "block";
    clonedSvg.style.overflow = "visible";

    content.replaceChildren();

    if (root) {
      root.querySelectorAll("style").forEach((s) => {
        content.appendChild(s.cloneNode(true));
      });
    }

    content.appendChild(clonedSvg);
    resetTransform();
    if (!lightbox.open) {
      lightbox.showModal();
    }
  }

  window.addEventListener(
    "click",
    (e) => {
      if (e.target.closest && e.target.closest(".mermaid-lightbox")) return;

      const path = e.composedPath ? e.composedPath() : [e.target];
      let mermaidContainer = null;
      for (const el of path) {
        if (el.classList && el.classList.contains("mermaid")) {
          mermaidContainer = el;
          break;
        }
      }
      if (!mermaidContainer && e.target.closest) {
        mermaidContainer = e.target.closest(".mermaid");
      }
      if (!mermaidContainer) return;

      let svg = null;
      for (const el of path) {
        if (el.tagName && el.tagName.toLowerCase() === "svg") {
          svg = el;
          break;
        }
      }

      const root =
        mermaidContainer.shadowRoot ||
        mermaidContainer._mermaidShadowRoot ||
        shadowRoots.get(mermaidContainer);

      if (!svg && root) {
        svg = root.querySelector("svg");
      }
      if (!svg) {
        svg = mermaidContainer.querySelector("svg");
      }

      if (svg) {
        e.preventDefault();
        e.stopPropagation();
        openLightbox(svg, root);
      }
    },
    true
  );
})();
