/*
  Amazon Cognito authentication. Requires amazon-cognito-identity-js to be
  loaded before this file.

  Sign-in uses SRP, so the password is never transmitted. The app client must
  have ALLOW_USER_SRP_AUTH enabled and no client secret.

  Reading a Cognito session is asynchronous, but getCurrentUser() is called
  synchronously during render. A profile object is therefore mirrored into
  sessionStorage at sign-in; bootstrap() revalidates it against the real session
  on page load and clears it once the session expires.
*/

const MMAuth = (() => {
  const PROFILE_KEY = "memematch_user";

  let pool = null;

  function userPool() {
    if (pool) {
      return pool;
    }

    if (typeof AmazonCognitoIdentity === "undefined") {
      throw new Error(
        "The Cognito SDK did not load. Check the <script> tag order."
      );
    }

    pool = new AmazonCognitoIdentity.CognitoUserPool({
      UserPoolId: CONFIG.COGNITO_USER_POOL_ID,
      ClientId: CONFIG.COGNITO_CLIENT_ID,
    });

    return pool;
  }

  function cognitoUser(username) {
    return new AmazonCognitoIdentity.CognitoUser({
      Username: username,
      Pool: userPool(),
    });
  }

  /* --- the synchronous profile mirror ------------------------------- */

  function cacheProfile(session) {
    const claims = session.getIdToken().decodePayload();

    const profile = {
      // The Cognito sub is the user id in the JWT, in users.user_id and as the
      // ExternalImageId on the enrolled face.
      id: claims.sub,
      username: claims["cognito:username"] || (claims.email || "").split("@")[0],
      email: claims.email || "",
    };

    try {
      sessionStorage.setItem(PROFILE_KEY, JSON.stringify(profile));
    } catch (error) {
      console.warn("Could not cache the signed-in profile.", error);
    }

    return profile;
  }

  function clearProfile() {
    try {
      sessionStorage.removeItem(PROFILE_KEY);
    } catch (error) {
      console.warn("Could not clear the cached profile.", error);
    }
  }

  function cachedProfile() {
    try {
      const raw = sessionStorage.getItem(PROFILE_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch (error) {
      return null;
    }
  }

  /* --- session ------------------------------------------------------- */

  function getSession() {
    return new Promise((resolve) => {
      let user;

      try {
        user = userPool().getCurrentUser();
      } catch (error) {
        resolve(null);
        return;
      }

      if (!user) {
        resolve(null);
        return;
      }

      // getSession renews an expired id token while the refresh token is valid.
      user.getSession((error, session) => {
        if (error || !session || !session.isValid()) {
          resolve(null);
          return;
        }
        resolve(session);
      });
    });
  }

  async function getIdToken() {
    const session = await getSession();
    return session ? session.getIdToken().getJwtToken() : null;
  }

  // Reconcile the sessionStorage mirror with the real session. Returns the
  // profile, or null when signed out.
  async function bootstrap() {
    const session = await getSession();

    if (!session) {
      clearProfile();
      return null;
    }

    return cacheProfile(session);
  }

  /* --- registration -------------------------------------------------- */

  function signUp({ username, email, password }) {
    return new Promise((resolve, reject) => {
      const attributes = [
        new AmazonCognitoIdentity.CognitoUserAttribute({
          Name: "email",
          Value: email,
        }),
      ];

      userPool().signUp(username, password, attributes, null, (error, result) => {
        if (error) {
          reject(new Error(friendlyMessage(error)));
          return;
        }

        resolve({
          // False means a verification code was emailed and the account is
          // unusable until confirmSignUp() succeeds.
          confirmed: result.userConfirmed,
          username: result.user.getUsername(),
        });
      });
    });
  }

  function confirmSignUp(username, code) {
    return new Promise((resolve, reject) => {
      cognitoUser(username).confirmRegistration(code, true, (error) => {
        if (error) {
          reject(new Error(friendlyMessage(error)));
          return;
        }
        resolve(true);
      });
    });
  }

  function resendCode(username) {
    return new Promise((resolve, reject) => {
      cognitoUser(username).resendConfirmationCode((error) => {
        if (error) {
          reject(new Error(friendlyMessage(error)));
          return;
        }
        resolve(true);
      });
    });
  }

  /* --- sign in / out -------------------------------------------------- */

  function signIn(username, password) {
    return new Promise((resolve, reject) => {
      const details = new AmazonCognitoIdentity.AuthenticationDetails({
        Username: username,
        Password: password,
      });

      cognitoUser(username).authenticateUser(details, {
        onSuccess: (session) => resolve(cacheProfile(session)),

        onFailure: (error) => {
          // Tagged so the login page can switch to the confirmation step.
          if (error.code === "UserNotConfirmedException") {
            const wrapped = new Error(
              "This account is not confirmed yet. Enter the code we emailed you."
            );
            wrapped.code = "UserNotConfirmedException";
            reject(wrapped);
            return;
          }

          reject(new Error(friendlyMessage(error)));
        },

        newPasswordRequired: () => {
          reject(new Error(
            "This account needs a new password. Reset it in the Cognito console."
          ));
        },
      });
    });
  }

  function signOut() {
    return new Promise((resolve) => {
      try {
        const user = userPool().getCurrentUser();
        if (user) {
          user.signOut();
        }
      } catch (error) {
        console.warn("Sign-out failed, clearing the local session anyway.", error);
      }

      clearProfile();
      resolve(true);
    });
  }

  /* --- errors --------------------------------------------------------- */

  function friendlyMessage(error) {
    const map = {
      UsernameExistsException: "That username is already taken.",
      InvalidPasswordException:
        "That password does not meet the requirements. Use at least 8 characters with a number.",
      InvalidParameterException: "Check the details you entered and try again.",
      NotAuthorizedException: "Incorrect username or password.",
      UserNotFoundException: "Incorrect username or password.",
      CodeMismatchException: "That confirmation code is not right.",
      ExpiredCodeException: "That code has expired. Request a new one.",
      LimitExceededException: "Too many attempts. Wait a moment and try again.",
      TooManyRequestsException: "Too many attempts. Wait a moment and try again.",
    };

    // Cognito wraps trigger errors as "<TriggerName> failed with error
    // <message>." Unwrap to recover the message the trigger raised.
    const fromTrigger = /(?:PreSignUp|PostConfirmation|PreAuthentication) failed with error (.+?)\.?\s*$/
      .exec(error.message || "");

    if (fromTrigger) {
      return fromTrigger[1];
    }

    // NotAuthorized and UserNotFound share a message so the response does not
    // disclose which usernames exist.
    return map[error.code] || error.message || "Something went wrong. Please try again.";
  }

  return {
    bootstrap,
    getSession,
    getIdToken,
    cachedProfile,
    clearProfile,
    signUp,
    confirmSignUp,
    resendCode,
    signIn,
    signOut,
  };
})();
