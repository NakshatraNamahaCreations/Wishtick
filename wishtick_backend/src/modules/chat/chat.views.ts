import type { ChatDocument } from './schemas/chat.schema';
import type { MessageDocument } from './schemas/message.schema';

export interface ReactionView {
  emoji: string;
  count: number;
  userIds: string[];
}

export interface MessageView {
  id: string;
  chatId: string;
  senderId: string | null;
  kind: string;
  body: string;
  attachments: { mediaId: string; url: string | null; contentType: string | null }[];
  replyToId: string | null;
  reactions: ReactionView[];
  editedAt: Date | null;
  deletedAt: Date | null;
  systemType: string | null;
  systemPayload: Record<string, unknown> | null;
  createdAt: Date;
}

export interface ChatView {
  id: string;
  type: string;
  refId: string;
  lastMessageAt: Date | null;
  unreadCount: number;
  whoCanPost: string;
  participantCount: number;
}

/**
 * Projects a message for the wire. A soft-deleted message keeps its envelope
 * (so replies to it don't dangle) but its body and attachments are stripped —
 * "this message was deleted" is all a client should render.
 */
export function toMessageView(m: MessageDocument): MessageView {
  const deleted = m.deletedAt !== null;
  return {
    id: m._id.toString(),
    chatId: m.chatId.toString(),
    senderId: m.senderId ? m.senderId.toString() : null,
    kind: m.kind,
    body: deleted ? '' : m.body,
    attachments: deleted
      ? []
      : m.attachments.map((a) => ({
          mediaId: a.mediaId.toString(),
          url: a.url,
          contentType: a.contentType,
        })),
    replyToId: m.replyToId ? m.replyToId.toString() : null,
    reactions: m.reactions.map((r) => ({
      emoji: r.emoji,
      count: r.userIds.length,
      userIds: r.userIds.map((id) => id.toString()),
    })),
    editedAt: m.editedAt,
    deletedAt: m.deletedAt,
    systemType: m.systemType,
    systemPayload: m.systemPayload,
    createdAt: m.createdAt,
  };
}

export function toChatView(chat: ChatDocument, unreadCount: number): ChatView {
  return {
    id: chat._id.toString(),
    type: chat.type,
    refId: chat.refId.toString(),
    lastMessageAt: chat.lastMessageAt,
    unreadCount,
    whoCanPost: chat.settings.whoCanPost,
    participantCount: chat.participantIds.length,
  };
}
