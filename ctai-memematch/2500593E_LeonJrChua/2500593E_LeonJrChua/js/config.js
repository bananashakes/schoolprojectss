/*
  Deployment configuration - all AWS-specific values for the frontend.

  This file is served to the browser, so it must contain no secrets. Cognito
  user pool and app client ids are public identifiers by design. Database
  credentials are held in Secrets Manager and read only by the Lambdas.
*/

const CONFIG = {
  // API Gateway > the API > Stages > prod > Invoke URL. No trailing slash.
  API_BASE_URL: "https://ht4rwwem4f.execute-api.ap-southeast-2.amazonaws.com",

  // Must match the region everything else is deployed into.
  REGION: "ap-southeast-2",

  // Cognito > User pools > the pool > User pool ID.
  COGNITO_USER_POOL_ID: "ap-southeast-2_3pTXdrfSo",

  // Public SPA client with no client secret: the frontend is static files, so
  // a secret could not be kept confidential. Authentication uses SRP.
  COGNITO_CLIENT_ID: "mpabvu0giibtbj8k9c7t8frv9",

  // CloudFront domain. Blank resolves asset paths relative to the current page.
  ASSET_BASE_URL: "",
};

// Uploaded images arrive as absolute CloudFront URLs; bundled meme assets are
// relative paths. Resolve either form to a loadable URL.
function assetUrl(path) {
  if (!path) {
    return "";
  }

  if (path.startsWith("http://") || path.startsWith("https://") || path.startsWith("data:")) {
    return path;
  }

  if (!CONFIG.ASSET_BASE_URL) {
    return path;
  }

  return `${CONFIG.ASSET_BASE_URL.replace(/\/$/, "")}/${path.replace(/^\//, "")}`;
}

// An unedited config otherwise surfaces as a CORS error rather than an obvious
// configuration fault.
if (CONFIG.API_BASE_URL.includes("REPLACE_ME")) {
  console.warn(
    "%cconfig.js still has placeholder values. Fill in API_BASE_URL, " +
    "COGNITO_USER_POOL_ID and COGNITO_CLIENT_ID before testing against AWS.",
    "color:#b3261e;font-weight:bold"
  );
}
