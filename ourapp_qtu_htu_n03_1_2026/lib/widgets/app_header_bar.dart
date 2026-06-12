import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:privatechat/services/lan_chat_controller.dart';
import 'package:privatechat/services/theme_controller.dart';

class AppHeaderBar extends StatelessWidget {
  const AppHeaderBar({
    super.key,
    required this.search,
    required this.searchHint,
    required this.username,
    required this.status,
    required this.onSearchChanged,
    required this.onLogout,
    this.onSearchSubmitted,
    this.leadingIcon,
    this.leadingTooltip,
    this.onLeadingPressed,
    this.onRefresh,
  });

  final TextEditingController search;
  final String searchHint;
  final String username;
  final ConnectionStatus status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback onLogout;
  final IconData? leadingIcon;
  final String? leadingTooltip;
  final VoidCallback? onLeadingPressed;
  final VoidCallback? onRefresh;

  static const headerBlue = Color(0xFF0084FF);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final statusColor = switch (status) {
      ConnectionStatus.connected => Colors.lightGreenAccent,
      ConnectionStatus.connecting => Colors.amber,
      ConnectionStatus.disconnected => Colors.redAccent,
    };

    return ColoredBox(
      color: headerBlue,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Row(
            children: [
              if (leadingIcon != null && onLeadingPressed != null)
                _HeaderIconButton(
                  icon: leadingIcon!,
                  onPressed: onLeadingPressed!,
                  tooltip: leadingTooltip ?? '',
                ),
              if (leadingIcon != null && onLeadingPressed != null)
                const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: TextField(
                    controller: search,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                    ),
                    cursorColor: headerBlue,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade600,
                        size: 22,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 10),
                _HeaderIconButton(
                  icon: Icons.refresh_rounded,
                  onPressed: onRefresh!,
                  tooltip: 'Làm mới',
                ),
              ],
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Icon(Icons.circle, size: 8, color: statusColor),
                      ),
                    ],
                  ),
                ),
                color: Theme.of(context).colorScheme.surface,
                onSelected: (v) {
                  if (v == 'logout') onLogout();
                  if (v == 'theme') theme.toggle();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      username,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(
                          theme.isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(theme.isDark ? 'Chế độ sáng' : 'Chế độ tối'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(value: 'logout', child: Text('Thoát')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
