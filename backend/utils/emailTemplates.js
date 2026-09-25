// HTML for the "Forgot password" OTP email.
const otpEmailHtml = (otp, OTP_MINUTES) => `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Password Reset Code</title>
</head>
<body style="margin:0; padding:0; background-color:#f4f5f7; font-family:Arial, Helvetica, sans-serif;">
  <!-- Preheader (hidden preview text) -->
  <div style="display:none; max-height:0; overflow:hidden; opacity:0;">
    Your ISDR 2026 verification code is inside. It expires soon.
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f5f7; padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="480" cellpadding="0" cellspacing="0" style="max-width:480px; width:100%; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 2px 10px rgba(0,0,0,0.06);">

          <!-- Header / Brand bar -->
          <tr>
            <td style="background-color:#1e3a8a; padding:24px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="color:#ffffff; font-size:18px; font-weight:bold; letter-spacing:0.5px;">
                    ISDR 2026
                  </td>
                  <td align="right" style="color:#c7d2fe; font-size:12px;">
                    Security Verification
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 32px 24px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding-bottom:8px;">
                    <!-- Icon circle -->
                    <table role="presentation" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="width:56px; height:56px; border-radius:50%; background-color:#eef2ff; text-align:center; vertical-align:middle; font-size:26px;">
                          🔐
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <h1 style="margin:20px 0 8px 0; font-size:20px; color:#111827; text-align:center;">
                Reset your password
              </h1>
              <p style="margin:0 0 24px 0; font-size:14px; line-height:22px; color:#6b7280; text-align:center;">
                Use the verification code below to continue resetting your password.
              </p>

              <!-- OTP Box -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center" style="padding:20px; background-color:#f5f7ff; border:1px dashed #c7d2fe; border-radius:10px;">
                    <span style="font-size:34px; font-weight:bold; letter-spacing:10px; color:#2563eb; font-family:'Courier New', monospace;">
                      ${otp}
                    </span>
                  </td>
                </tr>
              </table>

              <p style="margin:20px 0 0 0; font-size:13px; line-height:20px; color:#6b7280; text-align:center;">
                This code expires in <strong style="color:#111827;">${OTP_MINUTES} minutes</strong>.
                Do not share it with anyone.
              </p>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding:0 32px;">
              <hr style="border:none; border-top:1px solid #e5e7eb; margin:0;">
            </td>
          </tr>

          <!-- Security note -->
          <tr>
            <td style="padding:20px 32px 28px 32px;">
              <p style="margin:0; font-size:12px; line-height:18px; color:#9ca3af; text-align:center;">
                If you did not request this password reset, you can safely ignore this email —
                your account remains secure. Never share this code with anyone, including
                anyone claiming to be from our support team.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#f9fafb; padding:16px 32px; text-align:center;">
              <p style="margin:0; font-size:11px; color:#9ca3af;">
                © 2026 ISDR. All rights reserved.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

module.exports = { otpEmailHtml };
