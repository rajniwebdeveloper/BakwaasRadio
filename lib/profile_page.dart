import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final bg = Colors.white;
  String _name = 'User Name';
  String _email = 'user@bakwaas.fm';
  String _phone = '+91 98765 43210';
  String _selectedLanguage = 'English';
  bool _notifications = true;

  final List<Map<String, String>> _languages = [
    {
      'code': 'hi',
      'name': 'Hindi (Uttar Pradesh, MP)',
      'image': 'https://picsum.photos/200?image=101'
    },
    {
      'code': 'bn',
      'name': 'Bengali (West Bengal)',
      'image': 'https://picsum.photos/200?image=102'
    },
    {
      'code': 'ta',
      'name': 'Tamil (Tamil Nadu)',
      'image': 'https://picsum.photos/200?image=103'
    },
    {
      'code': 'te',
      'name': 'Telugu (Andhra/Telangana)',
      'image': 'https://picsum.photos/200?image=104'
    },
    {
      'code': 'mr',
      'name': 'Marathi (Maharashtra)',
      'image': 'https://picsum.photos/200?image=105'
    },
    {
      'code': 'gu',
      'name': 'Gujarati (Gujarat)',
      'image': 'https://picsum.photos/200?image=106'
    },
    {
      'code': 'kn',
      'name': 'Kannada (Karnataka)',
      'image': 'https://picsum.photos/200?image=107'
    },
    {
      'code': 'ml',
      'name': 'Malayalam (Kerala)',
      'image': 'https://picsum.photos/200?image=108'
    },
    {
      'code': 'pa',
      'name': 'Punjabi (Punjab)',
      'image': 'https://picsum.photos/200?image=109'
    },
    {
      'code': 'or',
      'name': 'Odia (Odisha)',
      'image': 'https://picsum.photos/200?image=110'
    },
    {
      'code': 'as',
      'name': 'Assamese (Assam)',
      'image': 'https://picsum.photos/200?image=111'
    },
  ];

  final List<Map<String, String>> _singers = [
    {'name': 'Arijit Singh', 'image': 'https://picsum.photos/100?image=201'},
    {'name': 'A. R. Rahman', 'image': 'https://picsum.photos/100?image=202'},
    {'name': 'Taylor Swift', 'image': 'https://picsum.photos/100?image=203'},
  ];

  void _showLanguagePicker() async {
    final chosen = await showDialog<String>(
        context: context,
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
      setState(() => _selectedLanguage = chosen);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Language set to $chosen')));
    }
  }

  void _showAddSingerDialog() async {
    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final added = await showDialog<bool>(
        context: context,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Singer added')));
    }
  }

  void _showEditProfileDialog() async {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);
    final saved = await showDialog<bool>(
        context: context,
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
                    if (nm.isEmpty) return; // require name
                    setState(() {
                      _name = nm;
                      _email = em.isEmpty ? _email : em;
                      _phone = ph.isEmpty ? _phone : ph;
                    });
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save'))
            ],
          );
        });
    if (saved == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated')));
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

              // Languages header + small horizontal list of language thumbnails
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
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.black26))),
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
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
                subtitle: Text(_selectedLanguage,
                    style: const TextStyle(color: Colors.black87)),
                trailing: TextButton(
                    onPressed: _showLanguagePicker,
                    child: const Text('Change',
                        style: TextStyle(color: Colors.tealAccent))),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications, color: Colors.black87),
                title: const Text('Notifications'),
                subtitle: const Text('Enable push notifications',
                    style: TextStyle(color: Colors.black87)),
                trailing: Switch(
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                    thumbColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.tealAccent;
                      }
                      return null;
                    })),
              ),

              const SizedBox(height: 6),
              const Divider(color: Color.fromARGB(255, 236, 235, 235)),
              const SizedBox(height: 8),

              // Singers section
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
                                  style: const TextStyle(color: Colors.black87),
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

              const Spacer(),

              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')));
                  },
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
                    child: Text('Sign out'),
                  ),
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
