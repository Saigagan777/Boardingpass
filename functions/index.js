const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

// Mirrors profile restrictions into Firebase Authentication. It only responds
// to a restriction state change, so its audit write cannot create a loop.
exports.syncAccountRestriction = onDocumentWritten(
  'users/{userId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const wasRestricted = before?.isLoginRestricted === true;
    const isRestricted = after.isLoginRestricted === true;
    if (wasRestricted === isRestricted) return;

    try {
      await admin.auth().updateUser(event.params.userId, {
        disabled: isRestricted,
      });
      await event.data.after.ref.set(
        {
          authAccessSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
          authDisabled: isRestricted,
        },
        { merge: true },
      );
      logger.info('Firebase Auth restriction synchronized', {
        userId: event.params.userId,
        isRestricted,
      });
    } catch (error) {
      logger.error('Unable to synchronize Firebase Auth restriction', {
        userId: event.params.userId,
        error,
      });
      throw error;
    }
  },
);
