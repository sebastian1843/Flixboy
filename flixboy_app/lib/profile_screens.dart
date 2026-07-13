// lib/profile_screens.dart
// Pantallas de selección y gestión de perfiles.
import 'package:flutter/material.dart';
import 'main.dart';
import 'firebase_service.dart';
import 'storage_service.dart';
import 'app_transitions.dart';
import 'push_notifications.dart';
import 'profile_manager.dart';
import 'kids_mode.dart';
import 'auth_screens.dart';
import 'home_screen.dart';
//  PANTALLA 8: SELECCIÓN DE PERFILES
// ══════════════════════════════════════════════════════════════

Widget _buildImageSelector(
    List<String> imgs, String selImage, void Function(String) onSelect) {
  return SizedBox(
    height: 80,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: imgs.length,
      itemBuilder: (_, i) {
        final img   = imgs[i];
        final isSel = selImage == img;
        return GestureDetector(
          onTap: () => onSelect(img),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                  width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(img, width: 60, height: 60, fit: BoxFit.cover),
            ),
          ),
        );
      },
    ),
  );
}

class ProfileSelectScreen extends StatefulWidget {
  const ProfileSelectScreen({super.key});
  @override State<ProfileSelectScreen> createState() =>
      _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  List<UserProfile> _profiles = [];
  final List<String> _imgs = [
    'assets/images/profile1.jpg', 'assets/images/profile2.jpg',
    'assets/images/profile3.jpg', 'assets/images/profile4.jpg',
    'assets/images/profile5.jpg',
  ];
  bool _loading = true;

  @override void initState() { super.initState(); _loadProfiles(); }

  Future<void> _loadProfiles() async {
    final saved       = await StorageService.loadProfiles();
    final displayName = AuthService.currentUser?.displayName ?? 'Usuario';
    setState(() {
      if (saved.isNotEmpty) {
        _profiles = saved.map((p) => UserProfile(
          name:       p['name']       as String,
          image:      p['image']      as String,
          pin:        p['pin']        as String?,
          isOwner:    p['isOwner']    as bool? ?? false,
          isKidsMode: p['isKidsMode'] as bool? ?? false,
        )).toList();
      } else {
        _profiles = [UserProfile(
            name: displayName,
            image: 'assets/images/profile1.jpg',
            isOwner: true)];
        _persistProfiles();
      }
      _loading = false;
    });
  }

  Future<void> _persistProfiles() async => StorageService.saveProfiles(
    _profiles.map((p) => {
      'name': p.name, 'image': p.image, 'pin': p.pin,
      'isOwner': p.isOwner, 'isKidsMode': p.isKidsMode,
    }).toList(),
  );

  void _addProfile() {
    if (_profiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Máximo 5 perfiles'),
          backgroundColor: Color(0xFFE50914)));
      return;
    }
    Navigator.push(context, AppRoute.slideUp(CreateProfileScreen(
      availableImages: _imgs,
      onCreated: (profile) async {
        setState(() => _profiles.add(profile));
        await _persistProfiles();
      },
    )));
  }

  void _selectProfile(UserProfile p) {
    final profileData = ProfileData(
      id:         p.name,
      name:       p.name,
      image:      p.image,
      pin:        p.pin,
      isOwner:    p.isOwner,
      isKidsMode: p.isKidsMode,
    );

    if (p.pin != null) {
      _showPinDialog(p, profileData);
    } else {
      ProfileManager.setActiveProfile(profileData).then((_) {
        if (profileData.isKidsMode) {
          Navigator.pushReplacement(
              context, AppRoute.fade(KidsModeScreen(allContent: const [])));
        } else {
          Navigator.pushReplacement(
              context, AppRoute.fade(const HomeScreen()));
        }
      });
    }
  }

  void _showPinDialog(UserProfile p, ProfileData profileData) {
    final pinCtrl = TextEditingController();
    bool obscure = true, error = false;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8),
            child: Image.asset(p.image, width: 36, height: 36, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Expanded(child: Text(p.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ingresa el PIN para acceder.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: pinCtrl, obscureText: obscure,
            keyboardType: TextInputType.number, maxLength: 6,
            style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 8),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(color: Color(0xFF999999), letterSpacing: 8),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF999999)),
                onPressed: () => set(() => obscure = !obscure),
              ),
              filled: true, fillColor: const Color(0xFF222222),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: error ? const Color(0xFFE50914) : const Color(0xFF3A3A3A),
                    width: 1.5),
              ),
            ),
            onChanged: (_) => set(() => error = false),
          ),
          if (error) ...[
            const SizedBox(height: 8),
            const Text('PIN incorrecto',
                style: TextStyle(color: Color(0xFFE50914), fontSize: 12)),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              if (hashPin(pinCtrl.text) == p.pin) {
                Navigator.pop(ctx);
                ProfileManager.setActiveProfile(profileData).then((_) {
                  if (profileData.isKidsMode) {
                    Navigator.pushReplacement(context,
                        AppRoute.fade(KidsModeScreen(allContent: const [])));
                  } else {
                    Navigator.pushReplacement(
                        context, AppRoute.fade(const HomeScreen()));
                  }
                });
              } else {
                set(() => error = true);
              }
            },
            child: const Text('Entrar'),
          ),
        ],
      )),
    );
  }

 @override
Widget build(BuildContext context) {
  if (_loading) return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE50914))));
  return Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    body: SafeArea(child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('FLIXBOY', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
              color: Color(0xFFE50914), letterSpacing: 4)),
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              AppRoute.slideUp(ManageProfilesScreen(
                  profiles: _profiles, availableImages: _imgs)),
            ).then((_) async { await _persistProfiles(); setState(() {}); }),
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF999999), size: 18),
            label: const Text('Editar',
                style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
          ),
        ]),
      ),
      // ... resto del build de ProfileSelectScreen
        const SizedBox(height: 32),
        const Text('¿Quién está viendo?', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 40),
        Expanded(child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 24,
              crossAxisSpacing: 24, childAspectRatio: 0.85),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          itemCount: _profiles.length + (_profiles.length < 5 ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _profiles.length) return GestureDetector(
              onTap: _addProfile,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 90, height: 90,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3A3A3A), width: 2)),
                  child: const Icon(Icons.add, size: 40, color: Color(0xFF999999))),
                const SizedBox(height: 12),
                const Text('Agregar perfil',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
              ]),
            );
            final p = _profiles[index];
            return TapScale(
              onTap: () => _selectProfile(p),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.asset(p.image, width: 90, height: 90, fit: BoxFit.cover)),
                  if (p.pin != null) Positioned(bottom: 4, right: 4,
                    child: Container(width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE50914), shape: BoxShape.circle),
                      child: const Icon(Icons.lock, color: Colors.white, size: 14))),
                  if (p.isOwner) Positioned(top: 4, right: 4,
                    child: Container(width: 24, height: 24,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE50914), shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A0A0A), width: 2)),
                      child: const Icon(Icons.star, color: Colors.white, size: 12))),
                  if (p.isKidsMode) Positioned(top: 4, left: 4,
                    child: Container(width: 24, height: 24,
                      decoration: const BoxDecoration(
                          color: Color(0xFF8B0000), shape: BoxShape.circle),
                      child: const Icon(Icons.child_care, color: Colors.white, size: 13))),
                ]),
                const SizedBox(height: 12),
                Text(p.name, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                if (p.isKidsMode)
                  const Text('Kids', style: TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
              ]),
            );
          },
        )),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () async {
            await PushNotificationService.onLogout();
            await AuthService.logout();
            await LocalSessionManager.clear();
            if (mounted) {
              Navigator.pushAndRemoveUntil(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            }
          },
          icon: const Icon(Icons.logout, color: Color(0xFF999999), size: 18),
          label: const Text('Cerrar sesión',
              style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
        ),
        const SizedBox(height: 32),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 9: CREAR PERFIL
// ══════════════════════════════════════════════════════════════

class CreateProfileScreen extends StatefulWidget {
  final List<String> availableImages;
  final void Function(UserProfile) onCreated;
  const CreateProfileScreen({
    super.key,
    required this.availableImages,
    required this.onCreated,
  });
  @override State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _nameCtrl = TextEditingController();
  String _selImage = '';
  bool _isKidsMode = false, _hasPin = false;
  final _pinCtrl  = TextEditingController();
  final _pin2Ctrl = TextEditingController();
  bool _op = true, _op2 = true;

  @override
  void initState() {
    super.initState();
    _selImage = widget.availableImages.isNotEmpty ? widget.availableImages[0] : '';
  }

  @override void dispose() {
    _nameCtrl.dispose(); _pinCtrl.dispose(); _pin2Ctrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresa un nombre'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    if (_hasPin && _pinCtrl.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PIN mínimo 4 dígitos'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    if (_hasPin && _pinCtrl.text != _pin2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PINs no coinciden'), backgroundColor: Color(0xFFE50914)));
      return;
    }
    widget.onCreated(UserProfile(
      name:       _nameCtrl.text.trim(),
      image:      _selImage,
      pin:        _hasPin ? hashPin(_pinCtrl.text) : null,
      isKidsMode: _isKidsMode,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Crear perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        // Avatar seleccionable
        GestureDetector(
          onTap: () => _showImagePicker(),
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE50914), width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _selImage.isNotEmpty
                    ? Image.asset(_selImage, fit: BoxFit.cover)
                    : Container(color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.person, size: 50, color: Color(0xFF444444))),
              ),
            ),
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFFE50914), shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 14),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('Toca para cambiar', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
        const SizedBox(height: 24),
        // Nombre
        TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nombre del perfil',
            labelStyle: const TextStyle(color: Color(0xFF999999)),
            prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF999999)),
            filled: true, fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        // Modo niños
        _switchTile(
          icon: Icons.child_care_rounded,
          title: 'Perfil infantil',
          subtitle: 'Solo mostrará contenido apto para niños.',
          value: _isKidsMode,
          onChanged: (v) => setState(() => _isKidsMode = v),
        ),
        const SizedBox(height: 12),
        // PIN
        _switchTile(
          icon: Icons.lock_outline,
          title: 'Proteger con PIN',
          subtitle: 'Solicita PIN al acceder a este perfil.',
          value: _hasPin,
          onChanged: (v) => setState(() { _hasPin = v; if (!v) { _pinCtrl.clear(); _pin2Ctrl.clear(); } }),
        ),
        if (_hasPin) ...[
          const SizedBox(height: 16),
          _pwField(_pinCtrl, 'PIN (4-6 dígitos)', _op,
              () => setState(() => _op = !_op)),
          const SizedBox(height: 12),
          _pwField(_pin2Ctrl, 'Confirmar PIN', _op2,
              () => setState(() => _op2 = !_op2)),
        ],
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ),
  );

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Elige un avatar',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12),
            itemCount: widget.availableImages.length,
            itemBuilder: (_, i) {
              final img   = widget.availableImages[i];
              final isSel = _selImage == img;
              return GestureDetector(
                onTap: () {
                  setState(() => _selImage = img);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSel ? const Color(0xFFE50914) : Colors.transparent,
                        width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(img, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ]),
      )),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: value ? const Color(0xFFE50914) : const Color(0xFF999999)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
                color: value ? Colors.white : const Color(0xFF999999))),
            Text(subtitle, style: const TextStyle(
                color: Color(0xFF666666), fontSize: 11)),
          ])),
          Switch(value: value, onChanged: onChanged,
              activeColor: const Color(0xFFE50914)),
        ]),
      );

  Widget _pwField(TextEditingController c, String label, bool ob, VoidCallback t) =>
      TextField(
        controller: c, obscureText: ob,
        keyboardType: TextInputType.number, maxLength: 6,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          counterText: '',
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF999999)),
          prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
          suffixIcon: IconButton(
            icon: Icon(ob ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF999999)),
            onPressed: t,
          ),
          filled: true, fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
//  PANTALLA 10: EDITAR PERFIL (parte de ManageProfilesScreen)
// ══════════════════════════════════════════════════════════════

class ManageProfilesScreen extends StatefulWidget {
  final List<UserProfile> profiles;
  final List<String>      availableImages;
  const ManageProfilesScreen({
    super.key,
    required this.profiles,
    required this.availableImages,
  });
  @override State<ManageProfilesScreen> createState() =>
      _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  late List<UserProfile> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = widget.profiles.map((p) => UserProfile(
      name:       p.name,
      image:      p.image,
      pin:        p.pin,
      isOwner:    p.isOwner,
      isKidsMode: p.isKidsMode,
    )).toList();
  }

  @override
  void dispose() {
    widget.profiles
      ..clear()
      ..addAll(_profiles);
    super.dispose();
  }

  void _editProfile(int index) {
    final p           = _profiles[index];
    final nameCtrl    = TextEditingController(text: p.name);
    final pinCtrl     = TextEditingController();
    final pin2Ctrl    = TextEditingController();
    String selImage   = p.image;
    bool hasPin       = p.pin != null;
    bool isKidsMode   = p.isKidsMode;
    bool op = true, op2 = true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: Text('Editar "${p.name}"',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildImageSelector(widget.availableImages, selImage,
                  (img) => set(() => selImage = img)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: const TextStyle(color: Color(0xFF999999)),
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF999999)),
                  filled: true, fillColor: const Color(0xFF222222),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.lock_outline,
                      color: hasPin ? const Color(0xFFE50914) : const Color(0xFF999999),
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Proteger con PIN',
                      style: TextStyle(
                          color: hasPin ? Colors.white : const Color(0xFF999999)))),
                  Switch(
                      value: hasPin,
                      onChanged: (v) => set(() {
                        hasPin = v;
                        if (!v) { pinCtrl.clear(); pin2Ctrl.clear(); }
                      }),
                      activeColor: const Color(0xFFE50914)),
                ]),
              ),
              if (hasPin) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl, obscureText: op,
                  keyboardType: TextInputType.number, maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: p.pin != null ? 'Nuevo PIN (vacío = mantener)' : 'PIN (4-6 dígitos)',
                    labelStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(op ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF999999)),
                      onPressed: () => set(() => op = !op),
                    ),
                    filled: true, fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pin2Ctrl, obscureText: op2,
                  keyboardType: TextInputType.number, maxLength: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Confirmar PIN',
                    labelStyle: const TextStyle(color: Color(0xFF999999)),
                    prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFF999999)),
                    suffixIcon: IconButton(
                      icon: Icon(op2 ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF999999)),
                      onPressed: () => set(() => op2 = !op2),
                    ),
                    filled: true, fillColor: const Color(0xFF222222),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.child_care_rounded,
                      color: isKidsMode ? const Color(0xFFE50914) : const Color(0xFF999999),
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Modo niños',
                        style: TextStyle(
                            color: isKidsMode ? Colors.white : const Color(0xFF999999))),
                    if (isKidsMode) const Text('Solo muestra contenido infantil',
                        style: TextStyle(color: Color(0xFF999999), fontSize: 11)),
                  ])),
                  Switch(
                      value: isKidsMode,
                      onChanged: (v) => set(() => isKidsMode = v),
                      activeColor: const Color(0xFFE50914)),
                ]),
              ),
            ],
          )),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              String? newPin = p.pin;
              if (hasPin && pinCtrl.text.isNotEmpty) {
                if (pinCtrl.text.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PIN mínimo 4 dígitos'),
                      backgroundColor: Color(0xFFE50914)));
                  return;
                }
                if (pinCtrl.text != pin2Ctrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('PINs no coinciden'),
                      backgroundColor: Color(0xFFE50914)));
                  return;
                }
                newPin = hashPin(pinCtrl.text);
              } else if (!hasPin) {
                newPin = null;
              }
              setState(() {
                _profiles[index].name       = nameCtrl.text.trim();
                _profiles[index].image      = selImage;
                _profiles[index].pin        = newPin;
                _profiles[index].isKidsMode = isKidsMode;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar cambios'),
          ),
        ],
      )),
    );
  }

  void _deleteProfile(int index) {
    if (_profiles[index].isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No puedes eliminar el perfil principal'),
          backgroundColor: Color(0xFFE50914)));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A))),
        title: const Text('Eliminar perfil', style: TextStyle(color: Colors.white)),
        content: Text('¿Eliminar "${_profiles[index].name}"?',
            style: const TextStyle(color: Color(0xFF999999))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF999999)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _profiles.removeAt(index));
              Navigator.pop(context);
            },
            child: const Text('Eliminar perfil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0A0A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0A0A0A), elevation: 0,
      leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
      title: const Text('Administrar perfiles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ),
    body: Column(children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF1E0505),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3))),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.star, color: Color(0xFFE50914), size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Text(
              'Solo el creador puede administrar perfiles.',
              style: TextStyle(color: Color(0xFF999999), fontSize: 12, height: 1.5))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _profiles.length,
        itemBuilder: (_, index) {
          final p = _profiles[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.asset(p.image, width: 52, height: 52, fit: BoxFit.cover)),
                if (p.pin != null) Positioned(bottom: 2, right: 2,
                  child: Container(width: 18, height: 18,
                    decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
                    child: const Icon(Icons.lock, color: Colors.white, size: 10))),
                if (p.isOwner) Positioned(top: 2, right: 2,
                  child: Container(width: 18, height: 18,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914), shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.5)),
                    child: const Icon(Icons.star, color: Colors.white, size: 9))),
                if (p.isKidsMode) Positioned(top: 2, left: 2,
                  child: Container(width: 18, height: 18,
                    decoration: const BoxDecoration(color: Color(0xFF8B0000), shape: BoxShape.circle),
                    child: const Icon(Icons.child_care, color: Colors.white, size: 10))),
              ]),
              title: Row(children: [
                Flexible(child: Text(p.name, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (p.isOwner) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Creador',
                        style: TextStyle(color: Color(0xFFE50914), fontSize: 10,
                            fontWeight: FontWeight.bold))),
                ],
                if (p.isKidsMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF8B0000).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Kids',
                        style: TextStyle(color: Color(0xFFCC0000), fontSize: 10,
                            fontWeight: FontWeight.bold))),
                ],
              ]),
              subtitle: Text(
                  p.pin != null ? 'Con PIN' : 'Sin PIN',
                  style: TextStyle(
                      color: p.pin != null
                          ? const Color(0xFFE50914).withValues(alpha: 0.8)
                          : const Color(0xFF999999),
                      fontSize: 12)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                    onPressed: () => _editProfile(index)),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: p.isOwner
                          ? const Color(0xFF999999).withValues(alpha: 0.3)
                          : const Color(0xFFE50914)),
                  onPressed: p.isOwner ? null : () => _deleteProfile(index),
                ),
              ]),
            ),
          );
        },
      )),
    ]),
  );
}

