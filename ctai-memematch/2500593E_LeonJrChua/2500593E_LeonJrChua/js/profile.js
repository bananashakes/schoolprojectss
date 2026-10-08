/*
  Profile page - the signed-in user's posts, plus face enrolment.

  IndexFaces stores a face vector in the collection under the Cognito sub.
  SearchFacesByImage matches against it when a post is created; without an
  enrolment no post can carry the verified badge.
*/

document.addEventListener("DOMContentLoaded", async () => {
  await renderProfile();
  setupFaceEnrolment();
  setupNotificationPreference();
});

async function renderProfile() {
  const currentUser = getCurrentUser();
  const mainContent = document.getElementById("mainContent");

  if (!currentUser) {
    mainContent.innerHTML = `
      <section class="empty-state">
        <h1>You are logged out</h1>
        <p>Login to view your MemeMatch profile and post history.</p>
        <a class="btn btn-primary" href="login.html">Go to login</a>
      </section>
    `;

    return;
  }

  const profilePosts = document.getElementById("profilePosts");
  profilePosts.innerHTML = `<div class="empty-state"><h2>Loading your board...</h2></div>`;

  try {
    await loadPosts({ userId: currentUser.id });
  } catch (error) {
    console.error("Could not load your posts:", error);

    profilePosts.innerHTML = `
      <div class="empty-state">
        <h2>Could not reach MemeMatch</h2>
        <p>Check your connection and reload the page.</p>
      </div>
    `;

    return;
  }

  const posts = apiGetProfilePostsSync(currentUser.id);

  document.getElementById("profileName").textContent = currentUser.username;
  document.getElementById("profileEmail").textContent = currentUser.email;
  document.getElementById("profileInitials").textContent =
    currentUser.username.slice(0, 2).toUpperCase();

  document.getElementById("totalPosts").textContent = posts.length;
  document.getElementById("totalLikes").textContent =
    posts.reduce((sum, post) => sum + post.likes, 0);
  document.getElementById("topEmotion").textContent = getTopEmotion(posts);

  profilePosts.innerHTML = posts.length
    ? posts.map((post) => renderPostCard(post, { showManagement: true })).join("")
    : `
      <div class="empty-state">
        <h2>No posts yet</h2>
        <p>Your saved MemeMatch posts will appear here.</p>
        <a class="btn btn-primary" href="create.html">Create your first meme</a>
      </div>
    `;

  bindPostInteractions(renderProfile);
  bindProfilePostManagement();
  setupNotifications();
}

/* ------------------------------------------------------- face enrolment */

async function setupFaceEnrolment() {
  const input = document.getElementById("faceUpload");
  const statusText = document.getElementById("faceStatus");
  const preview = document.getElementById("facePreview");

  if (!input || !getCurrentUser()) {
    return;
  }

  const deleteButton = document.getElementById("faceDeleteBtn");

  const status = await apiFaceStatus();
  showEnrolmentStatus(status.enrolled);

  if (deleteButton) {
    deleteButton.addEventListener("click", async () => {
      const confirmed = window.confirm(
        "Remove your enrolled face? New posts will no longer carry the verified badge."
      );

      if (!confirmed) {
        return;
      }

      const restoreButton = setButtonLoading(deleteButton, "Removing...");

      try {
        await apiDeleteFace();

        preview.classList.add("hidden");
        preview.removeAttribute("src");

        restoreButton();
        showEnrolmentStatus(false);

        showToast(
          "Face removed",
          "Your stored face vector was deleted from the collection.",
          "check"
        );
      } catch (error) {
        restoreButton();
        console.error("Could not remove the enrolled face:", error);

        showToast("Could not remove", error.message || "Please try again.", "spark");
      }
    });
  }

  input.addEventListener("change", () => {
    const file = input.files[0];

    if (!file) {
      return;
    }

    if (!["image/png", "image/jpeg", "image/jpg"].includes(file.type)) {
      showToast("Unsupported image", "Enrol with a JPG or PNG photo.", "upload");
      return;
    }

    const reader = new FileReader();

    reader.onload = async () => {
      await enrol(String(reader.result));

      // Reset the input so selecting the same file again fires a change event.
      input.value = "";
    };

    reader.readAsDataURL(file);
  });

  /* --- camera capture --------------------------------------------------- */

  const cameraToggle = document.getElementById("faceCameraToggle");
  const cameraPanel = document.getElementById("faceCameraPanel");
  const cameraVideo = document.getElementById("faceCameraStream");
  const cameraError = document.getElementById("faceCameraError");

  let activeStream = null;

  if (cameraToggle) {
    cameraToggle.addEventListener("click", () => {
      if (activeStream) {
        closeCamera();
      } else {
        openCamera();
      }
    });

    document.getElementById("faceCameraCancel").addEventListener("click", closeCamera);

    document.getElementById("faceCaptureBtn").addEventListener("click", async () => {
      if (!activeStream) {
        return;
      }

      const canvas = document.createElement("canvas");

      canvas.width = cameraVideo.videoWidth;
      canvas.height = cameraVideo.videoHeight;

      // The preview is mirrored in CSS; the captured frame is not, so
      // Rekognition receives the face in its true orientation.
      canvas.getContext("2d").drawImage(cameraVideo, 0, 0, canvas.width, canvas.height);

      const dataUrl = canvas.toDataURL("image/jpeg", 0.9);

      closeCamera();
      await enrol(dataUrl);
    });

    // Release the camera if the page is left with the stream open.
    window.addEventListener("pagehide", closeCamera);
  }

  async function openCamera() {
    cameraError.textContent = "";

    // getUserMedia is only exposed on secure origins (HTTPS or localhost).
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      cameraError.textContent =
        "This browser cannot open a camera here. Upload a photo instead.";
      return;
    }

    try {
      activeStream = await navigator.mediaDevices.getUserMedia({
        // facingMode "user" selects the front camera. Dimensions are hints.
        video: { facingMode: "user", width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      });
    } catch (error) {
      cameraError.textContent =
        error.name === "NotAllowedError"
          ? "Camera permission was denied. Allow it in your browser settings, or upload a photo."
          : "No camera was available. Upload a photo instead.";
      return;
    }

    cameraVideo.srcObject = activeStream;
    cameraPanel.classList.remove("hidden");
    cameraToggle.textContent = "Close camera";
  }

  function closeCamera() {
    if (activeStream) {
      // Each track must be stopped individually or the camera stays active.
      activeStream.getTracks().forEach((track) => track.stop());
      activeStream = null;
    }

    cameraVideo.srcObject = null;
    cameraPanel.classList.add("hidden");
    cameraToggle.textContent = "Use camera";
  }

  // Shared by the file picker and the camera, so both enrol the same way.
  async function enrol(dataUrl) {
    preview.src = dataUrl;
    preview.classList.remove("hidden");

    statusText.textContent = "Enrolling your face...";
    statusText.className = "face-enrol-status pending";

    try {
      const response = await apiEnrolFace(dataUrl);

      showEnrolmentStatus(true);
      showToast(
        "Face enrolled",
        `Rekognition indexed your face at ${Number(response.confidence).toFixed(1)}% confidence.`,
        "check"
      );
    } catch (error) {
      console.error("Face enrolment failed:", error);

      statusText.textContent = error.message || "Enrolment failed. Try another photo.";
      statusText.className = "face-enrol-status failed";

      preview.classList.add("hidden");
      showToast("Could not enrol", error.message || "Try a clearer photo.", "spark");
    }
  }

  function showEnrolmentStatus(enrolled) {
    // Only offer removal when there is something stored to remove.
    if (deleteButton) {
      deleteButton.classList.toggle("hidden", !enrolled);
    }

    if (enrolled) {
      statusText.textContent = "Your face is enrolled. New posts will be verified automatically.";
      statusText.className = "face-enrol-status enrolled";
    } else {
      statusText.textContent = "Not enrolled yet. Add a clear photo of your face to get the verified badge.";
      statusText.className = "face-enrol-status";
    }
  }
}

/* --------------------------------------------------- email notifications */

/*
  The toggle manages an SNS subscription for the signed-in address, filtered to
  that user. Subscribing cannot complete here: SNS emails a confirmation link
  and delivers nothing until it is clicked.
*/
async function setupNotificationPreference() {
  const button = document.getElementById("notifyToggle");
  const statusText = document.getElementById("notifyStatus");

  if (!button || !statusText || !getCurrentUser()) {
    return;
  }

  let state = await apiGetNotificationSubscription();

  if (!state) {
    statusText.textContent = "Notification settings are unavailable right now.";
    statusText.className = "face-enrol-status failed";
    return;
  }

  showState(state);

  button.addEventListener("click", async () => {
    const restoreButton = setButtonLoading(button, "Saving...");

    try {
      const response = state.subscribed
        ? await apiUnsubscribeNotifications()
        : await apiSubscribeNotifications();

      state = response;
      restoreButton();
      showState(response);

      if (response.pending) {
        showToast(
          "Confirm your subscription",
          "Amazon SNS emailed you a confirmation link.",
          "message"
        );
      } else if (response.subscribed) {
        showToast("Email alerts on", "Activity on your posts will be emailed to you.", "check");
      } else {
        showToast("Email alerts off", "You will no longer be emailed.", "check");
      }
    } catch (error) {
      restoreButton();
      console.error("Could not update notification settings:", error);
      showToast("Could not save", error.message || "Please try again.", "spark");
    }
  });

  function showState({ subscribed, pending }) {
    if (pending) {
      // Confirmation happens in the user's inbox, so there is nothing further
      // this page can do until they return.
      statusText.textContent =
        "Almost there. Click the confirmation link Amazon SNS emailed you, then reload this page.";
      statusText.className = "face-enrol-status pending";
      button.textContent = "Waiting for confirmation";
      button.disabled = true;
      return;
    }

    button.disabled = false;

    if (subscribed) {
      statusText.textContent = "Email alerts are on for activity on your posts.";
      statusText.className = "face-enrol-status enrolled";
      button.textContent = "Turn off email alerts";
      return;
    }

    statusText.textContent = "Email alerts are off.";
    statusText.className = "face-enrol-status";
    button.textContent = "Turn on email alerts";
  }
}

/* ------------------------------------------------ post edit and delete */

function bindProfilePostManagement() {
  document.querySelectorAll("[data-edit-post]").forEach((button) => {
    button.addEventListener("click", () => {
      const postId = button.dataset.editPost;
      const card = button.closest("[data-post-id]");
      const form = card.querySelector(`[data-edit-caption-form="${postId}"]`);

      // Only one edit form open at a time.
      document.querySelectorAll("[data-edit-caption-form]").forEach((otherForm) => {
        if (otherForm !== form) {
          otherForm.hidden = true;
        }
      });

      form.hidden = false;

      const textarea = form.querySelector("textarea");
      textarea.focus();
      textarea.setSelectionRange(textarea.value.length, textarea.value.length);
    });
  });

  document.querySelectorAll("[data-cancel-edit]").forEach((button) => {
    button.addEventListener("click", () => {
      const form = button.closest("[data-edit-caption-form]");

      const post = apiGetFeedPostsSync().find(
        (item) => item.id === form.dataset.editCaptionForm
      );

      if (post) {
        form.querySelector("textarea").value = post.caption;
      }

      form.querySelector("[data-edit-error]").textContent = "";
      form.hidden = true;
    });
  });

  document.querySelectorAll("[data-edit-caption-form]").forEach((form) => {
    form.addEventListener("submit", async (event) => {
      event.preventDefault();

      const textarea = form.querySelector("textarea");
      const errorMessage = form.querySelector("[data-edit-error]");
      const caption = textarea.value.trim();

      errorMessage.textContent = "";

      if (!caption) {
        errorMessage.textContent = "Caption cannot be empty.";
        textarea.focus();
        return;
      }

      const saveButton = form.querySelector("button[type='submit']");
      const restoreButton = setButtonLoading(saveButton, "Saving...");

      const response = await apiUpdatePost(form.dataset.editCaptionForm, {
        caption: caption
      });

      restoreButton();

      if (!response.success) {
        errorMessage.textContent = response.message;
        textarea.focus();
        return;
      }

      showToast("Post updated", "Your new caption has been saved.", "check");
      renderProfile();
    });
  });

  document.querySelectorAll("[data-delete-post]").forEach((button) => {
    button.addEventListener("click", async () => {
      const postId = button.dataset.deletePost;
      const post = apiGetFeedPostsSync().find((item) => item.id === postId);

      if (!post) {
        return;
      }

      const confirmed = window.confirm(
        `Delete the post "${post.caption}"? This cannot be undone.`
      );

      if (!confirmed) {
        return;
      }

      const restoreButton = setButtonLoading(button, "Deleting...");
      const response = await apiDeletePost(postId);

      restoreButton();

      if (!response.success) {
        showToast("Could not delete post", response.message, "spark");
        return;
      }

      showToast("Post deleted", "The post was removed from your profile and feed.", "check");
      renderProfile();
    });
  });
}
