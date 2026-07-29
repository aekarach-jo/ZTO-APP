import 'package:flutter/material.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.width = 156,
    this.height = 48,
    this.framed = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.borderRadius = 18,
    this.branchCode,
  });

  final double width;
  final double height;
  final bool framed;
  final EdgeInsets padding;
  final double borderRadius;

  /// สาขาที่กำลังใช้งาน — สาขา KD ใช้โลโก้ ZTO Savannakhet แทนโลโก้ CLS
  final String? branchCode;

  bool get _isKdBranch => branchCode?.trim().toUpperCase() == 'KD';

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius - 4),
      child: ColoredBox(
        color: Colors.white,
        child: SizedBox(
          width: width,
          height: height,
          child: _isKdBranch ? _buildKdLogo(context) : _buildClsLogo(context),
        ),
      ),
    );

    if (!framed) {
      return image;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFD7E9FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16084E9A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: image,
    );
  }

  /// โลโก้ CLS เป็นภาพจัตุรัสที่มีขอบขาวเยอะ จึงต้องซูมเข้าไปให้เต็มกรอบ
  Widget _buildClsLogo(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledSize = constraints.maxHeight * 5.2;
        final centeredTop = (constraints.maxHeight - scaledSize) / 2;

        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: (constraints.maxWidth - scaledSize) / 2,
                top: centeredTop,
                child: SizedBox(
                  width: scaledSize,
                  height: scaledSize,
                  child: Image.asset(
                    'assets/images/CLS_LOGO.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackText(context, 'CLS Logistics'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// โลโก้ KD เป็นภาพแนวนอนที่เต็มเฟรมอยู่แล้ว จึงแสดงแบบ contain ได้เลย
  Widget _buildKdLogo(BuildContext context) {
    return Image.asset(
      'assets/images/KD_LOGO.jpg',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          _buildFallbackText(context, 'ZTO Savannakhet'),
    );
  }

  Widget _buildFallbackText(BuildContext context, String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
