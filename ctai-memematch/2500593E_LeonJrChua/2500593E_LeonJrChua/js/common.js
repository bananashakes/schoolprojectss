/*
  Shared data, rendering and API layer.

  loadPosts() performs the network fetch and fills a cache;
  apiGetFeedPostsSync() reads that cache synchronously for the like, comment
  and delete handlers, which need a post lookup without awaiting.

  Script load order on every page:
    config.js -> amazon-cognito-identity.min.js -> cognito.js -> common.js -> page script
*/

/* ---------------------------------------------------------------- state */

// Populated by loadMemeCatalog() from GET /memes.
let memeList = [];

// Populated by loadPosts(); read by apiGetFeedPostsSync().
let cachedPosts = [];

const icons = {
  heart:
    "M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.6l-1-1a5.5 5.5 0 0 0-7.8 7.8l1 1L12 21l7.8-7.6 1-1a5.5 5.5 0 0 0 0-7.8z",
  message:
    "M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z",
  spark:
    "M12 2l1.9 6.1L20 10l-6.1 1.9L12 18l-1.9-6.1L4 10l6.1-1.9L12 2z",
  check:
    "M20 6L9 17l-5-5",
  upload:
    "M12 16V4m0 0l-5 5m5-5l5 5M4 20h16",
  close:
    "M18 6L6 18M6 6l12 12"
};

/* ------------------------------------------------------------ bootstrap */

document.addEventListener("DOMContentLoaded", initialiseApp);

async function initialiseApp() {
  setupNavigation();
  updateAccountLink();

  // Clears the cached profile if the Cognito session expired while the tab was
  // closed, so the nav does not show a stale signed-in state.
  try {
    await MMAuth.bootstrap();
  } catch (error) {
    console.warn("Could not restore the session.", error);
  }

  updateAccountLink();
  setupNotifications();
}

function setupNavigation() {
  const navToggle = document.getElementById("navToggle");
  const navLinks = document.getElementById("navLinks");

  if (!navToggle || !navLinks) {
    return;
  }

  navToggle.addEventListener("click", () => {
    const isOpen = navLinks.classList.toggle("open");
    navToggle.setAttribute("aria-expanded", String(isOpen));
  });

  navLinks.addEventListener("click", () => {
    navLinks.classList.remove("open");
    navToggle.setAttribute("aria-expanded", "false");
  });

  const currentPage = document.body.dataset.page;

  document.querySelectorAll("[data-page-link]").forEach((link) => {
    if (link.dataset.pageLink === currentPage) {
      link.classList.add("active");
      link.setAttribute("aria-current", "page");
    }
  });
}

/*
  In-app notifications are derived from loaded post data: likes and comments by
  other users. SNS handles email delivery separately, as a browser cannot
  subscribe to an SNS topic.
*/
let notificationsBound = false;
let visibleNotifications = [];

const NOTIFICATION_POLL_MS = 45000;
const NOTIFICATION_READ_LIFETIME = 24 * 60 * 60 * 1000;

function notificationStorageKey() {
  const currentUser = getCurrentUser();
  const userId = currentUser ? currentUser.id : "guest";

  return `memematch_notifications_${userId}`;
}

function loadNotificationState() {
  try {
    const saved = localStorage.getItem(notificationStorageKey());
    const state = JSON.parse(saved || "{}");

    return state && typeof state === "object" && !Array.isArray(state)
      ? state
      : {};
  } catch (error) {
    return {};
  }
}

function saveNotificationState(state) {
  localStorage.setItem(notificationStorageKey(), JSON.stringify(state));
}

function setupNotifications() {
  const bell = document.getElementById("bellButton");
  const panel = document.getElementById("notificationPanel");
  const badge = document.getElementById("bellBadge");

  if (!bell || !panel) {
    return;
  }

  const state = loadNotificationState();
  const now = Date.now();

  visibleNotifications = buildNotifications().filter((item) => {
    const saved = state[item.id] || {};

    if (saved.dismissedAt) {
      return false;
    }

    if (
      saved.readAt &&
      now - saved.readAt >= NOTIFICATION_READ_LIFETIME
    ) {
      return false;
    }

    return true;
  });

  const unread = visibleNotifications.filter(
    (item) => !(state[item.id] || {}).readAt
  ).length;

  panel.innerHTML = visibleNotifications.length
    ? visibleNotifications
        .map((item) => {
          const readClass = (state[item.id] || {}).readAt
            ? "is-read"
            : "is-unread";

          return `
            <div
              class="notification-item ${readClass}"
              data-notification-id="${escapeAttribute(item.id)}">
              
              <span class="notification-icon">
                ${icon(item.icon)}
              </span>

              <span>${escapeHtml(item.text)}</span>

              <span class="notification-time">
                ${escapeHtml(item.time)}
              </span>

              <button
                class="notification-dismiss"
                type="button"
                data-dismiss-notification="${escapeAttribute(item.id)}"
                aria-label="Dismiss notification">
                ${icon("close")}
              </button>
            </div>
          `;
        })
        .join("")
    : `
        <div class="notification-item notification-empty">
          <span>No activity yet.</span>
        </div>
      `;

  if (badge) {
    badge.textContent = unread;
    badge.classList.toggle("hidden", unread === 0);
  }

  bell.setAttribute(
    "aria-label",
    unread ? `Notifications, ${unread} unread` : "Notifications"
  );

  function setOpen(isOpen) {
    panel.classList.toggle("hidden", !isOpen);
    bell.setAttribute("aria-expanded", String(isOpen));

    if (!isOpen) {
      return;
    }

    const latestState = loadNotificationState();
    const readAt = Date.now();

    visibleNotifications.forEach((item) => {
      const previous = latestState[item.id] || {};

      if (!previous.readAt) {
        latestState[item.id] = {
          ...previous,
          readAt
        };
      }
    });

    saveNotificationState(latestState);

    if (badge) {
      badge.classList.add("hidden");
    }

    bell.setAttribute("aria-label", "Notifications");

    // Renders the cards again with their read appearance.
    setupNotifications();
  }

  if (notificationsBound) {
    return;
  }

  notificationsBound = true;

  bell.addEventListener("click", () => {
    setOpen(panel.classList.contains("hidden"));
  });

  panel.addEventListener("click", (event) => {
    const dismissButton = event.target.closest(
      "[data-dismiss-notification]"
    );

    if (!dismissButton) {
      return;
    }

    event.stopPropagation();

    const notificationId =
      dismissButton.dataset.dismissNotification;

    const latestState = loadNotificationState();
    const previous = latestState[notificationId] || {};

    latestState[notificationId] = {
      ...previous,
      dismissedAt: Date.now()
    };

    saveNotificationState(latestState);
    setupNotifications();

    showToast(
      "Notification removed",
      "This notification has been dismissed.",
      "check"
    );
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest("#navBell")) {
      setOpen(false);
    }
  });

  document.addEventListener("keydown", (event) => {
    if (
      event.key === "Escape" &&
      !panel.classList.contains("hidden")
    ) {
      setOpen(false);
      bell.focus();
    }
  });

  window.setInterval(async () => {
    if (!getCurrentUser()) {
      return;
    }

    try {
      await loadPosts();
      setupNotifications();
    } catch (error) {
      // The next polling cycle retries automatically.
    }
  }, NOTIFICATION_POLL_MS);
}

function buildNotifications() {
  const currentUser = getCurrentUser();

  if (!currentUser) {
    return [];
  }

  const mine = cachedPosts.filter(
    (post) => post.userId === currentUser.id
  );

  const items = [];

  mine.forEach((post) => {
    const label = post.caption
      ? `"${post.caption.slice(0, 28)}"`
      : "your meme";

    const likeCount = Number(post.likes || 0);

    if (likeCount > 0) {
      items.push({
        id: `like:${post.id}:${likeCount}`,
        icon: "heart",
        text: `${likeCount} ${
          likeCount === 1 ? "like" : "likes"
        } on ${label}`,
        time: relativeTime(post.createdAt)
      });
    }

    (post.comments || []).forEach((comment) => {
      if (comment.username === currentUser.username) {
        return;
      }

      const username = String(comment.username || "Someone");
      const commentText = String(comment.text || "");

      items.push({
        id: `comment:${post.id}:${username}:${commentText}`,
        icon: "message",
        text: `${username} commented: ${commentText.slice(0, 40)}`,
        time: relativeTime(post.createdAt)
      });
    });
  });

  return items.slice(0, 8);
}

function relativeTime(timestamp) {
  const then = new Date(timestamp).getTime();

  if (Number.isNaN(then)) {
    return "";
  }

  const minutes = Math.max(1, Math.round((Date.now() - then) / 60000));

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.round(minutes / 60);

  if (hours < 24) {
    return `${hours}h ago`;
  }

  return `${Math.round(hours / 24)}d ago`;
}

function updateAccountLink() {
  const accountLink = document.getElementById("accountLink");
  const currentUser = getCurrentUser();

  if (accountLink) {
    accountLink.textContent = currentUser ? currentUser.username : "Login";
    accountLink.setAttribute(
      "aria-label",
      currentUser ? `Account for ${currentUser.username}` : "Login or register"
    );
  }

  const demoStatus = document.getElementById("demoStatus");
  const demoMessage = document.getElementById("demoMessage");

  if (demoStatus && demoMessage) {
    if (currentUser) {
      demoStatus.textContent = "Signed in";
      demoStatus.className = "status-badge success";
      demoMessage.innerHTML = `You are signed in as <strong>${escapeHtml(currentUser.username)}</strong>.`;
    } else {
      demoStatus.textContent = "Guest mode";
      demoStatus.className = "status-badge info";
      demoMessage.textContent = "You are browsing as a guest. Login to post and view your profile.";
    }
  }
}

/* ------------------------------------------------------------- identity */

// Synchronous: page scripts read the current user during render. MMAuth keeps
// this mirror in step with the Cognito session.
function getCurrentUser() {
  return MMAuth.cachedProfile();
}

/* -------------------------------------------------------------- storage */

function readSessionValue(key, fallbackValue) {
  try {
    if (typeof sessionStorage === "undefined") {
      return fallbackValue;
    }

    const savedValue = sessionStorage.getItem(key);

    if (savedValue === null) {
      return fallbackValue;
    }

    return JSON.parse(savedValue);
  } catch (error) {
    console.warn(`Could not read ${key} from session storage.`, error);
    return fallbackValue;
  }
}

function writeSessionValue(key, value) {
  try {
    if (typeof sessionStorage === "undefined") {
      return false;
    }

    sessionStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch (error) {
    console.warn(`Could not save ${key} to session storage.`, error);
    return false;
  }
}

// Rekognition rejects raw image payloads above 5MB, which a phone photo will
// exceed. Downscale before upload.
function resizeImageDataUrl(dataUrl, { maxWidth = 1280, maxHeight = 1280, quality = 0.82 } = {}) {
  return new Promise((resolve) => {
    if (
      typeof dataUrl !== "string" ||
      !dataUrl.startsWith("data:image/") ||
      typeof Image === "undefined" ||
      typeof document === "undefined"
    ) {
      resolve(dataUrl);
      return;
    }

    const image = new Image();

    image.onload = () => {
      const scale = Math.min(1, maxWidth / image.naturalWidth, maxHeight / image.naturalHeight);

      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));

      const context = canvas.getContext("2d");

      if (!context) {
        resolve(dataUrl);
        return;
      }

      context.fillStyle = "#f4f0e7";
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);

      try {
        resolve(canvas.toDataURL("image/jpeg", quality));
      } catch (error) {
        console.warn("Could not create a smaller image preview.", error);
        resolve(dataUrl);
      }
    };

    image.onerror = () => resolve(dataUrl);
    image.src = dataUrl;
  });
}

/* ------------------------------------------------------------ transport */

class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

/*
  Single entry point for API Gateway calls.

  The Authorization header carries the Cognito ID token. API Gateway's
  authorizer verifies it before the Lambda runs, and the Lambda reads the user
  id from those verified claims rather than from the request body.
*/
async function apiFetch(path, { method = "GET", body = null, auth = true } = {}) {
  const headers = { "Content-Type": "application/json" };

  if (auth) {
    const token = await MMAuth.getIdToken();

    if (!token) {
      throw new ApiError("Sign in to continue.", 401);
    }

    headers.Authorization = token;
  }

  let response;

  try {
    response = await fetch(`${CONFIG.API_BASE_URL}${path}`, {
      method,
      headers,
      body: body === null ? undefined : JSON.stringify(body)
    });
  } catch (error) {
    // fetch rejects only on network-level failure, usually CORS or an
    // unreachable endpoint.
    console.error(`Network failure calling ${method} ${path}`, error);
    throw new ApiError("Could not reach MemeMatch. Check your connection.", 0);
  }

  let payload = {};

  try {
    payload = await response.json();
  } catch (error) {
    payload = {};
  }

  if (!response.ok) {
    throw new ApiError(payload.message || `Request failed (${response.status}).`, response.status);
  }

  return payload;
}

/* ---------------------------------------------------------------- memes */

async function loadMemeCatalog() {
  if (memeList.length) {
    return memeList;
  }

  const data = await apiFetch("/memes", { auth: false });
  memeList = data.memes || [];

  return memeList;
}

function findMemeById(memeId) {
  if (!memeId) {
    return null;
  }

  return memeList.find((meme) => String(meme.id) === String(memeId)) || null;
}

function memesForClass(expressionClass) {
  return memeList.filter((meme) => meme.expressionClass === expressionClass);
}

function expressionClasses() {
  return [...new Set(memeList.map((meme) => meme.expressionClass))];
}

/*
  Request a different meme in the same expression class. GET /memes orders by
  RAND(), so repeated calls return different rows. No Rekognition call is made:
  the expression is unchanged.

  Returns null when the class holds only one meme.
*/
async function apiRerollMeme(expressionClass, previousMemeId) {
  const data = await apiFetch(
    `/memes?expressionClass=${encodeURIComponent(expressionClass)}`,
    { auth: false }
  );

  const candidates = data.memes || [];

  const different = candidates.find(
    (meme) => String(meme.id) !== String(previousMemeId)
  );

  return different || null;
}

/* ---------------------------------------------------------------- posts */

// Fetch the feed and cache it. Renderers call this; lookups read
// apiGetFeedPostsSync().
async function loadPosts({ userId = null, emotion = null } = {}) {
  const query = new URLSearchParams();

  if (userId) {
    query.set("userId", userId);
  }

  if (emotion && emotion !== "ALL") {
    query.set("emotion", emotion);
  }

  const suffix = query.toString() ? `?${query}` : "";

  // The feed route is unauthenticated so signed-out visitors can browse.
  const data = await apiFetch(`/posts${suffix}`, { auth: false });

  cachedPosts = data.posts || [];
  return cachedPosts;
}

function apiGetFeedPostsSync() {
  return cachedPosts;
}

function apiGetProfilePostsSync(userId) {
  return cachedPosts.filter((post) => post.userId === userId);
}

/* ------------------------------------------------------------ analysis */

/*
  Image recognition call.

  Rekognition classifies the expression, then the matched meme is read from RDS
  by expression class. A supplied templateId overrides the meme selection only;
  the analysis still runs, so the recorded expression reflects the image.
*/
async function apiAnalyzeExpression(filePayload) {
  await loadMemeCatalog();

  const compressed = await resizeImageDataUrl(filePayload.dataUrl, {
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 0.85
  });

  const analysis = await apiFetch("/analyse", {
    method: "POST",
    body: { imageBase64: compressed }
  });

  let meme = findMemeById(filePayload.templateId);

  if (!meme) {
    // GET /memes orders by RAND(), so a repeat request can return a different
    // meme from the same class.
    const data = await apiFetch(
      `/memes?expressionClass=${encodeURIComponent(analysis.expressionClass)}`,
      { auth: false }
    );

    const candidates = data.memes || [];

    if (filePayload.previousMemeId && candidates.length > 1) {
      meme = candidates.find((item) => String(item.id) !== String(filePayload.previousMemeId));
    }

    meme = meme || candidates[0] || null;
  }

  if (!meme) {
    throw new ApiError(
      `No meme is set up for "${analysis.expressionClass}" yet.`,
      404
    );
  }

  const result = {
    uploadedImageUrl: analysis.uploadedImageUrl,
    detectedEmotion: analysis.expressionClass,
    confidenceScore: analysis.confidenceScore,
    classifierSource: analysis.classifierSource,
    fallbackNote: analysis.fallbackNote,
    faceQuality: analysis.faceQuality,
    matchedMemeId: meme.id,
    matchedMemeName: meme.name,
    matchedMemeUrl: meme.imageUrl,
    suggestedCaption: meme.quote || ""
  };

  if (!writeSessionValue("memematch_result", result)) {
    throw new Error("The image could not be saved for the result screen.");
  }

  return result;
}

async function apiCheckSentiment(caption, expressionClass) {
  try {
    return await apiFetch("/sentiment", {
      method: "POST",
      body: { caption, expressionClass }
    });
  } catch (error) {
    // Allow post creation when Comprehend is unavailable.
    console.warn("Sentiment check skipped.", error);
    return null;
  }
}

/* --------------------------------------------------------- face (auth) */

async function apiEnrolFace(dataUrl) {
  const compressed = await resizeImageDataUrl(dataUrl, {
    maxWidth: 1024,
    maxHeight: 1024,
    quality: 0.85
  });

  return apiFetch("/face/enrol", {
    method: "POST",
    body: { imageBase64: compressed }
  });
}

async function apiVerifyFace(dataUrl) {
  try {
    const compressed = await resizeImageDataUrl(dataUrl, {
      maxWidth: 1024,
      maxHeight: 1024,
      quality: 0.85
    });

    return await apiFetch("/face/verify", {
      method: "POST",
      body: { imageBase64: compressed }
    });
  } catch (error) {
    // An unenrolled or unverified user posts without the badge.
    console.warn("Face verification skipped.", error);
    return { verified: false };
  }
}

// Withdraws an enrolment. Rekognition deletes the stored vectors, so the badge
// stops appearing on new posts.
async function apiDeleteFace() {
  return apiFetch("/face/enrol", { method: "DELETE" });
}

async function apiFaceStatus() {
  try {
    return await apiFetch("/face/status");
  } catch (error) {
    return { enrolled: false };
  }
}

/* ------------------------------------------------------------ post CRUD */

async function apiCreateMemePost(postPayload) {
  try {
    const response = await apiFetch("/posts", {
      method: "POST",
      body: {
        uploadedImageUrl: postPayload.uploadedImageUrl,
        matchedMemeId: postPayload.matchedMemeId,
        detectedEmotion: postPayload.detectedEmotion,
        confidenceScore: postPayload.confidenceScore,
        classifierSource: postPayload.classifierSource,
        faceVerified: postPayload.faceVerified,
        caption: postPayload.caption,
        captionSentiment: postPayload.captionSentiment,
        sentimentMatches: postPayload.sentimentMatches,
        isRemix: postPayload.isRemix,
        templateUrl: postPayload.templateUrl,
        topText: postPayload.topText,
        bottomText: postPayload.bottomText
      }
    });

    return { success: true, postId: response.postId };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

async function apiUpdatePost(postId, updates) {
  try {
    const response = await apiFetch(`/posts/${encodeURIComponent(postId)}`, {
      method: "PATCH",
      body: { caption: updates.caption }
    });

    const cached = cachedPosts.find((post) => post.id === String(postId));

    if (cached) {
      cached.caption = response.caption;
    }

    return { success: true, caption: response.caption };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

async function apiDeletePost(postId) {
  try {
    await apiFetch(`/posts/${encodeURIComponent(postId)}`, { method: "DELETE" });

    cachedPosts = cachedPosts.filter((post) => post.id !== String(postId));

    return { success: true, postId };
  } catch (error) {
    return { success: false, message: error.message };
  }
}

/* ------------------------------------------------------------- social */

async function apiAddLike(postId) {
  try {
    const response = await apiFetch(`/posts/${encodeURIComponent(postId)}/likes`, {
      method: "POST"
    });

    // Update the cache so a re-render reflects the new count without refetching.
    const cached = cachedPosts.find((post) => post.id === String(postId));

    if (cached) {
      cached.likes = response.likes;
      cached.liked = response.liked;
    }

    return response;
  } catch (error) {
    showToast("Could not update like", error.message, "spark");

    const cached = cachedPosts.find((post) => post.id === String(postId));
    return { likes: cached ? cached.likes : 0, liked: cached ? cached.liked : false };
  }
}

async function apiAddComment(postId, commentText) {
  try {
    const response = await apiFetch(`/posts/${encodeURIComponent(postId)}/comments`, {
      method: "POST",
      body: { text: commentText }
    });

    const cached = cachedPosts.find((post) => post.id === String(postId));

    if (cached) {
      cached.comments = response.comments;
    }

    return response;
  } catch (error) {
    showToast("Could not add comment", error.message, "spark");
    return { comments: [] };
  }
}

/* ------------------------------------------- notification subscription */

/*
  Email delivery is an SNS subscription against the activity topic, filtered to
  the signed-in user. Subscribing returns pending: SNS emails a confirmation
  link that must be clicked before anything is delivered.
*/
async function apiGetNotificationSubscription() {
  try {
    return await apiFetch("/notifications/subscription");
  } catch (error) {
    console.warn("Could not read notification settings.", error);
    return null;
  }
}

async function apiSubscribeNotifications() {
  return apiFetch("/notifications/subscription", { method: "POST" });
}

async function apiUnsubscribeNotifications() {
  return apiFetch("/notifications/subscription", { method: "DELETE" });
}

async function apiLogout() {
  await MMAuth.signOut();
  updateAccountLink();
  return { success: true };
}

/* ---------------------------------------------------------- rendering */

function renderPostCard(post, options = {}) {
  const initials = post.username.slice(0, 2).toUpperCase();
  const comments = Array.isArray(post.comments) ? post.comments : [];
  const showManagement = options.showManagement === true;

  const uploadedImage = post.uploadedImageUrl
    ? `<img src="${escapeAttribute(assetUrl(post.uploadedImageUrl))}" alt="Uploaded ${escapeAttribute(String(post.detectedEmotion).toLowerCase())} expression" />`
    : `<div class="fallback-face" aria-label="Example expression illustration"><span class="face-mouth"></span></div>`;

  // Set when SearchFacesByImage matched the account holder's enrolled face.
  const verifiedBadge = post.faceVerified
    ? `<span class="verified-badge" title="Face verified with Amazon Rekognition">${icon("check")}</span>`
    : "";

  // Marks posts classified by the DetectFaces fallback rather than the trained
  // model.
  const sourceNote = post.classifierSource === "detect_faces"
    ? `<span class="source-note" title="The trained model was unavailable, so DetectFaces answered">fallback</span>`
    : "";

  const vibeChip = post.sentimentMatches === false
    ? `<span class="vibe-chip" title="Amazon Comprehend read the caption">caption doesn't match the face</span>`
    : "";

  const mediaBlock = post.isRemix
    ? `
      <div class="post-media post-media-remix">
        <div class="meme-stage">
          <img src="${escapeAttribute(assetUrl(post.templateUrl))}" alt="${escapeAttribute(post.matchedMemeName)} meme remix" loading="lazy" />
          ${post.topText ? `<span class="meme-text top">${escapeHtml(post.topText)}</span>` : ""}
          ${post.bottomText ? `<span class="meme-text bottom">${escapeHtml(post.bottomText)}</span>` : ""}
        </div>
      </div>
    `
    : `
      <div class="post-media">
        <div class="post-upload">${uploadedImage}</div>
        <div class="post-meme">
          <img src="${escapeAttribute(assetUrl(post.matchedMemeUrl))}" alt="${escapeAttribute(post.matchedMemeName)} meme" loading="lazy" />
        </div>
      </div>
    `;

  return `
    <article class="post-card" data-post-id="${escapeAttribute(post.id)}">
      ${mediaBlock}

      <div class="post-body">
        <div class="post-meta">
          <div class="user-chip">
            <span class="avatar">${escapeHtml(initials)}</span>
            <span>${escapeHtml(post.username)}</span>
            ${verifiedBadge}
          </div>

          <span class="emotion-badge">${escapeHtml(post.detectedEmotion)} · ${post.isRemix ? "remix" : `${Number(post.confidenceScore).toFixed(1)}%`}${sourceNote}</span>
        </div>

        <p class="post-caption">${escapeHtml(post.caption)}</p>
        ${vibeChip}

        ${
          showManagement
            ? `
              <div class="profile-post-actions">
                <button class="btn btn-secondary" type="button" data-edit-post="${escapeAttribute(post.id)}">Edit caption</button>
                <button class="btn btn-danger" type="button" data-delete-post="${escapeAttribute(post.id)}">Delete post</button>
              </div>

              <form class="edit-caption-form" data-edit-caption-form="${escapeAttribute(post.id)}" hidden>
                <label for="edit-caption-${escapeAttribute(post.id)}">Caption</label>
                <textarea id="edit-caption-${escapeAttribute(post.id)}" name="caption" maxlength="160" rows="3" required>${escapeHtml(post.caption)}</textarea>
                <p class="field-error" data-edit-error role="alert"></p>

                <div class="edit-caption-actions">
                  <button class="btn btn-primary" type="submit">Save changes</button>
                  <button class="btn btn-secondary" type="button" data-cancel-edit>Cancel</button>
                </div>
              </form>
            `
            : ""
        }

        <div class="card-actions">
          <button class="${post.liked ? "liked" : ""}" type="button" data-like="${escapeAttribute(post.id)}" aria-label="${post.liked ? "Unlike" : "Like"} post. Current likes ${post.likes}" aria-pressed="${post.liked ? "true" : "false"}">
            ${icon("heart")}
            <span>${post.likes}</span>
          </button>

          <span class="comment-count" aria-label="${comments.length} comments">
            ${icon("message")}
            ${comments.length}
          </span>
        </div>

        <form class="comment-box" data-comment-form="${escapeAttribute(post.id)}">
          <label class="visually-hidden" for="comment-${escapeAttribute(post.id)}">Add a comment</label>
          <input id="comment-${escapeAttribute(post.id)}" type="text" maxlength="80" placeholder="Add a comment" required />
          <button class="btn btn-dark" type="submit">Post</button>
        </form>

        ${
          comments.length
            ? `
              <div class="comment-list">
                ${comments
                  .slice(-3)
                  .map((comment) => {
                    const username = typeof comment === "string" ? "Guest" : comment.username || "Guest";
                    const text = typeof comment === "string" ? comment : comment.text || "";

                    return `<div class="comment-item"><strong>${escapeHtml(username)}</strong> <span>${escapeHtml(text)}</span></div>`;
                  })
                  .join("")}
              </div>
            `
            : ""
        }
      </div>
    </article>
  `;
}

function bindPostInteractions(onUpdate) {
  const signedIn = Boolean(getCurrentUser());

  document.querySelectorAll("[data-like]").forEach((button) => {
    button.addEventListener("click", async () => {
      if (!signedIn) {
        showToast("Login required", "Sign in to like posts.", "spark");
        return;
      }

      // Ignore clicks while a request is in flight. The unique key on
      // (post_id, user_id) prevents duplicate rows, but out-of-order responses
      // would leave the displayed count wrong.
      if (button.dataset.busy === "1") {
        return;
      }

      button.dataset.busy = "1";

      try {
        const response = await apiAddLike(button.dataset.like);

        button.querySelector("span").textContent = response.likes;
        button.classList.toggle("liked", response.liked);
        button.setAttribute("aria-pressed", String(response.liked));
        button.setAttribute(
          "aria-label",
          `${response.liked ? "Unlike" : "Like"} post. Current likes ${response.likes}`
        );
      } finally {
        button.dataset.busy = "";
      }
    });
  });

  document.querySelectorAll("[data-comment-form]").forEach((form) => {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();

      if (!signedIn) {
        showToast("Login required", "Sign in to comment.", "spark");
        return;
      }

      const input = form.querySelector("input");
      const button = form.querySelector("button[type='submit']");
      const comment = input.value.trim();

      if (!comment || form.dataset.busy === "1") {
        return;
      }

      // Lock the form for the round trip. Comments have no uniqueness
      // constraint, so a repeated submit would insert a duplicate row.
      form.dataset.busy = "1";
      input.disabled = true;
      button.disabled = true;

      try {
        await apiAddComment(form.dataset.commentForm, comment);

        input.value = "";
        showToast("Comment added", "Your comment has been added.", "message");
        onUpdate();
      } finally {
        form.dataset.busy = "";
        input.disabled = false;
        button.disabled = false;
      }
    });
  });
}

/* ---------------------------------------------------------------- ui */

function showToast(title, message, iconName = "spark") {
  const stack = document.getElementById("toastStack");

  if (!stack) {
    return;
  }

  const toast = document.createElement("div");
  toast.className = "toast";

  toast.innerHTML = `
    <div class="toast-icon">${icon(iconName)}</div>

    <div>
      <strong>${escapeHtml(title)}</strong>
      <span>${escapeHtml(message)}</span>
    </div>

    <button type="button" aria-label="Dismiss notification">×</button>
  `;

  toast.querySelector("button").addEventListener("click", () => toast.remove());

  stack.appendChild(toast);

  window.setTimeout(() => toast.remove(), 4300);
}

function setButtonLoading(button, label) {
  const original = button.innerHTML;

  button.disabled = true;
  button.innerHTML = `${icon("spark")} ${label}`;

  return () => {
    button.disabled = false;
    button.innerHTML = original;
  };
}

// Mirrors the Cognito pool's password policy so invalid input fails without a
// network round trip. Cognito enforces the rule server-side regardless.
function validateAuth(data, mode) {
  const errors = {};

  if (mode === "register" && (!data.username || data.username.trim().length < 3)) {
    errors.username = "Username must be at least 3 characters.";
  }

  if (mode === "register" && data.username && !/^[a-zA-Z0-9._-]+$/.test(data.username.trim())) {
    errors.username = "Use letters, numbers, dots, dashes or underscores only.";
  }

  if (!data.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) {
    errors.email = "Enter a valid email address.";
  }

  if (!data.password || data.password.length < 8) {
    errors.password = "Password must be at least 8 characters.";
  } else if (mode === "register" && !/\d/.test(data.password)) {
    errors.password = "Password must contain at least one number.";
  }

  return errors;
}

function showFormErrors(errors) {
  document.querySelectorAll(".field-error").forEach((element) => {
    element.textContent = "";
  });

  document.querySelectorAll("[aria-invalid='true']").forEach((field) => {
    field.setAttribute("aria-invalid", "false");
  });

  Object.entries(errors).forEach(([fieldName, message]) => {
    const field = document.getElementById(fieldName);
    const error = document.getElementById(`${fieldName}Error`);

    if (field) {
      field.setAttribute("aria-invalid", "true");
    }

    if (error) {
      error.textContent = message;
    }
  });
}

function getTopEmotion(posts) {
  if (!posts.length) {
    return "NONE";
  }

  const counts = posts.reduce((total, post) => {
    total[post.detectedEmotion] = (total[post.detectedEmotion] || 0) + 1;
    return total;
  }, {});

  return Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
}

function icon(name) {
  return `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${icons[name] || icons.spark}"></path></svg>`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replaceAll("`", "&#096;");
}
