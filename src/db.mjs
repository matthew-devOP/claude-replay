/**
 * SQLite-based persistent cache for session metadata, stats, favorites, and tags.
 * Database stored at ~/.claude-replay/cache.db
 */

import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
let Database;
try { Database = require("better-sqlite3"); } catch { throw new Error("better-sqlite3 not installed"); }
import { join } from "node:path";
import { homedir } from "node:os";
import { mkdirSync, existsSync, statSync } from "node:fs";

// Use /app/data in Docker (writable), or ~/.claude-replay locally
const DB_DIR = process.env.CLAUDE_REPLAY_DATA || join(homedir(), ".claude-replay");
const DB_PATH = join(DB_DIR, "cache.db");

let db = null;

export function getDb() {
  if (db) return db;
  mkdirSync(DB_DIR, { recursive: true });
  db = new Database(DB_PATH);
  db.pragma("journal_mode = WAL");
  db.pragma("synchronous = NORMAL");
  initSchema();
  return db;
}

function initSchema() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS session_meta (
      path TEXT PRIMARY KEY,
      project_dir TEXT NOT NULL,
      session_id TEXT NOT NULL,
      file_mtime TEXT,
      file_size INTEGER DEFAULT 0,
      turn_count INTEGER DEFAULT 0,
      duration INTEGER,
      preview TEXT DEFAULT '',
      user_previews TEXT DEFAULT '[]',
      first_timestamp TEXT,
      last_timestamp TEXT,
      cached_at TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_session_project ON session_meta(project_dir);

    CREATE TABLE IF NOT EXISTS session_stats (
      path TEXT PRIMARY KEY,
      file_mtime TEXT,
      stats_json TEXT NOT NULL,
      cached_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS favorites (
      path TEXT PRIMARY KEY,
      session_id TEXT NOT NULL,
      preview TEXT DEFAULT '',
      project_dir TEXT DEFAULT '',
      pinned_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS tags (
      path TEXT NOT NULL,
      tag TEXT NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (path, tag)
    );

    CREATE INDEX IF NOT EXISTS idx_tags_path ON tags(path);
  `);
}

// ─── Session metadata cache ───

export function getCachedMeta(path, currentMtime) {
  const d = getDb();
  const row = d.prepare("SELECT * FROM session_meta WHERE path = ?").get(path);
  if (!row) return null;
  // Invalidate if file changed
  if (row.file_mtime !== currentMtime) return null;
  return {
    sessionId: row.session_id,
    path: row.path,
    date: row.file_mtime,
    size: row.file_size,
    turnCount: row.turn_count,
    duration: row.duration,
    preview: row.preview,
    userPreviews: JSON.parse(row.user_previews || "[]"),
  };
}

export function setCachedMeta(path, projectDir, meta) {
  const d = getDb();
  d.prepare(`
    INSERT OR REPLACE INTO session_meta
    (path, project_dir, session_id, file_mtime, file_size, turn_count, duration, preview, user_previews, first_timestamp, last_timestamp, cached_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(
    path, projectDir, meta.sessionId, meta.date, meta.size || 0,
    meta.turnCount || 0, meta.duration || null,
    meta.preview || "", JSON.stringify(meta.userPreviews || []),
    meta.firstTimestamp || null, meta.lastTimestamp || null,
    new Date().toISOString()
  );
}

// ─── Session stats cache ───

export function getCachedStats(path, currentMtime) {
  const d = getDb();
  const row = d.prepare("SELECT * FROM session_stats WHERE path = ?").get(path);
  if (!row) return null;
  if (row.file_mtime !== currentMtime) return null;
  return JSON.parse(row.stats_json);
}

export function setCachedStats(path, mtime, stats) {
  const d = getDb();
  d.prepare(`
    INSERT OR REPLACE INTO session_stats (path, file_mtime, stats_json, cached_at)
    VALUES (?, ?, ?, ?)
  `).run(path, mtime, JSON.stringify(stats), new Date().toISOString());
}

// ─── Favorites ───

export function getFavorites() {
  const d = getDb();
  return d.prepare("SELECT * FROM favorites ORDER BY pinned_at DESC").all().map(r => ({
    path: r.path, id: r.session_id, preview: r.preview, projectDirName: r.project_dir,
  }));
}

export function addFavorite(path, sessionId, preview, projectDir) {
  const d = getDb();
  d.prepare(`
    INSERT OR REPLACE INTO favorites (path, session_id, preview, project_dir, pinned_at)
    VALUES (?, ?, ?, ?, ?)
  `).run(path, sessionId, preview || "", projectDir || "", new Date().toISOString());
}

export function removeFavorite(path) {
  const d = getDb();
  d.prepare("DELETE FROM favorites WHERE path = ?").run(path);
}

export function isFavorite(path) {
  const d = getDb();
  return !!d.prepare("SELECT 1 FROM favorites WHERE path = ?").get(path);
}

// ─── Tags ───

export function getTagsForSession(path) {
  const d = getDb();
  return d.prepare("SELECT tag FROM tags WHERE path = ? ORDER BY created_at").all(path).map(r => r.tag);
}

export function getAllTaggedSessions() {
  const d = getDb();
  const rows = d.prepare("SELECT path, tag FROM tags ORDER BY path, created_at").all();
  const result = {};
  for (const r of rows) {
    if (!result[r.path]) result[r.path] = [];
    result[r.path].push(r.tag);
  }
  return result;
}

export function addTag(path, tag) {
  const d = getDb();
  d.prepare("INSERT OR IGNORE INTO tags (path, tag, created_at) VALUES (?, ?, ?)").run(path, tag, new Date().toISOString());
}

export function removeTag(path, tag) {
  const d = getDb();
  d.prepare("DELETE FROM tags WHERE path = ? AND tag = ?").run(path, tag);
}

export function setTags(path, tags) {
  const d = getDb();
  const del = d.prepare("DELETE FROM tags WHERE path = ?");
  const ins = d.prepare("INSERT INTO tags (path, tag, created_at) VALUES (?, ?, ?)");
  const now = new Date().toISOString();
  d.transaction(() => {
    del.run(path);
    for (const tag of tags) ins.run(path, tag, now);
  })();
}

// ─── Cache stats ───

export function getCacheInfo() {
  const d = getDb();
  const metaCount = d.prepare("SELECT COUNT(*) as c FROM session_meta").get().c;
  const statsCount = d.prepare("SELECT COUNT(*) as c FROM session_stats").get().c;
  const favCount = d.prepare("SELECT COUNT(*) as c FROM favorites").get().c;
  const tagCount = d.prepare("SELECT COUNT(*) as c FROM tags").get().c;
  let dbSize = 0;
  try { dbSize = statSync(DB_PATH).size; } catch {}
  return { metaCount, statsCount, favCount, tagCount, dbSize, dbPath: DB_PATH };
}
