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

// Email configuration - SMTP credentials can be set via Firebase functions config or environment variables
// For local testing you can create a .env file in the functions folder with SMTP_USER and SMTP_PASS (do NOT commit .env)
try {
  // Load local .env when present (safe to require, will be no-op in production)
  require('dotenv').config();
} catch (e) {
  // ignore
}

const smtpHost = functions.config().smtp?.host || process.env.SMTP_HOST || 'smtp.gmail.com';
const smtpPort = functions.config().smtp?.port || process.env.SMTP_PORT || 587;
const smtpSecure = (functions.config().smtp?.secure === true) || (process.env.SMTP_SECURE === 'true') || false;
const smtpUser = functions.config().smtp?.user || process.env.SMTP_USER;
const smtpPass = functions.config().smtp?.pass || process.env.SMTP_PASS;

if (!smtpUser || !smtpPass) {
  console.warn('⚠️ SMTP credentials not configured. Email sending may fail. Set via `firebase functions:config:set smtp.user="..." smtp.pass="..."` or set SMTP_USER/SMTP_PASS in environment variables.');
}

const emailTransporter = nodemailer.createTransport({
  host: smtpHost,
  port: Number(smtpPort),
  secure: smtpSecure,
  auth: smtpUser && smtpPass ? { user: smtpUser, pass: smtpPass } : undefined,
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

      // Filter subscribed users by eligibility for this scheme
      function isUserEligibleForScheme(userData, scheme) {
        try {
          // Parse numeric fields safely
          const age = userData.age !== undefined && userData.age !== null ? Number(userData.age) : null;
          const income = userData.annualIncome !== undefined && userData.annualIncome !== null ? Number(userData.annualIncome) : null;

          // Age check
          if (age !== null && (scheme.minAge !== undefined || scheme.maxAge !== undefined)) {
            if (scheme.minAge !== undefined && age < Number(scheme.minAge)) return false;
            if (scheme.maxAge !== undefined && age > Number(scheme.maxAge)) return false;
          }

          // Income check
          if (income !== null && scheme.maxIncomeINR !== undefined && scheme.maxIncomeINR !== null) {
            if (income > Number(scheme.maxIncomeINR)) return false;
          }

          // Occupation / beneficiary type
          const occ = (userData.occupation || '').toString().toLowerCase();
          const occReq = (scheme.occupationEligible || '').toString().toLowerCase();
          if (occReq && occReq !== 'any' && occReq !== 'not applicable') {
            if (!(occ && occ.includes(occReq)) && !(occReq && occReq.includes(occ))) return false;
          }

          // Category / caste
          const category = (userData.category || '').toString().toLowerCase();
          const catReq = (scheme.categoryEligible || '').toString().toLowerCase();
          if (catReq && catReq !== 'all') {
            if (!(category && category.includes(catReq)) && !(catReq && catReq.includes(category))) return false;
          }

          // Gender
          const gender = (userData.gender || '').toString().toLowerCase();
          const genderReq = (scheme.genderEligible || '').toString().toLowerCase();
          if (genderReq && genderReq !== 'all') {
            if (!(gender && gender.includes(genderReq)) && !(genderReq && genderReq.includes(gender))) return false;
          }

          // State / location
          const state = (userData.state || 'India').toString().toLowerCase();
          const schemeState = (scheme.state || 'India').toString().toLowerCase();
          if (schemeState && schemeState !== 'india') {
            if (!(state && state.includes(schemeState)) && !(schemeState && schemeState.includes(state))) return false;
          }

          return true;
        } catch (e) {
          console.error('Eligibility check error:', e);
          return false;
        }
      }

      const eligibleUsers = [];
      usersSnapshot.forEach((userDoc) => {
        const userData = userDoc.data();
        const userId = userDoc.id;
        if (isUserEligibleForScheme(userData, newScheme)) {
          eligibleUsers.push({ id: userId, data: userData });
        }
      });

      console.log(`🔎 Eligible users for this scheme: ${eligibleUsers.length}`);

      // Send notifications to eligible users
      const promises = [];

      eligibleUsers.forEach((entry) => {
        const userData = entry.data;
        const userId = entry.id;

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

/**
 * HTTPS endpoint to send scheme details to specified email addresses
 * Expects JSON body: { schemeId: string, emails: [string], lang: 'en'|'hi'|'mr' }
 */
exports.sendSchemeDetails = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const body = req.body || {};
  const schemeId = body.schemeId;
  const emails = Array.isArray(body.emails) ? body.emails : [];
  const lang = (body.lang || 'en').toString().slice(0, 2);

  if (!schemeId || !emails.length) {
    return res.status(400).json({ error: 'schemeId and emails are required' });
  }

  try {
    let schemeSnap = await admin.firestore().collection('schemes').doc(schemeId).get();
    let scheme = schemeSnap.exists ? schemeSnap.data() : null;

    // Fallback: treat schemeId as schemeName and query
    if (!scheme) {
      const q = await admin.firestore().collection('schemes').where('schemeName', '==', schemeId).limit(1).get();
      if (!q.empty) {
        scheme = q.docs[0].data();
      }
    }

    if (!scheme) return res.status(404).json({ error: 'Scheme not found' });

    // Localize subject and body
    const subjects = {
      en: `Details: ${scheme.schemeName}`,
      hi: `विवरण: ${scheme.schemeName}`,
      mr: `तपशील: ${scheme.schemeName}`
    };

    const bodies = {
      en: `<p>Dear user,</p><p>Here are details for <strong>${scheme.schemeName}</strong>.</p><p><strong>Benefits:</strong> ${scheme.benefits || ''}</p><p><strong>Eligibility:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>Please open the app for next steps.</p>`,
      hi: `<p>प्रिय उपयोगकर्ता,</p><p>यहाँ <strong>${scheme.schemeName}</strong> के लिए विवरण दिए गए हैं।</p><p><strong>लाभ:</strong> ${scheme.benefits || ''}</p><p><strong>पात्रता:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>आगे की जानकारी के लिए ऐप खोलें।</p>`,
      mr: `<p>प्रिय वापरकर्ता,</p><p>ये <strong>${scheme.schemeName}</strong> साठी तपशील आहेत.</p><p><strong>लाभ:</strong> ${scheme.benefits || ''}</p><p><strong>पात्रता:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>अधिक माहितीसाठी अॅप उघडा.</p>`
    };

    const subject = subjects[lang] || subjects['en'];
    const html = bodies[lang] || bodies['en'];

    // Send emails
    const promises = [];
    emails.forEach((to) => {
      const p = emailTransporter.sendMail({
        from: '"YojanaSuchak" <yojanasuchak@gmail.com>',
        to,
        subject,
        html,
      }).then(() => console.log(`✅ Email sent to ${to}`)).catch((err) => console.error(`❌ Failed to send to ${to}:`, err));
      promises.push(p);
    });

    await Promise.all(promises);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error in sendSchemeDetails:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

// Callable version for in-app calls
exports.sendSchemeDetailsCallable = functions.https.onCall(async (data, context) => {
  const schemeId = data.schemeId;
  const emails = Array.isArray(data.emails) ? data.emails : [];
  const lang = (data.lang || 'en').toString().slice(0, 2);

  if (!schemeId || !emails.length) {
    throw new functions.https.HttpsError('invalid-argument', 'schemeId and emails are required');
  }

  try {
    let schemeSnap = await admin.firestore().collection('schemes').doc(schemeId).get();
    let scheme = schemeSnap.exists ? schemeSnap.data() : null;

    // Fallback: treat schemeId as schemeName and query
    if (!scheme) {
      const q = await admin.firestore().collection('schemes').where('schemeName', '==', schemeId).limit(1).get();
      if (!q.empty) {
        scheme = q.docs[0].data();
      }
    }

    if (!scheme) throw new functions.https.HttpsError('not-found', 'Scheme not found');

    const subjects = {
      en: `Details: ${scheme.schemeName}`,
      hi: `विवरण: ${scheme.schemeName}`,
      mr: `तपशील: ${scheme.schemeName}`
    };

    const bodies = {
      en: `<p>Dear user,</p><p>Here are details for <strong>${scheme.schemeName}</strong>.</p><p><strong>Benefits:</strong> ${scheme.benefits || ''}</p><p><strong>Eligibility:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>Please open the app for next steps.</p>`,
      hi: `<p>प्रिय उपयोगकर्ता,</p><p>यहाँ <strong>${scheme.schemeName}</strong> के लिए विवरण दिए गए हैं।</p><p><strong>लाभ:</strong> ${scheme.benefits || ''}</p><p><strong>पात्रता:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>आगे की जानकारी के लिए ऐप खोलें।</p>`,
      mr: `<p>प्रिय वापरकर्ता,</p><p>ये <strong>${scheme.schemeName}</strong> साठी तपशील आहेत.</p><p><strong>लाभ:</strong> ${scheme.benefits || ''}</p><p><strong>पात्रता:</strong> ${JSON.stringify(scheme.eligibility || {})}</p><p>अधिक माहितीसाठी अॅप उघडा.</p>`
    };

    const subject = subjects[lang] || subjects['en'];
    const html = bodies[lang] || bodies['en'];

    const promises = [];
    emails.forEach((to) => {
      const p = emailTransporter.sendMail({
        from: '"YojanaSuchak" <yojanasuchak@gmail.com>',
        to,
        subject,
        html,
      }).then(() => console.log(`✅ Email sent to ${to}`)).catch((err) => console.error(`❌ Failed to send to ${to}:`, err));
      promises.push(p);
    });

    await Promise.all(promises);
    return { success: true };
  } catch (error) {
    console.error('Error in sendSchemeDetailsCallable:', error);
    throw new functions.https.HttpsError('internal', 'Internal server error');
  }
});


// Callable to provide a SINGLE short follow-up question using server-side Gemini (or local fallback)
exports.getGeminiResponse = functions.https.onCall(async (data, context) => {
  const userProblem = (data.userProblem || '').toString();
  const missingFields = Array.isArray(data.missingFields) ? data.missingFields : [];
  const lang = (data.lang || 'en').toString().slice(0,2);
  const sector = data.sector || null;

  // If Gemini key is not set, use a deterministic local fallback question generator
  const hasGeminiKey = !!(functions.config().gemini?.key || process.env.GEMINI_API_KEY);

  // Local fallback generator (keeps questions short and sector-aware)
  function localFallback() {
    const p = userProblem.toLowerCase();

    // Education-focused
    if ((p.includes('student') || p.includes('education') || p.includes('fees')) ) {
      if (missingFields.includes('student')) {
        return { question: (lang === 'hi' ? 'क्या आप वर्तमान में छात्र/छात्रा हैं?' : (lang === 'mr' ? 'आप सध्या विद्यार्थी आहात का?' : 'Are you currently a student?')) };
      }
      if (missingFields.includes('age')) {
        return { question: (lang === 'hi' ? 'आपकी आयु क्या है?' : (lang === 'mr' ? 'आपची वय किती आहे?' : 'What is your age?')) };
      }
    }

    // Health-focused
    if (p.includes('health') || p.includes('medical')) {
      if (missingFields.includes('seniorCitizen')) {
        return { question: (lang === 'hi' ? 'क्या आप 60+ वरिष्ठ नागरिक हैं? (हाँ/नहीं)' : (lang === 'mr' ? 'आप 60+ वरिष्ठ नागरिक आहात का? (होय/नाही)' : 'Are you a senior citizen (60+)? (yes/no)')) };
      }
      if (missingFields.includes('disability')) {
        return { question: (lang === 'hi' ? 'क्या आपको कोई विकलांगता है? (हाँ/नहीं)' : (lang === 'mr' ? 'आपला काही अपंगत्व आहे का? (होय/नाही)' : 'Do you have any disability? (yes/no)')) };
      }
    }

    // General priority order
    const order = ['sector','occupation','age','income','category','gender','student','farmer','woman','seniorCitizen','disability'];
    for (const f of order) {
      if (missingFields.includes(f)) {
        switch (f) {
          case 'occupation':
            return { question: (lang === 'hi' ? 'आपका पेशा क्या है?' : (lang === 'mr' ? 'आपले व्यवसाय काय आहे?' : 'What is your occupation?')) };
          case 'age':
            return { question: (lang === 'hi' ? 'आपकी आयु क्या है?' : (lang === 'mr' ? 'आपची वय किती आहे?' : 'What is your age?')) };
          case 'income':
            return { question: (lang === 'hi' ? 'आपकी मासिक/वार्षिक आय क्या है? (लगभग)' : (lang === 'mr' ? 'आपले मासिक/वार्षिक उत्पन्न किती आहे? (सुमारे)' : 'What is your monthly/annual income? (approx.)')) };
          case 'category':
            return { question: (lang === 'hi' ? 'आप किस श्रेणी से हैं? (General/SC/ST/OBC)' : (lang === 'mr' ? 'आप कोणत्या वर्गात आहात? (General/SC/ST/OBC)' : 'Which category do you belong to? (General/SC/ST/OBC)')) };
          case 'gender':
            return { question: (lang === 'hi' ? 'आपका लिंग क्या है?' : (lang === 'mr' ? 'आपले लिंग काय आहे?' : 'What is your gender?')) };
          case 'student':
            return { question: (lang === 'hi' ? 'क्या आप छात्र/छात्रा हैं? (हाँ/नहीं)' : (lang === 'mr' ? 'आप विद्यार्थी आहात का? (होय/नाही)' : 'Are you a student? (yes/no)')) };
          case 'farmer':
            return { question: (lang === 'hi' ? 'क्या आप किसान हैं? (हाँ/नहीं)' : (lang === 'mr' ? 'आप शेतकरी आहात का? (होय/नाही)' : 'Are you a farmer? (yes/no)')) };
          case 'woman':
            return { question: (lang === 'hi' ? 'क्या आप महिला हैं? (हाँ/नहीं)' : (lang === 'mr' ? 'आप स्त्री आहात का? (होय/नाही)' : 'Are you a woman? (yes/no)')) };
          case 'seniorCitizen':
            return { question: (lang === 'hi' ? 'क्या आप 60+ वरिष्ठ नागरिक हैं? (हाँ/नहीं)' : (lang === 'mr' ? 'आप 60+ वरिष्ठ नागरिक आहात का? (होय/नाही)' : 'Are you a senior citizen (60+)? (yes/no)')) };
          case 'disability':
            return { question: (lang === 'hi' ? 'क्या आपको कोई विकलांगता है? (हाँ/नहीं)' : (lang === 'mr' ? 'आपला काही अपंगत्व आहे का? (होय/नाही)' : 'Do you have any disability? (yes/no)')) };
          default:
            return { question: (lang === 'hi' ? 'कृपया अपनी समस्या के बारे में और जानकारी दें।' : (lang === 'mr' ? 'कृपया आपल्या समस्येबद्दल अधिक माहिती द्या.' : 'Please provide more details about your problem.')) };
        }
      }
    }

    return { question: (lang === 'hi' ? 'कृपया अपनी समस्या के बारे में और जानकारी दें।' : (lang === 'mr' ? 'कृपया आपल्या समस्येबद्दल अधिक माहिती द्या.' : 'Please provide more details about your problem.')) };
  }

  // If Gemini key exists, call configured provider (Google Generative / PaLM or OpenAI). Falls back to local generator on any error.
  try {
    if (!hasGeminiKey) {
      return localFallback();
    }

    const gConfig = functions.config().gemini || {};
    const provider = gConfig.provider || process.env.GEMINI_PROVIDER || 'google'; // 'google' or 'openai'
    const key = gConfig.key || process.env.GEMINI_API_KEY;
    const model = gConfig.model || process.env.GEMINI_MODEL || (provider === 'google' ? 'text-bison-001' : 'gpt-4o-mini');

    async function callGenerator(prompt) {
      if (provider === 'google') {
        // Generative Language API (HTTP). Requires an API key with the Generative API enabled.
        // Example URL: https://generativelanguage.googleapis.com/v1beta2/models/text-bison-001:generateText?key=API_KEY
        const url = `https://generativelanguage.googleapis.com/v1beta2/models/${encodeURIComponent(model)}:generateText?key=${encodeURIComponent(key)}`;
        const body = { prompt: { text: prompt }, temperature: 0.2, maxOutputTokens: 40 };
        const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
        if (!resp.ok) throw new Error(`Generative API error: ${resp.status}`);
        const json = await resp.json();
        const text = json?.candidates?.[0]?.content || json?.output?.[0]?.content || null;
        return text;
      } else if (provider === 'openai') {
        // OpenAI-compatible call (if using OpenAI keys/models)
        const url = 'https://api.openai.com/v1/chat/completions';
        const body = {
          model,
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 60,
          temperature: 0.2,
        };
        const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` }, body: JSON.stringify(body) });
        if (!resp.ok) throw new Error(`OpenAI API error: ${resp.status}`);
        const json = await resp.json();
        const text = json?.choices?.[0]?.message?.content || json?.choices?.[0]?.text || null;
        return text;
      } else {
        throw new Error('Unsupported gemini.provider: ' + provider);
      }
    }

    // Build a concise prompt requesting ONE short follow-up question in the user's language
    const prompt = `You are an assistant that asks ONE concise follow-up question (max 12 words) to clarify a user's problem in Marathi/Hindi/English. User problem: "${userProblem}". Missing fields: ${missingFields.join(', ') || 'none'}. Sector: ${sector || 'general'}. Language: ${lang}. Ask only the question (no extra text).`;

    console.log('LLM provider:', provider, 'model:', model ? model : 'default');
    const generated = await callGenerator(prompt);
    if (generated && typeof generated === 'string') {
      const q = generated.split('\n').map(s => s.trim()).find(Boolean) || generated.trim();
      let question = q;
      if (question.length > 120) question = question.slice(0, 120) + '...';
      return { question };
    } else {
      return localFallback();
    }
  } catch (err) {
    console.error('Error in getGeminiResponse:', err);
    return localFallback();
  }
});


/**
 * Helper: extract JSON object from raw model text (first { ... } block)
 */
function safeJsonExtract(raw) {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('Model returned invalid JSON');
  }
  const js = raw.slice(start, end + 1);
  return JSON.parse(js);
}

/**
 * Generic provider call helper used by the Gemini callables
 */
async function providerGenerate(prompt, maxTokens = 600) {
  const gConfig = functions.config().gemini || {};
  const provider = gConfig.provider || process.env.GEMINI_PROVIDER || 'google';
  const key = gConfig.key || process.env.GEMINI_API_KEY;
  const model = gConfig.model || process.env.GEMINI_MODEL || (provider === 'google' ? 'text-bison-001' : 'gpt-4o-mini');

  if (!key) throw new Error('No gemini key configured');

  if (provider === 'google') {
    const url = `https://generativelanguage.googleapis.com/v1beta2/models/${encodeURIComponent(model)}:generateText?key=${encodeURIComponent(key)}`;
    const body = { prompt: { text: prompt }, temperature: 0.1, maxOutputTokens: maxTokens };
    const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!resp.ok) throw new Error(`Generative API error: ${resp.status}`);
    const json = await resp.json();
    return json?.candidates?.[0]?.content || json?.output?.[0]?.content || '';
  }

  if (provider === 'openai') {
    const url = 'https://api.openai.com/v1/chat/completions';
    const body = {
      model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: maxTokens,
      temperature: 0.1,
    };
    const resp = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` }, body: JSON.stringify(body) });
    if (!resp.ok) throw new Error(`OpenAI API error: ${resp.status}`);
    const json = await resp.json();
    return json?.choices?.[0]?.message?.content || json?.choices?.[0]?.text || '';
  }

  throw new Error('Unsupported gemini.provider: ' + provider);
}


/**
 * Callable: Run initial profile extraction + eligibility check
 * Returns the strict JSON object as specified in the Python prompt
 */
exports.geminiInitialProfile = functions.https.onCall(async (data, context) => {
  const callSid = String(data.callSid || '').trim();
  const userText = String(data.userText || '').trim();
  const language = String((data.language || 'en')).slice(0,2);
  const schemes = Array.isArray(data.schemes) ? data.schemes : [];

  if (!userText) throw new functions.https.HttpsError('invalid-argument', 'userText is required');

  // Build a prompt similar to the Python implementation (concise but strict about JSON)
  const prompt = `You are Yojana Suchak.\n\nYou are running inside a phone-call system. Your output is parsed by a machine.\n\nAbsolute output rule: Output MUST be a SINGLE valid JSON object and nothing else.\n\nUser statement: ${userText}\n\nAvailable schemes: ${JSON.stringify(schemes)}\n\nReturn this exact JSON shape:\n{ "profile": { "age": null, "gender": null, "state": null, "residence_type": null, "annual_income": null, "occupation": null, "land_holding": null, "caste_category": null }, "additional_attributes": {}, "eligible_schemes": [], "schemes_needing_more_info": [], "followup_question": "" }`;

  try {
    const raw = await providerGenerate(prompt, 800);
    let dataObj;
    try {
      dataObj = safeJsonExtract(raw);
    } catch (e) {
      console.error('Invalid JSON from provider:', raw);
      // Fallback: return minimal parsed structure
      return {
        profile: { age: null, gender: null, state: null, residence_type: null, annual_income: null, occupation: null, land_holding: null, caste_category: null },
        additional_attributes: {},
        eligible_schemes: [],
        schemes_needing_more_info: [],
        followup_question: ''
      };
    }

    // Ensure shape and types
    dataObj.profile = dataObj.profile || { age: null, gender: null, state: null, residence_type: null, annual_income: null, occupation: null, land_holding: null, caste_category: null };
    dataObj.additional_attributes = dataObj.additional_attributes || {};
    dataObj.eligible_schemes = Array.isArray(dataObj.eligible_schemes) ? dataObj.eligible_schemes : [];
    dataObj.schemes_needing_more_info = Array.isArray(dataObj.schemes_needing_more_info) ? dataObj.schemes_needing_more_info : [];
    dataObj.followup_question = dataObj.followup_question || '';

    // Limit eligible schemes to first 3 to keep payload small
    dataObj.eligible_schemes = dataObj.eligible_schemes.slice(0, 3);

    return dataObj;
  } catch (err) {
    console.error('Error in geminiInitialProfile:', err);
    // Fallback minimal response
    return {
      profile: { age: null, gender: null, state: null, residence_type: null, annual_income: null, occupation: null, land_holding: null, caste_category: null },
      additional_attributes: {},
      eligible_schemes: [],
      schemes_needing_more_info: [],
      followup_question: ''
    };
  }
});


/**
 * Callable: Run a follow-up update and finalize eligibility
 */
exports.geminiUpdateProfile = functions.https.onCall(async (data, context) => {
  const callSid = String(data.callSid || '').trim();
  const followupText = String(data.followupText || '').trim();
  const language = String((data.language || 'en')).slice(0,2);
  const schemes = Array.isArray(data.schemes) ? data.schemes : [];

  if (!callSid || !followupText) throw new functions.https.HttpsError('invalid-argument', 'callSid and followupText are required');

  const prompt = `You are Yojana Suchak.\n\nExisting profile: ${JSON.stringify(data.existing_profile || {})}\nExisting additional_attributes: ${JSON.stringify(data.existing_additional_attributes || {})}\nUser follow-up answer: ${followupText}\nAvailable schemes: ${JSON.stringify(schemes)}\n\nRules: Update only null fields in profile, do not invent new fields. Return EXACTLY this JSON: { "updated_profile": { "age": null, "gender": null, "state": null, "residence_type": null, "annual_income": null, "occupation": null, "land_holding": null, "caste_category": null }, "updated_additional_attributes": {}, "final_eligible_schemes": [], "still_missing_fields": [], "followup_question": "" }`;

  try {
    const raw = await providerGenerate(prompt, 800);
    let dataObj;
    try {
      dataObj = safeJsonExtract(raw);
    } catch (e) {
      console.error('Invalid JSON from provider (followup):', raw);
      // fallback: return minimal structure with followup cleared
      return { updated_profile: data.existing_profile || {}, updated_additional_attributes: data.existing_additional_attributes || {}, final_eligible_schemes: [], still_missing_fields: [], followup_question: '' };
    }

    // Normalize similar to Python helpers
    dataObj.updated_profile = dataObj.updated_profile || { age: null, gender: null, state: null, residence_type: null, annual_income: null, occupation: null, land_holding: null, caste_category: null };
    dataObj.updated_additional_attributes = dataObj.updated_additional_attributes || {};
    dataObj.final_eligible_schemes = Array.isArray(dataObj.final_eligible_schemes) ? dataObj.final_eligible_schemes : [];
    dataObj.still_missing_fields = Array.isArray(dataObj.still_missing_fields) ? dataObj.still_missing_fields : [];
    dataObj.followup_question = dataObj.followup_question || '';

    return dataObj;
  } catch (err) {
    console.error('Error in geminiUpdateProfile:', err);
    return { updated_profile: data.existing_profile || {}, updated_additional_attributes: data.existing_additional_attributes || {}, final_eligible_schemes: [], still_missing_fields: [], followup_question: '' };
  }
});


/**
 * Callable: Generate a concise spoken explanation for a scheme
 */
exports.geminiGenerateSchemeDetails = functions.https.onCall(async (data, context) => {
  const scheme = data.scheme || null;
  const language = String((data.language || 'en')).slice(0,2);
  if (!scheme) throw new functions.https.HttpsError('invalid-argument', 'scheme is required');

  const prompt = `Explain the following government scheme clearly in ${language}. Use simple spoken language. Keep it under 30 seconds of speech. Include: 1) Who can apply (brief), 2) Key benefits, 3) Required documents, 4) Where to apply. Scheme: ${JSON.stringify(scheme)}. Return plain text only.`;

  try {
    const raw = await providerGenerate(prompt, 500);
    const clean = (raw || '').replace(/\*|`|__|\*\*/g, '').replace(/\s+/g, ' ').trim();
    return { text: clean };
  } catch (err) {
    console.error('Error in geminiGenerateSchemeDetails:', err);
    return { text: `${scheme.schemeName || scheme.scheme_title || 'This scheme'} - details not available at the moment.` };
  }
});

