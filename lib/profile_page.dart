import 'package:flutter/material.dart';
import 'app_data.dart';
import 'api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final bg = Colors.white;
  // start with empty user data so profile shows a clean state when no
  // persisted/profile info is available.
  String _name = '';
  String _email = '';
  String _phone = '';
  String _selectedLanguage = '';
  bool _notifications = true;

  // No dummy languages or singers by default — show sections only when
  // there is real data to render.
  final List<Map<String, String>> _languages = <Map<String, String>>[];
  final List<Map<String, String>> _singers = <Map<String, String>>[];

  void _showLanguagePicker() async {
    if (_languages.isEmpty) return;
    // ignore: use_build_context_synchronously
    final chosen = await showDialog<String>(
      context: AppData.navigatorKey.currentContext!,
      builder: (ctx) {
          return Dialog(
            backgroundColor: bg,
            child: SizedBox(
              height: 380,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Choose language',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      padding: const EdgeInsets.all(12),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: _languages.map((lang) {
                        final selected = lang['name'] == _selectedLanguage;
                        final display = lang['name']!.contains('(')
                            ? lang['name']!.split('(')[0].trim()
                            : lang['name']!;
                        return InkWell(
                          onTap: () => Navigator.of(ctx).pop(lang['name']),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                  image: NetworkImage(lang['image']!),
                                  fit: BoxFit.cover),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: const LinearGradient(
                                            colors: [
                                              Colors.black26,
                                              Colors.black38
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter)),
                                  ),
                                ),
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(display,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                                if (selected)
                                  const Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Icon(Icons.check_circle,
                                          color: Colors.tealAccent))
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
    if (chosen != null && chosen.isNotEmpty) {
      final navCtx = AppData.navigatorKey.currentContext;
      if (navCtx != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(navCtx).showSnackBar(SnackBar(content: Text('Language set to $chosen')));
      }
      if (!mounted) return;
      setState(() => _selectedLanguage = chosen);
    }
  }

  void _showAddSingerDialog() async {
    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    // ignore: use_build_context_synchronously
    final added = await showDialog<bool>(
      context: AppData.navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
              backgroundColor: bg,
              title: const Text('Add singer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                          hintText: 'Singer name',
                          hintStyle: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 8),
                  TextField(
                      controller: imageCtrl,
                      style: const TextStyle(color: Colors.black),
                      decoration: const InputDecoration(
                          hintText: 'Image URL (optional)',
                          hintStyle: TextStyle(color: Colors.grey))),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      setState(() {
                        _singers.add(
                            {'name': name, 'image': imageCtrl.text.trim()});
                      });
                      Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Add'))
              ],
            ));
    if (added == true) {
      final navCtx = AppData.navigatorKey.currentContext;
      if (navCtx != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(navCtx).showSnackBar(const SnackBar(content: Text('Singer added')));
      }
    }
  }

  void _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    // ignore: use_build_context_synchronously
    final saved = await showDialog<bool>(
      context: AppData.navigatorKey.currentContext!,
      builder: (ctx) {
          return AlertDialog(
            backgroundColor: bg,
            title: const Text('Edit profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                        hintText: 'Full name',
                        hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Colors.grey)),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                        hintText: 'Mobile number',
                        hintStyle: TextStyle(color: Colors.grey)),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      final nm = nameCtrl.text.trim();
                      final em = emailCtrl.text.trim();
                      final ph = phoneCtrl.text.trim();
                      // Allow empty fields — store whatever user provided.
                      setState(() {
                        _name = nm;
                        _email = em.isEmpty ? '' : em;
                        _phone = ph.isEmpty ? '' : ph;
                      });
                      Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Save'))
            ],
          );
        });
    if (saved == true) {
      // Update local profile info. Do NOT automatically mark as logged in
      // unless the user completed an auth flow.
      AppData.currentUser.value = {'name': _name, 'email': _email, 'phone': _phone};
      final navCtx = AppData.navigatorKey.currentContext;
      if (navCtx != null) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(navCtx).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
      if (!mounted) return;
    }
  }

  Future<void> _showLoginDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool keepSigned = false;
    // ignore: use_build_context_synchronously
    final result = await showDialog<bool>(
      context: AppData.navigatorKey.currentContext!,
      builder: (ctx) {
          return AlertDialog(
            title: const Text('Login'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: passCtrl, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
                const SizedBox(height: 8),
                StatefulBuilder(builder: (ctx2, setState2) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: keepSigned,
                    onChanged: (v) => setState2(() => keepSigned = v ?? false),
                    title: const Text('Keep me signed in (1 year)'),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Login'))
            ],
          );
        });
    if (result == true) {
      final email = emailCtrl.text.trim();
      final pwd = passCtrl.text;
      try {
        final deviceInfo = {'mode': 'web'}; // minimal device info; native platforms may add better details
        final resp = await ApiService.login(email, pwd, oneYear: keepSigned, device: deviceInfo);
          if (resp != null && resp['ok'] == true) {
          AppData.currentUser.value = resp['user'] as Map<String, dynamic>;
          if (resp.containsKey('token')) AppData.currentUser.value['token'] = resp['token'];
          if (resp.containsKey('tokenExpiresAt')) AppData.currentUser.value['tokenExpiresAt'] = resp['tokenExpiresAt'];
          // persist auth
          if (resp.containsKey('token')) {
            await AppData.saveAuthToPrefs(token: resp['token'] as String, tokenExpiresAt: resp['tokenExpiresAt'] as String?, user: resp['user'] as Map<String, dynamic>);
          }
          AppData.isLoggedIn.value = true;
          final navCtx = AppData.navigatorKey.currentContext;
          if (navCtx != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(navCtx).showSnackBar(const SnackBar(content: Text('Logged in')));
          }
          if (!mounted) return;
        } else {
          final navCtx = AppData.navigatorKey.currentContext;
          if (navCtx != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(navCtx).showSnackBar(SnackBar(content: Text(resp['error'] ?? 'Login failed')));
          }
          if (!mounted) return;
        }
      } catch (e) {
        final navCtx = AppData.navigatorKey.currentContext;
        if (navCtx != null) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(navCtx).showSnackBar(SnackBar(content: Text('Login error: $e')));
        }
        if (!mounted) return;
      }
    }
  }

  Future<void> _showSignupDialog() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool keepSigned = false;
    // ignore: use_build_context_synchronously
    final result = await showDialog<bool>(
      context: AppData.navigatorKey.currentContext!,
      builder: (ctx) {
          return AlertDialog(
            title: const Text('Sign up'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: passCtrl, decoration: const InputDecoration(hintText: 'Password'), obscureText: true),
                const SizedBox(height: 8),
                StatefulBuilder(builder: (ctx2, setState2) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: keepSigned,
                    onChanged: (v) => setState2(() => keepSigned = v ?? false),
                    title: const Text('Keep me signed in (1 year)'),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign up'))
            ],
          );
        });
    if (result == true) {
      final email = emailCtrl.text.trim();
      final pwd = passCtrl.text;
      try {
        final deviceInfo = {'mode': 'web'};
        final resp = await ApiService.signup(email, pwd, oneYear: keepSigned, device: deviceInfo);
        if (resp != null && resp['ok'] == true) {
          AppData.currentUser.value = resp['user'] as Map<String, dynamic>;
          if (resp.containsKey('token')) AppData.currentUser.value['token'] = resp['token'];
          if (resp.containsKey('tokenExpiresAt')) AppData.currentUser.value['tokenExpiresAt'] = resp['tokenExpiresAt'];
          if (resp.containsKey('token')) {
            await AppData.saveAuthToPrefs(token: resp['token'] as String, tokenExpiresAt: resp['tokenExpiresAt'] as String?, user: resp['user'] as Map<String, dynamic>);
          }
          AppData.isLoggedIn.value = true;
          final navCtx = AppData.navigatorKey.currentContext;
          if (navCtx != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(navCtx).showSnackBar(const SnackBar(content: Text('Account created and logged in')));
          }
          if (!mounted) return;
        } else {
          final navCtx = AppData.navigatorKey.currentContext;
          if (navCtx != null) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(navCtx).showSnackBar(SnackBar(content: Text(resp['error'] ?? 'Signup failed')));
          }
          if (!mounted) return;
        }
      } catch (e) {
        final navCtx = AppData.navigatorKey.currentContext;
        if (navCtx != null) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(navCtx).showSnackBar(SnackBar(content: Text('Signup error: $e')));
        }
        if (!mounted) return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // profile header
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person,
                        size: 40, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _email,
                                style: const TextStyle(
                                    color: Colors.black87, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              _phone,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showEditProfileDialog,
                    child: const Text('Edit',
                        style: TextStyle(color: Colors.tealAccent)),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: Color.fromARGB(255, 230, 228, 228)),
              const SizedBox(height: 8),

              // Languages: only show when we have language options
              if (_languages.isNotEmpty) ...[
                const Text('Languages',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _languages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final lang = _languages[i];
                      final selected = lang['name'] == _selectedLanguage;
                      final display = lang['name']!.contains('(')
                          ? lang['name']!.split('(')[0].trim()
                          : lang['name']!;
                      return InkWell(
                        onTap: _showLanguagePicker,
                        child: Container(
                          width: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                                image: NetworkImage(lang['image']!),
                                fit: BoxFit.cover),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                  child: Container(
                                      decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              10),
                                          color: Colors.black26))),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(display,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.check_circle,
                                        color: Colors.tealAccent, size: 18))
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.translate, color: Colors.black87),
                  title: const Text('App language'),
                  subtitle: Text(_selectedLanguage.isNotEmpty ? _selectedLanguage : 'Not set',
                      style: const TextStyle(color: Colors.black87)),
                  trailing: TextButton(
                      onPressed: _showLanguagePicker,
                      child: const Text('Change',
                          style: TextStyle(color: Colors.tealAccent))),
                ),
              ],

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications, color: Colors.black87),
                title: const Text('Notifications'),
                subtitle: const Text('Enable push notifications',
                    style: TextStyle(color: Colors.black87)),
                trailing: Switch(
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                    thumbColor: WidgetStateProperty.resolveWith<Color?>(
                        (Set<WidgetState> states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.tealAccent;
                      }
                      return null;
                    })),
              ),

              const SizedBox(height: 6),
              const Divider(color: Color.fromARGB(255, 236, 235, 235)),
              const SizedBox(height: 8),

              // Favorite singers: show only when there are any
              if (_singers.isNotEmpty) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Favorite singers',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w600)),
                  TextButton(
                      onPressed: _showAddSingerDialog,
                      child: const Text('Add',
                          style: TextStyle(color: Colors.tealAccent)))
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _singers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final s = _singers[i];
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.shade200),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: (s['image'] != null &&
                                            s['image']!.isNotEmpty)
                                        ? NetworkImage(s['image']!)
                                        : null,
                                    child: (s['image'] == null ||
                                            s['image']!.isEmpty)
                                        ? const Icon(Icons.person,
                                            color: Colors.black54)
                                        : null),
                                const SizedBox(height: 8),
                                Text(s['name'] ?? '',
                                    style:
                                        const TextStyle(color: Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)
                              ],
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _singers.removeAt(i);
                                });
                              },
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.black87),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ),
              ],

              const Spacer(),

              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: AppData.isLoggedIn,
                  builder: (ctx, loggedIn, __) {
                    if (loggedIn) {
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () {
                          AppData.currentUser.value = <String, dynamic>{};
                          AppData.isLoggedIn.value = false;
                          AppData.clearAuthPrefs();
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                          child: Text('Sign out'),
                        ),
                      );
                    }

                    // Not logged in: show Login / Sign up actions
                    // Not logged in: show Login / Sign up actions only when backend
                    // ui-config allows it (feature flag `show_login_button`).
                    final showLogin = AppData.featureEnabled('show_login_button');
                    if (!showLogin) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: _showLoginDialog,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
                            child: Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: _showSignupDialog,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 12),
                            child: Text('Sign up'),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
