import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/models/kid_exit_model.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../bloc/security_bloc.dart';
import '../widgets/kid_exits_panel.dart';

class SecurityKidExitsTab extends StatelessWidget {
  final List<KidExitModel> kidExits;

  const SecurityKidExitsTab({super.key, required this.kidExits});

  @override
  Widget build(BuildContext context) {
    return KidExitsPanel(
      embedded: true,
      kidExits: kidExits,
      scrollController: null,
      onRefresh: () {
        final authState = context.read<AuthBloc>().state;
        final apartmentId =
            authState is AuthAuthenticated ? authState.user.apartmentId : null;
        context
            .read<SecurityBloc>()
            .add(LoadSecurityDataEvent(apartmentId: apartmentId));
      },
    );
  }
}
