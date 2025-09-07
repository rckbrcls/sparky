import * as SQLite from "expo-sqlite";

export interface Reminder {
  id: string;
  title: string;
  notes?: string;
  person?: string;
  project?: string;
  location?: string;
  type: "once" | "recurring" | "by_person_project" | "by_location";
  rrule?: string; // RRULE string for recurring reminders
  nextFireAt?: string; // ISO string
  status: "active" | "completed" | "overdue" | "archived";
  completedAt?: string; // ISO string
  notificationId?: string;
  createdAt: string; // ISO string
  updatedAt: string; // ISO string
}

export interface SnoozeHistory {
  id: string;
  reminderId: string;
  snoozeCount: number;
  originalFireAt: string; // ISO string
  newFireAt: string; // ISO string
  createdAt: string; // ISO string
}

export interface ImportantDate {
  id: string;
  title: string;
  description?: string;
  date: string; // ISO string (yearly recurring)
  type: "birthday" | "renewal" | "due_date";
  person?: string;
  leadTimes: string; // JSON array of lead times like [7, 1, 0.08] (days)
  createdAt: string; // ISO string
  updatedAt: string; // ISO string
}

export interface ReviewStage {
  id: string;
  reminderId: string;
  currentStage: number; // 0-6 (1d, 3d, 7d, 14d, 30d, 60d, 90d)
  lastReviewAt: string; // ISO string
  ignoreCount: number;
  createdAt: string; // ISO string
  updatedAt: string; // ISO string
}

class Database {
  private db: SQLite.SQLiteDatabase | null = null;

  async initialize(): Promise<void> {
    this.db = await SQLite.openDatabaseAsync("reminders.db");
    await this.createTables();
  }

  private async createTables(): Promise<void> {
    if (!this.db) throw new Error("Database not initialized");

    await this.db.execAsync(`
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        notes TEXT,
        person TEXT,
        project TEXT,
        location TEXT,
        type TEXT NOT NULL CHECK (type IN ('once', 'recurring', 'by_person_project', 'by_location')),
        rrule TEXT,
        nextFireAt TEXT,
        status TEXT NOT NULL CHECK (status IN ('active', 'completed', 'overdue', 'archived')),
        completedAt TEXT,
        notificationId TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    `);

    await this.db.execAsync(`
      CREATE TABLE IF NOT EXISTS snooze_history (
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        snoozeCount INTEGER NOT NULL,
        originalFireAt TEXT NOT NULL,
        newFireAt TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (reminderId) REFERENCES reminders (id) ON DELETE CASCADE
      );
    `);

    await this.db.execAsync(`
      CREATE TABLE IF NOT EXISTS important_dates (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('birthday', 'renewal', 'due_date')),
        person TEXT,
        leadTimes TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    `);

    await this.db.execAsync(`
      CREATE TABLE IF NOT EXISTS review_stages (
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        currentStage INTEGER NOT NULL,
        lastReviewAt TEXT NOT NULL,
        ignoreCount INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (reminderId) REFERENCES reminders (id) ON DELETE CASCADE
      );
    `);

    // Create indexes for better performance
    await this.db.execAsync(`
      CREATE INDEX IF NOT EXISTS idx_reminders_nextFireAt ON reminders (nextFireAt);
      CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders (status);
      CREATE INDEX IF NOT EXISTS idx_reminders_person ON reminders (person);
      CREATE INDEX IF NOT EXISTS idx_reminders_project ON reminders (project);
      CREATE INDEX IF NOT EXISTS idx_snooze_history_reminderId ON snooze_history (reminderId);
      CREATE INDEX IF NOT EXISTS idx_review_stages_reminderId ON review_stages (reminderId);
    `);
  }

  async getAllReminders(): Promise<Reminder[]> {
    if (!this.db) throw new Error("Database not initialized");
    const result = await this.db.getAllAsync(
      "SELECT * FROM reminders ORDER BY nextFireAt ASC"
    );
    return result as Reminder[];
  }

  async getReminderById(id: string): Promise<Reminder | null> {
    if (!this.db) throw new Error("Database not initialized");
    const result = await this.db.getFirstAsync(
      "SELECT * FROM reminders WHERE id = ?",
      [id]
    );
    return result as Reminder | null;
  }

  async createReminder(
    reminder: Omit<Reminder, "id" | "createdAt" | "updatedAt">
  ): Promise<string> {
    if (!this.db) throw new Error("Database not initialized");

    const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
    const now = new Date().toISOString();

    await this.db.runAsync(
      `
      INSERT INTO reminders (
        id, title, notes, person, project, location, type, rrule, 
        nextFireAt, status, completedAt, notificationId, createdAt, updatedAt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `,
      [
        id,
        reminder.title,
        reminder.notes || null,
        reminder.person || null,
        reminder.project || null,
        reminder.location || null,
        reminder.type,
        reminder.rrule || null,
        reminder.nextFireAt || null,
        reminder.status,
        reminder.completedAt || null,
        reminder.notificationId || null,
        now,
        now,
      ]
    );

    return id;
  }

  async updateReminder(id: string, updates: Partial<Reminder>): Promise<void> {
    if (!this.db) throw new Error("Database not initialized");

    const fields = Object.keys(updates).filter((key) => key !== "id");
    const setClause = fields.map((field) => `${field} = ?`).join(", ");
    const values = fields.map((field) => (updates as any)[field]);

    await this.db.runAsync(
      `
      UPDATE reminders SET ${setClause}, updatedAt = ? WHERE id = ?
    `,
      [...values, new Date().toISOString(), id]
    );
  }

  async deleteReminder(id: string): Promise<void> {
    if (!this.db) throw new Error("Database not initialized");
    await this.db.runAsync("DELETE FROM reminders WHERE id = ?", [id]);
  }

  async getTodayReminders(): Promise<Reminder[]> {
    if (!this.db) throw new Error("Database not initialized");
    const today = new Date();
    const startOfDay = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate()
    ).toISOString();
    const endOfDay = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate() + 1
    ).toISOString();

    const result = await this.db.getAllAsync(
      `
      SELECT * FROM reminders 
      WHERE nextFireAt >= ? AND nextFireAt < ? AND status = 'active'
      ORDER BY nextFireAt ASC
    `,
      [startOfDay, endOfDay]
    );

    return result as Reminder[];
  }

  async getOverdueReminders(): Promise<Reminder[]> {
    if (!this.db) throw new Error("Database not initialized");
    const now = new Date().toISOString();

    const result = await this.db.getAllAsync(
      `
      SELECT * FROM reminders 
      WHERE nextFireAt < ? AND status = 'active'
      ORDER BY nextFireAt ASC
    `,
      [now]
    );

    return result as Reminder[];
  }

  async getUpcomingReminders(): Promise<Reminder[]> {
    if (!this.db) throw new Error("Database not initialized");
    const now = new Date().toISOString();

    const result = await this.db.getAllAsync(
      `
      SELECT * FROM reminders 
      WHERE nextFireAt > ? AND status = 'active'
      ORDER BY nextFireAt ASC
    `,
      [now]
    );

    return result as Reminder[];
  }

  async getRemindersByPersonOrProject(
    personOrProject: string
  ): Promise<Reminder[]> {
    if (!this.db) throw new Error("Database not initialized");

    const result = await this.db.getAllAsync(
      `
      SELECT * FROM reminders 
      WHERE (person = ? OR project = ?) AND status = 'active'
      ORDER BY nextFireAt ASC
    `,
      [personOrProject, personOrProject]
    );

    return result as Reminder[];
  }

  // Snooze History methods
  async createSnoozeHistory(
    snooze: Omit<SnoozeHistory, "id" | "createdAt">
  ): Promise<string> {
    if (!this.db) throw new Error("Database not initialized");

    const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
    const now = new Date().toISOString();

    await this.db.runAsync(
      `
      INSERT INTO snooze_history (id, reminderId, snoozeCount, originalFireAt, newFireAt, createdAt)
      VALUES (?, ?, ?, ?, ?, ?)
    `,
      [
        id,
        snooze.reminderId,
        snooze.snoozeCount,
        snooze.originalFireAt,
        snooze.newFireAt,
        now,
      ]
    );

    return id;
  }

  async getSnoozeHistoryForReminder(
    reminderId: string
  ): Promise<SnoozeHistory[]> {
    if (!this.db) throw new Error("Database not initialized");

    const result = await this.db.getAllAsync(
      `
      SELECT * FROM snooze_history 
      WHERE reminderId = ? 
      ORDER BY createdAt DESC
    `,
      [reminderId]
    );

    return result as SnoozeHistory[];
  }

  // Important Dates methods
  async createImportantDate(
    date: Omit<ImportantDate, "id" | "createdAt" | "updatedAt">
  ): Promise<string> {
    if (!this.db) throw new Error("Database not initialized");

    const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
    const now = new Date().toISOString();

    await this.db.runAsync(
      `
      INSERT INTO important_dates (id, title, description, date, type, person, leadTimes, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `,
      [
        id,
        date.title,
        date.description || null,
        date.date,
        date.type,
        date.person || null,
        date.leadTimes,
        now,
        now,
      ]
    );

    return id;
  }

  async getAllImportantDates(): Promise<ImportantDate[]> {
    if (!this.db) throw new Error("Database not initialized");
    const result = await this.db.getAllAsync(
      "SELECT * FROM important_dates ORDER BY date ASC"
    );
    return result as ImportantDate[];
  }

  // Review Stages methods
  async createReviewStage(
    stage: Omit<ReviewStage, "id" | "createdAt" | "updatedAt">
  ): Promise<string> {
    if (!this.db) throw new Error("Database not initialized");

    const id = Date.now().toString() + Math.random().toString(36).substr(2, 9);
    const now = new Date().toISOString();

    await this.db.runAsync(
      `
      INSERT INTO review_stages (id, reminderId, currentStage, lastReviewAt, ignoreCount, createdAt, updatedAt)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
      [
        id,
        stage.reminderId,
        stage.currentStage,
        stage.lastReviewAt,
        stage.ignoreCount,
        now,
        now,
      ]
    );

    return id;
  }

  async getReviewStageForReminder(
    reminderId: string
  ): Promise<ReviewStage | null> {
    if (!this.db) throw new Error("Database not initialized");

    const result = await this.db.getFirstAsync(
      `
      SELECT * FROM review_stages WHERE reminderId = ?
    `,
      [reminderId]
    );

    return result as ReviewStage | null;
  }

  async updateReviewStage(
    reminderId: string,
    updates: Partial<ReviewStage>
  ): Promise<void> {
    if (!this.db) throw new Error("Database not initialized");

    const fields = Object.keys(updates).filter(
      (key) => !["id", "reminderId", "createdAt"].includes(key)
    );
    const setClause = fields.map((field) => `${field} = ?`).join(", ");
    const values = fields.map((field) => (updates as any)[field]);

    await this.db.runAsync(
      `
      UPDATE review_stages SET ${setClause}, updatedAt = ? WHERE reminderId = ?
    `,
      [...values, new Date().toISOString(), reminderId]
    );
  }

  // Export and Import
  async exportData(): Promise<{
    reminders: Reminder[];
    snoozeHistory: SnoozeHistory[];
    importantDates: ImportantDate[];
    reviewStages: ReviewStage[];
  }> {
    if (!this.db) throw new Error("Database not initialized");

    const [reminders, snoozeHistory, importantDates, reviewStages] =
      await Promise.all([
        this.db.getAllAsync("SELECT * FROM reminders"),
        this.db.getAllAsync("SELECT * FROM snooze_history"),
        this.db.getAllAsync("SELECT * FROM important_dates"),
        this.db.getAllAsync("SELECT * FROM review_stages"),
      ]);

    return {
      reminders: reminders as Reminder[],
      snoozeHistory: snoozeHistory as SnoozeHistory[],
      importantDates: importantDates as ImportantDate[],
      reviewStages: reviewStages as ReviewStage[],
    };
  }

  async importData(data: {
    reminders?: Reminder[];
    snoozeHistory?: SnoozeHistory[];
    importantDates?: ImportantDate[];
    reviewStages?: ReviewStage[];
  }): Promise<void> {
    if (!this.db) throw new Error("Database not initialized");

    // Import reminders
    if (data.reminders) {
      for (const reminder of data.reminders) {
        await this.db.runAsync(
          `
          INSERT OR REPLACE INTO reminders (
            id, title, notes, person, project, location, type, rrule, 
            nextFireAt, status, completedAt, notificationId, createdAt, updatedAt
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
          [
            reminder.id,
            reminder.title,
            reminder.notes || null,
            reminder.person || null,
            reminder.project || null,
            reminder.location || null,
            reminder.type,
            reminder.rrule || null,
            reminder.nextFireAt || null,
            reminder.status,
            reminder.completedAt || null,
            reminder.notificationId || null,
            reminder.createdAt,
            reminder.updatedAt,
          ]
        );
      }
    }

    // Import other data types similarly...
    if (data.importantDates) {
      for (const date of data.importantDates) {
        await this.db.runAsync(
          `
          INSERT OR REPLACE INTO important_dates (
            id, title, description, date, type, person, leadTimes, createdAt, updatedAt
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
          [
            date.id,
            date.title,
            date.description || null,
            date.date,
            date.type,
            date.person || null,
            date.leadTimes,
            date.createdAt,
            date.updatedAt,
          ]
        );
      }
    }
  }
}

export const database = new Database();
