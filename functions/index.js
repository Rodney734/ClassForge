const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.aiTutor = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { message, userId, level } = data;
  const userUid = context.auth.uid;

  // Rate limiting
  const rateLimitRef = admin.firestore()
    .collection('ai_rate_limits')
    .doc(userUid);
  
  const rateLimit = await rateLimitRef.get();
  const now = Date.now();
  const limit = 50; // messages per hour
  
  if (rateLimit.exists) {
    const data = rateLimit.data();
    const lastReset = data.lastReset || 0;
    const count = data.count || 0;
    
    if (now - lastReset > 3600000) {
      await rateLimitRef.set({ count: 1, lastReset: now });
    } else if (count >= limit) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Rate limit exceeded. Please try again later.'
      );
    } else {
      await rateLimitRef.update({ count: count + 1 });
    }
  } else {
    await rateLimitRef.set({ count: 1, lastReset: now });
  }

  // System prompt
  const systemPrompt = `You are ClassForge AI, an educational tutor for a student at Level ${level}. Your purpose is to help students learn academic subjects. Be patient, encouraging, and professional. Explain concepts step-by-step with clear examples. Politely decline any requests that are not related to academic subjects.`;

  // Get conversation history
  const historySnapshot = await admin.firestore()
    .collection('users').doc(userUid)
    .collection('ai_tutor_messages')
    .orderBy('timestamp', 'desc')
    .limit(10)
    .get();

  const messages = [
    { role: 'system', content: systemPrompt }
  ];

  // Add history
  const history = historySnapshot.docs.reverse();
  for (const doc of history) {
    const data = doc.data();
    if (data.isUser) {
      messages.push({ role: 'user', content: data.text });
    } else {
      messages.push({ role: 'assistant', content: data.text });
    }
  }

  messages.push({ role: 'user', content: message });

  // Call AI API
  try {
    // Using Mistral AI API via the secure Cloud Function proxy
    const mistralApiUrl = 'https://api.mistral.ai/v1/chat/completions';

    const response = await axios.post(
      mistralApiUrl,
      {
        model: 'mistral-small',
        messages: messages,
        temperature: 0.7,
        max_tokens: 2000,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${functions.config().mistral.api_key}`,
        },
      }
    );

    const aiResponse = response.data.choices[0].message.content;

    // Save AI response to the user's message subcollection
    await admin.firestore()
      .collection('users').doc(userUid)
      .collection('ai_tutor_messages').add({
      'text': aiResponse,
      'isUser': false,
      'timestamp': admin.firestore.FieldValue.serverTimestamp(),
    });

    // The function now saves the data and doesn't need to return it.
    return { success: true, message: "AI response saved." };
  } catch (error) {
    console.error('AI API Error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get AI response'
    );
  }
});

function generateSuggestions(message) {
  const topics = ['Flutter', 'SQL', 'Python', 'JavaScript', 'APIs'];
  const suggestions = [];
  for (const topic of topics) {
    if (message.toLowerCase().includes(topic.toLowerCase())) {
      suggestions.push(`More about ${topic}`);
      suggestions.push(`Quiz me on ${topic}`);
    }
  }
  if (suggestions.length === 0) {
    suggestions.push('Explain Flutter');
    suggestions.push('Quiz me on SQL');
  }
  return suggestions.slice(0, 4);
}