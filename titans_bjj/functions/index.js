const admin = require('firebase-admin');
const functions = require('firebase-functions');

admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function requireString(value, field) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `${field} deve ser uma string valida.`,
    );
  }
  return value.trim();
}

function isExpired(expiresAt) {
  if (!expiresAt) return false;
  if (typeof expiresAt.toDate === 'function') {
    return expiresAt.toDate().getTime() < Date.now();
  }
  if (expiresAt instanceof Date) {
    return expiresAt.getTime() < Date.now();
  }
  return false;
}

function userRef(academyId, uid) {
  return db.collection('academies').doc(academyId).collection('users').doc(uid);
}

async function copyDocument(sourceRef, targetRef) {
  const snap = await sourceRef.get();
  if (!snap.exists) return;
  await targetRef.set(snap.data(), { merge: true });
}

async function copyCollection(sourceRef, targetRef) {
  const snap = await sourceRef.get();
  let batch = db.batch();
  let writes = 0;

  for (const doc of snap.docs) {
    batch.set(targetRef.doc(doc.id), doc.data(), { merge: true });
    writes += 1;
    if (writes === 450) {
      await batch.commit();
      batch = db.batch();
      writes = 0;
    }
  }

  if (writes > 0) await batch.commit();
}

async function copyConfirmedSubcollections(sourceRef, targetRef) {
  await copyDocument(
    sourceRef.collection('progress').doc('profile'),
    targetRef.collection('progress').doc('profile'),
  );
  await copyDocument(
    sourceRef.collection('nutrition').doc('profile'),
    targetRef.collection('nutrition').doc('profile'),
  );
  await copyCollection(
    sourceRef.collection('nutrition').doc('profile').collection('meals'),
    targetRef.collection('nutrition').doc('profile').collection('meals'),
  );
  await copyCollection(
    sourceRef.collection('training_sessions'),
    targetRef.collection('training_sessions'),
  );
}

exports.acceptAcademyInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario autenticado obrigatorio.',
    );
  }

  const academyId = requireString(data && data.academyId, 'academyId');
  const inviteId = requireString(data && data.inviteId, 'inviteId');
  const authUid = context.auth.uid;
  const authEmail = normalizeEmail(context.auth.token.email);

  if (!authEmail) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Usuario autenticado precisa ter e-mail.',
    );
  }

  const inviteRef = db
    .collection('academies')
    .doc(academyId)
    .collection('invites')
    .doc(inviteId);

  let pendingProfileId = null;
  let sourceRef = null;
  let targetRef = null;

  await db.runTransaction(async (transaction) => {
    const inviteSnap = await transaction.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Convite nao encontrado.');
    }

    const invite = inviteSnap.data() || {};
    if (invite.academyId !== academyId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite pertence a outra academia.',
      );
    }
    if (invite.status !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite nao esta pendente.',
      );
    }
    if (String(invite.acceptedAuthUid || '').trim()) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Convite ja possui usuario vinculado.',
      );
    }
    if (isExpired(invite.expiresAt)) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Convite expirado.');
    }
    if (normalizeEmail(invite.emailNormalized) !== authEmail) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Convite nao pertence ao e-mail autenticado.',
      );
    }

    pendingProfileId = String(invite.pendingProfileId || '').trim();
    if (!pendingProfileId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite sem perfil pendente.',
      );
    }

    sourceRef = userRef(academyId, pendingProfileId);
    targetRef = userRef(academyId, authUid);

    const sourceSnap = await transaction.get(sourceRef);
    if (!sourceSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Perfil pendente nao encontrado.',
      );
    }

    const targetSnap = await transaction.get(targetRef);
    if (targetSnap.exists) {
      const migratedFrom = String(
        (targetSnap.data() || {}).migratedFromPendingProfileId || '',
      );
      if (migratedFrom !== pendingProfileId) {
        throw new functions.https.HttpsError(
          'already-exists',
          'Usuario Auth ja possui perfil nesta academia.',
        );
      }
      return;
    }

    transaction.set(targetRef, {
      ...sourceSnap.data(),
      uid: authUid,
      academyId,
      migratedFromPendingProfileId: pendingProfileId,
      authLinkedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await copyConfirmedSubcollections(sourceRef, targetRef);

  await db.runTransaction(async (transaction) => {
    const inviteSnap = await transaction.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Convite nao encontrado.');
    }
    const invite = inviteSnap.data() || {};
    if (invite.academyId !== academyId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite pertence a outra academia.',
      );
    }
    if (invite.status !== 'pending') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Convite nao esta pendente.',
      );
    }
    if (String(invite.acceptedAuthUid || '').trim()) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Convite ja possui usuario vinculado.',
      );
    }
    if (isExpired(invite.expiresAt)) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Convite expirado.');
    }
    if (normalizeEmail(invite.emailNormalized) !== authEmail) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Convite nao pertence ao e-mail autenticado.',
      );
    }
    if (String(invite.pendingProfileId || '').trim() !== pendingProfileId) {
      throw new functions.https.HttpsError(
        'aborted',
        'Perfil pendente mudou durante o aceite.',
      );
    }

    transaction.set(inviteRef, {
      status: 'accepted',
      acceptedAuthUid: authUid,
      acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true, academyId, inviteId, acceptedAuthUid: authUid };
});