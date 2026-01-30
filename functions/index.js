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

  // If Gemini key exists we currently still use the fallback generator until server-side Gemini is configured
  try {
    if (!hasGeminiKey) {
      return localFallback();
    }

    // TODO: Implement real Gemini call here using server-side key
    // For now, fallback is returned even if key exists to keep behavior deterministic
    return localFallback();
  } catch (err) {
    console.error('Error in getGeminiResponse:', err);
    return localFallback();
  }
});

