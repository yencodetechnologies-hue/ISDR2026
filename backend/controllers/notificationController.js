const Notification = require('../models/Notification');
const { sendNotificationToUser } = require('../utils/fcmService');

/**
 * The account notifications belong to. An Admin ID (co-management login)
 * shares the property's token, so it's told apart by req.managementUserId.
 */
function recipientOf(req) {
  if (req.userType === 'apartment' && req.managementUserId) {
    return { userId: req.managementUserId, userType: 'management' };
  }
  return { userId: req.userId, userType: req.userType || 'participant' };
}

function buildNotificationQuery(req, extraQuery = {}) {
  const { userId, userType } = recipientOf(req);
  return { userId, userType, ...extraQuery };
}

// @desc    Get user's notifications
// @route   GET /api/notifications
// @access  Private
const getNotifications = async (req, res) => {
  try {
    const { page = 1, limit = 20, type, read } = req.query;

    // Build query
    const extraQuery = {};
    if (type) {
      extraQuery.type = type;
    }
    if (read !== undefined) {
      extraQuery.read = read === 'true';
    }
    const query = buildNotificationQuery(req, extraQuery);

    // Calculate pagination
    const skip = (parseInt(page) - 1) * parseInt(limit);

    // Get notifications
    const notifications = await Notification.find(query)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(skip)
      .lean();

    // Get total count
    const total = await Notification.countDocuments(query);

    res.json({
      success: true,
      notifications: notifications.map((n) => ({
        id: n._id.toString(),
        title: n.title,
        body: n.body,
        type: n.type,
        data: n.data,
        read: n.read,
        apartmentId: n.apartmentId ? n.apartmentId.toString() : null,
        createdAt: n.createdAt,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
        pages: Math.ceil(total / parseInt(limit)),
      },
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

// @desc    Get unread notification count
// @route   GET /api/notifications/unread-count
// @access  Private
const getUnreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments(buildNotificationQuery(req, { read: false }));

    res.json({
      success: true,
      count,
    });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

// @desc    Mark notification as read
// @route   PUT /api/notifications/:id/read
// @access  Private
const markAsRead = async (req, res) => {
  try {
    const notification = await Notification.findOne(
      buildNotificationQuery(req, { _id: req.params.id })
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        error: 'Notification not found',
      });
    }

    notification.read = true;
    await notification.save();

    res.json({
      success: true,
      message: 'Notification marked as read',
      notification: {
        id: notification._id.toString(),
        read: notification.read,
      },
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Notification not found' });
    }
    console.error('Mark as read error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

// @desc    Mark all notifications as read
// @route   PUT /api/notifications/read-all
// @access  Private
const markAllAsRead = async (req, res) => {
  try {
    const result = await Notification.updateMany(buildNotificationQuery(req, { read: false }), {
      $set: { read: true },
    });

    res.json({
      success: true,
      message: 'All notifications marked as read',
      updatedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('Mark all as read error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

// @desc    Delete notification
// @route   DELETE /api/notifications/:id
// @access  Private
const deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete(
      buildNotificationQuery(req, { _id: req.params.id })
    );

    if (!notification) {
      return res.status(404).json({
        success: false,
        error: 'Notification not found',
      });
    }

    res.json({
      success: true,
      message: 'Notification deleted successfully',
    });
  } catch (error) {
    if (error.name === 'CastError') {
      return res.status(404).json({ success: false, error: 'Notification not found' });
    }
    console.error('Delete notification error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

// @desc    Send test push to logged-in user (FCM + in-app notification record)
// @route   POST /api/notifications/test
// @access  Private
const sendTestNotification = async (req, res) => {
  try {
    const { userId, userType } = recipientOf(req);
    const { title, body } = req.body || {};

    const result = await sendNotificationToUser(userId, userType, {
      title: title || 'ISDR 2026 test',
      body: body || 'Push notifications are working.',
      type: 'general',
      data: { source: 'api', test: true },
      apartmentId: req.apartmentId,
    });

    if (!result.success) {
      return res.status(400).json({
        success: false,
        error: result.error || 'Failed to send test notification',
      });
    }

    res.json({
      success: true,
      message: 'Test notification sent',
      successCount: result.successCount,
      failureCount: result.failureCount,
    });
  } catch (error) {
    console.error('Send test notification error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Server error',
    });
  }
};

module.exports = {
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotification,
  sendTestNotification,
};
