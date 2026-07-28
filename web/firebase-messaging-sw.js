try {
  importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
  importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

  firebase.initializeApp({
    apiKey: 'AIzaSyAIc_ObWVFGTd9OnkxqvlIFp7JjPyDM4t0',
    authDomain: 'fir-p-57bdc.firebaseapp.com',
    projectId: 'fir-p-57bdc',
    storageBucket: 'fir-p-57bdc.appspot.com',
    messagingSenderId: '514349178076',
    appId: '1:514349178076:web:2d0a64dff36e2fc6ba6819',
  });

  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    const notificationTitle = payload.notification?.title || 'NexMeet';
    const notificationOptions = {
      body: payload.notification?.body || '',
      icon: '/favicon.png',
      data: payload.data || {},
    };
    self.registration.showNotification(notificationTitle, notificationOptions);
  });

  self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
      clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
        for (const client of clientList) {
          if (client.url && 'focus' in client) {
            return client.focus();
          }
        }
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
    );
  });
} catch (e) {
  console.warn('[FCM SW] Firebase messaging initialization failed:', e);
}
