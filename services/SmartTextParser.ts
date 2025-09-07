import { addDays, isValid } from "date-fns";

export interface ParsedReminder {
  title: string;
  type: "date" | "note" | "trigger";
  fireAt?: Date;
  triggerType?: "location" | "person" | "time" | "dayOfWeek" | "project";
  triggerConfig?: any;
  priority: 1 | 2 | 3;
  tags: string[];
  folderId?: string;
  person?: string;
  persons?: string[]; // plural block /people
  project?: string;
  location?: string;
  locations?: string[]; // plural block /locations
  body?: string; // multiline remainder (notes)
}

export class SmartTextParser {
  private static readonly TIME_PATTERNS = [
    /(\d{1,2}):(\d{2})\s*(am|pm)?/gi,
    /(\d{1,2})\s*(am|pm)/gi,
    /às\s*(\d{1,2}):?(\d{2})?/gi,
    /(\d{1,2})h(\d{2})?/gi,
  ];

  private static readonly DATE_PATTERNS = [
    /hoje/gi,
    /amanhã/gi,
    /tomorrow/gi,
    /(\d{1,2})\/(\d{1,2})/g,
    /(segunda|terça|quarta|quinta|sexta|sábado|domingo)/gi,
    /(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/gi,
  ];

  private static readonly PERSON_PATTERNS = [
    /call\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /ligar\s+para\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /falar\s+com\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /encontrar\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /meet\s+with\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
  ];

  private static readonly LOCATION_PATTERNS = [
    /at\s+(home|work|office|gym|store|market|casa|trabalho|academia)/gi,
    /no\s+(trabalho|escritório|casa|mercado|supermercado)/gi,
    /na\s+(academia|farmácia|escola|universidade)/gi,
  ];

  private static readonly PROJECT_PATTERNS = [
    /projeto\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /project\s+([a-zA-Z\s]+)/gi,
  ];

  private static readonly PRIORITY_PATTERNS = [
    { pattern: /(!{3}|urgent|urgente|importante)/gi, priority: 3 },
    { pattern: /(!{2}|important|médio|medio)/gi, priority: 2 },
    { pattern: /(!{1}|normal|baixo)/gi, priority: 1 },
  ];

  private static readonly FOLDER_KEYWORDS = {
    work: [
      "trabalho",
      "reunião",
      "meeting",
      "projeto",
      "project",
      "cliente",
      "client",
      "call",
      "email",
    ],
    personal: [
      "casa",
      "home",
      "família",
      "family",
      "aniversário",
      "birthday",
      "amigo",
      "friend",
    ],
    health: [
      "médico",
      "doctor",
      "consulta",
      "appointment",
      "remédio",
      "medicine",
      "academia",
      "gym",
      "exercício",
    ],
    default: [],
  } as const;

  static parseText(input: string): ParsedReminder {
    const text = input.trim();
    const { commands, remainingText } = this.parseSlashCommands(text);
    const base = remainingText.trim();
    const timeInfo = this.extractTime(base);
    const dateInfo = this.extractDate(base);
    const person = this.extractPerson(base);
    const location = this.extractLocation(base);
    const project = this.extractProject(base);
    const priority = this.extractPriority(base);
    const tags: string[] = []; // deprecated hashtag tags in markdown mode

    if (commands.tags) {
      // still allow explicit /tags block but no leading # stripping now
      const extra = commands.tags
        .split(/[\s,;]+/)
        .map((t) => t.toLowerCase())
        .filter(Boolean);
      for (const t of extra) if (!tags.includes(t)) tags.push(t);
    }

    const folderId = this.determineFolderId(base);
    const result: ParsedReminder = {
      title: this.cleanTitle(
        base,
        timeInfo,
        dateInfo,
        person,
        location,
        project
      ),
      type: "note",
      priority,
      tags,
      folderId,
      person,
      project,
      location,
    };

    if (!commands.note && !commands.title) {
      const lines = input.split(/\n/);
      const cleanedLines: string[] = [];
      let skipBlock: string | null = null; // 'tags' | 'people' | 'locations'
      const BLOCK_START: Record<string, string> = {
        "/tags": "tags",
        "/people": "people",
        "/locations": "locations",
      };
      const BLOCK_END: Record<string, string> = {
        "/endtags": "tags",
        "/endpeople": "people",
        "/endlocations": "locations",
      };
      for (const rawLine of lines) {
        const line = rawLine; // preserve indentation for bullets
        const trimmed = line.trim();
        if (skipBlock) {
          // Inside a block until we find its end marker
          const lower = trimmed.toLowerCase();
          if (BLOCK_END[lower] === skipBlock) {
            skipBlock = null; // stop skipping after end marker line
          }
          continue; // skip block content and end marker line itself
        }
        // Detect block start
        const lower = trimmed.toLowerCase();
        if (BLOCK_START[lower]) {
          skipBlock = BLOCK_START[lower];
          continue; // skip the start marker line
        }
        // Remove inline single-line commands with their arguments (until next /command or EOL)
        // Commands covered: /date /person /location /project /priority /title /note
        let processed = line
          .replace(
            /\/(date|person|location|project|priority|title|note)\b[^/\n]*/gi,
            ""
          )
          .trimEnd();
        // If line becomes only a command residue or empty after trimming, skip unless it's a bullet marker
        if (processed.trim().length === 0) {
          if (/^\s*[•\-*]\s*$/.test(line)) continue; // ignore stray bullet markers
        }
        cleanedLines.push(processed);
      }
      // Simple: first non-empty line => title; rest => body
      const firstNonEmpty = cleanedLines.find((l) => l.trim().length > 0);
      if (firstNonEmpty) {
        result.title = firstNonEmpty.replace(/^\s*[•\-*]\s?/, "").trim();
        const idx = cleanedLines.indexOf(firstNonEmpty);
        const rest = cleanedLines
          .slice(idx + 1)
          .join("\n")
          .trim();
        if (rest) result.body = rest;
      }
    }

    if (commands.note) {
      result.title = commands.note.trim();
    } else if (commands.title) {
      result.title = commands.title.trim();
    }

    if (commands.priority) {
      const map: Record<string, 1 | 2 | 3> = {
        low: 1,
        baixa: 1,
        normal: 1,
        "1": 1,
        "!": 1,
        medium: 2,
        medio: 2,
        médio: 2,
        "2": 2,
        "!!": 2,
        high: 3,
        alta: 3,
        urgent: 3,
        urgente: 3,
        "3": 3,
        "!!!": 3,
      };
      const k = commands.priority.toLowerCase();
      if (map[k]) result.priority = map[k];
    }
    if (commands.person) result.person = commands.person.trim();
    if (commands.location) result.location = commands.location.trim();
    if (commands.project) result.project = commands.project.trim();

    if (commands.date) {
      const d = this.extractDate(commands.date);
      const t = this.extractTime(commands.date);
      result.type = "date";
      result.fireAt = this.combineDateTime(d, t);
    }
    if (commands.people) {
      const list = commands.people
        .split(/[\n;,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
      if (list.length) result.persons = list;
    }
    if (commands.locations) {
      const list = commands.locations
        .split(/[\n;,]+/)
        .map((s) => s.trim())
        .filter(Boolean);
      if (list.length) result.locations = list;
    }

    if (result.type !== "date" && (dateInfo || timeInfo)) {
      result.type = "date";
      result.fireAt = this.combineDateTime(dateInfo, timeInfo);
    }
    if (result.type !== "date") {
      if (result.persons?.length || result.locations?.length) {
        result.type = "trigger";
      } else if (result.person || result.location) {
        result.type = "trigger";
        if (result.person) {
          result.triggerType = "person";
          result.triggerConfig = { contactName: result.person };
        } else if (result.location) {
          result.triggerType = "location";
          result.triggerConfig = { location: result.location };
        }
      }
    }

    return result;
  }

  private static parseSlashCommands(input: string): {
    commands: Record<string, string>;
    remainingText: string;
  } {
    const tokens = input.split(/\s+/);
    const commands: Record<string, string> = {};
    const consumed = new Array(tokens.length).fill(false);
    const BLOCKS: Record<string, string> = {
      tags: "endtags",
      people: "endpeople",
      locations: "endlocations",
    };
    const isDateToken = (tok: string) => {
      const tl = tok.toLowerCase();
      return [
        /^(hoje|today|amanhã|amanha|tomorrow)$/,
        /^\d{1,2}\/\d{1,2}$/,
        /^\d{1,2}:\d{2}$/,
        /^\d{1,2}h(\d{2})?$/,
        /^\d{1,2}(am|pm)$/,
        /^(segunda|terça|terca|quarta|quinta|sexta|sábado|sabado|domingo|monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/,
      ].some((r) => r.test(tl));
    };
    let i = 0;
    while (i < tokens.length) {
      const tok = tokens[i];
      if (tok.startsWith("/")) {
        const name = tok.slice(1).toLowerCase();
        let j = i + 1;
        const parts: string[] = [];
        if (BLOCKS[name]) {
          const end = "/" + BLOCKS[name];
          while (j < tokens.length && tokens[j].toLowerCase() !== end) {
            parts.push(tokens[j]);
            consumed[j] = true;
            j++;
          }
          if (j < tokens.length && tokens[j].toLowerCase() === end) {
            consumed[j] = true;
            j++;
          }
        } else if (name === "date") {
          while (
            j < tokens.length &&
            !tokens[j].startsWith("/") &&
            isDateToken(tokens[j])
          ) {
            parts.push(tokens[j]);
            consumed[j] = true;
            j++;
          }
        } else {
          while (j < tokens.length && !tokens[j].startsWith("/")) {
            parts.push(tokens[j]);
            consumed[j] = true;
            j++;
          }
        }
        consumed[i] = true;
        commands[name] = parts.join(" ");
        i = j;
      } else i++;
    }
    const remainingText = tokens.filter((_, idx) => !consumed[idx]).join(" ");
    return { commands, remainingText };
  }

  private static extractTime(
    input: string
  ): { hour: number; minute: number } | null {
    for (const pattern of this.TIME_PATTERNS) {
      pattern.lastIndex = 0;
      const m = pattern.exec(input);
      if (m) {
        let h = parseInt(m[1]);
        const min = parseInt(m[2] || "0");
        const ampm = m[3]?.toLowerCase();
        if (ampm === "pm" && h !== 12) h += 12;
        if (ampm === "am" && h === 12) h = 0;
        return { hour: h, minute: min };
      }
    }
    return null;
  }
  private static extractDate(input: string): Date | null {
    const now = new Date();
    if (/hoje|today/i.test(input)) return now;
    if (/amanhã|amanha|tomorrow/i.test(input)) return addDays(now, 1);
    const dm = /(\d{1,2})\/(\d{1,2})/.exec(input);
    if (dm) {
      const day = parseInt(dm[1]);
      const month = parseInt(dm[2]) - 1;
      const d = new Date(now.getFullYear(), month, day);
      if (isValid(d)) return d;
    }
    const map: Record<string, number> = {
      segunda: 1,
      monday: 1,
      terça: 2,
      terca: 2,
      tuesday: 2,
      quarta: 3,
      wednesday: 3,
      quinta: 4,
      thursday: 4,
      sexta: 5,
      friday: 5,
      sábado: 6,
      sabado: 6,
      saturday: 6,
      domingo: 0,
      sunday: 0,
    };
    for (const k of Object.keys(map)) {
      if (new RegExp(k, "i").test(input)) {
        const target = map[k];
        const today = now.getDay();
        let diff = target - today;
        if (diff <= 0) diff += 7;
        return addDays(now, diff);
      }
    }
    return null;
  }
  private static extractPerson(input: string): string | undefined {
    for (const p of this.PERSON_PATTERNS) {
      p.lastIndex = 0;
      const m = p.exec(input);
      if (m && m[1]) return m[1].trim();
    }
    return undefined;
  }
  private static extractLocation(input: string): string | undefined {
    for (const p of this.LOCATION_PATTERNS) {
      p.lastIndex = 0;
      const m = p.exec(input);
      if (m && m[1]) return m[1].trim();
    }
    const direct = [
      "casa",
      "home",
      "trabalho",
      "work",
      "office",
      "escritório",
      "academia",
      "gym",
    ];
    for (const l of direct) if (input.toLowerCase().includes(l)) return l;
    return undefined;
  }
  private static extractProject(input: string): string | undefined {
    for (const p of this.PROJECT_PATTERNS) {
      p.lastIndex = 0;
      const m = p.exec(input);
      if (m && m[1]) return m[1].trim();
    }
    return undefined;
  }
  private static extractPriority(input: string): 1 | 2 | 3 {
    for (const { pattern, priority } of this.PRIORITY_PATTERNS) {
      pattern.lastIndex = 0;
      if (pattern.test(input)) return priority as 1 | 2 | 3;
    }
    return 1;
  }
  // extractTags removed for markdown mode
  private static determineFolderId(input: string): string {
    const lower = input.toLowerCase();
    for (const [fid, keywords] of Object.entries(this.FOLDER_KEYWORDS)) {
      if (keywords.some((k) => lower.includes(k))) return fid;
    }
    return "default";
  }
  private static cleanTitle(
    input: string,
    _time: any,
    _date: any,
    person?: string,
    location?: string,
    project?: string
  ): string {
    let cleaned = input;
    for (const p of this.TIME_PATTERNS) cleaned = cleaned.replace(p, "");
    for (const p of this.DATE_PATTERNS) cleaned = cleaned.replace(p, "");
    if (person)
      for (const p of this.PERSON_PATTERNS) cleaned = cleaned.replace(p, "");
    if (location)
      for (const p of this.LOCATION_PATTERNS) cleaned = cleaned.replace(p, "");
    if (project)
      for (const p of this.PROJECT_PATTERNS) cleaned = cleaned.replace(p, "");
    for (const { pattern } of this.PRIORITY_PATTERNS)
      cleaned = cleaned.replace(pattern, "");
    cleaned = cleaned.replace(/\s+/g, " ").trim();
    return cleaned || input;
  }
  private static combineDateTime(
    dateInfo: Date | null,
    timeInfo: { hour: number; minute: number } | null
  ): Date | undefined {
    if (!dateInfo && !timeInfo) return undefined;
    const base = dateInfo || new Date();
    if (timeInfo)
      return new Date(
        base.getFullYear(),
        base.getMonth(),
        base.getDate(),
        timeInfo.hour,
        timeInfo.minute
      );
    return base;
  }
}
