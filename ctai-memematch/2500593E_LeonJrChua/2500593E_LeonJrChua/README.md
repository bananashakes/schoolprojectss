# MemeMatch
# I USED AI TO GENERATE THIS READ.MD

Leon Jr Chua · 2500593E · CAI2C09 · `ap-southeast-2`

MemeMatch reads the facial expression in an uploaded or captured photo, pairs it
with a matching reaction meme, and posts the result to a shared feed with likes
and comments.

The site is static files in S3 served through CloudFront, with an API Gateway
HTTP API in front of six Lambda functions.

## Running it

The deployed site is served from CloudFront over HTTPS. Opening the HTML files
directly from disk will not work: `js/config.js` points at a deployed API
Gateway stage, Cognito requires a real origin, and camera capture requires a
secure context.

## Pages

| Page | Purpose |
|---|---|
| `index.html` | Community feed, expression filters, activity notifications |
| `create.html` | Upload or capture a photo and analyse it |
| `result.html` | Matched meme, confidence, caption form |
| `profile.html` | Own posts, face enrolment, email notification settings |
| `remix.html` | Caption a blank meme template |
| `login.html` | Registration, email confirmation, sign in |

## Frontend

| File | Role |
|---|---|
| `js/config.js` | Deployment values: API base URL, region, Cognito ids |
| `js/cognito.js` | Cognito sign-up, confirmation and SRP sign-in |
| `js/common.js` | API layer, post rendering, notifications, shared helpers |
| `js/feed.js` | Feed, expression filters, trends, hero showcase |
| `js/create.js` | File and camera capture, expression analysis |
| `js/result.js` | Result display, caption checks, post creation |
| `js/profile.js` | Own posts, face enrolment, notification toggle |
| `js/remix.js` | Template gallery and caption overlay |
| `js/auth.js` | Login page flow |

Every `api*` function in `common.js` calls API Gateway. Writes carry the Cognito
ID token in the `Authorization` header; the feed and meme catalogue are readable
while signed out.

## Lambda functions

| Function | In VPC | Purpose |
|---|---|---|
| `mm-analyse-expression` | no | DetectFaces quality gate, Custom Labels classification, Comprehend caption checks |
| `mm-face` | no | Face enrolment, verification and withdrawal against a Rekognition collection |
| `mm-posts-crud` | yes | Posts and meme catalogue in RDS MySQL |
| `mm-social` | yes | Likes, comments, SNS activity events and subscriptions |
| `mm-post-confirmation` | yes | Cognito trigger: creates the `users` row |
| `mm-pre-signup` | no | Cognito trigger: rejects duplicate email addresses |

The split follows the VPC trust boundary. A function inside the VPC can reach
the private RDS instance but loses its route to the public AWS APIs; a function
outside it is the reverse. Two IAM roles split on the same boundary.

`lambda/mm-setup/` is a one-off bootstrap that creates the Rekognition face
collection, which has no console UI. `lambda/lambda_txt/txt/` holds a plain-text
copy of each function's source, and `lambda/lambda_txt/pymysql-layer.zip` is the
layer shared by the functions that reach RDS.

## Database

`database/schema.sql` creates five tables (`users`, `memes`, `meme_posts`,
`likes`, `comments`), seeds the meme catalogue, and creates a non-root
application user that can read and write rows but cannot alter the schema.

`memes.expression_class` must match the labels the classifier returns, or an
analysed face matches no meme.

## AWS services

S3, CloudFront, API Gateway, Lambda, Cognito, RDS MySQL, Rekognition,
Comprehend, SNS, Secrets Manager, CloudWatch, VPC.

## Configuration and secrets

All deployment-specific values live in `js/config.js`. Nothing secret is in this
repository: the Cognito user pool and app client ids are public identifiers by
design, and the database credentials are held in Secrets Manager and read only
by the Lambda functions at runtime.

## Security

- S3 bucket is private with Block Public Access enabled. CloudFront reads it
  through Origin Access Control, so no public bucket policy exists.
- HTTPS enforced; HTTP is redirected.
- RDS is not publicly accessible. Port 3306 accepts the Lambda security group as
  source rather than an IP range.
- Identity is taken from the verified Cognito JWT, never from the request body.
  Update and delete enforce ownership inside the SQL `WHERE` clause, so another
  user's row matches nothing and returns 403.
- All SQL uses parameterised queries.
- Errors are logged in full to CloudWatch and returned to the browser as a
  generic message, so no stack trace exposes the schema or the RDS endpoint.

## Known limitations

- The trained Custom Labels model was built from burst-captured frames of a
  single face. Near-duplicate frames were split across training and test sets by
  Rekognition's automatic split, so the reported evaluation overstates real
  accuracy. It is better described as a personalised expression model than a
  general classifier. The `DetectFaces` fallback covers this, and
  `meme_posts.classifier_source` records which path produced each result.
- Face verification is face matching, not liveness detection.
- Caption toxicity screening is initiated by the frontend. `mm-posts-crud` runs
  inside the VPC with the database role, so it can reach neither Comprehend nor
  the internet to screen server-side.
- Deleting a Cognito user does not remove the corresponding database row.

## Generative AI use declaration

Generative AI tools were used during this project for user interface and user
experience suggestions, code explanation, debugging, code
review and refinement, and documentation drafting. All AWS resources were
configured by the me, and all code was reviewed and tested by me
before submission.
