import 'package:flutter/material.dart';
import '../../core/widgets/lily_backdrop.dart';
import '../../services/profile_service.dart';
import '../home/home_page.dart';
import 'profile_setup_page.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<String?> loading = ProfileService().name();
  void retry() => setState(() => loading = ProfileService().name());
  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: loading,
    builder: (context, result) {
      if (!result.hasData && result.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: LilyBackdrop(child: Center(child: CircularProgressIndicator())),
        );
      }
      if (result.hasError) {
        return Scaffold(
          body: LilyBackdrop(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Your profile could not load.'),
                  TextButton(onPressed: retry, child: const Text('Try again')),
                ],
              ),
            ),
          ),
        );
      }
      final name = result.data;
      return name == null || name.trim().isEmpty
          ? ProfileSetupPage(onSaved: retry)
          : const Home();
    },
  );
}
