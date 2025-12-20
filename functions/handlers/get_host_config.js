#!/usr/bin/env node
/**
 * Quick script to show host configuration
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');

const getHostConfig = onRequest({ cors: true }, async (req, res) => {
    const db = admin.firestore();

    try {
        const snapshot = await db.collection('zoom_hosts')
            .where('is_active', '==', true)
            .orderBy('priority', 'asc')
            .get();

        const hosts = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                email: data.email,
                displayName: data.display_name,
                maxConcurrentMeetings: data.max_concurrent_meetings,
                priority: data.priority,
            };
        });

        res.json({ hosts });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = { getHostConfig };
