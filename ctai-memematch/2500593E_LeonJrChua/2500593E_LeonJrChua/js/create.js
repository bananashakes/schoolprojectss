/*
  Create page - capture or upload a reaction image and submit it for analysis.

  Two Rekognition calls are issued in parallel:
    /analyse      expression classification
    /face/verify  face-collection match against the account holder
*/

document.addEventListener("DOMContentLoaded", async () => {
  const dropZone = document.getElementById("dropZone");
  const imageInput = document.getElementById("imageUpload");
  const analyseButton = document.getElementById("analyseBtn");
  const clearTemplateButton = document.getElementById("clearTemplateBtn");

  const pageParameters = new URLSearchParams(window.location.search);

  let selectedMeme = null;
  let selectedFileDataUrl = "";
  let selectedFileName = "";

  // The catalog must load before a template id from the query string can be
  // resolved against it.
  try {
    await loadMemeCatalog();
    selectedMeme = findMemeById(pageParameters.get("template"));
    displaySelectedTemplate();
  } catch (error) {
    console.error("Could not load the meme catalog:", error);
    showToast("Could not reach MemeMatch", "Check your connection and reload.", "spark");
  }

  imageInput.addEventListener("change", () => {
    handleSelectedFile(imageInput.files[0]);
  });

  ["dragenter", "dragover"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.add("drag-over");
    });
  });

  ["dragleave", "drop"].forEach((eventName) => {
    dropZone.addEventListener(eventName, (event) => {
      event.preventDefault();
      dropZone.classList.remove("drag-over");
    });
  });

  dropZone.addEventListener("drop", (event) => {
    handleSelectedFile(event.dataTransfer.files[0]);
  });

  clearTemplateButton.addEventListener("click", () => {
    selectedMeme = null;

    document.getElementById("selectedTemplateBanner").classList.add("hidden");
    analyseButton.textContent = "Find my meme";

    const cleanUrl = new URL(window.location.href);
    cleanUrl.search = "";
    window.history.replaceState({}, "", cleanUrl);

    showToast(
      "Automatic matching selected",
      "MemeMatch will choose a template from the detected expression.",
      "check"
    );
  });

  analyseButton.addEventListener("click", async () => {
    if (!selectedFileDataUrl) {
      showToast("Choose an image", "Select a reaction photo first.", "upload");
      return;
    }

    // /analyse requires a token; fail before the round trip.
    if (!getCurrentUser()) {
      showToast("Login required", "Sign in before analysing a photo.", "spark");

      window.setTimeout(() => {
        window.location.href = "login.html";
      }, 900);

      return;
    }

    const restoreButton = setButtonLoading(
      analyseButton,
      selectedMeme ? "Creating recreation..." : "Finding a match..."
    );

    try {
      const [result, verification] = await Promise.all([
        apiAnalyzeExpression({
          fileName: selectedFileName,
          dataUrl: selectedFileDataUrl,
          templateId: selectedMeme ? selectedMeme.id : null
        }),
        apiVerifyFace(selectedFileDataUrl)
      ]);

      result.faceVerified = Boolean(verification && verification.verified);
      writeSessionValue("memematch_result", result);

      window.location.href = "result.html";
    } catch (error) {
      restoreButton();
      console.error("Could not create meme:", error);

      // The DetectFaces quality gate returns 422 with a specific reason;
      // surface it instead of a generic message.
      showToast(
        error.status === 422 ? "Try another photo" : "Could not create meme",
        error.message || "Please try another image.",
        "spark"
      );
    }
  });

  // Single entry point for both image sources: file selection and camera capture.
  function acceptImage(dataUrl, label) {
    selectedFileDataUrl = dataUrl;
    selectedFileName = label;

    document.getElementById("previewImage").src = dataUrl;
    document.getElementById("previewFrame").classList.remove("hidden");
    document.getElementById("uploadPlaceholder").classList.add("hidden");

    analyseButton.disabled = false;

    showToast("Image ready", `${label} is ready.`, "check");
  }

  function handleSelectedFile(file) {
    if (!file) {
      return;
    }

    const allowedTypes = ["image/png", "image/jpeg", "image/jpg", "image/webp"];

    if (!allowedTypes.includes(file.type)) {
      showToast("Unsupported image", "Choose a JPG, PNG or WebP image.", "upload");
      return;
    }

    if (file.size > 8 * 1024 * 1024) {
      showToast("Image is too large", "Choose an image under 8 MB.", "upload");
      return;
    }

    const reader = new FileReader();

    reader.onload = () => acceptImage(String(reader.result), file.name);
    reader.readAsDataURL(file);
  }

  /* --- camera capture --------------------------------------------------- */

  const cameraToggle = document.getElementById("cameraToggle");
  const cameraPanel = document.getElementById("cameraPanel");
  const cameraVideo = document.getElementById("cameraStream");
  const cameraError = document.getElementById("cameraError");

  let activeStream = null;

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
    cameraToggle.textContent = "Take a photo instead";
  }

  cameraToggle.addEventListener("click", () => {
    if (activeStream) {
      closeCamera();
    } else {
      openCamera();
    }
  });

  document.getElementById("cameraCancel").addEventListener("click", closeCamera);

  document.getElementById("captureBtn").addEventListener("click", () => {
    if (!activeStream) {
      return;
    }

    const canvas = document.createElement("canvas");

    canvas.width = cameraVideo.videoWidth;
    canvas.height = cameraVideo.videoHeight;

    // The preview is mirrored in CSS; the captured frame is not, so
    // Rekognition receives the image in its true orientation.
    canvas.getContext("2d").drawImage(cameraVideo, 0, 0, canvas.width, canvas.height);

    acceptImage(canvas.toDataURL("image/jpeg", 0.9), "camera photo");
    closeCamera();
  });

  // Release the camera if the page is left with the stream open.
  window.addEventListener("pagehide", closeCamera);

  function displaySelectedTemplate() {
    if (!selectedMeme) {
      return;
    }

    const banner = document.getElementById("selectedTemplateBanner");
    const templateImage = document.getElementById("selectedTemplateImage");

    templateImage.src = assetUrl(selectedMeme.imageUrl);
    templateImage.alt = `${selectedMeme.name} meme template`;

    document.getElementById("selectedTemplateName").textContent =
      `${selectedMeme.name} · ${selectedMeme.expressionClass}`;

    analyseButton.textContent = "Create with this template";

    banner.classList.remove("hidden");
  }
});
