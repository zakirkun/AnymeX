
import 'package:aurora/auth/auth_provider.dart';
import 'package:aurora/main.dart';
import 'package:aurora/pages/Downloads/download_page.dart';
import 'package:aurora/pages/user/profile.dart';
import 'package:aurora/pages/user/settings.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';

class SettingsModal extends StatelessWidget {
  const SettingsModal({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // var box = Hive.box('login-data');
    final anilistProvider = Provider.of<AniListProvider>(context);
    // final userInfo =
    //     box.get('userInfo', defaultValue: ['Guest', 'Guest', 'null']);
    // final userName = userInfo?[0] ?? 'Guest';
    // final avatarImagePath = userInfo?[2] ?? 'null';
    // final isLoggedIn = userName != 'Guest';
    // final hasAvatarImage = avatarImagePath != 'null';

    final userName = anilistProvider.userData?['user']?['name'] ?? 'Guest';
    final avatarImagePath = anilistProvider.userData?['user']?['avatar']?['large'];
    final isLoggedIn = anilistProvider.userData?['user']?['name'] != null;
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const SizedBox(width: 5),
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              child: isLoggedIn
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(fit: BoxFit.cover, avatarImagePath),
                    )
                  : Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.inverseSurface,
                    ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName),
                GestureDetector(
                  onTap: () {
                    if (isLoggedIn) {
                      anilistProvider.logout(context);
                    } else {
                      anilistProvider.login(context);
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const MainApp()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    isLoggedIn ? 'Logout' : 'Login',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Expanded(
              child: SizedBox.shrink(),
            ),
            IconButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                icon: const Icon(Iconsax.notification))
          ]),
          const SizedBox(height: 10),
          // ListTile(
          //   leading: const Icon(Iconsax.user),
          //   title: const Text('Login (Not Completed)'),
          //   onTap: () {
          //     Navigator.pushReplacement(
          //       context,
          //       MaterialPageRoute(builder: (context) => const LoginPage()),
          //     );
          //   },
          // ),
          ListTile(
            leading: const Icon(Iconsax.user),
            title: const Text('View Profile'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          
          ListTile(
            leading: const Icon(Iconsax.document_download),
            title: const Text('Downloads'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DownloadPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Iconsax.setting),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Iconsax.logout),
              title: const Text('Logout'),
              onTap: () {
                Provider.of<AniListProvider>(context, listen: false)
                    .logout(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const MainApp()),
                  (route) => false,
                );
              },
            ),
        ],
      ),
    );
  }
}
