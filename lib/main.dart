import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
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

  // Contacto seleccionado y carrito
  Contact? _selectedContact;
  List<Contact> _phoneContacts = [];
  bool _isLoadingContacts = false;

  final Map<String, double> _products = {
    'ABRILLANTADOR DE CALZADO 9 ML': 54.00,
    'ACEITE BABY NUTRINE 150 ML': 65.00,
  };

  final Map<String, int> _cart = {
    'ABRILLANTADOR DE CALZADO 9 ML': 3,
    'ACEITE BABY NUTRINE 150 ML': 3,
  };

  List<Map<String, dynamic>> _orderHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Cargar contactos del teléfono
  Future<void> _getPhoneContacts() async {
    setState(() => _isLoadingContacts = true);
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      setState(() {
        _phoneContacts = contacts.where((c) => c.phones.isNotEmpty).toList();
        _isLoadingContacts = false;
      });
    } else {
      setState(() => _isLoadingContacts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de contactos denegado')),
        );
      }
    }
  }

  double get _totalPrice {
    double total = 0;
    _cart.forEach((product, qty) {
      total += (_products[product] ?? 0) * qty;
    });
    return total;
  }

  String _generateOrderSummary() {
    String clientName = _selectedContact != null 
        ? _selectedContact!.displayName 
        : 'Cliente No Especificado';
        
    StringBuffer buffer = StringBuffer();
    buffer.writeln('*NUEVO PEDIDO*');
    buffer.writeln('Cliente: $clientName');
    buffer.writeln('---------------------------');
    
    _cart.forEach((product, qty) {
      if (qty > 0) {
        double price = _products[product] ?? 0;
        buffer.writeln('• $product x$qty = \$${(price * qty).toStringAsFixed(2)}');
      }
    });
    
    buffer.writeln('---------------------------');
    buffer.writeln('*TOTAL: \$${_totalPrice.toStringAsFixed(2)}*');
    return buffer.toString();
  }

  Future<void> _sendWhatsApp() async {
    if (_selectedContact == null || _selectedContact!.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente con número válido')),
      );
      return;
    }

    String phone = _selectedContact!.phones.first.number
        .replaceAll(RegExp(r'[^\d+]'), '');
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
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> newOrder = {
      'client': _selectedContact?.displayName ?? 'Cliente',
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'total': _totalPrice,
      'items': _cart.entries.where((e) => e.value > 0).map((e) => '${e.key} x${e.value}').toList(),
    };

    _orderHistory.insert(0, newOrder);
    await prefs.setString('order_history', jsonEncode(_orderHistory));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido guardado con éxito')),
      );
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('order_history');
    if (data != null) {
      setState(() {
        _orderHistory = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  void _showContactPicker() async {
    await _getPhoneContacts();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _isLoadingContacts
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _phoneContacts.length,
                itemBuilder: (context, index) {
                  final contact = _phoneContacts[index];
                  final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
                  return ListTile(
                    title: Text(contact.displayName),
                    subtitle: Text(phone),
                    onTap: () {
                      setState(() {
                        _selectedContact = contact;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              );
      },
    );
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
          const Center(child: Text('Clientes')),
          const Center(child: Text('Productos')),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: InkWell(
            onTap: _showContactPicker,
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
                    _selectedContact == null
                        ? 'Buscar/Seleccionar Cliente de la Agenda'
                        : '${_selectedContact!.displayName} (${_selectedContact!.phones.first.number})',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            children: _products.keys.map((productName) {
              int qty = _cart[productName] ?? 0;
              double price = _products[productName] ?? 0;
              return ListTile(
                title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('\$${price.toStringAsFixed(2)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () {
                        if (qty > 0) {
                          setState(() => _cart[productName] = qty - 1);
                        }
                      },
                    ),
                    Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onPressed: () {
                        setState(() => _cart[productName] = qty + 1);
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
}
