const { getAuth, getFirestore } = require('../firebase');

async function requireAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing Authorization header' });
  }
  const idToken = authHeader.slice(7);
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    req.uid = decoded.uid;
    req.decodedToken = decoded;
    try {
      const db = getFirestore();
      const userDoc = await db.collection('users').doc(decoded.uid).get();
      req.user = userDoc.exists
        ? { uid: decoded.uid, ...userDoc.data() }
        : { uid: decoded.uid, email: decoded.email, displayName: decoded.name };
    } catch (_) {
      req.user = { uid: decoded.uid, email: decoded.email };
    }
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

module.exports = { requireAuth };
