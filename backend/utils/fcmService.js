const path = require('path');
const dotenv = require('dotenv');

// Load .env before Firebase init (fcmService can be required before server.js dotenv.config).
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const Apartment = require('../models/Apartment');
const ManagementUser = require('../models/ManagementUser');
const EventStaff = require('../models/EventStaff');
const EventRegistration = require('../models/EventRegistration');
const Speaker = require('../models/Speaker');
const Notification = require('../models/Notification');

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

function initializeFirebase() {
  if (firebaseInitialized) {
    return;
  }

  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

    if (!projectId || !privateKey || !clientEmail) {
      console.warn('Firebase credentials not found in .env. FCM notifications will be disabled.');
      return;
    }

    if (!getApps().length) {
      initializeApp({
        credential: cert({
          projectId,
          privateKey,
          clientEmail,
        }),
      });
    }

    firebaseInitialized = true;
    console.log('Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('Error initializing Firebase Admin SDK:', error);
  }
}

// Initialize on module load
initializeFirebase();

/**
 * Get the account model for a userType:
 * apartment = admin login, management = Admin ID, user = event staff,
 * participant, speaker.
 */
async function getUserModel(userId, userType) {
  const modelMap = {
    apartment: Apartment,
    management: ManagementUser,
    user: EventStaff,
    participant: EventRegistration,
    speaker: Speaker,
  };

  const Model = modelMap[userType];
  if (!Model) {
    throw new Error(`Invalid userType: ${userType}`);
  }

  return await Model.findById(userId);
}

// Tokens FCM reports as gone (app uninstalled / token rotated).
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Remove invalid FCM token from user's tokens array
 */
async function removeInvalidToken(userId, userType, invalidToken) {
  try {
    const user = await getUserModel(userId, userType);
    if (user && user.fcmTokens) {
      await user.constructor.updateOne({ _id: user._id }, { $pull: { fcmTokens: invalidToken } });
    }
  } catch (error) {
    console.error('Error removing invalid token:', error);
  }
}

/**
 * Store the notification for the in-app Notifications screen.
 */
async function storeNotification(userId, userType, notification) {
  try {
    await Notification.create({
      userId,
      userType,
      title: notification.title,
      body: notification.body,
      type: notification.type || 'general',
      data: notification.data || {},
      apartmentId: notification.apartmentId || null,
      read: false,
    });
  } catch (error) {
    console.error('Error storing notification:', error);
  }
}

/**
 * Send notification to a single user (all their devices)
 * notification: { title, body, type?, data?, apartmentId? }
 */
async function sendNotificationToUser(userId, userType, notification) {
  try {
    const user = await getUserModel(userId, userType);
    if (!user) {
      return { success: false, error: 'User not found' };
    }

    // Kept for the Notifications screen even if the device can't get the push.
    await storeNotification(userId, userType, notification);

    if (!firebaseInitialized) {
      console.warn('Firebase not initialized. Skipping notification.');
      return { success: false, error: 'Firebase not initialized' };
    }

    // Filter out empty strings and get valid tokens
    const validTokens = [
      ...new Set((user.fcmTokens || []).filter((token) => token && token.trim() !== '')),
    ];

    if (validTokens.length === 0) {
      return { success: false, error: 'No valid FCM tokens found' };
    }

    const dataPayload = Object.fromEntries(
      Object.entries({ type: notification.type || 'general', ...(notification.data || {}) }).map(
        ([key, value]) => [key, value == null ? '' : String(value)]
      )
    );

    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: dataPayload,
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
        },
      },
      tokens: validTokens,
    };

    const response = await getMessaging().sendEachForMulticast(message);

    // Handle invalid tokens
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && DEAD_TOKEN_CODES.has(resp.error && resp.error.code)) {
          failedTokens.push(validTokens[idx]);
        }
      });

      // Remove invalid tokens from database
      for (const token of failedTokens) {
        await removeInvalidToken(userId, userType, token);
      }
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (error) {
    console.error('Error sending notification to user:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Send notification to multiple users
 */
async function sendNotificationToMultipleUsers(userIds, userType, notification) {
  const results = [];
  for (const userId of userIds) {
    const result = await sendNotificationToUser(String(userId), userType, notification);
    results.push({ userId: String(userId), ...result });
  }

  return results;
}

/**
 * Send notification to specific account types of a property:
 * 'apartment' (admin login), 'management' (Admin IDs), 'user' (event staff),
 * 'participant', 'speaker'.
 */
async function sendNotificationToApartmentByUserType(apartmentId, userTypes, notification) {
  try {
    const allUsers = [];

    if (userTypes.includes('apartment')) {
      const apt = await Apartment.findById(apartmentId).select('_id');
      if (apt) allUsers.push({ id: apt._id, type: 'apartment' });
    }
    if (userTypes.includes('management')) {
      const members = await ManagementUser.find({ apartmentId, isActive: true }).select('_id');
      allUsers.push(...members.map((m) => ({ id: m._id, type: 'management' })));
    }
    if (userTypes.includes('user')) {
      const staff = await EventStaff.find({ apartmentId, isActive: true }).select('_id');
      allUsers.push(...staff.map((s) => ({ id: s._id, type: 'user' })));
    }
    if (userTypes.includes('participant')) {
      const participants = await EventRegistration.find({
        apartmentId,
        status: { $ne: 'cancelled' },
      }).select('_id');
      allUsers.push(...participants.map((p) => ({ id: p._id, type: 'participant' })));
    }
    if (userTypes.includes('speaker')) {
      const speakers = await Speaker.find({ apartmentId }).select('_id');
      allUsers.push(...speakers.map((s) => ({ id: s._id, type: 'speaker' })));
    }

    const results = [];
    for (const user of allUsers) {
      const result = await sendNotificationToUser(user.id.toString(), user.type, {
        ...notification,
        apartmentId,
      });
      results.push({ userId: user.id.toString(), userType: user.type, ...result });
    }

    return results;
  } catch (error) {
    console.error('Error sending notification to apartment by user type:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Send notification to everyone on a property: event staff and participants.
 */
async function sendNotificationToApartment(apartmentId, notification) {
  return sendNotificationToApartmentByUserType(apartmentId, ['user', 'participant'], notification);
}

module.exports = {
  sendNotificationToUser,
  sendNotificationToMultipleUsers,
  sendNotificationToApartment,
  sendNotificationToApartmentByUserType,
  initializeFirebase,
};
