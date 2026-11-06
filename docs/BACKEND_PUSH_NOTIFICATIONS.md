# Push Notifications (FCM) — Backend Setup for `ardent_starlink_sandbox_api`

The Starlink mobile app now supports Firebase Cloud Messaging (FCM) push
notifications, set up the same way as **ANI HRIS** and **eForward**. The app
side is done. To start sending notifications, the backend needs:

1. A table that stores each phone's FCM token.
2. Three endpoints the app calls: register, remove, and test.
3. A helper that sends pushes with `firebase-admin`.
4. Calls to that helper wherever a user should be notified, such as ticket
   status changes.

Everything below is written for this repo's stack: Express 5, Sequelize 5,
MySQL, routes mounted under `/api/v1/`, and `authMiddleware` setting
`req.user` to the `users` row.

---

## 1. Firebase project

| | |
|---|---|
| Firebase project ID | `ardent-starlink` |
| Project number | `958137090170` |
| Owner account | `naparamon5@gmail.com`, the same account as ani-hris and eforward-app |
| Console | https://console.firebase.google.com/project/ardent-starlink |
| Android app | `com.ardentnetworks.starlink` (`1:958137090170:android:29a946eaeb4280b1683bc3`) |
| iOS app | `com.ardentnetworks.starlink` (`1:958137090170:ios:9e5ebe8ee9aad991683bc3`) |
| Apple Team ID | `K9973Z86YT` |

### Which Firebase file goes where

| File | Who uses it | Where it goes |
|---|---|---|
| `google-services.json` | **Mobile app (Android)** | `Starlink-App/android/app/google-services.json`. Already in place; the backend doesn't need it. |
| `GoogleService-Info.plist` | **Mobile app (iOS)** | `Starlink-App/ios/Runner/GoogleService-Info.plist`. Already in place; the backend doesn't need it. |
| **Service-account JSON** (`*-firebase-adminsdk-*.json`) | **Backend** | `ardent_starlink_sandbox_api/config/`, or set it as an env var. See section 2. |

For reference, this is the app's `google-services.json`. It only identifies the
Firebase project, so it isn't secret, and the backend doesn't use it.

```json
{
  "project_info": {
    "project_number": "958137090170",
    "project_id": "ardent-starlink",
    "storage_bucket": "ardent-starlink.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:958137090170:android:29a946eaeb4280b1683bc3",
        "android_client_info": {
          "package_name": "com.ardentnetworks.starlink"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyBXg_j36Ab4nwMgR704qTYwigEKZ0-JYNg"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
```

---

## 2. Backend credential: the service-account key

The backend sends pushes with the Firebase Admin SDK, which needs a
**service-account private key** for the `ardent-starlink` project.

1. In the Firebase console, open `ardent-starlink`, then go to **Project
   settings → Service accounts** and click **Generate new private key**. This
   downloads a file named like `ardent-starlink-firebase-adminsdk-xxxxx.json`.
2. Give the server that key in one of these ways:
   - **File:** put the JSON in `config/` on the server, either as
     `config/fcm-service-account.json` or under its original name. The helper
     finds any `*adminsdk*.json` file in `config/`.
   - **Env var:** set `FIREBASE_SERVICE_ACCOUNT` to the whole JSON as a single
     line, or set `GOOGLE_APPLICATION_CREDENTIALS` to the file's path.
3. **Never commit this file.** Add these lines to `.gitignore`:

   ```gitignore
   # Firebase Admin SDK service account (push notifications) — never commit
   config/fcm-service-account.json
   config/*adminsdk*.json
   ```

Without the key, the helper below logs `Push disabled` and does nothing.
Device tokens are still saved, and the server runs normally.

---

## 3. Install the dependency

```bash
npm install firebase-admin@^14
```

---

## 4. Database table

The app registers one token per phone, and a user can have several phones.

```sql
-- FCM device tokens for mobile push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT          NOT NULL,
  fcm_token    VARCHAR(255) NOT NULL,
  device_id    VARCHAR(100) NULL,
  device_model VARCHAR(100) NULL,
  platform     VARCHAR(10)  NULL,          -- 'android' | 'ios'
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_device_tokens_fcm_token (fcm_token),
  KEY idx_device_tokens_user (user_id)
);
```

Sequelize model: **`models/device_tokens.js`**. `models/index.js` loads every
file in `models/`, so you don't need to register it anywhere else.

```js
// Firebase Cloud Messaging device tokens — one row per phone.
module.exports = function (sequelize, DataTypes) {
  return sequelize.define(
    "device_tokens",
    {
      id: { autoIncrement: true, type: DataTypes.INTEGER, allowNull: false, primaryKey: true },
      user_id: { type: DataTypes.INTEGER, allowNull: false },
      fcm_token: { type: DataTypes.STRING(255), allowNull: false, unique: "uq_device_tokens_fcm_token" },
      device_id: { type: DataTypes.STRING(100), allowNull: true },
      device_model: { type: DataTypes.STRING(100), allowNull: true },
      platform: { type: DataTypes.STRING(10), allowNull: true },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    },
    {
      sequelize,
      tableName: "device_tokens",
      timestamps: false,
      indexes: [{ name: "idx_device_tokens_user", fields: ["user_id"] }],
    }
  );
};
```

---

## 5. Push helper: `helpers/push.js`

```js
// Firebase Cloud Messaging sender for the mobile app (same approach as the
// ANI HRIS and eForward servers): send to every device token of a user and
// delete the ones FCM reports as dead.
//
// Credentials (service-account JSON), any of:
//   • env FIREBASE_SERVICE_ACCOUNT = the JSON string
//   • env GOOGLE_APPLICATION_CREDENTIALS = path to the file
//   • config/fcm-service-account.json, or any *adminsdk*.json in config/
// With none present, push is disabled (no-op) and the server still runs.

const fs = require("fs");
const path = require("path");
const { logger } = require("../config/logger");
const db = require("../models");

// MUST match the Android channel id the app creates (push_service.dart).
const ANDROID_CHANNEL_ID = "starlink_notifications";

let messaging = null;
let initTried = false;

function getMessaging() {
  if (initTried) return messaging;
  initTried = true;
  try {
    const { initializeApp, cert, getApps } = require("firebase-admin/app");
    const { getMessaging: adminGetMessaging } = require("firebase-admin/messaging");

    let credential;
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      credential = cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT));
    } else {
      const configDir = path.resolve(__dirname, "../config");
      let filePath =
        process.env.GOOGLE_APPLICATION_CREDENTIALS ||
        path.join(configDir, "fcm-service-account.json");
      if (!fs.existsSync(filePath)) {
        try {
          const match = fs
            .readdirSync(configDir)
            .find((f) => f.endsWith(".json") && f.includes("adminsdk"));
          if (match) filePath = path.join(configDir, match);
        } catch (_) {}
      }
      if (!fs.existsSync(filePath)) {
        logger.warn(
          "Push disabled: no Firebase service account. Set FIREBASE_SERVICE_ACCOUNT, " +
            "GOOGLE_APPLICATION_CREDENTIALS, or drop the admin SDK JSON in config/."
        );
        return null;
      }
      logger.info(`FCM using service account: ${path.basename(filePath)}`);
      credential = cert(JSON.parse(fs.readFileSync(filePath, "utf8")));
    }

    if (!getApps().length) initializeApp({ credential });
    messaging = adminGetMessaging();
    logger.info("FCM push initialized");
  } catch (err) {
    logger.warn(`Push disabled: ${err.message}`);
    messaging = null;
  }
  return messaging;
}

// FCM data values must all be strings.
function stringifyData(data = {}) {
  const out = {};
  for (const [k, v] of Object.entries(data)) {
    if (v !== null && v !== undefined) out[k] = String(v);
  }
  return out;
}

/** Saves (or re-assigns) a device token to a user. */
async function registerToken(userId, { fcm_token, device_id, device_model, platform }) {
  const tokens = db.device_tokens;
  const { Op } = db.Sequelize;
  // One row per phone: drop this phone's older tokens (rotated, or left by a
  // previous user who signed in on the same phone).
  if (device_id) {
    await tokens.destroy({ where: { device_id, fcm_token: { [Op.ne]: fcm_token } } });
  }
  const fields = {
    user_id: userId,
    device_id: device_id || null,
    device_model: device_model || null,
    platform: platform || null,
    updated_at: new Date(),
  };
  const existing = await tokens.findOne({ where: { fcm_token } });
  if (existing) await existing.update(fields);
  else await tokens.create({ ...fields, fcm_token });
}

async function removeToken(fcm_token) {
  await db.device_tokens.destroy({ where: { fcm_token } });
}

async function countTokens(userId) {
  return db.device_tokens.count({ where: { user_id: userId } });
}

/**
 * Sends a notification to every registered device of a user. Never throws.
 * @param {number} userId
 * @param {{title: string, body: string, data?: object}} payload
 */
async function notifyUser(userId, { title, body, data = {} }) {
  try {
    const fcm = getMessaging();
    if (!fcm || !userId) return { sent: 0, skipped: true };

    const rows = await db.device_tokens.findAll({
      where: { user_id: userId },
      attributes: ["fcm_token"],
      raw: true,
    });
    const tokens = rows.map((r) => String(r.fcm_token)).filter(Boolean);
    if (!tokens.length) return { sent: 0 };

    const res = await fcm.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringifyData({ title, body, ...data }),
      android: { priority: "high", notification: { channelId: ANDROID_CHANNEL_ID } },
      apns: { payload: { aps: { sound: "default" } } },
    });

    // Remove tokens FCM says are invalid / no longer registered.
    const dead = [];
    res.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        dead.push(tokens[i]);
      }
    });
    if (dead.length) {
      await db.device_tokens.destroy({ where: { fcm_token: dead } });
    }

    logger.info(
      `Push to user ${userId}: ${res.successCount}/${tokens.length} sent` +
        (dead.length ? `, ${dead.length} stale removed` : "")
    );
    return { sent: res.successCount };
  } catch (err) {
    logger.warn(`notifyUser failed: ${err.message}`);
    return { sent: 0, error: err.message };
  }
}

module.exports = { notifyUser, registerToken, removeToken, countTokens };
```

---

## 6. Endpoints: `controllers/v1/push.controller.js`

**The app already calls these routes**, so the paths and bodies must match
exactly.

| Method | Path | Auth | Body | When the app calls it |
|---|---|---|---|---|
| POST | `/api/v1/auth/fcm-token` | Bearer | `{ fcm_token, platform, device_id }` | After login, after OTP login, on session restore, and when Firebase rotates the token |
| POST | `/api/v1/auth/fcm-token/remove` | Bearer | `{ fcm_token }` | On logout, before the access token is cleared |
| POST | `/api/v1/auth/fcm-token/test` | Bearer | none | Manual test: sends a test push to the caller's own phones |

`platform` is `"android"` or `"ios"`. `device_id` is a random ID the app
generates once per install, so each phone keeps only one token row.

```js
const express = require("express");
const router = express.Router();
const { logger } = require("../../config/logger");

const authentication = require("../../middleware/authMiddleware");
const set_response = require("../../helpers/setResponse");
const push = require("../../helpers/push");

// POST /auth/fcm-token  { fcm_token, platform?, device_id?, device_model? }
router.post("/auth/fcm-token", authentication, async (req, res) => {
  const { fcm_token, device_id, device_model, platform } = req.body || {};
  if (!fcm_token) return set_response.error(res, "fcm_token is required");
  try {
    await push.registerToken(req.user.id, { fcm_token, device_id, device_model, platform });
    return res.json({ message: "registered" });
  } catch (error) {
    logger.error(`FCM token register failed: ${error.message}`);
    return set_response.serverError(res, error.message);
  }
});

// POST /auth/fcm-token/remove  { fcm_token }
router.post("/auth/fcm-token/remove", authentication, async (req, res) => {
  const { fcm_token } = req.body || {};
  if (!fcm_token) return res.json({ message: "removed" });
  try {
    await push.removeToken(fcm_token);
    return res.json({ message: "removed" });
  } catch (error) {
    logger.error(`FCM token remove failed: ${error.message}`);
    return set_response.serverError(res, error.message);
  }
});

// POST /auth/fcm-token/test — test push to the caller's own devices.
router.post("/auth/fcm-token/test", authentication, async (req, res) => {
  try {
    const tokens_registered = await push.countTokens(req.user.id);
    const result = await push.notifyUser(req.user.id, {
      title: "Test notification",
      body: "Push notifications are working.",
      data: { type: "test" },
    });
    return res.json({
      user_id: req.user.id,
      tokens_registered,
      push_sent: result.sent || 0,
      push_disabled: result.skipped === true,
      error: result.error,
    });
  } catch (error) {
    logger.error(`FCM test failed: ${error.message}`);
    return set_response.serverError(res, error.message);
  }
});

module.exports = router;
```

Mount it in **`index.js`** next to the other v1 controllers:

```js
app.use("/api/v1/", require("./controllers/v1/push.controller"));
```

---

## 7. Sending notifications from events

Call `notifyUser(userId, { title, body, data })` wherever a user should be
notified. Don't `await` it, so a push failure never fails the request.
`notifyUser` never throws.

Suggested starting points in `controllers/v1/ticket.controller.js`. Each one
notifies the ticket creator (`ticket.user_id`):

```js
const { notifyUser } = require("../../helpers/push");
```

**Accept ticket** (`PUT /tickets/accept-ticket/:id`), after the status-change
`ticketLogs.create(...)`:

```js
notifyUser(ticket.user_id, {
  title: "Ticket in progress",
  body: `Your ticket #${id} (${ticket.subject}) is now being worked on.`,
  data: { type: "ticket", ticket_id: id, status: "in_progress" },
});
```

**Resolve ticket** (`PUT /tickets/resolved/:id`), after the remarks
`ticketLogs.create(...)`:

```js
notifyUser(ticket.user_id, {
  title: "Ticket resolved",
  body: `Your ticket #${id} (${ticket.subject}) has been resolved.`,
  data: { type: "ticket", ticket_id: id, status: "resolved" },
});
```

Other good candidates: a new comment on a ticket (notify the other side), a new
ticket (notify admins and agents), and billing or subscription events.

### Payload rules

- `notification.title` / `notification.body` are what the user sees.
- Every value in `data` must be a **string**. The helper converts them for you.
- Always send `data.type`, plus an ID (for example `ticket_id`). The app will
  use these to open the right screen when the notification is tapped.
- The Android channel ID must stay `starlink_notifications`, the same as in the
  app.

---

## 8. Testing

1. Put the service-account key in `config/` and restart the API. The log
   should show `FCM push initialized`.
2. Log in on the app on a **real phone**. The iOS Simulator can't receive push.
   The app calls `POST /api/v1/auth/fcm-token`, and a row appears in
   `device_tokens`.
3. Send a test push with that user's access token:

   ```bash
   curl -X POST https://startlink-sandbox-api.ardentnetworks.com.ph/api/v1/auth/fcm-token/test \
     -H "Authorization: Bearer <ACCESS_TOKEN>"
   ```

   Expected: `tokens_registered >= 1`, `push_sent >= 1`,
   `push_disabled: false`, and the notification shows up on the phone.
4. Log out in the app. The row is deleted through `/auth/fcm-token/remove`.

| Result | Meaning |
|---|---|
| `push_disabled: true` | The server can't find the service-account key (section 2) |
| `tokens_registered: 0` | The app hasn't registered yet. Check that the routes are mounted and the user is logged in |
| Android works but iOS doesn't | The APNs `.p8` key hasn't been uploaded in Firebase (Project settings → Cloud Messaging → Apple app configuration; Team ID `K9973Z86YT`) |

---

## 9. Note found while checking

`controllers/v1/comments.controller.js` (`GET/POST /comments/:ticket_id`) is
**not mounted** in `index.js`, so the app's comment posting can't reach it.
Mount it before adding comment notifications:

```js
app.use("/api/v1/", require("./controllers/v1/comments.controller"));
```
