import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

// Events
abstract class NotificationEvent extends Equatable {
  const NotificationEvent();
  @override
  List<Object?> get props => [];
}

class LoadNotifications extends NotificationEvent {
  final int page;
  final String? type;
  final bool? read;
  const LoadNotifications({this.page = 1, this.type, this.read});
  @override
  List<Object?> get props => [page, type, read];
}

class RefreshNotifications extends NotificationEvent {
  const RefreshNotifications();
}

class MarkAsRead extends NotificationEvent {
  final String notificationId;
  const MarkAsRead(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

class MarkAllAsRead extends NotificationEvent {
  const MarkAllAsRead();
}

class DeleteNotification extends NotificationEvent {
  final String notificationId;
  const DeleteNotification(this.notificationId);
  @override
  List<Object?> get props => [notificationId];
}

class LoadUnreadCount extends NotificationEvent {
  const LoadUnreadCount();
}

// States
abstract class NotificationState extends Equatable {
  const NotificationState();
  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final int currentPage;
  final int totalPages;
  final bool hasMore;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [notifications, unreadCount, currentPage, totalPages, hasMore];
}

class NotificationError extends NotificationState {
  final String message;
  const NotificationError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  NotificationBloc({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository(),
        super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<RefreshNotifications>(_onRefreshNotifications);
    on<MarkAsRead>(_onMarkAsRead);
    on<MarkAllAsRead>(_onMarkAllAsRead);
    on<DeleteNotification>(_onDeleteNotification);
    on<LoadUnreadCount>(_onLoadUnreadCount);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final result = await _repository.getNotifications(
        page: event.page,
        type: event.type,
        read: event.read,
      );

      if (result['success'] == true) {
        final notifications = result['notifications'] as List<NotificationModel>;
        final pagination = result['pagination'] as Map<String, dynamic>;
        final unreadCount = await _repository.getUnreadCount();

        emit(NotificationLoaded(
          notifications: notifications,
          unreadCount: unreadCount,
          currentPage: pagination['page'] ?? 1,
          totalPages: pagination['pages'] ?? 1,
          hasMore: (pagination['page'] ?? 1) < (pagination['pages'] ?? 1),
        ));
      } else {
        emit(NotificationError(result['error'] ?? 'Failed to load notifications'));
      }
    } catch (e) {
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onRefreshNotifications(
    RefreshNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    if (state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      add(LoadNotifications(page: 1, type: null, read: null));
    } else {
      add(const LoadNotifications());
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final success = await _repository.markAsRead(event.notificationId);
    if (success && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      final updatedNotifications = currentState.notifications.map((n) {
        if (n.id == event.notificationId) {
          return n.copyWith(read: true);
        }
        return n;
      }).toList();

      final unreadCount = await _repository.getUnreadCount();

      emit(NotificationLoaded(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
        currentPage: currentState.currentPage,
        totalPages: currentState.totalPages,
        hasMore: currentState.hasMore,
      ));
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final success = await _repository.markAllAsRead();
    if (success && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      final updatedNotifications = currentState.notifications
          .map((n) => n.copyWith(read: true))
          .toList();

      emit(NotificationLoaded(
        notifications: updatedNotifications,
        unreadCount: 0,
        currentPage: currentState.currentPage,
        totalPages: currentState.totalPages,
        hasMore: currentState.hasMore,
      ));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationState> emit,
  ) async {
    final success = await _repository.deleteNotification(event.notificationId);
    if (success && state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      final updatedNotifications = currentState.notifications
          .where((n) => n.id != event.notificationId)
          .toList();

      final unreadCount = await _repository.getUnreadCount();

      emit(NotificationLoaded(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
        currentPage: currentState.currentPage,
        totalPages: currentState.totalPages,
        hasMore: currentState.hasMore,
      ));
    }
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    final unreadCount = await _repository.getUnreadCount();
    if (state is NotificationLoaded) {
      final currentState = state as NotificationLoaded;
      emit(NotificationLoaded(
        notifications: currentState.notifications,
        unreadCount: unreadCount,
        currentPage: currentState.currentPage,
        totalPages: currentState.totalPages,
        hasMore: currentState.hasMore,
      ));
    } else {
      // If no notifications loaded yet, just emit a state with unread count
      // This allows the badge to show the count even before notifications are loaded
      emit(NotificationLoaded(
        notifications: const [],
        unreadCount: unreadCount,
        currentPage: 1,
        totalPages: 1,
        hasMore: false,
      ));
    }
  }
}
