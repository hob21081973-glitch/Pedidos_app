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
  int? _editingOrderIndex;

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

  final TextEditingController _orderSearchController = TextEditingController();
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();

  String _orderSearchQuery = '';
  String _clientSearchQuery = '';
  String _productSearchQuery = '';

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
        List<dynamic> list = jsonDecode(historyData);
        _orderHistory = list.map((item) => Map<String, dynamic>.from(item)).toList();
      });
    }

    String? clientsData = prefs.getString('saved_clients');
    if (clientsData != null) {
      setState(() {
        List<dynamic> list = jsonDecode(clientsData);
        _clients = list.map((item) => Map<String, String>.from(item as Map)).toList();
      });
    }

    String? productsData = prefs.getString('saved_products');
    if (productsData != null) {
      setState(() {
        List<dynamic> list = jsonDecode(productsData);
        _products = list.map((item) => Map<String, dynamic>.from(item)).toList();
      });
    }

    _resetCart();
  }

  void _resetCart() {
    _cart.clear();
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

  Future<void> _sendWhatsApp({String? customPhone, String? customMessage}) async {
    String? phone = customPhone ?? _selectedClient?['phone'];
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente con número de teléfono validado.')),
      );
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    String messageText = customMessage ?? _generateOrderSummary();
    Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(messageText)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (customMessage == null) {
        await _saveOrder();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  Future<void> _saveOrder() async {
    if (_cart.values.every((qty) => qty == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto al pedido.')),
      );
      return;
    }

    Map<String, dynamic> orderData = {
      'client': _selectedClient != null ? _selectedClient!['name']! : 'Cliente General',
      'phone': _selectedClient != null ? _selectedClient!['phone']! : '',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'total': _totalPrice,
      'items': _cart.entries.where((e) => e.value > 0).map((e) => {'name': e.key, 'qty': e.value}).toList(),
    };

    setState(() {
      if (_editingOrderIndex != null) {
        _orderHistory[_editingOrderIndex!] = orderData;
        _editingOrderIndex = null;
      } else {
        _orderHistory.insert(0, orderData);
      }
      _resetCart();
      _selectedClient = null;
    });

    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido procesado y guardado con éxito.')),
      );
    }
  }

  void _loadOrderForEditing(int index) {
    var order = _orderHistory[index];
    setState(() {
      _editingOrderIndex = index;
      _resetCart();

      var matchedClient = _clients.firstWhere(
        (c) => c['name'] == order['client'],
        orElse: () => {'name': order['client'], 'phone': order['phone'] ?? ''},
      );
      _selectedClient = matchedClient;

      List items = order['items'];
      for (var item in items) {
        if (item is Map) {
          _cart[item['name']] = item['qty'];
        } else if (item is String) {
          var parts = item.split(' x');
          if (parts.length == 2) {
            _cart[parts[0]] = int.tryParse(parts[1]) ?? 1;
          }
        }
      }
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editingOrderIndex != null ? 'Editando Pedido' : 'Sistema de Pedidos'),
        backgroundColor: Colors.green[700],
        actions: _editingOrderIndex != null
            ? [
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      _editingOrderIndex = null;
                      _resetCart();
                      _selectedClient = null;
                    });
                  },
                )
              ]
            : null,
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

  Widget _buildNewOrderTab() {
    final searchResults = _orderSearchQuery.isEmpty
        ? []
        : _products.where((p) => p['name'].toString().toLowerCase().contains(_orderSearchQuery.toLowerCase())).toList();

    final selectedProducts = _products.where((p) => (_cart[p['name']] ?? 0) > 0).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
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
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: TextField(
            controller: _orderSearchController,
            decoration: InputDecoration(
              hintText: 'Buscar y agregar producto...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _orderSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _orderSearchController.clear();
                          _orderSearchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            ),
            onChanged: (value) => setState(() => _orderSearchQuery = value),
          ),
        ),
        if (_orderSearchQuery.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(4),
            ),
            child: searchResults.isEmpty
                ? const Padding(padding: EdgeInsets.all(8.0), child: Text('Sin coincidencias'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      var prod = searchResults[index];
                      return ListTile(
                        dense: true,
                        title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('\$${(prod['price'] as num).toStringAsFixed(2)}'),
                        trailing: const Icon(Icons.add, color: Colors.green),
                        onTap: () {
                          setState(() {
                            String pName = prod['name'];
                            _cart[pName] = (_cart[pName] ?? 0) + 1;
                            _orderSearchController.clear();
                            _orderSearchQuery = '';
                          });
                        },
                      );
                    },
                  ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: selectedProducts.isEmpty
              ? const Center(
                  child: Text('Usa el buscador arriba para agregar productos.', style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: selectedProducts.length,
                  itemBuilder: (context, index) {
                    var product = selectedProducts[index];
                    String name = product['name'];
                    double price = (product['price'] as num).toDouble();
                    int qty = _cart[name] ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('\$${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 28),
                              onPressed: () {
                                if (qty > 0) setState(() => _cart[name] = qty - 1);
                              },
                            ),
                            Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 28),
                              onPressed: () => setState(() => _cart[name] = qty + 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.all(10)),
                      onPressed: _saveOrder,
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: Text(_editingOrderIndex != null ? 'Actualizar' : 'Guardar', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600], padding: const EdgeInsets.all(10)),
                      onPressed: () => _sendWhatsApp(),
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

  Widget _buildHistoryTab() {
    return _orderHistory.isEmpty
        ? const Center(child: Text('No hay pedidos guardados.'))
        : ListView.builder(
            itemCount: _orderHistory.length,
            itemBuilder: (context, index) {
              final order = _orderHistory[index];
              List rawItems = order['items'] ?? [];
              String itemsSummary = rawItems.map((e) {
                if (e is Map) return '${e['name']} x${e['qty']}';
                return e.toString();
              }).join(', ');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text('${order['client']} - \$${(order['total'] as num).toStringAsFixed(2)}'),
                  subtitle: Text('Fecha: ${order['date']}\nItems: $itemsSummary'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _loadOrderForEditing(index),
                        tooltip: 'Editar Pedido',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.green),
                        onPressed: () {
                          String msg = "*PEDIDO HISTÓRICO*\nCliente: ${order['client']}\nItems: $itemsSummary\nTotal: \$${order['total']}";
                          _sendWhatsApp(customPhone: order['phone'], customMessage: msg);
                        },
                        tooltip: 'Enviar WhatsApp',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _orderHistory.removeAt(index));
                          _saveData();
                        },
                        tooltip: 'Eliminar Pedido',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildClientsTab() {
    final filteredClients = _clients.where((c) {
      return c['name']!.toLowerCase().contains(_clientSearchQuery.toLowerCase()) ||
          c['phone']!.contains(_clientSearchQuery);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _clientSearchController,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
              onChanged: (val) => setState(() => _clientSearchQuery = val),
            ),
          ),
          Expanded(
            child: filteredClients.isEmpty
                ? const Center(child: Text('No hay clientes.'))
                : ListView.builder(
                    itemCount: filteredClients.length,
                    itemBuilder: (context, index) {
                      var client = filteredClients[index];
                      int originalIndex = _clients.indexOf(client);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: ListTile(
                          title: Text(client['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(client['phone']!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showClientDialog(index: originalIndex),
                                tooltip: 'Editar Cliente',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() => _clients.removeAt(originalIndex));
                                  _saveData();
                                },
                                tooltip: 'Eliminar Cliente',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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

  Widget _buildProductsTab() {
    final filteredProducts = _products.where((p) {
      return p['name'].toString().toLowerCase().contains(_productSearchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _productSearchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              ),
              onChanged: (val) => setState(() => _productSearchQuery = val),
            ),
          ),
          Expanded(
            child: filteredProducts.isEmpty
                ? const Center(child: Text('No hay productos.'))
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      var product = filteredProducts[index];
                      int originalIndex = _products.indexOf(product);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: ListTile(
                          title: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('\$${(product['price'] as num).toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showProductDialog(index: originalIndex),
                                tooltip: 'Editar Producto',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _cart.remove(_products[originalIndex]['name']);
                                    _products.removeAt(originalIndex);
                                  });
                                  _saveData();
                                },
                                tooltip: 'Eliminar Producto',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                double? parsedPrice = double.tryParse(priceController.text);
                if (nameController.text.isNotEmpty && parsedPrice != null) {
                  setState(() {
                    if (index == null) {
                      _products.add({'name': nameController.text, 'price': parsedPrice});
                      _cart[nameController.text] = 0;
                    } else {
                      String oldName = _products[index]['name'];
                      int oldQty = _cart[oldName] ?? 0;
                      _cart.remove(oldName);

                      _products[index] = {'name': nameController.text, 'price': parsedPrice};
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
