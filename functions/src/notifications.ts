import * as functions from "firebase-functions/v2";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const db = () => getFirestore();
const messaging = () => getMessaging();

async function sendPush(toUserId: string, title: string, body: string, data: any) {
    const userSnap = await db().collection("users").doc(toUserId).get();
    const token = userSnap.data()?.fcmToken;

    if (token) {
        try {
            await messaging().send({
                notification: { title, body },
                // 1. ADDED id AND postId TO MATCH YOUR FLUTTER onGenerateRoute
                data: {
                    ...data,
                    id: data.id || "",
                    postId: data.id || "",
                    click_action: "FLUTTER_NOTIFICATION_CLICK"
                },
                token: token,
                // 2. FORCE HIGH PRIORITY FOR HEADS-UP DISPLAY
                android: {
                    priority: "high",
                    notification: {
                        channelId: "high_importance_channel",
                    },
                },
            });
        } catch (error) {
            console.error("Push Error:", error);
        }
    }
}

// 1. LIKES
export const onLikeCreated = functions.firestore.onDocumentCreated("posts/{postId}/likes/{userId}", async (event) => {
    const { userId, postId } = event.params;
    const postSnap = await db().collection("posts").doc(postId).get();
    const authorId = postSnap.data()?.authorId;

    if (!authorId || authorId === userId) return;

    await db().collection("notifications").add({
        type: "like", fromUserId: userId, toUserId: authorId, postId, createdAt: FieldValue.serverTimestamp(), read: false,
    });

    const senderSnap = await db().collection("users").doc(userId).get();
    const senderName = senderSnap.data()?.displayName || "Someone";
    await sendPush(authorId, "New Like", `${senderName} liked your post.`, { type: "like", id: postId });
});

// 2. COMMENTS
export const onCommentCreated = functions.firestore.onDocumentCreated("posts/{postId}/comments/{commentId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const { postId } = event.params;
    const postSnap = await db().collection("posts").doc(postId).get();
    const authorId = postSnap.data()?.authorId;

    if (!authorId || data.userId === authorId) return;

    await db().collection("notifications").add({
        type: "comment", fromUserId: data.userId, toUserId: authorId, postId, createdAt: FieldValue.serverTimestamp(), read: false,
    });

    const senderSnap = await db().collection("users").doc(data.userId).get();
    const senderName = senderSnap.data()?.displayName || "Someone";
    await sendPush(authorId, "New Comment", `${senderName} commented: ${data.content || data.text}`, { type: "comment", id: postId });
});

// 3. FOLLOWS
export const onFollowUpdated = functions.firestore.onDocumentWritten("Friends/{userId}", async (event) => {
    const before = event.data?.before.data()?.followingMetadata || {};
    const after = event.data?.after.data()?.followingMetadata || {};
    const newFollowedId = Object.keys(after).find(key => !before[key]);

    if (!newFollowedId) return;

    await db().collection("notifications").add({
        type: "follow", fromUserId: event.params.userId, toUserId: newFollowedId, createdAt: FieldValue.serverTimestamp(), read: false,
    });

    const senderSnap = await db().collection("users").doc(event.params.userId).get();
    const senderName = senderSnap.data()?.displayName || "Someone";
    await sendPush(newFollowedId, "New Follower", `${senderName} started following you.`, { type: "follow", id: event.params.userId });
});

// 4. MESSAGES
export const onMessageCreated = functions.firestore.onDocumentCreated("chats/{chatId}/messages/{messageId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;

    await db().collection("notifications").add({
        type: "message", fromUserId: data.senderId, toUserId: data.receiverId, chatId: event.params.chatId, createdAt: FieldValue.serverTimestamp(), read: false,
    });

    const senderSnap = await db().collection("users").doc(data.senderId).get();
    const senderName = senderSnap.data()?.displayName || "New Message";
    await sendPush(data.receiverId, senderName, data.content, { type: "chat", id: event.params.chatId });
});