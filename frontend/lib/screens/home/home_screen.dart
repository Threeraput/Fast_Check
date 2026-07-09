import 'package:flutter/material.dart';
import 'package:frontend/models/users.dart';
import 'package:frontend/screens/classroom/classroom_home_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/utils/app_theme.dart';

class HomeScreen extends StatefulWidget {
	const HomeScreen({super.key});

	@override
	State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
	User? _currentUser;
	bool _isAdmin = false;

	@override
	void initState() {
		super.initState();
		_loadCurrentUser();
	}

	Future<void> _loadCurrentUser() async {
		final user = await AuthService.getCurrentUserFromLocal();
		final tokenRoles = await AuthService.getTokenRoles();
		if (!mounted) return;
		setState(() {
			_currentUser = user;
			_isAdmin = tokenRoles.contains('admin');
		});
	}

	Future<void> _logout() async {
		await AuthService.logout();
		if (!mounted) return;
		Navigator.of(context).pushReplacementNamed('/login');
	}

	@override
	Widget build(BuildContext context) {
		final user = _currentUser;
		return Scaffold(
			backgroundColor: Colors.transparent,
			appBar: AppBar(
				title: const Text('Home'),
				actions: [
					if (_isAdmin)
						TextButton(
							onPressed: () => Navigator.pushNamed(context, '/admin-dashboard'),
							child: const Text('Admin', style: TextStyle(fontSize: 13)),
						),
					IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
				],
			),
			body: Center(
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: AppCard(
						padding: const EdgeInsets.all(16),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								if (user == null)
									const Padding(
										padding: EdgeInsets.symmetric(vertical: 16),
										child: SizedBox(
											width: 22,
											height: 22,
											child: CircularProgressIndicator(strokeWidth: 2),
										),
									)
								else ...[
									CircleAvatar(
										radius: 24,
										backgroundColor: AppColors.primaryLight,
										child: Text(
											user.username[0].toUpperCase(),
											style: const TextStyle(
												fontSize: 18,
												fontWeight: FontWeight.w700,
												color: AppColors.primary,
											),
										),
									),
									const SizedBox(height: 12),
									Text(
										'Welcome, ${user.firstName ?? user.username}',
										textAlign: TextAlign.center,
										style: const TextStyle(
											fontSize: 18,
											fontWeight: FontWeight.w700,
											color: AppColors.textPrimary,
										),
									),
									const SizedBox(height: 6),
									Text('Username: ${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
									if (user.email != null)
										Text('Email: ${user.email}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
									const SizedBox(height: 8),
									AppBadge(user.roles.join(', '), color: AppColors.surfaceAlt),
									const SizedBox(height: 18),
								],
								FilledButton.icon(
									icon: const Icon(Icons.people_alt_outlined, size: 18),
									label: const Text('Go to Classroom'),
									onPressed: () {
										Navigator.of(context).push(
											MaterialPageRoute(builder: (_) => const ClassroomHomeScreen()),
										);
									},
								),
							],
						),
					),
				),
			),
		);
	}
}
