import 'package:flutter/material.dart';

import 'api/api.dart';
import 'ledger_page.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.home, this.userChanges});
  final Widget home;
  final Stream<User?>? userChanges;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final _users = widget.userChanges ?? AuthApi.userChanges;

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: _users,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(child: Text(AuthApi.errorMessage(snapshot.error!))),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data == null ? const LoginScreen() : widget.home;
    },
  );
}

class TripSelectionPage extends StatefulWidget {
  const TripSelectionPage({super.key});

  @override
  State<TripSelectionPage> createState() => _TripSelectionPageState();
}

class _TripSelectionPageState extends State<TripSelectionPage> {
  late final _trips = TripApi.watchAll();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('내 여행'),
      actions: [
        IconButton(
          tooltip: '로그아웃',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await AuthApi.signOut();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(AuthApi.errorMessage(e))));
            }
          },
        ),
      ],
    ),
    body: StreamBuilder<List<Trip>>(
      stream: _trips,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(AuthApi.errorMessage(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final trips = snapshot.data!;
        if (trips.isEmpty) return const Center(child: Text('등록된 여행이 없어요'));
        return ListView.builder(
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return ListTile(
              title: Text(trip.name),
              subtitle: Text('${dayOnly(trip.start)} – ${dayOnly(trip.end)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LedgerPage(tripId: trip.id),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
