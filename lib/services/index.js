require('dotenv').config();

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { AccessToken } = require("livekit-server-sdk");

admin.initializeApp();

const db = admin.firestore();
const { Timestamp } = admin.firestore;

exports.generateLiveKitToken = onCall(async (request) => {
  const { roomName, identity, name, isHost } = request.data;

  if (!roomName || !identity) {
    throw new HttpsError("invalid-argument", "Missing roomName or identity");
  }

  const apiKey = process.env.LIVEKIT_API_KEY;
  const apiSecret = process.env.LIVEKIT_API_SECRET;

  if (!apiKey || !apiSecret) {
    throw new HttpsError("failed-precondition", "Server secrets not configured");
  }

  const at = new AccessToken(apiKey, apiSecret, {
    identity: identity,
    name: name || identity,
  });

  at.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
    // If lecturer, they can record or manage the room
    roomAdmin: isHost,
  });

  return {
    token: await at.toJwt(),
  };
});

exports.seedLecturerCodes = onCall(async (request) => {
  // Ensure the user is authenticated (you can add more specific admin checks here)
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be authenticated to run this function.');
  }

  const codes = request.data.codes;
  if (!codes || !Array.isArray(codes) || codes.length === 0) {
    throw new HttpsError('invalid-argument', 'Please provide an array of codes.');
  }

  const batch = db.batch();
  const codesCollection = db.collection('lecturer_codes');

  codes.forEach(code => {
    if (typeof code === 'string' && code.trim().length > 0) {
      const docRef = codesCollection.doc(); // Auto-generate document ID
      batch.set(docRef, {
        code: code.trim().toUpperCase(),
        used: false,
        usedBy: null,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  });

  await batch.commit();

  console.log(`Successfully seeded ${codes.length} lecturer codes.`);
  return { success: true, count: codes.length };
});


// Auto-delete old messages after 5 minutes (Runs every minute for testing)
exports.cleanupOldMessages = functions.pubsub.schedule('* * * * *').onRun(async (context) => {
  try {
    // Calculate cutoff time (5 minutes ago)
    const cutoff = Date.now() - (5 * 60 * 1000);
    
    // Get messages older than cutoff (limit to 500 for batch safety)
    const oldMessages = await db.collection('group_chat')
      .where('timestamp', '<', Timestamp.fromMillis(cutoff))
      .limit(500)
      .get();
    
    if (oldMessages.empty) {
      console.log('No old messages found to delete.');
      return null;
    }
    
    const batch = db.batch();
    oldMessages.docs.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
    console.log(`Successfully deleted ${oldMessages.size} old messages.`);
    return null;
  } catch (error) {
    console.error('Error in cleanupOldMessages:', error);
    return null;
  }
});