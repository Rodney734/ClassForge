import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {v4 as uuidv4} from "uuid";

// Initialize the Firebase Admin SDK
admin.initializeApp();

export const aiTutor = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated",
    );
  }

  const message = String(data?.message ?? "").trim();
  const userUid = context.auth.uid;

  if (!message) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "A message is required.",
    );
  }

  const level = Number(data?.level ?? 0);
  const systemPrompt = `You are ClassForge AI, an educational tutor for university students in Malawi. You are fluent in both English and Chichewa. Your purpose is to help students learn academic subjects, including programming, databases, AI, and other studies. Be patient and clear. For level ${level}, explain step-by-step using examples when helpful. If a request is unrelated to learning, politely redirect to academic help.`;

  const historySnapshot = await admin.firestore()
    .collection("users")
    .doc(userUid)
    .collection("ai_tutor_messages")
    .orderBy("timestamp", "desc")
    .limit(10)
    .get();

  const messages = [{role: "system", content: systemPrompt}];
  const history = historySnapshot.docs.reverse();
  for (const doc of history) {
    const messageDoc = doc.data();
    const role = messageDoc.isUser ? "user" : "assistant";
    messages.push({role, content: String(messageDoc.text ?? "")});
  }

  messages.push({role: "user", content: message});

  await admin.firestore()
    .collection("users")
    .doc(userUid)
    .collection("ai_tutor_messages")
    .add({
      text: message,
      isUser: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

  const apiKey = process.env.MISTRAL_API_KEY ?? (functions.config().mistral && functions.config().mistral.api_key) ?? "";
  if (!apiKey) {
    throw new functions.https.HttpsError(
      "internal",
      "Mistral API key is not configured.",
    );
  }

  try {
    const response = await fetch("https://api.mistral.ai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: "mistral-small-latest",
        messages,
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(errorBody || "Mistral request failed");
    }

    const responseBody = await response.json();
    const aiResponse = responseBody.choices?.[0]?.message?.content ?? "I’m sorry, I couldn’t generate a response right now.";

    await admin.firestore()
      .collection("users")
      .doc(userUid)
      .collection("ai_tutor_messages")
      .add({
        text: aiResponse,
        isUser: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
    };
  } catch (error) {
    functions.logger.error("AI API Error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to get AI response",
    );
  }
});

/**
 * Triggered when a document in 'scheduled_classes' is updated.
 * If the status changes to 'live', it sends a "call" notification
 * to all students of the corresponding level.
 */
export const onClassGoLive = functions
  // Apply runtime options for v1 functions to control costs/concurrency.
  .runWith({maxInstances: 10})
  .region("us-central1") // Example: specify region
  .firestore
  .document("scheduled_classes/{classId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // --- Condition Check ---
    // Exit if status is not 'live' or if it was already 'live'.
    if (afterData.status !== "live" || beforeData.status === "live") {
      const logMessage = `Function exiting: Status is not 'live' or was already 'live'. Status: ${afterData.status}`;
      functions.logger.log(logMessage);
      return null;
    }

    const classId = context.params.classId;
    const level = afterData.level;
    // Provide default names if they are missing from the document.
    const courseName = afterData.courseName ?? "Live Class";
    const lecturerName = afterData.lecturerName ?? "Lecturer";

    functions.logger.log(
      `Class '${courseName}' (ID: ${classId}) for Level ${level} just went live. Preparing notifications.`,
    );

    // --- Get Target Students ---
    // Find all users who are students and match the class level.
    const usersSnapshot = await admin
      .firestore()
      .collection("users")
      .where("role", "==", "student")
      .where("level", "==", level)
      .get();

    if (usersSnapshot.empty) {
      functions.logger.log(
        `No students found for Level ${level}. No notifications sent.`,
      );
      return null;
    }

    // --- Collect FCM Tokens ---
    // Extract the push notification token from each student's profile.
    const tokens: string[] = [];
    usersSnapshot.forEach((doc) => {
      const user = doc.data();
      if (user.fcmToken) {
        tokens.push(user.fcmToken);
      }
    });

    if (tokens.length === 0) {
      functions.logger.log(
        `Found ${usersSnapshot.size} students, but none have FCM tokens. ` +
        "No notifications sent.",
      );
      return null;
    }

    functions.logger.log(
      `Found ${tokens.length} tokens. Preparing to send messages.`);

    // --- Construct the Notification Payload ---
    // This payload is specifically designed for the flutter_callkit_incoming package.
    const callUUID = uuidv4(); // Generate a unique ID for this call event.
    const payload = {
      data: {
        // Main data for flutter_callkit_incoming
        uuid: callUUID,
        callerName: lecturerName, // Shows up as the caller
        handle: courseName, // Shows up as the "number" or topic
        appName: "ClassForge",
        // Type '1' indicates a video call for flutter_callkit_incoming
        type: "1",
        avatar: "https://i.pravatar.cc/100", // Optional: lecturer's profile pic URL
        duration: "30000", // 30 seconds

        // Custom data for your app to use when the call is answered
        extra: JSON.stringify({
          classId: classId,
          courseName: courseName,
          lecturerName: lecturerName,
        }),
      },
      tokens: tokens,
    };

    // --- Send the Notifications ---
    try {
      const response = await admin.messaging().sendMulticast(payload);
      functions.logger.log(
        `Successfully sent ${response.successCount} call notifications. ` +
        `Failed: ${response.failureCount}.`,
      );

      // Optional: Clean up failed tokens if needed
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            functions.logger.error(
              `Failed to send to token: ${tokens[idx]}`,
              resp.error,
            );
          }
        });
      }
    } catch (error) {
      functions.logger.error("Error sending multicast message:", error);
    }

    return null;
  });

/**
 * Removes chat relay data after clients have had time to receive it.
 * Each device keeps its own local copy, so Firebase is not the chat history.
 */
export const purgeEphemeralChatMessages = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const firestore = admin.firestore();
    const now = Date.now();
    const messageSnapshot = await firestore
      .collection("messages")
      .orderBy("timestamp", "asc")
      .limit(400)
      .get();
    const expiredMessages = messageSnapshot.docs.filter((message) => {
      const data = message.data();
      const expiresAt = data.expiresAt?.toMillis?.();
      const timestamp = data.timestamp?.toMillis?.();
      return expiresAt != null ? expiresAt <= now :
        timestamp != null && timestamp <= now - 10 * 60 * 1000;
    });

    if (expiredMessages.length === 0) return null;

    const batch = firestore.batch();
    const bucket = admin.storage().bucket();

    for (const message of expiredMessages) {
      const data = message.data();
      const reactions = await firestore
        .collection("message_reactions")
        .where("messageId", "==", message.id)
        .get();

      reactions.docs.forEach((reaction) => batch.delete(reaction.ref));
      batch.delete(message.ref);

      if (typeof data.filePath === "string" && data.filePath.length > 0) {
        await bucket.file(data.filePath).delete().catch(() => undefined);
      }
    }

    await batch.commit();
    functions.logger.info(
      `Purged ${expiredMessages.length} ephemeral chat messages.`,
    );
    return null;
  });
