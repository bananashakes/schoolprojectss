-- MemeMatch - RDS MySQL schema


CREATE DATABASE IF NOT EXISTS memematch
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE memematch;


-- Users -----------------------------------------------------------------
-- user_id is the Cognito `sub` claim, so the token is the source of truth for
-- identity and the app never invents its own user ids. Populated by the
-- Cognito PostConfirmation Lambda trigger.

CREATE TABLE IF NOT EXISTS users (
  user_id           VARCHAR(64)   NOT NULL,
  username          VARCHAR(64)   NOT NULL,
  email             VARCHAR(255)  NOT NULL,
  profile_image_url VARCHAR(512)  DEFAULT NULL,
  -- Rekognition collection FaceId from IndexFaces at enrolment.
  face_id           VARCHAR(128)  DEFAULT NULL,
  face_enrolled_at  DATETIME      DEFAULT NULL,
  created_at        DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;


-- Memes -----------------------------------------------------------------
-- expression_class matches a Custom Labels output label. Several memes may
-- share a class, which is what makes the "reroll another match" button work.

CREATE TABLE IF NOT EXISTS memes (
  meme_id          INT           NOT NULL AUTO_INCREMENT,
  meme_name        VARCHAR(120)  NOT NULL,
  meme_image_url   VARCHAR(512)  NOT NULL,
  expression_class VARCHAR(40)   NOT NULL,
  quote            VARCHAR(255)  DEFAULT NULL,
  active_status    TINYINT(1)    NOT NULL DEFAULT 1,
  created_at       DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (meme_id),
  KEY idx_memes_class (expression_class, active_status)
) ENGINE=InnoDB;


-- Posts -----------------------------------------------------------------
-- classifier_source records which path produced the result: the trained model
-- or the DetectFaces fallback. caption_sentiment holds the Comprehend result
-- for the caption/expression comparison.

CREATE TABLE IF NOT EXISTS meme_posts (
  post_id            BIGINT        NOT NULL AUTO_INCREMENT,
  user_id            VARCHAR(64)   NOT NULL,
  uploaded_image_url VARCHAR(512)  DEFAULT NULL,
  matched_meme_id    INT           DEFAULT NULL,
  detected_emotion   VARCHAR(40)   NOT NULL,
  confidence_score   DECIMAL(5,2)  NOT NULL,
  classifier_source  ENUM('custom_labels','detect_faces') NOT NULL DEFAULT 'custom_labels',
  face_verified      TINYINT(1)    NOT NULL DEFAULT 0,
  caption            VARCHAR(160)  DEFAULT NULL,
  caption_sentiment  VARCHAR(16)   DEFAULT NULL,
  sentiment_matches  TINYINT(1)    DEFAULT NULL,

  -- remix.html posts render a template with overlaid text instead of the
  -- uploaded-photo + meme pair.
  is_remix           TINYINT(1)    NOT NULL DEFAULT 0,
  template_url       VARCHAR(512)  DEFAULT NULL,
  top_text           VARCHAR(120)  DEFAULT NULL,
  bottom_text        VARCHAR(120)  DEFAULT NULL,

  created_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id),
  KEY idx_posts_user (user_id, created_at),
  KEY idx_posts_feed (created_at),
  KEY idx_posts_emotion (detected_emotion),
  CONSTRAINT fk_posts_user FOREIGN KEY (user_id)
    REFERENCES users (user_id) ON DELETE CASCADE,
  CONSTRAINT fk_posts_meme FOREIGN KEY (matched_meme_id)
    REFERENCES memes (meme_id) ON DELETE SET NULL
) ENGINE=InnoDB;


-- Likes -----------------------------------------------------------------
-- The unique key makes the like toggle idempotent, so a double-click cannot
-- inflate the count.

CREATE TABLE IF NOT EXISTS likes (
  like_id    BIGINT      NOT NULL AUTO_INCREMENT,
  post_id    BIGINT      NOT NULL,
  user_id    VARCHAR(64) NOT NULL,
  created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (like_id),
  UNIQUE KEY uq_like_once (post_id, user_id),
  CONSTRAINT fk_likes_post FOREIGN KEY (post_id)
    REFERENCES meme_posts (post_id) ON DELETE CASCADE,
  CONSTRAINT fk_likes_user FOREIGN KEY (user_id)
    REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- Comments --------------------------------------------------------------

CREATE TABLE IF NOT EXISTS comments (
  comment_id   BIGINT       NOT NULL AUTO_INCREMENT,
  post_id      BIGINT       NOT NULL,
  user_id      VARCHAR(64)  NOT NULL,
  comment_text VARCHAR(280) NOT NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (comment_id),
  KEY idx_comments_post (post_id, created_at),
  CONSTRAINT fk_comments_post FOREIGN KEY (post_id)
    REFERENCES meme_posts (post_id) ON DELETE CASCADE,
  CONSTRAINT fk_comments_user FOREIGN KEY (user_id)
    REFERENCES users (user_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- Seed: memes -----------------------------------------------------------
-- expression_class must match the labels the Custom Labels model outputs, and
-- the values EMOTION_TO_CLASS in mm-analyse-expression falls back to. A class
-- absent from this table cannot be matched, so /analyse returns 404 for it.
-- Image paths stay relative so they resolve against the CloudFront origin.

INSERT INTO memes (meme_name, meme_image_url, expression_class, quote) VALUES
  ('heh heh heh',  'assets/memes/happy.png',      'happy',    'When you bombed the test but its finally over.'),
  ('uh ouh',       'assets/memes/surprised.png',  'shocked',  'uh ouh'),
  ('Wait What?',   'assets/memes/huh.jpg',        'thinking', 'When the demo worked yesterday.'),
  ('gg',           'assets/memes/cat-look.png',   'neutral',  'WE are cooked g'),
  ('Pain Archive', 'assets/memes/sad.jpg',        'sad',      'our grades dont define us right.'),
  ('Praying',      'assets/memes/praying.jpeg',   'praying',  'US before checking OUR grades'),
  ('WHY I OUTTA',  'assets/memes/angry_meme.jpg', 'rage',     'ragebait');


-- Application user ------------------------------------------------------
-- Least privilege: the app can read and write rows but cannot alter schema or
-- drop tables. Change the password and keep it in Secrets Manager, never in a
-- Lambda environment variable.

CREATE USER IF NOT EXISTS 'memematch_app'@'%'
  IDENTIFIED BY 'CHANGE_ME_then_store_in_secrets_manager';

GRANT SELECT, INSERT, UPDATE, DELETE ON memematch.* TO 'memematch_app'@'%';
FLUSH PRIVILEGES;


-- Sanity check ----------------------------------------------------------
--   SELECT expression_class, COUNT(*) FROM memes GROUP BY expression_class;
