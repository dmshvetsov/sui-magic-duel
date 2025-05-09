export interface ChatMessage {
  id: string;
  text: string;
  username: string;
  channel: string;
  timestamp: string;
}

export function displayName(message: ChatMessage ) {
    const address = message.username
    return address.slice(0, 6) + '..' + address.slice(-4)
}