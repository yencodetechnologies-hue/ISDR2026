class ApiConfig {
  /// Local backend URL for Android Emulator (10.0.2.2 points to host PC's localhost)
  static const String _emulatorBaseUrl = 'http://10.0.2.2:5000/api';

  /// Local backend URL configuration for physical mobile devices on the same Wi-Fi
  static const String _localBaseUrl = 'http://192.168.100.247:5000/api';
  static const String _productionBaseUrl =
      'https://maccess.octosofttechnologies.in/api';

  /// Public Razorpay Key ID — same value as backend `RAZORPAY_KEY_ID`.
  /// Override at build time: `--dart-define=RAZORPAY_KEY_ID=rzp_live_...`
  static const String _razorpayKeyId = 'rzp_test_StaehAceNWvsTB';

  /// Override at runtime: run with
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:5000/api
  /// to use a local backend (or your PC IP for a device on the same network).
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Base URL: returns the live production backend.
  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) return _overrideBaseUrl;
    return _productionBaseUrl;
  }

  static String get authBase => '$baseUrl/auth';

  // Auth endpoints
  static String get register => '$authBase/register';
  static String get registerAdmin => '$authBase/register-admin';
  static String get login => '$authBase/login';
  static String get sendOtp => '$authBase/send-otp';
  static String get verifyOtp => '$authBase/verify-otp';
  static String get forgotPassword => '$authBase/forgot-password';
  static String get resetPassword => '$authBase/reset-password';
  static String get getCurrentUser => '$authBase/me';
  static String get updateManagementProfile => '$authBase/management-profile';
  static String get updateFcmToken => '$authBase/fcm-token';
  static String get getAllUsers => '$authBase/users';
  static String get registerTenant => '$authBase/register-tenant';
  static String get registerResidentBundle => '$authBase/register-resident-bundle';
  static String get getTenants => '$authBase/tenants';
  static String get getUsersByMobileNumber => '$authBase/users-by-mobile';
  static String get managementUsers => '$authBase/management-users';
  static String deleteManagementUserUrl(String id) => '$authBase/management-users/$id';

  // Apartment endpoints
  static String get apartmentsBase => '$baseUrl/apartments';
  static String get getAllApartments => apartmentsBase;
  static String getApartmentUrl(String id) => '$apartmentsBase/$id';
  static String get createApartment => apartmentsBase;
  static String get createCompanyPublic => '$apartmentsBase/public-company';
  static String updateApartmentUrl(String id) => '$apartmentsBase/$id';
  static String deleteApartmentUrl(String id) => '$apartmentsBase/$id';

  // Block endpoints
  static String get blocksBase => '$baseUrl/blocks';
  static String get getAllBlocks => blocksBase;
  static String get getBlock => blocksBase; // Use with /:id
  static String get createBlock => blocksBase;
  static String get addFloor => blocksBase; // Use with /:id/floors
  static String get addRoom => blocksBase; // Use with /:blockId/floors/:floorId/rooms
  static String get updateRoom => blocksBase; // Use with /:blockId/floors/:floorId/rooms/:roomId
  static String get deleteRoom => blocksBase; // Use with /:blockId/floors/:floorId/rooms/:roomId
  static String get updateBlock => blocksBase; // Use with /:id
  static String get updateFloor => blocksBase; // Use with /:blockId/floors/:floorId
  static String get deleteBlock => blocksBase; // Use with /:id
  static String get deleteFloor => blocksBase; // Use with /:blockId/floors/:floorId
  static String get toggleBlockActive => blocksBase; // Use with /:id/toggle-active
  static String get toggleUserActive => getAllUsers; // Use with /:id/toggle-active
  static String get updateUserStatus => getAllUsers; // Use with /:id/status
  static String get updateUser => getAllUsers; // Use with /:id
  static String get deleteUser => getAllUsers; // Use with /:id
  static String get securityBase => '$authBase/security';
  static String get updateSecurity => securityBase; // Use with /:id
  static String get deleteSecurity => securityBase; // Use with /:id

  // Maintenance endpoints
  static String get maintenanceBase => '$baseUrl/maintenance';
  static String get getAllMaintenance => '$maintenanceBase/all';
  static String get getMaintenance => maintenanceBase;
  static String get setMaintenance => maintenanceBase;
  static String get updateMaintenance => maintenanceBase; // Use with /:id

  /// Razorpay Key ID for checkout — [_razorpayKeyId], or `--dart-define`, or create-order `keyId`.
  static String get razorpayKey {
    const fromDefine = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return _razorpayKeyId;
  }

  // Payment endpoints
  static String get paymentsBase => '$baseUrl/payments';
  static String get getAllPayments => paymentsBase;
  static String get getPaymentStats => '$paymentsBase/stats';
  static String get getMyPayments => '$paymentsBase/my';
  static String get recordPayment => paymentsBase;
  static String get assignPayment => paymentsBase;
  static String get createRazorpayOrder => '$paymentsBase/create-order';
  static String get downloadPaymentReport => '$paymentsBase/report/download';
  static String getPaymentByIdUrl(String id) => '$paymentsBase/$id';
  static String completePaymentUrl(String id) => '$paymentsBase/$id/complete';
  static String downloadPaymentInvoiceUrl(String id) =>
      '$paymentsBase/$id/invoice/download';
  static String sendPaymentReminderUrl(String id) => '$paymentsBase/$id/send-reminder';
  static String uploadPaymentProofUrl(String id) => '$paymentsBase/$id/upload-proof';
  static String verifyPaymentProofUrl(String id) => '$paymentsBase/$id/verify-proof';
  static String rejectPaymentProofUrl(String id) => '$paymentsBase/$id/reject-proof';

  // Notice endpoints
  static String get noticesBase => '$baseUrl/notices';
  static String get getAllNotices => noticesBase;
  static String get createNotice => noticesBase;
  static String get updateNotice => noticesBase; // Use with /:id
  static String get deleteNotice => noticesBase; // Use with /:id

  // Post endpoints (feed / user posts)
  static String get postsBase => '$baseUrl/posts';
  static String get getPosts => postsBase;
  static String get createPost => postsBase;
  static String deletePostUrl(String id) => '$postsBase/$id';

  // Poll endpoints
  static String get pollsBase => '$baseUrl/polls';
  static String get getPolls => pollsBase;
  static String get createPoll => pollsBase;
  static String deletePollUrl(String id) => '$pollsBase/$id';
  static String votePollUrl(String id) => '$pollsBase/$id/vote';

  // Community / User events endpoints
  static String get communityEventsBase => '$baseUrl/community-events';
  static String get getCommunityEvents => communityEventsBase;
  static String get createCommunityEvent => communityEventsBase;
  static String deleteCommunityEventUrl(String id) => '$communityEventsBase/$id';

  // Permission endpoints
  static String get permissionsBase => '$baseUrl/permissions';
  static String get getPermissions => permissionsBase; // Use with /:userType
  static String get updatePermissions => permissionsBase; // Use with /:userType

  // Ad endpoints
  static String get adsBase => '$baseUrl/ads';
  static String get getAds => adsBase;
  static String get createAd => adsBase;
  static String get deleteAd => adsBase; // Use with /:id

  // Property document endpoints
  static String get propertyDocumentsBase => '$baseUrl/property-documents';
  static String get propertyDocumentRequirements =>
      '$propertyDocumentsBase/requirements';
  static String get myPropertyDocuments => '$propertyDocumentsBase/my';
  static String propertyDocumentsForUserUrl(String userId) =>
      '$propertyDocumentsBase/user/$userId';
  static String get uploadPropertyDocument => '$propertyDocumentsBase/upload';
  static String deletePropertyDocumentRequirementUrl(String id) =>
      '$propertyDocumentsBase/requirements/$id';

  // Amenity endpoints
  static String get amenitiesBase => '$baseUrl/amenities';
  static String get getAmenities => amenitiesBase;
  static String get createAmenity => amenitiesBase;
  static String updateAmenityUrl(String id) => '$amenitiesBase/$id';
  static String deleteAmenityUrl(String id) => '$amenitiesBase/$id';
  static String getAmenitySlotsUrl(String id) => '$amenitiesBase/$id/slots';
  static String bookAmenityUrl(String id) => '$amenitiesBase/$id/book';
  static String get amenityBookings => '$amenitiesBase/bookings';
  static String cancelAmenityBookingUrl(String id) => '$amenitiesBase/bookings/$id/cancel';

  // Vehicle endpoints
  static String get vehiclesBase => '$baseUrl/vehicles';
  static String get getVehicles => vehiclesBase;
  static String get addVehicle => vehiclesBase;
  static String deleteVehicleUrl(String id) => '$vehiclesBase/$id';
  static String verifyVehicleUrl(String id) => '$vehiclesBase/verify/$id';

  // Family member endpoints
  static String get familyMembersBase => '$baseUrl/family-members';
  static String get getFamilyMembers => familyMembersBase;
  static String get addFamilyMember => familyMembersBase;
  static String deleteFamilyMemberUrl(String id) => '$familyMembersBase/$id';

  // Visitor endpoints (security: all visitors / today)
  static String get visitorsBase => '$baseUrl/visitors';
  static String get getSecurityVisitors => '$visitorsBase/all/list';
  static String get createSecurityVisitor => '$visitorsBase/security';
  static String get createSecurityVisitorBulk => '$visitorsBase/security/bulk';
  static String get getVisitorsForMyUnit => '$visitorsBase/my-unit';
  static String get getActiveVisitors => '$visitorsBase/active';
  static String get getVisitorHistory => '$visitorsBase/history';
  static String get getVisitorAnalytics => '$visitorsBase/analytics';
  static String get getMonthlyAttendance => '$visitorsBase/monthly-attendance';
  static String visitorApprovalUrl(String visitorId) => '$visitorsBase/$visitorId/approval';
  static String visitorEntryUrl(String visitorId) => '$visitorsBase/$visitorId/entry';
  static String visitorExitUrl(String visitorId) => '$visitorsBase/$visitorId/exit';
  static String get getMonthlyVisitorPasses => '$visitorsBase/monthly-passes';
  static String get createMonthlyVisitorPass => '$visitorsBase/monthly-passes';
  static String monthlyVisitorPassToggleUrl(String passId) => '$visitorsBase/monthly-passes/$passId/toggle';
  static String get verifyVisitorByOtp => '$visitorsBase/verify-by-otp';
  static String get verifyVisitorByQr => '$visitorsBase/verify-by-qr';

  // Managed event ticketing (BookMyShow-style)
  static String get managedEventsBase => '$baseUrl/managed-events';
  static String get managedEventsList => managedEventsBase;
  static String get managedEventsCreate => managedEventsBase;
  static String managedEventById(String id) => '$managedEventsBase/$id';
  static String managedEventRegistrations(String id) =>
      '$managedEventsBase/$id/registrations';
  static String managedEventRegistrationSpot(String id) =>
      '$managedEventsBase/$id/registrations/spot';
  static String managedEventRegistrationBulk(String id) =>
      '$managedEventsBase/$id/registrations/bulk';
  static String managedEventRegistrationById(String id, String regId) =>
      '$managedEventsBase/$id/registrations/$regId';
  static String managedEventPublic(String slug) =>
      '$managedEventsBase/public/$slug';
  static String managedEventRegister(String slug) =>
      '$managedEventsBase/public/$slug/register';
  static String managedEventPublicTicket(String id) =>
      '$managedEventsBase/public/ticket/$id';
  static String get managedEventVerifyQr => '$managedEventsBase/verify-qr';
  static String get managedEventMyTickets => '$managedEventsBase/my-tickets';
  static String get managedEventSecurityToday =>
      '$managedEventsBase/security/today';
  static String get managedEventClaimInclusion =>
      '$managedEventsBase/claim-inclusion';
  /// Public web register link host (web SPA).
  static const String publicWebBaseUrl = 'https://www.maccess.online';
  static const String eventWebBaseUrl = publicWebBaseUrl;
  static String eventRegisterWebUrl(String slug) => '$eventWebBaseUrl/e/$slug';

  // Security list for residents
  static String get getSecurityList => '$securityBase/list';

  // Support / Help desk endpoints
  static String get supportTicketsBase => '$baseUrl/support/tickets';
  static String supportTicketById(String id) => '$supportTicketsBase/$id';
  static String supportMessages(String ticketId) => '$supportTicketsBase/$ticketId/messages';
  static String supportSendMessage(String ticketId) => '$supportTicketsBase/$ticketId/messages';
  static String supportTicketStatus(String id) => '$supportTicketsBase/$id/status';

  // Complaints endpoints
  static String get complaintsBase => '$baseUrl/complaints';
  static String complaintStatus(String id) => '$complaintsBase/$id/status';

  // Society operations endpoints
  static String get societyOpsBase => '$baseUrl/society-ops';
  static String get societyOpsSummary => '$societyOpsBase/summary';
  static String get societyOpsFurniture => '$societyOpsBase/furniture';
  static String get societyOpsLiftServices => '$societyOpsBase/lift-services';
  static String get societyOpsLiftPayments => '$societyOpsBase/lift-payments';
  static String get societyOpsAssets => '$societyOpsBase/assets';

  // Leave request endpoints (hostel)
  static String get leaveRequestsBase => '$baseUrl/leave-requests';
  static String get myLeaveRequests => '$leaveRequestsBase/mine';
  static String leaveRequestApproval(String id) => '$leaveRequestsBase/$id/approval';
  static String leaveRequestCancel(String id) => '$leaveRequestsBase/$id/cancel';
  static String leaveRequestGatePass(String id) => '$leaveRequestsBase/$id/gate-pass';
  static String get verifyLeaveByQr => '$leaveRequestsBase/verify-by-qr';
  static String leaveRequestsList({String? apartmentId, String? status}) {
    final q = <String>[];
    if (apartmentId != null && apartmentId.isNotEmpty) q.add('apartmentId=$apartmentId');
    if (status != null && status.isNotEmpty) q.add('status=$status');
    if (q.isEmpty) return leaveRequestsBase;
    return '$leaveRequestsBase?${q.join('&')}';
  }

  // Hostel resident digital ID
  static String get hostelIdPayload => '$authBase/hostel-id-payload';
  static String get verifyHostelQr => '$authBase/verify-hostel-qr';
  static String get staffQr => '$authBase/staff-qr';

  // Kid exit endpoints (user–security communication)
  static String get kidExitsBase => '$baseUrl/kid-exits';
  static String get reportKidExit => kidExitsBase;
  static String get getKidExits => kidExitsBase;
  static String kidExitAcknowledgeUrl(String id) => '$kidExitsBase/$id/acknowledge';

  // Subscription endpoints (admin subscription, app-active for user/security)
  static String get subscriptionBase => '$baseUrl/subscription';
  static String get subscriptionPlans => '$subscriptionBase/plans';
  static String get subscriptionPlansHistory => '$subscriptionBase/plans/history';
  static String get subscriptionCreateOrder => '$subscriptionBase/create-order';
  static String get subscriptionVerify => '$subscriptionBase/verify';
  static String get subscriptionMy => '$subscriptionBase/my';
  static String subscriptionByApartment(String apartmentId) =>
      '$subscriptionBase/by-apartment/$apartmentId';
  static String get subscriptionPurchases => '$subscriptionBase/purchases';
  static String subscriptionPurchaseInvoiceDownload(String id, {String format = 'pdf'}) =>
      '$subscriptionBase/purchases/$id/invoice/download?format=$format';
  static String get subscriptionAppActive => '$subscriptionBase/app-active';
  static String get subscriptionCreatePlan => '$subscriptionBase/plans';
  static String subscriptionUpdatePlan(String id) => '$subscriptionBase/plans/$id';
  static String subscriptionDeletePlan(String id) => '$subscriptionBase/plans/$id';

  // Guard Message / Chat endpoints
  static String get guardMessagesBase => '$baseUrl/guard-messages';
  static String get guardConversations => '$guardMessagesBase/conversations';
  static String guardConversationMessages(String conversationId) =>
      '$guardMessagesBase/conversations/$conversationId';
  static String guardMarkConversationRead(String conversationId) =>
      '$guardMessagesBase/conversations/$conversationId/read';
  static String get guardSendMessage => '$guardMessagesBase/send';
  static String guardMarkMessageRead(String messageId) =>
      '$guardMessagesBase/$messageId/read';
  static String get guardUnreadCount => '$guardMessagesBase/unread-count';
  static String get guardSecurityList => '$guardMessagesBase/security-list';
  static String get guardTenantList => '$guardMessagesBase/tenant-list';
  static String get guardGetOrCreateConversation => '$guardMessagesBase/conversation';

  // Tenant Message / Chat endpoints
  static String get tenantMessagesBase => '$baseUrl/tenant-messages';
  static String tenantGetOrCreateConversation(String tenantId) =>
      '$tenantMessagesBase/conversation/$tenantId';
  static String get tenantConversations => '$tenantMessagesBase/conversations';
  static String tenantConversationMessages(String conversationId) =>
      '$tenantMessagesBase/conversations/$conversationId';
  static String tenantMarkConversationRead(String conversationId) =>
      '$tenantMessagesBase/conversations/$conversationId/read';
  static String get tenantSendMessage => '$tenantMessagesBase/send';
  static String get tenantUploadAgreement => '$tenantMessagesBase/agreements/upload';
  static String tenantGetAgreements(String conversationId) =>
      '$tenantMessagesBase/agreements/$conversationId';
  static String tenantDeleteAgreement(String agreementId) =>
      '$tenantMessagesBase/agreements/$agreementId';
  static String tenantDownloadAgreement(String agreementId) =>
      '$tenantMessagesBase/agreements/$agreementId/download';

  // Health check
  static String get health => '$baseUrl/health';

  // Notification endpoints
  static String get notificationsBase => '$baseUrl/notifications';
  static String get getNotifications => notificationsBase;
  static String get getUnreadCount => '$notificationsBase/unread-count';
  static String markAsReadUrl(String id) => '$notificationsBase/$id/read';
  static String get markAllAsRead => '$notificationsBase/read-all';
  static String deleteNotificationUrl(String id) => '$notificationsBase/$id';
}
