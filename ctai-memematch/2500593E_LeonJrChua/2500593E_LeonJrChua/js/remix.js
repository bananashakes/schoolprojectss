/*
  Remix editor - caption a blank template without submitting a face image.

  Templates are read from the memes table. No Rekognition call is made: the
  template is chosen directly, so there is no expression to classify. Posts are
  stored with is_remix = 1 and render through the same feed card.
*/

document.addEventListener("DOMContentLoaded", async () => {
  const remixForm = document.getElementById("remixForm");
  const topInput = document.getElementById("remixTopInput");
  const bottomInput = document.getElementById("remixBottomInput");
  const searchInput = document.getElementById("templateSearch");

  let selectedTemplateId = null;

  try {
    const memes = await loadMemeCatalog();

    if (!memes.length) {
      document.getElementById("templateGallery").innerHTML =
        `<p class="page-copy">No templates are set up yet.</p>`;
      return;
    }

    selectedTemplateId = memes[0].id;

    renderTemplateGallery();
    updateSelectedTemplate();
  } catch (error) {
    console.error("Could not load templates:", error);
    showToast("Could not reach MemeMatch", "Check your connection and reload.", "spark");
    return;
  }

  [topInput, bottomInput].forEach((input) => {
    input.addEventListener("input", syncMemeText);
  });

  remixForm.addEventListener("submit", postRemix);
  searchInput.addEventListener("input", filterTemplates);

  // Hide non-matching cards rather than re-rendering, so click listeners and
  // the selected highlight survive filtering.
  function filterTemplates() {
    const query = searchInput.value.trim().toLowerCase();

    let visibleCount = 0;

    document.querySelectorAll(".template-card").forEach((card) => {
      const matches = card.dataset.search.includes(query);

      card.classList.toggle("hidden", !matches);

      if (matches) {
        visibleCount += 1;
      }
    });

    document
      .getElementById("templateEmptyState")
      .classList.toggle("hidden", visibleCount > 0);
  }

  function renderTemplateGallery() {
    const gallery = document.getElementById("templateGallery");

    // data-search holds the expression class, meme name and image filename so
    // all three are searchable.
    gallery.innerHTML = memeList
      .map(
        (template) => `
          <button class="template-card" type="button" data-template-id="${escapeAttribute(template.id)}" data-search="${escapeAttribute(`${template.expressionClass} ${template.name} ${String(template.imageUrl).split("/").pop()}`.toLowerCase())}">
            <img src="${escapeAttribute(assetUrl(template.imageUrl))}" alt="${escapeAttribute(template.name)} meme template" />
            <strong>${escapeHtml(template.name)}</strong>
          </button>
        `
      )
      .join("");

    gallery.querySelectorAll("[data-template-id]").forEach((card) => {
      card.addEventListener("click", () => {
        selectedTemplateId = card.dataset.templateId;
        updateSelectedTemplate();

        // The editor sits above the gallery; scroll it back into view.
        document
          .getElementById("remixStageImage")
          .scrollIntoView({ behavior: "smooth", block: "nearest" });
      });
    });
  }

  function updateSelectedTemplate() {
    const template = findMemeById(selectedTemplateId);

    if (!template) {
      return;
    }

    document.getElementById("currentPickNote").textContent =
      `current pick: ${template.name}`;

    const stageImage = document.getElementById("remixStageImage");

    stageImage.src = assetUrl(template.imageUrl);
    stageImage.alt = `${template.name} blank meme template`;

    document.querySelectorAll(".template-card").forEach((card) => {
      card.classList.toggle(
        "selected",
        String(card.dataset.templateId) === String(selectedTemplateId)
      );
    });
  }

  // Caption text is an HTML layer over the template image rather than being
  // composited into it. Empty lines hide their layer.
  function syncMemeText() {
    const layers = [
      ["remixTextTop", topInput],
      ["remixTextBottom", bottomInput]
    ];

    layers.forEach(([layerId, input]) => {
      const layer = document.getElementById(layerId);
      const text = input.value.trim();

      layer.textContent = text;
      layer.classList.toggle("hidden", !text);
    });
  }

  async function postRemix(event) {
    event.preventDefault();

    const topText = topInput.value.trim();
    const bottomText = bottomInput.value.trim();

    if (!topText && !bottomText) {
      showToast("Write some text first", "Add a top or bottom line before posting.", "upload");
      return;
    }

    const currentUser = getCurrentUser();

    if (!currentUser) {
      showToast("Login required", "Login before posting your remix to the feed.", "spark");

      window.setTimeout(() => {
        window.location.href = "login.html";
      }, 900);

      return;
    }

    const template = findMemeById(selectedTemplateId);

    if (!template) {
      showToast("Pick a template", "Choose a template before posting.", "upload");
      return;
    }

    const postButton = document.getElementById("postRemixBtn");
    const restoreButton = setButtonLoading(postButton, "Posting...");

    const caption = [topText, bottomText].filter(Boolean).join(" / ");

    try {
      // Remix captions publish to the same feed as analysed posts, so they go
      // through the same Comprehend toxicity check before anything is written.
      const sentiment = await apiCheckSentiment(caption, template.expressionClass);

      if (sentiment && sentiment.blocked) {
        restoreButton();
        showToast("Caption needs a rewrite", sentiment.message, "spark");
        return;
      }

      const response = await apiCreateMemePost({
        uploadedImageUrl: null,
        matchedMemeId: template.id,
        detectedEmotion: template.expressionClass,
        // No image is classified for a remix: the template is chosen directly,
        // so there is no measured confidence to record. The feed card reads
        // is_remix and shows "remix" in place of a percentage.
        confidenceScore: 0,
        classifierSource: "custom_labels",
        faceVerified: false,
        caption: caption,
        captionSentiment: sentiment ? sentiment.sentiment : null,
        sentimentMatches: sentiment ? sentiment.matches : null,
        isRemix: true,
        templateUrl: template.imageUrl,
        topText: topText,
        bottomText: bottomText
      });

      if (!response.success) {
        throw new Error(response.message || "The post could not be saved.");
      }

      restoreButton();

      showToast("Posted to the corkboard", "Your remix is now at the top of the feed.", "check");

      window.setTimeout(() => {
        window.location.href = "index.html#feed";
      }, 600);
    } catch (error) {
      restoreButton();
      console.error("Could not post remix:", error);

      showToast("Post was not saved", error.message || "Please try again.", "spark");
    }
  }
});
