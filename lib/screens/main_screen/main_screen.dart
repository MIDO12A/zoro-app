import 'package:flutter/material.dart';
import '../../config/r.dart';
import '../../services/dynamic_config_service.dart';
import '../../l10n/app_localizations.dart';
import '../discover/room_discover_screen.dart';
import '../message/message_screen.dart';
import '../login/profile_screen.dart';
import '../room/widgets/svga_player.dart';



class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: DynamicConfigService(),
      builder: (context, _) {
        final pages = <Widget>[
          RoomDiscoverScreen(),
          MessageScreen(),
          ProfileScreen(),
        ];
        return Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: pages,
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFF4DDA9),
                      Color(0xFFFFFFFF),
                    ],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          normalIcon: R.tabDiscoverNor,
                          selectedIcon: R.tabDiscoverPre,
                          label: l10n.tabDiscover,
                        ),
                        _buildNavItem(
                          index: 1,
                          normalIcon: R.tabMessageNor,
                          selectedIcon: R.tabMessagePre,
                          label: l10n.tabMessage,
                        ),
                        _buildNavItem(
                          index: 2,
                          normalIcon: R.tabMineNor,
                          selectedIcon: R.tabMinePre,
                          label: l10n.tabProfile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navIconWidget(String iconPath) {
    if (iconPath.endsWith('.svga') || iconPath.endsWith('.vap')) {
      return SvgaPlayer(
        assetPath: iconPath,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
      );
    }
    return R.image(iconPath, width: 48, height: 48, fit: BoxFit.contain);
  }

  Widget _buildNavItem({
    required int index,
    required String normalIcon,
    required String selectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: _navIconWidget(isSelected ? selectedIcon : normalIcon),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Color(0xFF894916),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
