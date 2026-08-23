import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Pedidos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: false,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Listas de datos locales
  List<Map<String, String>> _clients = [
    {'name': 'Juan Pérez', 'phone': '50432152136'},
  ];

  List<Map<String, dynamic>> _products = [
    {'name': 'ABRILLANTADOR DE CALZADO 9 ML', 'price': 54.00},
    {'name': 'ACEITE BABY NUTRINE 150 ML', 'price': 65.00},
  ];

  Map<String, int> _cart = {};
  Map<String, String>? _selectedClient;
  List<Map<String, dynamic>> _orderHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Cargar historial
    String? historyData = prefs.getString('order_history');
    if (historyData != null) {
      setState(() {
        _orderHistory = List<Map<String, dynamic>>.from(jsonDecode(historyData));
      });
    }

    // Cargar clientes
    String? clientsData = prefs.getString('saved_clients');
    if (clientsData != null) {
      setState(() {
        _clients = List<Map<String, String>>.from(
          jsonDecode(clientsData).map((item) => Map<String, String>.from(item))
        );
      });
    }

    // Cargar productos
    String? productsData = prefs.getString('saved_products');
    if (productsData != null) {
      setState(() {
        _products = List<Map<String, dynamic>>.from(jsonDecode(productsData));
      });
    }

    // Inicializar carrito
    for (var p in _products) {
      _cart[p['name']] = 0;
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('order_history', jsonEncode(_orderHistory));
    await prefs.setString('saved_clients', jsonEncode(_clients));
    await prefs.setString('saved_products', jsonEncode(_products));
  }

  double get _totalPrice {
    double total = 0;
    _cart.forEach((productName, qty) {
      var prod = _products.firstWhere((p) => p['name'] == productName, orElse: () => {'price': 0.0});
      total += (prod['price'] as double) * qty;
    });
    return total;
  }

  String _generateOrderSummary() {
    String clientName = _selectedClient != null ? _selectedClient!['name']! : 'Cliente General';
    StringBuffer buffer = StringBuffer();
    buffer.writeln('*NUEVO PEDIDO*');
    buffer.writeln('Cliente: $clientName');
    buffer.writeln('---------------------------');
    
    _cart.forEach((product, qty) {
      if (qty > 0) {
        var prod = _products.firstWhere((p) => p['name'] == product);
        double price = prod['price'];
        buffer.writeln('• $product x$qty = \$${(price * qty).toStringAsFixed(2)}');
      }
    });
    
    buffer.writeln('---------------------------');
    buffer.writeln('*TOTAL: \$${_totalPrice.toStringAsFixed(2)}*');
    return buffer.toString();
  }

  Future<void> _sendWhatsApp() async {
    if (_selectedClient == null || _selectedClient!['phone']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente con número de teléfono')),
      );
      return;
    }

    String phone = _selectedClient!['phone']!.replaceAll(RegExp(r'[^\d+]'), '');
    String text = Uri.encodeComponent(_generateOrderSummary());
    Uri url = Uri.parse("https://wa.me/$phone?text=$text");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await _saveOrder();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _saveOrder() async {
    Map<String, dynamic> newOrder = {
      'client': _selectedClient != null ? _selectedClient!['name']! : 'Cliente General',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'total': _totalPrice,
      'items': _cart.entries.where((e) => e.value > 0).map((e) => '${e.key} x${e.value}').toList(),
    };

    setState(() {
      _orderHistory.insert(0, newOrder);
    });
    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido guardado en el Historial')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Pedidos'),
        backgroundColor: Colors.green[700],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildNewOrderTab(),
          _buildHistoryTab(),
          _buildClientsTab(),
          _buildProductsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Nuevo Pedido'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Productos'),
        ],
      ),
    );
  }

  // PESTAÑA NUEVO PEDIDO
  Widget _buildNewOrderTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: InkWell(
            onTap: _showClientSelectorDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedClient == null
                        ? 'Seleccionar Cliente'
                        : '${_selectedClient!['name']} (${_selectedClient!['phone']})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: _products.map((product) {
              String name = product['name'];
              double price = product['price'];
              int qty = _cart[name] ?? 0;
              return ListTile(
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('\$${price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        if (qty > 0) setState(() => _cart[name] = qty - 1);
                      },
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () {
                        setState(() => _cart[name] = qty + 1);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'TOTAL: \$${_totalPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(12)),
                      onPressed: _saveOrder,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.all(12)),
                      onPressed: _sendWhatsApp,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar Pedido'),
                    ),
                  ),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  void _showClientSelectorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Cliente'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                var client = _clients[index];
                return ListTile(
                  title: Text(client['name']!),
                  subtitle: Text(client['phone']!),
                  onTap: () {
                    setState(() => _selectedClient = client);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // PESTAÑA HISTORIAL
  Widget _buildHistoryTab() {
    return _orderHistory.isEmpty
        ? const Center(child: Text('No hay pedidos guardados.'))
        : ListView.builder(
            itemCount: _orderHistory.length,
            itemBuilder: (context, index) {
              final order = _orderHistory[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text('${order['client']} - \$${order['total']}'),
                  subtitle: Text('Fecha: ${order['date']}\nItems: ${(order['items'] as List).join(', ')}'),
                  isThreeLine: true,
                ),
              );
            },
          );
  }

  // PESTAÑA CLIENTES
  Widget _buildClientsTab() {
    return Scaffold(
      body: ListView.builder(
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          var client = _clients[index];
          return ListTile(
            title: Text(client['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(client['phone']!),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showClientDialog(index: index);
                } else if (value == 'delete') {
                  setState(() => _clients.removeAt(index));
                  _saveData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _showClientDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showClientDialog({int? index}) {
    TextEditingController nameController = TextEditingController(text: index != null ? _clients[index]['name'] : '');
    TextEditingController phoneController = TextEditingController(text: index != null ? _clients[index]['phone'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? 'Nuevo Cliente' : 'Editar Cliente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del cliente')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Teléfono (WhatsApp)'), keyboardType: TextInputType.phone),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    if (index == null) {
                      _clients.add({'name': nameController.text, 'phone': phoneController.text});
                    } else {
                      _clients[index] = {'name': nameController.text, 'phone': phoneController.text};
                    }
                  });
                  _saveData();
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  // PESTAÑA PRODUCTOS
  Widget _buildProductsTab() {
    return Scaffold(
      body: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          var product = _products[index];
          return ListTile(
            title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('\$${(product['price'] as double).toStringAsFixed(2)}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showProductDialog(index: index);
                } else if (value == 'delete') {
                  setState(() {
                    _cart.remove(_products[index]['name']);
                    _products.removeAt(index);
                  });
                  _saveData();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showProductDialog({int? index}) {
    TextEditingController nameController = TextEditingController(text: index != null ? _products[index]['name'] : '');
    TextEditingController priceController = TextEditingController(text: index != null ? _products[index]['price'].toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(index == null ? 'Nuevo Producto' : 'Editar Producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre del producto')),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                  double price = double.tryParse(priceController.text) ?? 0.0;
                  setState(() {
                    if (index == null) {
                      _products.add({'name': nameController.text, 'price': price});
                      _cart[nameController.text] = 0;
                    } else {
                      String oldName = _products[index]['name'];
                      int oldQty = _cart[oldName] ?? 0;
                      _cart.remove(oldName);
                      _products[index] = {'name': nameController.text, 'price': price};
                      _cart[nameController.text] = oldQty;
                    }
                  });
                  _saveData();
                  Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
