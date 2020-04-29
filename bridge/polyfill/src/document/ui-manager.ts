import { krakenUIManager, krakenRequestBatchUpdate, krakenToBlob } from '../bridge';

const updateMessageQueue: any[] = [];
let updateRequested: boolean = false;

function appendMessage(message: any[]) {
  updateMessageQueue.push(message);
  if (!updateRequested) {
    updateRequested = true;
    krakenRequestBatchUpdate(requestUpdateFrame);
  }
}

function sendMessage(message: any[]) {
  return krakenUIManager(JSON.stringify(message));
}

export function requestUpdateFrame() {
  updateRequested = false;
  if (updateMessageQueue.length > 0) {
    // Make sure message queue is cleared, no matter that dart throws error or not.
    try {
      sendMessage(['batchUpdate', updateMessageQueue]);
    } catch(err) {
      console.error(err);
    } finally {
      updateMessageQueue.length = 0;
    }
  }
}

export function createElement(type: string, id: number) {
  appendMessage(['createElement', [id, type]]);
}

export function createTextNode(id: number, data: string) {
  appendMessage(['createTextNode', [id, data]]);
}

export function createComment(id: number, data: string) {
  appendMessage(['createComment', [id, data]]);
}

export function insertAdjacentNode(parentNodeId: number, position: string, nodeId: number) {
  appendMessage(['insertAdjacentNode', [parentNodeId, position, nodeId]]);
}

export function removeNode(id: number) {
  appendMessage(['removeNode', [id]]);
}

export function setProperty(id: number, key: string, value: any) {
  appendMessage(['setProperty', [id, key, value]]);
}

export function removeProperty(id: number, key: string) {
  appendMessage(['removeProperty', [id, key]]);
}

export function setStyle(id: number, key: string, value: string) {
  appendMessage(['setStyle', [id, key, value]]);
}

export function addEvent(id: number, eventName: string) {
  appendMessage(['addEvent', [id, eventName]]);
}

export function removeEvent(id: number, eventName: string) {
  appendMessage(['removeEvent', [id, eventName]]);
}

export function method(id: number, methodName: string, params: any[] = []) {
  // Must flush batch update before get
  requestUpdateFrame();
  return sendMessage(['method', [id, methodName, params]]);
}

export function toBlob(nodeId: number, devicePixelRatio: number) {
  // need to flush all pending frame messages
  requestUpdateFrame();
  return new Promise((resolve, reject) => {
    krakenToBlob(nodeId, devicePixelRatio, (err, blob) => {
      if (err) {
        return reject(new Error(err));
      }

      resolve(new Blob([blob]));
    });
  });
}