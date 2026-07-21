const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('localhost') ? false : { rejectUnauthorized: false }
});

async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id              SERIAL PRIMARY KEY,
        firebase_uid    TEXT UNIQUE NOT NULL,
        display_name    TEXT NOT NULL,
        email           TEXT UNIQUE NOT NULL,
        photo_url       TEXT,
        fcm_token       TEXT,
        status          TEXT DEFAULT 'Hey there! I am using WhatsApp Clone.',
        last_seen       TIMESTAMPTZ DEFAULT NOW(),
        created_at      TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS contacts (
        id              SERIAL PRIMARY KEY,
        user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        contact_user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at      TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(user_id, contact_user_id)
      );

      CREATE TABLE IF NOT EXISTS conversations (
        id              SERIAL PRIMARY KEY,
        type            TEXT NOT NULL DEFAULT 'direct', -- 'direct' | 'group'
        name            TEXT,
        avatar_url      TEXT,
        created_by      INT REFERENCES users(id),
        created_at      TIMESTAMPTZ DEFAULT NOW(),
        updated_at      TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS participants (
        id              SERIAL PRIMARY KEY,
        conversation_id INT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        user_id         INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        joined_at       TIMESTAMPTZ DEFAULT NOW(),
        UNIQUE(conversation_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS messages (
        id              SERIAL PRIMARY KEY,
        conversation_id INT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
        sender_id       INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        type            TEXT NOT NULL DEFAULT 'text', -- text|image|video|audio|file
        content         TEXT,
        file_url        TEXT,
        file_name       TEXT,
        file_size       INT,
        mime_type       TEXT,
        reply_to_id     INT REFERENCES messages(id),
        status          TEXT DEFAULT 'sent', -- sent|delivered|read
        created_at      TIMESTAMPTZ DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_participants_user     ON participants(user_id);
      CREATE INDEX IF NOT EXISTS idx_participants_conv     ON participants(conversation_id);
    `);
    console.log('✅ Database schema initialized');
  } finally {
    client.release();
  }
}

module.exports = { pool, initDB };
