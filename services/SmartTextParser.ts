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
  project?: string;
  location?: string;
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
    /próxim[ao]\s+(segunda|terça|quarta|quinta|sexta|sábado|domingo)/gi,
    /next\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)/gi,
  ];

  private static readonly PERSON_PATTERNS = [
    /call\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /ligar\s+para\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /falar\s+com\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /encontrar\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /meet\s+with\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /when\s+(.+?)\s+(calls?|arrives?|comes?)/gi,
    /quando\s+(.+?)\s+(ligar|chegar|vir)/gi,
  ];

  private static readonly LOCATION_PATTERNS = [
    /when\s+(.+?)\s+(home|work|office)/gi,
    /quando\s+(.+?)\s+(casa|trabalho|escritório)/gi,
    /at\s+(home|work|office|gym|store|market|casa|trabalho|academia)/gi,
    /no\s+(trabalho|escritório|casa|mercado|supermercado)/gi,
    /na\s+(academia|farmácia|escola|universidade)/gi,
    /when\s+(home|work|office|gym)/gi,
    /quando\s+(em\s+casa|no\s+trabalho|na\s+academia)/gi,
  ];

  private static readonly PROJECT_PATTERNS = [
    /projeto\s+([a-záàâãéèêíìîóòôõúùû\s]+)/gi,
    /project\s+([a-zA-Z\s]+)/gi,
    /#([a-záàâãéèêíìîóòôõúùû]+)/gi,
  ];

  private static readonly PRIORITY_PATTERNS = [
    { pattern: /(!{3}|urgent|urgente|importante)/gi, priority: 3 },
    { pattern: /(!{2}|important|médio)/gi, priority: 2 },
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
  };

  static parseText(input: string): ParsedReminder {
    const originalInput = input.trim();

    // 1. Extrair comandos com barra antes de qualquer outra detecção
    const { commands, remainingText } = this.parseSlashCommands(originalInput);
    const cleanInput = remainingText.trim();

    // Extract time information
    const timeInfo = this.extractTime(cleanInput);
    const dateInfo = this.extractDate(cleanInput);

    // Extract entities
    const person = this.extractPerson(cleanInput);
    const location = this.extractLocation(cleanInput);
    const project = this.extractProject(cleanInput);

    // Determine priority
    const priority = this.extractPriority(cleanInput);

    // Extract tags
    const tags = this.extractTags(cleanInput);

    // Merge tags com /tags
    if (commands.tags) {
      const extraTags = commands.tags
        .split(/[\s,]+/)
        .filter(Boolean)
        .map((t) => t.replace(/^#/, "").toLowerCase());
      for (const t of extraTags) if (!tags.includes(t)) tags.push(t);
    }

    // Determine folder
    const folderId = this.determineFolderId(cleanInput);

    // Clean title by removing detected patterns
    const title = this.cleanTitle(
      cleanInput,
      timeInfo,
      dateInfo,
      person,
      location,
      project
    );

    // Determine type and create result
    let result: ParsedReminder = {
      title,
      type: "note",
      priority,
      tags,
      folderId,
      person,
      project,
      location,
    };

    // 2. Aplicar comandos explícitos que sobrescrevem detecções automáticas
    // /note ou /title define título explicitamente
    if (commands.note) {
      result.title = commands.note.trim();
    } else if (commands.title) {
      result.title = commands.title.trim();
    }

    // /priority sobrescreve prioridade
    if (commands.priority) {
      const pMap: Record<string, 1 | 2 | 3> = {
        low: 1,
        baixa: 1,
        normal: 1,
        1: 1,
        "!": 1,
        medium: 2,
        medio: 2,
        médio: 2,
        2: 2,
        "!!": 2,
        high: 3,
        alta: 3,
        urgent: 3,
        urgente: 3,
        3: 3,
        "!!!": 3,
      };
      const key = commands.priority.toLowerCase();
      if (pMap[key] !== undefined) {
        result.priority = pMap[key];
      }
    }

    // /person, /location, /project
    if (commands.person) result.person = commands.person.trim();
    if (commands.location) result.location = commands.location.trim();
    if (commands.project) result.project = commands.project.trim();

    // /date força tipo date (tentar extrair data/hora desse trecho também)
    if (commands.date) {
      const forcedDateInfo = this.extractDate(commands.date);
      const forcedTimeInfo = this.extractTime(commands.date);
      if (forcedDateInfo || forcedTimeInfo) {
        result.fireAt = this.combineDateTime(forcedDateInfo, forcedTimeInfo);
        result.type = "date"; // garante que preview mostre como lembrete de data
      } else {
        // Mesmo sem conseguir parsear, se usuário chamou /date, tratamos como date
        result.type = "date";
      }
    }

    // /trigger <tipo> [valor]
    if (commands.trigger) {
      const parts = commands.trigger.split(/\s+/).filter(Boolean);
      const tType = parts.shift()?.toLowerCase();
      const rest = parts.join(" ").trim();
      if (tType === "person") {
        if (rest) result.person = rest;
        result.type = "trigger";
        result.triggerType = "person";
        result.triggerConfig = { contactName: result.person };
      } else if (tType === "location") {
        if (rest) result.location = rest;
        result.type = "trigger";
        result.triggerType = "location";
        result.triggerConfig = { location: result.location };
      } else if (tType === "project") {
        if (rest) result.project = rest;
        result.type = "trigger";
        result.triggerType = "project";
        result.triggerConfig = { projectName: result.project };
      }
    }

    // Só aplica detecção automática se ainda não foi marcado como date por comandos
    if (result.type !== "date") {
      if (dateInfo || timeInfo) {
        result.type = "date";
        result.fireAt = this.combineDateTime(dateInfo, timeInfo);
      } else if (person || location) {
        result.type = "trigger";

        if (person && location) {
          // If both person and location are mentioned, prioritize person
          result.triggerType = "person";
          result.triggerConfig = { contactName: person, location };
        } else if (person) {
          result.triggerType = "person";
          result.triggerConfig = { contactName: person };
        } else if (location) {
          result.triggerType = "location";
          result.triggerConfig = { location: location };
        }
      }
    }

    return result;
  }

  // Extrai comandos iniciados com / e retorna texto restante
  private static parseSlashCommands(input: string): {
    commands: Record<string, string>;
    remainingText: string;
  } {
    const tokens = input.split(/\s+/);
    const commands: Record<string, string> = {};
    let i = 0;
    const consumed: boolean[] = new Array(tokens.length).fill(false);
    while (i < tokens.length) {
      const tok = tokens[i];
      if (tok.startsWith("/")) {
        const cmd = tok.slice(1).toLowerCase();
        let j = i + 1;
        const valueParts: string[] = [];
        while (j < tokens.length && !tokens[j].startsWith("/")) {
          valueParts.push(tokens[j]);
          consumed[j] = true;
          j++;
        }
        consumed[i] = true;
        commands[cmd] = valueParts.join(" ");
        i = j;
      } else {
        i++;
      }
    }
    // Montar remainingText sem os tokens consumidos
    const remainingText = tokens.filter((_, idx) => !consumed[idx]).join(" ");
    return { commands, remainingText };
  }

  private static extractTime(
    input: string
  ): { hour: number; minute: number } | null {
    for (const pattern of this.TIME_PATTERNS) {
      const match = pattern.exec(input);
      if (match) {
        let hour = parseInt(match[1]);
        const minute = parseInt(match[2] || "0");
        const ampm = match[3]?.toLowerCase();

        if (ampm === "pm" && hour !== 12) hour += 12;
        if (ampm === "am" && hour === 12) hour = 0;

        return { hour, minute };
      }
    }
    return null;
  }

  private static extractDate(input: string): Date | null {
    const now = new Date();

    // Today
    if (/hoje|today/gi.test(input)) {
      return now;
    }

    // Tomorrow
    if (/amanhã|tomorrow/gi.test(input)) {
      return addDays(now, 1);
    }

    // Specific date patterns
    const dateMatch = input.match(/(\d{1,2})\/(\d{1,2})/);
    if (dateMatch) {
      const day = parseInt(dateMatch[1]);
      const month = parseInt(dateMatch[2]) - 1; // JavaScript months are 0-indexed
      const year = now.getFullYear();
      const date = new Date(year, month, day);
      if (isValid(date)) {
        return date;
      }
    }

    // Days of week
    const dayPatterns = {
      "segunda|monday": 1,
      "terça|tuesday": 2,
      "quarta|wednesday": 3,
      "quinta|thursday": 4,
      "sexta|friday": 5,
      "sábado|saturday": 6,
      "domingo|sunday": 0,
    };

    for (const [pattern, targetDay] of Object.entries(dayPatterns)) {
      const regex = new RegExp(pattern, "gi");
      if (regex.test(input)) {
        const today = now.getDay();
        let daysToAdd = (targetDay as number) - today;
        if (daysToAdd <= 0) daysToAdd += 7; // Next week
        return addDays(now, daysToAdd);
      }
    }

    return null;
  }

  private static extractPerson(input: string): string | undefined {
    for (const pattern of this.PERSON_PATTERNS) {
      pattern.lastIndex = 0; // Reset regex state
      const match = pattern.exec(input);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
    return undefined;
  }

  private static extractLocation(input: string): string | undefined {
    for (const pattern of this.LOCATION_PATTERNS) {
      pattern.lastIndex = 0; // Reset regex state
      const match = pattern.exec(input);
      if (match && match[1]) {
        return match[1].trim();
      }
    }

    // Check for direct location mentions
    const directLocations = [
      "casa",
      "home",
      "trabalho",
      "work",
      "office",
      "escritório",
      "academia",
      "gym",
    ];
    for (const location of directLocations) {
      if (input.toLowerCase().includes(location)) {
        return location;
      }
    }

    return undefined;
  }

  private static extractProject(input: string): string | undefined {
    for (const pattern of this.PROJECT_PATTERNS) {
      const match = pattern.exec(input);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
    return undefined;
  }

  private static extractPriority(input: string): 1 | 2 | 3 {
    for (const { pattern, priority } of this.PRIORITY_PATTERNS) {
      if (pattern.test(input)) {
        return priority as 1 | 2 | 3;
      }
    }
    return 1; // Default priority
  }

  private static extractTags(input: string): string[] {
    const hashtagPattern = /#([a-záàâãéèêíìîóòôõúùû]+)/gi;
    const tags: string[] = [];
    let match;

    while ((match = hashtagPattern.exec(input)) !== null) {
      tags.push(match[1].toLowerCase());
    }

    return tags;
  }

  private static determineFolderId(input: string): string {
    const lowerInput = input.toLowerCase();

    for (const [folderId, keywords] of Object.entries(this.FOLDER_KEYWORDS)) {
      if (keywords.some((keyword) => lowerInput.includes(keyword))) {
        return folderId;
      }
    }

    return "default";
  }

  private static cleanTitle(
    input: string,
    timeInfo: any,
    dateInfo: any,
    person?: string,
    location?: string,
    project?: string
  ): string {
    let cleaned = input;

    // Remove time patterns
    for (const pattern of this.TIME_PATTERNS) {
      cleaned = cleaned.replace(pattern, "");
    }

    // Remove date patterns
    for (const pattern of this.DATE_PATTERNS) {
      cleaned = cleaned.replace(pattern, "");
    }

    // Remove person patterns
    if (person) {
      for (const pattern of this.PERSON_PATTERNS) {
        cleaned = cleaned.replace(pattern, "");
      }
    }

    // Remove location patterns
    if (location) {
      for (const pattern of this.LOCATION_PATTERNS) {
        cleaned = cleaned.replace(pattern, "");
      }
    }

    // Remove project patterns
    if (project) {
      for (const pattern of this.PROJECT_PATTERNS) {
        cleaned = cleaned.replace(pattern, "");
      }
    }

    // Remove priority patterns
    for (const { pattern } of this.PRIORITY_PATTERNS) {
      cleaned = cleaned.replace(pattern, "");
    }

    // Clean up extra spaces and punctuation
    cleaned = cleaned.replace(/\s+/g, " ").trim();
    cleaned = cleaned.replace(/^[,\s]+|[,\s]+$/g, "");

    return cleaned || input; // Fallback to original if cleaning removed everything
  }

  private static combineDateTime(
    dateInfo: Date | null,
    timeInfo: { hour: number; minute: number } | null
  ): Date | undefined {
    if (!dateInfo && !timeInfo) return undefined;

    const base = dateInfo || new Date();

    if (timeInfo) {
      return new Date(
        base.getFullYear(),
        base.getMonth(),
        base.getDate(),
        timeInfo.hour,
        timeInfo.minute
      );
    }

    return base;
  }
}
