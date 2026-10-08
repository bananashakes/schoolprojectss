/*
  Login page - Cognito sign-up, email confirmation and sign-in.

  Sign-up requires email confirmation before the account is usable.
  UserNotConfirmedException on sign-in routes to the same confirmation step.

  The password is held in a closure for the post-confirmation sign-in only and
  is never persisted.
*/

document.addEventListener("DOMContentLoaded", () => {
  let authMode = "login";
  let pendingUsername = "";
  let pendingPassword = "";

  const authForm = document.getElementById("authForm");
  const usernameGroup = document.getElementById("usernameGroup");
  const submitButton = document.getElementById("authSubmit");

  const credentialsStep = document.getElementById("credentialsStep");
  const confirmStep = document.getElementById("confirmStep");
  const confirmForm = document.getElementById("confirmForm");
  const confirmEmail = document.getElementById("confirmEmail");
  const logoutButton = document.getElementById("logoutButton");

  updateSignedInPanel();

  /* --- login / register tabs ---------------------------------------- */

  document.querySelectorAll("[data-auth-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      authMode = button.dataset.authMode;

      document.querySelectorAll("[data-auth-mode]").forEach((item) => {
        item.classList.toggle("active", item === button);
      });

      usernameGroup.classList.toggle("hidden", authMode !== "register");
      document.getElementById("username").required = authMode === "register";
      submitButton.textContent = authMode === "login" ? "Login" : "Create account";

      const password = document.getElementById("password");
      password.setAttribute(
        "autocomplete",
        authMode === "login" ? "current-password" : "new-password"
      );

      showFormErrors({});
    });
  });

  /* --- sign up / sign in --------------------------------------------- */

  authForm.addEventListener("submit", async (event) => {
    event.preventDefault();

    const formData = Object.fromEntries(new FormData(authForm).entries());
    const errors = validateAuth(formData, authMode);

    showFormErrors(errors);

    if (Object.keys(errors).length) {
      return;
    }

    const email = formData.email.trim();
    const restoreButton = setButtonLoading(
      submitButton,
      authMode === "login" ? "Signing in..." : "Creating account..."
    );

    pendingPassword = formData.password;

    try {
      if (authMode === "register") {
        const result = await MMAuth.signUp({
          username: formData.username.trim(),
          email,
          password: formData.password
        });

        pendingUsername = result.username;
        restoreButton();

        if (result.confirmed) {
          // Reached only when the pool is configured to auto-confirm.
          await signInAndContinue(pendingUsername, pendingPassword);
          return;
        }

        showConfirmStep(email);
        showToast("Check your email", `We sent a confirmation code to ${email}.`, "message");
        return;
      }

      await signInAndContinue(email, formData.password);
    } catch (error) {
      restoreButton();

      // Unconfirmed accounts are recoverable: route to the confirmation step.
      if (error.code === "UserNotConfirmedException") {
        pendingUsername = email;
        showConfirmStep(email);
        showToast("Confirm your account", error.message, "spark");
        return;
      }

      showFormErrors({ password: error.message });
      showToast("Could not continue", error.message, "spark");
    }
  });

  /* --- confirmation code ---------------------------------------------- */

  if (confirmForm) {
    confirmForm.addEventListener("submit", async (event) => {
      event.preventDefault();

      const codeField = document.getElementById("code");
      const code = codeField.value.trim();

      if (!/^\d{6}$/.test(code)) {
        showFormErrors({ code: "Enter the 6-digit code from your email." });
        return;
      }

      showFormErrors({});

      const confirmButton = document.getElementById("confirmSubmit");
      const restoreButton = setButtonLoading(confirmButton, "Confirming...");

      try {
        await MMAuth.confirmSignUp(pendingUsername, code);

        showToast("Account confirmed", "Signing you in now.", "check");

        // Password retained from sign-up, so no second prompt is needed.
        if (pendingPassword) {
          await signInAndContinue(pendingUsername, pendingPassword);
          return;
        }

        restoreButton();
        showCredentialsStep();
      } catch (error) {
        restoreButton();
        showFormErrors({ code: error.message });
      }
    });

    document.getElementById("resendCode").addEventListener("click", async (event) => {
      const restoreButton = setButtonLoading(event.currentTarget, "Sending...");

      try {
        await MMAuth.resendCode(pendingUsername);
        showToast("Code sent", "Check your inbox for a new code.", "message");
      } catch (error) {
        showToast("Could not resend", error.message, "spark");
      }

      restoreButton();
    });

    document.getElementById("backToLogin").addEventListener("click", () => {
      pendingPassword = "";
      showCredentialsStep();
    });
  }

  /* --- sign out --------------------------------------------------------- */

  if (logoutButton) {
    logoutButton.addEventListener("click", async () => {
      await apiLogout();
      updateSignedInPanel();
      updateAccountLink();
      showToast("Logged out", "You can still browse the feed or sign in again.", "check");
    });
  }

  /* --- helpers ---------------------------------------------------------- */

  async function signInAndContinue(username, password) {
    await MMAuth.signIn(username, password);

    pendingPassword = "";
    updateAccountLink();

    window.location.href = "index.html";
  }

  function showConfirmStep(email) {
    if (!confirmStep) {
      return;
    }

    confirmEmail.textContent = email;
    credentialsStep.classList.add("hidden");
    confirmStep.classList.remove("hidden");

    document.getElementById("code").focus();
  }

  function showCredentialsStep() {
    if (!confirmStep) {
      return;
    }

    confirmStep.classList.add("hidden");
    credentialsStep.classList.remove("hidden");
    showFormErrors({});
  }
});

function updateSignedInPanel() {
  const currentUser = getCurrentUser();
  const panel = document.getElementById("signedInPanel");

  if (!panel) {
    return;
  }

  if (currentUser) {
    panel.classList.remove("hidden");
    document.getElementById("signedInName").textContent = currentUser.username;
    document.getElementById("signedInEmail").textContent = currentUser.email;
  } else {
    panel.classList.add("hidden");
  }
}
