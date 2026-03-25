import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/models/product_model.dart';
import '../bloc/pos_bloc.dart';
import '../bloc/pos_event.dart';
import '../bloc/pos_state.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        if (state.filteredProducts.isEmpty) {
          // Agar umuman hech qanday mahsulot bo'lmasa — sync taklif qilish
          final noProducts = state.allProducts.isEmpty;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  noProducts ? Icons.inventory_2_outlined : Icons.search_off,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  noProducts ? 'Mahsulotlar yuklanmadi' : 'Mahsulot topilmadi',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                if (noProducts) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: state.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(state.isSyncing ? 'Yuklanmoqda...' : 'Sinxronlash'),
                    onPressed: state.isSyncing
                        ? null
                        : () => context.read<PosBloc>().add(SyncStarted()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.78,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: state.filteredProducts.length,
          itemBuilder: (context, index) {
            return ProductCard(product: state.filteredProducts[index]);
          },
        );
      },
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductModel product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.isLowStock;
    final isOutOfStock = product.stockQuantity <= 0;

    return GestureDetector(
      onTap: isOutOfStock ? null : () => context.read<PosBloc>().add(ProductAddedToCart(product)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOutOfStock ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const Text('TUGAGAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    if (isLowStock && !isOutOfStock)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(4)),
                          child: Text('Kam: ${product.stockQuantity.toInt()}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        color: isOutOfStock ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatPrice(product.sellPrice),
                            style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (!isOutOfStock)
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.add, size: 18, color: Colors.white),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surfaceVariant,
    alignment: Alignment.center,
    child: Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textSecondary),
  );

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
  }
}
