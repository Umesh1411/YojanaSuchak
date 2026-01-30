/**
 * Firebase Cloud Functions for YojanaSuchak App
 * 
 * This file contains functions to:
 * 1. Send email notifications when new schemes are added
 * 2. Send push notifications to subscribed users
 * 
 * SETUP REQUIRED:
 * 1. Install dependencies: npm install
 * 2. Deploy: firebase deploy --only functions
 * 3. Configure email service (SendGrid/Firebase Extensions/SMTP)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin
admin.initializeApp();

// Email configuration - UPDATE WITH YOUR SMTP DETAILS
const emailTransporter = nodemailer.createTransport({
  host: 'smtp.gmail.com', // Update if using different SMTP
  port: 587,
  secure: false,
  auth: {
    user: functions.config().smtp?.user || 'yojanasuchak@gmail.com',
    pass: functions.config().smtp?.pass || 'your-app-password',
  },
});

/**
 * Triggered when a new scheme is added to Firestore 'schemes' collection
 * Sends email and push notifications to all subscribed users
 */
exports.onNewSchemeAdded = functions.firestore
  .document('schemes/{schemeId}')
  .onCreate(async (snap, context) => {
    const newScheme = snap.data();
    const schemeId = context.params.schemeId;

    console.log(`📢 New scheme added: ${newScheme.schemeName} (ID: ${schemeId})`);

    try {
      // Get all subscribed users from Firestore
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .where('notificationsEnabled', '==', true)
        .get();

      if (usersSnapshot.empty) {
        console.log('⚠️ No subscribed users found');
        return null;
      }

      console.log(`📧 Found ${usersSnapshot.size} subscribed users`);

      // Prepare notification content
      const notificationTitle = 'नवीन योजना उपलब्ध आहे! / New Scheme Available!';
      const notificationBody = `${newScheme.schemeName} - ${newScheme.department}`;
      const emailSubject = `New Government Scheme: ${newScheme.schemeName}`;
      
      // Build email HTML content
      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background-color: #1976d2; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; background-color: #f9f9f9; }
            .scheme-card { background-color: white; padding: 15px; margin: 10px 0; border-left: 4px solid #1976d2; }
            .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>YojanaSuchak</h1>
              <p>नवीन योजना सूचना / New Scheme Notification</p>
            </div>
            <div class="content">
              <h2>${newScheme.schemeName}</h2>
              <div class="scheme-card">
                <p><strong>Department:</strong> ${newScheme.department}</p>
                <p><strong>Target Group:</strong> ${newScheme.targetGroup}</p>
                <p><strong>Benefits:</strong> ${newScheme.benefits}</p>
                <p><strong>Eligibility:</strong> ${newScheme.eligibility}</p>
              </div>
              <p>Check the YojanaSuchak app for more details and to apply!</p>
            </div>
            <div class="footer">
              <p>This is an automated notification from YojanaSuchak</p>
              <p>To unsubscribe, update your notification settings in the app</p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Send notifications to all subscribed users
      const promises = [];

      usersSnapshot.forEach((userDoc) => {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // Send email notification
        if (userData.email) {
          const emailPromise = emailTransporter.sendMail({
            from: '"YojanaSuchak" <yojanasuchak@gmail.com>',
            to: userData.email,
            subject: emailSubject,
            html: emailHtml,
          }).then(() => {
            console.log(`✅ Email sent to ${userData.email}`);
          }).catch((error) => {
            console.error(`❌ Failed to send email to ${userData.email}:`, error);
          });
          promises.push(emailPromise);
        }

        // Send push notification via FCM
        if (userData.fcmToken) {
          const message = {
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: {
              type: 'new_scheme',
              schemeId: schemeId,
              schemeName: newScheme.schemeName,
              department: newScheme.department,
            },
            token: userData.fcmToken,
          };

          const pushPromise = admin.messaging().send(message)
            .then((response) => {
              console.log(`✅ Push notification sent to user ${userId}:`, response);
            })
            .catch((error) => {
              console.error(`❌ Failed to send push notification to user ${userId}:`, error);
              // If token is invalid, remove it from user document
              if (error.code === 'messaging/invalid-registration-token' ||
                  error.code === 'messaging/registration-token-not-registered') {
                return admin.firestore()
                  .collection('users')
                  .doc(userId)
                  .update({ fcmToken: admin.firestore.FieldValue.delete() });
              }
            });
          promises.push(pushPromise);
        }
      });

      // Wait for all notifications to be sent
      await Promise.all(promises);
      console.log(`✅ All notifications sent for scheme: ${newScheme.schemeName}`);

      return null;
    } catch (error) {
      console.error('❌ Error in onNewSchemeAdded:', error);
      return null;
    }
  });

/**
 * HTTP endpoint to manually trigger notifications (for testing)
 * Usage: POST /sendTestNotification
 */
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  // In production, add authentication here
  const testScheme = {
    schemeName: 'Test Scheme',
    department: 'Test Department',
    targetGroup: 'All Citizens',
    benefits: 'Test benefits',
    eligibility: 'Test eligibility',
  };

  try {
    // Create a test document to trigger the function
    await admin.firestore().collection('schemes').add(testScheme);
    res.status(200).send('Test notification triggered');
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send('Error triggering notification');
  }
});

/**
 * Triggered when a scheme is created or updated.
 * Re-evaluates users and notifies only those who are newly eligible.
 */
exports.onSchemeCreatedOrUpdated = functions.firestore
  .document('schemes/{schemeId}')
  .onWrite(async (change, context) => {
    const newScheme = change.after.exists ? change.after.data() : null;
    const oldScheme = change.before.exists ? change.before.data() : null;
    const schemeId = context.params.schemeId;

    if (!newScheme) {
      console.log('⚠️ Scheme deleted, skipping re-evaluation');
      return null;
    }

    // Only handle active Maharashtra schemes
    if (newScheme.state !== 'Maharashtra' || newScheme.isActive !== true) {
      console.log('ℹ️ Scheme not active or not Maharashtra; skipping');
      return null;
    }

    // If eligibility is not structured, skip (safe-fail)
    const newEligibility = newScheme.eligibility || null;
    if (!newEligibility) {
      console.log('⚠️ Scheme eligibility not structured; skipping re-evaluation for scheme', schemeId);
      return null;
    }

    try {
      const usersSnapshot = await admin.firestore().collection('users').get();
      if (usersSnapshot.empty) {
        console.log('⚠️ No users to evaluate');
        return null;
      }

      const notifyPromises = [];

      usersSnapshot.forEach((userDoc) => {
        const userData = userDoc.data();
        const userId = userDoc.id;

        const wasEligible = oldScheme ? userEligibleForScheme(userData, oldScheme) : false;
        const nowEligible = userEligibleForScheme(userData, newScheme);

        if (!wasEligible && nowEligible) {
          // Build localized notification content
          const userLang = (userData.language || 'en').toString().slice(0,2);

          const titleMap = {
            en: 'New scheme you are eligible for',
            hi: 'आप पात्र आहात अशा नवीन योजनेची माहिती',
            mr: 'आपण पात्र असलेली नवीन योजना उपलब्ध'
          };

          const bodyMap = {
            en: `${newScheme.schemeName} - Suitable for you based on your profile.`,
            hi: `${newScheme.schemeName} - आपकी प्रोफ़ाइल के आधार पर यह योजना आपके लिए उपयुक्त है।`,
            mr: `${newScheme.schemeName} - आपल्या प्रोफाइलच्या आधारावर ही योजना आपल्यासाठी उपयुक्त आहे.`
          };

          const emailSubjects = {
            en: `You are eligible: ${newScheme.schemeName}`,
            hi: `आप पात्र हैं: ${newScheme.schemeName}`,
            mr: `आपण पात्र आहात: ${newScheme.schemeName}`
          };

          const emailHtmls = {
            en: `<p>Dear user,</p><p>You are newly eligible for <strong>${newScheme.schemeName}</strong>.</p><p>Benefits: ${newScheme.benefits || ''}</p><p>Please open the app for next steps.</p>`,
            hi: `<p>प्रिय उपयोगकर्ता,</p><p>आप अब <strong>${newScheme.schemeName}</strong> के लिए पात्र हैं।</p><p>लाभ: ${newScheme.benefits || ''}</p><p>आगे की जानकारी के लिए ऐप खोलें।</p>`,
            mr: `<p>प्रिय वापरकर्ता,</p><p>आप आता <strong>${newScheme.schemeName}</strong> साठी पात्र आहात.</p><p>लाभ: ${newScheme.benefits || ''}</p><p>अधिक माहितीसाठी अॅप उघडा.</p>`
          };

          // Push notification
          if (userData.notificationsEnabled && userData.fcmToken) {
            const message = {
              notification: {
                title: titleMap[userLang] || titleMap['en'],
                body: bodyMap[userLang] || bodyMap['en'],
              },
              data: {
                type: 'new_scheme_eligibility',
                schemeId: schemeId,
              },
              token: userData.fcmToken,
            };

            const pushPromise = admin.messaging().send(message)
              .then((resp) => console.log(`✅ Push sent to ${userId}`))
              .catch((err) => {
                console.error(`❌ Push failed for ${userId}:`, err);
                if (err.code === 'messaging/invalid-registration-token' || err.code === 'messaging/registration-token-not-registered') {
                  return admin.firestore().collection('users').doc(userId).update({ fcmToken: admin.firestore.FieldValue.delete() });
                }
              });

            notifyPromises.push(pushPromise);
          }

          // Email notification
          if (userData.email) {
            const emailPromise = emailTransporter.sendMail({
              from: '"YojanaSuchak" <yojanasuchak@gmail.com>',
              to: userData.email,
              subject: emailSubjects[userLang] || emailSubjects['en'],
              html: emailHtmls[userLang] || emailHtmls['en'],
            }).then(() => console.log(`✅ Email sent to ${userData.email}`))
              .catch((error) => console.error(`❌ Failed to send email to ${userData.email}:`, error));

            notifyPromises.push(emailPromise);
          }

        }
      });

      await Promise.all(notifyPromises);
      console.log('✅ Completed re-evaluation notifications for scheme', schemeId);
      return null;
    } catch (error) {
      console.error('❌ Error in onSchemeCreatedOrUpdated:', error);
      return null;
    }
  });

/**
 * Simple eligibility check - expects structured eligibility in scheme. Returns boolean.
 */
function userEligibleForScheme(user, scheme) {
  try {
    const eligibility = scheme.eligibility || {};

    // Age
    if (eligibility.minAge && eligibility.maxAge) {
      if (!user.age) return false;
      if (user.age < eligibility.minAge || user.age > eligibility.maxAge) return false;
    } else if (eligibility.minAge) {
      if (!user.age || user.age < eligibility.minAge) return false;
    } else if (eligibility.maxAge) {
      if (!user.age || user.age > eligibility.maxAge) return false;
    }

    // Gender
    if (eligibility.gender) {
      if (!user.gender || user.gender.toLowerCase() !== eligibility.gender.toLowerCase()) return false;
    }

    // Income
    if (eligibility.incomeLimit) {
      if (user.income == null) return false;
      if (Number(user.income) > Number(eligibility.incomeLimit)) return false;
    }

    // Occupation
    if (eligibility.occupation) {
      if (!user.occupation || user.occupation.toLowerCase() !== eligibility.occupation.toLowerCase()) return false;
    }

    // Category
    if (eligibility.category) {
      if (!user.category || user.category.toLowerCase() !== eligibility.category.toLowerCase()) return false;
    }

    // Disability
    if (eligibility.disabilityRequired) {
      if (!user.disability) return false;
    }

    // Flags
    const flags = ['farmer', 'student', 'woman', 'seniorCitizen'];
    for (const f of flags) {
      if (eligibility[f] === true) {
        if (!user[f]) return false;
      }
    }

    return true;
  } catch (e) {
    console.error('Error in eligibility check', e);
    return false;
  }
}

