// ===========================================
// NOTIFICATION SYSTEM - REUSABLE COMPONENT
// ===========================================

class NotificationSystem {
  constructor() {
    this.updateInterval = null;
    this.initialized = false;
  }

  // Initialize the notification system
  async init() {
    if (this.initialized) return;
    
    try {
      await this.addNotificationHTML();
      this.setupEventListeners();
      this.startUpdates();
      this.initialized = true;
    } catch (error) {
      console.error('Error initializing notification system:', error);
    }
  }

  // Add notification HTML to header
  addNotificationHTML() {
    // Find the header container with user avatar
    const userAvatar = document.getElementById('userAvatar');
    if (!userAvatar || !userAvatar.parentElement) return;

    const headerContainer = userAvatar.parentElement.parentElement; // Get the flex container
    
    // Check if notification icon already exists
    if (document.getElementById('notificationBell')) return;

    // Create notification HTML
    const notificationHTML = `
      <!-- Notification Bell Icon -->
      <div class="relative">
        <button id="notificationBell" class="relative p-2 text-gray-600 hover:text-gray-800 focus:outline-none">
          <i class="fas fa-bell text-xl"></i>
          <!-- Notification Badge -->
          <span id="notificationBadge" class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-5 w-5 flex items-center justify-center hidden">0</span>
        </button>
        
        <!-- Notification Dropdown -->
        <div id="notificationDropdown" class="absolute right-0 mt-2 w-80 bg-white rounded-md shadow-lg z-50 hidden max-h-96 overflow-y-auto">
          <div class="py-2">
            <div class="px-4 py-2 text-sm font-medium text-gray-700 border-b flex justify-between items-center">
              <span>Notifications</span>
              <button id="markAllRead" class="text-xs text-blue-600 hover:text-blue-800">Mark all read</button>
            </div>
            <div id="notificationList" class="max-h-64 overflow-y-auto">
              <!-- Notifications will be loaded here -->
            </div>
            <div class="px-4 py-2 border-t">
              <button id="viewAllNotifications" class="text-sm text-blue-600 hover:text-blue-800 w-full text-center">View All Notifications</button>
            </div>
          </div>
        </div>
      </div>
    `;

    // Insert before user avatar container
    userAvatar.parentElement.insertAdjacentHTML('beforebegin', notificationHTML);

    // Add necessary CSS if not already present
    this.addNotificationCSS();
  }

  // Add notification CSS
  addNotificationCSS() {
    if (document.getElementById('notificationSystemCSS')) return;

    const css = `
      <style id="notificationSystemCSS">
        .notification-item {
          transition: background-color 0.15s ease;
        }
        
        .notification-item:hover {
          background-color: #f9fafb !important;
        }
        
        .line-clamp-2 {
          display: -webkit-box;
          -webkit-line-clamp: 2;
          line-clamp: 2;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }
        
        @keyframes pulse-notification {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
        
        .animate-pulse-notification {
          animation: pulse-notification 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
        }
      </style>
    `;

    document.head.insertAdjacentHTML('beforeend', css);
  }

  // Setup event listeners
  setupEventListeners() {
    const notificationBell = document.getElementById('notificationBell');
    const notificationDropdown = document.getElementById('notificationDropdown');
    const markAllRead = document.getElementById('markAllRead');
    const userDropdown = document.getElementById('userDropdown');

    if (notificationBell && notificationDropdown) {
      notificationBell.addEventListener('click', (e) => {
        e.stopPropagation();
        notificationDropdown.classList.toggle('hidden');
        
        // Close user dropdown if open
        if (userDropdown && !userDropdown.classList.contains('hidden')) {
          userDropdown.classList.add('hidden');
        }
        
        // Load notifications when opened
        if (!notificationDropdown.classList.contains('hidden')) {
          this.loadNotifications();
        }
      });
    }

    if (markAllRead) {
      markAllRead.addEventListener('click', () => this.markAllAsRead());
    }

    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (notificationDropdown && 
          !notificationDropdown.classList.contains('hidden') &&
          !notificationBell.contains(e.target)) {
        notificationDropdown.classList.add('hidden');
      }
    });
  }

  // Load notifications
  async loadNotifications() {
    try {
      const notifications = await fetchNotifications();
      this.displayNotifications(notifications);
      this.updateBadge(notifications);
    } catch (error) {
      console.error('Error loading notifications:', error);
    }
  }

  // Display notifications
  displayNotifications(notifications) {
    const notificationList = document.getElementById('notificationList');
    if (!notificationList) return;

    if (notifications.length === 0) {
      notificationList.innerHTML = `
        <div class="px-4 py-6 text-center text-gray-500">
          <i class="fas fa-bell-slash text-2xl mb-2"></i>
          <p>No notifications</p>
        </div>
      `;
      return;
    }

    // Sort notifications
    const sortedNotifications = notifications.sort((a, b) => {
      const priorityOrder = { urgent: 4, high: 3, medium: 2, low: 1 };
      const priorityDiff = (priorityOrder[b.priority] || 1) - (priorityOrder[a.priority] || 1);
      if (priorityDiff !== 0) return priorityDiff;
      return new Date(b.created_at) - new Date(a.created_at);
    });

    const recentNotifications = sortedNotifications.slice(0, 10);

    notificationList.innerHTML = recentNotifications.map(notification => {
      const isUnread = !notification.is_read;
      const timeAgo = this.getTimeAgo(notification.created_at);
      const priorityIcon = this.getPriorityIcon(notification.priority);
      const typeColor = this.getNotificationTypeColor(notification.notification_type);

      return `
        <div class="notification-item px-4 py-3 border-b border-gray-100 hover:bg-gray-50 cursor-pointer ${isUnread ? 'bg-blue-50' : ''}"
             data-notification-id="${notification.id}"
             onclick="notificationSystem.handleClick(${notification.id}, '${notification.action_url || ''}')">
          <div class="flex items-start space-x-3">
            <div class="flex-shrink-0">
              <i class="fas ${priorityIcon} ${typeColor}"></i>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center justify-between">
                <p class="text-sm font-medium text-gray-900 ${isUnread ? 'font-semibold' : ''}">${notification.title}</p>
                <span class="text-xs text-gray-500">${timeAgo}</span>
              </div>
              <p class="text-sm text-gray-600 mt-1 line-clamp-2">${notification.message}</p>
              ${notification.priority === 'urgent' ? '<span class="inline-block px-2 py-1 text-xs bg-red-100 text-red-800 rounded-full mt-1">URGENT</span>' : ''}
              ${isUnread ? '<div class="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>' : ''}
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  // Update notification badge
  updateBadge(notifications) {
    const badge = document.getElementById('notificationBadge');
    if (!badge) return;

    const unreadCount = notifications.filter(n => !n.is_read).length;
    
    if (unreadCount > 0) {
      badge.textContent = unreadCount > 99 ? '99+' : unreadCount;
      badge.classList.remove('hidden');
      badge.classList.add('animate-pulse-notification');
    } else {
      badge.classList.add('hidden');
      badge.classList.remove('animate-pulse-notification');
    }
  }

  // Handle notification click
  async handleClick(notificationId, actionUrl) {
    try {
      await markNotificationAsRead(notificationId);
      await this.loadNotifications();
      
      if (actionUrl && actionUrl !== '' && actionUrl !== 'null') {
        window.location.href = actionUrl;
      }
    } catch (error) {
      console.error('Error handling notification click:', error);
    }
  }

  // Mark all as read
  async markAllAsRead() {
    try {
      const notifications = await fetchNotifications();
      const unreadNotifications = notifications.filter(n => !n.is_read);
      
      for (const notification of unreadNotifications) {
        await markNotificationAsRead(notification.id);
      }
      
      await this.loadNotifications();
      if (typeof showSuccess === 'function') {
        showSuccess('All notifications marked as read');
      }
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
      if (typeof showError === 'function') {
        showError('Failed to mark notifications as read');
      }
    }
  }

  // Start periodic updates
  startUpdates() {
    this.loadNotifications();
    this.updateInterval = setInterval(() => this.loadNotifications(), 30000);
  }

  // Stop updates
  stopUpdates() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
      this.updateInterval = null;
    }
  }

  // Utility functions
  getTimeAgo(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now - date) / 1000);

    if (diffInSeconds < 60) return 'Just now';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
    if (diffInSeconds < 2592000) return `${Math.floor(diffInSeconds / 86400)}d ago`;
    return date.toLocaleDateString();
  }

  getPriorityIcon(priority) {
    switch (priority) {
      case 'urgent': return 'fa-exclamation-triangle';
      case 'high': return 'fa-exclamation-circle';
      case 'medium': return 'fa-info-circle';
      case 'low': return 'fa-check-circle';
      default: return 'fa-bell';
    }
  }

  getNotificationTypeColor(type) {
    switch (type) {
      case 'error': return 'text-red-500';
      case 'warning': return 'text-yellow-500';
      case 'success': return 'text-green-500';
      case 'info': return 'text-blue-500';
      default: return 'text-gray-500';
    }
  }

  // Destroy the notification system
  destroy() {
    this.stopUpdates();
    
    // Remove HTML elements
    const notificationBell = document.getElementById('notificationBell');
    if (notificationBell && notificationBell.parentElement) {
      notificationBell.parentElement.remove();
    }
    
    // Remove CSS
    const css = document.getElementById('notificationSystemCSS');
    if (css) {
      css.remove();
    }
    
    this.initialized = false;
  }
}

// Create global instance
const notificationSystem = new NotificationSystem();

// Auto-initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  // Initialize after a short delay to ensure other systems are ready
  setTimeout(() => {
    notificationSystem.init();
  }, 1000);
});

// Clean up on page unload
window.addEventListener('beforeunload', () => {
  notificationSystem.stopUpdates();
});
