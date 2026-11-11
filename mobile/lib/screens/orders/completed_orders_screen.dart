import 'package:flutter/material.dart';

import 'orders_screen.dart';

/// Rute lama `/completed-orders`: membuka OrdersScreen pada tab Selesai.
class CompletedOrdersScreen extends StatelessWidget {
  const CompletedOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => const OrdersScreen(initialTab: 1);
}
