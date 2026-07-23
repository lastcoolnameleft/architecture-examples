(function () {
  function shouldSkipImage(img) {
    if (!img || !img.src) {
      return true;
    }

    if (img.closest("a.no-lightbox, .no-lightbox")) {
      return true;
    }

    var src = img.getAttribute("src") || "";
    if (/^data:/i.test(src)) {
      return true;
    }

    var width = img.naturalWidth || img.width;
    var height = img.naturalHeight || img.height;

    // Skip tiny images, badges, and icons.
    if (width && height && (width < 120 || height < 80)) {
      return true;
    }

    return false;
  }

  function createOverlay() {
    var overlay = document.createElement("div");
    overlay.className = "site-lightbox-overlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", "Expanded image view");

    var image = document.createElement("img");
    image.className = "site-lightbox-image";
    image.alt = "";

    var hint = document.createElement("div");
    hint.className = "site-lightbox-hint";
    hint.textContent = "Click anywhere or press Esc to close";

    overlay.appendChild(image);
    overlay.appendChild(hint);
    document.body.appendChild(overlay);

    function closeOverlay() {
      overlay.classList.remove("open");
      image.removeAttribute("src");
      image.removeAttribute("alt");
      document.body.style.overflow = "";
    }

    overlay.addEventListener("click", closeOverlay);

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && overlay.classList.contains("open")) {
        closeOverlay();
      }
    });

    return {
      open: function (src, altText) {
        image.src = src;
        image.alt = altText || "Expanded image";
        overlay.classList.add("open");
        document.body.style.overflow = "hidden";
      },
    };
  }

  function initLightbox() {
    var viewer = createOverlay();
    var images = document.querySelectorAll(
      "#main-content img, .main-content img, main img, article img, section img"
    );

    images.forEach(function (img) {
      if (shouldSkipImage(img)) {
        return;
      }

      if (img.dataset.lightboxBound === "true") {
        return;
      }

      img.dataset.lightboxBound = "true";
      img.classList.add("site-lightbox-ready");

      img.addEventListener("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        viewer.open(img.currentSrc || img.src, img.alt || "Expanded image");
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initLightbox);
  } else {
    initLightbox();
  }
})();
