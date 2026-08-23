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

  List<Map<String, String>> _clients = [
    {'name': 'Juan Pérez', 'phone': '50432152136'},
  ];

  List<Map<String, dynamic>> _products = [
    {'name': 'ABRILLANTADOR DE CALZADO 9 ML', 'price': 54.00},
    {'name': 'ACEITE BABY NUTRINE 150 ML', 'price': 65.00},
  ];

  final Map<String, int> _cart = {};
  Map<String, String>? _selectedClient;
  List<Map<String, dynamic>> _orderHistory = [];

  // Controlador de búsqueda de productos
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? historyData = prefs.getString('order_history');
    if (historyData != null) {
      setState(() {
        _orderHistory = List<Map<String, dynamic>>.from(jsonDecode(historyData));
      });
    }

    String? clientsData = prefs.getString('saved_clients');
    if (clientsData != null) {
      setState(() {
        _clients = List<Map<String, String>>.from(
          jsonDecode(clientsData).map((item) => Map<String, String>.from(item))
        );
      });
    }

    String? productsData = prefs.getString('saved_products');
    if (productsData != null) {
      setState(() {
        _products = List<Map<String, dynamic>>.from(jsonDecode(productsData));
      });
    }

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
      var prod = _products.firstWhere(
        (p) => p['name'] == productName,
        orElse: () => {'price': 0.0},
      );
      double price = (prod['price'] as num).toDouble();
      total += price * qty;
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
        var prod = _products.firstWhere((p) => p['name'] == product, orElse: () => {'price': 0.0});
        double price = (prod['price'] as num).toDouble();
        buffer.writeln('• $product x$qty = \$${(price * qty).toStringAsFixed(2)}');
      }
    });
    
    buffer.writeln('---------------------------');
    buffer.writeln('*TOTAL: \$${_totalPrice.toStringAsFixed(2)}*');
    return buffer.toString();
  }

  Future<void> _sendWhatsApp() async {
    if (_selectedClient == null || (_selectedClient!['phone'] ?? '').isEmpty) {
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
    final filteredProducts = _products.where((product) {
      return product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Selector de Cliente
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: InkWell(
            onTap: _showClientSelectorDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedClient == null
                          ? 'Seleccionar Cliente'
                          : '${_selectedClient!['name']} (${_selectedClient!['phone']})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),

        // Buscador de productos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(height: 8),

        // Lista de Productos filtrada
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(child: Text('No se encontraron productos.'))
              : ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    var product = filteredProducts[index];
                    String name = product['name'];
                    double price = (product['price'] as num).toDouble();
                    int qty = _cart[name] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('\$${price.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                if (qty > 0) setState(() => _cart[name] = qty - 1);
                              },
                            ),
                            Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () {
                                setState(() => _cart[name] = qty + 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Total y Botones
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Text(
                'TOTAL: \$${_totalPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[800]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(12)),
                      onPressed: _saveOrder,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text('Guardar', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.all(12)),
                      onPressed: _sendWhatsApp,
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text('Enviar Pedido', style: TextStyle(color: Colors.white)),
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
            child: _clients.isEmpty
                ? const Text('No hay clientes agregados.')
                : ListView.builder(
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
      body: _clients.isEmpty
          ? const Center(child: Text('No hay clientes registrados.'))
          : ListView.builder(
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                var client = _clients[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(client['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(client['phone']!),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showClientDialog(index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => _clients.removeAt(index));
                            _saveData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _showClientDialog(),
        child: const Icon(Icons.add, color: Colors.white),
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
      body: _products.isEmpty
          ? const Center(child: Text('No hay productos registrados.'))
          : ListView.builder(
              itemCount: _products.length,
              itemBuilder: (context, index) {
                var product = _products[index];
                double price = (product['price'] as num).toDouble();
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('\$${price.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showProductDialog(index: index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _cart.remove(_products[index]['name']);
                              _products.removeAt(index);
                            });
                            _saveData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add, color: Colors.white),
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
