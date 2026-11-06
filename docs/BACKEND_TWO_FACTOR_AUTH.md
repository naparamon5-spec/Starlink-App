# Two-Factor Authentication with an Authenticator App — Backend Changes for `ardent_starlink_sandbox_api`

The Starlink mobile app no longer uses the **emailed 4-digit OTP**. The second
sign-in step is now a **6-digit code from Google Authenticator or Microsoft
Authenticator** (TOTP), the same approach as **ANI HRIS** and **eForward**. The
app side is done; this guide lists the backend changes it needs.

## How it works

| Who | Behaviour |
|---|---|
| **`end_user`** (today they get the email OTP) | **Required.** At the first sign-in after this change, the app shows a QR code to link an authenticator app. After that, every sign-in asks for a code. |
| **Everyone else** (customer, biller, admin, agent, engineer) | **Optional.** They can turn it on in *Profile → Security Settings*. Once it's on, every sign-in asks for a code. |
| Lost phone | An admin resets the user's 2FA (section 8). An `end_user` then links a new phone at their next sign-in. |

The existing in-memory `otpGuard` stays. It already ties the code step to a
password-verified sign-in (15-minute window, at most 5 wrong codes). That's
what stops anyone from signing in with an email and a code alone, which would
otherwise be possible because authenticator codes never need to be "sent".

## What the app expects (the API contract)

| Step | Request | Response the app expects |
|---|---|---|
| Sign in, 2FA on | `POST /api/v1/auth/login {email, password}` | `200` with `data: { userId, flag: false, setupRequired: false }` |
| Sign in, 2FA required but not linked yet | same | `200` with `data: { userId, flag: false, setupRequired: true, otpauthUrl, secret, issuer, account }` |
| Sign in, no 2FA | same | unchanged: `data: { accessToken, user }` plus the refresh cookie |
| Enter code | `POST /api/v1/auth/verify-otp {email, otp}` (`otp` = 6 digits) | Same body as today on success (`data: { accessToken, user }` plus the refresh cookie). On failure, a non-200 status with a `message`. |
| Status | `GET /api/v1/auth/2fa/status` (Bearer) | `data: { enabled, required }` |
| Start linking (Settings) | `POST /api/v1/auth/2fa/setup` (Bearer) | `data: { otpauthUrl, secret, issuer, account }` |
| Confirm linking (Settings) | `POST /api/v1/auth/2fa/verify {code}` (Bearer) | `2xx` once it's turned on |
| Turn off (Settings) | `POST /api/v1/auth/2fa/disable {code}` (Bearer) | `2xx`, or `403` when the role requires 2FA |

- The app recognises the 2FA step from `userId` + `flag: false` (same as
  today), so **keep `flag: false`**.
- When a `verify-otp` failure message contains **"sign in again"**, the app
  sends the user back to the password screen. The existing `SIGN_IN_AGAIN` and
  "Too many incorrect codes. Please sign in again." messages already do this.
- `POST /auth/resend-otp` isn't called any more and can be deleted.

---

## 1. Install the TOTP library

This is the same library ANI HRIS uses (`otplib` v13).

```bash
npm install otplib@^13
```

## 2. Database table

One row per user. `secret` is the linked authenticator. `pending_secret` holds
a new secret during setup or "link a new phone", so the current authenticator
keeps working until the new one is confirmed.

```sql
CREATE TABLE IF NOT EXISTS user_two_factor (
  user_id        INT         NOT NULL PRIMARY KEY,
  secret         VARCHAR(64) NULL,
  pending_secret VARCHAR(64) NULL,
  enabled        TINYINT(1)  NOT NULL DEFAULT 0,
  created_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**`models/user_two_factor.js`** (`models/index.js` loads it automatically):

```js
module.exports = function (sequelize, DataTypes) {
  return sequelize.define(
    "user_two_factor",
    {
      user_id: { type: DataTypes.INTEGER, allowNull: false, primaryKey: true },
      secret: { type: DataTypes.STRING(64), allowNull: true },
      pending_secret: { type: DataTypes.STRING(64), allowNull: true },
      enabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
      created_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
      updated_at: { type: DataTypes.DATE, allowNull: false, defaultValue: DataTypes.NOW },
    },
    { sequelize, tableName: "user_two_factor", timestamps: false }
  );
};
```

## 3. Helper: `helpers/twoFactor.js`

```js
// TOTP two-factor authentication (Google / Microsoft Authenticator), same
// approach as ANI HRIS. Required for REQUIRED_ROLES, optional for everyone else.
const otplib = require("otplib");
const db = require("../models");
const { logger } = require("../config/logger");

const ISSUER = "Ardent Starlink";
// Accept codes ±2 steps (±60s) for phone/server clock drift — same as HRIS.
// Keep the server clock synced (NTP); this is only a safety margin.
const WINDOW = 2;
const REQUIRED_ROLES = ["end_user"];

const isRequired = (user) => REQUIRED_ROLES.includes(user.role);

const get = (userId) => db.user_two_factor.findByPk(userId);

/** True when `token` is the current code for `secret`. Never throws. */
function verify(token, secret) {
  try {
    const res = otplib.verifySync({
      token: String(token || "").trim(),
      secret: String(secret || "").replace(/\s+/g, ""),
      window: WINDOW,
    });
    return !!(res && res.valid);
  } catch (err) {
    logger.warn(`2FA verify failed: ${err.message}`);
    return false;
  }
}

/**
 * Creates (or reuses) a pending secret and returns what the app needs to show
 * the QR code. Reusing the pending secret keeps the QR the same if the user
 * goes back and signs in again before finishing. The active secret, if any,
 * keeps working until activate() swaps in the new one.
 */
async function beginSetup(user) {
  const row = await get(user.id);
  const pending = (row && row.pending_secret) || otplib.generateSecret();
  if (row) await row.update({ pending_secret: pending, updated_at: new Date() });
  else await db.user_two_factor.create({ user_id: user.id, pending_secret: pending, enabled: false });

  const account = user.email || String(user.id);
  return {
    secret: pending,
    otpauthUrl: otplib.generateURI({ secret: pending, label: account, issuer: ISSUER }),
    issuer: ISSUER,
    account,
  };
}

/** Makes the pending secret the active one and turns 2FA on. */
async function activate(userId) {
  const row = await get(userId);
  if (!row || !row.pending_secret) return false;
  await row.update({
    secret: row.pending_secret,
    pending_secret: null,
    enabled: true,
    updated_at: new Date(),
  });
  return true;
}

/** Removes 2FA completely (turn off / admin reset). */
const reset = (userId) => db.user_two_factor.destroy({ where: { user_id: userId } });

module.exports = { ISSUER, isRequired, get, verify, beginSetup, activate, reset };
```

## 4. Change `POST /auth/login` in `controllers/v1/auth.controller.js`

Add the require at the top:

```js
const twoFactor = require("../../helpers/twoFactor");
```

Replace the whole `// if role is end_user, OTP required` block, which generates
the code, saves `code`/`code_expiration` and calls `mail.sendAuthentications`,
with:

```js
    // Two-factor (authenticator app): required for end users, optional for
    // everyone else once they turn it on.
    const tfa = await twoFactor.get(user.id);
    if (twoFactor.isRequired(user) || (tfa && tfa.enabled)) {
      // Only this password-verified sign-in may submit a code (15 min, 5 tries).
      otpGuard.start(user.id);

      if (tfa && tfa.enabled) {
        return set_response.success(
          res,
          { userId: user.id, flag: false, setupRequired: false },
          "Enter the code from your authenticator app",
        );
      }

      // Required but not linked yet: the app shows this QR first.
      const setup = await twoFactor.beginSetup(user);
      return set_response.success(
        res,
        { userId: user.id, flag: false, setupRequired: true, ...setup },
        "Set up your authenticator app",
      );
    }
```

Everything after that block (issuing tokens) stays the same.

## 5. Change `POST /auth/verify-otp`

Replace the route with this version. It checks the authenticator code instead
of the emailed one, and finishes linking when the account was in setup. The
part that issues tokens is unchanged.

```js
router.post("/auth/verify-otp", async (req, res) => {
  try {
    const { email, otp } = req.body;

    const user = email ? await users.findOne({ where: { email } }) : null;

    // Only after a correct password (POST /auth/login) in the last 15 minutes.
    // A code on its own never signs anyone in.
    if (!user || !otpGuard.get(user.id)) {
      return set_response.unAuthorized(res, SIGN_IN_AGAIN);
    }

    if (user.inactive === "Y") {
      otpGuard.clear(user.id);
      return set_response.unAuthorized(res, "Inactive account");
    }

    // Linked → check the active secret. Still in setup → check the pending one.
    const tfa = await twoFactor.get(user.id);
    const enrolling = !(tfa && tfa.enabled);
    const secret = enrolling ? tfa && tfa.pending_secret : tfa.secret;

    if (!secret || !twoFactor.verify(otp, secret)) {
      // At most 5 wrong codes per sign-in, then the password is needed again.
      if (otpGuard.recordFailure(user.id)) {
        return set_response.unAuthorized(
          res,
          "Too many incorrect codes. Please sign in again.",
        );
      }
      return set_response.unAuthorized(res, "Invalid authentication code");
    }

    otpGuard.clear(user.id);
    if (enrolling) await twoFactor.activate(user.id);

    const jti = randomUUID();
    const accessToken = tokenGenerator.generateAccessToken(user);
    const refreshToken = tokenGenerator.generateRefreshToken({
      userId: user.dataValues.id,
      jti,
    });

    res.cookie("refreshToken", refreshToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "strict",
      path: "/api/v1/auth",
      maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
    });

    await session.create({
      userId: user.id,
      jti,
      revoked: false,
      expiration: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    return set_response.success(
      res,
      {
        accessToken: accessToken,
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          company: user.com_eu_code,
          position: user.position,
        },
      },
      "Login Success",
    );
  } catch (error) {
    logger.error(`Verify 2FA failed: ${error.message}`);
    return set_response.serverError(res);
  }
});
```

## 6. Delete `POST /auth/resend-otp`

There's nothing to resend because authenticator codes are generated on the
phone. Delete the `router.post("/auth/resend-otp", ...)` route. `otpGuard`'s
`takeResend` / `MAX_RESENDS` and `mail.sendAuthentications` become unused and
can be removed too. The `users.code` / `users.code_expiration` columns are no
longer used for sign-in, but check that nothing else uses them (for example
password reset) before dropping them.

## 7. Settings endpoints: `controllers/v1/twoFactor.controller.js`

These are used by the app's *Security Settings → Two-Factor Authentication*
card.

```js
const express = require("express");
const router = express.Router();
const { logger } = require("../../config/logger");

const authentication = require("../../middleware/authMiddleware");
const set_response = require("../../helpers/setResponse");
const twoFactor = require("../../helpers/twoFactor");

// GET /auth/2fa/status → { enabled, required }
router.get("/auth/2fa/status", authentication, async (req, res) => {
  try {
    const tfa = await twoFactor.get(req.user.id);
    return set_response.success(res, {
      enabled: !!(tfa && tfa.enabled),
      required: twoFactor.isRequired(req.user),
    });
  } catch (error) {
    logger.error(`2FA status failed: ${error.message}`);
    return set_response.serverError(res);
  }
});

// POST /auth/2fa/setup → { otpauthUrl, secret, issuer, account }
// Also used for "Link a new phone": the current authenticator keeps working
// until /auth/2fa/verify confirms the new one.
router.post("/auth/2fa/setup", authentication, async (req, res) => {
  try {
    return set_response.success(res, await twoFactor.beginSetup(req.user));
  } catch (error) {
    logger.error(`2FA setup failed: ${error.message}`);
    return set_response.serverError(res);
  }
});

// POST /auth/2fa/verify { code } → turns 2FA on with the new authenticator
router.post("/auth/2fa/verify", authentication, async (req, res) => {
  try {
    const tfa = await twoFactor.get(req.user.id);
    if (!tfa || !tfa.pending_secret) {
      return set_response.error(res, "Start the authenticator setup first");
    }
    if (!twoFactor.verify(req.body.code, tfa.pending_secret)) {
      return set_response.error(res, "Invalid authentication code");
    }
    await twoFactor.activate(req.user.id);
    return set_response.success(res, { enabled: true }, "Two-factor authentication enabled");
  } catch (error) {
    logger.error(`2FA verify failed: ${error.message}`);
    return set_response.serverError(res);
  }
});

// POST /auth/2fa/disable { code } → turns 2FA off (not allowed when required)
router.post("/auth/2fa/disable", authentication, async (req, res) => {
  try {
    if (twoFactor.isRequired(req.user)) {
      return set_response.forbidden(res, "Two-factor authentication is required for your account");
    }
    const tfa = await twoFactor.get(req.user.id);
    if (!tfa || !tfa.enabled) return set_response.success(res, { enabled: false });
    if (!twoFactor.verify(req.body.code, tfa.secret)) {
      return set_response.error(res, "Invalid authentication code");
    }
    await twoFactor.reset(req.user.id);
    return set_response.success(res, { enabled: false }, "Two-factor authentication disabled");
  } catch (error) {
    logger.error(`2FA disable failed: ${error.message}`);
    return set_response.serverError(res);
  }
});

module.exports = router;
```

Mount it in **`index.js`** with the other v1 controllers:

```js
app.use("/api/v1/", require("./controllers/v1/twoFactor.controller"));
```

## 8. Admin reset (lost or replaced phone)

Add this to `controllers/v1/users.controller.js`, or anywhere admins manage
users. It uses the same permission rule as the other user-management actions.

```js
const twoFactor = require("../../helpers/twoFactor");
const { canManageUser } = require("../../helpers/userManagement");

// DELETE /users/:id/2fa — removes the user's authenticator. An end_user links
// a new one at their next sign-in; other roles can turn it on again in Settings.
router.delete("/users/:id/2fa", authentication, roleAuthentication, async (req, res) => {
  try {
    const target = await db.users.findByPk(req.params.id);
    if (!target) return set_response.notFound(res, "User not found");
    if (!canManageUser(req.user, target)) return set_response.forbidden(res, "Forbidden");
    await twoFactor.reset(target.id);
    return set_response.success(res, null, "Two-factor authentication reset");
  } catch (error) {
    logger.error(`2FA reset failed: ${error.message}`);
    return set_response.serverError(res);
  }
});
```

The mobile app has no button for this yet. Use the web admin or call it
directly until one is added.

---

## 9. Rollout notes

- **Existing end users** see the QR setup screen at their next sign-in. They
  need Google Authenticator or Microsoft Authenticator installed. Tell them
  before releasing.
- **Release order:** deploy the backend first, then the app. The new app
  version can't sign in end users against the old backend: the old backend
  emails a 4-digit code, but the new app asks for a 6-digit authenticator code.
- The server clock must be accurate (NTP). A drift of more than about a minute
  makes every code fail.
- `otpGuard` is in memory, so a restart in the middle of a sign-in only means
  that user enters their password again. This is the same as today.

## 10. Testing

1. Sign in as an **end user** in the app. The setup screen with the QR code
   appears. Scan it with Google or Microsoft Authenticator and enter the code;
   you're signed in, and `user_two_factor` now has `enabled = 1`.
2. Sign out and sign in again. Only the code screen appears (no QR). A correct
   code signs you in.
3. Enter 5 wrong codes. You get "Too many incorrect codes. Please sign in
   again." and the app returns to the password screen.
4. Sign in as a **customer**: no code is asked for. In *Profile → Security
   Settings*, tap *Set up*, scan, and verify. The next sign-in asks for a code.
   *Turn off* with a code turns it off again.
5. Admin reset (`DELETE /users/:id/2fa`) on the end user. Their next sign-in
   shows the QR setup again.

Generating a test code without a phone, from the backend folder:

```bash
node -e "const o=require('otplib');console.log(o.generateSync({secret:'<SECRET>'}))"
```
