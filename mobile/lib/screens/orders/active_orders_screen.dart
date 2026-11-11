import 'package:flutter/material.dart';

import 'orders_screen.dart';

/// Rute lama `/active-orders`: membuka OrdersScreen pada tab Aktif.
class ActiveOrdersScreen extends StatelessWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => const OrdersScreen(initialTab: 0);
}
