const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

exports.aiTutor = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const message = String(data?.message ?? '').trim();
  const userUid = context.auth.uid;

  if (!message) {
    throw new functions.https.HttpsError('invalid-argument', 'A message is required.');
  }

  const userDoc = await admin.firestore().collection('users').doc(userUid).get();
  const level = Number(userDoc.data()?.level ?? 0);

  const systemPrompt = `You are ClassForge AI, an educational tutor for university students in Malawi. You are fluent in both English and Chichewa. Your purpose is to help students learn academic subjects, including programming, databases, AI, and other studies. Be patient and clear. For level ${level}, explain step-by-step using examples when helpful. If a request is unrelated to learning, politely redirect to academic help.`;

  const historySnapshot = await admin.firestore()
    .collection('users')
    .doc(userUid)
    .collection('ai_tutor_messages')
    .orderBy('timestamp', 'desc')
    .limit(10)
    .get();

  const messages = [{ role: 'system', content: systemPrompt }];
  const history = historySnapshot.docs.reverse();
  for (const doc of history) {
    const data = doc.data();
    messages.push({ role: data.isUser ? 'user' : 'assistant', content: String(data.text ?? '') });
  }

  messages.push({ role: 'user', content: message });

  await admin.firestore().collection('users').doc(userUid).collection('ai_tutor_messages').add({
    text: message,
    isUser: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const apiKey = process.env.MISTRAL_API_KEY || (functions.config().mistral && functions.config().mistral.api_key) || '';
  if (!apiKey) {
    throw new functions.https.HttpsError('internal', 'Mistral API key is not configured.');
  }

  try {
    const response = await axios.post('https://api.mistral.ai/v1/chat/completions', {
      model: 'mistral-small-latest',
      messages,
      temperature: 0.7,
    }, {
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
    });

    const aiResponse = response.data?.choices?.[0]?.message?.content || 'I’m sorry, I couldn’t generate a response right now.';

    await admin.firestore().collection('users').doc(userUid).collection('ai_tutor_messages').add({
      text: aiResponse,
      isUser: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  } catch (error) {
    console.error('AI API Error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get AI response');
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