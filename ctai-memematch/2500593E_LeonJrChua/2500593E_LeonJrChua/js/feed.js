/*
  Home feed.

  Filter chips and the trend list are built from the expression classes present
  in the memes table, so relabelling the classifier and reseeding the table
  requires no frontend change.
*/

document.addEventListener("DOMContentLoaded", async () => {
  const feedList = document.getElementById("feedList");

  if (!feedList) {
    return;
  }

  let selectedEmotion = "ALL";

  feedList.innerHTML = `<div class="empty-state"><h2>Loading the corkboard...</h2></div>`;

  try {
    await loadMemeCatalog();
    renderFilterChips();
  } catch (error) {
    console.error("Could not load the meme catalog:", error);
  }

  await renderFeed();

  /* --- filters --------------------------------------------------------- */

  function renderFilterChips() {
    const allChip = document.querySelector('[data-filter="ALL"]');

    if (!allChip) {
      return;
    }

    const row = allChip.parentElement;

    expressionClasses().forEach((expressionClass) => {
      const chip = document.createElement("button");

      chip.type = "button";
      chip.className = "filter-chip";
      chip.dataset.filter = expressionClass;
      chip.setAttribute("aria-pressed", "false");
      chip.textContent = prettyLabel(expressionClass);

      row.appendChild(chip);
    });
  }

  // Chips are created after DOMContentLoaded, so use delegation rather than
  // binding each button.
  document.addEventListener("click", (event) => {
    const chip = event.target.closest("[data-filter]");

    if (!chip) {
      return;
    }

    selectedEmotion = chip.dataset.filter;

    document.querySelectorAll("[data-filter]").forEach((item) => {
      const active = item === chip;
      item.classList.toggle("active", active);
      item.setAttribute("aria-pressed", String(active));
    });

    renderFeed();
  });

  /* --- rendering -------------------------------------------------------- */

  async function renderFeed() {
    try {
      // Filter in SQL so unmatched posts are never transferred.
      await loadPosts({ emotion: selectedEmotion });
    } catch (error) {
      console.error("Could not load posts:", error);

      feedList.innerHTML = `
        <div class="empty-state">
          <h2>Could not reach MemeMatch</h2>
          <p>Check your connection and reload the page.</p>
        </div>
      `;

      return;
    }

    const posts = apiGetFeedPostsSync();

    feedList.innerHTML = posts.length
      ? posts.map((post) => renderPostCard(post)).join("")
      : `
        <div class="empty-state">
          <h2>No matches yet</h2>
          <p>${selectedEmotion === "ALL" ? "Be the first to post a reaction." : "Try a different expression filter."}</p>
        </div>
      `;

    bindPostInteractions(renderFeed);
    renderTrends();
    renderHeroShowcase(posts);
    setupNotifications();
  }

  /*
    Populate the hero showcase from the newest post so no fabricated confidence
    score or reaction count is displayed. The showcase is hidden entirely when
    the feed is empty.
  */
  function renderHeroShowcase(posts) {
    const showcase = document.getElementById("heroShowcase");

    if (!showcase) {
      return;
    }

    const cue = document.getElementById("heroCue");
    const newest = posts.find((post) => !post.isRemix && post.uploadedImageUrl);

    // With no post to display, hide the showcase rather than leaving the
    // markup's placeholder values on screen.
    showcase.classList.toggle("hidden", !newest);

    if (cue) {
      cue.classList.toggle("hidden", !newest);
    }

    if (!newest) {
      return;
    }

    const memeImage = showcase.querySelector(".hero-meme-card img");
    const memeCaption = showcase.querySelector(".hero-meme-caption");
    const reactionImage = showcase.querySelector(".hero-reaction-card img");
    const sticker = showcase.querySelector(".confidence-sticker");
    const notice = showcase.querySelector(".reaction-notice");

    if (memeImage) {
      memeImage.src = assetUrl(newest.matchedMemeUrl);
      memeImage.alt = `${newest.matchedMemeName} meme`;
    }

    if (memeCaption) {
      memeCaption.textContent = newest.caption;
    }

    if (reactionImage) {
      reactionImage.src = assetUrl(newest.uploadedImageUrl);
      reactionImage.alt = `Uploaded ${String(newest.detectedEmotion).toLowerCase()} expression`;
    }

    if (sticker) {
      sticker.innerHTML =
        `${Number(newest.confidenceScore).toFixed(1)}%` +
        `<small>${escapeHtml(prettyLabel(newest.detectedEmotion))}</small>`;
    }

    if (notice) {
      const count = Number(newest.likes || 0);
      notice.textContent = `${count} ${count === 1 ? "reaction" : "reactions"} · newest drop`;
    }
  }

  async function renderTrends() {
    const trendList = document.getElementById("trendList");

    if (!trendList) {
      return;
    }

    // Counted from an unfiltered read so totals are unaffected by the active
    // filter.
    let allPosts = [];

    try {
      const response = await apiFetch("/posts", { auth: false });
      allPosts = response.posts || [];
    } catch (error) {
      allPosts = apiGetFeedPostsSync();
    }

    trendList.innerHTML = expressionClasses()
      .map((expressionClass) => {
        const count = allPosts.filter((post) => post.detectedEmotion === expressionClass).length;

        return `
          <div class="trend-item">
            <strong>${escapeHtml(prettyLabel(expressionClass))}</strong>
            <span>${count} ${count === 1 ? "post" : "posts"}</span>
          </div>
        `;
      })
      .join("");
  }
});

// Converts a stored class name into display text, e.g. "neutral" -> "Neutral".
function prettyLabel(value) {
  const text = String(value).replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/*
  Hero showcase reveal animation (index.html). Removing .is-playing, forcing a
  reflow and re-adding it restarts the CSS animation. Skipped under
  prefers-reduced-motion, where the resting state matches the final frame.
*/
document.addEventListener("DOMContentLoaded", () => {
  const showcase = document.getElementById("heroShowcase");

  if (!showcase) {
    return;
  }

  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

  function playReveal() {
    if (reducedMotion.matches) {
      return;
    }

    showcase.classList.remove("is-playing");
    void showcase.offsetWidth;
    showcase.classList.add("is-playing");
  }

  showcase.addEventListener("click", playReveal);

  showcase.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      playReveal();
    }
  });
});
