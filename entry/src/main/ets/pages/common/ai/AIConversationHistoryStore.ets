import preferences from '@ohos.data.preferences';
import util from '@ohos.util';
import common from '@ohos.app.ability.common';
import {
  AIConversationHistoryRecord,
  AIWorkspaceSessionSnapshot,
  DisplayItemSnapshot,
  DisplayItemType
} from './AIPanelModels';

export class AIConversationHistoryStore {
  private static instance: AIConversationHistoryStore;

  private readonly prefName = 'deadliner_ai_conversation_store';
  private readonly historyKey = 'archived_history';
  private readonly draftKey = 'current_draft';
  private readonly maxHistoryCount = 12;

  private pref: preferences.Preferences | null = null;
  private archivedHistory: AIConversationHistoryRecord[] = [];
  private currentDraft: AIWorkspaceSessionSnapshot | null = null;

  private constructor() {}

  static getInstance(): AIConversationHistoryStore {
    if (!AIConversationHistoryStore.instance) {
      AIConversationHistoryStore.instance = new AIConversationHistoryStore();
    }
    return AIConversationHistoryStore.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.pref) {
      return;
    }
    this.pref = await preferences.getPreferences(context, this.prefName);
    await this.loadFromDisk();
  }

  getArchivedHistory(): AIConversationHistoryRecord[] {
    return [...this.archivedHistory];
  }

  getCurrentDraft(): AIWorkspaceSessionSnapshot | null {
    if (!this.currentDraft) {
      return null;
    }
    return this.cloneSessionSnapshot(this.currentDraft);
  }

  async saveCurrentDraft(snapshot: AIWorkspaceSessionSnapshot | null): Promise<void> {
    this.currentDraft = snapshot ? this.cloneSessionSnapshot(snapshot) : null;
    await this.saveDraftToDisk();
  }

  async clearCurrentDraft(): Promise<void> {
    this.currentDraft = null;
    await this.saveDraftToDisk();
  }

  async archiveSession(snapshot: AIWorkspaceSessionSnapshot | null): Promise<AIConversationHistoryRecord | null> {
    if (!snapshot || !this.hasMeaningfulItems(snapshot.displayItems)) {
      return null;
    }

    const now = Date.now();
    const record: AIConversationHistoryRecord = {
      id: util.generateRandomUUID(true),
      title: this.buildTitle(snapshot.displayItems),
      preview: this.buildPreview(snapshot.displayItems),
      updatedAt: now,
      itemCount: snapshot.displayItems.length,
      displayItems: [...snapshot.displayItems]
    };

    this.archivedHistory = [record, ...this.archivedHistory]
      .sort((a, b) => b.updatedAt - a.updatedAt)
      .slice(0, this.maxHistoryCount);

    await this.saveHistoryToDisk();
    return record;
  }

  async deleteHistoryRecord(recordId: string): Promise<void> {
    this.archivedHistory = this.archivedHistory.filter((item) => item.id !== recordId);
    await this.saveHistoryToDisk();
  }

  private hasMeaningfulItems(items: DisplayItemSnapshot[]): boolean {
    return items.some((item) => {
      if ((item.text ?? '').trim().length > 0) {
        return true;
      }
      return item.type === DisplayItemType.AITask ||
        item.type === DisplayItemType.AIHabit ||
        item.type === DisplayItemType.AIToolRequest ||
        item.type === DisplayItemType.AIToolResult;
    });
  }

  private buildTitle(items: DisplayItemSnapshot[]): string {
    const firstUser = items.find((item) => item.type === DisplayItemType.UserQuery && (item.text ?? '').trim().length > 0);
    const firstAI = items.find((item) => item.type === DisplayItemType.AIChat && (item.text ?? '').trim().length > 0);
    const base = (firstUser?.text ?? firstAI?.text ?? '未命名对话').trim();
    return this.limitText(base, 18);
  }

  private buildPreview(items: DisplayItemSnapshot[]): string {
    const reversed = [...items].reverse();
    const lastAI = reversed.find((item) => item.type === DisplayItemType.AIChat && (item.text ?? '').trim().length > 0);
    const lastUser = reversed.find((item) => item.type === DisplayItemType.UserQuery && (item.text ?? '').trim().length > 0);
    const base = (lastAI?.text ?? lastUser?.text ?? '已暂存对话').trim();
    return this.limitText(base, 32);
  }

  private limitText(text: string, maxLength: number): string {
    if (text.length <= maxLength) {
      return text;
    }
    return `${text.substring(0, Math.max(0, maxLength - 1))}…`;
  }

  private cloneSessionSnapshot(snapshot: AIWorkspaceSessionSnapshot): AIWorkspaceSessionSnapshot {
    return {
      displayItems: [...snapshot.displayItems],
      sessionSummary: snapshot.sessionSummary,
      addedTaskKeys: [...snapshot.addedTaskKeys],
      addedHabitKeys: [...snapshot.addedHabitKeys],
      taskProposalToolRequests: [...snapshot.taskProposalToolRequests],
      habitProposalToolRequests: [...snapshot.habitProposalToolRequests],
      lastSubmittedToolName: snapshot.lastSubmittedToolName,
      toolOriginalUserText: snapshot.toolOriginalUserText,
      updatedAt: snapshot.updatedAt
    };
  }

  private async saveHistoryToDisk(): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(this.historyKey, JSON.stringify(this.archivedHistory));
    await this.pref.flush();
  }

  private async saveDraftToDisk(): Promise<void> {
    if (!this.pref) {
      return;
    }
    await this.pref.put(this.draftKey, this.currentDraft ? JSON.stringify(this.currentDraft) : '');
    await this.pref.flush();
  }

  private async loadFromDisk(): Promise<void> {
    if (!this.pref) {
      return;
    }

    const rawHistory = await this.pref.get(this.historyKey, '') as string;
    if (rawHistory) {
      try {
        this.archivedHistory = JSON.parse(rawHistory) as AIConversationHistoryRecord[];
      } catch (err) {
        this.archivedHistory = [];
      }
    }

    const rawDraft = await this.pref.get(this.draftKey, '') as string;
    if (rawDraft) {
      try {
        this.currentDraft = JSON.parse(rawDraft) as AIWorkspaceSessionSnapshot;
      } catch (err) {
        this.currentDraft = null;
      }
    }
  }
}
