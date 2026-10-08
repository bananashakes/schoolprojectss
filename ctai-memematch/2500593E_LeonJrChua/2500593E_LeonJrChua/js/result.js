/*
  Result page - review the matched meme, caption it and save the post.

  Posting sends the caption to Comprehend first: toxicity blocks publication,
  while a sentiment/expression mismatch is stored and displayed as a feature.

  Reroll re-queries RDS for another meme in the same expression class. No
  Rekognition call is repeated, as the expression is unchanged.
*/

document.addEventListener("DOMContentLoaded", () => {
  let result = readSessionValue("memematch_result", null);

  const resultContent = document.getElementById("resultContent");
  const emptyResult = document.getElementById("emptyResult");

  if (!result) {
    resultContent.classList.add("hidden");
    emptyResult.classList.remove("hidden");
    return;
  }

  displayResult();

  document.getElementById("postForm").addEventListener("submit", async (event) => {
    event.preventDefault();

    const caption = document.getElementById("caption").value.trim();

    if (!caption) {
      showFormErrors({ caption: "Write a caption before posting." });
      return;
    }

    showFormErrors({});

    const currentUser = getCurrentUser();

    if (!currentUser) {
      showToast("Login required", "Login before saving this meme to the feed.", "spark");

      window.setTimeout(() => {
        window.location.href = "login.html";
      }, 900);

      return;
    }

    const postButton = event.currentTarget.querySelector("button[type='submit']");
    const restoreButton = setButtonLoading(postButton, "Posting...");

    const activeResult = result;

    try {
      const sentiment = await apiCheckSentiment(caption, activeResult.detectedEmotion);

      // Caption flagged by Comprehend toxicity detection. Stop before any
      // write so the caption can be edited.
      if (sentiment && sentiment.blocked) {
        restoreButton();
        showFormErrors({ caption: sentiment.message });
        showToast("Caption needs a rewrite", sentiment.message, "spark");
        return;
      }

      const response = await apiCreateMemePost({
        uploadedImageUrl: activeResult.uploadedImageUrl,
        matchedMemeId: activeResult.matchedMemeId,
        detectedEmotion: activeResult.detectedEmotion,
        confidenceScore: activeResult.confidenceScore,
        classifierSource: activeResult.classifierSource,
        faceVerified: activeResult.faceVerified,
        caption: caption,
        captionSentiment: sentiment ? sentiment.sentiment : null,
        sentimentMatches: sentiment ? sentiment.matches : null
      });

      if (!response.success) {
        throw new Error(response.message || "The post could not be saved.");
      }

      writeSessionValue("memematch_result", null);
      restoreButton();

      if (sentiment && sentiment.matches === false) {
        showToast(
          "Posted, but the vibes are off",
          `Your face said ${activeResult.detectedEmotion}, your caption reads ${sentiment.sentiment.toLowerCase()}.`,
          "spark"
        );
      } else {
        showToast("Posted to the corkboard", "Your meme is now at the top of the feed.", "check");
      }

      window.setTimeout(() => {
        window.location.href = "index.html#feed";
      }, 600);
    } catch (error) {
      restoreButton();
      console.error("Could not post meme:", error);

      showToast("Post was not saved", error.message || "Please try again.", "spark");
    }
  });

  // Reroll: same expression, different meme.
  const analyseButton = document.getElementById("analyseBtn");

  analyseButton.addEventListener("click", async () => {
    const restoreButton = setButtonLoading(analyseButton, "Finding another...");

    try {
      const meme = await apiRerollMeme(result.detectedEmotion, result.matchedMemeId);

      if (!meme) {
        showToast(
          "No other match",
          `${result.detectedEmotion} only has one meme right now.`,
          "spark"
        );
        restoreButton();
        return;
      }

      result.matchedMemeId = meme.id;
      result.matchedMemeName = meme.name;
      result.matchedMemeUrl = meme.imageUrl;
      result.suggestedCaption = meme.quote || result.suggestedCaption;

      writeSessionValue("memematch_result", result);

      displayResult();
      restoreButton();

      showToast("New match", `Swapped to ${meme.name}.`, "check");
    } catch (error) {
      restoreButton();
      showToast("Could not reroll", error.message || "Please try again.", "spark");
    }
  });

  function displayResult() {
    const uploadedImage = document.getElementById("uploadedResultImage");
    const matchedMemeImage = document.getElementById("matchedMemeImage");
    const reactionTile = uploadedImage.closest(".result-tile");

    const updateReactionOrientation = () => {
      const isLandscape = uploadedImage.naturalWidth > uploadedImage.naturalHeight * 1.08;
      reactionTile.classList.toggle("is-landscape", isLandscape);
    };

    uploadedImage.onload = updateReactionOrientation;
    uploadedImage.src = assetUrl(result.uploadedImageUrl);

    if (uploadedImage.complete) {
      updateReactionOrientation();
    }

    matchedMemeImage.src = assetUrl(result.matchedMemeUrl);
    matchedMemeImage.alt = `${result.matchedMemeName} meme`;

    document.getElementById("matchedMemeName").textContent = result.matchedMemeName;
    document.getElementById("detectedEmotion").textContent = result.detectedEmotion;
    document.getElementById("confidenceScore").textContent =
      `${Number(result.confidenceScore).toFixed(1)}%`;
    document.getElementById("confidenceBar").style.width = `${result.confidenceScore}%`;

    const captionField = document.getElementById("caption");

    // Only prefill an untouched field, so a reroll never wipes what the user
    // has already typed.
    if (!captionField.value.trim()) {
      captionField.value = result.suggestedCaption || "";
    }

    renderAnalysisNotes();
  }

  /*
    Shows which model answered. When the trained model is stopped, this is what
    makes the fallback visible instead of silent.
  */
  function renderAnalysisNotes() {
    const host = document.getElementById("analysisNotes");

    if (!host) {
      return;
    }

    const notes = [];

    if (result.classifierSource === "custom_labels") {
      notes.push(`<span class="analysis-chip strong">Trained classifier</span>`);
    } else {
      notes.push(`<span class="analysis-chip">Stock emotion API (fallback)</span>`);
    }

    if (result.faceVerified) {
      notes.push(`<span class="analysis-chip verified">${icon("check")} Face verified</span>`);
    }

    if (result.faceQuality && typeof result.faceQuality.sharpness === "number") {
      notes.push(
        `<span class="analysis-chip">sharpness ${result.faceQuality.sharpness.toFixed(0)}</span>`
      );
    }

    host.innerHTML = notes.join("");
  }
});
