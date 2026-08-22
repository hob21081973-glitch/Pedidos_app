import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Pedidos',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: false),
      home: const PantallaPrincipal(),
    );
  }
}

// --- MODELOS DE DATOS ---
class Cliente {
  String nombre;
  String telefono;
  Cliente({required this.nombre, required this.telefono});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'telefono': telefono};
  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(nombre: map['nombre'], telefono: map['telefono']);
}

class Producto {
  String nombre;
  double precio;
  Producto({required this.nombre, required this.precio});

  Map<String, dynamic> toMap() => {'nombre': nombre, 'precio': precio};
  factory Producto.fromMap(Map<String, dynamic> map) => Producto(nombre: map['nombre'], precio: (map['precio'] as num).toDouble());
}

// --- BASE DE DATOS LOCAL (PERSISTENTE EN EL MÓVIL) ---
class DBLocal {
  static List<Cliente> clientes = [];
  static List<Producto> productos = [];

  static Future<void> cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? cJson = prefs.getString('clientes_db');
    if (cJson != null) {
      Iterable list = json.decode(cJson);
      clientes = list.map((model) => Cliente.fromMap(model)).toList();
    } else {
      clientes = [Cliente(nombre: "Juan Pérez", telefono: "50432152136")];
    }

    String? pJson = prefs.getString('productos_db');
    if (pJson != null) {
      Iterable list = json.decode(pJson);
      productos = list.map((model) => Producto.fromMap(model)).toList();
    } else {
      productos = [
        Producto(nombre: "Café Molido 500g", precio: 100.0),
        Producto(nombre: "Filtros de Papel", precio: 50.0),
      ];
    }
  }

  static Future<void> guardarClientes() async {
    final prefs = await SharedPreferences.getInstance();
    List mapList = clientes.map((c) => c.toMap()).toList();
    await prefs.setString('clientes_db', json.encode(mapList));
  }

  static Future<void> guardarProductos() async {
    final prefs = await SharedPreferences.getInstance();
    List mapList = productos.map((p) => p.toMap()).toList();
    await prefs.setString('productos_db', json.encode(mapList));
  }
}

// --- INTERFAZ ---
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    DBLocal.cargarDatos().then((_) {
      setState(() => cargando = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sistema de Pedidos'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.add_shopping_cart), text: "Nuevo Pedido"),
              Tab(icon: Icon(Icons.receipt_long), text: "Historial"),
              Tab(icon: Icon(Icons.people), text: "Clientes"),
              Tab(icon: Icon(Icons.inventory_2), text: "Productos"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PantallaNuevoPedido(),
            Center(child: Text("Historial de Pedidos")),
            PantallaClientes(),
            PantallaProductos(),
          ],
        ),
      ),
    );
  }
}

class PantallaNuevoPedido extends StatefulWidget {
  const PantallaNuevoPedido({super.key});

  @override
  State<PantallaNuevoPedido> createState() => _PantallaNuevoPedidoState();
}

class _PantallaNuevoPedidoState extends State<PantallaNuevoPedido> {
  Cliente? clienteSeleccionado;
  Map<int, int> cantidades = {};

  @override
  void initState() {
    super.initState();
    if (DBLocal.clientes.isNotEmpty) clienteSeleccionado = DBLocal.clientes.first;
  }

  @override
  Widget build(BuildContext context) {
    if (DBLocal.clientes.isNotEmpty && !DBLocal.clientes.contains(clienteSeleccionado)) {
      clienteSeleccionado = DBLocal.clientes.first;
    }

    double total = 0;
    for (int i = 0; i < DBLocal.productos.length; i++) {
      total += (cantidades[i] ?? 0) * DBLocal.productos[i].precio;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DBLocal.clientes.isEmpty
              ? const Text("No hay clientes guardados.", style: TextStyle(color: Colors.red))
              : DropdownButton<Cliente>(
                  value: clienteSeleccionado,
                  isExpanded: true,
                  items: DBLocal.clientes.map((c) => DropdownMenuItem(value: c, child: Text("${c.nombre} (${c.telefono})"))).toList(),
                  onChanged: (val) => setState(() => clienteSeleccionado = val),
                ),
        ),
        Expanded(
          child: DBLocal.productos.isEmpty
              ? const Center(child: Text("No hay productos disponibles."))
              : ListView.builder(
                  itemCount: DBLocal.productos.length,
                  itemBuilder: (context, i) {
                    final p = DBLocal.productos[i];
                    int cant = cantidades[i] ?? 0;
                    return ListTile(
                      title: Text(p.nombre),
                      subtitle: Text("\$${p.precio.toStringAsFixed(2)}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() => cantidades[i] = cant > 0 ? cant - 1 : 0)),
                          Text('$cant', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => setState(() => cantidades[i] = cant + 1)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Text("TOTAL: \$${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {},
                  child: const Text("Enviar Pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class PantallaClientes extends StatefulWidget {
  const PantallaClientes({super.key});

  @override
  State<PantallaClientes> createState() => _PantallaClientesState();
}

class _PantallaClientesState extends State<PantallaClientes> {
  void _mostrarModalCliente({Cliente? clienteExistente, int? index}) {
    final nom = TextEditingController(text: clienteExistente?.nombre ?? '');
    final tel = TextEditingController(text: clienteExistente?.telefono ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(clienteExistente == null ? "Nuevo Cliente" : "Editar Cliente"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: "Nombre")),
              TextField(controller: tel, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Teléfono")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nom.text.isNotEmpty && tel.text.isNotEmpty) {
                setState(() {
                  if (clienteExistente == null) {
                    DBLocal.clientes.add(Cliente(nombre: nom.text, telefono: tel.text));
                  } else {
                    clienteExistente.nombre = nom.text;
                    clienteExistente.telefono = tel.text;
                  }
                });
                await DBLocal.guardarClientes();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DBLocal.clientes.isEmpty
          ? const Center(child: Text("No hay clientes guardados."))
          : ListView.builder(
              itemCount: DBLocal.clientes.length,
              itemBuilder: (context, i) {
                final c = DBLocal.clientes[i];
                return ListTile(
                  leading: const Icon(Icons.person, color: Colors.green),
                  title: Text(c.nombre),
                  subtitle: Text(c.telefono),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _mostrarModalCliente(clienteExistente: c, index: i);
                      } else if (val == 'delete') {
                        setState(() => DBLocal.clientes.removeAt(i));
                        await DBLocal.guardarClientes();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _mostrarModalCliente(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class PantallaProductos extends StatefulWidget {
  const PantallaProductos({super.key});

  @override
  State<PantallaProductos> createState() => _PantallaProductosState();
}

class _PantallaProductosState extends State<PantallaProductos> {
  void _mostrarModalProducto({Producto? productoExistente, int? index}) {
    final nom = TextEditingController(text: productoExistente?.nombre ?? '');
    final pre = TextEditingController(text: productoExistente != null ? productoExistente.precio.toString() : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(productoExistente == null ? "Nuevo Producto" : "Editar Producto"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: "Nombre")),
              TextField(controller: pre, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nom.text.isNotEmpty && pre.text.isNotEmpty) {
                double precioNum = double.tryParse(pre.text) ?? 0.0;
                setState(() {
                  if (productoExistente == null) {
                    DBLocal.productos.add(Producto(nombre: nom.text, precio: precioNum));
                  } else {
                    productoExistente.nombre = nom.text;
                    productoExistente.precio = precioNum;
                  }
                });
                await DBLocal.guardarProductos();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DBLocal.productos.isEmpty
          ? const Center(child: Text("No hay productos guardados."))
          : ListView.builder(
              itemCount: DBLocal.productos.length,
              itemBuilder: (context, i) {
                final p = DBLocal.productos[i];
                return ListTile(
                  leading: const Icon(Icons.shopping_bag, color: Colors.green),
                  title: Text(p.nombre),
                  subtitle: Text("\$${p.precio.toStringAsFixed(2)}"),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'edit') {
                        _mostrarModalProducto(productoExistente: p, index: i);
                      } else if (val == 'delete') {
                        setState(() => DBLocal.productos.removeAt(i));
                        await DBLocal.guardarProductos();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Eliminar')])),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        onPressed: () => _mostrarModalProducto(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}