import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Full-width primary action button with built-in loading state.
class VybeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color? color;
  final double height;
  const VybeButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon, this.color, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? AppColors.primary,
          disabledBackgroundColor: (color ?? AppColors.primary).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: loading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, style: AppText.button.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
      ),
    );
  }
}

/// Rounded white surface used for grouping content.
class VybeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool bordered;
  const VybeCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: bordered ? Border.all(color: AppColors.line) : null,
        boxShadow: bordered ? null : AppShadow.soft,
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(AppRadius.lg), onTap: onTap, child: body),
    );
  }
}

/// Small coloured square holding an icon.
class VybeIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const VybeIconBox({super.key, required this.icon, this.color = AppColors.primary, this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// Status pill (e.g. "completed", "searching").
class VybeBadge extends StatelessWidget {
  final String text;
  final Color color;
  const VybeBadge({super.key, required this.text, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(7)),
    child: Text(text, style: AppText.tiny.copyWith(color: color, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

/// Pickup -> drop route card with dotted connector.
class VybeRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final EdgeInsets padding;
  const VybeRouteCard({super.key, required this.from, required this.to, this.padding = const EdgeInsets.fromLTRB(14, 13, 14, 13)});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.line)),
    child: Stack(children: [
      Positioned(left: 3.5, top: 20, child: Column(children: List.generate(4, (_) =>
        Container(width: 1.5, height: 3, margin: const EdgeInsets.only(bottom: 3), color: AppColors.muted.withOpacity(0.55)))),
      ),
      Column(children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("FROM", style: AppText.tiny),
            const SizedBox(height: 1),
            Text(from, style: AppText.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("TO", style: AppText.tiny),
            const SizedBox(height: 1),
            Text(to, style: AppText.bodyStrong.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ]),
    ]),
  );
}

/// Selectable ride option row (Single / Sharing).
class VybeRideOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  const VybeRideOption({super.key, required this.icon, required this.title, required this.subtitle, required this.price, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft.withOpacity(0.45) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: selected ? AppColors.primarySoft : AppColors.canvas, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: Icon(icon, size: 19, color: selected ? AppColors.primary : AppColors.body),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(subtitle, style: AppText.label.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Text(price, style: AppText.price.copyWith(fontSize: 15)),
        if (selected) ...[
          const SizedBox(width: 9),
          Container(width: 18, height: 18, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 11, color: Colors.white)),
        ],
      ]),
    ),
  );
}

/// Empty state with icon, title and optional action.
class VybeEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const VybeEmpty({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 76, height: 76,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), shape: BoxShape.circle),
        child: Icon(icon, size: 34, color: AppColors.primary.withOpacity(0.75))),
      const SizedBox(height: 18),
      Text(title, style: AppText.h3, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: AppText.body, textAlign: TextAlign.center),
      ],
      if (action != null) ...[const SizedBox(height: 20), action!],
    ]),
  ));
}

/// Shimmer placeholder block used while data loads.
class VybeShimmer extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const VybeShimmer({super.key, this.height = 16, this.width, this.radius = 8});
  @override State<VybeShimmer> createState() => _VybeShimmerState();
}

class _VybeShimmerState extends State<VybeShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(-1 + 2 * _c.value, 0),
          end: Alignment(1 + 2 * _c.value, 0),
          colors: const [Color(0xFFEDF1F6), Color(0xFFF7F9FC), Color(0xFFEDF1F6)],
        ),
      ),
    ),
  );
}

/// Standard loading list used by history / tickets.
class VybeListSkeleton extends StatelessWidget {
  final int count;
  const VybeListSkeleton({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: count,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (_, __) => Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), boxShadow: AppShadow.soft),
      child: Row(children: [
        const VybeShimmer(height: 42, width: 42, radius: 11),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          VybeShimmer(height: 13, width: 130),
          SizedBox(height: 8),
          VybeShimmer(height: 11, width: 90),
        ])),
        const VybeShimmer(height: 17, width: 52),
      ]),
    ),
  );
}

/// Fade + slide entrance animation for list items and sections.
class VybeFadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const VybeFadeIn({super.key, required this.child, this.delayMs = 0});
  @override State<VybeFadeIn> createState() => _VybeFadeInState();
}

class _VybeFadeInState extends State<VybeFadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () { if (mounted) _c.forward(); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
      child: widget.child,
    ),
  );
}
