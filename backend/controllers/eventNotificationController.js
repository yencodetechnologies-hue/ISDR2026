const ManagedEvent = require('../models/ManagedEvent');
const EventRegistration = require('../models/EventRegistration');
const EventNotification = require('../models/EventNotification');
const { normalizeInclusions } = require('./managedEventController');

// POST /api/managed-events/:id/notifications
// Body: { message, packageId?, inclusionName? }
// Targets the event's participants (not cancelled), narrowed to a package and/or an inclusion.
const sendNotification = async (req, res) => {
  try {
    const event = await ManagedEvent.findById(req.params.id);
    if (!event) {
      return res.status(404).json({ success: false, error: 'Event not found' });
    }
    if (String(event.apartmentId) !== String(req.apartmentId)) {
      return res.status(403).json({ success: false, error: 'Not authorized for this event' });
    }

    const message = String(req.body.message || '').trim();
    if (!message) {
      return res.status(400).json({ success: false, error: 'Notification content is required' });
    }
    const packageId = String(req.body.packageId || '').trim();
    const inclusionName = String(req.body.inclusionName || '').trim();

    const packages = event.packages || [];
    let selectedPackage = null;
    if (packageId) {
      selectedPackage = packages.find((p) => p.id === packageId);
      if (!selectedPackage) {
        return res.status(400).json({ success: false, error: 'Package not found in this event' });
      }
    }

    // Packages whose participants are targeted: the chosen one, else every package that offers
    // the chosen inclusion, else all.
    let targetPackages = packages;
    if (selectedPackage) {
      targetPackages = [selectedPackage];
    }
    if (inclusionName) {
      targetPackages = targetPackages.filter((p) =>
        normalizeInclusions(p.inclusions).some(
          (i) => i.name.toLowerCase() === inclusionName.toLowerCase()
        )
      );
      if (targetPackages.length === 0) {
        return res
          .status(400)
          .json({ success: false, error: 'That inclusion is not part of the selected package' });
      }
    }

    const filter = { eventId: event._id, status: { $ne: 'cancelled' } };
    if (selectedPackage || inclusionName) {
      const ids = targetPackages.map((p) => p.id);
      const names = targetPackages.map((p) => p.name);
      filter.$or = [{ packageId: { $in: ids } }, { packageName: { $in: names } }];
    }
    const recipients = await EventRegistration.find(filter).select('_id').lean();

    const notification = await EventNotification.create({
      eventId: event._id,
      apartmentId: event.apartmentId,
      packageId: selectedPackage ? selectedPackage.id : '',
      packageName: selectedPackage ? selectedPackage.name : '',
      inclusionName,
      message,
      recipientIds: recipients.map((r) => r._id),
      recipientCount: recipients.length,
    });

    res.status(201).json({
      success: true,
      recipientCount: recipients.length,
      notification: {
        id: notification._id.toString(),
        eventId: event._id.toString(),
        packageName: notification.packageName,
        inclusionName: notification.inclusionName,
        message: notification.message,
        recipientCount: notification.recipientCount,
        createdAt: notification.createdAt,
      },
    });
  } catch (error) {
    console.error('sendNotification error:', error);
    res.status(500).json({ success: false, error: error.message || 'Server error' });
  }
};

module.exports = { sendNotification };
